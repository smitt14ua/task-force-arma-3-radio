#include "script_component.hpp"

/* ----------------------------------------------------------------------------
  Name: TFAR_fnc_isTurnedOut

  Author:
    shukari

  Description:
    Checks whether a unit is attenuated, meaning in another compartment outside of outside voice range.

  Arguments:
    0: Unit to check <OBJECT>

  Return Value:
    0: isTurnedOut <BOOL>
    1: isolation amount <NUMBER> (only meaningful if not turned out; otherwise an internal reason code)

  Example:
    if !(([player] call TFAR_fnc_isTurnedOut) select 0) then {
        player sideChat "I cant hear you outside guy!";
    };

  Config & Variable API:
    Example:
        Config: CBA_attenuatedRoles[] = {{"driver", -1, "ani_window_1"}, {"turret", {0}, "ani_window_2"}, {"gunner", -1, "ani_window_4"}};
        Variable:  _vehicle setVariable ["CBA_attenuatedRoles", [["driver", -1, "ani_window_1"]]];
    Attributes
        role
        cargoindex or turretPath
        animation for attenuated ("" for always NOT attenuated)
    Info
        variable overrides config
---------------------------------------------------------------------------- */
params [["_unit", objNull, [objNull]]];

// outside of the vehicle or turned out
if (isNull objectParent _unit) exitWith {[true, 1]};
if (isTurnedOut _unit) exitWith {[true, 2]};

// A position update calls this twice per unit (TFAR_fnc_vehicleId and TFAR_fnc_vehicleIsIsolatedAndInside), cache it for the frame
private _cache = _unit getVariable QGVAR(isTurnedOutCache);
if (!isNil "_cache" && {(_cache select 0) == diag_frameNo}) exitWith {+(_cache select 1)};

private _result = call {
    private _vehicle = vehicle _unit;

    // Config values don't change at runtime, cache them per vehicle class (this runs for every unit in a vehicle on
    // every position update): [open vehicle, config CBA_attenuatedRoles, soundAttenuationCargo, attenuation amount]
    if (isNil QGVAR(isTurnedOutConfigCache)) then {GVAR(isTurnedOutConfigCache) = createHashMap};
    private _vehicleType = typeOf _vehicle;
    private _vehicleKey = [_vehicleType, TFAR_experimentalVehicleIsolation];
    private _vehicleData = GVAR(isTurnedOutConfigCache) get _vehicleKey;
    if (isNil "_vehicleData") then {
        private _config = configFile >> "CfgVehicles" >> _vehicleType;
        // class CfgSoundEffects >> class AttenuationsEffects
        private _attenuationType = getText (_config >> "attenuationEffectType");

        private _attenuation = [_vehicleType, "tf_isolatedAmount", 0.0] call TFAR_fnc_getVehicleConfigProperty;
        if (TFAR_experimentalVehicleIsolation) then {
            private _type = configFile >> "CfgSoundEffects" >> "AttenuationsEffects" >> _attenuationType;
            private _gains = getArray (_type >> "Equalizer0" >> "gain") + getArray (_type >> "Equalizer1" >> "gain");
            if (_gains isNotEqualTo []) then {
                private _sum = 0;
                {
                    _sum = _sum + _x;
                } forEach _gains;
                _attenuation = 1 - (_sum / count _gains);
            };
        };

        _vehicleData = [
            _attenuationType in ["OpenCarAttenuation", "OpenHeliAttenuation", "jsrs_OpenCar_Attenuation", "jsrs_SemiOpenCar_Attenuation"],
            getArray (_config >> "CBA_attenuatedRoles"),
            getArray (_config >> "soundAttenuationCargo"),
            _attenuation
        ];
        GVAR(isTurnedOutConfigCache) set [_vehicleKey, _vehicleData];
    };
    _vehicleData params ["_isOpenVehicle", "_configAttenuatedRoles", "_attenuateCargo", "_attenuation"];

    // open vehicle
    if (_isOpenVehicle) exitWith {[true, 3]};

    private _fullCrew = fullCrew _vehicle;
    private _crewIndex = _fullCrew findIf {_unit isEqualTo (_x param [0, objNull])};
    if (_crewIndex == -1) exitWith {[true,7]}; //This can apparently happen. No idea how but it happened.
    (_fullCrew select _crewIndex) params ["", "_role", "_cargoIndex", "_turretPath", "_isFFV"];
    _role = toLower _role;
    private _return = !_isFFV;

    // Turret config, cached like the vehicle's: [enabledByAnimationSource, gunnerAction]
    private _turretKey = [_vehicleType, _turretPath];
    private _turretData = GVAR(isTurnedOutConfigCache) get _turretKey;
    if (isNil "_turretData") then {
        private _turret = [_vehicle, _turretPath] call CBA_fnc_getTurret;
        _turretData = [getText (_turret >> "enabledByAnimationSource"), getText (_turret >> "gunnerAction")];
        GVAR(isTurnedOutConfigCache) set [_turretKey, _turretData];
    };
    _turretData params ["_enabledAnim", "_gunnerAction"];

    // override for enabledByAnimationSource FFVs
    if (!(_enabledAnim isEqualTo "") && {(_vehicle animationSourcePhase _enabledAnim) < 1}) then {
        _return = true;
    };

    // API
    // copy, so the array stored in the vehicle variable doesn't grow on every call
    private _attenuationAPI = +(_vehicle getVariable ["CBA_attenuatedRoles", []]);
    _attenuationAPI append _configAttenuatedRoles;

    if !(_attenuationAPI isEqualTo []) then {
        {
            // second entry is a cargo index <NUMBER> or a turret path <ARRAY>
            _x params [["_configRole", "", [""]], ["_cargoOrTurretIndex", -1, [0, []]], ["_animation", "", [""]]];

            if (_configRole == _role && {_cargoOrTurretIndex isEqualTo ([_cargoIndex, _turretPath] select (_cargoOrTurretIndex isEqualType []))}) exitWith {
                _return = if !(_animation isEqualTo "") then {
                    !((_vehicle animationSourcePhase _animation) > 0)
                } else {
                    false // is always outside
                };
            };
        } forEach _attenuationAPI;
    };

    // Fix for vanilla tank commanders
    if (!_return && {_role isEqualTo "commander"}) exitWith {[false, _attenuation]};

    // This exit is crucial for the difference between FFV and Override and normale roles
    if (!_return) exitWith {[true, 4]}; // return

    if (_role in ["gunner", "turret"]) exitWith {
        [animationState _unit == _gunnerAction, _attenuation]
    };

    if (_role isEqualTo "cargo") exitWith {
        // if attenuate array has less elements than the current cargo index, use the last value of the array
        private _cargoIndex = _cargoIndex min (count _attenuateCargo - 1);
        private _value = _attenuateCargo param [_cargoIndex, 1];

        if (_value == 1) then {
            [false, _attenuation]
        } else {
            [_value == 0, _value]
        }

    };

    [false, _attenuation]
};

_unit setVariable [QGVAR(isTurnedOutCache), [diag_frameNo, _result]];
+_result
