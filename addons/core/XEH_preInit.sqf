#include "script_component.hpp"

#include "XEH_PREP.inc.sqf"

//Needed on all machines (static radios on the server raise it, setVolume broadcasts it). Don't overwrite a value
//a JIP client may already have received from the server.
if (isNil "TF_speakerDistance") then {TF_speakerDistance = 20};

if (isServer && {isMultiplayer || is3DENMultiplayer}) then {
    [] call DFUNC(serverInit);
};
GVAR(SettingsInitialized) = false;
["CBA_settingsInitialized", {
    GVAR(SettingsInitialized) = true;
    if (isServer) then {
        // Replay once more after every CBA callback: other initialization
        // callbacks may themselves have assigned names through the public API.
        {
            private _isLrRadio = _x;
            private _radioType = ["sr", "lr"] select _isLrRadio;
            {
                private _suffix = format ["%1_%2", _radioType, _x];
                private _variableName = "TFAR_frequencyNames_" + _suffix;
                if (!isNil {missionNamespace getVariable (_variableName + "_pending")}) then {
                    [
                        missionNamespace getVariable ["TFAR_setting_frequencyNames_" + _suffix, ""],
                        _variableName,
                        _isLrRadio
                    ] call TFAR_fnc_applyFrequencyNamesSetting;
                };
            } forEach ["west", "east", "independent"];
        } forEach [false, true];
    };
}] call CBA_fnc_addEventhandler;

if (hasInterface) then {
    ["TFAR_frequencyNamesChanged", {
        params ["_variableName", "_definitions"];
        // Carry the table in the event as well as publishing it for JIP, so UI
        // refresh does not depend on public-variable/event delivery order.
        missionNamespace setVariable [_variableName, _definitions];
        call TFAR_fnc_refreshRadioDialogFrequency;
    }] call CBA_fnc_addEventHandler;
};

[] call DFUNC(initCBASettings);

GVAR(VehicleConfigCacheNamespace) = false call CBA_fnc_createNamespace;
GVAR(WeaponConfigCacheNamespace) = false call CBA_fnc_createNamespace;
GVAR(ObjectInterceptionCache) = createHashMap;

VARIABLE_DEFAULT(TFAR_Teamspeak_Channel_Name,"TaskForceRadio");
VARIABLE_DEFAULT(TFAR_Teamspeak_Channel_Password,"123");


