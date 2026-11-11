#pragma once

#include <QList>
#include <QObject>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

#include "webvtt.h"

// One subtitle track for the player: reads the WebVTT file at `source` once, then gives the text
// for a playing position quickly (a binary search per change of `position`).
//
//   SubtitleTrack { source: Videos.subtitles(video)[0].source; position: player.position }
//   Text { text: track.text }          // "" between the cues, or without a (readable) source
class SubtitleTrack : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // A local file (Videos.subtitles()); empty or unreadable: no cues.
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    // Playing position in ms.
    Q_PROPERTY(qint64 position READ position WRITE setPosition NOTIFY positionChanged)
    // The text at `position`; lines are joined with "\n".
    Q_PROPERTY(QString text READ text NOTIFY textChanged)
    // Number of cues read.
    Q_PROPERTY(int count READ count NOTIFY sourceChanged)

public:
    explicit SubtitleTrack(QObject *parent = nullptr);

    QUrl source() const { return m_source; }
    void setSource(const QUrl &source);
    qint64 position() const { return m_position; }
    void setPosition(qint64 ms);
    QString text() const { return m_text; }
    int count() const { return int(m_cues.size()); }

    Q_INVOKABLE QString textAt(qint64 ms) const;

signals:
    void sourceChanged();
    void positionChanged();
    void textChanged();

private:
    void update();

    QUrl m_source;
    qint64 m_position = 0;
    QString m_text;
    QList<WebVtt::Cue> m_cues;
};
