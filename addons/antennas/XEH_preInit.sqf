#include "script_component.hpp"

#include "XEH_PREP.inc.sqf"

if (!hasInterface) exitWith {}; //Don't need on Headless and dedicated Servers

GVAR(radioTowerList) = [] call CBA_fnc_hashCreate;

["TFAR_ConfigRefresh",{
    #ifdef DEBUG_MODE_FULL
        systemChat "TFAR_ConfigRefresh";
    #endif
    ([(GVAR(radioTowerList))] call CBA_fnc_hashKeys) call FUNC(pluginAddRadioTower);
}] call CBA_fnc_addEventHandler;

// Killed only fires where the tower is local, it broadcasts this event so every client stops relaying over it
[QGVAR(towerKilled), {
    params ["_tower"];
    [_tower] call FUNC(deleteRadioTower);
}] call CBA_fnc_addEventHandler;
