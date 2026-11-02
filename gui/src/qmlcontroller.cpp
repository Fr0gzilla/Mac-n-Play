#include "qmlcontroller.h"

#include <QTimer>
#include <QKeyEvent>
#include <QDateTime>
#include <QHash>
#include <QStyleHints>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QWheelEvent>
#include <cstdlib>
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

static QVector<QPair<uint32_t, Qt::Key>> key_map = {
    { CHIAKI_CONTROLLER_BUTTON_DPAD_UP, Qt::Key_Up },
    { CHIAKI_CONTROLLER_BUTTON_DPAD_DOWN, Qt::Key_Down },
    { CHIAKI_CONTROLLER_BUTTON_DPAD_LEFT, Qt::Key_Left },
    { CHIAKI_CONTROLLER_BUTTON_DPAD_RIGHT, Qt::Key_Right },
    { CHIAKI_CONTROLLER_BUTTON_CROSS, Qt::Key_Return },
    { CHIAKI_CONTROLLER_BUTTON_MOON, Qt::Key_Escape },
    { CHIAKI_CONTROLLER_BUTTON_BOX, Qt::Key_No },
    { CHIAKI_CONTROLLER_BUTTON_PYRAMID, Qt::Key_Yes },
    { CHIAKI_CONTROLLER_BUTTON_L1, Qt::Key_PageUp },
    { CHIAKI_CONTROLLER_BUTTON_R1, Qt::Key_PageDown },
    { CHIAKI_CONTROLLER_BUTTON_OPTIONS, Qt::Key_Menu },
    { CHIAKI_CONTROLLER_BUTTON_L3, Qt::Key_F1},
    { CHIAKI_CONTROLLER_BUTTON_R3, Qt::Key_F2},
    { CHIAKI_CONTROLLER_ANALOG_BUTTON_L2, Qt::Key_F3},
    { CHIAKI_CONTROLLER_ANALOG_BUTTON_R2, Qt::Key_F4},
};

// Navigation dans l'appli seulement (pas en jeu) : l'utilisateur peut choisir quel bouton
// envoie chaque touche (Paramètres › Touches › Manette). Réglage « macnplay/navMapping » :
// {"<code de touche Qt>": <bouton chiaki>, …} ; sans réglage, la table par défaut ci-dessus.
static bool nav_capture = false;
static qint64 nav_capture_since = 0;

void QmlController::SetNavCapture(bool enabled)
{
    nav_capture = enabled;
    nav_capture_since = QDateTime::currentMSecsSinceEpoch();
}

static QVector<QPair<uint32_t, Qt::Key>> NavKeyMap()
{
    static QString cached_json;
    static QVector<QPair<uint32_t, Qt::Key>> cached = key_map;
    const QString json = QSettings().value("macnplay/navMapping").toString();
    if(json == cached_json)
        return cached;
    cached_json = json;
    cached = key_map;
    // valeur : un bouton, ou [principal, second] (deux boutons pour la même touche)
    const QJsonObject overrides = QJsonDocument::fromJson(json.toUtf8()).object();
    QVector<QPair<uint32_t, Qt::Key>> extra;
    for(auto &k : cached)
    {
        const QString key = QString::number(static_cast<int>(k.second));
        if(!overrides.contains(key))
            continue;
        const QJsonValue value = overrides.value(key);
        if(value.isArray())
        {
            const QJsonArray buttons = value.toArray();
            k.first = buttons.isEmpty() ? 0 : static_cast<uint32_t>(buttons.at(0).toInteger());
            for(qsizetype i = 1; i < buttons.size(); i++)
                if(buttons.at(i).toInteger())
                    extra.append({ static_cast<uint32_t>(buttons.at(i).toInteger()), k.second });
        }
        else
            k.first = static_cast<uint32_t>(value.toInteger());
    }
    cached += extra;
    return cached;
}

