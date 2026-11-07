// Contrôleur (MVC) de la partie, et point d'entrée des écrans (« Chiaki » en QML).
//
// Rôle : lancer, suivre et arrêter une partie sur une console (connexion locale ou par
// le compte PSN, réveil pendant la connexion, changement de qualité en cours de partie,
// mise en veille du Mac), et réunir les autres contrôleurs pour les écrans :
//   - Chiaki.consoles          → ConsoleRegistry (liste, association, réveil des consoles)
//   - Chiaki.psn               → PsnAccount (compte PSN, jetons, profil)
//   - Chiaki.controllers       → ConnectedControllers (manettes branchées)
//   - Chiaki.controllerMapping → ControllerMappingController (attribution des boutons)
//   - Chiaki.settings          → QmlSettings (réglages)
//   - Chiaki.journal           → JournalController (journal de l'appli)
//   - Chiaki.updates           → UpdateChecker (nouvelles versions publiées)
//   - Chiaki.diagnostic        → ConnectionDiagnostic (« Tester ma connexion »)
// Le moteur de la partie (réseau, vidéo, son) est StreamSession, hérité de chiaki-ng.
#pragma once

#include "streamsession.h"
#include "discoverymanager.h"
#include "qmlmainwindow.h"
#include "qmlcontroller.h"
#include "qmlsettings.h"
#include "controllermappingcontroller.h"
#include "psnaccount.h"
#include "consoleregistry.h"
#include "connectedcontrollers.h"
#include "appjournal.h"
#include "updatechecker.h"
#include "remotequalityguard.h"
#include "connectiondiagnostic.h"

#include <QObject>
#include <QMutex>
#include <QThread>
#include <QJSValue>
#include <QSet>
#include <QUrl>
#include <QFutureWatcher>
#include <QFuture>
#include <QAtomicInteger>
#ifdef CHIAKI_HAVE_WEBENGINE
#include <QQuickWebEngineProfile>
#include <QWebEngineUrlRequestInterceptor>
#endif

class SystemdInhibit;
#ifdef Q_OS_MACOS
    class MacWakeSleep;
#elif defined(Q_OS_WINDOWS)
    class WindowsWakeSleep;
#endif

class PsnConnectionWorker : public QObject
{
    Q_OBJECT

public:
    void ConnectPsnConnection(StreamSession *session, const QString &duid, const bool &ps5);

signals:
    void resultReady(const ChiakiErrorCode &err);
};

class QmlBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QmlMainWindow* window READ qmlWindow CONSTANT)
    Q_PROPERTY(QmlSettings* settings READ qmlSettings CONSTANT)
    Q_PROPERTY(StreamSession* session READ qmlSession NOTIFY sessionChanged)
    Q_PROPERTY(QList<QmlController*> controllers READ qmlControllers NOTIFY controllersChanged)
    Q_PROPERTY(PsnAccount* psn READ psnAccount CONSTANT)
    Q_PROPERTY(ConsoleRegistry* consoles READ consoleRegistry CONSTANT)
    Q_PROPERTY(JournalController* journal READ journalController CONSTANT)
    Q_PROPERTY(UpdateChecker* updates READ updateChecker CONSTANT)
    Q_PROPERTY(ConnectionDiagnostic* diagnostic READ connectionDiagnostic CONSTANT)
    // message sur la partie en cours (« Partie par Internet… », « Connexion faible… »), vide sinon
    Q_PROPERTY(QString sessionNotice READ sessionNotice NOTIFY sessionNoticeChanged)
    Q_PROPERTY(bool autoConnect READ autoConnect NOTIFY autoConnectChanged)
    Q_PROPERTY(PsnConnectState connectState READ connectState WRITE setConnectState NOTIFY connectStateChanged)
    Q_PROPERTY(ControllerMappingController* controllerMapping READ controllerMappingController CONSTANT)

