#include "script_component.hpp"

/*
  Name: TFAR_fnc_onAdditionalLRTangentReleased

  Author: NKey
    Fired when the additional keybinding for LR is relesed.

  Arguments:
    None

  Return Value:
    Whether or not the event was handled <BOOL>

  Example:
    call TFAR_fnc_onAdditionalLRTangentReleased;

  Public: No
*/

if (!TF_tangent_lr_pressed || {!TF_tangent_lr_additional}) exitWith {false};

TF_tangent_lr_pressed = false;
//End what was pressed, the active radio, channel or frequency may have changed meanwhile
[1] call TFAR_fnc_endTangentTransmission;
false