if (hasInterface) then {//Clientside Variables
    call TFAR_fnc_initKeybinds;
    //PreInit variablesy

    VARIABLE_DEFAULT(TFAR_DefaultRadio_Backpack_West,"TFAR_rt1523g");
    VARIABLE_DEFAULT(TFAR_DefaultRadio_Backpack_East,"TFAR_mr3000");
    VARIABLE_DEFAULT(TFAR_DefaultRadio_Backpack_Independent,"TFAR_anprc155");

    VARIABLE_DEFAULT(TFAR_DefaultRadio_Personal_West,"TFAR_anprc152");
    VARIABLE_DEFAULT(TFAR_DefaultRadio_Personal_East,"TFAR_fadak");
    VARIABLE_DEFAULT(TFAR_DefaultRadio_Personal_Independent,"TFAR_anprc148jem");

    VARIABLE_DEFAULT(TFAR_DefaultRadio_Rifleman_West,"TFAR_rf7800str");
    VARIABLE_DEFAULT(TFAR_DefaultRadio_Rifleman_East,"TFAR_pnr1000a");
    VARIABLE_DEFAULT(TFAR_DefaultRadio_Rifleman_Independent,"TFAR_anprc154");

    VARIABLE_DEFAULT(TFAR_DefaultRadio_Airborne_West,"TFAR_anarc210");
    VARIABLE_DEFAULT(TFAR_DefaultRadio_Airborne_East,"TFAR_mr6000l");
    VARIABLE_DEFAULT(TFAR_DefaultRadio_Airborne_Independent,"TFAR_anarc164");

    VARIABLE_DEFAULT(TF_terrain_interception_coefficient,7.0);

    MUTEX_INIT(TF_radio_request_mutex);

    GVAR(use_saved_sr_setting) = false;
    GVAR(saved_active_sr_settings) = nil;

    GVAR(use_saved_lr_setting) = false;
    GVAR(saved_active_lr_settings) = nil;

    TF_curator_backpack_1 = nil;
    TF_curator_backpack_2 = nil;
    TF_curator_backpack_3 = nil;

    TF_MAX_SW_VOLUME = 10;
    TF_MAX_LR_VOLUME = 10;

    TF_UNDERWATER_RADIO_DEPTH = -3;//Depth at which LR Radio will still work. Also underwater vehicle LR Radios

    TF_new_line = toString [0xA];
    TF_vertical_tab = toString [0xB];

    TF_last_lr_tangent_press = 0.0;
    //Keys held down (scancode -> time of the first KeyDown) and keys released (scancode -> diag_tickTime), see
    //TFAR_fnc_trackTangentKeys
    GVAR(keysHeld) = createHashMap;
    GVAR(keysReleased) = createHashMap;

    TF_HintFnc = nil;

    TF_tangent_sw_pressed = false;
    TF_tangent_lr_pressed = false;
    //Which tangent set the pressed flag (true = additional), so only that tangent's release ends the transmission
    TF_tangent_sw_additional = false;
    TF_tangent_lr_additional = false;

    TF_speak_volume_level = "normal";
    TF_speak_volume_meters = TFAR_VOLUME_NORMAL;
    TF_min_voice_volume = TFAR_VOLUME_WHISPERING;
    TF_max_voice_volume = TFAR_VOLUME_YELLING;
    TF_sw_dialog_radio = nil;

    TF_last_speak_volume_level = TF_speak_volume_level;
    TF_last_speak_volume_meters = TF_speak_volume_meters;

    tf_lr_dialog_radio = nil;
    TF_lr_active_radio = nil;
    TF_lr_active_curator_radio = nil;


    TFAR_speakerRadios = [];
    GVAR(collectSpeakerRadios) = true;
    TFAR_currentNearPlayers = [];
    TFAR_currentFarPlayers = [];
    TFAR_currentNearPlayersProcessing = [];
    TFAR_currentFarPlayersProcessing = [];

    TFAR_currentNearPlayersProcessed = true;
    TFAR_currentFarPlayersProcessed = true;
    TFAR_lastPlayerScanTime = 0;
    TFAR_volumeIndicatorFlashIndex = 0; //Increments everytime the volumeIndicator is shown when it's set to hidden. Makes sure the Hide function is only called once for the latest show


    tf_lastError = false;

    GVAR(VehicleConfigCacheNamespace) setVariable ["TFAR_fnc_haveSWRadio_lastCache",-1];
    GVAR(VehicleConfigCacheNamespace) setVariable ["TFAR_fnc_haveDDRadio_lastCache",-1];

    GVAR(VehicleConfigCacheNamespace) setVariable ["TFAR_fnc_radiosList_lastCache",-1];
    GVAR(VehicleConfigCacheNamespace) setVariable ["TFAR_fnc_sendSpeakerRadioslastExec",-1];
    GVAR(VehicleConfigCacheNamespace) setVariable ["TFAR_fnc_requestRadios_lastExec",-1];
    GVAR(VehicleConfigCacheNamespace) setVariable ["TFAR_fnc_sendFrequencyInfo_lastExec",-1];
    GVAR(VehicleConfigCacheNamespace) setVariable ["lastRadioSettingUpdate",-1];

    ISNILS(TFAR_takingRadio,2);

    TFAR_lastLoadoutChange = 0;
};

if (!isMultiplayer && !is3DENMultiplayer) exitWith {}; //Don't do anything more in Singleplayer - down here to atleast have Hotkeys available before

if (isServer) then {//Serverside variables
    missionNamespace setVariable ["TF_server_addon_version",TFAR_ADDON_VERSION,true];
    TFAR_RadioCountNamespace = false call CBA_fnc_createNamespace;
    TFAR_RadioSettingsNamespace = true call CBA_fnc_createNamespace;
    publicVariable "TFAR_RadioSettingsNamespace";
};

if (isDedicated) exitWith {}; //Code below here only on clients

//To support channel switching while transmitting, we need to stop transmission on old channel, and start new transmission on new channel

GVAR(currentTransmittingRadio) = []; //List of [radio, isAdditional] that are currently transmitting

["TFAR_event_OnTangent", {
    params ["_unit", "_radio", "_type", "_isAdditional", "_start"];

    private _activeRadios = GVAR(currentTransmittingRadio);

    if (_start) then {
        _activeRadios pushBackUnique [_radio, _isAdditional];
    } else {
        _activeRadios deleteAt (_activeRadios find [_radio, _isAdditional]);
    };
}] call CBA_fnc_addEventHandler;

