#include "bundleshelf.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>

namespace {
const QString kShelf = QStringLiteral("shelf.json");
const QString kContentSuffix = QStringLiteral(".inhalt.json");
constexpr auto kVideoRootKey = "videos/storage";
}

BundleShelf::BundleShelf(const QString &root, const QString &videoRoot)
    : m_root(root)
    , m_videoRoot(videoRoot.isEmpty() ? root : videoRoot)
{
    load();
}

BundleShelf &BundleShelf::shared()
{
    static BundleShelf shelf(defaultRoot(), chosenVideoRoot());
    return shelf;
}

QString BundleShelf::chosenVideoRoot()
{
    return QSettings().value(QLatin1String(kVideoRootKey)).toString();
}

void BundleShelf::chooseVideoRoot(const QString &videoRoot)
{
    QSettings settings;
    if (videoRoot.isEmpty()) {
        settings.remove(QLatin1String(kVideoRootKey));
        return;
    }
    settings.setValue(QLatin1String(kVideoRootKey), videoRoot);
}

void BundleShelf::setMoving(bool moving)
{
    if (moving == m_moving) {
        return;
    }
    m_moving = moving;
    if (!moving) {
        emit notifier().changed();
    }
}

void BundleShelf::setVideoRoot(const QString &videoRoot)
{
    m_videoRoot = videoRoot.isEmpty() ? m_root : videoRoot;
    emit notifier().changed();
}

BundleShelfNotifier &BundleShelf::notifier()
{
    static BundleShelfNotifier n;
    return n;
}

QString BundleShelf::defaultRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/bundles");
}

void BundleShelf::load()
{
    QFile file(QDir(m_root).filePath(kShelf));
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }
    const QJsonObject all = QJsonDocument::fromJson(file.readAll()).object();
    for (auto it = all.begin(); it != all.end(); ++it) {
        const QJsonObject o = it.value().toObject();
        if (!validId(it.key())) {
            continue;
        }
        Bundle b;
        b.code = o.value(QStringLiteral("code")).toString();
        b.key = QByteArray::fromBase64(o.value(QStringLiteral("key")).toString().toLatin1());
        b.version = o.value(QStringLiteral("version")).toInt();
        const QJsonObject videos = o.value(QStringLiteral("videos")).toObject();
        for (auto v = videos.begin(); v != videos.end(); ++v) {
            const QJsonObject f = v.value().toObject();
            b.files.insert(v.key(), f.value(QStringLiteral("file")).toString());
            if (f.value(QStringLiteral("cropped")).toBool()) {
                b.cropped << v.key();
            }
            const QJsonObject tracks = f.value(QStringLiteral("untertitel")).toObject();
            for (auto t = tracks.begin(); t != tracks.end(); ++t) {
                b.subtitles[v.key()].insert(t.key(), t.value().toString());
            }
            const QJsonObject cuts = f.value(QStringLiteral("cuts")).toObject();
            for (auto c = cuts.begin(); c != cuts.end(); ++c) {
                const QJsonArray place = c.value().toArray();
                b.cuts[v.key()][c.key()] = {place.at(0).toDouble(), place.at(1).toDouble()};
            }
        }
        m_bundles.insert(it.key(), b);

        QFile content(contentPath(it.key()));
        if (content.open(QIODevice::ReadOnly)) {
            const QJsonObject c = QJsonDocument::fromJson(content.readAll()).object();
            if (!c.isEmpty()) {
                m_content.insert(it.key(), c);
            }
        }
    }
}

QString BundleShelf::contentPath(const QString &id) const
{
    return QDir(m_root).filePath(id + kContentSuffix);
}

// The key is kept next to the videos it opens, in the app's private data (not in a backup export).
bool BundleShelf::save() const
{
    QJsonObject all;
    for (auto it = m_bundles.cbegin(); it != m_bundles.cend(); ++it) {
        QJsonObject videos;
        for (auto f = it->files.cbegin(); f != it->files.cend(); ++f) {
            QJsonObject cuts;
            const QHash<QString, Cut> places = it->cuts.value(f.key());
            for (auto c = places.cbegin(); c != places.cend(); ++c) {
                cuts.insert(c.key(), QJsonArray{c->von, c->bis});
            }
            QJsonObject tracks;
            const QMap<QString, QString> subtitles = it->subtitles.value(f.key());
            for (auto t = subtitles.cbegin(); t != subtitles.cend(); ++t) {
                tracks.insert(t.key(), t.value());
            }
            videos.insert(f.key(), QJsonObject{{QStringLiteral("file"), f.value()},
                                               {QStringLiteral("cropped"), it->cropped.contains(f.key())},
                                               {QStringLiteral("cuts"), cuts},
                                               {QStringLiteral("untertitel"), tracks}});
        }
        all.insert(it.key(), QJsonObject{{QStringLiteral("code"), it->code},
                                         {QStringLiteral("key"), QString::fromLatin1(it->key.toBase64())},
                                         {QStringLiteral("version"), it->version},
                                         {QStringLiteral("videos"), videos}});
    }
    QDir().mkpath(m_root);
    QSaveFile file(QDir(m_root).filePath(kShelf));
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    file.write(QJsonDocument(all).toJson());
    const bool ok = file.commit();
    emit notifier().changed();
    return ok;
}

bool BundleShelf::unlock(const QString &id, const QString &code, const QByteArray &key)
{
    if (!validId(id)) {
        return false;
    }
    Bundle &b = m_bundles[id];
    b.code = code;
    b.key = key;
    return save();
}

