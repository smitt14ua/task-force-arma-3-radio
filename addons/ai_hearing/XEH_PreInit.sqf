#include "script_component.hpp"

#include "XEH_PREP.inc.sqf"

[
    "TFAR_AICanHearPlayer",
    "CHECKBOX",
    [LSTRING(SETTING_HEADER), LSTRING(SETTING_DESC)],
    localize ELSTRING(settings,global),
    false,
    1,
    FUNC(onSettingChanged)
] call CBA_Settings_fnc_init;

[
    "TFAR_AICanHearSpeaker",
    "CHECKBOX",
    [LSTRING(SETTING_SPEAKER_HEADER), LSTRING(SETTING_SPEAKER_DESC)],
    localize ELSTRING(settings,global),
    false,
    1,
    FUNC(onSettingChanged)
] call CBA_Settings_fnc_init;

[
    QGVAR(reveal),
    {
        params ["_ai", "_target", "_value"];
        // knowsAbout is only accurate where the AI is local
        if (_ai knowsAbout _target > 1.5) exitWith {};
        _ai reveal [_target, _value];
    }
] call CBA_fnc_addEventHandler;
