#include "qmlbackend.h"
#include <QSettings>
#include "qmlsettings.h"
#include "qmlmainwindow.h"
#include "streamsession.h"
#include "controllermanager.h"
#include "psnaccountid.h"
#include "psntoken.h"
#include "jsonrequester.h"
#include <QJsonObject>
#include <QJsonArray>
#include "systemdinhibit.h"
#include "chiaki/remote/holepunch.h"
#ifdef Q_OS_MACOS
#include "macWakeSleep.h"
#elif defined(Q_OS_WINDOWS)
#include "windowsWakeSleep.h"
#endif
#if CHIAKI_GUI_ENABLE_STEAM_SHORTCUT
#include "steamtools.h"
#endif

#ifdef CHIAKI_HAVE_WEBENGINE
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
#include <QWebEngineClientHints>
#endif
#include <QWebEngineCookieStore>
#endif
#include <QUrlQuery>
#include <QMetaObject>
#include <QtGlobal>
#include <QGuiApplication>
#include <QPixmap>
#include <QImageReader>
#include <QProcessEnvironment>
#include <QDesktopServices>
#include <QtConcurrent>
#include <QTimer>

extern "C" {
#include <chiaki/time.h>
#include <libavcodec/avcodec.h>
#include <libavutil/pixdesc.h>
#include <libavutil/pixfmt.h>
}

static bool detailedVerboseTelemetryEnabled()
{
    return qEnvironmentVariableIntValue("CHIAKI_VERBOSE_LOG_NOISE") == 1;
}

#define CHIAKI_NOISY_DEBUG() if (!detailedVerboseTelemetryEnabled()) {} else qCDebug(chiakiGui)

static void logDecoderDeliveryStats(qint64 now_us, int32_t frames_lost, bool recovered)
{
    static qint64 last_sample_us = 0;
    static qint64 last_log_us = 0;
    static qint64 min_interval_us = 0;
    static qint64 max_interval_us = 0;
    static qint64 sum_interval_us = 0;
    static int samples = 0;
    static int lost_samples = 0;
    static int recovered_samples = 0;

    if (frames_lost > 0)
        lost_samples += frames_lost;
    if (recovered)
        recovered_samples++;

    if (last_sample_us != 0) {
        const qint64 interval_us = now_us - last_sample_us;
        if (min_interval_us == 0 || interval_us < min_interval_us)
            min_interval_us = interval_us;
        if (interval_us > max_interval_us)
            max_interval_us = interval_us;
        sum_interval_us += interval_us;
        samples++;
    }
    last_sample_us = now_us;

    if (last_log_us == 0)
        last_log_us = now_us;
    else if (now_us - last_log_us >= 1000000 && samples > 0) {
        CHIAKI_NOISY_DEBUG().nospace()
            << "[decode] arrival interval_us_min=" << min_interval_us
            << " interval_us_max=" << max_interval_us
            << " interval_us_avg=" << (sum_interval_us / samples)
            << " frames_lost=" << lost_samples
            << " recovered=" << recovered_samples
            << " samples=" << samples;
        last_log_us = now_us;
        min_interval_us = 0;
        max_interval_us = 0;
        sum_interval_us = 0;
        samples = 0;
        lost_samples = 0;
        recovered_samples = 0;
    }
}

static void logDecoderHandoffStats(qint64 now_us, qint64 handoff_us, double pts)
{
    static qint64 last_log_us = 0;
    static qint64 min_handoff_us = 0;
    static qint64 max_handoff_us = 0;
    static qint64 sum_handoff_us = 0;
    static int samples = 0;

    if (handoff_us < 0)
        handoff_us = 0;
    if (handoff_us >= 12000) {
        CHIAKI_NOISY_DEBUG().nospace()
            << "[decode] handoff_outlier_us=" << handoff_us
            << " pts=" << pts;
    }
    if (min_handoff_us == 0 || handoff_us < min_handoff_us)
        min_handoff_us = handoff_us;
    if (handoff_us > max_handoff_us)
        max_handoff_us = handoff_us;
    sum_handoff_us += handoff_us;
    samples++;

    if (last_log_us == 0)
        last_log_us = now_us;
    else if (now_us - last_log_us >= 1000000 && samples > 0) {
        CHIAKI_NOISY_DEBUG().nospace()
            << "[decode] handoff_us_min=" << min_handoff_us
            << " handoff_us_max=" << max_handoff_us
            << " handoff_us_avg=" << (sum_handoff_us / samples)
            << " pts=" << pts
            << " samples=" << samples;
        last_log_us = now_us;
        min_handoff_us = 0;
        max_handoff_us = 0;
        sum_handoff_us = 0;
        samples = 0;
    }
}

static void logDecoderFramePtsStats(qint64 now_us, double pts, float duration)
{
    static qint64 last_log_us = 0;
    static double last_pts = -1.0;
    static qint64 min_interval_us = 0;
    static qint64 max_interval_us = 0;
    static qint64 sum_interval_us = 0;
    static qint64 min_duration_us = 0;
    static qint64 max_duration_us = 0;
    static qint64 sum_duration_us = 0;
    static int samples = 0;

    if (last_pts >= 0.0) {
        const qint64 interval_us = static_cast<qint64>((pts - last_pts) * 1000000.0 + 0.5);
        if (min_interval_us == 0 || interval_us < min_interval_us)
            min_interval_us = interval_us;
        if (interval_us > max_interval_us)
            max_interval_us = interval_us;
        sum_interval_us += interval_us;
        samples++;
    }
    last_pts = pts;

    const qint64 duration_us = static_cast<qint64>(duration * 1000000.0 + 0.5);
    if (min_duration_us == 0 || duration_us < min_duration_us)
        min_duration_us = duration_us;
    if (duration_us > max_duration_us)
        max_duration_us = duration_us;
    sum_duration_us += duration_us;

    if (last_log_us == 0)
        last_log_us = now_us;
    else if (now_us - last_log_us >= 1000000 && samples > 0) {
        CHIAKI_NOISY_DEBUG().nospace()
            << "[decode] pts interval_us_min=" << min_interval_us
            << " interval_us_max=" << max_interval_us
            << " interval_us_avg=" << (sum_interval_us / samples)
            << " duration_us_min=" << min_duration_us
            << " duration_us_max=" << max_duration_us
            << " duration_us_avg=" << (sum_duration_us / samples)
            << " samples=" << samples;
        last_log_us = now_us;
        min_interval_us = 0;
        max_interval_us = 0;
        sum_interval_us = 0;
        min_duration_us = 0;
        max_duration_us = 0;
        sum_duration_us = 0;
        samples = 0;
    }
}

static inline bool frame_has_planes(const AVFrame *frame)
{
    if (!frame)
        return false;
    if (frame->hw_frames_ctx)
        return true; // zero copy frames still map via hw context
    const int planes = av_pix_fmt_count_planes(static_cast<AVPixelFormat>(frame->format));
    return frame->data[0] && planes > 0;
}

static bool frame_can_use_direct_render(const AVFrame *frame, bool use_opengl_renderer)
{
    if (!frame || !frame->hw_frames_ctx)
        return true;

    switch (frame->format) {
    case AV_PIX_FMT_VULKAN:
        return true;
#ifdef Q_OS_LINUX
    case AV_PIX_FMT_VAAPI:
        return !use_opengl_renderer;
#endif
    default:
        return false;
    }
}

#define PSN_DEVICES_TRIES 2
#define MAX_PSN_RECONNECT_TRIES 6
#define PSN_INTERNET_WAIT_SECONDS 5
#define WAKEUP_PSN_IGNORE_SECONDS 10
#define WAKEUP_WAIT_SECONDS 25
static QMutex chiaki_log_mutex;
static ChiakiLog *chiaki_log_ctx = nullptr;
static QtMessageHandler qt_msg_handler = nullptr;

static void msg_handler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QMutexLocker lock(&chiaki_log_mutex);
    if (!chiaki_log_ctx) {
        qt_msg_handler(type, context, msg);
        return;
    }
    ChiakiLogLevel chiaki_level;
    switch (type) {
    case QtDebugMsg:
        chiaki_level = CHIAKI_LOG_DEBUG;
        break;
    case QtInfoMsg:
        chiaki_level = CHIAKI_LOG_INFO;
        break;
    case QtWarningMsg:
        chiaki_level = CHIAKI_LOG_WARNING;
        break;
    case QtCriticalMsg:
        chiaki_level = CHIAKI_LOG_ERROR;
        break;
    case QtFatalMsg:
        chiaki_level = CHIAKI_LOG_ERROR;
        break;
    }
    chiaki_log(chiaki_log_ctx, chiaki_level, "%s", qPrintable(msg));
}

QmlRegist::QmlRegist(const ChiakiRegistInfo &regist_info, uint32_t log_mask, QObject *parent)
    : QObject(parent)
{
    chiaki_log_init(&chiaki_log, log_mask, &QmlRegist::log_cb, this);
    chiaki_regist_start(&chiaki_regist, &chiaki_log, &regist_info, &QmlRegist::regist_cb, this);
}

void QmlRegist::log_cb(ChiakiLogLevel level, const char *msg, void *user)
{
    chiaki_log_cb_print(level, msg, nullptr);
    auto r = static_cast<QmlRegist*>(user);
    QMetaObject::invokeMethod(r, std::bind(&QmlRegist::log, r, level, QString::fromUtf8(msg)), Qt::QueuedConnection);
}

void QmlRegist::regist_cb(ChiakiRegistEvent *event, void *user)
{
    auto r = static_cast<QmlRegist*>(user);
    switch (event->type) {
    case CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS:
        QMetaObject::invokeMethod(r, std::bind(&QmlRegist::success, r, *event->registered_host), Qt::QueuedConnection);
        QMetaObject::invokeMethod(r, &QObject::deleteLater, Qt::QueuedConnection);
        break;
    case CHIAKI_REGIST_EVENT_TYPE_FINISHED_FAILED:
        QMetaObject::invokeMethod(r, &QmlRegist::failed, Qt::QueuedConnection);
        QMetaObject::invokeMethod(r, &QObject::deleteLater, Qt::QueuedConnection);
        break;
    default:
        break;
    }
}

QmlBackend::QmlBackend(Settings *settings, QmlMainWindow *window)
    : QObject(window)
    , settings(settings)
    , settings_qml(new QmlSettings(settings, this))
    , window(window)
{
    qt_msg_handler = qInstallMessageHandler(msg_handler);

    const char *uri = "org.streetpea.chiaking";
    qmlRegisterSingletonInstance(uri, 1, 0, "Chiaki", this);
    qmlRegisterUncreatableType<QmlMainWindow>(uri, 1, 0, "ChiakiWindow", {});
    qmlRegisterUncreatableType<QmlSettings>(uri, 1, 0, "ChiakiSettings", {});
    qmlRegisterUncreatableType<StreamSession>(uri, 1, 0, "ChiakiSession", {});

    QObject *frame_obj = new QObject();
    frame_thread = new QThread(frame_obj);
    frame_thread->setObjectName("frame");
    frame_thread->start();
    frame_obj->moveToThread(frame_thread);

    PsnConnectionWorker *worker = new PsnConnectionWorker;
    worker->moveToThread(&psn_connection_thread);
    connect(&psn_connection_thread, &QThread::finished, worker, &QObject::deleteLater);
    connect(this, &QmlBackend::psnConnect, worker, &PsnConnectionWorker::ConnectPsnConnection);
    connect(worker, &PsnConnectionWorker::resultReady, this, &QmlBackend::checkPsnConnection);
    connect(&psn_hosts_watcher, &QFutureWatcher<void>::finished, [this]{ this->updating_psn_hosts = false; });
    psn_connection_thread.start();

    setConnectState(PsnConnectState::NotStarted);
    connect(settings_qml, &QmlSettings::audioVolumeChanged, this, &QmlBackend::updateAudioVolume);
    connect(settings_qml, &QmlSettings::placeboChanged, window, &QmlMainWindow::updatePlacebo);
        connect(settings_qml,
            &QmlSettings::vSyncEnabledChanged,
            window,
            &QmlMainWindow::updateVSync,
            Qt::QueuedConnection);
    connect(settings_qml,
            &QmlSettings::vulkanDeferredSwapChanged,
            window,
            &QmlMainWindow::updateVulkanDeferredSwap,
            Qt::QueuedConnection);
    connect(settings_qml, &QmlSettings::streamMenuEnabledChanged, this, &QmlBackend::updateStreamShortcut);
    connect(settings_qml, &QmlSettings::streamMenuShortcut1Changed, this, &QmlBackend::updateStreamShortcut);
    connect(settings_qml, &QmlSettings::streamMenuShortcut2Changed, this, &QmlBackend::updateStreamShortcut);
    connect(settings_qml, &QmlSettings::streamMenuShortcut3Changed, this, &QmlBackend::updateStreamShortcut);
    connect(settings_qml, &QmlSettings::streamMenuShortcut4Changed, this, &QmlBackend::updateStreamShortcut);
    connect(settings, &Settings::RegisteredHostsUpdated, this, &QmlBackend::hostsChanged);
    connect(settings, &Settings::HiddenHostsUpdated, this, &QmlBackend::hiddenHostsChanged);
    connect(settings, &Settings::ManualHostsUpdated, this, &QmlBackend::hostsChanged);
    connect(settings, &Settings::CurrentProfileChanged, this, &QmlBackend::profileChanged);
    connect(&discovery_manager, &DiscoveryManager::HostsUpdated, this, &QmlBackend::updateDiscoveryHosts);
    discovery_manager.SetSettings(settings);
    setDiscoveryEnabled(true);
    connect(ControllerManager::GetInstance(), &ControllerManager::AvailableControllersUpdated, this, &QmlBackend::updateControllers);
    connect(settings_qml, &QmlSettings::allowJoystickBackgroundEventsChanged, this, &QmlBackend::setAllowJoystickBackgroundEvents);
    connect(window, &QmlMainWindow::activeChanged, this, &QmlBackend::setIsAppActive);
    connect(this, &QmlBackend::sessionChanged, this, &QmlBackend::setIsAppActive);
    setAllowJoystickBackgroundEvents();
    setIsAppActive();
    ControllerManager::GetInstance()->SetIsAppActive(window->isActive());
    updateControllers();
    updateControllerMappings();
    connect(settings, &Settings::ControllerMappingsUpdated, this, &QmlBackend::updateControllerMappings);
    connect(this, &QmlBackend::controllersChanged, this, &QmlBackend::updateControllerMappings);
    auto_connect_mac = settings->GetAutoConnectHost().GetServerMAC();
    auto_connect_nickname = settings->GetAutoConnectHost().GetServerNickname();
    psn_auto_connect_timer = new QTimer(this);
    psn_auto_connect_timer->setSingleShot(true);
    psn_reconnect_tries = 0;
    psn_reconnect_timer = new QTimer(this);
    wakeup_start_timer = new QTimer(this);
    wakeup_start_timer->setSingleShot(true);
    if(autoConnect() && !auto_connect_nickname.isEmpty())
    {
        connect(psn_auto_connect_timer, &QTimer::timeout, this, [this]
        {
            int i = 0;
            for (const auto &host : std::as_const(psn_hosts))
            {
                if(host.GetName() == auto_connect_nickname)
                {
                    int index = discovery_manager.GetHosts().size() + this->settings->GetManualHosts().size() + i;
                    connectToHost(index);
                    return;
                }
                i++;
            }
            qCWarning(chiakiGui) << "Couldn't find PSN host with the requested nickname: " << auto_connect_nickname;
        });
        psn_auto_connect_timer->start(PSN_INTERNET_WAIT_SECONDS * 1000);
    }
    connect(psn_reconnect_timer, &QTimer::timeout, this, [this]{
        QString refresh = this->settings->GetPsnRefreshToken();
        if(refresh.isEmpty())
        {
            qCWarning(chiakiGui) << "No refresh token found, can't refresh PSN token to use PSN remote connection";
            psn_reconnect_tries = 0;
            resume_session = false;
            psn_reconnect_timer->stop();
            setConnectState(PsnConnectState::ConnectFailed);
            return;
        }
        PSNToken *psnToken = new PSNToken(this->settings, this);
        connect(psnToken, &PSNToken::PSNTokenError, this, [this](const QString &error) {
            qCWarning(chiakiGui) << "Internet is currently down...waiting 5 seconds" << error;
            psn_reconnect_tries++;
            if(psn_reconnect_tries < MAX_PSN_RECONNECT_TRIES)
                return;
            else
            {
                resume_session = false;
                psn_reconnect_tries = 0;
                psn_reconnect_timer->stop();
                setConnectState(PsnConnectState::ConnectFailed);
            }
        });
        connect(psnToken, &PSNToken::UnauthorizedError, this, &QmlBackend::psnCredsExpired);
        connect(psnToken, &PSNToken::PSNTokenSuccess, this, [this]() {
            qCWarning(chiakiGui) << "PSN Remote Connection Tokens Refreshed. Internet is back up";
            resume_session = false;
            psn_reconnect_tries = 0;
            psn_reconnect_timer->stop();
            createSession(session_info);
        });
        connect(psnToken, &PSNToken::Finished, psnToken, &QObject::deleteLater);
        QString refresh_token = this->settings->GetPsnRefreshToken();
        psnToken->RefreshPsnToken(std::move(refresh_token));
    });
    connect(wakeup_start_timer, &QTimer::timeout, this, [this]
    {
        emit wakeupStartFailed();
    });
    psn_auto_connect_timer->start(PSN_INTERNET_WAIT_SECONDS * 1000);
    sleep_inhibit = new SystemdInhibit(QGuiApplication::applicationName(), tr("Remote Play session"), "sleep", "delay", this);
    connect(sleep_inhibit, &SystemdInhibit::sleep, this, &QmlBackend::goToSleep);
    connect(sleep_inhibit, &SystemdInhibit::resume, this, &QmlBackend::resumeFromSleep);
    connect(ControllerManager::GetInstance(), &ControllerManager::ControllerMoved, sleep_inhibit, &SystemdInhibit::simulateUserActivity);
#ifdef Q_OS_MACOS
    mac_wake_sleep = new MacWakeSleep(this);
    connect(mac_wake_sleep, &MacWakeSleep::wokeUp, this, &QmlBackend::resumeFromSleep);
    connect(ControllerManager::GetInstance(), &ControllerManager::ControllerMoved, mac_wake_sleep, &MacWakeSleep::simulateUserActivity);
#elif defined(Q_OS_WINDOWS)
    windows_wake_sleep = new WindowsWakeSleep(this);
    connect(windows_wake_sleep, &WindowsWakeSleep::wokeUp, this, &QmlBackend::resumeFromSleep);
    connect(windows_wake_sleep, &WindowsWakeSleep::sleeping, this, &QmlBackend::goToSleep);
#endif
    refreshPsnToken();
}

