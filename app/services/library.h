#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class BundleShelf;
class Lessons;

// The Lernpakete for QML: the installed packages and their techniques (Lessons), and the player's
// list around one of them. A package's technique ids are "lern/<package>/<id>".
class Library : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // Installed packages by title: {id, title, text, sparte, count, videos [{video, title}]}. Follows
    // a package that came or went, and a change of language.
    Q_PROPERTY(QVariantList packages READ packages NOTIFY changed)

public:
    explicit Library(QObject *parent = nullptr);
    // For tests: another shelf and lessons.
    Library(const Lessons &lessons, const BundleShelf &shelf, QObject *parent = nullptr);

    QVariantList packages() const;

    // The rows of a package in order (group and entry, as Programme::entries()); see Lessons::rows().
    Q_INVOKABLE QVariantList rows(const QString &package) const;
    // The installed packages' entries that name this exam-programme technique (Lessons::related()).
    Q_INVOKABLE QVariantList related(const QString &programmeId) const;
    // The player's list around a technique: {playlist, index}, the package's entries whose video is on
    // the device, so that previous and next work. A technique without a video on the device is a
    // list of its own; an unknown id gives an empty list and index -1.
    Q_INVOKABLE QVariantMap around(const QString &id) const;

signals:
    void changed();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    const Lessons &m_lessons;
    const BundleShelf &m_shelf;
};
