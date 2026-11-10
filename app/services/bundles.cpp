#include "bundles.h"

#include "catalog.h"

#include <QDir>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkInformation>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QSettings>
#include <QStorageInfo>
#include <QtConcurrent/QtConcurrentRun>

namespace {

// The public manifest (tools/bundle.py hochladen): which bundles exist, their files, the codes'
// entries. It holds no code and no key.
const QUrl kManifest(QStringLiteral("https://git.arianw.de/api/packages/shrippen/generic/mitori-manifest/1/manifest.json"));
constexpr int kHttpError = 400;                 // from this status on a body is an error page
constexpr int kFormat = 2;                      // "format" of the manifest
constexpr int kContentFormat = 1;               // "format" of a Lernpaket's content (inhalt.mvb)
constexpr auto kWifiOnlyKey = "videos/wifiOnly";
constexpr qint64 kFreshSeconds = 6 * 60 * 60;
constexpr int kTimeoutMs = 30 * 1000;           // without a byte for this long a download fails
constexpr qint64 kProgressMs = 250;             // the least time between two progress reports
const QString kManifestFile = QStringLiteral("manifest.json");
const QString kContentKey = QStringLiteral("inhalt");
const QString kContentFile = QStringLiteral("inhalt.json");     // the decrypted content, while loading

// A file's cut points from the manifest; what makes no sense is left out (the app's own time counts).
QHash<QString, BundleShelf::Cut> cutsOf(const QJsonObject &file)
{
    QHash<QString, BundleShelf::Cut> cuts;
    for (const QJsonValue &v : file.value(QStringLiteral("kapitel")).toArray()) {
        const QJsonObject k = v.toObject();
        const QString id = k.value(QStringLiteral("id")).toString();
        const QJsonValue von = k.value(QStringLiteral("von"));
        const QJsonValue bis = k.value(QStringLiteral("bis"));
        if (id.isEmpty() || !von.isDouble() || !bis.isDouble() || von.toDouble() < 0 || von.toDouble() >= bis.toDouble()) {
            continue;
        }
        cuts.insert(id, {von.toDouble(), bis.toDouble()});
    }
    return cuts;
}

// The file a video gets on the device: "aikido-k5.mvb", version 2 → "aikido-k5.v2.mkv". With the
// version, so that a player showing the old file sees that it changed.
QString plainName(const QString &file, int version)
{
    return QFileInfo(file).completeBaseName() + QStringLiteral(".v%1.mkv").arg(version);
}

} // namespace

// MITORI_BUNDLES_MANIFEST: another manifest (tests: a local file).
Bundles::Bundles(QObject *parent)
    : QObject(parent)
    , m_shelf(&BundleShelf::shared())
    , m_source(qEnvironmentVariableIsSet("MITORI_BUNDLES_MANIFEST") ? QUrl(qEnvironmentVariable("MITORI_BUNDLES_MANIFEST")) : kManifest)
{
    loadCache();
}

Bundles::Bundles(const QUrl &manifest, const QString &root, QObject *parent)
    : QObject(parent)
    , m_ownShelf(std::make_unique<BundleShelf>(root))
    , m_shelf(m_ownShelf.get())
    , m_source(manifest)
{
    loadCache();
}

Bundles::~Bundles()
{
    for (const auto &job : std::as_const(m_jobs)) {
        if (job->reply) {
            job->reply->abort();
        }
    }
}

QNetworkAccessManager *Bundles::network()
{
    if (!m_network) {
        m_network = new QNetworkAccessManager(this);
    }
    return m_network;
}

bool Bundles::wifiOnly() const
{
    return QSettings().value(QLatin1String(kWifiOnlyKey), true).toBool();
}

void Bundles::setWifiOnly(bool on)
{
    if (on == wifiOnly()) {
        return;
    }
    QSettings().setValue(QLatin1String(kWifiOnlyKey), on);
    emit changed();
}

bool Bundles::onWifi()
{
    if (!QNetworkInformation::instance()
        && !QNetworkInformation::loadBackendByFeatures(QNetworkInformation::Feature::TransportMedium)) {
        return true;    // unknown: no way to tell, as on most desktops
    }
    const QNetworkInformation *info = QNetworkInformation::instance();
    if (info->supports(QNetworkInformation::Feature::Metered) && info->isMetered()) {
        return false;
    }
    switch (info->transportMedium()) {
    case QNetworkInformation::TransportMedium::Cellular:
        return false;
    default:
        return true;
    }
}

