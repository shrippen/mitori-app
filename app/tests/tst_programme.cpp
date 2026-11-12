#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>

#include <algorithm>

#include "bundleshelf.h"
#include "courses.h"
#include "practicegrade.h"
#include "programme.h"
#include "searchkey.h"

namespace {

int count(const QVariantList &rows, const QString &kind)
{
    int n = 0;
    for (const QVariant &r : rows) {
        n += r.toMap().value(QStringLiteral("kind")).toString() == kind;
    }
    return n;
}

QStringList ids(const QVariantList &rows)
{
    QStringList result;
    for (const QVariant &r : rows) {
        if (r.toMap().value(QStringLiteral("kind")) == QLatin1String("entry")) {
            result << r.toMap().value(QStringLiteral("id")).toString();
        }
    }
    return result;
}

// A small discipline for the technique map: a kata without attack, one group title in kyu and dan
// grades, a variant of a combination in a later grade, an attack with and without addition, theory.
const char *const kMapCatalog = R"({"format": 1, "stand": "2026.11.0", "disziplinen": [{"id": "test", "kurzname": "Test",
  "grade": [{"id": "k5", "name": "5. Kyu"}, {"id": "k4", "name": "4. Kyu"}, {"id": "d1", "name": "1. Dan"}],
  "gruppen": [{"id": "kyu/kata", "titel": "Kata", "art": "ohne_angriff"},
              {"id": "kyu/tachi", "titel": "Tachi-waza", "jp": "立技", "art": "angriffe"},
              {"id": "dan/tachi", "titel": "Tachi-waza", "jp": "立技", "art": "angriffe"},
              {"id": "dan/theorie", "titel": "Theorie", "art": "text"}],
  "techniken": [
    {"id": "kamae", "gruppe": "kyu/kata", "grad": "k5", "angriff": null, "name": "Kamae"},
    {"id": "ikkyo-kd", "gruppe": "kyu/tachi", "grad": "k5", "name": "Ikkyo", "jp": "一教",
     "angriff": {"name": "Katate-dori", "zusatz": null, "jp": "片手取り"}},
    {"id": "irimi-kd", "gruppe": "kyu/tachi", "grad": "k5", "name": "Irimi-nage",
     "angriff": {"name": "Katate-dori", "zusatz": null}},
    {"id": "ikkyo-kd-ai", "gruppe": "kyu/tachi", "grad": "k5", "name": "Ikkyo",
     "angriff": {"name": "Katate-dori", "zusatz": "Ai-hanmi"}},
    {"id": "ikkyo-kd-ura", "gruppe": "kyu/tachi", "grad": "k4", "name": "Ikkyo", "zusatz": "ura",
     "angriff": {"name": "Katate-dori", "zusatz": null}},
    {"id": "kote-ts", "gruppe": "kyu/tachi", "grad": "k4", "name": "Kote-gaeshi",
     "angriff": {"name": "Tsuki", "zusatz": null}},
    {"id": "irimi-ts", "gruppe": "dan/tachi", "grad": "d1", "name": "Irimi-nage",
     "angriff": {"name": "Tsuki", "zusatz": null}},
    {"id": "essay", "gruppe": "dan/theorie", "grad": "d1", "name": "Essay",
     "angriff": {"name": "Schrift", "zusatz": null}}]}]})";

QVariantMap at(const QVariant &v, int i) { return v.toList().value(i).toMap(); }

// The cell of a map grid at a row and column.
QVariantMap cell(const QVariantMap &grid, int row, int column)
{
    return at(at(grid.value(QStringLiteral("rows")), row).value(QStringLiteral("cells")), column);
}

} // namespace

class TstProgramme : public QObject
{
    Q_OBJECT

    static Catalog loaded()
    {
        Catalog c;
        c.load(QStringLiteral(MITORI_DATEN_JSON));
        return c;
    }
    Programme programme{loaded()};

    // A new Courses with an empty book, and no practice grade or old grade stored.
    std::unique_ptr<Courses> emptyCourses(const QTemporaryDir &dir)
    {
        QSettings settings;
        settings.remove(QStringLiteral("practiceGrade"));
        settings.remove(QStringLiteral("programme/grade"));
        return std::make_unique<Courses>(dir.filePath(QStringLiteral("book.sqlite")), QUrl(),
                                         dir.filePath(QStringLiteral("cal.ics")), loaded());
    }

    static bool pass(Courses &courses, const QString &discipline, const QString &grade)
    {
        return courses.addGrade(discipline, grade, QStringLiteral("2024-03-01"), QString());
    }

    // The package of tests/data/bundle as Bundles leaves it on the app's shelf.
    static void installLesson()
    {
        QFile file(QStringLiteral(TEST_BUNDLE_DIR "/inhalt.json"));
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QJsonObject content = QJsonDocument::fromJson(file.readAll()).object();
        QVERIFY(BundleShelf::shared().installed(QStringLiteral("test-lesson"), 1, {}, {}, {}, content));
    }

private slots:
    void initTestCase()
    {
        QSettings().clear();
    }

    void cleanupTestCase()
    {
        QDir(BundleShelf::defaultRoot()).removeRecursively();
    }

    // The techniques of an installed Lernpaket (lern/<package>/<id>): by id, label, search and
    // suggestion after the programme's; the programme's own lists stay. A removed package keeps its
    // names (notes) but leaves the search.
    void lessonTechniques()
    {
        const QString irimi = QStringLiteral("lern/test-lesson/irimi");
        QVERIFY(programme.entry(irimi).isEmpty());
        QCOMPARE(programme.techniqueLabel(irimi), QString());
        QSignalSpy texts(&programme, &Programme::textsChanged);
        const int revision = programme.revision();
        const int before = programme.search(QStringLiteral("irimi"), 1000).size();

        installLesson();
        QCOMPARE(texts.count(), 1);
        QCOMPARE(programme.revision(), revision + 1);
        const QVariantMap e = programme.entry(irimi);
        QCOMPARE(e.value(QStringLiteral("title")).toString(), QStringLiteral("Irimi-nage"));
        QCOMPARE(e.value(QStringLiteral("discipline")).toString(), QStringLiteral("lern"));
        QCOMPARE(programme.techniqueLabel(irimi), QStringLiteral("Irimi-nage (Variante) · Shomen-uchi · Lernpaket"));
        QCOMPARE(programme.techniqueLabel(QStringLiteral("lern/test-lesson/tenkan")), QStringLiteral("Tenkan · Lernpaket"));

        const QVariantList found = programme.search(QStringLiteral("irimi"), 1000);
        QCOMPARE(found.size(), before + 1);
        const QVariantMap last = found.last().toMap();
        QCOMPARE(last.value(QStringLiteral("id")).toString(), irimi);
        QCOMPARE(last.value(QStringLiteral("disciplineName")).toString(), QStringLiteral("Lernpaket"));
        QCOMPARE(last.value(QStringLiteral("gradeName")).toString(), QString());
        QCOMPARE(last.value(QStringLiteral("groupName")).toString(), QStringLiteral("Grundtechniken"));
        // Words of the section and the addition find it too.
        QVERIFY(ids(programme.search(QStringLiteral("grundtechniken variante"))).contains(irimi));
        QVERIFY(ids(programme.suggest(QStringLiteral("Wir üben Irimi-nage und Tenkan."), 1000)).contains(irimi));
        QVERIFY(ids(programme.suggest(QStringLiteral("Wir üben Irimi-nage und Tenkan."), 1000))
                    .contains(QStringLiteral("lern/test-lesson/tenkan")));

        // The programme's lists do not have it.
        QVERIFY(!ids(programme.practiceEntries(QStringLiteral("aikido"), QStringLiteral("k5"))).contains(irimi));

        QVERIFY(BundleShelf::shared().remove(QStringLiteral("test-lesson")));
        QCOMPARE(texts.count(), 2);
        QCOMPARE(programme.search(QStringLiteral("irimi"), 1000).size(), before);
        QCOMPARE(programme.entry(irimi).value(QStringLiteral("title")).toString(), QStringLiteral("Irimi-nage"));
        QCOMPARE(programme.techniqueLabel(irimi), QStringLiteral("Irimi-nage (Variante) · Shomen-uchi · Lernpaket"));
    }

