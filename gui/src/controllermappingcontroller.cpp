#include "controllermappingcontroller.h"
#include "controllermanager.h"
#include "qmlcontroller.h"
#include "settings.h"
#include "macnplaylog.h"

#include <QTimer>
#include <SDL.h>

// nom SDL de chaque action PlayStation (« a » = Croix, « dpup » = haut…)
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
		{static_cast<int>(ControllerButtonExt::MISC1)                 , "misc1"},
	};
	return button_map;
}

// table SDL « GUID,nom,action:bouton,… » → action SDL → boutons physiques
static QMap<QString, QStringList> ParseSdlMapping(const QString &sdl_mapping)
{
	QMap<QString, QStringList> out;
	QStringList fields = sdl_mapping.split(u',');
	if(fields.length() < 2)
		return out;
	fields.removeFirst();  // GUID
	fields.removeFirst();  // nom de la manette
	for(const QString &field : std::as_const(fields))
	{
		QStringList parts = field.split(u':');
		if(parts.length() < 2)
			continue;
		const QString key = parts.takeFirst();
		out.insert(key, out.value(key) + parts);
	}
	return out;
}

// clés de la table SDL qui ne sont pas des boutons (informations sur la manette)
static bool IsButtonKey(const QString &key)
{
	return key != "crc" && key != "platform" && key != "type" && key != "hint" && !key.startsWith("sdk");
}

ControllerMappingController::ControllerMappingController(Settings *settings, const QHash<int, QmlController*> *controllers, QObject *parent)
	: QObject(parent), settings(nullptr), controllers(controllers)
{
	setSettings(settings);
}

void ControllerMappingController::setSettings(Settings *new_settings)
{
	if(settings)
		disconnect(settings, nullptr, this, nullptr);
	settings = new_settings;
	connect(settings, &Settings::ControllerMappingsUpdated, this, &ControllerMappingController::applySavedMappings);
	applySavedMappings();
}

void ControllerMappingController::controllerOpened(Controller *opened)
{
	const QString opened_vid_pid = opened->GetVIDPIDString();
	const QString opened_guid = opened->GetGUIDString();
	rememberGuidToUpdate(opened_vid_pid, opened_guid);

	// les anciennes versions enregistraient l'affectation par GUID (propre à chaque système) :
	// on la range désormais sous le VID:PID, identique partout
	const QMap<QString, QString> saved = settings->GetControllerMappings();
	if(saved.contains(opened_guid))
	{
		QString old_mapping = saved.value(opened_guid);
		old_mapping.remove(0, old_mapping.indexOf(",") + 1);
		settings->RemoveControllerMapping(opened_guid);
		settings->SetControllerMapping(opened_vid_pid, old_mapping);
		qCInfo(logController) << "Affectation déplacée du GUID" << opened_guid << "vers le VID:PID" << opened_vid_pid;
	}

	connect(opened, &Controller::UpdatingControllerMapping, this, &ControllerMappingController::startWith);
	connect(opened, &Controller::NewButtonMapping, this, &ControllerMappingController::onButtonPressedWhileSelecting);
}

void ControllerMappingController::controllerClosed(int closed_device_id)
{
	if(closed_device_id != device_id)
		return;
	qCInfo(logController) << "La manette en cours de réglage a été débranchée : réglage abandonné";
	controller = nullptr;
	quit();
}

void ControllerMappingController::rememberGuidToUpdate(const QString &key_vid_pid, const QString &key_guid)
{
	QStringList guids = guids_to_update.value(key_vid_pid);
	guids.append(key_guid);
	guids_to_update.insert(key_vid_pid, guids);
}

void ControllerMappingController::addSdlMapping(const QString &mapping_guid, const QString &mapping)
{
	switch(SDL_GameControllerAddMapping(mapping.toUtf8().constData()))
	{
		case -1:
			qCWarning(logController) << "SDL refuse l'affectation de la manette" << mapping_guid << ":" << SDL_GetError();
			break;
		case 0:
			qCInfo(logController) << "Affectation mise à jour pour la manette" << mapping_guid;
			break;
		case 1:
			qCInfo(logController) << "Affectation ajoutée pour la manette" << mapping_guid;
			break;
		default:
			qCWarning(logController) << "Réponse inattendue de SDL pour la manette" << mapping_guid;
			break;
	}
}

