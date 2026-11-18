#include "script_component.hpp"
/*
  Name: TFAR_fnc_addDiaryRecord

  Author: NKey
    Adds diary help record to briefing.

  Arguments:
    None

  Return Value:
    None

  Example:
    call TFAR_fnc_addDiaryRecord;

  Public: No
*/

if (TFAR_ShowDiaryRecord) then {
    player createDiarySubject ["radio", localize LSTRING(subject_name)];
    player createDiaryRecord ["radio", [localize LSTRING(radio_diver), localize LSTRING(radio_diver_text)]];
    //Filled with the player's actual keybinds, refreshed whenever the map (diary) is opened
    GVAR(diaryControlsRecord) = player createDiaryRecord ["radio", [localize LSTRING(radio_control), ""]];
    call TFAR_fnc_updateDiaryControls;
    if (isNil QGVAR(diaryControlsMapEH)) then {
        GVAR(diaryControlsMapEH) = addMissionEventHandler ["Map", {
            params ["_mapIsOpened"];
            if (_mapIsOpened) then {call TFAR_fnc_updateDiaryControls};
        }];
    };
    player createDiaryRecord ["radio", [localize LSTRING(radio_intercept), localize LSTRING(radio_intercept_text)]];
    player createDiaryRecord ["radio", [localize LSTRING(radio_vehicle), localize LSTRING(radio_vehicle_text)]];
};
