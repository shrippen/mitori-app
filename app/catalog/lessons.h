#pragma once

#include <QHash>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include "catalog.h"

class BundleShelf;

// The techniques of the installed Lernpakete (video bundles with their own techniques, see
// mitori-daten/tools/lernpakete.md), read from the content the shelf keeps (BundleShelf::content).
// The counterpart of Catalog for what is not in mitori-daten.json. Read by services only.
//
//   shelf  <id>.inhalt.json ──► packages()   installed packages {id, title, text, sparte, count, videos}
//                           ├─► rows(id)     a package's rows, as Programme::entries()
//                           └─► entry(id)    any technique whose content is on the shelf, also of a
//                                            removed package (notes keep their labels)
//
// Texts in the app's language (Catalog::language): English with x_en in place of x, as for the
// catalog. Parsed once per language and shelf change.
class Lessons : public QObject
{
    Q_OBJECT

public:
    // The ids of a lesson's techniques start with this and the package's id: "lern/shirakawa-1/…".
    static constexpr auto kPrefix = "lern/";
    static constexpr auto kDiscipline = "lern";

    // The lessons of the app's shelf (BundleShelf::shared()).
    static Lessons &shared();
    explicit Lessons(const BundleShelf &shelf, QObject *parent = nullptr);

    // Installed packages by title: {id, title, text, sparte, count, videos [{video, title}]}.
    QVariantList packages() const;
    // The rows of an installed package in order. Each row has `kind`:
    //   "group"   title, jp, text      a section
    //   "entry"   id, title, extra, jp, attack, attackJp, text, wie [ids], video {video, von, bis} or null,
    //             discipline "lern", package, disciplineName (the package's title), gradeName "",
    //             groupName (the section), steps [], open false
    QVariantList rows(const QString &package) const;
    // One technique by id (the row of rows()), or an empty map.
    QVariantMap entry(const QString &id) const;
    // A lesson video's picture area {hoehe, y, h, verhaeltnis} as in the catalog's videos; empty if none.
    QVariantMap crop(const QString &video) const;
    // Grows when a lesson came, went or changed (not for every save of the shelf).
    quint64 revision() const;

signals:
    void changed();

private:
    struct Package {
        QVariantMap info;
        QVariantList rows;
    };

    void refresh() const;

    const BundleShelf &m_shelf;
    quint64 m_signalled = 0;
    // Built on first use and again when the shelf's lessons or the language change.
    mutable bool m_built = false;
    mutable quint64 m_revision = 0;
    mutable Catalog::Language m_language = Catalog::Language::German;
    mutable QList<Package> m_packages;                  // installed, by title
    mutable QHash<QString, QVariantMap> m_entries;
    mutable QHash<QString, QVariantMap> m_crops;
};