    // The programme's chips add Hon-Menkyo and Menkyo-Kaiden with what the catalog says of them,
    // not Hôshu; grades() and the other disciplines stay as they are.
    void gradeChipsShowGradesWithoutForms()
    {
        const QString toho = QStringLiteral("shinkitoho");
        const auto idsOf = [](const QVariantList &grades) {
            QStringList result;
            for (const QVariant &g : grades) {
                result << g.toMap().value(QStringLiteral("id")).toString();
            }
            return result;
        };

        const QVariantList chips = programme.gradeChips(toho);
        const QStringList withForms = idsOf(programme.grades(toho));
        const QStringList noForms{QStringLiteral("honmenkyo"), QStringLiteral("kaiden")};
        QCOMPARE(idsOf(chips), withForms + noForms);
        QVERIFY(!withForms.contains(QStringLiteral("honmenkyo")));
        QVERIFY(chips.first().toMap().value(QStringLiteral("count")).toInt() > 0);

        const QVariantMap honmenkyo = chips.at(withForms.size()).toMap();
        QCOMPARE(honmenkyo.value(QStringLiteral("count")).toInt(), 0);
        QCOMPARE(honmenkyo.value(QStringLiteral("name")).toString(), QStringLiteral("Hon-Menkyo"));
        QCOMPARE(honmenkyo.value(QStringLiteral("jp")).toString(), QStringLiteral("本免許"));
        QCOMPARE(honmenkyo.value(QStringLiteral("bedeutung")).toString(), QStringLiteral("Diplom"));
        QVERIFY(honmenkyo.value(QStringLiteral("inhalt")).toString().contains(QStringLiteral("Ko-dachi")));
        QCOMPARE(honmenkyo.value(QStringLiteral("abstand")).toString(), QStringLiteral("4 Jahre"));

        for (const QString &other : {QStringLiteral("aikido"), QStringLiteral("daitoryu")}) {
            QCOMPARE(programme.gradeChips(other), programme.grades(other));
        }
    }

    // Today's practice draws from every grade up to the given one; only that one is current.
    void practiceEntriesUpToTheGrade()
    {
        const QVariantList rows = programme.practiceEntries(QStringLiteral("aikido"), QStringLiteral("k4"));
        const int k5 = count(programme.entries(QStringLiteral("aikido"), QStringLiteral("k5")), QStringLiteral("entry"));
        const int k4 = count(programme.entries(QStringLiteral("aikido"), QStringLiteral("k4")), QStringLiteral("entry"));
        QCOMPARE(rows.size(), k5 + k4);
        QVERIFY(!rows.first().toMap().value(QStringLiteral("current")).toBool());
        QVERIFY(rows.last().toMap().value(QStringLiteral("current")).toBool());
        QCOMPARE(rows.last().toMap().value(QStringLiteral("gradeName")).toString(), QStringLiteral("4. Kyu"));
        QCOMPARE(programme.practiceEntries(QStringLiteral("aikido"), QStringLiteral("k5")).size(), k5);
    }

    // Nothing entered, nothing chosen: the first grade. Then the one after the highest passed.
    void practiceGradeFollowsPassedGrades()
    {
        const QString aikido = QStringLiteral("aikido");
        QTemporaryDir dir;
        const auto courses = emptyCourses(dir);
        PracticeGrade practice(&programme, courses.get());
        QSignalSpy changed(&practice, &PracticeGrade::changed);
        QCOMPARE(practice.grade(aikido), QStringLiteral("k5"));
        QVERIFY(!practice.manual(aikido));

        QVERIFY(pass(*courses, aikido, QStringLiteral("k5")));
        QCOMPARE(practice.grade(aikido), QStringLiteral("k4"));
        QCOMPARE(changed.size(), 1);

        // By rank, not by day; other disciplines stay.
        QVERIFY(pass(*courses, aikido, QStringLiteral("k3")));
        QCOMPARE(practice.grade(aikido), QStringLiteral("k2"));
        QCOMPARE(practice.grade(QStringLiteral("daitoryu")), QStringLiteral("k5"));

        // A note changes Courses, not the practice grade: no signal.
        changed.clear();
        const QString notebook = courses->create(QStringLiteral("Kurs"), QStringLiteral("2026-01-01"),
                                                 QStringLiteral("2026-01-01"), QString(), QString());
        QVERIFY(!notebook.isEmpty());
        QCOMPARE(changed.size(), 0);
    }

    // After the last grade with forms (next: Hon-Menkyo, then none at all) it stays on that one;
    // a grade without forms is never one.
    void practiceGradeHasForms()
    {
        const QString toho = QStringLiteral("shinkitoho");
        QTemporaryDir dir;
        const auto courses = emptyCourses(dir);
        PracticeGrade practice(&programme, courses.get());
        const QVariantList grades = programme.grades(toho);
        const QString last = grades.last().toMap().value(QStringLiteral("id")).toString();

        QVERIFY(pass(*courses, toho, last));
        QCOMPARE(courses->nextGrade(toho), QStringLiteral("honmenkyo"));
        QCOMPARE(practice.grade(toho), last);

        QVERIFY(pass(*courses, toho, QStringLiteral("kaiden")));
        QCOMPARE(courses->nextGrade(toho), QString());
        QCOMPARE(practice.grade(toho), last);

        practice.setGrade(toho, QStringLiteral("kaiden"));
        QCOMPARE(practice.grade(toho), last);
        practice.setGrade(toho, QStringLiteral("nonsense"));
        QCOMPARE(practice.grade(toho), last);
        QVERIFY(!practice.manual(toho));
    }

    // A choice holds, also below the suggestion and across a new start.
    void practiceGradeByHand()
    {
        const QString aikido = QStringLiteral("aikido");
        QTemporaryDir dir;
        const auto courses = emptyCourses(dir);
        QVERIFY(pass(*courses, aikido, QStringLiteral("k4")));
        PracticeGrade practice(&programme, courses.get());
        QSignalSpy changed(&practice, &PracticeGrade::changed);
        QCOMPARE(practice.grade(aikido), QStringLiteral("k3"));

        practice.setGrade(aikido, QStringLiteral("k5"));
        QCOMPARE(practice.grade(aikido), QStringLiteral("k5"));
        QVERIFY(practice.manual(aikido));
        QCOMPARE(changed.size(), 1);
        PracticeGrade restarted(&programme, courses.get());
        QCOMPARE(restarted.grade(aikido), QStringLiteral("k5"));

        // The suggested grade again: follows "My grades" from here on.
        practice.setGrade(aikido, QStringLiteral("k3"));
        QVERIFY(!practice.manual(aikido));
        QCOMPARE(changed.size(), 2);
        QVERIFY(pass(*courses, aikido, QStringLiteral("k3")));
        QCOMPARE(practice.grade(aikido), QStringLiteral("k2"));
    }

    // A passed grade moves a choice forward unless it is further already.
    void practiceGradeAfterPassing()
    {
        const QString aikido = QStringLiteral("aikido");
        QTemporaryDir dir;
        const auto courses = emptyCourses(dir);
        QVERIFY(pass(*courses, aikido, QStringLiteral("k4")));
        PracticeGrade practice(&programme, courses.get());

        // Behind: moves to the new suggestion.
        practice.setGrade(aikido, QStringLiteral("k5"));
        QVERIFY(pass(*courses, aikido, QStringLiteral("k3")));
        QCOMPARE(practice.grade(aikido), QStringLiteral("k2"));
        QVERIFY(!practice.manual(aikido));

        // Further: stays, until the suggestion passes it.
        practice.setGrade(aikido, QStringLiteral("k1"));
        QVERIFY(pass(*courses, aikido, QStringLiteral("k2")));
        QCOMPARE(practice.grade(aikido), QStringLiteral("k1"));
        QVERIFY(practice.manual(aikido));
        QVERIFY(pass(*courses, aikido, QStringLiteral("k1")));
        QCOMPARE(practice.grade(aikido), courses->nextGrade(aikido));
        QVERIFY(!practice.manual(aikido));
    }

