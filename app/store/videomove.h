#pragma once

#include <QString>
#include <QStringList>

#include <atomic>
#include <functional>

// Moves the bundles' folders from one place to another (Storage runs it in a thread of its own).
// On the same disk each folder is renamed; else each file is copied, and the old folders go only
// once every copy is complete. A cancel or a failure leaves the old place as it was and removes
// what was copied.
//
//   from/aikido-kyu/…  ──copy, 4 MB at a time──►  to/aikido-kyu/…   then from/aikido-kyu goes
class VideoMove
{
public:
    enum class Result { Done, Cancelled, Failed };
    // Auto: a rename on the same disk; Copy always copies (tests: a second disk is rarely at hand).
    enum class Way { Auto, Copy };

    // `folders`: the bundles' folder names in `from` (their ids).
    VideoMove(const QString &from, const QString &to, const QStringList &folders, Way way = Way::Auto);

    // Bytes of the folders' files.
    qint64 total() const;
    // `progress` gets the bytes moved so far; `cancel` is read between two pieces.
    Result run(const std::function<void(qint64)> &progress, const std::atomic_bool &cancel);
    QString errorString() const { return m_error; }

private:
    bool sameDisk() const;
    Result rename();
    Result copy(const std::function<void(qint64)> &progress, const std::atomic_bool &cancel);
    bool copyFile(const QString &source, const QString &target, qint64 &done,
                  const std::function<void(qint64)> &progress, const std::atomic_bool &cancel);
    void undo();

    QString m_from;
    QString m_to;
    QStringList m_folders;
    Way m_way;
    QString m_error;
    bool m_cancelled = false;
};
