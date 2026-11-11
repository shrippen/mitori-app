#pragma once

#include <QList>
#include <QString>

// A WebVTT file (the subtitles of a Lernpaket's videos) as cues. Only what a subtitle needs: header,
// NOTE, STYLE and REGION blocks, cue ids and the settings after the times are skipped; tags
// (<i>, <c.yellow>, <00:01.000>) go, their text stays; the lines of a cue are joined with "\n".
// Times are "hh:mm:ss.mmm" or "mm:ss.mmm".
class WebVtt
{
public:
    struct Cue {
        qint64 start = 0;       // ms
        qint64 end = 0;
        QString text;
    };

    // The cues by start time; a block that is no cue, or has no text, is left out.
    static QList<Cue> parse(const QString &text);
    // The cues of a file (UTF-8); none when it cannot be read.
    static QList<Cue> read(const QString &path);
    // The text shown at `ms` in cues from parse(): the cue that began last and has not ended
    // (a cue that began earlier and overlaps it is not found); "" in a gap.
    static QString textAt(const QList<Cue> &cues, qint64 ms);
};