// The manifest as last loaded: the list and the codes' entries also offline.
void Bundles::loadCache()
{
    QFile file(QDir(m_shelf->root()).filePath(kManifestFile));
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }
    const QJsonObject m = QJsonDocument::fromJson(file.readAll()).object();
    if (m.value(QStringLiteral("format")).toInt() != kFormat) {
        return;
    }
    m_manifest = m;
    m_loaded = QFileInfo(file).lastModified(QTimeZone::UTC);
    m_manifestState = ManifestState::Ready;
}

void Bundles::reload(Reload when)
{
    if (m_manifestState == ManifestState::Loading) {
        return;
    }
    if (when == Reload::Older && m_loaded.isValid() && m_loaded.secsTo(QDateTime::currentDateTimeUtc()) < kFreshSeconds) {
        return;
    }
    QNetworkRequest request(m_source);
    request.setTransferTimeout(kTimeoutMs);
    QNetworkReply *reply = network()->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] { received(reply); });
    m_manifestState = ManifestState::Loading;
    emit changed();
}

// Another format or no JSON (an error page) does not replace the manifest on the device.
void Bundles::received(QNetworkReply *reply)
{
    reply->deleteLater();
    const QByteArray data = reply->error() == QNetworkReply::NoError ? reply->readAll() : QByteArray();
    const QJsonObject m = QJsonDocument::fromJson(data).object();
    if (m.value(QStringLiteral("format")).toInt() != kFormat) {
        qWarning("Bundles: the manifest could not be loaded: %s", qPrintable(reply->errorString()));
        m_manifestState = ManifestState::Failed;
        emit changed();
        return;
    }
    QDir().mkpath(m_shelf->root());
    QSaveFile file(QDir(m_shelf->root()).filePath(kManifestFile));
    if (file.open(QIODevice::WriteOnly)) {
        file.write(data);
        file.commit();
    }
    m_manifest = m;
    m_loaded = QDateTime::currentDateTimeUtc();
    m_manifestState = ManifestState::Ready;
    emit changed();
}

// Only bundles whose id can name a folder (BundleShelf::validId): the id goes into paths.
QJsonObject Bundles::manifestBundle(const QString &id, Kind *kind) const
{
    if (!BundleShelf::validId(id)) {
        return {};
    }
    const std::pair<QString, Kind> lists[] = {{QStringLiteral("bundles"), Kind::Exam}, {QStringLiteral("lernpakete"), Kind::Lesson}};
    for (const auto &[key, listKind] : lists) {
        for (const QJsonValue &b : m_manifest.value(key).toArray()) {
            if (b.toObject().value(QStringLiteral("id")).toString() != id) {
                continue;
            }
            if (kind) {
                *kind = listKind;
            }
            return b.toObject();
        }
    }
    return {};
}

