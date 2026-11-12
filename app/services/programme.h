#pragma once

#include <QHash>
#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <functional>
#include <optional>

#include "catalog.h"
#include "searchkey.h"

// The exam programme for QML: disciplines, grades and the entries of a grade, ready for a list.
class Programme : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // In the app's language (Catalog): texts follow a change of it, ids stay.
    Q_PROPERTY(QVariantList disciplines READ disciplines NOTIFY textsChanged)
    // Grows when the texts change language or a Lernpaket comes or goes: bindings that call the functions below read it to follow.
    Q_PROPERTY(int revision READ revision NOTIFY textsChanged)
    Q_PROPERTY(QString errorString READ errorString CONSTANT)
    Q_PROPERTY(QString dataVersion READ dataVersion CONSTANT)
    // The discipline chosen last (start menu tile, programme page); kept across starts.
    Q_PROPERTY(QString discipline READ discipline WRITE setDiscipline NOTIFY selectionChanged)

public:
    explicit Programme(QObject *parent = nullptr);
    // For tests: another catalog.
    explicit Programme(const Catalog &catalog, QObject *parent = nullptr);

    QVariantList disciplines() const { return m_catalog.disciplines(); }
    QString errorString() const { return m_catalog.errorString(); }
    QString dataVersion() const { return m_catalog.dataVersion(); }
    int revision() const { return m_revision; }

    QString discipline() const;
    void setDiscipline(const QString &discipline);

    // Grades of a discipline that have their own material: {id, name, jp, count}.
    Q_INVOKABLE QVariantList grades(const QString &discipline) const;
    // The programme page's chips, in catalog order: grades(), and with count 0 a grade without
    // entries that has an `inhalt` (Shinki Toho Hon-Menkyo; Hôshu has none). Chosen only on that
    // page: nothing else can use such a grade.
    Q_INVOKABLE QVariantList gradeChips(const QString &discipline) const;
    // Rows of a grade in programme order. Each row has `kind`:
    //   "group"     title, jp            a heading (Kata, Tachi-waza · Mae-seme, Kamae, Ô-dachi …)
    //   "attack"    title, extra, jp     the attack the techniques below answer
    //   "entry"     id, title, extra, jp, nr, video {video, von, bis} or none, comment {titel, text} or none,
    //               steps [{title, jp}]: the positions of a sequence (Kamae exercise), else empty
    //   "info"      id, title, jp, text, comment   an introduction with a comment only (Kumidachi)
    //   "text"      id, title            a theory item of the exam (essay, oral exam): no video, no rating
    // grades(), entries(), practiceEntries() and techniqueMap() read the catalog only (no cache, no
    // Lessons): StartBoard calls them from a worker thread. Keep it so, or change StartBoard.
    Q_INVOKABLE QVariantList entries(const QString &discipline, const QString &grade) const;
    // What today's practice draws from: the entry rows of every grade up to `grade` (the practice
    // grade, see PracticeGrade), in programme order, each with `current` (part of that grade) and
    // `gradeName`.
    Q_INVOKABLE QVariantList practiceEntries(const QString &discipline, const QString &grade) const;
    // Techniques whose name, attack, Japanese, additions, group or steps contain every word of `query`
    // (see SearchText), in the texts the rows show (English with English on, not the German), across all disciplines and grades in programme order (at most `limit`).
    // Each row as in entries(), with `discipline`, `disciplineName`, `grade`, `gradeName` and
    // `groupName` (Tachi-waza · Mae-seme …). The techniques of the installed Lernpakete follow the
    // programme's, as Lessons has them (`disciplineName` the package's title, `gradeName` empty).
    Q_INVOKABLE QVariantList search(const QString &query, int limit = 50) const;
    // The techniques whose Shinki Toho comment (title and text) holds every word of the query, rows
    // as in search() plus `excerpt`: the comment's line with the words, shortened around them. Same
    // rules and language as search(), at most `limit`.
    Q_INVOKABLE QVariantList searchComments(const QString &query, int limit = 50) const;
    // Builds what search() compares (16 ms), when the search opens, not on the first letter.
    Q_INVOKABLE void prepareSearch() const { searchRows(); }
    // The techniques a text names (a course note), best first, at most `limit`, leaving out the ids
    // in `without` (those already linked); rows as in search(). A name counts as whole words, however
    // written ("shiho nage", "Shihonage" for Shihô-nage), and the longest wins: "Uchi-kaiten-nage" does
    // not also name Kaiten-nage. Of one name, those that also name the attack (whole, then its end,
    // "Katate-dori") come first, then the discipline chosen last; several names take turns, so that
    // 26 Ikkyo do not push out Kote-gaeshi. "Ô-dachi 5" is that form, "O-dachi" alone the forms in
    // order, up to `limit`.
    Q_INVOKABLE QVariantList suggest(const QString &text, int limit = 8, const QStringList &without = {}) const;
    // "Shihô-nage · Katate-dori · Aikido 5. Kyu", or "" for an id not in the programme.
    Q_INVOKABLE QString techniqueLabel(const QString &id) const;
    // One entry by id (the same map as in entries()), or an empty map. An id "lern/<package>/…" is a
    // technique of a Lernpaket (Lessons, also one that was removed since); the label ends with its title.
    Q_INVOKABLE QVariantMap entry(const QString &id) const;
    // The technique map (clickdummy "Landkarte") of every grade up to `grade`: a grid per group
    // with attacks, in the order of the discipline's groups; groups of the same title (kyu and dan
    // grades) are one.
    // Each grid: kind "matrix", title, jp,
    //   columns  [{title, extra, jp}]  the attacks (with addition), in order of appearance
    //   rows     [{title, jp, cells}]  the techniques by name, in order of appearance; one cell
    //            per column: {} where the technique does not answer the attack, else
    //            {ids, entry, gradeName, gradeNames}: every entry of the combination (variants, a
    //            later grade), the first one's row (as in entries()) and grade, the grades of all.
    // Shinki Toho: one grid, kind "forms", title "Ô-dachi 1–N", jp, cells [{ids, entry, gradeName, gradeNames}]
    // one per form.
    Q_INVOKABLE QVariantList techniqueMap(const QString &discipline, const QString &grade) const;

