// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)

#include "connectedcontrollers.h"
#include "controllermanager.h"
#include "controllermappingcontroller.h"
#include "qmlcontroller.h"
#include "qmlmainwindow.h"
#include "settings.h"
#include "macnplaylog.h"
#include "macnplayrules.h"

ConnectedControllers::ConnectedControllers(Settings *settings, QmlMainWindow *window, QObject *parent)
    : QObject(parent), settings(settings), window(window)
{
    connect(ControllerManager::GetInstance(), &ControllerManager::AvailableControllersUpdated, this, &ConnectedControllers::refresh);
    connect(window, &QmlMainWindow::activeChanged, this, &ConnectedControllers::applyAppActive);
    applyBackgroundEvents();
    applyAppActive();
}

uint32_t ConnectedControllers::streamMenuShortcut() const
{
    if(!settings->GetStreamMenuEnabled())
        return 0;
    return MacnPlayRules::buttonComboMask({settings->GetStreamMenuShortcut1(), settings->GetStreamMenuShortcut2(),
                                           settings->GetStreamMenuShortcut3(), settings->GetStreamMenuShortcut4()});
}

void ConnectedControllers::applyStreamMenuShortcut()
{
    const uint32_t shortcut = streamMenuShortcut();
    for(auto *controller : std::as_const(controllers))
        controller->setEscapeShortcut(shortcut);
}

void ConnectedControllers::applyBackgroundEvents()
{
    ControllerManager::GetInstance()->SetAllowJoystickBackgroundEvents(settings->GetAllowJoystickBackgroundEvents());
}

void ConnectedControllers::applyAppActive()
{
    ControllerManager::GetInstance()->SetIsAppActive(window->isActive());
}

void ConnectedControllers::refresh()
{
    bool changed = false;
    const auto available = ControllerManager::GetInstance()->GetAvailableControllers();
    for(auto it = controllers.begin(); it != controllers.end();)
    {
        if(available.contains(it.key()))
        {
            ++it;
            continue;
        }
        qCInfo(logController) << "Manette débranchée :" << it.value()->GetVIDPID();
        if(mapping)
            mapping->controllerClosed(it.key());
        it.value()->deleteLater();
        it = controllers.erase(it);
        changed = true;
    }
    const uint32_t shortcut = streamMenuShortcut();
    for(auto id : available)
    {
        if(controllers.contains(id))
            continue;
        Controller *controller = ControllerManager::GetInstance()->OpenController(id);
        if(!controller)
        {
            qCWarning(logController) << "Impossible d'ouvrir la manette" << id;
            continue;
        }
        auto *qml_controller = new QmlController(controller, shortcut, window, this);
        controllers[id] = qml_controller;
        qCInfo(logController) << "Manette branchée :" << qml_controller->GetVIDPID();
        if(mapping)
        {
            connect(qml_controller, &QmlController::navButtonCaptured, mapping, &ControllerMappingController::navButtonCaptured);
            mapping->controllerOpened(controller);
        }
        changed = true;
    }
    if(changed)
        emit listChanged();
}
