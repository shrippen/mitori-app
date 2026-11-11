#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

#include "subtitletrack.h"
#include "webvtt.h"


using namespace Qt::StringLiterals;

// The WebVTT reader (store) and the SubtitleTrack element (services) on the test bundle's track.
class TstWebVtt : public QObject
{
    Q_OBJECT

    static QString sample()
    {
        QFile f(QStringLiteral(TEST_BUNDLE_DIR "/test.en.vtt"));
        return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()) : QString();
    }

private slots:
    // Header, NOTE, cue id, settings and tags are no cues or text; both time forms read.
    void parsesTheTestTrack()
    {
        const QList<WebVtt::Cue> cues = WebVtt::parse(sample());
        QCOMPARE(cues.size(), 2);
        QCOMPARE(cues.at(0).start, 1000);
        QCOMPARE(cues.at(0).end, 3500);
        QCOMPARE(cues.at(0).text, u"Hello test"_s);
        QCOMPARE(cues.at(1).start, 4000);
        QCOMPARE(cues.at(1).end, 5250);
        QCOMPARE(cues.at(1).text, u"First line\nSecond line"_s);
    }

    void hoursAndCrLf()
    {
        const QList<WebVtt::Cue> cues = WebVtt::parse(u"﻿WEBVTT\r\n\r\nSTYLE\r\n::cue { color: red }\r\n\r\n"
                                                      "REGION\r\nid:a\r\n\r\n"
                                                      "01:02:03.004 --> 01:02:04.000 line:90%\r\nA &amp; B &lt;ok&gt;\r\n\r\n"
                                                      "00:09.000 --> 00:10.000\r\n<v Speaker>Hi</v>\r\n"_s);
        QCOMPARE(cues.size(), 2);
        // Sorted by start.
        QCOMPARE(cues.at(0).start, 9000);
        QCOMPARE(cues.at(0).text, u"Hi"_s);
        QCOMPARE(cues.at(1).start, 3723004);
        QCOMPARE(cues.at(1).end, 3724000);
        QCOMPARE(cues.at(1).text, u"A & B <ok>"_s);
    }

    void brokenBlocksAreSkipped()
    {
        const QList<WebVtt::Cue> cues = WebVtt::parse(u"WEBVTT\n\n1\nno timing here\n\n00:01.000 --> 00:02.000\n\n"
                                                      "x\n00:01.000 --> 00:02.000\nid line is first\n\n"
                                                      "00:03.000 --> 00:04.000\nkept\n"_s);
        QCOMPARE(cues.size(), 2);
        QCOMPARE(cues.at(0).text, u"id line is first"_s);
        QCOMPARE(cues.at(1).text, u"kept"_s);
        QVERIFY(WebVtt::parse(QString()).isEmpty());
        QVERIFY(WebVtt::read(u"/nonexistent/x.vtt"_s).isEmpty());
    }

    void textAtEdges()
    {
        const QList<WebVtt::Cue> cues = WebVtt::parse(sample());
        QCOMPARE(WebVtt::textAt(cues, 0), QString());
        QCOMPARE(WebVtt::textAt(cues, 999), QString());
        QCOMPARE(WebVtt::textAt(cues, 1000), u"Hello test"_s);
        QCOMPARE(WebVtt::textAt(cues, 3499), u"Hello test"_s);
        QCOMPARE(WebVtt::textAt(cues, 3500), QString());
        QCOMPARE(WebVtt::textAt(cues, 4000), u"First line\nSecond line"_s);
        QCOMPARE(WebVtt::textAt(cues, 5250), QString());
        QCOMPARE(WebVtt::textAt({}, 10), QString());
    }

    // The element reads its file once and follows the position; its text changes only at the edges.
    void trackFollowsPosition()
    {
        SubtitleTrack track;
        QSignalSpy texts(&track, &SubtitleTrack::textChanged);
        QCOMPARE(track.text(), QString());
        track.setSource(QUrl::fromLocalFile(QStringLiteral(TEST_BUNDLE_DIR "/test.en.vtt")));
        QCOMPARE(track.count(), 2);

        track.setPosition(1200);
        QCOMPARE(track.text(), u"Hello test"_s);
        track.setPosition(1300);
        QCOMPARE(texts.size(), 1);
        track.setPosition(3600);
        QCOMPARE(track.text(), QString());
        QCOMPARE(track.textAt(4100), u"First line\nSecond line"_s);
        QCOMPARE(texts.size(), 2);

        // A source that cannot be read: no cues, no text.
        track.setSource(QUrl::fromLocalFile(u"/nonexistent/x.vtt"_s));
        QCOMPARE(track.count(), 0);
        QCOMPARE(track.text(), QString());
    }
};

QTEST_GUILESS_MAIN(TstWebVtt)
#include "tst_webvtt.moc"
