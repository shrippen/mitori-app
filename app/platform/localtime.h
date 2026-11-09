#pragma once

// The local time zone, read once. glibc reads TZ on every local time (each JS Date, each
// QDateTime::toLocalTime); unset, it stats /etc/localtime each time: half of the All years
// page's time (5 years of calendar). Pinned, a time zone changed while the app runs counts after
// a restart. Linux only; Android's libc reads a system property, not a file.
namespace LocalTime {

// TZ=":/etc/localtime" when TZ is unset and the file exists; before the first local time.
void pin();

}
