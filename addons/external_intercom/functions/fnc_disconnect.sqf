#include "script_component.hpp"

/*
  Name: TFAR_external_intercom_fnc_disconnect

  Author: Arend(Saborknight)
    Disconnects the player from the intercom of a vehicle.

  Arguments:
    0: Vehicle object <OBJECT>
    1: Player unit <OBJECT>

  Return Value:
    None

  Example:
    [_vehicle, _player] call TFAR_external_intercom_fnc_disconnect;

  Public: Yes
*/
params [["_vehicle", objNull], "_player"];

{
    if (count _x isEqualTo 2) then {
        [_player, _x select 1] call (_x select 0);
    };
} forEach (_player getVariable ["TFAR_ExternalIntercomEHs", []]);
_player setVariable ["TFAR_ExternalIntercomEHs", nil];
_player setVariable ["TFAR_vehicleIDOverride", nil, true];
_player setVariable ["TFAR_ExternalIntercomVehicle", nil, true];

private _externalIntercomSpeakers = _vehicle getVariable ["TFAR_ExternalIntercomSpeakers", [objNull, []]];

TRACE_3("Disconnecting %1 from %2 with %3",_player,_vehicle,_externalIntercomSpeakers);
// Rope and handset are also stored on the player, so they get cleaned up even if the vehicle is already deleted (null)
private _ropeIDs = _player getVariable ["TFAR_ExternalIntercomRopeIDs", []];
if (_ropeIDs isNotEqualTo []) then {
    _player setVariable ["TFAR_ExternalIntercomRopeIDs", nil, true];
};

if ((_externalIntercomSpeakers select 0) isEqualTo _player) then {
    _externalIntercomSpeakers set [0, objNull];

    if (_ropeIDs isEqualTo []) then {
        _ropeIDs = _vehicle getVariable ["TFAR_ExternalIntercomRopeIDs", []];
    };
    _vehicle setVariable ["TFAR_ExternalIntercomRopeIDs", nil, true];
};

// Kill the rope and model
_ropeIDs params [["_ropeID", objNull], ["_handset", objNull]];
if (!isNull _handset) then {
    deleteVehicle _handset;
};
if (!isNull _ropeID) then {
    ropeDestroy _ropeID;
};

_externalIntercomSpeakers set [1, (_externalIntercomSpeakers select 1) arrayIntersect (_externalIntercomSpeakers select 1)];
(_externalIntercomSpeakers select 1) deleteAt ((_externalIntercomSpeakers select 1) find _player);

// TODO: Fix possible race condition that could occur here. I'm too dumb to know how
_vehicle setVariable ["TFAR_ExternalIntercomSpeakers", _externalIntercomSpeakers, true];

if (hasInterface && {(missionNamespace getVariable ["TFAR_currentUnit", player]) isEqualTo _player}) then { // This feels redundant but... maybe it helps?
    TRACE_1("PhoneConnectionIndicatorRsc is being removed for %1",_player);
    // Hide indicator
    (QGVAR(PhoneConnectionIndicatorRsc) call BIS_fnc_rscLayer) cutText ["", "PLAIN"];
};
