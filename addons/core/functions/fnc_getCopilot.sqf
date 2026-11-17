#include "script_component.hpp"

/*
  Name: TFAR_fnc_getCopilot

  Author: Grundy
    Returns the unit in the passed vehicle's co-pilot seat

  Arguments:
    0: Vehicle <OBJECT>

  Return Value:
    Unit occupying the vehicle's co-pilot seat, objNull if there is no co-pilot <OBJECT>

  Example:
    _copilot = (vehicle player) call TFAR_fnc_getCopilot;

  Public: Yes
*/

// default co-pilot turret
private _copilotTurret = 0;

// if this is a helicopter, find the turret number that has isCopilot set to 1
if (_this isKindOf "Helicopter") then {
    // get a list of all turret classes, including inherited ones (configClasses/count/select skip inherited entries)
    private _turrets = configProperties [configFile >> "CfgVehicles" >> (typeOf _this) >> "Turrets", "isClass _x", true];

    // find the co-pilot's turret (we assume that there is just one co-pilot), -1 if there is none
    _copilotTurret = _turrets findIf {getNumber (_x >> "isCopilot") == 1};
};

_this turretUnit [_copilotTurret]