QVariantList Bundles::bundles() const
{
    QVariantList result;
    QJsonArray all = m_manifest.value(QStringLiteral("bundles")).toArray();
    const qsizetype exams = all.size();            // the exam bundles first, then the Lernpakete
    for (const QJsonValue &v : m_manifest.value(QStringLiteral("lernpakete")).toArray()) {
        all.append(v);
    }
    for (qsizetype i = 0; i < all.size(); ++i) {
        const QJsonObject b = all.at(i).toObject();
        const QString id = b.value(QStringLiteral("id")).toString();
        if (!BundleShelf::validId(id)) {
            continue;
        }
        const Kind kind = i < exams ? Kind::Exam : Kind::Lesson;
        const int version = b.value(QStringLiteral("version")).toInt();
        const BundleShelf::Bundle shelf = m_shelf->bundle(id);
        qint64 size = 0;
        QStringList videos;
        for (const QJsonValue &f : b.value(QStringLiteral("videos")).toArray()) {
            size += qint64(f.toObject().value(QStringLiteral("groesse")).toDouble());
            videos << f.toObject().value(QStringLiteral("video")).toString();
        }

        State state = shelf.key.isEmpty() ? State::Locked
                    : shelf.version == 0  ? State::Unlocked
                    : shelf.version < version ? State::Update
                                              : State::Installed;
        if (kind == Kind::Lesson && b.value(kContentKey).toObject().value(QStringLiteral("format")).toInt() != kContentFormat) {
            state = State::Unsupported;
        }
        if (m_failed.contains(id)) {
            state = m_failed.value(id);
        }
        double progress = 0;
        if (const auto job = m_jobs.value(id)) {
            state = State::Downloading;
            progress = job->total > 0 ? double(job->done + job->received) / double(job->total) : 0;
        }
        // The manifest's titles as the catalog's: titel_en where the English differs.
        const QString title = Catalog::language() == Catalog::Language::English && b.contains(QStringLiteral("titel_en"))
                                  ? b.value(QStringLiteral("titel_en")).toString()
                                  : b.value(QStringLiteral("titel")).toString();
        result << QVariantMap{{QStringLiteral("id"), id},
                              {QStringLiteral("uid"), id},         // the key of the page's rows (KeyedListModel)
                              {QStringLiteral("title"), title},
                              {QStringLiteral("kind"), QVariant::fromValue(kind)},
                              {QStringLiteral("version"), version},
                              {QStringLiteral("installed"), shelf.version},
                              {QStringLiteral("videos"), videos},
                              {QStringLiteral("size"), size},
                              {QStringLiteral("state"), QVariant::fromValue(state)},
                              {QStringLiteral("progress"), progress},
                              {QStringLiteral("hint"), b.value(QStringLiteral("hinweis")).toString()},
                              {QStringLiteral("code"), shelf.code.isEmpty() ? QString() : BundleCrypto::grouped(shelf.code)}};
    }
    return result;
}

int Bundles::updates() const
{
    int n = 0;
    for (const QVariant &b : bundles()) {
        n += b.toMap().value(QStringLiteral("state")).value<State>() == State::Update;
    }
    return n;
}

bool Bundles::codeValid(const QString &code) const
{
    return !BundleCrypto::normalized(code).isEmpty();
}

QString Bundles::grouped(const QString &code) const
{
    const QString n = BundleCrypto::normalized(code);
    return n.isEmpty() ? code : BundleCrypto::grouped(n);
}

void Bundles::unlock(const QString &input)
{
    const QString code = BundleCrypto::normalized(input);
    // A whole code whose check character does not fit has a typo; anything else is no code.
    if (code.isEmpty()) {
        emit unlockFailed(BundleCrypto::complete(input) ? UnlockError::Typo : UnlockError::Invalid);
        return;
    }
    if (m_manifest.isEmpty()) {
        emit unlockFailed(UnlockError::NoManifest);
        return;
    }
    const QJsonObject entry = m_manifest.value(QStringLiteral("codes")).toObject().value(BundleCrypto::lookupId(code)).toObject();
    const QString id = entry.value(QStringLiteral("bundle")).toString();
    if (entry.isEmpty() || manifestBundle(id).isEmpty()) {
        emit unlockFailed(UnlockError::Unknown);
        return;
    }

    // Argon2id takes a moment and 64 MiB: not on the thread that draws.
    const QByteArray salt = QByteArray::fromBase64(entry.value(QStringLiteral("salz")).toString().toLatin1());
    const QByteArray wrapped = QByteArray::fromBase64(entry.value(QStringLiteral("schluessel")).toString().toLatin1());
    const int passes = entry.value(QStringLiteral("t")).toInt();
    const int kibibytes = entry.value(QStringLiteral("m")).toInt();
    auto *watcher = new QFutureWatcher<QByteArray>(this);
    connect(watcher, &QFutureWatcher<QByteArray>::finished, this, [this, watcher, code, id] {
        watcher->deleteLater();
        m_unlocking = false;
        const QByteArray key = watcher->result();
        if (key.isEmpty()) {
            emit changed();
            emit unlockFailed(UnlockError::Wrong);
            return;
        }
        if (!m_shelf->unlock(id, code, key)) {
            m_error = tr("The code could not be saved on this device.");
        }
        emit changed();
        emit unlocked(id);
    });
    m_unlocking = true;
    emit changed();
    watcher->setFuture(QtConcurrent::run(&BundleCrypto::unwrapKey, code, id, salt, passes, kibibytes, wrapped));
}

