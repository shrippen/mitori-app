#include "subtitletrack.h"

SubtitleTrack::SubtitleTrack(QObject *parent)
    : QObject(parent)
{
}

void SubtitleTrack::setSource(const QUrl &source)
{
    if (source == m_source) {
        return;
    }
    m_source = source;
    m_cues = source.isLocalFile() ? WebVtt::read(source.toLocalFile()) : QList<WebVtt::Cue>();
    emit sourceChanged();
    update();
}

void SubtitleTrack::setPosition(qint64 ms)
{
    if (ms == m_position) {
        return;
    }
    m_position = ms;
    emit positionChanged();
    update();
}

QString SubtitleTrack::textAt(qint64 ms) const
{
    return WebVtt::textAt(m_cues, ms);
}

// The text changes only at a cue's edge: no signal for every tick of the position.
void SubtitleTrack::update()
{
    const QString now = textAt(m_position);
    if (now == m_text) {
        return;
    }
    m_text = now;
    emit textChanged();
}