bool QmlBackend::prepareFrameForPresentation(ChiakiFfmpegFrame &frame, bool use_opengl_renderer)
{
    if (!frame.frame)
        return false;

    if (frame.frame->format == AV_PIX_FMT_NONE)
        return false;

    if (!frame.frame->hw_frames_ctx)
        return frame_has_planes(frame.frame);

    const bool direct_render = !disable_zero_copy && frame_can_use_direct_render(frame.frame, use_opengl_renderer);
    if (direct_render)
        return frame_has_planes(frame.frame);

    const int format = frame.frame->format;
    {
        QMutexLocker locker(&hw_transfer_state_mutex);
        if (!logged_hw_transfer_formats.contains(format)) {
            logged_hw_transfer_formats.insert(format);
            const char *format_name = av_get_pix_fmt_name(static_cast<AVPixelFormat>(format));
            qCInfo(chiakiGui) << "Transferring hardware-decoded frames to software for presentation:"
                              << (format_name ? format_name : "unknown");
        }
    }

    AVFrame *sw_frame = av_frame_alloc();
    if (!sw_frame)
        return false;

    if (av_hwframe_transfer_data(sw_frame, frame.frame, 0) < 0) {
        bool should_log_failure = false;
        {
            QMutexLocker locker(&hw_transfer_state_mutex);
            if (!logged_hw_transfer_failures.contains(format)) {
                logged_hw_transfer_failures.insert(format);
                should_log_failure = true;
            }
        }
        if (should_log_failure) {
            const char *format_name = av_get_pix_fmt_name(static_cast<AVPixelFormat>(format));
            qCWarning(chiakiGui) << "Failed to transfer hardware frame for presentation:"
                                 << (format_name ? format_name : "unknown");
        }
        av_frame_free(&sw_frame);
        return false;
    }

    av_frame_copy_props(sw_frame, frame.frame);
    av_frame_free(&frame.frame);
    frame.frame = sw_frame;
    return frame_has_planes(frame.frame);
}

QmlBackend::~QmlBackend()
{
    if(session)
    {
        chiaki_log_mutex.lock();
        chiaki_log_ctx = nullptr;
        chiaki_log_mutex.unlock();
        session->deleteLater();
        session = nullptr;
    }
#ifdef CHIAKI_HAVE_WEBENGINE
    if(request_interceptor)
        request_interceptor->deleteLater();
#endif
    frame_thread->quit();
    frame_thread->wait();
    frame_thread->parent()->deleteLater();
    psn_connection_thread.quit();
    psn_connection_thread.wait();
}

QmlMainWindow *QmlBackend::qmlWindow() const
{
    return window;
}

QmlSettings *QmlBackend::qmlSettings() const
{
    return settings_qml;
}

StreamSession *QmlBackend::qmlSession() const
{
    return session;
}

void QmlBackend::updateAudioVolume()
{
    if(session)
        session->SetAudioVolume(settings->GetAudioVolume());
}

void QmlBackend::goToSleep()
{
    qCInfo(chiakiGui) << "About to sleep";
    if (session) {
        if (this->settings->GetSuspendAction() == SuspendAction::Sleep)
            session->GoToBed();
        session->Stop();
        if(!session_info.duid.isEmpty())
            psnCancel(true);
        resume_session = true;
    }
}
void QmlBackend::resumeFromSleep()
{
#ifdef Q_OS_WINDOWS
    if(windows_wake_sleep->getWakeState() == WindowsWakeState::AboutToSleep)
    {
        windows_wake_sleep->setWakeState(WindowsWakeState::Awake);
        return;
    }
    windows_wake_sleep->setWakeState(WindowsWakeState::Awake);
#endif
    if (resume_session) {
        qCInfo(chiakiGui) << "Resuming session...";
        resume_session = false;
        if(session_info.duid.isEmpty())
        {
            createSession({
                session_info.settings,
                session_info.target,
                session_info.host,
                session_info.nickname,
                session_info.regist_key,
                session_info.morning,
                session_info.initial_login_pin,
                session_info.duid,
                session_info.auto_regist,
                session_info.fullscreen,
                session_info.zoom,
                session_info.stretch,
            });
        }
        else
        {
            emit showPsnView();
            setConnectState(PsnConnectState::WaitingForInternet);
            psn_reconnect_timer->start(PSN_INTERNET_WAIT_SECONDS * 1000);
        }
    }
}

QList<QmlController*> QmlBackend::qmlControllers() const
{
    return controllers.values();
}

void QmlBackend::profileChanged()
{
    QString profile = settings->GetCurrentProfile();
    Settings *settings_copy = new Settings(profile);
    if(settings_allocd)
        settings->deleteLater();
    settings_allocd = true;
    settings = settings_copy;
    emit hostsChanged();
    updateControllerMappings();
    connect(settings, &Settings::RegisteredHostsUpdated, this, &QmlBackend::hostsChanged);
    connect(settings, &Settings::HiddenHostsUpdated, this, &QmlBackend::hiddenHostsChanged);
    connect(settings, &Settings::ManualHostsUpdated, this, &QmlBackend::hostsChanged);
    connect(settings, &Settings::CurrentProfileChanged, this, &QmlBackend::profileChanged);
    connect(settings, &Settings::ControllerMappingsUpdated, this, &QmlBackend::updateControllerMappings);
    settings_qml->setSettings(settings);
    discovery_manager.SetSettings(settings);
    window->setSettings(settings);
    setDiscoveryEnabled(true);

    auto_connect_mac = settings->GetAutoConnectHost().GetServerMAC();
    auto_connect_nickname = settings->GetAutoConnectHost().GetServerNickname();
    psn_reconnect_timer->deleteLater();
    psn_auto_connect_timer->deleteLater();
    psn_auto_connect_timer = new QTimer(this);
    psn_auto_connect_timer->setSingleShot(true);
    psn_reconnect_tries = 0;
    psn_reconnect_timer = new QTimer(this);
    if(autoConnect() && !auto_connect_nickname.isEmpty())
    {
        connect(psn_auto_connect_timer, &QTimer::timeout, this, [this]
        {
            int i = 0;
            for (const auto &host : std::as_const(psn_hosts))
            {
                if(host.GetName() == auto_connect_nickname)
                {
                    int index = discovery_manager.GetHosts().size() + this->settings->GetManualHosts().size() + i;
                    connectToHost(index);
                    return;
                }
                i++;
            }
            qCWarning(chiakiGui) << "Couldn't find PSN host with the requested nickname: " << auto_connect_nickname;
        });
        psn_auto_connect_timer->start(PSN_INTERNET_WAIT_SECONDS * 1000);
    }
    connect(psn_reconnect_timer, &QTimer::timeout, this, [this]{
        QString refresh = this->settings->GetPsnRefreshToken();
        if(refresh.isEmpty())
        {
            qCWarning(chiakiGui) << "No refresh token found, can't refresh PSN token to use PSN remote connection";
            psn_reconnect_tries = 0;
            resume_session = false;
            psn_reconnect_timer->stop();
            setConnectState(PsnConnectState::ConnectFailed);
            return;
        }
        PSNToken *psnToken = new PSNToken(this->settings, this);
        connect(psnToken, &PSNToken::PSNTokenError, this, [this](const QString &error) {
            qCWarning(chiakiGui) << "Internet is currently down...waiting 5 seconds" << error;
            psn_reconnect_tries++;
            if(psn_reconnect_tries < MAX_PSN_RECONNECT_TRIES)
                return;
            else
            {
                resume_session = false;
                psn_reconnect_tries = 0;
                psn_reconnect_timer->stop();
                setConnectState(PsnConnectState::ConnectFailed);
            }
        });
        connect(psnToken, &PSNToken::UnauthorizedError, this, &QmlBackend::psnCredsExpired);
        connect(psnToken, &PSNToken::PSNTokenSuccess, this, []() {
            qCWarning(chiakiGui) << "PSN Remote Connection Tokens Refreshed. Internet is back up";
        });
        connect(psnToken, &PSNToken::PSNTokenSuccess, this, [this]() {
            resume_session = false;
            psn_reconnect_tries = 0;
            psn_reconnect_timer->stop();
            createSession(session_info);
        });
        connect(psnToken, &PSNToken::Finished, psnToken, &QObject::deleteLater);
        QString refresh_token = this->settings->GetPsnRefreshToken();
        psnToken->RefreshPsnToken(std::move(refresh_token));
    });
    sleep_inhibit->deleteLater();
    sleep_inhibit = new SystemdInhibit(QGuiApplication::applicationName(), tr("Remote Play session"), "sleep", "delay", this);
    connect(sleep_inhibit, &SystemdInhibit::sleep, this, &QmlBackend::goToSleep);
    connect(sleep_inhibit, &SystemdInhibit::resume, this, &QmlBackend::resumeFromSleep);
    connect(ControllerManager::GetInstance(), &ControllerManager::ControllerMoved, sleep_inhibit, &SystemdInhibit::simulateUserActivity);
#ifdef Q_OS_MACOS
    mac_wake_sleep->deleteLater();
    mac_wake_sleep = new MacWakeSleep(this);
    connect(mac_wake_sleep, &MacWakeSleep::wokeUp, this, &QmlBackend::resumeFromSleep);
    connect(ControllerManager::GetInstance(), &ControllerManager::ControllerMoved, mac_wake_sleep, &MacWakeSleep::simulateUserActivity);
#elif defined(Q_OS_WINDOWS)
    windows_wake_sleep->deleteLater();
    windows_wake_sleep = new WindowsWakeSleep(this);
    connect(windows_wake_sleep, &WindowsWakeSleep::wokeUp, this, &QmlBackend::resumeFromSleep);
    connect(windows_wake_sleep, &WindowsWakeSleep::sleeping, this, &QmlBackend::goToSleep);
#endif
    refreshPsnToken();
    emit hostsChanged();
    emit hiddenHostsChanged();
}

bool QmlBackend::discoveryEnabled() const
{
    return discovery_manager.GetActive();
}

void QmlBackend::setDiscoveryEnabled(bool enabled)
{
    discovery_manager.SetActive(enabled);
    emit discoveryEnabledChanged();
}

QmlBackend::PsnConnectState QmlBackend::connectState() const
{
    return psn_connect_state;
}

void QmlBackend::checkNickname(QString nickname)
{
    if(!session)
        return;
    if(!settings->GetNicknameRegisteredHostRegistered(nickname))
    {
        emit error(tr("PS4 Console Unregistered"), tr("Can't proceed...please register your PS4 console locally"));
        session->Stop();
    }
}

void QmlBackend::setConnectState(PsnConnectState connect_state)
{
    psn_connect_state = connect_state;
    if(connect_state == PsnConnectState::ConnectFailed)
    {
        if(!this->settings->GetGeometry().isEmpty())
        {
            window->setGeometry(this->settings->GetGeometry());
            window->normalTime();
        }
        else
            window->showMaximized();
    }
    emit connectStateChanged();
}

