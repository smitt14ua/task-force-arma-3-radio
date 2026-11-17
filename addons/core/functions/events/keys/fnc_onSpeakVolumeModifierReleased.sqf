#include "script_component.hpp"

/*
  Name: TFAR_fnc_onSpeakVolumeModifierReleased

  Author: ACyprus
    Restores any transient volume changes for the player's voice in game

  Arguments:
    None

  Return Value:
    Whether or not the event was handled <BOOL>

  Example:
    call TFAR_fnc_onSpeakVolumeModifierReleased;

  Public: No
*/

//Pressed handler exited early, nothing to restore
if !(missionNamespace getVariable [QGVAR(speakVolumeModifierActive), false]) exitWith {false};
GVAR(speakVolumeModifierActive) = false;

TF_speak_volume_level = TF_last_speak_volume_level;
TF_speak_volume_meters = TF_last_speak_volume_meters;

/*  Tell the plugin that we just changed our volume
    We can't wait for the normal sendFreqInfo interval because the Plugin has to
    know the change before we start transmitting
*/
call TFAR_fnc_sendFrequencyInfo;

//The old style hint is shown without timeout by the Pressed handler
call TFAR_fnc_hideHint;
if (!TFAR_oldVolumeHint && {!TFAR_ShowVolumeHUD}) then {
    (QGVAR(HUDVolumeIndicatorRsc) call BIS_fnc_rscLayer) cutText ["", "PLAIN"];
};

if (!isNil QGVAR(speakVolumeForcedSpeechTime)) then {
    private _fnc_release = {
        ["",format["TANGENT	RELEASED	%1	%2	%3","directSpeechFreq", 0, "directSpeech"],0] call TFAR_fnc_processTangent;
        GVAR(lastTangentRelease) = diag_tickTime; //See TFAR_fnc_startTangentTransmission
    };
    //The plugin processes the newest message first, a RELEASED sent in the same poll interval as the PRESSED
    //would be dropped before it. Delay it like TFAR_fnc_endTangentTransmission and block tangents meanwhile.
    private _remaining = 0.06 - (diag_tickTime - GVAR(speakVolumeForcedSpeechTime));
    GVAR(speakVolumeForcedSpeechTime) = nil;
    if (_remaining <= 0) exitWith {call _fnc_release};

    private _pending = [2, diag_tickTime];
    GVAR(pendingTangentRelease) = _pending;
    [{
        params ["_pending", "_fnc_release"];
        if ((missionNamespace getVariable [QGVAR(pendingTangentRelease), []]) isEqualTo _pending) then {
            GVAR(pendingTangentRelease) = [];
        };
        call _fnc_release;
    }, [_pending, _fnc_release], _remaining] call CBA_fnc_waitAndExecute;
};

call TFAR_fnc_updateSpeakVolumeUI;
["OnSpeakVolumeModifierReleased", [TFAR_currentUnit, TF_speak_volume_level, TF_speak_volume_meters]] call TFAR_fnc_fireEventHandlers;

true
