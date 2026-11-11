#pragma once

#include <QObject>
#include <QUrl>
#include <QtQmlIntegration/qqmlintegration.h>

#include <memory>

struct SoundSample;

// GameSound: plays the game's sound effects and music, in place of QtMultimedia's
// SoundEffect, with the same QML interface (source, volume, loops, playing, status,
// play(), stop()).
//
// Why not SoundEffect: Qt tags every SoundEffect stream as a system "event" sound, so a
// desktop that mutes system sounds (GNOME's "System Sounds", KDE's "Notification
// Sounds") silenced the whole game. Every GameSound instead plays through one shared
// audio stream with no media role: an ordinary application stream that follows the
// game's own volume in the system mixer.
//
// The source is a PCM WAV file (8, 16, 24 or 32-bit integer, or 32-bit float), read in
// full when it is set, so a GameSound is Ready at once and a play() is never lost to a
// pending load. play() on a one-shot sound starts a new voice, so quick repeats overlap
// rather than cut each other off; a looping sound plays at most once at a time.
class GameSound : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(int loops READ loops WRITE setLoops NOTIFY loopsChanged)
    Q_PROPERTY(bool playing READ isPlaying NOTIFY playingChanged)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)

public:
    enum Loop { Infinite = -2 };
    Q_ENUM(Loop)
    enum Status { Null, Loading, Ready, Error };
    Q_ENUM(Status)

    explicit GameSound(QObject *parent = nullptr);
    ~GameSound() override;

    QUrl source() const { return m_source; }
    void setSource(const QUrl &url);
    qreal volume() const { return m_volume; }
    void setVolume(qreal volume);
    int loops() const { return m_loops; }
    void setLoops(int loops);
    bool isPlaying() const { return m_active > 0; }
    Status status() const { return m_status; }

    Q_INVOKABLE void play();
    Q_INVOKABLE void stop();

signals:
    void sourceChanged();
    void volumeChanged();
    void loopsChanged();
    void playingChanged();
    void statusChanged();

private:
    friend class SoundMixer;
    void voiceEnded(quint64 generation);   // called (queued) by the mixer
    void setStatus(Status status);

    QUrl m_source;
    qreal m_volume = 1.0;
    int m_loops = 1;
    Status m_status = Null;
    std::shared_ptr<const SoundSample> m_sample;
    int m_active = 0;            // voices playing now
    quint64 m_generation = 0;    // bumped by stop(), so stale "ended" notes are ignored
};
