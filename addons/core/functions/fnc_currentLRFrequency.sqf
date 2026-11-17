#include "script_component.hpp"

/*
  Name: TFAR_fnc_currentLRFrequency

  Author: NKey
    Returns current Frequency of the active LR Radio

  Arguments:
    None

  Return Value:
    Frequency of active LR Radio, nil if there is no active LR radio <STRING>

  Example:
    _LRFrequency = call TFAR_fnc_currentLRFrequency

  Public: Yes
*/

private _radio = call TFAR_fnc_activeLrRadio;
if (isNil "_radio") exitWith {nil};

_radio call TFAR_fnc_getLrFrequency