QVariantList QmlBackend::hosts() const
{
    QVariantList out;
    QList<QString> discovered_nicknames;
    QList<ManualHost> discovered_manual_hosts;
    size_t registered_discovered_ps4s = 0;
    auto manual_hosts = settings->GetManualHosts();
    for (const auto &host : discovery_manager.GetHosts()) {
        QVariantMap m;
        HostMAC host_mac = host.GetHostMAC();
        bool registered = settings->GetRegisteredHostRegistered(host_mac);
        bool hidden = settings->GetHiddenHostHidden(host_mac);
        if(registered && hidden)
        {
            settings->RemoveHiddenHost(host_mac);
            bool hidden = false;
        }
        // Update hidden host nickname if it's changed
        if(hidden)
        {
            auto hidden_host = settings->GetHiddenHost(host_mac);
            if(hidden_host.GetNickname() != host.host_name)
            {
                hidden_host.SetNickname(host.host_name);
                settings->RemoveHiddenHost(host_mac);
                settings->AddHiddenHost(hidden_host);
            }
        }
        m["discovered"] = true;
        bool manual = false;
        for(int i = 0; i < manual_hosts.length(); i++)
        {
            const auto &manual_host = manual_hosts.at(i);
            if(manual_host.GetRegistered() && manual_host.GetMAC() == host_mac && manual_host.GetHost() == host.host_addr)
            {
                manual = true;
                discovered_manual_hosts.append(manual_host);
            }
        }
        m["manual"] = manual;
        m["name"] = host.host_name;
        QString duid = "";
        if(!registered)
        {
            if(psn_nickname_hosts.contains(host.host_name))
                duid = psn_nickname_hosts.value(host.host_name).GetDuid();
            else if(!host.ps5)
                duid =  psn_nickname_hosts.value(QString("Main PS4 Console")).GetDuid();
        }
        m["duid"] = duid;
        m["address"] = host.host_addr;
        m["ps5"] = host.ps5;
        m["mac"] = host_mac.ToString();
        m["state"] = chiaki_discovery_host_state_string(host.state);
        m["app"] = host.running_app_name;
        m["titleId"] = host.running_app_titleid;
        m["registered"] = registered;
        m["display"] = hidden ? false : true;
        discovered_nicknames.append(host.host_name);
        out.append(m);
        if(!host.ps5 && registered)
            registered_discovered_ps4s++;
    }
    for (const auto &host : settings->GetManualHosts()) {
        QVariantMap m;
        m["discovered"] = false;
        m["manual"] = true;
        m["name"] = host.GetHost();
        m["duid"] = "";
        m["address"] = host.GetHost();
        m["state"] = "unknown";
        m["registered"] = false;
        m["display"] = discovered_manual_hosts.contains(host) ? false : true;
        if (host.GetRegistered() && settings->GetRegisteredHostRegistered(host.GetMAC())) {
            auto registered = settings->GetRegisteredHost(host.GetMAC());
            m["registered"] = true;
            m["name"] = registered.GetServerNickname();
            m["ps5"] = chiaki_target_is_ps5(registered.GetTarget());
            m["mac"] = registered.GetServerMAC().ToString();
        }
        out.append(m);
    }
    if(registered_discovered_ps4s >= settings->GetPS4RegisteredHostsRegistered())
        discovered_nicknames.append(QString("Main PS4 Console"));
    for (const auto &host : psn_hosts) {
        QVariantMap m;
        // Only list PSN remote hosts that aren't discovered locally
        bool discovered = false;
        for (int i = 0; i < discovered_nicknames.size(); ++i)
        {
            if (discovered_nicknames.at(i) == host.GetName())
                discovered = true;
        }
        for (int i = 0; i < waking_sleeping_nicknames.size(); ++i)
        {
            if (waking_sleeping_nicknames.at(i) == host.GetName())
                discovered = true;
        }
        if(discovered)
            continue;
        m["discovered"] = false;
        m["manual"] = false;
        m["display"] = true;
        m["name"] = host.GetName();
        m["duid"] = host.GetDuid();
        m["address"] = "";
        m["registered"] = true;
        m["ps5"] = host.IsPS5();
        out.append(m);
    }
    // démonstration : MACNPLAY_DEMO_PS5=1 ajoute une fausse PS5 pour voir l'accueil avec deux consoles
    if (qEnvironmentVariableIsSet("MACNPLAY_DEMO_PS5")) {
        QVariantMap m;
        m["demo"] = true;
        m["discovered"] = true;
        m["manual"] = false;
        m["display"] = true;
        m["name"] = "PS5-Salon";
        m["duid"] = "";
        m["address"] = "192.168.1.72";
        m["ps5"] = true;
        m["mac"] = "000000000000";
        m["state"] = "standby";
        m["app"] = "";
        m["registered"] = true;
        out.append(m);
    }
    return out;
}

bool QmlBackend::autoConnect() const
{
    return auto_connect_mac.GetValue();
}

void QmlBackend::psnCancel(bool stop_thread)
{
    session->CancelPsnConnection(stop_thread);
}

void QmlBackend::checkPsnConnection(const ChiakiErrorCode &err)
{
    switch(err)
    {
        case CHIAKI_ERR_SUCCESS:
            setConnectState(PsnConnectState::LinkingConsole);
            psnSessionStart();
            break;
        case CHIAKI_ERR_HOST_DOWN:
            setConnectState(PsnConnectState::ConnectFailedStart);
            if(session)
            {
                chiaki_log_mutex.lock();
                chiaki_log_ctx = nullptr;
                chiaki_log_mutex.unlock();
                session->deleteLater();
                session = nullptr;
                setDiscoveryEnabled(true);
            }
            break;
        case CHIAKI_ERR_HOST_UNREACH:
            setConnectState(PsnConnectState::ConnectFailedConsoleUnreachable);
            if(session)
            {
                chiaki_log_mutex.lock();
                chiaki_log_ctx = nullptr;
                chiaki_log_mutex.unlock();
                session->deleteLater();
                session = nullptr;
                setDiscoveryEnabled(true);
            }
            break;
        default:
            setConnectState(PsnConnectState::ConnectFailed);
            if(session)
            {
                chiaki_log_mutex.lock();
                chiaki_log_ctx = nullptr;
                chiaki_log_mutex.unlock();
                session->deleteLater();
                session = nullptr;
                setDiscoveryEnabled(true);
            }
            break;
    }
}

void QmlBackend::psnSessionStart()
{
    startSession(true);
}

void QmlBackend::startSession(bool emit_session_changed)
{
    if (window)
        window->armVerbosePlaceboQuietWindow();

    applyStartupWindowSizing();
    if (emit_session_changed)
        prepareStartupPresentation(true);

    try {
        session->Start();
    } catch (const Exception &e) {
        StreamSession *failed_session = session;
        session = nullptr;
        chiaki_log_mutex.lock();
        chiaki_log_ctx = nullptr;
        chiaki_log_mutex.unlock();
        if (window) {
            emit sessionChanged(nullptr);
            window->resetPlaceboQueue();
            window->requestOverlayUpdate();
        }
        failed_session->deleteLater();
        emit error(tr("Stream failed"), tr("Failed to start Stream Session: %1").arg(e.what()));
        return;
    }

    if (emit_session_changed)
        emit sessionChanged(session);

    sleep_inhibit->inhibit();
}

// Une PS4 classique ne propose pas de 1080p, une PS4 Pro oui : on coche ou décoche
// « PS4 Pro » pour cette console (même réglage que la case de la page « L'essentiel »).
void QmlBackend::checkPs4Pro(StreamSession *checked_session)
{
    if (session != checked_session || pro_check_mac.isEmpty())
        return;
    const int height = checked_session->GetMaxStreamHeight();
    if (height <= 0)
        return;
    const QString mac = pro_check_mac;
    pro_check_mac.clear();

    QSettings prefs;
    QStringList pro_hosts = prefs.value("macnplay/ps4ProHosts").toString().split(",", Qt::SkipEmptyParts);
    const bool is_pro = height >= pro_check_requested_height;
    qCInfo(chiakiGui) << "PS4" << mac << "propose jusqu'a" << height << "p :" << (is_pro ? "PS4 Pro" : "PS4 classique");
    if (is_pro && !pro_hosts.contains(mac))
        pro_hosts.append(mac);
    if (!is_pro)
    {
        pro_hosts.removeAll(mac);
        // la prochaine partie demandera directement le maximum de cette console
        settings->SetResolutionLocalPS4(CHIAKI_VIDEO_RESOLUTION_PRESET_720p);
        settings->SetBitrateLocalPS4(0);
    }
    prefs.setValue("macnplay/ps4ProHosts", pro_hosts.join(","));
}

void QmlBackend::createSession(const StreamSessionConnectInfo &connect_info)
{
    pending_recovered_frame.storeRelaxed(0);

    if (autoConnect()) {
        auto_connect_mac = {};
        emit autoConnectChanged();
    }

    if (session) {
        qCWarning(chiakiGui) << "Another session is already active";
        return;
    }

    session_info = connect_info;
    window->setStreamMaxFPS(connect_info.video_profile.max_fps);
    disable_zero_copy = !settings->GetUseZeroCopy();
    {
        QMutexLocker locker(&hw_transfer_state_mutex);
        logged_hw_transfer_formats.clear();
        logged_hw_transfer_failures.clear();
    }
    QStringList availableDecoders = settings_qml->availableDecoders();
    if (!session_info.hw_decoder.isEmpty()
        && session_info.hw_decoder != "auto"
        && session_info.hw_decoder != "none"
        && !availableDecoders.contains(session_info.hw_decoder)) {
        qCInfo(chiakiGui) << "Configured hw decoder" << session_info.hw_decoder
                          << "is not currently available, falling back to auto";
        session_info.hw_decoder = "auto";
    }
    bool use_opengl_renderer = window && window->runtimeRendererBackend() == static_cast<int>(RenderBackend::OpenGL);
    bool prefer_cuda = window && window->nvidiaCard() && availableDecoders.contains("cuda");
    auto fallbackVulkanDecoderForOpenGL = [&]() {
        if (!use_opengl_renderer || session_info.hw_decoder != "vulkan")
            return;

        bool fallbackApplied = false;
#if defined(Q_OS_LINUX)
        if (prefer_cuda)
        {
            qCInfo(chiakiGui) << "Renderer backend is OpenGL, falling back from vulkan decoder to cuda";
            session_info.hw_decoder = "cuda";
            fallbackApplied = true;
        }
        else
        if (availableDecoders.contains("vaapi"))
        {
            qCInfo(chiakiGui) << "Renderer backend is OpenGL, falling back from vulkan decoder to vaapi";
            session_info.hw_decoder = "vaapi";
            fallbackApplied = true;
        }
#elif defined(Q_OS_WIN)
        if (prefer_cuda)
        {
            qCInfo(chiakiGui) << "Renderer backend is OpenGL, falling back from vulkan decoder to cuda";
            session_info.hw_decoder = "cuda";
            fallbackApplied = true;
        }
        else
        if (availableDecoders.contains("d3d11va"))
        {
            qCInfo(chiakiGui) << "Renderer backend is OpenGL, falling back from vulkan decoder to d3d11va";
            session_info.hw_decoder = "d3d11va";
            fallbackApplied = true;
        }
#elif defined(Q_OS_MACOS)
        if (availableDecoders.contains("videotoolbox"))
        {
            qCInfo(chiakiGui) << "Renderer backend is OpenGL, falling back from vulkan decoder to videotoolbox";
            session_info.hw_decoder = "videotoolbox";
            fallbackApplied = true;
        }
#endif
        if (!fallbackApplied)
        {
            qCInfo(chiakiGui) << "Renderer backend is OpenGL, falling back from vulkan decoder to software decoder";
            session_info.hw_decoder.clear();
        }
    };
    if(session_info.hw_decoder == "auto")
    {
        session_info.hw_decoder = QString();
#if defined(Q_OS_LINUX)
        if(!use_opengl_renderer && availableDecoders.contains("vulkan"))
        {
            qCInfo(chiakiGui) << "Auto hw decoder selecting vulkan";
            session_info.hw_decoder = "vulkan";
        }
        else if(prefer_cuda)
        {
            qCInfo(chiakiGui) << "Auto hw decoder selecting cuda";
            session_info.hw_decoder = "cuda";
        }
        else if(availableDecoders.contains("vaapi"))
        {
            qCInfo(chiakiGui) << "Auto hw decoder selecting vaapi";
            session_info.hw_decoder = "vaapi";
        }
#elif defined(Q_OS_WIN)
        if(!use_opengl_renderer && availableDecoders.contains("vulkan"))
        {
            qCInfo(chiakiGui) << "Auto hw decoder selecting vulkan";
            session_info.hw_decoder = "vulkan";
        }
        else if(prefer_cuda)
        {
            qCInfo(chiakiGui) << "Auto hw decoder selecting cuda";
            session_info.hw_decoder = "cuda";
        }
        else if(availableDecoders.contains("d3d11va"))
        {
            qCInfo(chiakiGui) << "Auto hw decoder selecting d3d11va";
            session_info.hw_decoder = "d3d11va";
        }
#elif defined(Q_OS_MACOS)
        if(availableDecoders.contains("videotoolbox"))
        {
            qCInfo(chiakiGui) << "Auto hw decoder selecting videotoolbox";
            session_info.hw_decoder = "videotoolbox";
        }
#endif
    }
    fallbackVulkanDecoderForOpenGL();
    if (session_info.hw_decoder == "vulkan") {
        session_info.hw_device_ctx = window->vulkanHwDeviceCtx();
        if (!session_info.hw_device_ctx)
        {
            session_info.hw_decoder.clear();
            qCInfo(chiakiGui) << "vulkan video decoding not supported by your gpu driver, retrying other hw video decoders";
#if defined(Q_OS_LINUX)
            if(prefer_cuda)
            {
                qCInfo(chiakiGui) << "Falling back to cuda";
                session_info.hw_decoder = "cuda";
            }
            else if(availableDecoders.contains("vaapi"))
            {
                qCInfo(chiakiGui) << "Falling back to vaapi";
                session_info.hw_decoder = "vaapi";
            }
#elif defined(Q_OS_WIN)
            if(prefer_cuda)
            {
                qCInfo(chiakiGui) << "Falling back to cuda";
                session_info.hw_decoder = "cuda";
            }
            else if(availableDecoders.contains("d3d11va"))
            {
                qCInfo(chiakiGui) << "Falling back to d3d11va";
                session_info.hw_decoder = "d3d11va";
            }
#endif
        }
        if(session_info.hw_decoder.isEmpty())
            qCInfo(chiakiGui) << "Falling back to software decoder";
    }

    try {
        session = new StreamSession(session_info, this);
    } catch (const Exception &e) {
        emit error(tr("Stream failed"), tr("Failed to initialize Stream Session: %1").arg(e.what()));
        return;
    }

    connect(session, &StreamSession::FfmpegFrameAvailable, frame_thread->parent(), [this, use_opengl_renderer]() {
        ChiakiFfmpegDecoder *decoder = session->GetFfmpegDecoder();
        if (!decoder) {
            qCCritical(chiakiGui) << "Session has no FFmpeg decoder";
            return;
        }
        int32_t frames_lost;
        ChiakiFfmpegFrame frame = chiaki_ffmpeg_decoder_pull_frame(decoder, &frames_lost);
        if (!frame.frame)
            return;
        logDecoderDeliveryStats(static_cast<qint64>(chiaki_time_now_monotonic_us()), frames_lost, frame.recovered);
        logDecoderFramePtsStats(static_cast<qint64>(chiaki_time_now_monotonic_us()), frame.pts, frame.duration);
        if (frame.recovered)
            pending_recovered_frame.storeRelaxed(1);

        const qint64 prepare_begin_us = static_cast<qint64>(chiaki_time_now_monotonic_us());
        if (!prepareFrameForPresentation(frame, use_opengl_renderer))
        {
            av_frame_free(&frame.frame);
            return;
        }
        const qint64 prepare_end_us = static_cast<qint64>(chiaki_time_now_monotonic_us());
        if (prepare_end_us >= prepare_begin_us && prepare_end_us - prepare_begin_us >= 5000) {
            CHIAKI_NOISY_DEBUG().nospace()
                << "[decode] prepare_frame_us=" << (prepare_end_us - prepare_begin_us)
                << " pts=" << frame.pts;
        }

        if (pending_recovered_frame.fetchAndStoreRelaxed(0) != 0) {
            frame.recovered = true;
        }

        const qint64 delivery_us = static_cast<qint64>(chiaki_time_now_monotonic_us());
        QmlMainWindow *target_window = window;
        QMetaObject::invokeMethod(target_window, [target_window, frame, frames_lost, delivery_us]() mutable {
            target_window->presentFrame(frame, frames_lost, delivery_us);
        });
    });

    StreamSession *session_for_connections = session;
    connect(session, &StreamSession::SessionQuit, this, [this, session_for_connections](ChiakiQuitReason reason, const QString &reason_str) {
        if (session != session_for_connections)
            return;

        // relance après un changement de qualité : la console garde l'ancienne connexion
        // quelques secondes (« Remote is already in use ») ; on réessaie sans afficher d'erreur
        const bool retry_restart = restart_retrying && !session_for_connections->IsConnected() && restart_tries < 15;
        if (session_for_connections->IsConnected())
            restart_retrying = false;
        if (chiaki_quit_reason_is_error(reason) && !retry_restart) {
            restart_retrying = false;
            QString m = tr("Chiaki Session has quit") + ":\n" + tr(chiaki_quit_reason_string(reason));
            if (!reason_str.isEmpty())
                m += "\n" + tr("Reason") + ": \"" + reason_str + "\"";
            // une PS4 qui refuse la partie en 1080p avant même de démarrer : c'est une PS4 classique
            if (!pro_check_mac.isEmpty() && !session_for_connections->IsConnected()) {
                QSettings prefs;
                QStringList pro_hosts = prefs.value("macnplay/ps4ProHosts").toString().split(",", Qt::SkipEmptyParts);
                pro_hosts.removeAll(pro_check_mac);
                prefs.setValue("macnplay/ps4ProHosts", pro_hosts.join(","));
                settings->SetResolutionLocalPS4(CHIAKI_VIDEO_RESOLUTION_PRESET_720p);
                settings->SetBitrateLocalPS4(0);
                pro_check_mac.clear();
                m += "\n\n" + tr("This PS4 does not accept 1080p, so it is not a PS4 Pro. Image quality is now 720p: start the game again.");
            }
            emit sessionError(tr("Session has quit"), m);
        }

        chiaki_log_mutex.lock();
        chiaki_log_ctx = nullptr;
        chiaki_log_mutex.unlock();
        pending_recovered_frame.storeRelaxed(0);
        {
            QMutexLocker locker(&hw_transfer_state_mutex);
            logged_hw_transfer_formats.clear();
            logged_hw_transfer_failures.clear();
        }

        session_for_connections->deleteLater();
        session = nullptr;
        emit sessionChanged(session);

        sleep_inhibit->release();
        setDiscoveryEnabled(true);
        // relance demandée depuis le menu en jeu (autre qualité)
        if (restart_pending) {
            restart_pending = false;
            restart_retrying = true;
            restart_tries = 0;
            QTimer::singleShot(1500, this, [this] { restartCreateSession(); });
        } else if (retry_restart) {
            restart_tries++;
            qCInfo(chiakiGui) << "Console still busy after quality change, retry" << restart_tries;
            QTimer::singleShot(1500, this, [this] { restartCreateSession(); });
        }
#ifdef Q_OS_WINDOWS
        qCInfo(chiakiGui) << "Checking sleep state: ";
        if(windows_wake_sleep->getWakeState() == WindowsWakeState::Awake)
            QTimer::singleShot(2000, this, &QmlBackend::resumeFromSleep);
        else
            windows_wake_sleep->setWakeState(WindowsWakeState::Sleeping);
#endif
    });

    connect(session, &StreamSession::LoginPINRequested, this, [this, connect_info](bool incorrect) {
        if (!connect_info.initial_login_pin.isEmpty() && incorrect == false)
            session->SetLoginPIN(connect_info.initial_login_pin);
        else
            emit sessionPinDialogRequested();
    });

    connect(session, &StreamSession::DataHolepunchProgress, this, [this](bool finished) {
        if(finished)
        {
            setConnectState(PsnConnectState::DataConnectionFinished);
        }
        else
            setConnectState(PsnConnectState::DataConnectionStart);
    });

    connect(session, &StreamSession::NicknameReceived, this, &QmlBackend::checkNickname);

    connect(session, &StreamSession::AutoRegistSucceeded, this, &QmlBackend::finishAutoRegister);

    connect(session, &StreamSession::ConnectedChanged, this, [this, session_for_connections]() {
        if (session != session_for_connections)
            return;

        if (session_for_connections->IsConnected())
        {
            setDiscoveryEnabled(false);
            // la liste des tailles d'image arrive juste après la connexion
            if (!pro_check_mac.isEmpty())
                QTimer::singleShot(4000, this, [this, session_for_connections]() { checkPs4Pro(session_for_connections); });
        }
    });
    chiaki_log_mutex.lock();
    chiaki_log_ctx = session->GetChiakiLog();
    chiaki_log_mutex.unlock();

    if(connect_info.duid.isEmpty())
    {
        if(!wakeup_nickname.isEmpty())
        {
            wakeup_start = true;
            wakeup_start_timer->start(WAKEUP_WAIT_SECONDS * 1000);
            emit wakeupStartInitiated();
            QTimer::singleShot(0, this, &QmlBackend::updateDiscoveryHosts);
        }
        else
        {
            startSession(true);
        }
    }
    else
    {
        setDiscoveryEnabled(false);
        emit showPsnView();
        if(session_info.auto_regist)
            setConnectState(PsnConnectState::RegisteringConsole);
        else
            setConnectState(PsnConnectState::InitiatingConnection);
            emit psnConnect(session, session_info.duid, chiaki_target_is_ps5(session_info.target));
    }
}