public:

    enum class PsnConnectState
    {
        NotStarted,
        WaitingForInternet,
        InitiatingConnection,
        LinkingConsole,
        RegisteringConsole,
        RegistrationFinished,
        DataConnectionStart,
        DataConnectionFinished,
        ConnectFailed,
        ConnectFailedStart,
        ConnectFailedConsoleUnreachable,
    };
    Q_ENUM(PsnConnectState);
    QmlBackend(Settings *settings, QmlMainWindow *window);
    ~QmlBackend();

    QmlMainWindow *qmlWindow() const;
    QmlSettings *qmlSettings() const;
    PsnAccount *psnAccount() const { return psn_account; }
    ConsoleRegistry *consoleRegistry() const { return consoles; }
    JournalController *journalController() const { return journal; }
    UpdateChecker *updateChecker() const { return updates; }
    ConnectionDiagnostic *connectionDiagnostic() const { return diagnostic; }
    QString sessionNotice() const { return session_notice; }
    StreamSession *qmlSession() const;
    QList<QmlController*> qmlControllers() const;


    PsnConnectState connectState() const;
    void setConnectState(PsnConnectState connect_state);


    ControllerMappingController *controllerMappingController() const { return controller_mapping; }

    void finishAutoRegister(const ChiakiRegisteredHost &host);

    bool autoConnect() const;

    void psnConnector();

    void createSession(const StreamSessionConnectInfo &connect_info);

    void psnSessionStart();
    void startSession(bool emit_session_changed = true);

    void checkPsnConnection(const ChiakiErrorCode &err);

    void checkNickname(QString nickname);

    bool closeRequested();



    void profileChanged();
    bool prepareFrameForPresentation(ChiakiFfmpegFrame &frame, bool use_opengl_renderer);
    void prepareStartupPresentation(bool present_warmup);
    void applyStartupWindowSizing();

    void goToSleep();

    bool zeroCopy()        { return !disable_zero_copy; };
    void disableZeroCopy() { disable_zero_copy = true; };
    void enableZeroCopy()  { disable_zero_copy = false; };

    // lance une partie sur la console de clé « key » (voir ConsoleRegistry::list)
    Q_INVOKABLE void connectToHost(const QString &key, QString nickname = QString());
    Q_INVOKABLE void stopSession(bool sleep);
    // menu en jeu : qualité de la partie en cours, et relance dans une autre qualité
    Q_INVOKABLE QVariantMap sessionQuality() const;
    Q_INVOKABLE void restartSessionWithResolution(int preset);
    Q_INVOKABLE void sessionGoHome();
    Q_INVOKABLE void enterPin(const QString &pin);
    Q_INVOKABLE void stopAutoConnect();
    Q_INVOKABLE QString openPlaceboOptionsLink();
    Q_INVOKABLE void psnCancel(bool stop_thread);
    Q_INVOKABLE void autoRegister();
#if CHIAKI_GUI_ENABLE_STEAM_SHORTCUT
    Q_INVOKABLE void createSteamShortcut(QString shortcutName, QString launchOptions, const QJSValue &callback, QString steamDir);
#endif

signals:
    void sessionChanged(StreamSession *session);
    void sessionNoticeChanged();
    void psnConnect(StreamSession *session, const QString &duid, const bool &ps5);
    void showPsnView();
    void connectStateChanged();
    void controllersChanged();
    void autoConnectChanged();
    void wakeupStartInitiated();
    void wakeupStartFailed();
    // connexion automatique abandonnée sans partie (console en mode repos ou absente) : retour à l'accueil
    void autoConnectGaveUp();
    void windowTypeUpdated(WindowType type);

    void error(const QString &title, const QString &text);
    void sessionError(const QString &title, const QString &text);
    void sessionPinDialogRequested();
    void sessionStopDialogRequested();
    void registDialogRequested(const QString &host, bool ps5, const QString &duid);

private:

    void updateDiscoveryHosts();
    void updateAudioVolume();
    void resumeFromSleep();
    QString getExecutable();

    Settings *settings = {};
    // détection PS4 Pro : console de la partie en cours et hauteur d'image demandée
    QString pro_check_mac;
    int pro_check_requested_height = 0;
    void checkPs4Pro(StreamSession *checked_session);
    QmlSettings *settings_qml = {};
    QmlMainWindow *window = {};
    StreamSession *session = {};
    QThread *frame_thread = {};
    QTimer *psn_reconnect_timer = {};
    QTimer *psn_auto_connect_timer = {};
    QTimer *wakeup_start_timer = {};
    int psn_reconnect_tries = 0;
    QThread psn_connection_thread;
    PsnConnectState psn_connect_state;
    StreamSessionConnectInfo session_info = {};
    bool restart_pending = false;
    bool restart_retrying = false;
    int restart_tries = 0;
    // fenêtre gardée telle quelle pendant la relance (plein écran ou taille/position)
    bool restart_was_fullscreen = false;
    QRect restart_geometry;
    void restartCreateSession();
    StreamSessionConnectInfo restart_info = {};
    SystemdInhibit *sleep_inhibit = {};
#ifdef Q_OS_MACOS
    MacWakeSleep *mac_wake_sleep = {};
#elif defined(Q_OS_WINDOWS)
    WindowsWakeSleep *windows_wake_sleep = {};
#endif
    ControllerMappingController *controller_mapping = {};
    PsnAccount *psn_account = {};
    ConsoleRegistry *consoles = {};
    JournalController *journal = {};
    UpdateChecker *updates = {};
    RemoteQualityGuard *remote_quality = {};
    ConnectionDiagnostic *diagnostic = {};
    QString session_notice;
    void setSessionNotice(const QString &notice);
    void retryPsnAfterOutage();
    void setupAutoConnect();
    void giveUpAutoConnect(const char *reason);
    void detachSessionLog();
    void discardSession();
    // relance la partie dans un autre préréglage ; remember = l'enregistrer comme choix de l'utilisateur
    void restartSession(int preset, bool remember);
    ConnectedControllers *connected_controllers = {};
    bool disable_zero_copy = false;
    QMutex hw_transfer_state_mutex;
    QSet<int> logged_hw_transfer_formats;
    QSet<int> logged_hw_transfer_failures;
    QAtomicInteger<int> pending_recovered_frame = 0;
    bool resume_session = false;
    bool settings_allocd = false;
    // profil quitté au dernier changement : gardé le temps qu'une requête PSN en cours se termine
    Settings *retired_settings = nullptr;
    HostMAC auto_connect_mac = {};
    QString wakeup_nickname = "";
    bool wakeup_start = false;
};