    // A passed grade taken back gives the choice back.
    void practiceGradeAfterRemoving()
    {
        const QString aikido = QStringLiteral("aikido");
        QTemporaryDir dir;
        const auto courses = emptyCourses(dir);
        QVERIFY(pass(*courses, aikido, QStringLiteral("k5")));
        PracticeGrade practice(&programme, courses.get());
        practice.setGrade(aikido, QStringLiteral("k5"));

        QVERIFY(pass(*courses, aikido, QStringLiteral("k4")));
        QCOMPARE(practice.grade(aikido), QStringLiteral("k3"));
        const QVariantList grades = courses->grades();
        const auto k4 = std::find_if(grades.cbegin(), grades.cend(), [](const QVariant &g) {
            return g.toMap().value(QStringLiteral("grade")) == QLatin1String("k4");
        });
        QVERIFY(courses->removeGrade(k4->toMap().value(QStringLiteral("uid")).toString()));
        QCOMPARE(practice.grade(aikido), QStringLiteral("k5"));
    }

    // The one old grade becomes the choice once: nothing moves on the update, a later passed
    // grade counts. A value without forms goes.
    void practiceGradeMigrates()
    {
        const QString aikido = QStringLiteral("aikido");
        const QString toho = QStringLiteral("shinkitoho");
        const QString oldAikido = QStringLiteral("programme/grade/") + aikido;
        const QString oldToho = QStringLiteral("programme/grade/") + toho;
        QTemporaryDir dir;
        const auto courses = emptyCourses(dir);
        QVERIFY(pass(*courses, aikido, QStringLiteral("k4")));
        QSettings().setValue(oldAikido, QStringLiteral("k5"));
        QSettings().setValue(oldToho, QStringLiteral("kaiden"));

        PracticeGrade practice(&programme, courses.get());
        QCOMPARE(practice.grade(aikido), QStringLiteral("k5"));
        QVERIFY(practice.manual(aikido));
        QVERIFY(!QSettings().contains(oldAikido));
        QVERIFY(!QSettings().contains(oldToho));
        QCOMPARE(practice.grade(toho), programme.grades(toho).first().toMap().value(QStringLiteral("id")).toString());

        // Once: a choice made after it stays.
        practice.setGrade(aikido, QStringLiteral("k1"));
        PracticeGrade restarted(&programme, courses.get());
        QCOMPARE(restarted.grade(aikido), QStringLiteral("k1"));

        practice.setGrade(aikido, QStringLiteral("k5"));
        QVERIFY(pass(*courses, aikido, QStringLiteral("k3")));
        QCOMPARE(practice.grade(aikido), QStringLiteral("k2"));
    }

    // What a text names: however it is written, whole words only, the attack narrows it.
    void suggestFromText()
    {
        const auto first = [&](const QString &text) {
            return programme.suggest(text).value(0).toMap().value(QStringLiteral("title")).toString();
        };
        // Hyphens, spaces, case, punctuation; the name in a German sentence.
        for (const QString &text : {QStringLiteral("Heute viel Shiho-nage."), QStringLiteral("shiho nage!"),
                                    QStringLiteral("(SHIHONAGE), danach Pause")}) {
            QCOMPARE(first(text), QStringLiteral("Shiho-nage"));
        }
        // Long vowels as the data has them: Shihô-nage (Daitoryu), Ô-dachi, Ikkajô.
        const auto hasId = [&](const QString &text, const QString &id) {
            const QVariantList rows = programme.suggest(text, 200);
            return std::any_of(rows.cbegin(), rows.cend(), [&](const QVariant &r) { return r.toMap().value(QStringLiteral("id")) == id; });
        };
        const auto hasTitle = [&](const QString &text, const QString &title) {
            const QVariantList rows = programme.suggest(text, 200);
            return std::any_of(rows.cbegin(), rows.cend(), [&](const QVariant &r) { return r.toMap().value(QStringLiteral("title")) == title; });
        };
        for (const QString &text : {QStringLiteral("Ikkajo kime osae"), QStringLiteral("Ikkajô-kime-osae"), QStringLiteral("IKKAJŌ KIME OSAE")}) {
            QVERIFY2(hasTitle(text, QStringLiteral("Ikkajô-kime-osae")), qPrintable(text));
        }
        QVERIFY(hasTitle(QStringLiteral("Shiho-nage"), QStringLiteral("Shihô-nage")));
        for (const QString &text : {QStringLiteral("Ô-dachi 5 geübt"), QStringLiteral("O-dachi 5"), QStringLiteral("odachi Nr. 5"),
                                    QStringLiteral("Tsukikomi Seigan-yaburi"), QStringLiteral("Gohon-me")}) {
            QCOMPARE(programme.suggest(text).value(0).toMap().value(QStringLiteral("id")).toString(),
                     QStringLiteral("shinkitoho/odachi/5"));
        }
        QCOMPARE(programme.suggest(QStringLiteral("Ô-dachi 5")).size(), 1);
        // "O-dachi" alone: the forms, in order.
        QCOMPARE(programme.suggest(QStringLiteral("O-dachi")).value(0).toMap().value(QStringLiteral("id")).toString(),
                 QStringLiteral("shinkitoho/odachi/1"));
        // German umlauts: Kamae-Übung, however typed.
        for (const QString &text : {QStringLiteral("Kamae-Übung"), QStringLiteral("kamae übung"), QStringLiteral("KAMAE-UBUNG")}) {
            QVERIFY2(hasId(text, QStringLiteral("shinkitoho/kamae")), qPrintable(text));
        }
        // Japanese, with or without okurigana.
        QVERIFY(hasTitle(QStringLiteral("四方投げです"), QStringLiteral("Shiho-nage")));

        // Not inside a word, not an attack alone, not without a name; a German word stays one.
        QVERIFY(programme.suggest(QStringLiteral("Shihonagen")).isEmpty());
        QVERIFY(programme.suggest(QStringLiteral("Rikkyo")).isEmpty());
        QVERIFY(programme.suggest(QStringLiteral("nur Katate-dori heute")).isEmpty());
        QVERIFY(programme.suggest(QStringLiteral("Fußstellung beim Tenkan in der Mitte")).isEmpty());
        QVERIFY(programme.suggest(QString()).isEmpty());

        // The attack comes first: every row before the first without it has it.
        const QVariantList both = programme.suggest(QStringLiteral("Ikkyo aus Katate-dori"), 40);
        QVERIFY(both.size() > 2);
        QCOMPARE(both.first().toMap().value(QStringLiteral("title")).toString(), QStringLiteral("Ikkyo"));
        QVERIFY(both.first().toMap().value(QStringLiteral("attack")).toString().endsWith(QStringLiteral("katate-dori")));
        QVERIFY(std::any_of(both.cbegin(), both.cend(), [](const QVariant &r) {
            return !r.toMap().value(QStringLiteral("attack")).toString().endsWith(QStringLiteral("katate-dori"));
        }));
        // The whole attack before one that only ends the same.
        QCOMPARE(programme.suggest(QStringLiteral("Ikkyo aus Ryote-katate-dori")).first().toMap().value(QStringLiteral("attack")).toString(),
                 QStringLiteral("Ryote-katate-dori"));

        // Two names take turns: 26 Ikkyo leave room for Kote-gaeshi.
        const QVariantList two = programme.suggest(QStringLiteral("Ikkyo, dann Kote-gaeshi"), 4);
        QCOMPARE(two.size(), 4);
        QSet<QString> titles;
        for (const QVariant &r : two) {
            titles.insert(r.toMap().value(QStringLiteral("title")).toString());
        }
        QVERIFY(titles.contains(QStringLiteral("Ikkyo")) && titles.contains(QStringLiteral("Kote-gaeshi")));

        // With the attack too: "Ô-dachi 5" is not pushed out by Shiho-nage from Katate-dori.
        const QVariantList mixed = programme.suggest(QStringLiteral("Heute Ô-dachi 5 und Shiho-nage aus Katate-dori"));
        QVERIFY(std::any_of(mixed.cbegin(), mixed.cend(), [](const QVariant &r) {
            return r.toMap().value(QStringLiteral("id")) == QStringLiteral("shinkitoho/odachi/5");
        }));

        // The discipline chosen last comes first where both have the name.
        const QString before = programme.discipline();
        programme.setDiscipline(QStringLiteral("daitoryu"));
        QCOMPARE(programme.suggest(QStringLiteral("Kote-gaeshi")).first().toMap().value(QStringLiteral("discipline")).toString(),
                 QStringLiteral("daitoryu"));
        programme.setDiscipline(QStringLiteral("aikido"));
        QCOMPARE(programme.suggest(QStringLiteral("Kote-gaeshi")).first().toMap().value(QStringLiteral("discipline")).toString(),
                 QStringLiteral("aikido"));
        programme.setDiscipline(before);
    }