bool QmlBackend::closeRequested()
{
    if (!session)
        return true;

    bool stop = true;
    if (session->IsConnected()) {
        switch (settings->GetDisconnectAction()) {
        case DisconnectAction::Ask:
            stop = false;
            emit sessionStopDialogRequested();
            break;
        case DisconnectAction::AlwaysSleep:
            session->GoToBed();
            break;
        default:
            break;
        }
    }

    if (stop)
        session->Stop();

    return false;
}

void QmlBackend::deleteHost(int index)
{
    auto server = displayServerAt(index);
    auto id = server.manual_host.GetID();
    if (!server.valid || (id < 0))
        return;
    settings->RemoveManualHost(id);
}

void QmlBackend::wakeUpHost(int index, QString nickname)
{
    auto server = displayServerAt(index);
    if (!server.valid)
        return;
    if (!server.registered)
        return;
    if (!nickname.isEmpty())
    {
        waking_sleeping_nicknames.append(nickname);
        QTimer::singleShot(WAKEUP_PSN_IGNORE_SECONDS * 1000, [this, nickname]{
            waking_sleeping_nicknames.removeOne(nickname);
            emit hostsChanged();
        });
    }
    const QString wake_host = server.GetHostAddr();
    const QByteArray wake_regist_key = server.registered_host.GetRPRegistKey();
    const bool wake_ps5 = server.IsPS5();
    QTimer::singleShot(0, this, [this, wake_host, wake_regist_key, wake_ps5]() {
        if(!sendWakeup(wake_host, wake_regist_key, wake_ps5))
            qCWarning(chiakiGui) << "Couldn't wakeup server";
    });
}

void QmlBackend::setConsolePin(int index, QString console_pin)
{
    auto server = displayServerAt(index);
    if (!server.valid)
        return;
    server.registered_host.SetConsolePin(server.registered_host, std::move(console_pin));
    settings->AddRegisteredHost(server.registered_host);
}

void QmlBackend::addManualHost(int index, const QString &address)
{
    HostMAC hmac;
    QList<RegisteredHost> registered_hosts = settings->GetRegisteredHosts();
    bool registered = (index >= 0 && (index < registered_hosts.length()));
    if (registered)
        hmac = registered_hosts.at(index).GetServerMAC();
    ManualHost host(-1, address, registered, hmac);
    settings->SetManualHost(host);
}

void QmlBackend::hideHost(const QString &mac_string, const QString &host_nickname)
{
    QByteArray mac_array = QByteArray::fromHex(mac_string.toUtf8());
    if (mac_array.size() != 6)
    {
        qCCritical(chiakiGui) << "Invalid host mac:" << mac_string.toUtf8();
        qCCritical(chiakiGui) << "Aborting hidden host creation because mac string couldn't be converted to a valid host mac!";
        qCCritical(chiakiGui) << "Received an array of unexpected size. Expected: 6 bytes, Received:" << mac_array.size() << "bytes";
        return;
    }
    HostMAC mac((const uint8_t *)mac_array.constData());
    HiddenHost hidden_host(mac, host_nickname);
    settings->AddHiddenHost(hidden_host);
    emit hostsChanged();
}

void QmlBackend::unhideHost(const QString &mac_string)
{
    QByteArray mac_array = QByteArray::fromHex(mac_string.toUtf8());
    const char *mac_ptr = mac_array.constData();
    if (strlen(mac_ptr) != 6)
    {
        qCCritical(chiakiGui) << " Aborting hidden host creation because mac string couldn't be converted to a valid host mac!";
        return;
    }
    HostMAC mac((const uint8_t *)mac_ptr);
    settings->RemoveHiddenHost(mac);
    emit hostsChanged();
}

QVariantList QmlBackend::hiddenHosts() const
{
    QVariantList out;
    for (const auto &host : settings->GetHiddenHosts()) {
        QVariantMap m;
        m["name"] = host.GetNickname();
        m["mac"] = host.GetMAC().ToString();
        out.append(m);
    }
    return out;
}


bool QmlBackend::registerHost(const QString &host, const QString &psn_id, const QString &pin, const QString &cpin, bool broadcast, int target, const QJSValue &callback)
{
    ChiakiRegistInfo info = {};
    QByteArray hostb = host.toUtf8();
    info.host = hostb.constData();
    info.target = static_cast<ChiakiTarget>(target);
    info.broadcast = broadcast;
    info.pin = (uint32_t)pin.toULong();
    info.console_pin = (uint32_t)cpin.toULong();
    info.holepunch_info = nullptr;
    info.rudp = nullptr;
    QByteArray psn_idb;
    if (target == CHIAKI_TARGET_PS4_8) {
        psn_idb = psn_id.toUtf8();
        info.psn_online_id = psn_idb.constData();
    } else {
        QByteArray account_id = QByteArray::fromBase64(psn_id.toUtf8());
        if (account_id.size() != CHIAKI_PSN_ACCOUNT_ID_SIZE) {
            emit error(tr("Invalid Account-ID"), tr("The PSN Account-ID must be exactly %1 bytes encoded as base64.").arg(CHIAKI_PSN_ACCOUNT_ID_SIZE));
            return false;
        }
        info.psn_online_id = nullptr;
        memcpy(info.psn_account_id, account_id.constData(), CHIAKI_PSN_ACCOUNT_ID_SIZE);
    }
    auto regist = new QmlRegist(info, settings->GetLogLevelMask(), this);
    connect(regist, &QmlRegist::log, this, [callback](ChiakiLogLevel level, QString msg) {
        QJSValue cb = callback;
        if (cb.isCallable())
            cb.call({QString("[%1] %2").arg(chiaki_log_level_char(level)).arg(msg), true, false});
    });
    connect(regist, &QmlRegist::failed, this, [this, callback]() {
        QJSValue cb = callback;
        if (cb.isCallable())
            cb.call({QString(), false, true});

        regist_dialog_server = {};
    });
    connect(regist, &QmlRegist::success, this, [this, host, callback](const RegisteredHost &rhost) {
        QJSValue cb = callback;
        if (cb.isCallable())
            cb.call({QString(), true, true});

        settings->AddRegisteredHost(rhost);
        if(regist_dialog_server.discovered == false)
        {
            ManualHost manual_host = regist_dialog_server.manual_host;
            if(manual_host.GetHost().isEmpty())
                manual_host.SetHost(host);
            manual_host.Register(rhost);
            settings->SetManualHost(manual_host);
        }
    });
    return true;
}

void QmlBackend::autoRegister()
{
    const auto &server = regist_dialog_server;
    resume_session = false;
    StreamSessionConnectInfo info(
            settings,
            server.discovery_host.target,
            QString(),
            QString(),
            QByteArray(),
            QByteArray(),
            0,
            server.duid,
            true,
            false,
            false,
            false);

    QString expiry_s = settings->GetPsnAuthTokenExpiry();
    QString refresh = settings->GetPsnRefreshToken();
    if(expiry_s.isEmpty() || refresh.isEmpty())
        return;
    QDateTime expiry = QDateTime::fromString(expiry_s, settings->GetTimeFormat());
    // give 1 minute buffer
    QDateTime now = QDateTime::currentDateTime().addSecs(60);
    if(now.secsTo(expiry) < 1)
    {
        PSNToken *psnToken = new PSNToken(settings, this);
        connect(psnToken, &PSNToken::PSNTokenError, this, [this](const QString &error) {
            qCWarning(chiakiGui) << "Could not refresh token. Automatic PSN Connection Unavailable!" << error;
        });
        connect(psnToken, &PSNToken::UnauthorizedError, this, &QmlBackend::psnCredsExpired);
        connect(psnToken, &PSNToken::PSNTokenSuccess, this, []() {
            qCWarning(chiakiGui) << "PSN Remote Connection Tokens Refreshed.";
        });
        connect(psnToken, &PSNToken::PSNTokenSuccess, this, [this, info]() {
            createSession(info);
        });
        connect(psnToken, &PSNToken::Finished, psnToken, &QObject::deleteLater);
        QString refresh_token = settings->GetPsnRefreshToken();
        psnToken->RefreshPsnToken(std::move(refresh_token));
    }
    else
        createSession(info);
}

void QmlBackend::finishAutoRegister(const ChiakiRegisteredHost &host)
{
    QString nickname(host.server_nickname);
    if(!regist_dialog_server.discovery_host.ps5 && regist_dialog_server.discovery_host.host_name != nickname)
    {
        emit error(tr("PS4 Console Not Main"), tr("Can't proceed...%1 is not your main PS4 console in PSN").arg(regist_dialog_server.discovery_host.host_name));
        return;
    }
    settings->AddRegisteredHost(host);
    setConnectState(PsnConnectState::RegistrationFinished);
    updatePsnHosts();
}