void ControllerMappingController::applySavedMappings()
{
	if(SDL_WasInit(SDL_INIT_GAMECONTROLLER) == 0)
		return;
	const QMap<QString, QString> saved = settings->GetControllerMappings();
	for(auto it = saved.cbegin(); it != saved.cend(); ++it)
	{
		const QString &saved_vid_pid = it.key();
		if(!guids_to_update.contains(saved_vid_pid))
			continue;
		for(const QString &target_guid : guids_to_update.value(saved_vid_pid))
		{
			// on garde la table d'origine avant de la remplacer, pour « Réinitialiser »
			if(!original_mappings.contains(target_guid))
			{
				const SDL_JoystickGUID real_guid = SDL_JoystickGetGUIDFromString(target_guid.toUtf8().constData());
				char *original = SDL_GameControllerMappingForGUID(real_guid);
				const QString original_mapping(original);
				SDL_free(original);
				if(original_mapping.isEmpty())
				{
					// on passe à la manette suivante : une seule manette inconnue ne doit pas bloquer les autres
					qCWarning(logController) << "Table d'origine introuvable pour la manette" << target_guid << ":" << SDL_GetError();
					continue;
				}
				original_mappings.insert(target_guid, original_mapping);
			}
			addSdlMapping(target_guid, QString("%1,%2").arg(target_guid, it.value()));
		}
		guids_to_update.remove(saved_vid_pid);
	}
}

void ControllerMappingController::setInProgress(bool value)
{
	if(in_progress == value)
		return;
	in_progress = value;
	emit inProgressChanged();
}

void ControllerMappingController::setDefaultMapping(bool value)
{
	if(default_mapping == value)
		return;
	default_mapping = value;
	emit defaultMappingChanged();
}

void ControllerMappingController::setAltered(bool value)
{
	if(is_altered == value)
		return;
	is_altered = value;
	emit alteredChanged();
}

void ControllerMappingController::setAnalogStickMapping(bool enabled)
{
	if(analog_stick_mapping == enabled)
		return;
	if(in_progress && controller)
		controller->EnableAnalogStickMapping(enabled);
	analog_stick_mapping = enabled;
	emit analogStickMappingChanged();
}

QVariantList ControllerMappingController::mapping() const
{
	QVariantList out;
	if(!in_progress)
		return out;
	const QMap<int, QString> &names = ChiakiButtonSdlNames();
	for(auto it = names.cbegin(); it != names.cend(); ++it)
	{
		QVariantMap entry;
		entry["buttonName"] = Settings::GetChiakiControllerButtonName(it.key());
		entry["buttonValue"] = it.key();
		entry["physicalButton"] = current_mappings.value(it.value());
		out.append(entry);
	}
	return out;
}

// la manette attend qu'on appuie sur un de ses boutons pour être choisie
void ControllerMappingController::setWaitingForController(bool waiting)
{
	ControllerManager::GetInstance()->creatingControllerMapping(waiting);
}

void ControllerMappingController::begin(bool reset)
{
	reset_requested = reset;
	setWaitingForController(true);
	// une seule manette branchée : inutile de la choisir en appuyant sur un de ses boutons
	// (une même manette peut apparaître deux fois avec SDL sur macOS : on compare VID:PID)
	QTimer::singleShot(0, this, [this]() {
		if(in_progress)
			return;
		Controller *only = nullptr;
		QString only_vid_pid;
		for(auto *qml_controller : std::as_const(*controllers))
		{
			Controller *candidate = qml_controller->GetController();
			if(!candidate || candidate->IsSteamVirtual())
				continue;
			if(only && qml_controller->GetVIDPID() != only_vid_pid)
				return;
			only = candidate;
			only_vid_pid = qml_controller->GetVIDPID();
		}
		if(!only)
			return;
		setWaitingForController(false);
		startWith(only);
	});
}

void ControllerMappingController::abortStart()
{
	device_id = -1;
	controller = nullptr;
}