    // The longest whole name wins: a part of it is no other technique named.
    void suggestLongestName()
    {
        const auto titles = [&](const QString &text) {
            QStringList list;
            for (const QVariant &r : programme.suggest(text, 200)) {
                list << r.toMap().value(QStringLiteral("title")).toString();
            }
            return list;
        };
        const QStringList uchi = titles(QStringLiteral("Uchi-kaiten-nage"));
        QVERIFY(!uchi.isEmpty());
        QCOMPARE(uchi.first(), QStringLiteral("Uchi-kaiten-nage"));
        QVERIFY2(!uchi.contains(QStringLiteral("Kaiten-nage")), qPrintable(uchi.join(u',')));

        const QStringList tenchi = titles(QStringLiteral("Tenchi-nage"));
        QCOMPARE(tenchi.first(), QStringLiteral("Tenchi-nage"));
        QVERIFY2(!tenchi.contains(QStringLiteral("Tenchi")), qPrintable(tenchi.join(u',')));

        const QStringList both = titles(QStringLiteral("Ikkyo-shiho-nage"));
        QCOMPARE(both.first(), QStringLiteral("Ikkyo-shiho-nage"));
        QVERIFY2(!both.contains(QStringLiteral("Ikkyo")) && !both.contains(QStringLiteral("Shiho-nage")), qPrintable(both.join(u',')));

        // Named apart, each counts.
        const QStringList apart = titles(QStringLiteral("Kaiten-nage, dann Uchi-kaiten-nage"));
        QVERIFY(apart.contains(QStringLiteral("Kaiten-nage")) && apart.contains(QStringLiteral("Uchi-kaiten-nage")));

        // The attack named in full first, not the one its end spells.
        QCOMPARE(programme.suggest(QStringLiteral("Shiho-nage aus Ryote-ryote-dori")).first().toMap().value(QStringLiteral("attack")).toString(),
                 QStringLiteral("Ryote-ryote-dori"));
    }

    // A list is no name: punctuation, a line break or a dash between spaces ends a run of words;
    // a hyphen or a space still joins.
    void suggestAcrossPunctuation()
    {
        const auto titles = [&](const QString &text) {
            QStringList list;
            for (const QVariant &r : programme.suggest(text, 200)) {
                list << r.toMap().value(QStringLiteral("title")).toString();
            }
            return list;
        };
        const QString ikkyo = QStringLiteral("Ikkyo");
        const QString shiho = QStringLiteral("Shiho-nage");
        const QString joined = QStringLiteral("Ikkyo-shiho-nage");
        for (const QString &text : {QStringLiteral("Ikkyo, Shiho-nage"), QStringLiteral("Ikkyo. Shiho-nage."),
                                    QStringLiteral("Ikkyo; Shiho-nage"), QStringLiteral("Ikkyo\nShiho-nage"),
                                    QStringLiteral("Ikkyo – Shiho-nage"), QStringLiteral("Ikkyo - Shiho-nage"),
                                    QStringLiteral("(Ikkyo) Shiho-nage")}) {
            const QStringList list = titles(text);
            QVERIFY2(list.contains(ikkyo) && list.contains(shiho), qPrintable(text + u": " + list.join(u',')));
            QVERIFY2(!list.contains(joined), qPrintable(text + u": " + list.join(u',')));
        }
        const QStringList three = titles(QStringLiteral("Ikkyo. Shiho-nage. Kote-gaeshi."));
        QVERIFY2(three.contains(ikkyo) && three.contains(shiho) && three.contains(QStringLiteral("Kote-gaeshi")), qPrintable(three.join(u',')));
        QVERIFY2(!three.contains(joined), qPrintable(three.join(u',')));

        // Hyphens and spaces join.
        for (const QString &text : {QStringLiteral("Ikkyo-shiho-nage"), QStringLiteral("Ikkyo shiho nage"), QStringLiteral("Ikkyoshihonage.")}) {
            const QStringList list = titles(text);
            QVERIFY2(!list.isEmpty() && list.first() == joined, qPrintable(text + u": " + list.join(u',')));
            QVERIFY2(!list.contains(ikkyo) && !list.contains(shiho), qPrintable(text + u": " + list.join(u',')));
        }

        // A point before a number is no end: "Nr. 5".
        QCOMPARE(programme.suggest(QStringLiteral("Ô-dachi Nr. 5")).size(), 1);

        // Digits do not join: "1-3" is not form 13; "13" is.
        const auto formIds = [&](const QString &text) {
            QStringList list;
            for (const QVariant &r : programme.suggest(text, 200)) {
                list << r.toMap().value(QStringLiteral("id")).toString();
            }
            return list;
        };
        const QString thirteen = QStringLiteral("shinkitoho/odachi/13");
        for (const QString &text : {QStringLiteral("Ô-dachi 1-3"), QStringLiteral("Ô-dachi 1–3"), QStringLiteral("Ô-dachi 1 3")}) {
            QVERIFY2(!formIds(text).contains(thirteen), qPrintable(text + u": " + formIds(text).join(u',')));
        }
        QCOMPARE(formIds(QStringLiteral("Ô-dachi 13")), QStringList{thirteen});

        // A name with punctuation of its own names itself, and its first part is not named then.
        const QString slashed = QStringLiteral("Sankajô-kime-osae / -nage");
        const QString part = QStringLiteral("Sankajô-kime-osae");
        QCOMPARE(titles(slashed).value(0), slashed);
        QVERIFY2(!titles(slashed).contains(part), qPrintable(titles(slashed).join(u',')));
        QCOMPARE(titles(part).value(0), part);
        QCOMPARE(titles(QStringLiteral("Sankajo-kime-osae/-nage")).value(0), slashed);

        // Other punctuation at that place parts it: "Nage" here is the one who throws.
        for (const QString &text : {QStringLiteral("Sankajô-kime-osae. Nage bleibt tief."), QStringLiteral("Sankajô-kime-osae\nNage"),
                                    QStringLiteral("Sankajô-kime-osae, nage")}) {
            const QStringList list = titles(text);
            QVERIFY2(!list.contains(slashed), qPrintable(text + u": " + list.join(u',')));
            QVERIFY2(list.count(part) > 1, qPrintable(text + u": " + list.join(u',')));
        }
    }

    // Those left out make room: the next ones move up.
    void suggestWithout()
    {
        const QString text = QStringLiteral("Ikkyo, Nikyo, Sankyo, Yonkyo, Gokyo, Shiho-nage, Irimi-nage, Kote-gaeshi, Kaiten-nage, Tenchi-nage");
        const QVariantList first = programme.suggest(text);
        QCOMPARE(first.size(), 8);
        const QStringList firstIds = [&] {
            QStringList list;
            for (const QVariant &r : first) {
                list << r.toMap().value(QStringLiteral("id")).toString();
            }
            return list;
        }();
        const QVariantList next = programme.suggest(text, 8, firstIds);
        QCOMPARE(next.size(), 8);
        for (const QVariant &r : next) {
            QVERIFY(!firstIds.contains(r.toMap().value(QStringLiteral("id")).toString()));
        }

        // A form linked leaves "Ô-dachi 5" empty, not the group's other forms.
        QVERIFY(programme.suggest(QStringLiteral("Ô-dachi 5"), 8, {QStringLiteral("shinkitoho/odachi/5")}).isEmpty());
    }

    void techniqueLabel()
    {
        QCOMPARE(programme.techniqueLabel(QStringLiteral("gibt/es/nicht")), QString());
        const QString form = programme.techniqueLabel(QStringLiteral("shinkitoho/odachi/5"));
        QVERIFY2(form.startsWith(QStringLiteral("5 · Gohon-me · Tsukikomi Seigan-yaburi")), qPrintable(form));
        QVERIFY2(form.endsWith(QStringLiteral(" · Shinki Toho Shoden")), qPrintable(form));
        const QVariantList rows = programme.search(QStringLiteral("ikkyo katate"), 1);
        const QString label = programme.techniqueLabel(rows.first().toMap().value(QStringLiteral("id")).toString());
        QVERIFY2(label.startsWith(QStringLiteral("Ikkyo")), qPrintable(label));
        QVERIFY2(label.contains(QStringLiteral("katate-dori")), qPrintable(label));
        QVERIFY2(label.contains(QStringLiteral(" · Aikido ")), qPrintable(label));
    }

