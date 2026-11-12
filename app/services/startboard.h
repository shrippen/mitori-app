#pragma once

#include <QFutureWatcher>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include "practicelog.h"

class Courses;
class Exam;
class Glossary;
class Practice;
class PracticeGrade;
class Programme;
class QJSEngine;
class QQmlEngine;

// The notes tile's inputs and the snapshot of all (startboard.cpp).
struct StartNotes {
    int techniques = 0;
    int courses = 0;
    QDateTime at;
    QString text;
    bool media = false;
};
struct StartSnapshot;

// What the tiles of the start menu show, worked out off the GUI thread so that the menu draws
// at once and the tiles fill in a moment later.
//
//   services (GUI thread)   ──►  snapshot: plain values, copies
//                                      │  QtConcurrent::run
//                                      ▼
//                               summaries (worker)  ──►  tiles   (GUI thread, QFutureWatcher)
//
// The worker touches no QObject and no database: the snapshot holds copies (QVariant and the
// implicitly shared hashes of the ratings). A change of any input starts one new run after a short
// pause, so a burst of ratings costs one. `tiles` maps a tile's name to its summary; each
// summary has `ready: true`. A tile with no summary yet is an empty map.
//
//   programme  discipline, gradeName, ladder [{name, state: done|current|todo}], counts [0..4], total,
//              sure (level 3 and 4), ready (level 4), next {id, title, attack} (the technique
//              unsure the longest, or the first new one)
//   today      due, unsure (levels 1-2), fresh (new)
//   exam       planned, name (grade), mock (the mock exam's grade), days, share (0..1 of the exam's points at 3 or 4), sure, total
//   stats      days (practice days in 30), techniques, streak, cells [30 counts, today last]
//   courses    has, title, first (ISO), days, teacher, place, entries (-1: no notebook yet)
//   map        title, columns, levels [[-1 (no place), 0..4]]
//   glossary   word, jp, meaning
//   notes      techniques, courses, text, at (local), media
class StartBoard : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantMap tiles READ tiles NOTIFY tilesChanged)
    // Every tile has its summary of the latest state.
    Q_PROPERTY(bool ready READ ready NOTIFY tilesChanged)

public:
    // How many days the statistics tile's calendar shows.
    static constexpr int kDays = 30;
    // The pause that gathers a burst of changes into one run.
    static constexpr int kPauseMs = 40;

    // The app's: the engine's services.
    static StartBoard *create(QQmlEngine *engine, QJSEngine *);
    StartBoard(Programme *programme, Practice *practice, PracticeGrade *grades, Courses *courses, Exam *exam,
               Glossary *glossary, QObject *parent = nullptr);
    ~StartBoard() override;

    QVariantMap tiles() const { return m_tiles; }
    bool ready() const { return m_ready; }

    // How long the GUI thread took for the last snapshot, in microseconds (tests, diagnosis).
    qint64 snapshotUs() const { return m_snapshotUs; }

    // A run for the services' state of now (after the pause); the signals of the services do it.
    Q_INVOKABLE void refresh();

signals:
    void tilesChanged();

private:
    void start();
    void done();
    StartSnapshot snapshot();
    void readNotes();

    QPointer<Programme> m_programme;
    QPointer<Practice> m_practice;
    QPointer<PracticeGrade> m_grades;
    QPointer<Courses> m_courses;
    QPointer<Exam> m_exam;
    QPointer<Glossary> m_glossary;

    QTimer m_pause;
    QFutureWatcher<QVariantMap> m_watcher;
    QVariantMap m_tiles;
    bool m_ready = false;
    bool m_again = false;       // a change came while a run was working
    bool m_notesStale = true;
    StartNotes m_notes;
    qint64 m_snapshotUs = 0;
    QString m_gradeKey;
    QString m_grade;
};