#ifdef CHIAKI_HAVE_WEBENGINE
void QmlBackend::clearCookies(QQuickWebEngineProfile *profile)
{
    auto cookieStore = profile->cookieStore();
    cookieStore->deleteAllCookies();
}

void QmlBackend::setWebEngineHints(QQuickWebEngineProfile *profile)
{
    QDate starting_release_date(2025, 02, 18);
    QDate today = QDate::currentDate();
    auto daysSinceStart = starting_release_date.daysTo(today);
    qint64 versionsSinceStart = daysSinceStart / 28;
    qint64 release = 133 + versionsSinceStart;
    QString chrome_version = QString::number(release);
    auto userAgent = profile->httpUserAgent();
    userAgent = userAgent.replace(QRegularExpression(" \\bQtWebEngine[^ ]*\\b"), "");
    userAgent = userAgent.replace(QRegularExpression("\\bChrome[^ ]*\\b"), QString("Chrome/%1.0.0.0").arg(chrome_version));
#ifdef Q_OS_WINDOWS
    userAgent = userAgent.replace("Windows NT 6.2", "Windows NT 10.0");
    userAgent += QString(" Edg/%1.0.0.0").arg(chrome_version);
#endif
    profile->setHttpUserAgent(userAgent);
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
    auto hints = profile->clientHints();
    hints->setFullVersion(QString("%1.0.0.0").arg(chrome_version));
    QMap<QString, QVariant> fullVersionList;
    fullVersionList.insert("Not A(Brand", "99.0.0.0");
#ifdef Q_OS_WINDOWS
    fullVersionList.insert("Microsoft Edge", QString("%1.0.0.0").arg(chrome_version));
#else
    fullVersionList.insert("Google Chrome", QString("%1.0.0.0").arg(chrome_version));
#endif
    fullVersionList.insert("Chromium", QString("%1.0.0.0").arg(chrome_version));
    hints->setFullVersionList(fullVersionList);
#endif
    request_interceptor = new SecUaRequestInterceptor(chrome_version);
    profile->setUrlRequestInterceptor(request_interceptor);
}
#endif

void QmlBackend::connectToHost(int index, QString nickname)
{
    window->setWindowAdjustable(false);
    auto server = displayServerAt(index);
    if (!server.valid)
        return;

    if (!server.registered) {
        regist_dialog_server = server;
        emit registDialogRequested(server.GetHostAddr(), server.IsPS5(), server.duid);
        return;
    }

    // les réglages propres à cette console (qualité, fluidité…) s'appliquent à la partie
    if (server.registered_host.GetServerMAC().ToString() != QStringLiteral("000000000000"))
        settings_qml->activateConsole(server.registered_host.GetServerMAC().ToString());

    if (server.discovered && server.discovery_host.state == CHIAKI_DISCOVERY_HOST_STATE_STANDBY)
    {
        const QString wake_host = server.GetHostAddr();
        const QByteArray wake_regist_key = server.registered_host.GetRPRegistKey();
        const bool wake_ps5 = server.IsPS5();
        if(!sendWakeup(wake_host, wake_regist_key, wake_ps5))
        {
            qCWarning(chiakiGui) << "Couldn't wakeup server";
            window->setWindowAdjustable(true);
            return;
        }
        if(nickname.isEmpty())
        {
            qCWarning(chiakiGui) << "No nickname given for registered connection, not connecting...";
            return;
        }
        waking_sleeping_nicknames.append(nickname);
        QTimer::singleShot(WAKEUP_PSN_IGNORE_SECONDS * 1000, [this, nickname]{
            waking_sleeping_nicknames.removeOne(nickname);
            emit hostsChanged();
        });
        wakeup_nickname = nickname;
    }

    bool fullscreen = false, zoom = false, stretch = false;
    switch (settings->GetWindowType()) {
    case WindowType::SelectedResolution:
        break;
    case WindowType::CustomResolution:
        break;
    case WindowType::AdjustableResolution:
        break;
    case WindowType::Fullscreen:
        fullscreen = true;
        break;
    case WindowType::Zoom:
        zoom = true;
        break;
    case WindowType::Stretch:
        stretch = true;
        break;
    default:
        break;
    }
    emit windowTypeUpdated(settings->GetWindowType());

    resume_session = false;
    // une PS4 à qui l'on demande du 1080p : on regardera ce qu'elle propose vraiment
    pro_check_mac.clear();
    if(server.duid.isEmpty() && !server.IsPS5() && settings->GetResolutionLocalPS4() == CHIAKI_VIDEO_RESOLUTION_PRESET_1080p)
    {
        pro_check_mac = server.registered_host.GetServerMAC().ToString();
        pro_check_requested_height = 1080;
    }
    if(server.duid.isEmpty())
    {
        QString host = server.GetHostAddr();
        StreamSessionConnectInfo info(
                settings,
                server.registered_host.GetTarget(),
                std::move(host),
                std::move(nickname),
                server.registered_host.GetRPRegistKey(),
                server.registered_host.GetRPKey(),
                server.registered_host.GetConsolePin(),
                server.duid,
                false,
                fullscreen,
                zoom,
                stretch);
        createSession(info);
    }
    else
    {
        StreamSessionConnectInfo info(
                settings,
                server.psn_host.GetTarget(),
                QString(),
                QString(),
                QByteArray(),
                QByteArray(),
                server.registered_host.GetConsolePin(),
                server.duid,
                false,
                fullscreen,
                zoom,
                stretch);

        QString expiry_s = settings->GetPsnAuthTokenExpiry();
        QString refresh = settings->GetPsnRefreshToken();
        if(expiry_s.isEmpty() || refresh.isEmpty())
            return;
        QDateTime expiry = QDateTime::fromString(expiry_s, settings->GetTimeFormat());
        // give 1 minute buffer
        QDateTime now = QDateTime::currentDateTime().addSecs(60);
        if(now.secsTo(expiry) < 1)
        {
            PSNToken *psnToken = new PSNToken(settings, this);
            connect(psnToken, &PSNToken::PSNTokenError, this, [this](const QString &error) {
                qCWarning(chiakiGui) << "Could not refresh token. Automatic PSN Connection Unavailable!" << error;
            });
            connect(psnToken, &PSNToken::UnauthorizedError, this, &QmlBackend::psnCredsExpired);
            connect(psnToken, &PSNToken::PSNTokenSuccess, this, []() {
                qCWarning(chiakiGui) << "PSN Remote Connection Tokens Refreshed.";
            });
            connect(psnToken, &PSNToken::PSNTokenSuccess, this, [this, info]() {
                createSession(info);
            });
                connect(psnToken, &PSNToken::Finished, psnToken, &QObject::deleteLater);
            QString refresh_token = settings->GetPsnRefreshToken();
            psnToken->RefreshPsnToken(std::move(refresh_token));
        }
        else
            createSession(info);
    }
}

QVariantMap QmlBackend::sessionQuality() const
{
    QVariantMap m;
    if (!session)
        return m;
    const bool ps5 = chiaki_target_is_ps5(session_info.target);
    const bool local = session_info.duid.isEmpty();
    m["ps5"] = ps5;
    m["resolution"] = ps5 ? (local ? settings->GetResolutionLocalPS5() : settings->GetResolutionRemotePS5())
                          : (local ? settings->GetResolutionLocalPS4() : settings->GetResolutionRemotePS4());
    // 1080p : PS5, ou PS4 cochée « PS4 Pro »
    const QStringList pro_hosts = QSettings().value("macnplay/ps4ProHosts").toString().split(",", Qt::SkipEmptyParts);
    m["allow1080"] = ps5 || pro_hosts.contains(settings->GetActiveConsole());
    return m;
}

// changer de qualité en pleine partie : la console fixe la définition à la connexion,
// donc on enregistre la nouvelle valeur (pour cette console), on coupe sans mettre en veille
// et on se reconnecte tout de suite avec la nouvelle qualité
void QmlBackend::restartSessionWithResolution(int preset)
{
    if (!session || restart_pending)
        return;
    const auto resolution = static_cast<ChiakiVideoResolutionPreset>(preset);
    const bool ps5 = chiaki_target_is_ps5(session_info.target);
    const bool local = session_info.duid.isEmpty();
    if (ps5) {
        if (local) { settings->SetResolutionLocalPS5(resolution); settings->SetBitrateLocalPS5(0); }
        else { settings->SetResolutionRemotePS5(resolution); settings->SetBitrateRemotePS5(0); }
    } else {
        if (local) { settings->SetResolutionLocalPS4(resolution); settings->SetBitrateLocalPS4(0); }
        else { settings->SetResolutionRemotePS4(resolution); settings->SetBitrateRemotePS4(0); }
    }
    settings_qml->refreshAllKeys();
    restart_info = session_info;
    restart_info.video_profile = ps5 ? (local ? settings->GetVideoProfileLocalPS5() : settings->GetVideoProfileRemotePS5())
                                     : (local ? settings->GetVideoProfileLocalPS4() : settings->GetVideoProfileRemotePS4());
    restart_pending = true;
    restart_was_fullscreen = window->windowState() == Qt::WindowFullScreen;
    restart_geometry = window->geometry();
    qCInfo(chiakiGui) << "Restarting session with resolution preset" << preset;
    stopSession(false);
}

// relance : on recrée la partie puis on remet la fenêtre comme elle était
// (seule la définition de l'image change, pas la taille de l'affichage)
void QmlBackend::restartCreateSession()
{
    createSession(restart_info);
    if (!window)
        return;
    if (restart_was_fullscreen)
        window->fullscreenTime();
    else if (restart_geometry.isValid())
        window->setGeometry(restart_geometry);
}

void QmlBackend::stopSession(bool sleep)
{
    if (!session)
        return;

    if (!session_info.nickname.isEmpty())
    {
        waking_sleeping_nicknames.append(session_info.nickname);
        QTimer::singleShot(WAKEUP_PSN_IGNORE_SECONDS * 1000, [this]{
            waking_sleeping_nicknames.removeOne(session_info.nickname);
            emit hostsChanged();
        });
    }

    if (sleep)
        session->GoToBed();

    session->Stop();
}

void QmlBackend::sessionGoHome()
{
    if (!session)
        return;

    session->GoHome();
}

void QmlBackend::enterPin(const QString &pin)
{
    qCInfo(chiakiGui) << "Set login pin";
    if (session)
        session->SetLoginPIN(pin);
}

QUrl QmlBackend::psnLoginUrl() const
{
    size_t duid_size = CHIAKI_DUID_STR_SIZE;
    char duid[duid_size];
    chiaki_holepunch_generate_client_device_uid(duid, &duid_size);
    return QUrl(PSNAuth::LOGIN_URL + "duid=" + QString(duid) + "&");
}

bool QmlBackend::handlePsnLoginRedirect(const QUrl &url)
{
    if (!url.toString().startsWith(QString::fromStdString(PSNAuth::REDIRECT_PAGE)))
    {
        emit psnLoginAccountIdError(QString("Redirect URL invalid does not start with:\n") + QString::fromStdString(PSNAuth::REDIRECT_PAGE));
        return false;
    }

    const QString code = QUrlQuery(url).queryItemValue("code");
    if (code.isEmpty()) {
        qCWarning(chiakiGui) << "Invalid code from redirect url";
        emit psnLoginAccountIdError("Redirect URL invalid");
        return false;
    }
    PSNAccountID *psnId = new PSNAccountID(settings, this);
    connect(psnId, &PSNAccountID::AccountIDResponse, this, [this, psnId](const QString &accountId) {
        emit psnLoginAccountIdDone(accountId);
    });
    connect(psnId, &PSNAccountID::AccountIDResponse, this, &QmlBackend::updatePsnHosts);
    connect(psnId, &PSNAccountID::AccountIDError, [this](const QString &error) {
        qCWarning(chiakiGui) << "Could not retrieve psn token or account Id!" << error;
        emit psnLoginAccountIdError(error);
    });
    connect(psnId, &PSNAccountID::Finished, psnId, &QObject::deleteLater);
    psnId->GetPsnAccountId(code);
    emit psnTokenChanged();
    return true;
}

void QmlBackend::stopAutoConnect()
{
    auto_connect_mac = {};
    if(!wakeup_nickname.isEmpty())
    {
        wakeup_start_timer->stop();
        wakeup_nickname.clear();
        if(wakeup_start)
        {
            wakeup_start = false;
            chiaki_log_mutex.lock();
            chiaki_log_ctx = nullptr;
            chiaki_log_mutex.unlock();

            session->deleteLater();
            session = nullptr;
        }
    }
    emit autoConnectChanged();
}

QmlBackend::DisplayServer QmlBackend::displayServerAt(int index) const
{
    if (index < 0)
        return {};
    auto discovered = discovery_manager.GetHosts();
    auto manual = settings->GetManualHosts();
    if (index < discovered.size()) {
        DisplayServer server;
        server.valid = true;
        server.discovered = true;
        server.discovery_host = discovered.at(index);
        auto host_mac = server.discovery_host.GetHostMAC();
        server.registered = settings->GetRegisteredHostRegistered(host_mac);
        QString duid = "";
        if(!server.registered)
        {
            if(psn_nickname_hosts.contains(server.discovery_host.host_name))
                duid = psn_nickname_hosts.value(server.discovery_host.host_name).GetDuid();
            else if(!server.discovery_host.ps5)
                duid =  psn_nickname_hosts.value(QString("Main PS4 Console")).GetDuid();
        }
        server.duid = std::move(duid);
        if (server.registered)
            server.registered_host = settings->GetRegisteredHost(host_mac);
        for (int i = 0; i < manual.size(); i++)
        {
            const auto &manual_host = manual.at(i);
            if(manual_host.GetRegistered() && manual_host.GetMAC() == host_mac && manual_host.GetHost() == server.discovery_host.host_addr)
            {
                server.manual_host = std::move(manual_host);
                break;
            }
        }
        return server;
    }
    index -= discovered.size();
    if (index < manual.size()) {
        DisplayServer server;
        server.valid = true;
        server.discovered = false;
        server.manual_host = manual.at(index);
        server.registered = false;
        server.duid = QString();
        if (server.manual_host.GetRegistered() && settings->GetRegisteredHostRegistered(server.manual_host.GetMAC())) {
            server.registered = true;
            server.registered_host = settings->GetRegisteredHost(server.manual_host.GetMAC());
        }
        return server;
    }
    index -= manual.size();
    if (index < psn_hosts.count())
    {
        DisplayServer server;

        QMapIterator<QString, PsnHost> i(psn_hosts);
        size_t j = 0;
        while (i.hasNext())
        {
            i.next();
            PsnHost psn_host = i.value();
            bool hidden = false;
            for (const auto &host : discovery_manager.GetHosts())
            {
                if(host.host_name == psn_host.GetName())
                    hidden = true;
            }
            if(hidden)
                continue;
            if(j == index)
            {
                server.valid = true;
                server.discovered = false;
                server.psn_host = std::move(psn_host);
                server.duid = i.key();
                server.registered = true;
                server.registered_host = settings->GetNicknameRegisteredHost(server.psn_host.GetName());
                return server;
            }
            j++;
        }
        return {};
    }
    return {};
}