    // A glossary word names a technique only as a whole word; hyphenated parts are words.
    void techniquesNamedByWholeWord()
    {
        QVERIFY2(programme.techniquesNamed(QStringLiteral("Ago")).isEmpty(), "Ago is no part of a name");
        QVERIFY(programme.techniquesNamed(QStringLiteral("Ikk")).isEmpty());

        const QVariantList kote = programme.techniquesNamed(QStringLiteral("Kote"));
        QVERIFY(!kote.isEmpty());
        for (const QVariant &r : kote) {
            const QString title = r.toMap().value(QStringLiteral("title")).toString();
            const QString attack = r.toMap().value(QStringLiteral("attack")).toString();
            QVERIFY2(title.contains(QStringLiteral("Kote"), Qt::CaseInsensitive)
                     || attack.contains(QStringLiteral("Kote"), Qt::CaseInsensitive), qPrintable(title));
        }
        QVERIFY(programme.techniquesNamed(QStringLiteral("Kote-gaeshi")).size() > 0);
        QVERIFY(programme.techniquesNamed(QStringLiteral("Kote"), 3).size() <= 3);
        // The attack counts: Katate-dori is a whole name, Kat a word of none.
        QVERIFY(!programme.techniquesNamed(QStringLiteral("Katate-dori")).isEmpty());
        QVERIFY(programme.techniquesNamed(QStringLiteral("Kat")).isEmpty());
    }

    // Hyphens and spaces do not matter, and no hit is cut off by a small default.
    void techniquesNamedIgnoreHyphens()
    {
        const auto ids = [](const QVariantList &rows) {
            QStringList out;
            for (const QVariant &r : rows) {
                out << r.toMap().value(QStringLiteral("id")).toString();
            }
            out.sort();
            return out;
        };
        const QStringList pairs[] = {{QStringLiteral("Kesagake"), QStringLiteral("Kesa-gake")},
                                     {QStringLiteral("Fukiage"), QStringLiteral("Fuki-age")},
                                     {QStringLiteral("Kiriotoshi"), QStringLiteral("Kiri-otoshi")}};
        for (const QStringList &pair : pairs) {
            const QStringList joined = ids(programme.techniquesNamed(pair.at(0), 1000));
            QVERIFY2(!joined.isEmpty(), qPrintable(pair.at(0)));
            QCOMPARE(joined, ids(programme.techniquesNamed(pair.at(1), 1000)));
        }
        // Still whole words: a part of a word is none.
        QVERIFY(programme.techniquesNamed(QStringLiteral("Kesagak")).isEmpty());

        // Every discipline that has it (Aikido, Daitoryu, Shinki Toho).
        QSet<QString> disciplines;
        const QVariantList kiri = programme.techniquesNamed(QStringLiteral("Kiri-otoshi"), 1000);
        for (const QVariant &r : kiri) {
            disciplines << r.toMap().value(QStringLiteral("discipline")).toString();
        }
        QVERIFY2(kiri.size() >= 10 && disciplines.size() >= 2, qPrintable(QString::number(kiri.size())));
    }

    // Search across disciplines: every word must match; case, accents and hyphens do not matter.
    void searchFindsTechniques()
    {
        const QVariantList ikkyo = programme.search(QStringLiteral("ikkyo"));
        QVERIFY(ikkyo.size() > 5);
        const QVariantMap first = ikkyo.first().toMap();
        QCOMPARE(first.value(QStringLiteral("discipline")).toString(), QStringLiteral("aikido"));
        QVERIFY(!first.value(QStringLiteral("gradeName")).toString().isEmpty());
        QVERIFY(!first.value(QStringLiteral("disciplineName")).toString().isEmpty());
        QVERIFY(!first.value(QStringLiteral("groupName")).toString().isEmpty());
        // Two words narrow it down; the order of the words does not matter.
        const QVariantList narrow = programme.search(QStringLiteral("shomen IKKYO"));
        QVERIFY(!narrow.isEmpty() && narrow.size() < ikkyo.size());
        QCOMPARE(programme.search(QStringLiteral("ikkyo shomen")).size(), narrow.size());
        // Hyphens and accents: "shiho nage" finds Shiho-nage, "kote gaeshi" Kote-gaeshi.
        QVERIFY(!programme.search(QStringLiteral("shiho nage")).isEmpty());
        QVERIFY(!programme.search(QStringLiteral("KOTE-GAESHI")).isEmpty());
        // Japanese.
        QVERIFY(!programme.search(QStringLiteral("一教")).isEmpty());
        // Without the hyphen or spaces, and Japanese with or without okurigana, find the same.
        const QVariantList joined = programme.search(QStringLiteral("shihonage"));
        QVERIFY(!joined.isEmpty());
        QCOMPARE(joined.first().toMap().value(QStringLiteral("title")).toString(), QStringLiteral("Shiho-nage"));
        // While typing, a joined word may end inside a hyphenated name.
        QVERIFY(!programme.search(QStringLiteral("shihon")).isEmpty());
        QVERIFY(!programme.search(QStringLiteral("kiriotoshi")).isEmpty());
        QCOMPARE(programme.search(QStringLiteral("kiriotoshi"), 1000).size(),
                 programme.search(QStringLiteral("kiri otoshi"), 1000).size());
        // A hyphenated word also matches when its parts are in different fields, each from the
        // start of a word ("ai" not in Kaiten-nage: ai-hanmi finds no Gyaku-hanmi).
        QVERIFY(!programme.search(QStringLiteral("ikkyo-irimi")).isEmpty());
        QCOMPARE(programme.search(QStringLiteral("ikkyo-irimi"), 1000).size(),
                 programme.search(QStringLiteral("ikkyo irimi"), 1000).size());
        const QVariantList ai = programme.search(QStringLiteral("ai-hanmi"), 1000);
        QVERIFY(!ai.isEmpty());
        for (const QVariant &r : ai) {
            QVERIFY2(!searchKey(r.toMap().value(QStringLiteral("attackExtra")).toString()).contains(u"gyaku"),
                     qPrintable(r.toMap().value(QStringLiteral("title")).toString()));
        }
        // Other dashes separate as a hyphen does (en dash in "Ô-dachi 33–43", U+2010, minus).
        QCOMPARE(searchKey(QStringLiteral("Ô-dachi 33–43")), QStringLiteral("o dachi 33 43"));
        QVERIFY(!programme.search(QStringLiteral("dachi 33 43")).isEmpty());
        QCOMPARE(programme.search(QStringLiteral("ikkyo‐irimi"), 1000).size(),
                 programme.search(QStringLiteral("ikkyo-irimi"), 1000).size());
        QCOMPARE(programme.search(QStringLiteral("ikkyo−irimi"), 1000).size(),
                 programme.search(QStringLiteral("ikkyo-irimi"), 1000).size());
        // Apostrophes vanish (San'nin-gake as sannin), brackets and ・ separate.
        QVERIFY(!programme.search(QStringLiteral("sannin")).isEmpty());
        QVERIFY(!programme.search(QStringLiteral("rechterfuss")).isEmpty());
        QVERIFY(!programme.search(QStringLiteral("片手取り合半身")).isEmpty());
        // Separators: emoji and dashes as spaces, ´ as an apostrophe, a decimal point stays.
        QCOMPARE(searchKey(QStringLiteral("Kote gaeshi🙂―gut")), QStringLiteral("kote gaeshi gut"));
        QCOMPARE(searchKey(QStringLiteral("San´nin ⸺ 3,5 Min. am 12.03.")), QStringLiteral("sannin 3,5 min am 12.03"));
        // Variation selectors of emoji vanish and a keycap separates, so the emoji still ends a word;
        // a full-width apostrophe is an apostrophe.
        QCOMPARE(searchKey(QStringLiteral("❤️Sumi otoshi 1️⃣Kote")), QStringLiteral("sumi otoshi 1 kote"));
        QCOMPARE(searchKey(QStringLiteral("San＇nin")), QStringLiteral("sannin"));
        // Okurigana also go beside a kanji beyond the BMP.
        QVERIFY(SearchText(QStringLiteral("𠮟り方")).matches(searchWords(QStringLiteral("𠮟る方"))));
        // Kana keep their dakuten: が is not か.
        QCOMPARE(searchKey(QStringLiteral("ガ")), QStringLiteral("ガ"));
        // Full-width Latin from a Japanese keyboard folds.
        QVERIFY(!programme.search(QStringLiteral("ikkyo")).isEmpty());
        QCOMPARE(programme.search(QStringLiteral("ｉｋｋｙｏ"), 1000).size(), programme.search(QStringLiteral("ikkyo"), 1000).size());
        QVERIFY(!programme.search(QStringLiteral("切り落し")).isEmpty());
        QCOMPARE(programme.search(QStringLiteral("切り落とし"), 1000).size(),
                 programme.search(QStringLiteral("切り落し"), 1000).size());
        // The attack's addition and Japanese, and the group, are searched too; rows carry them.
        const QVariantList gyaku = programme.search(QStringLiteral("gyaku hanmi"));
        QVERIFY(!gyaku.isEmpty());
        QVERIFY(searchKey(gyaku.first().toMap().value(QStringLiteral("attackExtra")).toString()).contains(u"gyaku"));
        QVERIFY(!programme.search(QStringLiteral("ai-hanmi")).isEmpty());
        QVERIFY(!programme.search(QStringLiteral("片手取り")).isEmpty());
        QVERIFY(!programme.search(QStringLiteral("ukemi")).isEmpty());
        // No duplicates, a limit, nothing for blanks.
        QStringList seen;
        for (const QVariant &r : ikkyo) {
            const QString id = r.toMap().value(QStringLiteral("id")).toString();
            QVERIFY(!seen.contains(id));
            seen << id;
        }
        QCOMPARE(programme.search(QStringLiteral("ikkyo"), 3).size(), 3);
        QVERIFY(programme.search(QStringLiteral("   ")).isEmpty());
        QVERIFY(programme.search(QStringLiteral("zzzzqqq")).isEmpty());
    }

