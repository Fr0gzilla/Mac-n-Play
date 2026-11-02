#include "qmlbackend.h"
#include "psnaccount.h"
#include "consoleregistry.h"
#include "connectedcontrollers.h"
#include "macnplaylog.h"
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
    qmlRegisterUncreatableType<ControllerMappingController>(uri, 1, 0, "ControllerMapping", {});
    qmlRegisterUncreatableType<PsnAccount>(uri, 1, 0, "PsnAccount", {});
    qmlRegisterUncreatableType<ConsoleRegistry>(uri, 1, 0, "ConsoleRegistry", {});
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
    connected_controllers = new ConnectedControllers(settings, window, this);
    connect(connected_controllers, &ConnectedControllers::listChanged, this, &QmlBackend::controllersChanged);
    for (auto changed : {&QmlSettings::streamMenuEnabledChanged, &QmlSettings::streamMenuShortcut1Changed, &QmlSettings::streamMenuShortcut2Changed,
                         &QmlSettings::streamMenuShortcut3Changed, &QmlSettings::streamMenuShortcut4Changed})
        connect(settings_qml, changed, connected_controllers, &ConnectedControllers::applyStreamMenuShortcut);
    connect(settings, &Settings::CurrentProfileChanged, this, &QmlBackend::profileChanged);
    consoles = new ConsoleRegistry(settings, this);
    connect(consoles, &ConsoleRegistry::discoveredHostsUpdated, this, &QmlBackend::updateDiscoveryHosts);
    connect(consoles, &ConsoleRegistry::error, this, &QmlBackend::error);
    connect(settings_qml, &QmlSettings::allowJoystickBackgroundEventsChanged, connected_controllers, &ConnectedControllers::applyBackgroundEvents);
    connect(this, &QmlBackend::sessionChanged, connected_controllers, &ConnectedControllers::applyAppActive);
    controller_mapping = new ControllerMappingController(settings, connected_controllers->byDeviceId(), this);
    connected_controllers->setMappingController(controller_mapping);
    connected_controllers->refresh();
    connect(connected_controllers, &ConnectedControllers::listChanged, controller_mapping, &ControllerMappingController::applySavedMappings);
    psn_account = new PsnAccount(settings, this);
    connect(psn_account, &PsnAccount::tokensReady, consoles, &ConsoleRegistry::refreshPsnConsoles);
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
            const int index = consoles->psnConsoleIndex(auto_connect_nickname);
            if(index >= 0)
            {
                connectToHost(index);
                return;
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
        connect(psnToken, &PSNToken::UnauthorizedError, psn_account, &PsnAccount::forgetCredentials);
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
    psn_account->refresh();
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
    return connected_controllers->list();
}

void QmlBackend::profileChanged()
{
    QString profile = settings->GetCurrentProfile();
    Settings *settings_copy = new Settings(profile);
    if(settings_allocd)
        settings->deleteLater();
    settings_allocd = true;
    settings = settings_copy;
    controller_mapping->setSettings(settings);
    connected_controllers->setSettings(settings);
    consoles->setSettings(settings);
    psn_account->setSettings(settings);
    connect(settings, &Settings::CurrentProfileChanged, this, &QmlBackend::profileChanged);
    settings_qml->setSettings(settings);
    window->setSettings(settings);
    consoles->setDiscoveryEnabled(true);

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
            const int index = consoles->psnConsoleIndex(auto_connect_nickname);
            if(index >= 0)
            {
                connectToHost(index);
                return;
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
        connect(psnToken, &PSNToken::UnauthorizedError, psn_account, &PsnAccount::forgetCredentials);
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
    psn_account->refresh();
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
                consoles->setDiscoveryEnabled(true);
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
                consoles->setDiscoveryEnabled(true);
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
                consoles->setDiscoveryEnabled(true);
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
        consoles->setDiscoveryEnabled(true);
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
            consoles->setDiscoveryEnabled(false);
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
        consoles->setDiscoveryEnabled(false);
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

void QmlBackend::autoRegister()
{
    const auto &server = consoles->pendingRegistration();
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
        connect(psnToken, &PSNToken::UnauthorizedError, psn_account, &PsnAccount::forgetCredentials);
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
    if(!consoles->pendingRegistration().discovery_host.ps5 && consoles->pendingRegistration().discovery_host.host_name != nickname)
    {
        emit error(tr("PS4 Console Not Main"), tr("Can't proceed...%1 is not your main PS4 console in PSN").arg(consoles->pendingRegistration().discovery_host.host_name));
        return;
    }
    settings->AddRegisteredHost(host);
    setConnectState(PsnConnectState::RegistrationFinished);
    consoles->refreshPsnConsoles();
}

void QmlBackend::connectToHost(int index, QString nickname)
{
    window->setWindowAdjustable(false);
    auto server = consoles->consoleAt(index);
    if (!server.valid)
        return;

    if (!server.registered) {
        consoles->setPendingRegistration(server);
        emit registDialogRequested(server.address(), server.isPS5(), server.duid);
        return;
    }

    // les réglages propres à cette console (qualité, fluidité…) s'appliquent à la partie
    if (server.registered_host.GetServerMAC().ToString() != QStringLiteral("000000000000"))
        settings_qml->activateConsole(server.registered_host.GetServerMAC().ToString());

    if (server.discovered && server.discovery_host.state == CHIAKI_DISCOVERY_HOST_STATE_STANDBY)
    {
        const QString wake_host = server.address();
        const QByteArray wake_regist_key = server.registered_host.GetRPRegistKey();
        const bool wake_ps5 = server.isPS5();
        if(!consoles->sendWakeup(wake_host, wake_regist_key, wake_ps5))
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
        consoles->markWaking(nickname);
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
    if(server.duid.isEmpty() && !server.isPS5() && settings->GetResolutionLocalPS4() == CHIAKI_VIDEO_RESOLUTION_PRESET_1080p)
    {
        pro_check_mac = server.registered_host.GetServerMAC().ToString();
        pro_check_requested_height = 1080;
    }
    if(server.duid.isEmpty())
    {
        QString host = server.address();
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
            connect(psnToken, &PSNToken::UnauthorizedError, psn_account, &PsnAccount::forgetCredentials);
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
        consoles->markWaking(session_info.nickname);
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

void QmlBackend::updateDiscoveryHosts()
{
    // Wakeup console that we are currently connecting to
    for (const auto &host : consoles->discoveredHosts()) {
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
                consoles->sendWakeup(host.host_addr, registered.GetRPRegistKey(), host.ps5);
                QString nickname = host.host_name;
                wakeup_nickname = nickname;
                consoles->markWaking(nickname);
                break;
            }
        }
    }
    if (autoConnect()) {
        const int hosts_count = consoles->discoveredHosts().count();
        for (int i = 0; i < hosts_count; ++i) {
            if (consoles->discoveredHosts().at(i).GetHostMAC() != auto_connect_mac)
                continue;
            psn_auto_connect_timer->stop();
            connectToHost(i, consoles->discoveredHosts().at(i).host_name);
            break;
        }
    }
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

QString QmlBackend::openPlaceboOptionsLink()
{
    QUrl url = QUrl("https://libplacebo.org/options/");
    QDesktopServices::openUrl(url);
    return QString(url.toEncoded());
}

void PsnConnectionWorker::ConnectPsnConnection(StreamSession *session, const QString &duid, const bool &ps5)
{
    ChiakiErrorCode result = session->ConnectPsnConnection(duid, ps5);
    emit resultReady(result);
}