QmlController::QmlController(Controller *c, uint32_t shortcut, QObject *t, QObject *parent)
    : QObject(parent)
    , target(t)
    , escape_shortcut(shortcut)
    , controller(c)
{
    repeat_timer = new QTimer(this);
    connect(repeat_timer, &QTimer::timeout, this, [this]() {
        if (!repeat_running++)
            repeat_timer->start(80);
        sendKey(pressed_key);
        if (repeat_running == 50)
            repeat_timer->stop();
    });

    scroll_timer = new QTimer(this);
    scroll_timer->setInterval(16);
    connect(scroll_timer, &QTimer::timeout, this, &QmlController::sendScroll);

    connect(controller, &Controller::StateChanged, this, [this]() {
        auto state = controller->GetState();

        // joystick droit vertical : vitesse de défilement (zone morte au centre, plus vite en poussant fort)
        const int dead_zone = 8000;
        const int y = state.right_y;
        scroll_speed = std::abs(y) > dead_zone && !nav_capture ? (y > 0 ? 1 : -1) * ((std::abs(y) - dead_zone) * 36 / (32767 - dead_zone) + 2) : 0;
        if (scroll_speed && !scroll_timer->isActive())
            scroll_timer->start();
        else if (!scroll_speed)
            scroll_timer->stop();
        auto buttons = state.buttons;

        // joystick gauche = croix directionnelle ; il suffit de le pousser à mi-course
        // (et on garde la direction tant qu'il n'est pas presque revenu au centre)
        const int stick_on = 20000, stick_hold = 14000;
        auto held = [this](uint32_t dir) { return (old_buttons & dir) ? stick_hold : stick_on; };
        if (state.left_x > held(CHIAKI_CONTROLLER_BUTTON_DPAD_RIGHT))
            buttons |= CHIAKI_CONTROLLER_BUTTON_DPAD_RIGHT;
        else if (state.left_x < -held(CHIAKI_CONTROLLER_BUTTON_DPAD_LEFT))
            buttons |= CHIAKI_CONTROLLER_BUTTON_DPAD_LEFT;

        if (state.left_y > held(CHIAKI_CONTROLLER_BUTTON_DPAD_DOWN))
            buttons |= CHIAKI_CONTROLLER_BUTTON_DPAD_DOWN;
        else if (state.left_y < -held(CHIAKI_CONTROLLER_BUTTON_DPAD_UP))
            buttons |= CHIAKI_CONTROLLER_BUTTON_DPAD_UP;

        // gâchettes L2 / R2 : enfoncées à plus des deux tiers = appui (un peu moins pour garder l'appui)
        const uint8_t trigger_on = 170, trigger_hold = 120;
        if (state.l2_state > ((old_buttons & CHIAKI_CONTROLLER_ANALOG_BUTTON_L2) ? trigger_hold : trigger_on))
            buttons |= CHIAKI_CONTROLLER_ANALOG_BUTTON_L2;
        if (state.r2_state > ((old_buttons & CHIAKI_CONTROLLER_ANALOG_BUTTON_R2) ? trigger_hold : trigger_on))
            buttons |= CHIAKI_CONTROLLER_ANALOG_BUTTON_R2;

        // capture : on signale le premier bouton nouvellement pressé (l'appui qui a ouvert la fenêtre est ignoré)
        if (nav_capture) {
            const uint32_t newly = buttons & ~old_buttons;
            if (newly && QDateTime::currentMSecsSinceEpoch() - nav_capture_since > 250) {
                nav_capture = false;
                repeat_timer->stop();
                emit navButtonCaptured(newly & (~newly + 1));
            }
            old_buttons = buttons;
            return;
        }

        // la table n'est relue qu'au changement d'un bouton (pas à chaque mouvement de stick)
        const auto nav_map = buttons != old_buttons ? NavKeyMap() : QVector<QPair<uint32_t, Qt::Key>>();
        for (auto &k : nav_map) {
            const bool pressed = buttons & k.first;
            const bool old_pressed = old_buttons & k.first;
            if (pressed && !old_pressed) {
                pressed_key = k.second;
                sendKey(pressed_key);
                repeat_running = 0;
                repeat_timer->start(250);
            } else if (old_pressed && !pressed && pressed_key == k.second) {
                repeat_timer->stop();
                repeat_running = 1;
            }
        }

        if (escape_shortcut && (old_buttons & escape_shortcut) == escape_shortcut && (buttons & escape_shortcut) != escape_shortcut)
            sendKey(Qt::Key_O, Qt::ControlModifier);

        old_buttons = buttons;
    });
}

QmlController::~QmlController()
{
    controller->Unref();
}

bool QmlController::isDualSense() const
{
    return controller->IsDualSense();
}

bool QmlController::isHandheld() const
{
    return controller->IsHandheld();
}

bool QmlController::isPS() const
{
    return controller->IsPS();
}

bool QmlController::isSteamVirtual() const
{
    return controller->IsSteamVirtual();
}

bool QmlController::isDualSenseEdge() const
{
    return controller->IsDualSenseEdge();
}

QString QmlController::GetGUID() const
{
    return controller->GetGUIDString();
}

QString QmlController::GetVIDPID() const
{
    return controller->GetVIDPIDString();
}

void QmlController::sendScroll()
{
    if (!scroll_speed)
        return;
    // même fenêtre que les touches : celle qui a le focus (menu en jeu…), sinon la fenêtre principale
    QObject *receiver = target;
    if (auto *focus_window = qobject_cast<QQuickWindow *>(QGuiApplication::focusWindow()))
        receiver = focus_window;
    auto *window = qobject_cast<QWindow *>(receiver);
    if (!window)
        return;
    const QPointF center(window->width() / 2.0, window->height() / 2.0);
    // pousser vers le bas fait descendre la page (contenu vers le haut)
    const QPoint pixels(0, -scroll_speed);
    QWheelEvent wheel(center, window->mapToGlobal(center), pixels, pixels * 4, Qt::NoButton, Qt::NoModifier, Qt::NoScrollPhase, false);
    QGuiApplication::sendEvent(receiver, &wheel);
}

void QmlController::sendKey(Qt::Key key, Qt::KeyboardModifiers modifiers)
{
    // SDL2-compat/SDL3 on macOS can expose a single physical controller as
    // two devices, creating two QmlController instances that both fire for
    // the same button press. Deduplicate by VID:PID + key as a workaround
    // for the aliased SDL devices, but do not refresh the timestamp on
    // suppressed copies so held-button repeat can continue.
    static QHash<QString, qint64> last_key_time_by_device;
    const QString dedup_key = GetVIDPID() + QLatin1Char(':') + QString::number(static_cast<int>(key));
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const qint64 last_time = last_key_time_by_device.value(dedup_key, 0);
    if ((now - last_time) < 50)
        return;

    last_key_time_by_device.insert(dedup_key, now);

    // With the OpenGL renderer the stream menu and session dialogs are separate top-level
    // QML windows, so navigation keys go to whichever of those has focus. Shortcuts
    // (Ctrl+O toggles the stream menu) are handled by the main window.
    QObject *receiver = target;
    if (modifiers == Qt::NoModifier) {
        if (auto *focus_window = qobject_cast<QQuickWindow *>(QGuiApplication::focusWindow()))
            receiver = focus_window;
    }

    QKeyEvent press(QEvent::KeyPress, key, modifiers);
    QKeyEvent release(QEvent::KeyRelease, key, Qt::NoModifier);
    QGuiApplication::sendEvent(receiver, &press);
    QGuiApplication::sendEvent(receiver, &release);
}