    void selectionIsKept()
    {
        QCOMPARE(programme.discipline(), QStringLiteral("aikido"));
        programme.setDiscipline(QStringLiteral("daitoryu"));
        Programme other{loaded()};
        QCOMPARE(other.discipline(), QStringLiteral("daitoryu"));
        programme.setDiscipline(QStringLiteral("nonsense"));
        QCOMPARE(other.discipline(), QStringLiteral("daitoryu"));
    }

    void aikidoGradeStartsWithItsFirstGroup()
    {
        const QVariantList rows = programme.entries(QStringLiteral("aikido"), QStringLiteral("k5"));
        QCOMPARE(count(rows, QStringLiteral("entry")), 20);
        QCOMPARE(rows.first().toMap().value(QStringLiteral("kind")).toString(), QStringLiteral("group"));
        QCOMPARE(rows.first().toMap().value(QStringLiteral("title")).toString(), QStringLiteral("Kata"));
    }

    void attackHeadingOnlyWhenTheAttackChanges()
    {
        const QVariantList rows = programme.entries(QStringLiteral("aikido"), QStringLiteral("k5"));
        QString last;
        for (const QVariant &r : rows) {
            const QVariantMap map = r.toMap();
            if (map.value(QStringLiteral("kind")) == QLatin1String("attack")) {
                const QString key = map.value(QStringLiteral("title")).toString() + map.value(QStringLiteral("extra")).toString();
                QVERIFY2(key != last, qPrintable(key));
                last = key;
            } else if (map.value(QStringLiteral("kind")) == QLatin1String("group")) {
                last.clear();
            }
        }
        QVERIFY(count(rows, QStringLiteral("attack")) > 0);
    }

    void everyEntryOnce()
    {
        for (const QVariant &d : programme.disciplines()) {
            const QString discipline = d.toMap().value(QStringLiteral("id")).toString();
            QStringList all;
            for (const QVariant &g : programme.grades(discipline)) {
                all << ids(programme.entries(discipline, g.toMap().value(QStringLiteral("id")).toString()));
            }
            QCOMPARE(QSet<QString>(all.begin(), all.end()).size(), all.size());
        }
    }

    void shinkiTohoGradesShowTheirOwnForms()
    {
        const QVariantList shoden = programme.entries(QStringLiteral("shinkitoho"), QStringLiteral("shoden"));
        QCOMPARE(count(shoden, QStringLiteral("entry")), 3 + 1 + 1 + 11);
        QCOMPARE(count(shoden, QStringLiteral("info")), 1);
        const QStringList chuden = ids(programme.entries(QStringLiteral("shinkitoho"), QStringLiteral("chuden")));
        QCOMPARE(chuden.size(), 10);
        QCOMPARE(chuden.first(), QStringLiteral("shinkitoho/odachi/12"));
    }

    // The Kamae exercise is one entry (one flow); its 26 positions are its steps, Seigan twice.
    void kamaeIsOneEntry()
    {
        const QStringList shoden = ids(programme.entries(QStringLiteral("shinkitoho"), QStringLiteral("shoden")));
        QCOMPARE(shoden.filter(QStringLiteral("shinkitoho/kamae")), QStringList{QStringLiteral("shinkitoho/kamae")});
        const QVariantMap kamae = programme.entry(QStringLiteral("shinkitoho/kamae"));
        QCOMPARE(kamae.value(QStringLiteral("title")).toString(), QStringLiteral("Kamae-Übung"));
        QCOMPARE(kamae.value(QStringLiteral("jp")).toString(), QStringLiteral("構"));
        QVERIFY(kamae.value(QStringLiteral("video")).isValid());
        QVERIFY(kamae.value(QStringLiteral("comment")).isValid());
        const QVariantList steps = kamae.value(QStringLiteral("steps")).toList();
        QCOMPARE(steps.size(), 26);
        QCOMPARE(steps.first().toMap().value(QStringLiteral("title")).toString(), QStringLiteral("Rei"));
        QCOMPARE(steps.at(2).toMap().value(QStringLiteral("title")).toString(), QStringLiteral("Seigan"));
        QCOMPARE(steps.at(11).toMap().value(QStringLiteral("title")).toString(), QStringLiteral("Seigan"));
        QCOMPARE(steps.at(2).toMap().value(QStringLiteral("jp")).toString(), QStringLiteral("正眼"));
        QVERIFY(programme.entry(QStringLiteral("shinkitoho/kamae/1")).isEmpty());
        QVERIFY(programme.entry(QStringLiteral("shinkitoho/odachi/1")).value(QStringLiteral("steps")).toList().isEmpty());
        // Today's practice and the search hold it once; a position finds it.
        QCOMPARE(ids(programme.practiceEntries(QStringLiteral("shinkitoho"), QStringLiteral("shoden"))).count(QStringLiteral("shinkitoho/kamae")), 1);
        QVERIFY(ids(programme.search(QStringLiteral("jodan ura gasumi"))).contains(QStringLiteral("shinkitoho/kamae")));
        QVERIFY(ids(programme.search(QStringLiteral("開太刀"))).contains(QStringLiteral("shinkitoho/kamae")));
    }

    void gradesWithoutMaterialAreLeftOut()
    {
        QStringList grades;
        for (const QVariant &g : programme.grades(QStringLiteral("shinkitoho"))) {
            grades << g.toMap().value(QStringLiteral("id")).toString();
            QVERIFY(g.toMap().value(QStringLiteral("count")).toInt() > 0);
        }
        QCOMPARE(grades, (QStringList{QStringLiteral("shoden"), QStringLiteral("chuden"), QStringLiteral("okuden"), QStringLiteral("junmenkyo")}));
    }