bool QmlBackend::sendWakeup(const DisplayServer &server)
{
    if (!server.registered)
        return false;
    return sendWakeup(server.GetHostAddr(), server.registered_host.GetRPRegistKey(), server.IsPS5());
}

bool QmlBackend::sendWakeup(const QString &host, const QByteArray &regist_key, bool ps5)
{
    try {
        discovery_manager.SendWakeup(host, regist_key, ps5);
        return true;
    } catch (const Exception &e) {
        emit error(tr("Wakeup failed"), tr("Failed to send Wakeup packet:\n%1").arg(e.what()));
        return false;
    }
}

void QmlBackend::setAllowJoystickBackgroundEvents()
{
    ControllerManager::GetInstance()->SetAllowJoystickBackgroundEvents(settings->GetAllowJoystickBackgroundEvents());
}

void QmlBackend::setIsAppActive()
{
    ControllerManager::GetInstance()->SetIsAppActive(window->isActive());
}

uint32_t QmlBackend::getStreamShortcut() const
{
    if(!settings->GetStreamMenuEnabled())
        return 0;
	uint32_t stream_menu_shortcut1 = settings->GetStreamMenuShortcut1();
	if(stream_menu_shortcut1 > 0)
		stream_menu_shortcut1 = 1 << (stream_menu_shortcut1 - 1);
	uint32_t stream_menu_shortcut2 = settings->GetStreamMenuShortcut2();
	if(stream_menu_shortcut2 > 0)
		stream_menu_shortcut2 = 1 << (stream_menu_shortcut2 - 1);
	uint32_t stream_menu_shortcut3 = settings->GetStreamMenuShortcut3();
	if(stream_menu_shortcut3 > 0)
		stream_menu_shortcut3 = 1 << (stream_menu_shortcut3 - 1);
	uint32_t stream_menu_shortcut4 = settings->GetStreamMenuShortcut4();
	if(stream_menu_shortcut4 > 0)
		stream_menu_shortcut4 = 1 << (stream_menu_shortcut4 - 1);
    uint32_t shortcut = stream_menu_shortcut1 | stream_menu_shortcut2 | stream_menu_shortcut3 | stream_menu_shortcut4;
    return shortcut;
}

void QmlBackend::updateStreamShortcut()
{
    uint32_t shortcut = getStreamShortcut();
    for (const auto &controller : std::as_const(controllers)) {
       controller->setEscapeShortcut(shortcut);
    }
}

void QmlBackend::updateControllers()
{
    bool changed = false;
    QMap<QString,QString> controller_mappings = settings->GetControllerMappings();
    for (auto it = controllers.begin(); it != controllers.end();) {
        if (ControllerManager::GetInstance()->GetAvailableControllers().contains(it.key())) {
            it++;
            continue;
        }
        if(it.key() == controller_mapping_id)
        {
            controller_mapping_controller = nullptr;
            controllerMappingQuit();
        }
        QString vidpid = it.value()->GetVIDPID();
        QString guid = it.value()->GetGUID();
        it.value()->deleteLater();
        it = controllers.erase(it);
        changed = true;
    }
    uint32_t stream_shortcut = getStreamShortcut();
    for (auto id : ControllerManager::GetInstance()->GetAvailableControllers()) {
        if (controllers.contains(id))
            continue;
        auto controller = ControllerManager::GetInstance()->OpenController(id);
        if (!controller)
            continue;
        controllers[id] = new QmlController(controller, stream_shortcut ,window, this);
        connect(controllers[id], &QmlController::navButtonCaptured, this, &QmlBackend::navButtonCaptured);
        QString vidpid = controller->GetVIDPIDString();
        QString guid = controller->GetGUIDString();
        QStringList existing_vidpid;
        if(controller_guids_to_update.contains(vidpid))
            existing_vidpid.append(controller_guids_to_update.value(vidpid));
        existing_vidpid.append(guid);
        controller_guids_to_update.insert(vidpid, existing_vidpid);
        // replace old guid with new vid/pid
        if(controller_mappings.contains(guid))
        {
            QString old_mapping = controller_mappings.value(guid);
            qsizetype guid_string_length = old_mapping.indexOf(",") + 1;
            old_mapping.remove(0, guid_string_length);
            settings->RemoveControllerMapping(guid);
            settings->SetControllerMapping(vidpid, old_mapping);
            qCInfo(chiakiGui) << "Migrated controller mapping from platform-specific GUID: " << guid << " to platform-agnostic VID/PID: " << vidpid;
        }
        controller_guids_to_update.insert(vidpid, existing_vidpid);
        connect(controller, &Controller::UpdatingControllerMapping, this, &QmlBackend::controllerMappingUpdate);
        connect(controller, &Controller::NewButtonMapping, this, &QmlBackend::controllerMappingChangeButton);
        changed = true;
    }
    if (changed)
        emit controllersChanged();
}

void QmlBackend::setControllerMappingDefaultMapping(bool is_default_mapping)
{
    if(controller_mapping_default_mapping != is_default_mapping)
    {
        controller_mapping_default_mapping = is_default_mapping;
        emit controllerMappingDefaultMappingChanged();
    }
}

void QmlBackend::setControllerMappingAltered(bool altered)
{
    if(controller_mapping_altered != altered)
    {
        controller_mapping_altered = altered;
        emit controllerMappingAlteredChanged();
    }
}

void QmlBackend::setControllerMappingInProgress(bool is_in_progress)
{
    if(controller_mapping_in_progress != is_in_progress)
    {
        controller_mapping_in_progress = is_in_progress;
        emit controllerMappingInProgressChanged();
    }
}

void QmlBackend::setEnableAnalogStickMapping(bool enabled)
{
    if(enable_analog_stick_mapping != enabled)
    {
        if(controller_mapping_in_progress && controller_mapping_controller)
            controller_mapping_controller->EnableAnalogStickMapping(enabled);
        enable_analog_stick_mapping = enabled;
        emit enableAnalogStickMappingChanged();
    }
}

QVariantList QmlBackend::currentControllerMapping() const
{
    QVariantList out;
    if(!controller_mapping_in_progress)
        return out;
	QMap<int, QStringList> result =
	{
		{CHIAKI_CONTROLLER_BUTTON_CROSS     , controller_mapping_controller_mappings.contains("a") ? controller_mapping_controller_mappings.value("a") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_MOON      , controller_mapping_controller_mappings.contains("b") ? controller_mapping_controller_mappings.value("b") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_BOX       , controller_mapping_controller_mappings.contains("x") ? controller_mapping_controller_mappings.value("x") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_PYRAMID   , controller_mapping_controller_mappings.contains("y") ? controller_mapping_controller_mappings.value("y") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_DPAD_LEFT , controller_mapping_controller_mappings.contains("dpleft") ? controller_mapping_controller_mappings.value("dpleft") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_DPAD_RIGHT, controller_mapping_controller_mappings.contains("dpright") ? controller_mapping_controller_mappings.value("dpright") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_DPAD_UP   , controller_mapping_controller_mappings.contains("dpup") ? controller_mapping_controller_mappings.value("dpup") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_DPAD_DOWN , controller_mapping_controller_mappings.contains("dpdown") ? controller_mapping_controller_mappings.value("dpdown") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_L1        , controller_mapping_controller_mappings.contains("leftshoulder") ? controller_mapping_controller_mappings.value("leftshoulder") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_R1        , controller_mapping_controller_mappings.contains("rightshoulder") ? controller_mapping_controller_mappings.value("rightshoulder") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_L3        , controller_mapping_controller_mappings.contains("leftstick") ? controller_mapping_controller_mappings.value("leftstick") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_R3        , controller_mapping_controller_mappings.contains("rightstick") ? controller_mapping_controller_mappings.value("rightstick") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_OPTIONS   , controller_mapping_controller_mappings.contains("start") ? controller_mapping_controller_mappings.value("start") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_SHARE     , controller_mapping_controller_mappings.contains("back") ? controller_mapping_controller_mappings.value("back") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_TOUCHPAD  , controller_mapping_controller_mappings.contains("touchpad") ? controller_mapping_controller_mappings.value("touchpad") : QStringList()},
		{CHIAKI_CONTROLLER_BUTTON_PS        , controller_mapping_controller_mappings.contains("guide") ? controller_mapping_controller_mappings.value("guide") : QStringList()},
		{CHIAKI_CONTROLLER_ANALOG_BUTTON_L2 , controller_mapping_controller_mappings.contains("lefttrigger") ? controller_mapping_controller_mappings.value("lefttrigger") : QStringList()},
		{CHIAKI_CONTROLLER_ANALOG_BUTTON_R2 , controller_mapping_controller_mappings.contains("righttrigger") ? controller_mapping_controller_mappings.value("righttrigger") : QStringList()},
		{static_cast<int>(ControllerButtonExt::ANALOG_STICK_LEFT_X)   , controller_mapping_controller_mappings.contains("leftx") ? controller_mapping_controller_mappings.value("leftx") : QStringList()},
		{static_cast<int>(ControllerButtonExt::ANALOG_STICK_LEFT_Y)   , controller_mapping_controller_mappings.contains("lefty") ? controller_mapping_controller_mappings.value("lefty") : QStringList()},
		{static_cast<int>(ControllerButtonExt::ANALOG_STICK_RIGHT_X)  , controller_mapping_controller_mappings.contains("rightx") ? controller_mapping_controller_mappings.value("rightx") : QStringList()},
		{static_cast<int>(ControllerButtonExt::ANALOG_STICK_RIGHT_Y)  , controller_mapping_controller_mappings.contains("righty") ? controller_mapping_controller_mappings.value("righty") : QStringList()},
        {static_cast<int>(ControllerButtonExt::MISC1)   ,      controller_mapping_controller_mappings.contains("misc1") ? controller_mapping_controller_mappings.value("misc1") : QStringList()},
	};

    for (auto it = result.cbegin(); it != result.cend(); ++it) {
        QVariantMap m;
        m["buttonName"] = Settings::GetChiakiControllerButtonName(it.key());
        m["buttonValue"] = it.key();
        m["physicalButton"] = it.value();
        out.append(m);
    }
    return out;
}

void QmlBackend::updateControllerMappings()
{
    if(SDL_WasInit(SDL_INIT_GAMECONTROLLER)==0)
        return;
    QMap<QString,QString> controller_mappings = settings->GetControllerMappings();
    QStringList mapping_vidpids = controller_mappings.keys();
    for(int i=0; i<mapping_vidpids.length(); i++)
    {
        QString vidpid = mapping_vidpids.at(i);
        if(!controller_guids_to_update.contains(vidpid))
            continue;
        QStringList guids_to_update = controller_guids_to_update.value(vidpid);
        for(int j=0; j<guids_to_update.length(); j++)
        {
            QString guid = guids_to_update.at(j);
            if(!controller_mapping_original_controller_mappings.contains(guid))
            {
                const SDL_JoystickGUID real_guid = SDL_JoystickGetGUIDFromString(guid.toUtf8().constData());
                const char *mapping = SDL_GameControllerMappingForGUID(real_guid);
                QString original_controller_mapping(mapping);
                SDL_free((char *)mapping);
                if(original_controller_mapping.isEmpty())
                {
                    qCWarning(chiakiGui) << "Error retrieving controller mapping of GUID " << guid << "with error: " << SDL_GetError();
                    return;
                }
                controller_mapping_original_controller_mappings.insert(guid, original_controller_mapping);
            }
            QString controller_mapping_to_add = controller_mappings.value(vidpid);
            controller_mapping_to_add.prepend(QString("%1,").arg(guid));
            int result = SDL_GameControllerAddMapping(controller_mapping_to_add.toUtf8().constData());
            switch(result)
            {
                case -1:
                    qCWarning(chiakiGui) << "Error setting controller mapping for guid: " << guid << " with error: " << SDL_GetError();
                    break;
                case 0:
                    qCInfo(chiakiGui) << "Updated controller mapping for guid: " << guid;
                    break;
                case 1:
                    qCInfo(chiakiGui) << "Added controller mapping for guid: " << guid;
                    break;
                default:
                    qCInfo(chiakiGui) << "Unidentified problem mapping for guid: " << guid;
                    break;
            }
        }
        controller_guids_to_update.remove(vidpid);
    }
}

void QmlBackend::creatingControllerMapping(bool creating_controller_mapping)
{
    ControllerManager::GetInstance()->creatingControllerMapping(creating_controller_mapping);
}

void QmlBackend::beginControllerMapping(bool reset_mapping)
{
    controller_mapping_reset_requested = reset_mapping;
    creatingControllerMapping(true);
    // une seule manette branchée : inutile de la choisir en appuyant sur un de ses boutons
    // (une même manette peut apparaître deux fois avec SDL sur macOS : on compare VID:PID)
    QTimer::singleShot(0, this, [this]() {
        if(controller_mapping_in_progress)
            return;
        Controller *only = nullptr;
        QString only_vid_pid;
        for(auto *c : std::as_const(controllers))
        {
            Controller *controller = c->GetController();
            if(!controller || controller->IsSteamVirtual())
                continue;
            if(only && c->GetVIDPID() != only_vid_pid)
                return;
            only = controller;
            only_vid_pid = c->GetVIDPID();
        }
        if(!only)
            return;
        creatingControllerMapping(false);
        controllerMappingUpdate(only);
    });
}

void QmlBackend::controllerMappingChangeButton(QString button)
{
    if(!controller_mapping_in_progress || !controller_mapping_controller)
        return;
    emit controllerMappingButtonSelected(std::move(button));
}

// nom SDL de chaque bouton PlayStation (« a » = Croix, « dpup » = haut…)
static const QMap<int, QString> &ChiakiButtonSdlNames()
{
	static const QMap<int, QString> button_map =
	{
		{CHIAKI_CONTROLLER_BUTTON_CROSS     , "a"},
		{CHIAKI_CONTROLLER_BUTTON_MOON      , "b"},
		{CHIAKI_CONTROLLER_BUTTON_BOX       , "x"},
		{CHIAKI_CONTROLLER_BUTTON_PYRAMID   , "y"},
		{CHIAKI_CONTROLLER_BUTTON_DPAD_LEFT , "dpleft"},
		{CHIAKI_CONTROLLER_BUTTON_DPAD_RIGHT, "dpright"},
		{CHIAKI_CONTROLLER_BUTTON_DPAD_UP   , "dpup"},
		{CHIAKI_CONTROLLER_BUTTON_DPAD_DOWN , "dpdown"},
		{CHIAKI_CONTROLLER_BUTTON_L1        , "leftshoulder"},
		{CHIAKI_CONTROLLER_BUTTON_R1        , "rightshoulder"},
		{CHIAKI_CONTROLLER_BUTTON_L3        , "leftstick"},
		{CHIAKI_CONTROLLER_BUTTON_R3        , "rightstick"},
		{CHIAKI_CONTROLLER_BUTTON_OPTIONS   , "start"},
		{CHIAKI_CONTROLLER_BUTTON_SHARE     , "back"},
		{CHIAKI_CONTROLLER_BUTTON_TOUCHPAD  , "touchpad"},
		{CHIAKI_CONTROLLER_BUTTON_PS        , "guide"},
		{CHIAKI_CONTROLLER_ANALOG_BUTTON_L2 , "lefttrigger"},
		{CHIAKI_CONTROLLER_ANALOG_BUTTON_R2 , "righttrigger"},
		{static_cast<int>(ControllerButtonExt::ANALOG_STICK_LEFT_X)   , "leftx"},
		{static_cast<int>(ControllerButtonExt::ANALOG_STICK_LEFT_Y)   , "lefty"},
		{static_cast<int>(ControllerButtonExt::ANALOG_STICK_RIGHT_X)  , "rightx"},
		{static_cast<int>(ControllerButtonExt::ANALOG_STICK_RIGHT_Y)  , "righty"},
        {static_cast<int>(ControllerButtonExt::MISC1)   , "misc1"},
	};
	return button_map;
}

