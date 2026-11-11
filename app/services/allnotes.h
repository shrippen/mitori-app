#pragma once

#include <QPointer>
#include <QtQml/qqmlregistration.h>

#include "courses.h"
#include "keyedlistmodel.h"
#include "practice.h"
#include "programme.h"

// The rows of "All notes" (clickdummy "Alle Notizen"), built in C++: the notes on every
// technique (Practice) and the entries of every course notebook (Courses), newest first, with a
// filter. A change rebuilds the rows and changes only what changed (KeyedListModel), so the list
// keeps its place. In JavaScript the same took 64–120 ms per change with 2000 notes.
//
//   row  {uid, kind ("technique" | "course"), text, created, changed, day ("YYYY-MM-DD", local),
//         title ("Aikido 5. Kyu · 3 · Shiho-nage · Katate-dori", or the course's title),
//         discipline (a technique's, "" for a course), entry (a technique's id), course (a course's uid)}
//
//   filter  ""  every note     "courses"  the course notebooks     a discipline's id  its techniques
class AllNotes : public KeyedListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(Practice *practice READ practice WRITE setPractice NOTIFY sourcesChanged)
    Q_PROPERTY(Courses *courses READ courses WRITE setCourses NOTIFY sourcesChanged)
    Q_PROPERTY(Programme *programme READ programme WRITE setProgramme NOTIFY sourcesChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    // Every note before the filter, and the rows shown.
    Q_PROPERTY(int total READ total NOTIFY rowsChanged)
    Q_PROPERTY(int count READ count NOTIFY rowsChanged)
    // Of those, the notes on a Lernpaket's techniques (the page's filter for them).
    Q_PROPERTY(int lessonNotes READ lessonNotes NOTIFY rowsChanged)

public:
    explicit AllNotes(QObject *parent = nullptr);

    static constexpr auto kCourses = "courses";

    Practice *practice() const { return m_practice; }
    void setPractice(Practice *practice);
    Courses *courses() const { return m_courses; }
    void setCourses(Courses *courses);
    Programme *programme() const { return m_programme; }
    void setProgramme(Programme *programme);
    QString filter() const { return m_filter; }
    void setFilter(const QString &filter);
    int total() const { return int(m_all.size()); }
    int count() const { return rowCount(); }
    int lessonNotes() const { return m_lessonNotes; }

    // The rows anew from the sources (on every change of theirs).
    Q_INVOKABLE void rebuild();

signals:
    void sourcesChanged();
    void filterChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void readGradeNames();
    void collect();
    void show();
    QString techniqueTitle(const QVariantMap &entry) const;
    struct Technique {
        QString title;
        QString discipline;
    };
    const Technique &technique(const QString &entry);

    QPointer<Practice> m_practice;
    QPointer<Courses> m_courses;
    QPointer<Programme> m_programme;
    QString m_filter;
    QVariantList m_all;
    int m_lessonNotes = 0;
    QHash<QString, QString> m_gradeNames;   // "aikido/k5" → "Aikido 5. Kyu"
    QHash<QString, Technique> m_techniques; // by entry id
};