    // The technique map up to a grade: one grid per group title, rows techniques, columns attacks
    // (with addition) in order of appearance, a cell with every entry of its combination.
    void techniqueMapUpToAGrade()
    {
        QTemporaryDir dir;
        QFile file(dir.filePath(QStringLiteral("map.json")));
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(kMapCatalog);
        file.close();
        Catalog catalog;
        QVERIFY2(catalog.load(file.fileName()), qPrintable(catalog.errorString()));
        const Programme p(catalog);

        QVariantList map = p.techniqueMap(QStringLiteral("test"), QStringLiteral("k4"));
        QCOMPARE(map.size(), 1);                                // the kata has no attack
        QVariantMap grid = map.first().toMap();
        QCOMPARE(grid.value(QStringLiteral("kind")).toString(), QStringLiteral("matrix"));
        QCOMPARE(grid.value(QStringLiteral("title")).toString(), QStringLiteral("Tachi-waza"));
        QCOMPARE(grid.value(QStringLiteral("jp")).toString(), QStringLiteral("立技"));

        QStringList columns;
        for (const QVariant &c : grid.value(QStringLiteral("columns")).toList()) {
            columns << c.toMap().value(QStringLiteral("title")).toString() + QLatin1Char('/') + c.toMap().value(QStringLiteral("extra")).toString();
        }
        QCOMPARE(columns, (QStringList{QStringLiteral("Katate-dori/"), QStringLiteral("Katate-dori/Ai-hanmi"), QStringLiteral("Tsuki/")}));
        QStringList rows;
        for (const QVariant &r : grid.value(QStringLiteral("rows")).toList()) {
            rows << r.toMap().value(QStringLiteral("title")).toString();
            QCOMPARE(r.toMap().value(QStringLiteral("cells")).toList().size(), columns.size());
        }
        QCOMPARE(rows, (QStringList{QStringLiteral("Ikkyo"), QStringLiteral("Irimi-nage"), QStringLiteral("Kote-gaeshi")}));
        QCOMPARE(at(grid.value(QStringLiteral("rows")), 0).value(QStringLiteral("jp")).toString(), QStringLiteral("一教"));

        // Ikkyo against Katate-dori: k5, its variant ura from k4 in the same cell; the first opens.
        const QVariantMap ikkyo = cell(grid, 0, 0);
        QCOMPARE(ikkyo.value(QStringLiteral("ids")).toStringList(), (QStringList{QStringLiteral("ikkyo-kd"), QStringLiteral("ikkyo-kd-ura")}));
        QCOMPARE(ikkyo.value(QStringLiteral("gradeName")).toString(), QStringLiteral("5. Kyu"));
        // The tooltip names every grade of the place, not only the first one's.
        QCOMPARE(ikkyo.value(QStringLiteral("gradeNames")).toStringList(), (QStringList{QStringLiteral("5. Kyu"), QStringLiteral("4. Kyu")}));
        QCOMPARE(ikkyo.value(QStringLiteral("entry")).toMap().value(QStringLiteral("id")).toString(), QStringLiteral("ikkyo-kd"));
        QCOMPARE(cell(grid, 0, 1).value(QStringLiteral("ids")).toStringList(), QStringList{QStringLiteral("ikkyo-kd-ai")});
        QVERIFY(cell(grid, 0, 2).isEmpty());
        QVERIFY(cell(grid, 1, 2).isEmpty());                    // Irimi-nage against Tsuki: 1. Dan
        QCOMPARE(cell(grid, 2, 2).value(QStringLiteral("gradeName")).toString(), QStringLiteral("4. Kyu"));

        // Up to 1. Dan: the dan group of the same title joins the grid; theory stays out.
        map = p.techniqueMap(QStringLiteral("test"), QStringLiteral("d1"));
        QCOMPARE(map.size(), 1);
        grid = map.first().toMap();
        QCOMPARE(grid.value(QStringLiteral("rows")).toList().size(), 3);
        QCOMPARE(cell(grid, 1, 2).value(QStringLiteral("ids")).toStringList(), QStringList{QStringLiteral("irimi-ts")});
        QCOMPARE(cell(grid, 1, 2).value(QStringLiteral("gradeName")).toString(), QStringLiteral("1. Dan"));

        // Only 5. Kyu: no Tsuki yet.
        grid = p.techniqueMap(QStringLiteral("test"), QStringLiteral("k5")).first().toMap();
        QCOMPARE(grid.value(QStringLiteral("columns")).toList().size(), 2);
        QCOMPARE(grid.value(QStringLiteral("rows")).toList().size(), 2);
    }

    // The grids stand in the order of the discipline's groups (Daitoryu: "Zatori · Yoko-seme" from
    // the kyu grades before "Sonstige Techniken", not after it, where it came in a dan grade).
    void techniqueMapInGroupOrder()
    {
        for (const QString &discipline : {QStringLiteral("aikido"), QStringLiteral("daitoryu")}) {
            const QVariantList grades = programme.grades(discipline);
            const QString last = grades.last().toMap().value(QStringLiteral("id")).toString();

            QStringList order;
            for (const QVariant &d : programme.disciplines()) {
                if (d.toMap().value(QStringLiteral("id")) != discipline) {
                    continue;
                }
                for (const QVariant &g : d.toMap().value(QStringLiteral("gruppen")).toList()) {
                    const QString title = g.toMap().value(QStringLiteral("titel")).toString();
                    if (!order.contains(title)) {
                        order << title;
                    }
                }
            }

            QList<qsizetype> positions;
            for (const QVariant &grid : programme.techniqueMap(discipline, last)) {
                positions << order.indexOf(grid.toMap().value(QStringLiteral("title")).toString());
            }
            QVERIFY(positions.size() > 1);
            QVERIFY2(!positions.contains(-1), qPrintable(discipline));
            QVERIFY2(std::is_sorted(positions.cbegin(), positions.cend()), qPrintable(discipline));
        }
    }

    // Shinki Toho: the Ô-dachi forms up to a grade, numbered, each with the grade it comes in.
    void techniqueMapShinkiToho()
    {
        const QVariantList map = programme.techniqueMap(QStringLiteral("shinkitoho"), QStringLiteral("chuden"));
        QCOMPARE(map.size(), 1);
        const QVariantMap grid = map.first().toMap();
        QCOMPARE(grid.value(QStringLiteral("kind")).toString(), QStringLiteral("forms"));
        QCOMPARE(grid.value(QStringLiteral("title")).toString(), QStringLiteral("Ô-dachi 1–21"));
        const QVariantList cells = grid.value(QStringLiteral("cells")).toList();
        QCOMPARE(cells.size(), 21);
        QCOMPARE(at(cells, 0).value(QStringLiteral("entry")).toMap().value(QStringLiteral("nr")).toInt(), 1);
        QCOMPARE(at(cells, 0).value(QStringLiteral("gradeName")).toString(), QStringLiteral("Shoden"));
        QCOMPARE(at(cells, 11).value(QStringLiteral("ids")).toStringList(), QStringList{QStringLiteral("shinkitoho/odachi/12")});
        QCOMPARE(at(cells, 11).value(QStringLiteral("gradeName")).toString(), QStringLiteral("Chûden"));
    }

    void entryById()
    {
        const QVariantMap e = programme.entry(QStringLiteral("shinkitoho/odachi/12"));
        QCOMPARE(e.value(QStringLiteral("discipline")).toString(), QStringLiteral("shinkitoho"));
        QCOMPARE(e.value(QStringLiteral("grade")).toString(), QStringLiteral("chuden"));
        QVERIFY(programme.entry(QStringLiteral("nothing")).isEmpty());
    }