void QmlBackend::updateButton(int chiaki_button, QString physical_button, int new_index)
{
    const QMap<int, QString> &button_map = ChiakiButtonSdlNames();
    QString button = button_map.value(chiaki_button);
    QString old_mapping = controller_mapping_physical_button_mappings.contains(physical_button) ? controller_mapping_physical_button_mappings.value(physical_button) : QString();
    if(button == old_mapping)
        return;
    if(!old_mapping.isEmpty())
    {
        QStringList old_mapping_buttons = controller_mapping_controller_mappings.value(old_mapping);
        if(old_mapping_buttons.length() > 1)
        {
            old_mapping_buttons.removeOne(physical_button);
            controller_mapping_controller_mappings.insert(old_mapping, old_mapping_buttons);
        }
        else
            controller_mapping_controller_mappings.remove(old_mapping);
    }
    QStringList new_mapping_buttons = controller_mapping_controller_mappings.value(button);
    if(new_mapping_buttons.length() > new_index)
    {
        controller_mapping_physical_button_mappings.insert(new_mapping_buttons.at(new_index), QString());
        new_mapping_buttons.remove(new_index);
    }
    if(new_index == 0)
        new_mapping_buttons.prepend(physical_button);
    else
        new_mapping_buttons.append(physical_button);
    controller_mapping_controller_mappings.insert(button, new_mapping_buttons);
    controller_mapping_physical_button_mappings.insert(physical_button, button);
    if(controller_mapping_controller_mappings == controller_mapping_applied_controller_mappings)
        setControllerMappingAltered(false);
    else
        setControllerMappingAltered(true);
    emit currentControllerMappingChanged();
}

// capture d'un bouton pour la navigation dans l'appli (Paramètres › Touches › Manette)
void QmlBackend::startNavCapture()
{
    QmlController::SetNavCapture(true);
}

void QmlBackend::stopNavCapture()
{
    QmlController::SetNavCapture(false);
}

// affectation enregistrée de la première manette branchée : bouton physique (« b0 », « h0.1 »…) -> action PlayStation
QVariantMap QmlBackend::physicalButtonActions() const
{
    QVariantMap out;
    if(SDL_WasInit(SDL_INIT_GAMECONTROLLER) == 0)
        return out;
    for(auto *c : std::as_const(controllers))
    {
        Controller *controller = c->GetController();
        if(!controller || controller->IsSteamVirtual() || !controller->GetController())
            continue;
        char *mapping = SDL_GameControllerMapping(controller->GetController());
        if(!mapping)
            continue;
        QStringList fields = QString(mapping).split(u',');
        SDL_free(mapping);
        const QMap<int, QString> &names = ChiakiButtonSdlNames();
        for(const QString &field : fields)
        {
            const QStringList parts = field.split(u':');
            if(parts.length() != 2)
                continue;
            const int action = names.key(parts.at(0), 0);
            if(action)
                out.insert(parts.at(1), action);
        }
        break;
    }
    return out;
}

// boutons physiques de la manette en cours de réglage, avec l'action PlayStation que fait chacun (0 = aucune)
QVariantList QmlBackend::controllerMappingPhysicalButtons() const
{
    QVariantList out;
    if(!controller_mapping_in_progress)
        return out;
    const QMap<int, QString> &names = ChiakiButtonSdlNames();
    for(auto it = controller_mapping_physical_button_mappings.cbegin(); it != controller_mapping_physical_button_mappings.cend(); ++it)
    {
        QVariantMap m;
        m["physical"] = it.key();
        m["action"] = it.value().isEmpty() ? 0 : names.key(it.value(), 0);
        out.append(m);
    }
    return out;
}

// le bouton physique fait désormais l'action chiaki_button (0 = rien) ;
// le bouton qui faisait déjà cette action reprend l'ancienne action de celui-ci (échange)
void QmlBackend::assignPhysicalButton(QString physical_button, int chiaki_button)
{
    if(!controller_mapping_in_progress)
        return;
    const QString target = chiaki_button ? ChiakiButtonSdlNames().value(chiaki_button) : QString();
    const QString old = controller_mapping_physical_button_mappings.value(physical_button);
    if(target == old)
        return;
    if(!old.isEmpty())
    {
        QStringList old_buttons = controller_mapping_controller_mappings.value(old);
        old_buttons.removeOne(physical_button);
        if(old_buttons.isEmpty())
            controller_mapping_controller_mappings.remove(old);
        else
            controller_mapping_controller_mappings.insert(old, old_buttons);
    }
    if(!target.isEmpty())
    {
        QStringList target_buttons = controller_mapping_controller_mappings.value(target);
        if(!target_buttons.isEmpty() && !old.isEmpty())
        {
            const QString displaced = target_buttons.takeFirst();
            QStringList old_buttons = controller_mapping_controller_mappings.value(old);
            old_buttons.prepend(displaced);
            controller_mapping_controller_mappings.insert(old, old_buttons);
            controller_mapping_physical_button_mappings.insert(displaced, old);
        }
        target_buttons.prepend(physical_button);
        controller_mapping_controller_mappings.insert(target, target_buttons);
    }
    controller_mapping_physical_button_mappings.insert(physical_button, target);
    setControllerMappingAltered(controller_mapping_controller_mappings != controller_mapping_applied_controller_mappings);
    emit currentControllerMappingChanged();
}

void QmlBackend::controllerMappingUpdate(Controller *controller)
{
    if(SDL_WasInit(SDL_INIT_GAMECONTROLLER)==0)
        return;
    if(controller_mapping_in_progress)
        return;
    controller_mapping_controller = controller;
    if(controller->IsSteamVirtual() && !controller_mapping_reset_requested)
    {
        controllerMappingQuit();
        emit controllerMappingSteamControllerSelected();
        return;
    }
    controller_mapping_id = controller->GetDeviceID();
    const char *mapping = SDL_GameControllerMapping(controller->GetController());
    QString original_controller_mapping(mapping);
    qCInfo(chiakiGui) << "Original controller mapping: " << original_controller_mapping;
    SDL_free((char *)mapping);
    if(original_controller_mapping.isEmpty())
    {
        qCWarning(chiakiGui) << "Error retrieving controller mapping " << SDL_GetError();
        controller_mapping_id = -1;
        controller_mapping_controller = nullptr;
        return;
    }
	QStringList mapping_results = original_controller_mapping.split(u',');
    if(mapping_results.length() < 2)
    {
        qCWarning(chiakiGui) << "Received invalid Mapping List";
        controller_mapping_id = -1;
        controller_mapping_controller = nullptr;
        return;
    }
	controller_mapping_controller_guid = mapping_results.takeFirst();
    controller_mapping_controller_vid_pid = controller_mapping_controller->GetVIDPIDString();
    if(!controller_mapping_original_controller_mappings.contains(controller_mapping_controller_guid))
    {
        setControllerMappingDefaultMapping(true);
        controller_mapping_original_controller_mappings.insert(controller_mapping_controller_guid, original_controller_mapping);
    }
    controller_mapping_controller->EnableAnalogStickMapping(enable_analog_stick_mapping);
	controller_mapping_controller_type = mapping_results.takeFirst();
    if(controller_mapping_controller_type == "*")
    {
        controller_mapping_controller_type = controller_mapping_controller->GetType();
        if(controller_mapping_controller_type.isEmpty())
            controller_mapping_controller_type = QString("Unidentified Controller");
    }
    for(int i=0; i<mapping_results.length(); i++)
    {
        QString individual_mapping = mapping_results.at(i);
        QStringList individual_mapping_list = individual_mapping.split(u':');
        if(individual_mapping_list.length() < 2)
            continue;
        QString key = individual_mapping_list.takeFirst();
        if(controller_mapping_controller_mappings.contains(key))
        {
            auto update_list = controller_mapping_controller_mappings.value(key);
            individual_mapping_list = update_list + individual_mapping_list;
        }
        controller_mapping_controller_mappings.insert(key, individual_mapping_list);
        // only add buttons to physical mapping list
        if(key != "crc" && key != "platform" && key != "type" && key != "hint" && !key.startsWith("sdk"))
        {
            for(int j = 0; j < individual_mapping_list.length(); j++)
                controller_mapping_physical_button_mappings.insert(individual_mapping_list[j], key);
        }
    }

    controller_mapping_applied_controller_mappings = controller_mapping_controller_mappings;
    emit currentControllerTypeChanged();
    emit currentControllerMappingChanged();
    setControllerMappingInProgress(true);
}

void QmlBackend::controllerMappingSelectButton()
{
    if(controller_mapping_in_progress && controller_mapping_controller)
        controller_mapping_controller->IsUpdatingMappingButton(true);
}

void QmlBackend::controllerMappingReset()
{
    if(!controller_mapping_original_controller_mappings.contains(controller_mapping_controller_guid) || SDL_WasInit(SDL_INIT_GAMECONTROLLER)==0 || !settings->GetControllerMappings().keys().contains(controller_mapping_controller_vid_pid))
    {
        controllerMappingQuit();
        return;
    }
    settings->RemoveControllerMapping(controller_mapping_controller_vid_pid);
    int result = SDL_GameControllerAddMapping(controller_mapping_original_controller_mappings.value(controller_mapping_controller_guid).toUtf8().constData());
    switch(result)
    {
        case -1:
            qCWarning(chiakiGui) << "Error setting controller mapping for guid: " << controller_mapping_controller_guid << " with error: " << SDL_GetError();
            break;
        case 0:
            qCInfo(chiakiGui) << "Updated controller mapping for guid: " << controller_mapping_controller_guid;
            break;
        case 1:
            qCInfo(chiakiGui) << "Added controller mapping for guid: " << controller_mapping_controller_guid;
            break;
        default:
            qCInfo(chiakiGui) << "Unidentified problem mapping for guid: " << controller_mapping_controller_guid;
            break;
    }
    controllerMappingQuit();
}

void QmlBackend::controllerMappingQuit()
{
    if(controller_mapping_in_progress && controller_mapping_controller)
        controller_mapping_controller->IsUpdatingMappingButton(false);
    else
        creatingControllerMapping(false);
    controller_mapping_reset_requested = false;
    setEnableAnalogStickMapping(false);
    controller_mapping_controller = nullptr;
    setControllerMappingDefaultMapping(false);
    setControllerMappingAltered(false);
    controller_mapping_id = -1;
    controller_mapping_controller_guid.clear();
    controller_mapping_controller_vid_pid.clear();
    controller_mapping_controller_type.clear();
    controller_mapping_controller_mappings.clear();
    controller_mapping_applied_controller_mappings.clear();
    controller_mapping_physical_button_mappings.clear();
    setControllerMappingInProgress(false);
    emit currentControllerTypeChanged();
    emit currentControllerMappingChanged();
}

void QmlBackend::controllerMappingButtonQuit()
{
    if(controller_mapping_in_progress && controller_mapping_controller)
        controller_mapping_controller->IsUpdatingMappingButton(false);
}

void QmlBackend::controllerMappingApply()
{
    QString new_controller_mapping = controller_mapping_controller_type;
    QMapIterator<QString, QStringList> i(controller_mapping_controller_mappings);
    while (i.hasNext()) {
        i.next();
        const auto &physical_buttons = i.value();
        for(int j = 0; j < physical_buttons.length(); j++)
            new_controller_mapping += "," + (i.key() + ":" + physical_buttons.at(j));
    }
    // if user actually reset to default manually, reset mapping, else add
    if(new_controller_mapping == controller_mapping_original_controller_mappings.value(controller_mapping_controller_guid))
    {
        settings->RemoveControllerMapping(controller_mapping_controller_vid_pid);
        int result = SDL_GameControllerAddMapping(controller_mapping_original_controller_mappings.value(controller_mapping_controller_guid).toUtf8().constData());
        switch(result)
        {
            case -1:
                qCWarning(chiakiGui) << "Error setting controller mapping for guid: " << controller_mapping_controller_guid << " with error: " << SDL_GetError();
                break;
            case 0:
                qCInfo(chiakiGui) << "Updated controller mapping for guid: " << controller_mapping_controller_guid;
                break;
            case 1:
                qCInfo(chiakiGui) << "Added controller mapping for guid: " << controller_mapping_controller_guid;
                break;
            default:
                qCInfo(chiakiGui) << "Unidentified problem mapping for guid: " << controller_mapping_controller_guid;
                break;
        }
    }
    else
    {
        QStringList existing_vidpid;
        if(controller_guids_to_update.contains(controller_mapping_controller_vid_pid))
            existing_vidpid.append(controller_guids_to_update.value(controller_mapping_controller_vid_pid));
        existing_vidpid.append(controller_mapping_controller_guid);
        controller_guids_to_update.insert(controller_mapping_controller_vid_pid, existing_vidpid);
        settings->SetControllerMapping(controller_mapping_controller_vid_pid, new_controller_mapping);
    }
}

void QmlBackend::updateDiscoveryHosts()
{
    // Wakeup console that we are currently connecting to
    for (const auto &host : discovery_manager.GetHosts()) {
        if (host.host_addr != session_info.host)
            continue;
        if (host.ps5 != chiaki_target_is_ps5(session_info.target))
            continue;
        if (!settings->GetRegisteredHostRegistered(host.GetHostMAC()))
            continue;
        auto registered = settings->GetRegisteredHost(host.GetHostMAC());
        if (registered.GetRPRegistKey() == session_info.regist_key) {
            if(wakeup_start && session && host.host_name == wakeup_nickname && host.state == CHIAKI_DISCOVERY_HOST_STATE_READY)
            {
                wakeup_nickname.clear();
                wakeup_start = false;
                wakeup_start_timer->stop();
                startSession(true);
            }
            else if(host.state == CHIAKI_DISCOVERY_HOST_STATE_STANDBY && session && session->IsConnecting())
            {
                sendWakeup(host.host_addr, registered.GetRPRegistKey(), host.ps5);
                QString nickname = host.host_name;
                wakeup_nickname = nickname;
                waking_sleeping_nicknames.append(nickname);
                QTimer::singleShot(WAKEUP_PSN_IGNORE_SECONDS * 1000, [this, nickname]{
                    waking_sleeping_nicknames.removeOne(nickname);
                    emit hostsChanged();
                });
                break;
            }
        }
    }
    if (autoConnect()) {
        const int hosts_count = discovery_manager.GetHosts().count();
        for (int i = 0; i < hosts_count; ++i) {
            if (discovery_manager.GetHosts().at(i).GetHostMAC() != auto_connect_mac)
                continue;
            psn_auto_connect_timer->stop();
            connectToHost(i, discovery_manager.GetHosts().at(i).host_name);
            break;
        }
    }
    emit hostsChanged();
}