// la manette choisie : on lit sa table SDL actuelle pour la présenter à l'utilisateur
void ControllerMappingController::startWith(Controller *chosen)
{
	if(SDL_WasInit(SDL_INIT_GAMECONTROLLER) == 0 || in_progress)
		return;
	controller = chosen;
	if(chosen->IsSteamVirtual() && !reset_requested)
	{
		quit();
		emit steamControllerSelected();
		return;
	}
	device_id = chosen->GetDeviceID();
	char *raw_mapping = SDL_GameControllerMapping(chosen->GetController());
	const QString sdl_mapping(raw_mapping);
	SDL_free(raw_mapping);
	qCInfo(logController) << "Réglage de la manette, table actuelle :" << sdl_mapping;
	if(sdl_mapping.isEmpty())
	{
		qCWarning(logController) << "Impossible de lire la table de la manette :" << SDL_GetError();
		abortStart();
		return;
	}
	QStringList fields = sdl_mapping.split(u',');
	if(fields.length() < 2)
	{
		qCWarning(logController) << "Table de manette illisible :" << sdl_mapping;
		abortStart();
		return;
	}

	// format SDL : GUID,nom,action:bouton,action:bouton…
	guid = fields.takeFirst();
	vid_pid = chosen->GetVIDPIDString();
	if(!original_mappings.contains(guid))
	{
		setDefaultMapping(true);
		original_mappings.insert(guid, sdl_mapping);
	}
	chosen->EnableAnalogStickMapping(analog_stick_mapping);
	controller_type = fields.takeFirst();
	if(controller_type == "*")
	{
		controller_type = chosen->GetType();
		if(controller_type.isEmpty())
			controller_type = QString("Unidentified Controller");
	}
	for(const QString &field : std::as_const(fields))
	{
		QStringList parts = field.split(u':');
		if(parts.length() < 2)
			continue;
		const QString key = parts.takeFirst();
		QStringList buttons = current_mappings.value(key) + parts;
		current_mappings.insert(key, buttons);
		if(IsButtonKey(key))
		{
			for(const QString &physical : std::as_const(buttons))
				physical_to_action.insert(physical, key);
		}
	}

	applied_mappings = current_mappings;
	emit controllerTypeChanged();
	emit mappingChanged();
	setInProgress(true);
}

void ControllerMappingController::onButtonPressedWhileSelecting(QString button)
{
	if(!in_progress || !controller)
		return;
	emit buttonSelected(std::move(button));
}

void ControllerMappingController::selectButton()
{
	if(in_progress && controller)
		controller->IsUpdatingMappingButton(true);
}

void ControllerMappingController::stopSelectingButton()
{
	if(in_progress && controller)
		controller->IsUpdatingMappingButton(false);
}

void ControllerMappingController::updateButton(int chiaki_button, QString physical_button, int new_index)
{
	const QString action = ChiakiButtonSdlNames().value(chiaki_button);
	const QString old_action = physical_to_action.value(physical_button);
	if(action == old_action)
		return;
	if(!old_action.isEmpty())
	{
		QStringList old_buttons = current_mappings.value(old_action);
		if(old_buttons.length() > 1)
		{
			old_buttons.removeOne(physical_button);
			current_mappings.insert(old_action, old_buttons);
		}
		else
			current_mappings.remove(old_action);
	}
	QStringList new_buttons = current_mappings.value(action);
	if(new_buttons.length() > new_index)
	{
		physical_to_action.insert(new_buttons.at(new_index), QString());
		new_buttons.remove(new_index);
	}
	if(new_index == 0)
		new_buttons.prepend(physical_button);
	else
		new_buttons.append(physical_button);
	current_mappings.insert(action, new_buttons);
	physical_to_action.insert(physical_button, action);
	setAltered(current_mappings != applied_mappings);
	emit mappingChanged();
}

// le bouton physique fait désormais l'action chiaki_button (0 = rien) ;
// le bouton qui faisait déjà cette action reprend l'ancienne action de celui-ci (échange)
void ControllerMappingController::assignPhysicalButton(QString physical_button, int chiaki_button)
{
	if(!in_progress)
		return;
	const QString target = chiaki_button ? ChiakiButtonSdlNames().value(chiaki_button) : QString();
	const QString old = physical_to_action.value(physical_button);
	if(target == old)
		return;
	if(!old.isEmpty())
	{
		QStringList old_buttons = current_mappings.value(old);
		old_buttons.removeOne(physical_button);
		if(old_buttons.isEmpty())
			current_mappings.remove(old);
		else
			current_mappings.insert(old, old_buttons);
	}
	if(!target.isEmpty())
	{
		QStringList target_buttons = current_mappings.value(target);
		if(!target_buttons.isEmpty() && !old.isEmpty())
		{
			const QString displaced = target_buttons.takeFirst();
			QStringList old_buttons = current_mappings.value(old);
			old_buttons.prepend(displaced);
			current_mappings.insert(old, old_buttons);
			physical_to_action.insert(displaced, old);
		}
		target_buttons.prepend(physical_button);
		current_mappings.insert(target, target_buttons);
	}
	physical_to_action.insert(physical_button, target);
	setAltered(current_mappings != applied_mappings);
	emit mappingChanged();
}