signals:
    void selectionChanged();
    void textsChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    // The rows of a grade without the grade's name (entries() adds it).
    QVariantList gradeRows(const QString &disciplineId, const QString &grade) const;
    int entryCount(const QString &disciplineId, const QString &grade) const;
    QVariantMap findDiscipline(const QString &id) const;
    // Every technique once, in programme order, with `discipline`, `disciplineName`, `grade`,
    // `gradeName` and `groupName`; a visitor that returns false ends the walk.
    void eachTechnique(const std::function<bool(const QVariantMap &)> &visit) const;
    // Every technique (eachTechnique) with what search() compares, built once per language: the
    // search asks on every keystroke.
    struct SearchRow {
        QVariantMap row;
        SearchText text;
        std::optional<SearchText> comment;  // title and text of the Shinki Toho comment, if any
    };
    const QList<SearchRow> &searchRows() const;
    QVariantList shinkiTohoEntries(const QVariantMap &discipline, const QString &grade) const;
    QVariantList formMap(const QString &grade) const;

    Catalog m_catalog;
    Catalog::Language m_language;
    int m_revision = 0;
    // Built on first use, in the language of then (entry()).
    mutable QHash<QString, QVariantMap> m_entryIndex;
    mutable Catalog::Language m_indexLanguage = Catalog::Language::German;
    mutable QList<SearchRow> m_searchRows;
    mutable Catalog::Language m_searchLanguage = Catalog::Language::German;
    mutable quint64 m_searchLessons = 0;
};
