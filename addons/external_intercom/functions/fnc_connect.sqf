#include "script_component.hpp"

/*
  Name: TFAR_external_intercom_fnc_connect

  Author: Arend(Saborknight)
    Connects the player to the intercom of a vehicle, if intercom is enabled on
    the vehicle.

  Arguments:
    0: Vehicle object <OBJECT>
    1: Player unit <OBJECT>
    2: Is Wireless connection? <BOOLEAN>

  Return Value:
    None

  Example:
    [_vehicle, _player, [true]] call TFAR_external_intercom_fnc_connect;

  Public: Yes
*/
params ["_vehicle", "_player", "_actionParams"];
_actionParams params [["_wireless", false, [false]]];

TRACE_3('Connect',_player,_vehicle,_actionParams);

if (!alive _vehicle) exitWith {"no"};

if (TFAR_externalIntercomEnable isEqualTo 2) exitWith {"no"};

if (TFAR_externalIntercomEnable isEqualTo 1 && [side _player, side _vehicle] call BIS_fnc_sideIsEnemy) exitWith {"no"};

if (_wireless && !([_player] call FUNC(hasWirelessHeadgear))) exitWith {
    [parseText format [LLSTRING(HEADGEAR_NOT_WIRELESS_CAPABLE), getText(configFile >> "CfgWeapons" >> headgear _player >> "displayName")]] call TFAR_fnc_showHint;
    "no";
};

private _externalSpeakers = +(_vehicle getVariable ["TFAR_ExternalIntercomSpeakers", [objNull, []]]);
// External Speakers structure is always:
//  [_playerUsingPhone, [_infinitePlayersConnectedWirelessly...]]
if (!isNull (_externalSpeakers select 0) && !_wireless) exitWith {
    [parseText format [LLSTRING(SOMEONE_USING_PHONE), name (_externalSpeakers select 0)]] call TFAR_fnc_showHint;
    "no";
};

// Make sure we disconnect properly from any other connected vehicles & intercoms
private _oldVehicle = _player getVariable "TFAR_ExternalIntercomVehicle";
if (!isNil "_oldVehicle") then {
    [_oldVehicle, _player] call TFAR_external_intercom_fnc_disconnect;
    _externalSpeakers = +(_vehicle getVariable ["TFAR_ExternalIntercomSpeakers", [objNull, []]]);
};

if !(_player getVariable ["TFAR_ExternalIntercomOutOfRangeVehicle", objNull] isEqualTo _vehicle) then {
    _player setVariable ["TFAR_ExternalIntercomOutOfRangeVehicle", nil];
};

// Do the actual sign-on to intercom shit
private _vehicleID = _vehicle getVariable ["TFAR_vehicleIDOverride", netId _vehicle];
_vehicle setVariable ["TFAR_vehicleIDOverride", _vehicleID, true];
_player setVariable ["TFAR_ExternalIntercomVehicle", _vehicle, true];
_player setVariable ["TFAR_vehicleIDOverride", _vehicleID, true];

if (_wireless) then {
    _externalSpeakers select 1 pushBack _player;
} else {
    _externalSpeakers set [0, _player];
};
_vehicle setVariable ["TFAR_ExternalIntercomSpeakers", _externalSpeakers, true];

// Get intercom channel, now that we've signed on to the intercom
private _intercomSlot = [_vehicle, _player] call TFAR_external_intercom_fnc_getIntercomChannel;

_vehicle setVariable [format ["TFAR_IntercomSlot_%1", (netId _player)], _intercomSlot, true];
// Because TFAR checks the "vehicle", and thinks the unit is the vehicle when it's not in a vehicle, so we manually set it
_player setVariable [format ["TFAR_IntercomSlot_%1", (netId _player)], _intercomSlot, true];

(QGVAR(PhoneConnectionIndicatorRsc) call BIS_fnc_rscLayer) cutRsc [QGVAR(PhoneConnectionIndicatorRsc), "PLAIN", 0, true];

// Every connection gets a new token. Keep-alive/reconnect loops of an older connection (e.g. phone -> wireless on the
// same vehicle) see a different token and stop instead of disconnecting the new link.
private _connectionToken = (_player getVariable ["TFAR_ExternalIntercomConnectionToken", 0]) + 1;
_player setVariable ["TFAR_ExternalIntercomConnectionToken", _connectionToken];

private _playerEventhandlers = [];

