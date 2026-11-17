#include "script_component.hpp"

if (isServer) then {
    // A player leaving while connected would keep the phone busy and the rope/handset around forever
    addMissionEventHandler ["HandleDisconnect", {
        params ["_unit"];
        if (!isNil {_unit getVariable "TFAR_ExternalIntercomVehicle"} || {!isNil {_unit getVariable "TFAR_ExternalIntercomRopeIDs"}}) then {
            [_unit getVariable ["TFAR_ExternalIntercomVehicle", objNull], _unit] call TFAR_external_intercom_fnc_disconnect;
        };
        false // Keep default behaviour
    }];
};