["TFAR_event_OnSWchannelSet", {
    params ["", "_radio", "_newChannel", "_isAdditional", "_oldChannel"];

    if (_newChannel == _oldChannel) exitWith {};

    //Only restart if the changed channel (primary or additional) is the one transmitting
    if ([_radio, _isAdditional] in GVAR(currentTransmittingRadio)) then {
        //Currently transmitting on that radio, stop transmission on old channel and start new one on new channel.
        //A tangent transmission is ended through TFAR_fnc_endTangentTransmission, which keeps the RELEASED
        //from overtaking a PRESSED sent just before.
        private _transmission = missionNamespace getVariable [QGVAR(tangentTransmission), []];
        if ((_transmission select [0, 2]) isEqualTo [0, _radio] && {(_transmission select 4) isEqualTo _isAdditional}) then {
            [0] call TFAR_fnc_endTangentTransmission;
        } else {
            private _oldFrequency = [_radio, _oldChannel + 1] call TFAR_fnc_getChannelFrequency;
            [_radio, _oldChannel, _oldFrequency, _isAdditional] call TFAR_fnc_doSRTransmitEnd;
        };

        //Additional channel disabled, the additional tangent release can't end the transmission anymore
        if (_newChannel < 0) exitWith {TF_tangent_sw_pressed = false;};
        //The plugin drops a PRESSED that arrives while it still delays the RELEASED (TeamSpeak PTT delay +
        //tangentReleaseDelay), so the new frequency would never be broadcast. Press again once that is over.
        [{
            params ["_radio", "_isAdditional"];
            //Tangent released (or taken over by the other tangent) meanwhile
            if !(TF_tangent_sw_pressed && {TF_tangent_sw_additional isEqualTo _isAdditional}) exitWith {};
            if ([_radio, _isAdditional] in GVAR(currentTransmittingRadio)) exitWith {};
            private _channel = if (_isAdditional) then {_radio call TFAR_fnc_getAdditionalSwChannel} else {_radio call TFAR_fnc_getSwChannel};
            if (_channel < 0) exitWith {TF_tangent_sw_pressed = false;};
            private _frequency = [_radio, _channel + 1] call TFAR_fnc_getChannelFrequency;
            [_radio, _channel, _frequency, _isAdditional] call TFAR_fnc_doSRTransmit;
        //The plugin also adds TeamSpeak's own PTT release delay, which the mod can't know: leave a second for it
        }, [_radio, _isAdditional], (missionNamespace getVariable ["TFAR_tangentReleaseDelay", 0]) / 1000 + 1] call CBA_fnc_waitAndExecute;
    };
}] call CBA_fnc_addEventHandler;

["TFAR_event_OnLRchannelSet", {
    params ["", "_radioObj", "_radioQualif", "_newChannel", "_isAdditional", "_oldChannel"];

    private _radio = [_radioObj, _radioQualif];

    if (_newChannel == _oldChannel) exitWith {};

    //Only restart if the changed channel (primary or additional) is the one transmitting
    if ([_radio, _isAdditional] in GVAR(currentTransmittingRadio)) then {
        //Currently transmitting on that radio, stop transmission on old channel and start new one on new channel
        //(a tangent transmission through TFAR_fnc_endTangentTransmission, see the SW handler)
        private _transmission = missionNamespace getVariable [QGVAR(tangentTransmission), []];
        if ((_transmission select [0, 2]) isEqualTo [1, _radio] && {(_transmission select 4) isEqualTo _isAdditional}) then {
            [1] call TFAR_fnc_endTangentTransmission;
        } else {
            private _oldFrequency = [_radio, _oldChannel + 1] call TFAR_fnc_getChannelFrequency;
            [_radio, _oldChannel, _oldFrequency, _isAdditional] call TFAR_fnc_doLRTransmitEnd;
        };

        //Additional channel disabled, the additional tangent release can't end the transmission anymore
        if (_newChannel < 0) exitWith {TF_tangent_lr_pressed = false;};
        //See the SW handler: the plugin drops a PRESSED during its delayed RELEASED, so press again afterwards
        [{
            params ["_radio", "_isAdditional"];
            if !(TF_tangent_lr_pressed && {TF_tangent_lr_additional isEqualTo _isAdditional}) exitWith {};
            if ([_radio, _isAdditional] in GVAR(currentTransmittingRadio)) exitWith {};
            private _channel = if (_isAdditional) then {_radio call TFAR_fnc_getAdditionalLrChannel} else {_radio call TFAR_fnc_getLrChannel};
            if (_channel < 0) exitWith {TF_tangent_lr_pressed = false;};
            private _frequency = [_radio, _channel + 1] call TFAR_fnc_getChannelFrequency;
            [_radio, _channel, _frequency, _isAdditional] call TFAR_fnc_doLRTransmit;
        //The plugin also adds TeamSpeak's own PTT release delay, which the mod can't know: leave a second for it
        }, [_radio, _isAdditional], (missionNamespace getVariable ["TFAR_tangentReleaseDelay", 0]) / 1000 + 1] call CBA_fnc_waitAndExecute;
    };
}] call CBA_fnc_addEventHandler;

