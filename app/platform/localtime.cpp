#include "localtime.h"

#include <QFile>

namespace LocalTime {

namespace {

constexpr char kZoneFile[] = "/etc/localtime";
// The leading colon: a file, read once (glibc compares TZ with the last value and stops there).
constexpr char kPinnedZone[] = ":/etc/localtime";

}

void pin()
{
#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    if (!qEnvironmentVariableIsEmpty("TZ") || !QFile::exists(QLatin1String(kZoneFile))) {
        return;
    }
    qputenv("TZ", kPinnedZone);
#endif
}

}
