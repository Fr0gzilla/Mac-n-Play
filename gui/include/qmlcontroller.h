#pragma once

#include "controllermanager.h"

class QTimer;

class QmlController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool dualSense READ isDualSense CONSTANT)
    Q_PROPERTY(bool handheld READ isHandheld CONSTANT)
    Q_PROPERTY(bool steamVirtual READ isSteamVirtual CONSTANT)
    Q_PROPERTY(bool dualSenseEdge READ isDualSenseEdge CONSTANT)
    Q_PROPERTY(bool playStation READ isPS CONSTANT)

public:
    QmlController(Controller *controller, uint32_t shortcut, QObject *target, QObject *parent = nullptr);
    Controller *GetController() const { return controller; }
    ~QmlController();

    bool isDualSense() const;
    bool isHandheld() const;
    bool isSteamVirtual() const;
    bool isDualSenseEdge() const;
    bool isPS() const;
    void setEscapeShortcut(uint32_t shortcut) { escape_shortcut = shortcut; };
    QString GetGUID() const;
    QString GetVIDPID() const;
    // pendant une capture, le premier bouton pressé est signalé au lieu de naviguer
    static void SetNavCapture(bool enabled);

signals:
    void navButtonCaptured(uint button);

private:
    void sendKey(Qt::Key key, Qt::KeyboardModifiers modifiers = Qt::NoModifier);

    QObject *target = {};
    uint32_t escape_shortcut = 0;
    uint32_t old_buttons = 0;
    Controller *controller = {};
    QTimer *repeat_timer = {};
    // joystick droit : défilement des pages (comme deux doigts sur le pavé tactile)
    QTimer *scroll_timer = {};
    int scroll_speed = 0;
    void sendScroll();
    int repeat_running = 0;
    Qt::Key pressed_key = Qt::Key_unknown;
};
