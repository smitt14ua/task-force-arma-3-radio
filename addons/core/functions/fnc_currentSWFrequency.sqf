#include "script_component.hpp"

/*
  Name: TFAR_fnc_currentSWFrequency

  Author: NKey
    Returns current Frequency of the active SR Radio

  Arguments:
    None

  Return Value:
    Frequency of active SR Radio, nil if there is no active SR radio <STRING>

  Example:
    _SRFrequency = call TFAR_fnc_currentSWFrequency

  Public: Yes
*/

private _radio = call TFAR_fnc_activeSwRadio;
if (isNil "_radio") exitWith {nil};

_radio call TFAR_fnc_getSwFrequency
