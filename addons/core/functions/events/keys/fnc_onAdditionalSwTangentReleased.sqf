#include "script_component.hpp"

/*
  Name: TFAR_fnc_onAdditionalSwTangentReleased

  Author: NKey
    Fired when the additional keybinding for SR is relesed.

  Arguments:
    None

  Return Value:
    Whether or not the event was handled <BOOL>

  Example:
    call TFAR_fnc_onAdditionalSwTangentReleased;

  Public: No
*/

if (!TF_tangent_sw_pressed || {!TF_tangent_sw_additional}) exitWith {false};

TF_tangent_sw_pressed = false;
//End what was pressed, the active radio, channel or frequency may have changed meanwhile
[0] call TFAR_fnc_endTangentTransmission;
false
