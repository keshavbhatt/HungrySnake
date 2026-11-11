#include "GameSound.h"

#include <QAudioDevice>
#include <QAudioFormat>
#include <QAudioSink>
#include <QCoreApplication>
#include <QFile>
#include <QIODevice>
#include <QLoggingCategory>
#include <QMediaDevices>
#include <QMutex>
#include <QQmlFile>
#include <QTimer>
#include <QtEndian>

#include <algorithm>
#include <cstring>
#include <vector>

Q_LOGGING_CATEGORY(lcGameSound, "hungrysnake.sound")

// A decoded sound: interleaved float frames at the file's own rate and channel count.
// The mixer resamples while it plays, so nothing is converted up front.
struct SoundSample
{
    std::vector<float> data;
    int channels = 0;
    int rate = 0;
    qint64 frames = 0;
};

namespace {

quint16 le16(const char *p) { return qFromLittleEndian<quint16>(p); }
quint32 le32(const char *p) { return qFromLittleEndian<quint32>(p); }

// Reads a RIFF/WAVE file of PCM integer (8/16/24/32-bit) or 32-bit float samples.
std::shared_ptr<const SoundSample> loadWav(const QUrl &url, QString *error)
{
    QFile file(QQmlFile::urlToLocalFileOrQrc(url));
    if (!file.open(QIODevice::ReadOnly)) {
        *error = file.errorString();
        return {};
    }
    const QByteArray bytes = file.readAll();
    const char *b = bytes.constData();
    const qsizetype size = bytes.size();
    if (size < 12 || std::memcmp(b, "RIFF", 4) != 0 || std::memcmp(b + 8, "WAVE", 4) != 0) {
        *error = QStringLiteral("not a WAV file");
        return {};
    }

    int format = 0, channels = 0, bits = 0;
    quint32 rate = 0;
    const char *pcm = nullptr;
    qsizetype pcmSize = 0;
    for (qsizetype at = 12; at + 8 <= size;) {
        const quint32 chunk = le32(b + at + 4);
        const char *body = b + at + 8;
        const qsizetype avail = std::min<qsizetype>(chunk, size - at - 8);
        if (std::memcmp(b + at, "fmt ", 4) == 0 && avail >= 16) {
            format = le16(body);
            channels = le16(body + 2);
            rate = le32(body + 4);
            bits = le16(body + 14);
            if (format == 0xFFFE && avail >= 26)   // WAVE_FORMAT_EXTENSIBLE: real format follows
                format = le16(body + 24);
        } else if (std::memcmp(b + at, "data", 4) == 0) {
            pcm = body;
            pcmSize = avail;
        }
        at += 8 + qsizetype(chunk) + (chunk & 1);
    }

    const bool isInt = format == 1 && (bits == 8 || bits == 16 || bits == 24 || bits == 32);
    const bool isFloat = format == 3 && bits == 32;
    if (!pcm || channels < 1 || rate == 0 || (!isInt && !isFloat)) {
        *error = QStringLiteral("unsupported WAV format (%1, %2-bit)").arg(format).arg(bits);
        return {};
    }

    auto sample = std::make_shared<SoundSample>();
    const int width = bits / 8;
    sample->channels = channels;
    sample->rate = int(rate);
    sample->frames = pcmSize / (width * channels);
    sample->data.resize(size_t(sample->frames) * channels);
    for (size_t i = 0; i < sample->data.size(); ++i) {
        const char *p = pcm + i * width;
        float v = 0.f;
        if (isFloat) {
            v = qFromLittleEndian<float>(p);
        } else switch (bits) {
            case 8:  v = (quint8(*p) - 128) / 128.f; break;
            case 16: v = qint16(le16(p)) / 32768.f; break;
            case 24: v = (qint32(quint32(quint8(p[0])) << 8 | quint32(quint8(p[1])) << 16
                                 | quint32(quint8(p[2])) << 24) >> 8) / 8388608.f; break;
            case 32: v = qint32(le32(p)) / 2147483648.f; break;
        }
        sample->data[i] = v;
    }
    return sample;
}

} // namespace