if (_wireless) then {
    private _headgear = headgear _player;
    private _intercomMaxRange = ((((boundingBoxReal _vehicle) select 2) / 2) + (_vehicle getVariable ["TFAR_externalIntercomMaxRange_Wireless", TFAR_externalIntercomMaxRange_Wireless]));

    // Keep connection alive until out of range or disconnected
    [{
        params ["_vehicle", "_player", "_intercomMaxRange", "_headgear", "_connectionToken"];
        (_vehicle distance _player) > _intercomMaxRange
        || !alive _vehicle
        || !((_player getVariable ["TFAR_ExternalIntercomVehicle", objNull]) isEqualTo _vehicle)
        || !(_headgear isEqualTo (headgear _player))
        || !((_player getVariable ["TFAR_ExternalIntercomConnectionToken", -1]) isEqualTo _connectionToken)
    }, {
        params ["_vehicle", "_player", "_intercomMaxRange", "_headgear", "_connectionToken"];
        // Already disconnected, or connected again (to this or another vehicle) in the meantime
        if !((_player getVariable ["TFAR_ExternalIntercomVehicle", objNull]) isEqualTo _vehicle) exitWith {};
        if !((_player getVariable ["TFAR_ExternalIntercomConnectionToken", -1]) isEqualTo _connectionToken) exitWith {};

        [_vehicle, _player] call TFAR_external_intercom_fnc_disconnect;

        // Allow automatic reconnect for wireless devices if they run out then back into range
        if (alive _vehicle && alive _player && _headgear isEqualTo (headgear _player)) then {
            _player setVariable ["TFAR_ExternalIntercomOutOfRangeVehicle", _vehicle];
            [{
                params ["_vehicle", "_player", "_intercomMaxRange", "_headgear", "_connectionToken"];
                (_vehicle distance _player) < _intercomMaxRange
                || !alive _vehicle
                || !alive _player
                || !(_headgear isEqualTo (headgear _player))
                || !((_player getVariable ["TFAR_ExternalIntercomOutOfRangeVehicle", objNull]) isEqualTo _vehicle)
                || !((_player getVariable ["TFAR_ExternalIntercomConnectionToken", -1]) isEqualTo _connectionToken)
            }, {
                params ["_vehicle", "_player", "_intercomMaxRange", "_headgear", "_connectionToken"];

                if (
                    alive _vehicle
                    && alive _player
                    && _headgear isEqualTo (headgear _player)
                    && (_player getVariable ["TFAR_ExternalIntercomOutOfRangeVehicle", objNull]) isEqualTo _vehicle
                    && (_player getVariable ["TFAR_ExternalIntercomConnectionToken", -1]) isEqualTo _connectionToken
                ) then {
                    [_vehicle, _player, [true]] call TFAR_external_intercom_fnc_connect;
                };
            }, _this] call CBA_fnc_waitUntilAndExecute;
        };
    }, [_vehicle, _player, _intercomMaxRange, _headgear, _connectionToken]] call CBA_fnc_waitUntilAndExecute;

} else {
    private _interactionPointRelative = [_vehicle] call TFAR_external_intercom_fnc_getInteractionPoint;

    // Keep connection alive until out of range or disconnected
    [{
        params ["_vehicle", "_player", "_interactionPointRelative", "_connectionToken"];
        ((_vehicle modelToWorld _interactionPointRelative) distance _player) > _vehicle getVariable ["TFAR_externalIntercomMaxRange_Phone", TFAR_externalIntercomMaxRange_Phone]
        || !alive _vehicle
        || !((_player getVariable ["TFAR_ExternalIntercomVehicle", objNull]) isEqualTo _vehicle)
        || !((_player getVariable ["TFAR_ExternalIntercomConnectionToken", -1]) isEqualTo _connectionToken)
    }, {
        params ["_vehicle", "_player", "_interactionPointRelative", "_connectionToken"];
        // Already disconnected, or connected again (to this or another vehicle) in the meantime
        if !((_player getVariable ["TFAR_ExternalIntercomVehicle", objNull]) isEqualTo _vehicle) exitWith {};
        if !((_player getVariable ["TFAR_ExternalIntercomConnectionToken", -1]) isEqualTo _connectionToken) exitWith {};
        [_vehicle, _player] call TFAR_external_intercom_fnc_disconnect;
    }, [_vehicle, _player, _interactionPointRelative, _connectionToken]] call CBA_fnc_waitUntilAndExecute;

    private _handset = createSimpleObject [QPATHTOF(data\TFAR_handset.p3d), _player selectionPosition "head"];
    _handset attachTo [_player, [-0.14,-0.02,0.02], "head", true];
    _handset setVectorDirAndUp [[-2.5,0.8,0.25],[-1,-1,1]];
    private _ropeID = ropeCreate [_vehicle, _interactionPointRelative vectorAdd [0,0.2,0], _handset, "plug", (_vehicle getVariable ["TFAR_externalIntercomMaxRange_Phone", TFAR_externalIntercomMaxRange_Phone]) - 1, ["", [0,0,-1]], ["", [0,0,-1]], "TFAR_RopeSmallWire"];
    _vehicle setVariable ["TFAR_ExternalIntercomRopeIDs", [_ropeID, _handset], true];
    // Also stored on the player, so disconnect can clean up even if the vehicle was deleted in the meantime
    _player setVariable ["TFAR_ExternalIntercomRopeIDs", [_ropeID, _handset], true];

    // Eventhandlers
    if (_vehicle isNil "TFAR_ExternalIntercomRopeEH") then {
        _vehicle setVariable ["TFAR_ExternalIntercomRopeEH",
            _vehicle addEventHandler ["RopeBreak", {
                params ["_vehicle", "_ropeID"];
                TRACE_1("Rope broke",_this);

                if ((_vehicle getVariable ["TFAR_ExternalIntercomRopeIDs", [nil, nil]] select 0) isEqualTo _ropeID) then {
                    [_vehicle, _vehicle getVariable ["TFAR_ExternalIntercomSpeakers", [objNull, []]] select 0] call TFAR_external_intercom_fnc_disconnect;
                    _vehicle removeEventHandler ["RopeBreak", _thisEventHandler];
                    _vehicle setVariable ["TFAR_ExternalIntercomRopeEH", nil];
                };
            }]
        ];
        TRACE_1("Registered RopeBreak EH",_vehicle getVariable "TFAR_ExternalIntercomRopeEH");
    };

    _playerEventhandlers pushBack [
        {["ace_unconscious", _x select 1] call CBA_fnc_removeEventHandler},
        ["ace_unconscious", {
            params ["_unit", "_active"];
            _thisArgs params ["_player"];
            // Global event, only react to the connected local player
            if (_active && {_unit isEqualTo _player} && {!(_player isNil "TFAR_ExternalIntercomVehicle")}) then {
                [_player getVariable "TFAR_ExternalIntercomVehicle", _player] call TFAR_external_intercom_fnc_disconnect;
            };
        }, [_player]] call CBA_fnc_addEventHandlerArgs
    ];
};

