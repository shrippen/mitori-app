#pragma once

#include <QSqlDatabase>
#include <QSqlQuery>

// A save is a tap on the UI thread. SQLite's default journal syncs files several times per save
// (30 ms on an SSD, more on a phone's flash); written ahead (WAL) with synchronous=NORMAL, 0.1 ms.
// A crash of the app loses nothing; a power cut may lose the last saves, as with Android's own
// databases. Backups and syncs copy through SQLite (VACUUM INTO, ATTACH), so the -wal file goes
// with them. A file system without WAL (shared memory) keeps the journal: still a working store.
namespace WriteAhead {

inline void enable(const QSqlDatabase &db)
{
    QSqlQuery q(db);
    q.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
    q.exec(QStringLiteral("PRAGMA synchronous = NORMAL"));
}

}