// ── SoundMixer: one audio stream that every GameSound plays through ─────────────────
// The stream is opened on the first play(), paused (corked) after a couple of idle
// seconds, and reopened on the new device when the default output changes.
class SoundMixer : public QObject
{
public:
    static SoundMixer *instance()
    {
        static SoundMixer *mixer = new SoundMixer(QCoreApplication::instance());
        return mixer;
    }

    void play(GameSound *owner, std::shared_ptr<const SoundSample> sample, float gain, int loops);
    void stopOwner(GameSound *owner);
    void setOwnerGain(GameSound *owner, float gain);

private:
    struct Voice
    {
        GameSound *owner;
        quint64 generation;
        std::shared_ptr<const SoundSample> sample;
        double pos = 0.0;    // in source frames
        float gain = 1.f;
        int loops = 1;       // plays left, or GameSound::Infinite
    };

    // The pull-mode device the sink reads mixed audio from.
    class Output : public QIODevice
    {
    public:
        explicit Output(SoundMixer *mixer) : m_mixer(mixer) {}
        bool isSequential() const override { return true; }
        qint64 bytesAvailable() const override { return QIODevice::bytesAvailable() + (1 << 16); }
    protected:
        qint64 readData(char *data, qint64 maxlen) override { return m_mixer->render(data, maxlen); }
        qint64 writeData(const char *, qint64) override { return -1; }
    private:
        SoundMixer *m_mixer;
    };

    explicit SoundMixer(QObject *parent);
    ~SoundMixer() override { closeSink(); }   // before m_output, which the sink reads
    bool ensureRunning();
    void closeSink();
    qint64 render(char *data, qint64 maxlen);
    bool mixVoice(Voice &v, float *out, qint64 frames, int channels, int rate);
    void endVoice(const Voice &v);

    static constexpr int kMaxVoices = 32;
    static constexpr int kMaxVoicesPerSound = 4;

    QMediaDevices m_devices;
    QAudioDevice m_device;
    QAudioFormat m_format;
    QAudioSink *m_sink = nullptr;
    Output m_output{ this };
    QTimer m_idle;
    int m_idleTicks = 0;

    QMutex m_lock;                // guards m_voices; render() may run on the audio thread
    std::vector<Voice> m_voices;
    std::vector<float> m_mix;
};

SoundMixer::SoundMixer(QObject *parent) : QObject(parent)
{
    m_output.open(QIODevice::ReadOnly | QIODevice::Unbuffered);

    // Pause the stream once nothing has played for a couple of seconds, as SoundEffect
    // did, so an idle game keeps no audio device busy. Two idle checks in a row means
    // the last sound has also drained from the sink's buffer, so no tail of it is held
    // back to play late on resume.
    m_idle.setInterval(1000);
    connect(&m_idle, &QTimer::timeout, this, [this] {
        bool idle;
        {
            QMutexLocker lock(&m_lock);
            idle = m_voices.empty();
        }
        m_idleTicks = idle ? m_idleTicks + 1 : 0;
        if (m_idleTicks >= 2 && m_sink && m_sink->state() != QAudio::SuspendedState
            && m_sink->state() != QAudio::StoppedState)
            m_sink->suspend();
    });

    // Qt opens the stream on a named device, so it would not follow a new default output
    // (headphones plugged in, say). Reopen it on the new default when that changes.
    connect(&m_devices, &QMediaDevices::audioOutputsChanged, this, [this] {
        if (m_sink && QMediaDevices::defaultAudioOutput() != m_device) {
            closeSink();
            bool busy;
            {
                QMutexLocker lock(&m_lock);
                busy = !m_voices.empty();
            }
            if (busy)
                ensureRunning();
        }
    });
}

void SoundMixer::closeSink()
{
    if (!m_sink)
        return;
    m_idle.stop();
    m_sink->stop();
    delete m_sink;
    m_sink = nullptr;
}