// Just in case the player gets into the vehicle or dies/disconnects

_playerEventhandlers append [[
    {(_this select 0) removeEventHandler ["GetInMan", _x select 1]},
    _player addEventHandler ["GetInMan", {
        params ["_player", "_role", "_vehicle"];
        // Use 'TFAR_ExternalIntercomVehicle' variable, so that it doesn't matter
        // what vehicle the player enters, the intercom will disconnect
        [_player getVariable "TFAR_ExternalIntercomVehicle", _player] call TFAR_external_intercom_fnc_disconnect;

        _player removeEventHandler ["GetInMan", _thisEventHandler];
    }]
],[
    {(_this select 0) removeEventHandler ["Killed", _x select 1]},
    // Killed fires only where the unit is local, so only the connected player's machine disconnects
    _player addEventHandler ["Killed", {
        params ["_player"];
        [_player getVariable "TFAR_ExternalIntercomVehicle", _player] call TFAR_external_intercom_fnc_disconnect;
        _player removeEventHandler ["Killed", _thisEventHandler];
    }]
]];

_player setVariable ["TFAR_ExternalIntercomEHs", _playerEventhandlers];

// Just in case the vehicle is destroyed
if (_vehicle isNil "TFAR_ExternalIntercomEH") then {
    _vehicle setVariable ["TFAR_ExternalIntercomEH",
        _vehicle addMPEventHandler ["MPKilled", {
            params ["_vehicle"];
            // MPKilled fires on every machine, each machine disconnects its own connected units (phone user and wireless)
            (_vehicle getVariable ["TFAR_ExternalIntercomSpeakers", [objNull, []]]) params ["_phoneUser", "_wirelessUsers"];
            {
                if (local _x) then {
                    [_vehicle, _x] call TFAR_external_intercom_fnc_disconnect;
                };
            } forEach ((_wirelessUsers + [_phoneUser]) select {!isNull _x});
            _vehicle removeMPEventHandler ["MPKilled", _thisEventHandler];
        }],
        true
    ];
};