void Bundles::load(const QString &id, Network network)
{
    Kind kind = Kind::Exam;
    const QJsonObject b = manifestBundle(id, &kind);
    const BundleShelf::Bundle shelf = m_shelf->bundle(id);
    if (b.isEmpty() || shelf.key.isEmpty() || m_jobs.contains(id)) {
        return;
    }
    // A content format this version does not know: the page asks for an update (State::Unsupported).
    const QJsonObject inhalt = b.value(kContentKey).toObject();
    if (kind == Kind::Lesson && inhalt.value(QStringLiteral("format")).toInt() != kContentFormat) {
        return;
    }
    if (network == Network::WifiOnly && wifiOnly() && !onWifi()) {
        m_failed.insert(id, State::Waiting);
        emit changed();
        return;
    }
    m_failed.remove(id);
    m_error.clear();

    auto job = std::make_shared<Job>();
    job->id = id;
    job->version = b.value(QStringLiteral("version")).toInt();
    job->videos = b.value(QStringLiteral("videos")).toArray();
    // The content first: a damaged one fails before the large files load.
    if (kind == Kind::Lesson) {
        QJsonObject content = inhalt;
        content.insert(kContentKey, true);
        job->videos.prepend(content);
    }
    for (const QJsonValue &f : std::as_const(job->videos)) {
        job->total += qint64(f.toObject().value(QStringLiteral("groesse")).toDouble());
    }
    // A fresh folder next to the bundle's: the loaded version stays until the new one is complete.
    QDir(m_shelf->folder(id) + QStringLiteral(".part")).removeRecursively();
    QDir().mkpath(m_shelf->folder(id) + QStringLiteral(".part"));
    m_jobs.insert(id, job);
    emit changed();
    next(*job);
}

void Bundles::next(Job &job)
{
    const QString id = job.id;
    const QString partDir = m_shelf->folder(id) + QStringLiteral(".part");

    // Every file in: the new version replaces the old one.
    if (job.videos.isEmpty()) {
        QDir(m_shelf->folder(id)).removeRecursively();
        if (!QDir().rename(partDir, m_shelf->folder(id))
            || !m_shelf->installed(id, job.version, job.files, job.cropped, job.cuts, job.content)) {
            fail(id, tr("The videos could not be saved on this device."));
            return;
        }
        m_jobs.remove(id);
        emit changed();
        emit installed(id);
        return;
    }

    const QJsonObject f = job.videos.first().toObject();
    const QString file = f.value(QStringLiteral("datei")).toString();
    const qint64 size = qint64(f.value(QStringLiteral("groesse")).toDouble());
    // Names from the manifest go into a path: only a plain file name.
    if (file.isEmpty() || file.contains(QLatin1Char('/')) || file.contains(QLatin1Char('\\')) || file.startsWith(QLatin1Char('.'))) {
        fail(id, tr("The manifest names a file that cannot be loaded."));
        return;
    }
    const QUrl url(f.value(QStringLiteral("url")).toString());
    if (!url.isValid() || url.isRelative()) {
        fail(id, tr("The manifest names a file that cannot be loaded."));
        return;
    }
    const bool isContent = f.value(kContentKey).toBool();
    job.part = std::make_unique<QFile>(QDir(partDir).filePath(isContent ? kContentFile : plainName(file, job.version)));
    if (!job.part->open(QIODevice::WriteOnly)) {
        fail(id, tr("The videos could not be saved on this device."));
        return;
    }
    job.decryptor = std::make_unique<BundleCrypto::Decryptor>(m_shelf->bundle(id).key, size, job.part.get());
    job.sha.reset();
    job.received = 0;

    QNetworkRequest request(url);
    request.setTransferTimeout(kTimeoutMs);
    QNetworkReply *reply = network()->get(request);
    job.reply = reply;
    connect(reply, &QNetworkReply::readyRead, this, [this, id, reply] {
        const auto j = m_jobs.value(id);
        if (!j || j->reply != reply) {
            return;
        }
        // An error page is no video: `finished` says what happened.
        if (reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() >= kHttpError) {
            return;
        }
        const QByteArray data = reply->readAll();
        j->sha.addData(data);
        j->received += data.size();
        if (!j->decryptor->feed(data)) {
            reply->abort();
            return;
        }
        // Progress a few times a second: each change draws the page anew.
        if (j->shown.isValid() && j->shown.elapsed() < kProgressMs) {
            return;
        }
        j->shown.start();
        emit changed();
    });
    connect(reply, &QNetworkReply::finished, this, [this, id, reply, f, isContent] {
        reply->deleteLater();
        const auto j = m_jobs.value(id);
        if (!j || j->reply != reply) {
            return;
        }
        const QByteArray rest = reply->isOpen() ? reply->readAll() : QByteArray();
        j->sha.addData(rest);
        j->received += rest.size();
        const bool fed = j->decryptor->feed(rest);
        const bool ok = reply->error() == QNetworkReply::NoError && fed && j->decryptor->finish()
                        && QString::fromLatin1(j->sha.result().toHex()) == f.value(QStringLiteral("sha256")).toString();
        j->part->close();
        if (!ok) {
            // The server keeps only the current version: the next try needs the new manifest.
            const bool gone = reply->error() == QNetworkReply::ContentNotFoundError;
            fail(id, reply->error() != QNetworkReply::NoError && reply->error() != QNetworkReply::OperationCanceledError
                         ? tr("Loading failed: %1").arg(reply->errorString())
                         : isContent ? tr("The package's content arrived damaged; load it again.")
                                     : tr("A video arrived damaged; load it again."));
            if (gone) {
                reload();
            }
            return;
        }
        if (isContent) {
            const QString why = readContent(*j);
            if (!why.isEmpty()) {
                fail(id, why);
                return;
            }
            j->done += qint64(f.value(QStringLiteral("groesse")).toDouble());
            j->received = 0;
            j->videos.removeFirst();
            next(*j);
            return;
        }
        const QString video = f.value(QStringLiteral("video")).toString();
        j->files.insert(video, QFileInfo(*j->part).fileName());
        if (f.value(QStringLiteral("beschnitten")).toBool()) {
            j->cropped << video;
        }
        j->cuts.insert(video, cutsOf(f));
        j->done += qint64(f.value(QStringLiteral("groesse")).toDouble());
        j->received = 0;
        j->videos.removeFirst();
        next(*j);
    });
}