bool SoundMixer::ensureRunning()
{
    if (m_sink && m_sink->state() == QAudio::StoppedState && m_sink->error() != QAudio::NoError)
        closeSink();   // the stream broke (device gone, server restarted): open a new one

    if (!m_sink) {
        m_device = QMediaDevices::defaultAudioOutput();
        if (m_device.isNull())
            return false;
        QAudioFormat format;
        format.setSampleRate(48000);
        format.setChannelCount(2);
        format.setSampleFormat(QAudioFormat::Float);
        if (!m_device.isFormatSupported(format))
            format = m_device.preferredFormat();
        // Name the speaker positions, or PipeWire labels the channels aux0, aux1, ...
        if (format.channelConfig() == QAudioFormat::ChannelConfigUnknown)
            format.setChannelConfig(
                    QAudioFormat::defaultChannelConfigForChannelCount(format.channelCount()));
        m_format = format;
        m_sink = new QAudioSink(m_device, m_format, this);
        m_sink->setBufferSize(m_format.bytesForDuration(60000));   // about 60 ms of latency
        m_sink->start(&m_output);
        m_idle.start();
        qCDebug(lcGameSound) << "opened" << m_device.description() << m_format;
        return true;
    }

    m_idleTicks = 0;
    if (m_sink->state() == QAudio::SuspendedState)
        m_sink->resume();
    return true;
}

void SoundMixer::play(GameSound *owner, std::shared_ptr<const SoundSample> sample, float gain, int loops)
{
    if (!sample || sample->frames == 0)
        return;
    {
        QMutexLocker lock(&m_lock);
        // Keep the voice count bounded: a sound that is retriggered fast drops its own
        // oldest voice, and a full mixer drops the oldest voice overall.
        const auto mine = std::count_if(m_voices.begin(), m_voices.end(),
                                        [owner](const Voice &v) { return v.owner == owner; });
        if (mine >= kMaxVoicesPerSound) {
            auto oldest = std::find_if(m_voices.begin(), m_voices.end(),
                                       [owner](const Voice &v) { return v.owner == owner; });
            endVoice(*oldest);
            m_voices.erase(oldest);
        }
        if (int(m_voices.size()) >= kMaxVoices) {
            endVoice(m_voices.front());
            m_voices.erase(m_voices.begin());
        }
        m_voices.push_back(Voice{ owner, owner->m_generation, std::move(sample), 0.0, gain,
                                  loops == 0 ? 1 : loops });
    }
    ensureRunning();
}

void SoundMixer::stopOwner(GameSound *owner)
{
    QMutexLocker lock(&m_lock);
    std::erase_if(m_voices, [owner](const Voice &v) { return v.owner == owner; });
}

void SoundMixer::setOwnerGain(GameSound *owner, float gain)
{
    QMutexLocker lock(&m_lock);
    for (Voice &v : m_voices)
        if (v.owner == owner)
            v.gain = gain;
}

// Called with m_lock held, which also keeps the owner alive (~GameSound takes the lock
// first). The note is posted to the owner's thread; Qt drops it if the owner is deleted.
void SoundMixer::endVoice(const Voice &v)
{
    GameSound *owner = v.owner;
    const quint64 generation = v.generation;
    QMetaObject::invokeMethod(owner, [owner, generation] { owner->voiceEnded(generation); },
                              Qt::QueuedConnection);
}

// Adds one voice into `out`, resampling with linear interpolation. Returns false once
// the voice has finished.
bool SoundMixer::mixVoice(Voice &v, float *out, qint64 frames, int channels, int rate)
{
    const SoundSample &s = *v.sample;
    const int sc = s.channels;
    const float *src = s.data.data();
    const double step = double(s.rate) / rate;
    const bool looping = v.loops == GameSound::Infinite || v.loops > 1;

    for (qint64 f = 0; f < frames; ++f) {
        if (v.pos >= s.frames) {
            if (v.loops == GameSound::Infinite) {
                v.pos -= s.frames;
            } else if (v.loops > 1) {
                v.pos -= s.frames;
                --v.loops;
            } else {
                return false;
            }
        }
        const qint64 i = qint64(v.pos);
        const float t = float(v.pos - double(i));
        const qint64 j = i + 1 < s.frames ? i + 1 : (looping ? 0 : i);
        const float *a = src + i * sc;
        const float *b = src + j * sc;
        const float left = a[0] + (b[0] - a[0]) * t;
        const float right = sc > 1 ? a[1] + (b[1] - a[1]) * t : left;

        float *o = out + f * channels;
        if (channels == 1) {
            o[0] += 0.5f * (left + right) * v.gain;
        } else {
            o[0] += left * v.gain;
            o[1] += right * v.gain;
        }
        v.pos += step;
    }
    return v.pos < s.frames || v.loops == GameSound::Infinite || v.loops > 1;
}

