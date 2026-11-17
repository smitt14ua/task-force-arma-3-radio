#include "script_component.hpp"

/*
  Name: TFAR_fnc_lrRadiosList

  Author: NKey
    List of all the players LR radios

  Arguments:
    unit <OBJECT>

  Return Value:
    List of all the player's LR radios <ARRAY>

  Example:
    _radios = TFAR_currentUnit call TFAR_fnc_LRRadiosList;

  Public: Yes
*/

if (canSuspend) exitWith {
    private _ret = "";
    isNil {_ret = call TFAR_fnc_lrRadiosList};
    _ret
};

//Override and active radio (and curator backpacks) belong to the local player's current unit only
private _isCurrentUnit = _this isEqualTo TFAR_currentUnit;
private _backpackLR = (_this call TFAR_fnc_backpackLr);
private _activeLR = _backpackLR;
private "_overrideLR";
if (_isCurrentUnit) then {
    _activeLR = missionNamespace getVariable ["TF_lr_active_radio", _backpackLR];
    _overrideLR = missionNamespace getVariable "TFAR_OverrideActiveLRRadio";
};
private _vehicleLR = _this call TFAR_fnc_vehicleLr;


private _result = [];

_result pushBackUnique _overrideLR; //This is either override or active
if (_activeLR isEqualTo _vehicleLR) then {_result pushBackUnique _activeLR}; //This is either active or backpack
_result pushBackUnique _backpackLR; //if active one was already backpack, this will do nothing
_result pushBackUnique _vehicleLR; //Will be silently ignored if _vehicleLR is nil

if (_isCurrentUnit && {TFAR_currentUnit == player} && {player call TFAR_fnc_isForcedCurator}) then {
    if !(isNil "TF_curator_backpack_1") then {
        _result pushBack [TF_curator_backpack_1, "TF_curatorBackPack"];
    };
    if !(isNil "TF_curator_backpack_2") then {
        _result pushBack [TF_curator_backpack_2, "TF_curatorBackPack"];
    };
    if !(isNil "TF_curator_backpack_3") then {
        _result pushBack [TF_curator_backpack_3, "TF_curatorBackPack"];
    };
};

//If Player is remote Controlling return Player and controlled Unit's radios.
if (_this isEqualTo TFAR_currentUnit && {player isNotEqualTo TFAR_currentUnit}) then {
        {_result pushBackUnique _x} forEach (player call TFAR_fnc_LRRadiosList); //Override/active radio may be in both lists
};


_result
