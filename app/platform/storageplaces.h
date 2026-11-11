#pragma once

#include <QList>
#include <QString>

// The places on this device where the video bundles may lie, besides the app's own data folder.
// Android: each removable card (SD card), in the app's folder there (getExternalFilesDirs): no
// permission needed, and it goes with the app. Elsewhere none: the user picks a folder (Storage).
namespace StoragePlaces {

struct Place {
    QString path;       // the app's folder on the card
    QString label;      // the system's name for it ("SD card of SanDisk"), may be empty
};

QList<Place> cards();

}