qint64 SoundMixer::render(char *data, qint64 maxlen)
{
    const int channels = m_format.channelCount();
    const int bytesPerFrame = m_format.bytesPerFrame();
    if (channels <= 0 || bytesPerFrame <= 0)
        return 0;
    const qint64 frames = maxlen / bytesPerFrame;
    if (frames <= 0)
        return 0;

    const size_t count = size_t(frames) * channels;
    if (m_mix.size() < count)
        m_mix.resize(count);
    std::fill_n(m_mix.begin(), count, 0.f);
    {
        QMutexLocker lock(&m_lock);
        for (auto it = m_voices.begin(); it != m_voices.end();) {
            if (mixVoice(*it, m_mix.data(), frames, channels, m_format.sampleRate())) {
                ++it;
            } else {
                endVoice(*it);
                it = m_voices.erase(it);
            }
        }
    }

    const float *mix = m_mix.data();
    switch (m_format.sampleFormat()) {
    case QAudioFormat::Float: {
        float *out = reinterpret_cast<float *>(data);
        for (size_t i = 0; i < count; ++i)
            out[i] = std::clamp(mix[i], -1.f, 1.f);
        break;
    }
    case QAudioFormat::Int16: {
        qint16 *out = reinterpret_cast<qint16 *>(data);
        for (size_t i = 0; i < count; ++i)
            out[i] = qint16(std::clamp(mix[i], -1.f, 1.f) * 32767.f);
        break;
    }
    case QAudioFormat::Int32: {
        qint32 *out = reinterpret_cast<qint32 *>(data);
        for (size_t i = 0; i < count; ++i)
            out[i] = qint32(double(std::clamp(mix[i], -1.f, 1.f)) * 2147483647.0);
        break;
    }
    case QAudioFormat::UInt8: {
        quint8 *out = reinterpret_cast<quint8 *>(data);
        for (size_t i = 0; i < count; ++i)
            out[i] = quint8(128 + std::clamp(mix[i], -1.f, 1.f) * 127.f);
        break;
    }
    default:
        std::memset(data, 0, size_t(frames * bytesPerFrame));
        break;
    }
    return frames * bytesPerFrame;
}

// ── GameSound ───────────────────────────────────────────────────────────────────────

GameSound::GameSound(QObject *parent) : QObject(parent) {}

GameSound::~GameSound()
{
    SoundMixer::instance()->stopOwner(this);
}

void GameSound::setSource(const QUrl &url)
{
    if (url == m_source)
        return;
    stop();
    m_source = url;
    m_sample.reset();
    emit sourceChanged();

    if (url.isEmpty()) {
        setStatus(Null);
        return;
    }
    QString error;
    m_sample = loadWav(url, &error);
    if (!m_sample)
        qWarning("GameSound: cannot load %s: %s", qPrintable(url.toString()), qPrintable(error));
    setStatus(m_sample ? Ready : Error);
}

void GameSound::setVolume(qreal volume)
{
    volume = std::clamp(volume, 0.0, 1.0);
    if (qFuzzyCompare(volume, m_volume))
        return;
    m_volume = volume;
    SoundMixer::instance()->setOwnerGain(this, float(m_volume));
    emit volumeChanged();
}

void GameSound::setLoops(int loops)
{
    if (loops == m_loops)
        return;
    m_loops = loops;
    emit loopsChanged();
}

void GameSound::play()
{
    if (m_status != Ready)
        return;
    const bool looping = m_loops == Infinite || m_loops > 1;
    if (looping && m_active > 0)
        return;
    SoundMixer::instance()->play(this, m_sample, float(m_volume), m_loops);
    if (++m_active == 1)
        emit playingChanged();
}

void GameSound::stop()
{
    ++m_generation;
    SoundMixer::instance()->stopOwner(this);
    if (m_active > 0) {
        m_active = 0;
        emit playingChanged();
    }
}

void GameSound::voiceEnded(quint64 generation)
{
    if (generation != m_generation || m_active == 0)
        return;
    if (--m_active == 0)
        emit playingChanged();
}

void GameSound::setStatus(Status status)
{
    if (status == m_status)
        return;
    m_status = status;
    emit statusChanged();
}