    // English: the rows read the data's English (x_en), the ids stay; also entry(), built once
    // per language.
    void englishRows()
    {
        const QString id = QStringLiteral("shinkitoho/odachi/12");
        QCOMPARE(programme.entry(id).value(QStringLiteral("gradeName")).toString(), QStringLiteral("Chûden"));
        const QVariantList german = programme.entries(QStringLiteral("aikido"), QStringLiteral("d1"));

        Catalog::setLanguage(Catalog::Language::English);
        const QVariantList english = programme.entries(QStringLiteral("aikido"), QStringLiteral("d1"));
        const QVariantMap form = programme.entry(id);
        const QVariantMap kamae = programme.entry(QStringLiteral("shinkitoho/kamae"));
        Catalog::setLanguage(Catalog::Language::German);

        QCOMPARE(ids(english), ids(german));
        QCOMPARE(english.size(), german.size());
        const auto titles = [](const QVariantList &rows) {
            QStringList result;
            for (const QVariant &r : rows) {
                result << r.toMap().value(QStringLiteral("title")).toString();
            }
            return result;
        };
        QVERIFY(titles(german).contains(QStringLiteral("Theorie")));
        QVERIFY(titles(english).contains(QStringLiteral("Theory")));
        QVERIFY(titles(english).contains(QStringLiteral("oral examination")));
        const auto firstEntry = std::find_if(english.cbegin(), english.cend(), [](const QVariant &r) {
            return r.toMap().value(QStringLiteral("kind")) == QLatin1String("entry");
        });
        QCOMPARE(firstEntry->toMap().value(QStringLiteral("gradeName")).toString(), QStringLiteral("1st Dan"));

        QCOMPARE(form.value(QStringLiteral("gradeName")).toString(), QStringLiteral("Chûden"));   // Japanese in both
        QVERIFY(!form.value(QStringLiteral("comment")).toMap().value(QStringLiteral("text")).toString().isEmpty());
        QVERIFY(form.value(QStringLiteral("comment")).toMap().value(QStringLiteral("text"))
                != programme.entry(id).value(QStringLiteral("comment")).toMap().value(QStringLiteral("text")));
        const QVariantList steps = kamae.value(QStringLiteral("steps")).toList();
        QCOMPARE(steps.at(15).toMap().value(QStringLiteral("title")).toString(), QStringLiteral("Tsuki (right foot forward)"));
    }

    // Comments are searched with the rules of search(): accents and case do not matter, every word
    // must occur. A hit carries the line with the words, shortened.
    void searchesComments()
    {
        const QVariantList found = programme.searchComments(QStringLiteral("HOCHST angespannte MOMENT"), 1000);
        QVERIFY(!found.isEmpty());
        for (const QVariant &f : found) {
            const QVariantMap hit = f.toMap();
            QVERIFY(!hit.value(QStringLiteral("comment")).toMap().isEmpty());
            QVERIFY(!hit.value(QStringLiteral("gradeName")).toString().isEmpty());
            const QString excerpt = hit.value(QStringLiteral("excerpt")).toString();
            QVERIFY2(excerpt.contains(QStringLiteral("höchst")), qPrintable(excerpt));
            QVERIFY2(excerpt.size() <= 142, qPrintable(excerpt));
        }
        // Every word: one that is not there leaves nothing; no query finds nothing.
        QVERIFY(programme.searchComments(QStringLiteral("höchst angespannte zzzqqq")).isEmpty());
        QVERIFY(programme.searchComments(QString()).isEmpty());
        // A technique's name alone, not in a comment, is not a hit of its own.
        QCOMPARE(programme.searchComments(QStringLiteral("höchst"), 1).size(), 1);
    }

    // The excerpt holds the word found, also one with accents (the query's words are keys without
    // them) far into a long line, and never cuts a character in two.
    void excerptAroundTheWord()
    {
        const QString filler = QStringLiteral("Den rechten Fuß nach vorne setzen und das Schwert ziehen. ").repeated(4);
        const QString line = filler + QStringLiteral("Dann die Hüfte führen.");
        const QString excerpt = searchExcerpt(line, searchWords(QStringLiteral("fuhren")));
        QVERIFY2(excerpt.contains(QStringLiteral("führen")), qPrintable(excerpt));

        // As SearchText matches: across hyphens and spaces, while typing, and without okurigana.
        const QList<std::pair<QString, QString>> found{{QStringLiteral("Dann Shihô-nage omote."), QStringLiteral("shihon")},
                                                      {QStringLiteral("Dann Shihô-nage omote."), QStringLiteral("shihonage")},
                                                      {QStringLiteral("Dann Shiho nage omote."), QStringLiteral("shiho-nage")},
                                                      {QStringLiteral("正面打ち 切り落し 正面"), QStringLiteral("切り落とし")}};
        for (const auto &[end, query] : found) {
            const QString cut = searchExcerpt(filler + end, searchWords(query));
            const QString shown = end.split(u' ').at(1);
            QVERIFY2(cut.contains(shown), qPrintable(query + u" → " + cut));
        }

        // Where SearchText matches, not an earlier place it rules out: parts of a hyphenated word
        // each from a word's start (not in Kai-hanmi), across a space only to a word's end (not
        // "mit Tenkan").
        struct Hit {
            QString line;
            QString query;
            QString shown;
        };
        const QList<Hit> hits{{filler + QStringLiteral("Dann Ikkyo und dann irimi weiter."), QStringLiteral("ikkyo-irimi"), QStringLiteral("Ikkyo")},
                              {QStringLiteral("mit Tenkan ") + filler + QStringLiteral("die Mitte halten"), QStringLiteral("mitte"), QStringLiteral("Mitte")},
                              {QStringLiteral("Kai-hanmi ") + filler + QStringLiteral("dann ai hanmi"), QStringLiteral("ai-hanmi"), QStringLiteral("ai hanmi")}};
        for (const Hit &hit : hits) {
            const QString cut = searchExcerpt(hit.line, searchWords(hit.query));
            QVERIFY2(cut.contains(hit.shown), qPrintable(hit.query + u" → " + cut));
        }

        // A character beyond the BMP (two UTF-16 units) right at a cut stays whole.
        const QString wide = QString(kExcerptLength - 1, u'x') + QString::fromUcs4(U"\U00020B9F") + QStringLiteral(" Ende");
        const QString cut = searchExcerpt(wide, searchWords(QStringLiteral("xyz")));
        for (qsizetype i = 0; i < cut.size(); ++i) {
            QVERIFY2(!cut.at(i).isHighSurrogate() || (i + 1 < cut.size() && cut.at(i + 1).isLowSurrogate()), "a half character");
        }
    }

    // The search looks in what the rows show: English with English on, German with German; the
    // Japanese names in both.
    void searchInLanguage()
    {
        const QStringList german = ids(programme.search(QStringLiteral("2 arten"), 1000));
        QVERIFY(!german.isEmpty());
        QVERIFY(programme.search(QStringLiteral("2 variants")).isEmpty());

        Catalog::setLanguage(Catalog::Language::English);
        const QStringList english = ids(programme.search(QStringLiteral("2 variants"), 1000));
        const bool noGerman = programme.search(QStringLiteral("2 arten")).isEmpty();
        const bool japanese = !programme.search(QStringLiteral("shiho nage")).isEmpty();
        const bool group = !programme.search(QStringLiteral("other techniques")).isEmpty();
        Catalog::setLanguage(Catalog::Language::German);

        QCOMPARE(english, german);
        QCOMPARE(ids(programme.search(QStringLiteral("2 arten"), 1000)), german);   // German again
        QVERIFY(noGerman);
        QVERIFY(japanese);
        QVERIFY(group);
    }

    // A change of the app's catalog (LanguageChange) to another data language: one signal, a new
    // revision; a change that keeps the data's language (Qt's catalog alone) none.
    void textsFollowLanguage()
    {
        Programme own(loaded());
        QSignalSpy spy(&own, &Programme::textsChanged);
        const int revision = own.revision();
        const auto languageChange = [] {
            QEvent event(QEvent::LanguageChange);
            QCoreApplication::sendEvent(QCoreApplication::instance(), &event);
        };

        languageChange();
        QCOMPARE(spy.count(), 0);
        Catalog::setLanguage(Catalog::Language::English);
        languageChange();
        languageChange();
        QCOMPARE(spy.count(), 1);
        QCOMPARE(own.revision(), revision + 1);
        Catalog::setLanguage(Catalog::Language::German);
        languageChange();
        QCOMPARE(spy.count(), 2);
    }
};

int main(int argc, char *argv[])
{
    // Settings in the build directory (not ~/.qttest, which every build and review running at the
    // same time would share and overwrite).
    qputenv("XDG_CONFIG_HOME", TEST_DATA_DIR "/config");
    qputenv("XDG_DATA_HOME", TEST_DATA_DIR "/data");
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("mitori-test"));
    // The Lernpakete's shelf in a folder of the tests' own.
    QStandardPaths::setTestModeEnabled(true);
    QDir(BundleShelf::defaultRoot()).removeRecursively();
    TstProgramme test;
    return QTest::qExec(&test, argc, argv);
}
#include "tst_programme.moc"
