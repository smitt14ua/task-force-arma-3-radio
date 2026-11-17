#include "script_component.hpp"

/*
  Name: TFAR_fnc_releaseAllTangents

  Author: Dedmen
    Stops all outgoing radio transmissions

  Arguments:
    the player <OBJECT>

  Return Value:
    None

  Example:
    player call TFAR_fnc_releaseAllTangents;

  Public: Yes
*/

params ["_unit"];

//Called from camera/spectator paths, also in singleplayer and Eden where the client isn't initialized
if (isNil "TFAR_currentUnit") exitWith {};

// Stops transmissions cleanly in-game (takes care of hint and in-game variables)
if (_unit isEqualTo TFAR_currentUnit) then {
    call TFAR_fnc_onSwTangentReleased;
    call TFAR_fnc_onAdditionalSwTangentReleased;
    call TFAR_fnc_onLRTangentReleased;
    call TFAR_fnc_onAdditionalLRTangentReleased;
    //Transmission not started by a tangent keybinding
    [] call TFAR_fnc_endTangentTransmission;
    //A held speak volume modifier (death, unit change: its key release can get lost) blocks the radio tangents
    //while it forces direct speech, restore it
    call TFAR_fnc_onSpeakVolumeModifierReleased;
};

"task_force_radio_pipe" callExtension (format ["RELEASE_ALL_TANGENTS	%1~", _unit getVariable ["TFAR_unitName", name _unit]]); //Async call will always return "OK"
