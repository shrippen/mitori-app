#include "webvtt.h"

#include <QFile>
#include <QRegularExpression>
#include <algorithm>

namespace {
constexpr qint64 kMsPerSecond = 1000;
constexpr qint64 kMsPerMinute = 60 * kMsPerSecond;
constexpr qint64 kMsPerHour = 60 * kMsPerMinute;
const QString kBom = QStringLiteral("﻿");

// "00:01.500 --> 01:02:03.000 align:start": [hh:]mm:ss.mmm twice; the settings are not matched.
const QRegularExpression &timing()
{
    static const QRegularExpression re(QStringLiteral(
        R"(^\s*(?:(\d+):)?(\d{2}):(\d{2})\.(\d{3})\s+-->\s+(?:(\d+):)?(\d{2}):(\d{2})\.(\d{3})(?:\s|$))"));
    return re;
}

qint64 millis(const QRegularExpressionMatch &m, int first)
{
    return m.captured(first).toLongLong() * kMsPerHour + m.captured(first + 1).toLongLong() * kMsPerMinute
           + m.captured(first + 2).toLongLong() * kMsPerSecond + m.captured(first + 3).toLongLong();
}

// Blocks that carry no cue: NOTE, STYLE and REGION, as a word of their own on the first line.
bool isMeta(const QString &first)
{
    static const QRegularExpression re(QStringLiteral(R"(^(NOTE|STYLE|REGION)(\s|$))"));
    return re.match(first).hasMatch();
}

QString plain(const QString &line)
{
    static const QRegularExpression tags(QStringLiteral("<[^>]*>"));
    QString s = line;
    s.remove(tags);
    // The entities WebVTT names; "&amp;" last, so that "&amp;lt;" stays "&lt;".
    s.replace(QStringLiteral("&lt;"), QStringLiteral("<")).replace(QStringLiteral("&gt;"), QStringLiteral(">"));
    s.replace(QStringLiteral("&nbsp;"), QStringLiteral(" ")).replace(QStringLiteral("&amp;"), QStringLiteral("&"));
    return s.trimmed();
}
}

QList<WebVtt::Cue> WebVtt::parse(const QString &text)
{
    QString all = text;
    if (all.startsWith(kBom)) {
        all.remove(0, 1);
    }
    all.replace(QStringLiteral("\r\n"), QStringLiteral("\n")).replace(QLatin1Char('\r'), QLatin1Char('\n'));

    QList<Cue> cues;
    const QStringList blocks = all.split(QStringLiteral("\n\n"), Qt::SkipEmptyParts);
    for (const QString &block : blocks) {
        QStringList lines = block.split(QLatin1Char('\n'));
        // Blank lines of several in a row leave blocks that start with one.
        while (!lines.isEmpty() && lines.first().trimmed().isEmpty()) {
            lines.removeFirst();
        }
        if (lines.isEmpty() || lines.first().startsWith(QStringLiteral("WEBVTT")) || isMeta(lines.first())) {
            continue;
        }

        // The timing is the first line, or the second after a cue id.
        qsizetype at = timing().match(lines.first()).hasMatch() ? 0 : 1;
        if (at >= lines.size()) {
            continue;
        }
        const QRegularExpressionMatch m = timing().match(lines.at(at));
        if (!m.hasMatch()) {
            continue;
        }

        QStringList shown;
        for (qsizetype i = at + 1; i < lines.size(); ++i) {
            const QString line = plain(lines.at(i));
            if (!line.isEmpty()) {
                shown << line;
            }
        }
        if (shown.isEmpty()) {
            continue;
        }
        cues.append({millis(m, 1), millis(m, 5), shown.join(QLatin1Char('\n'))});
    }
    std::stable_sort(cues.begin(), cues.end(), [](const Cue &a, const Cue &b) { return a.start < b.start; });
    return cues;
}

QList<WebVtt::Cue> WebVtt::read(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    return parse(QString::fromUtf8(file.readAll()));
}

QString WebVtt::textAt(const QList<Cue> &cues, qint64 ms)
{
    // The first cue that starts after ms; the one before it is the last that began.
    const auto after = std::upper_bound(cues.cbegin(), cues.cend(), ms, [](qint64 t, const Cue &c) { return t < c.start; });
    if (after == cues.cbegin()) {
        return {};
    }
    const Cue &cue = *std::prev(after);
    return ms < cue.end ? cue.text : QString();
}