bool BundleShelf::installed(const QString &id, int version, const QHash<QString, QString> &files, const QStringList &cropped,
                            const Cuts &cuts, const QJsonObject &content, const Subtitles &subtitles)
{
    if (!validId(id)) {
        return false;
    }

    // Before shelf.json says "installed": a lesson without its content would show no techniques.
    // Not saved, not installed: the shelf keeps naming the loaded version and its content
    // (Bundles puts its files back).
    const Bundle before = m_bundles.value(id);
    const std::optional<QJsonObject> contentBefore = m_content.contains(id) ? std::optional(m_content.value(id)) : std::nullopt;
    if (!content.isEmpty()) {
        QDir().mkpath(m_root);
        QSaveFile out(contentPath(id));
        if (!out.open(QIODevice::WriteOnly)) {
            return false;
        }
        out.write(QJsonDocument(content).toJson(QJsonDocument::Compact));
        if (!out.commit()) {
            return false;
        }
        m_content.insert(id, content);
    }
    if (m_content.contains(id)) {
        ++m_lessonRevision;
    }
    Bundle &b = m_bundles[id];
    b.version = version;
    b.files = files;
    b.cropped = cropped;
    b.cuts = cuts;
    b.subtitles = subtitles;
    if (save()) {
        return true;
    }
    m_bundles[id] = before;
    if (!content.isEmpty()) {
        restoreContent(id, contentBefore);
    }
    return false;
}

// A lesson's content as it was before a failed install: written back, or gone if there was none.
void BundleShelf::restoreContent(const QString &id, const std::optional<QJsonObject> &content)
{
    if (!content) {
        QFile::remove(contentPath(id));
        m_content.remove(id);
        return;
    }
    QSaveFile out(contentPath(id));
    if (out.open(QIODevice::WriteOnly)) {
        out.write(QJsonDocument(*content).toJson(QJsonDocument::Compact));
        out.commit();
    }
    m_content.insert(id, *content);
}

bool BundleShelf::remove(const QString &id)
{
    if (!validId(id) || !m_bundles.contains(id)) {
        return false;
    }
    QDir(folder(id)).removeRecursively();
    if (m_content.contains(id)) {
        ++m_lessonRevision;
    }
    Bundle &b = m_bundles[id];
    b.version = 0;
    b.files.clear();
    b.cropped.clear();
    b.cuts.clear();
    b.subtitles.clear();
    return save();
}

QString BundleShelf::folder(const QString &id) const
{
    Q_ASSERT(validId(id));
    return QDir(m_videoRoot).filePath(id);
}

// Lower case letters, digits and hyphens, as tools/bundle.py makes them.
bool BundleShelf::validId(const QString &id)
{
    // Anchored: "$" alone also matches before a final line break ("abc\n").
    static const QRegularExpression plain(QRegularExpression::anchoredPattern(QStringLiteral("[a-z0-9][a-z0-9-]*")));
    return plain.match(id).hasMatch();
}

QString BundleShelf::path(const QString &video) const
{
    for (auto it = m_bundles.cbegin(); it != m_bundles.cend(); ++it) {
        const QString file = it->files.value(video);
        if (it->version > 0 && !file.isEmpty()) {
            const QString p = QDir(folder(it.key())).filePath(file);
            if (QFileInfo::exists(p)) {
                return p;
            }
        }
    }
    return {};
}

bool BundleShelf::cropped(const QString &video) const
{
    for (auto it = m_bundles.cbegin(); it != m_bundles.cend(); ++it) {
        if (it->version > 0 && it->cropped.contains(video)) {
            return true;
        }
    }
    return false;
}

QMap<QString, QString> BundleShelf::subtitles(const QString &video) const
{
    for (auto it = m_bundles.cbegin(); it != m_bundles.cend(); ++it) {
        const QString file = it->files.value(video);
        if (it->version == 0 || file.isEmpty() || !QFileInfo::exists(QDir(folder(it.key())).filePath(file))) {
            continue;
        }
        QMap<QString, QString> tracks;
        const QMap<QString, QString> named = it->subtitles.value(video);
        for (auto t = named.cbegin(); t != named.cend(); ++t) {
            const QString p = QDir(folder(it.key())).filePath(t.value());
            if (QFileInfo::exists(p)) {
                tracks.insert(t.key(), p);
            }
        }
        return tracks;
    }
    return {};
}

std::optional<BundleShelf::Cut> BundleShelf::cut(const QString &video, const QString &id) const
{
    for (auto it = m_bundles.cbegin(); it != m_bundles.cend(); ++it) {
        const QString file = it->files.value(video);
        if (it->version == 0 || file.isEmpty() || !QFileInfo::exists(QDir(folder(it.key())).filePath(file))) {
            continue;
        }
        const QHash<QString, Cut> places = it->cuts.value(video);
        const auto place = places.constFind(id);
        return place == places.cend() ? std::nullopt : std::optional<Cut>(*place);
    }
    return std::nullopt;
}

qint64 BundleShelf::size() const
{
    qint64 total = 0;
    for (auto it = m_bundles.cbegin(); it != m_bundles.cend(); ++it) {
        QDirIterator files(folder(it.key()), QDir::Files);
        while (files.hasNext()) {
            total += files.nextFileInfo().size();
        }
    }
    return total;
}