void QmlBackend::prepareStartupPresentation(bool present_warmup)
{
    if (!window)
        return;

    const auto &connect_info = session_info;
    if (present_warmup && connect_info.video_profile.width > 0 && connect_info.video_profile.height > 0)
        window->presentStartupWarmupFrame(connect_info.video_profile.width,
                                          connect_info.video_profile.height,
                                          connect_info.video_profile.codec == CHIAKI_CODEC_H265_HDR);
}

void QmlBackend::applyStartupWindowSizing()
{
    if (!window)
        return;

    const auto &connect_info = session_info;
    if (window->windowState() == Qt::WindowFullScreen)
        return;
    // relance après un changement de qualité : ne pas rétrécir la fenêtre à la taille de l'image
    if (restart_retrying) {
        if (restart_was_fullscreen)
            window->fullscreenTime();
        else if (restart_geometry.isValid())
            window->setGeometry(restart_geometry);
        return;
    }

    if(settings->GetWindowType() == WindowType::CustomResolution)
    {
        window->resize(settings->GetCustomResolutionWidth(), settings->GetCustomResolutionHeight());
        window->setMaximumSize(QSize(settings->GetCustomResolutionWidth(), settings->GetCustomResolutionHeight()));
    }
    else if(settings->GetWindowType() == WindowType::AdjustableResolution)
    {
        window->normalTime();
        if(!settings->GetStreamGeometry().isEmpty())
            window->setGeometry(settings->GetStreamGeometry());
    }
    else if (connect_info.video_profile.width > 0 && connect_info.video_profile.height > 0)
    {
        window->resize(connect_info.video_profile.width, connect_info.video_profile.height);
    }
}

#if CHIAKI_GUI_ENABLE_STEAM_SHORTCUT
QString QmlBackend::getExecutable() {
#if defined(Q_OS_LINUX)
    //Check for flatpak
    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString flatpakId = env.value("FLATPAK_ID");
    QString appImagePath = env.value("APPIMAGE");
    if (!flatpakId.isEmpty()) {
        return QString("flatpak");
    }
    if (!appImagePath.isEmpty())
        return appImagePath;
#endif
    return QCoreApplication::applicationFilePath();
}

void QmlBackend::createSteamShortcut(QString shortcutName, QString launchOptions, const QJSValue &callback, QString steamDir)
{
    QJSValue cb = callback;
    QString controller_layout_workshop_id = "3049833406";
    QMap<QString, const QPixmap*> artwork;
    auto landscape = QPixmap(":/icons/steam_landscape.png");
    auto portrait = QPixmap(":/icons/steam_portrait.png");
    QImageReader reader;
    reader.setAllocationLimit(512);
    reader.setFileName(":/icons/steam_hero.png");
    auto hero = QPixmap::fromImageReader(&reader);
    auto icon = QPixmap(":/icons/steam_icon.png");
    auto logo = QPixmap(":/icons/steam_logo.png");
    artwork.insert("landscape", &landscape);
    artwork.insert("portrait", &portrait);
    artwork.insert("hero", &hero);
    artwork.insert("icon", &icon);
    artwork.insert("logo", &logo);
    
    auto infoLambda = [callback](const QString &infoMessage) {
        QJSValue icb = callback;
        if (icb.isCallable())
            icb.call({infoMessage, true, false});
    };

    auto errorLambda = [callback](const QString &errorMessage) {
        QJSValue icb = callback;
        if (icb.isCallable())
            icb.call({errorMessage, false, true});
    };
    SteamTools* steam_tools = new SteamTools(infoLambda, errorLambda, steamDir);
    bool steamExists = steam_tools->steamExists();
    if(!steamExists)
    {
        if (cb.isCallable())
            cb.call({QString("[E] Steam does not exist, cannot create Steam Shortcut"), false, true});
        delete steam_tools;
        return;
    }

    QString executable = getExecutable();
    if(executable == "flatpak")
    {
        const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        QString flatpakId = env.value("FLATPAK_ID");
        launchOptions.prepend(QString("run %1 ").arg(flatpakId));
    }
    SteamShortcutEntry newShortcut = steam_tools->buildShortcutEntry(std::move(shortcutName), std::move(executable), std::move(launchOptions), std::move(artwork));

    QVector<SteamShortcutEntry> shortcuts = steam_tools->parseShortcuts();
    bool found = false;
    for (auto& map : shortcuts) {
        if (map.getExe() == newShortcut.getExe() && map.getLaunchOptions() == newShortcut.getLaunchOptions()) {
            // Replace the entire map with the new one
            
            if (cb.isCallable())
                cb.call({QString("[I] Updating Steam entry"), true, false});
            map = newShortcut;
            found = true;
            break;  // Stop iterating once a match is found
        }
    }

   //If we didn't find it to update, let's add it to the end
    if (!found) {
        if (cb.isCallable())
            cb.call({QString("[I] Adding Steam entry ") + QString(newShortcut.getAppName().toStdString().c_str()), false, true});
        shortcuts.append(newShortcut);
    }
    steam_tools->updateShortcuts(std::move(shortcuts));
    steam_tools->updateControllerConfig(newShortcut.getAppName(), std::move(controller_layout_workshop_id));
    if (!found)
    {
        if (cb.isCallable())
            cb.call({QString("[I] Added Steam entry: ") + QString(newShortcut.getAppName().toStdString().c_str()), true, true});
    }
    else
    {
        if (cb.isCallable())
            cb.call({QString("[I] Updated Steam entry: ") + QString(newShortcut.getAppName().toStdString().c_str()), true, true});
    }
    delete steam_tools;
}
#endif

QString QmlBackend::openPsnLink()
{
    QUrl url = psnLoginUrl();
    QDesktopServices::openUrl(url);
    url = psnLoginUrl();
    return QString(url.toEncoded());
}

QString QmlBackend::openPlaceboOptionsLink()
{
    QUrl url = QUrl("https://libplacebo.org/options/");
    QDesktopServices::openUrl(url);
    url = psnLoginUrl();
    return QString(url.toEncoded());
}

bool QmlBackend::checkPsnRedirectURL(const QUrl &url) const
{
    return url.toString().startsWith(QString::fromStdString(PSNAuth::REDIRECT_PAGE));
}

void QmlBackend::initPsnAuth(const QUrl &url, const QJSValue &callback)
{
    const QJSValue cb = callback;
    if (!url.toString().startsWith(QString::fromStdString(PSNAuth::REDIRECT_PAGE)))
    {
        if (cb.isCallable())
            cb.call({QString("[E] Invalid URL: Please make sure you have copy and pasted the URL correctly."), false, true});
        return;
    }
    const QString code = QUrlQuery(url).queryItemValue("code");
    if (code.isEmpty())
    {
        if (cb.isCallable())
            cb.call({QString("[E] Invalid code from redirect url."), false, true});
        return;
    }
    PSNAccountID *psnId = new PSNAccountID(settings, this);
    connect(psnId, &PSNAccountID::AccountIDResponse, this, &QmlBackend::updatePsnHosts);
    connect(psnId, &PSNAccountID::AccountIDError, this, [cb](const QString &error) {
        if (cb.isCallable())
            cb.call({error, false, true});
    });
    connect(psnId, &PSNAccountID::AccountIDResponse, this, [cb]() {
        if (cb.isCallable())
            cb.call({QString("[I] PSN Remote Connection Tokens Generated."), true, true});
    });
    connect(psnId, &PSNAccountID::Finished, psnId, &QObject::deleteLater);
    psnId->GetPsnAccountId(code);
    emit psnTokenChanged();
}

void QmlBackend::refreshAuth()
{
    PSNToken *psnToken = new PSNToken(settings, this);
    connect(psnToken, &PSNToken::PSNTokenError, this, [this](const QString &error) {
        qCWarning(chiakiGui) << "Could not refresh token. Automatic PSN Connection Unavailable!" << error;
    });
    connect(psnToken, &PSNToken::UnauthorizedError, this, &QmlBackend::psnCredsExpired);
    connect(psnToken, &PSNToken::PSNTokenSuccess, this, []() {
        qCWarning(chiakiGui) << "PSN Remote Connection Tokens Refreshed.";
    });
    connect(psnToken, &PSNToken::PSNTokenSuccess, this, &QmlBackend::updatePsnHosts);
    connect(psnToken, &PSNToken::Finished, psnToken, &QObject::deleteLater);
    QString refresh_token = settings->GetPsnRefreshToken();
    psnToken->RefreshPsnToken(std::move(refresh_token));
}

// profil du compte PSN (pseudo, avatar, PS Plus, trophées) affiché sur la carte de la console
void QmlBackend::fetchPsnProfile()
{
    const QString token = settings->GetPsnAuthToken();
    if (token.isEmpty())
    {
        if (!psn_profile.isEmpty())
        {
            psn_profile.clear();
            emit psnProfileChanged();
        }
        return;
    }
    const QString url = "https://us-prof.np.community.playstation.net/userProfile/v1/users/me/profile2"
        "?fields=onlineId,avatarUrls,plus,trophySummary(@default,level,progress,earnedTrophies),presences(@titleInfo)&avatarSizes=xl";
    auto requester = new JsonRequester(this);
    connect(requester, &JsonRequester::requestFinished, this, [this, requester](const QString &, const QJsonDocument &doc) {
        const QJsonObject profile = doc.object().value("profile").toObject();
        requester->deleteLater();
        if (profile.isEmpty())
            return;
        const QJsonObject trophies = profile.value("trophySummary").toObject();
        const QJsonObject earned = trophies.value("earnedTrophies").toObject();
        const QJsonArray avatars = profile.value("avatarUrls").toArray();
        QString avatar = avatars.isEmpty() ? QString() : avatars.first().toObject().value("avatarUrl").toString();
        if (avatar.startsWith("http://"))
            avatar.replace(0, 7, "https://");
        const QJsonObject presence = profile.value("presences").toArray().first().toObject();
        QVariantMap m;
        m["onlineId"] = profile.value("onlineId").toString();
        m["avatar"] = avatar;
        m["plus"] = profile.value("plus").toInt() == 1;
        m["level"] = trophies.value("level").toInt();
        m["progress"] = trophies.value("progress").toInt();
        m["platinum"] = earned.value("platinum").toInt();
        m["gold"] = earned.value("gold").toInt();
        m["silver"] = earned.value("silver").toInt();
        m["bronze"] = earned.value("bronze").toInt();
        m["online"] = presence.value("onlineStatus").toString() == "online";
        m["game"] = presence.value("titleName").toString();
        psn_profile = m;
        emit psnProfileChanged();
    });
    connect(requester, &JsonRequester::requestError, this, [requester](const QString &, const QString &error, const QNetworkReply::NetworkError &) {
        qCWarning(chiakiGui) << "Could not fetch PSN profile:" << error;
        requester->deleteLater();
    });
    requester->makeGetRequest(url, JsonRequester::generateBearerAuthHeader(token));
}

void QmlBackend::updatePsnHosts()
{
    fetchPsnProfile();
    if(updating_psn_hosts)
    {
        qCInfo(chiakiGui) << "Already updating psn hosts, skipping...";
        return;
    }
    psn_hosts_future = QtConcurrent::run(&QmlBackend::updatePsnHostsThread, this);
    psn_hosts_watcher.setFuture(psn_hosts_future);
    updating_psn_hosts = true;
}

void QmlBackend::updatePsnHostsThread()
{
    QString psn_token = settings->GetPsnAuthToken();
    if(psn_token.isEmpty())
        return;

    ChiakiHolepunchDeviceInfo *device_info_ps5 = nullptr;
    size_t num_devices_ps5 = 0;
    ChiakiLog backend_log;
    chiaki_log_init(&backend_log, settings->GetLogLevelMask(), chiaki_log_cb_print, nullptr);
    for(int i = 0; i < PSN_DEVICES_TRIES; i++)
    {
        ChiakiErrorCode err = chiaki_holepunch_list_devices(psn_token.toUtf8().constData(), CHIAKI_HOLEPUNCH_CONSOLE_TYPE_PS5, &device_info_ps5, &num_devices_ps5, &backend_log);
        if (err != CHIAKI_ERR_SUCCESS)
        {
            if(PSN_DEVICES_TRIES - i > 1)
            {
                qCWarning(chiakiGui) << "Failed to get PS5 devices trying again";
                continue;
            }
            else
            {
                qCWarning(chiakiGui) << "Failed to get PS5 devices after max tries: " << PSN_DEVICES_TRIES;
                num_devices_ps5 = 0;
            }
        }
        break;
    }
    for (size_t i = 0; i < num_devices_ps5; i++)
    {
        ChiakiHolepunchDeviceInfo dev = device_info_ps5[i];
        // skip devices that don't have remote play enabled
        if(!dev.remoteplay_enabled)
            continue;
        QByteArray duid_bytes(reinterpret_cast<char*>(dev.device_uid), sizeof(dev.device_uid));
        QString duid = QString(duid_bytes.toHex());
        QString name = QString(dev.device_name);
        bool ps5 = true;
        PsnHost psn_host(duid, name, ps5);
        if(!psn_nickname_hosts.contains(name))
            psn_nickname_hosts.insert(name, psn_host);
	    if(!psn_hosts.contains(duid) && settings->GetNicknameRegisteredHostRegistered(name))
		    psn_hosts.insert(duid, psn_host);
    }
    QByteArray duid_bytes(32, 'A');
    QString duid = QString(duid_bytes.toHex());
    QString name = QString("Main PS4 Console");
    bool ps5 = false;
    PsnHost psn_host(duid, name, ps5);
    if(!psn_nickname_hosts.contains(name))
        psn_nickname_hosts.insert(name, psn_host);
    if(!psn_hosts.contains(duid) && (settings->GetPS4RegisteredHostsRegistered() > 0))
        psn_hosts.insert(duid, psn_host);

    emit hostsChanged();
    qCInfo(chiakiGui) << "Updated PSN hosts";
    if(device_info_ps5)
        chiaki_holepunch_free_device_list(&device_info_ps5);
}

void QmlBackend::refreshPsnToken()
{
    QString expiry_s = settings->GetPsnAuthTokenExpiry();
    QString refresh = settings->GetPsnRefreshToken();
    if(expiry_s.isEmpty() || refresh.isEmpty())
        return;
    QDateTime expiry = QDateTime::fromString(expiry_s, settings->GetTimeFormat());
    // give 1 minute buffer
    QDateTime now = QDateTime::currentDateTime().addSecs(60);
    if (now >= expiry)
        refreshAuth();
    else
        updatePsnHosts();
}

void PsnConnectionWorker::ConnectPsnConnection(StreamSession *session, const QString &duid, const bool &ps5)
{
    ChiakiErrorCode result = session->ConnectPsnConnection(duid, ps5);
    emit resultReady(result);
}