// A Lernpaket's loaded content into job.content, and its file out of the bundle's folder. Returns
// what is wrong with it, or "".
QString Bundles::readContent(Job &job)
{
    const QString path = job.part->fileName();
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return tr("The videos could not be saved on this device.");
    }
    const QByteArray data = file.readAll();
    file.close();
    file.remove();

    QJsonParseError error;
    const QJsonObject content = QJsonDocument::fromJson(data, &error).object();
    if (error.error != QJsonParseError::NoError || content.isEmpty()) {
        return tr("The package's content arrived damaged; load it again.");
    }
    // Another package's content under this name would give it this one's techniques.
    if (content.value(QStringLiteral("id")).toString() != job.id) {
        return tr("The package's content does not belong to it.");
    }
    if (content.value(QStringLiteral("format")).toInt() != kContentFormat) {
        return tr("This package needs a newer version of Mitori.");
    }
    job.content = content;
    return {};
}

// The download stops; what was loaded before stays.
void Bundles::fail(const QString &id, const QString &why)
{
    if (const auto job = m_jobs.take(id)) {
        if (job->reply) {
            job->reply->abort();
        }
        if (job->part) {
            job->part->close();
        }
    }
    QDir(m_shelf->folder(id) + QStringLiteral(".part")).removeRecursively();
    qWarning("Bundles: %s: %s", qPrintable(id), qPrintable(why));
    m_error = why;
    m_failed.insert(id, State::Failed);
    emit changed();
}

void Bundles::cancel(const QString &id)
{
    if (!BundleShelf::validId(id)) {
        return;
    }
    const auto job = m_jobs.take(id);
    if (job && job->reply) {
        job->reply->abort();
    }
    QDir(m_shelf->folder(id) + QStringLiteral(".part")).removeRecursively();
    m_failed.remove(id);
    emit changed();
}

bool Bundles::remove(const QString &id)
{
    if (!BundleShelf::validId(id)) {
        return false;
    }
    cancel(id);
    const bool ok = m_shelf->remove(id);
    emit changed();
    return ok;
}

qint64 Bundles::freeSpace() const
{
    // The shelf's folder comes with the first bundle: until then the nearest that exists.
    QString path = QDir::cleanPath(m_shelf->root());
    while (!QFileInfo::exists(path) && QFileInfo(path).absolutePath() != path) {
        path = QFileInfo(path).absolutePath();
    }
    return QStorageInfo(path).bytesAvailable();
}