QVariantList ControllerMappingController::physicalButtons() const
{
	QVariantList out;
	if(!in_progress)
		return out;
	const QMap<int, QString> &names = ChiakiButtonSdlNames();
	for(auto it = physical_to_action.cbegin(); it != physical_to_action.cend(); ++it)
	{
		QVariantMap entry;
		entry["physical"] = it.key();
		entry["action"] = it.value().isEmpty() ? 0 : names.key(it.value(), 0);
		out.append(entry);
	}
	return out;
}

QVariantMap ControllerMappingController::physicalButtonActions() const
{
	QVariantMap out;
	if(SDL_WasInit(SDL_INIT_GAMECONTROLLER) == 0)
		return out;
	const QMap<int, QString> &names = ChiakiButtonSdlNames();
	for(auto *qml_controller : std::as_const(*controllers))
	{
		Controller *candidate = qml_controller->GetController();
		if(!candidate || candidate->IsSteamVirtual() || !candidate->GetController())
			continue;
		char *raw_mapping = SDL_GameControllerMapping(candidate->GetController());
		if(!raw_mapping)
			continue;
		const QStringList fields = QString(raw_mapping).split(u',');
		SDL_free(raw_mapping);
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

void ControllerMappingController::startNavCapture()
{
	QmlController::SetNavCapture(true);
}

void ControllerMappingController::stopNavCapture()
{
	QmlController::SetNavCapture(false);
}

// remet la table SDL d'origine de la manette en cours et oublie l'affectation enregistrée
void ControllerMappingController::restoreOriginalMapping()
{
	settings->RemoveControllerMapping(vid_pid);
	addSdlMapping(guid, original_mappings.value(guid));
}

void ControllerMappingController::reset()
{
	const bool can_restore = original_mappings.contains(guid)
		&& SDL_WasInit(SDL_INIT_GAMECONTROLLER) != 0
		&& settings->GetControllerMappings().contains(vid_pid);
	if(can_restore)
	{
		qCInfo(logController) << "Retour à l'affectation d'origine pour" << controller_type;
		restoreOriginalMapping();
	}
	quit();
}

void ControllerMappingController::quit()
{
	if(in_progress && controller)
		controller->IsUpdatingMappingButton(false);
	else
		setWaitingForController(false);
	reset_requested = false;
	setAnalogStickMapping(false);
	controller = nullptr;
	setDefaultMapping(false);
	setAltered(false);
	device_id = -1;
	guid.clear();
	vid_pid.clear();
	controller_type.clear();
	current_mappings.clear();
	applied_mappings.clear();
	physical_to_action.clear();
	setInProgress(false);
	emit controllerTypeChanged();
	emit mappingChanged();
}

void ControllerMappingController::apply()
{
	// on reconstruit la table SDL : nom,action:bouton,action:bouton…
	QString new_mapping = controller_type;
	for(auto it = current_mappings.cbegin(); it != current_mappings.cend(); ++it)
	{
		for(const QString &physical : it.value())
			new_mapping += "," + it.key() + ":" + physical;
	}
	// l'utilisateur est revenu de lui-même à l'affectation d'origine : on l'oublie
	// (comparaison bouton par bouton : l'ordre et le format des deux textes diffèrent)
	if(current_mappings == ParseSdlMapping(original_mappings.value(guid)))
	{
		qCInfo(logController) << "Affectation identique à l'origine pour" << controller_type << ": rien à enregistrer";
		restoreOriginalMapping();
		return;
	}
	qCInfo(logController) << "Nouvelle affectation enregistrée pour" << controller_type << "(" << vid_pid << ")";
	rememberGuidToUpdate(vid_pid, guid);
	settings->SetControllerMapping(vid_pid, new_mapping);
}
