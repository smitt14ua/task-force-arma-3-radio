#include "script_component.hpp"

/*
  Name: TFAR_fnc_getDefaultRadioSettings

  Author: Dorbedo
    Return array of default radio classes for player.
    The order is:
    1. User-specific frequencies (for LR, an radio with the side-encryptionCode is needed)
    2. Group-specific frequencies (for LR, an radio with the side-encryptionCode is needed)
    3. Side-specific frequencies (if same Frequencies for side is enabled)
    4. Randomized frequencies

  Arguments:
    0: is SR radio <BOOL> (Default: true)
    1: the unit <OBJECT> (Default: TFAR_currentUnit)
    2: the radiotype <STRING> (Default: "")

  Return Value:
    default settings <TYPENAME>

  Example:
    _SRSettings = true call TFAR_fnc_getDefaultRadioSettings;
    _LRSettings = false call TFAR_fnc_getDefaultRadioSettings;

  Public: Yes
*/

params [
    ["_isSR", true, [false]],
    ["_unit", TFAR_currentUnit, [objNull]],
    ["_radioClass", "", [""]]
];

private "_return";
//Set to true below if the settings are only provisional
GVAR(defaultSettingsProvisional) = false;

if (_isSR) then {

    private _frequencies = _unit getVariable ["TFAR_freq_sr", (group _unit) getVariable "TFAR_freq_sr"];

    if (TFAR_SameSRFrequenciesForSide && {isNil "_frequencies"}) then {
        private _sideName = switch (_unit call BIS_fnc_objectSide) do {
            case west : {"west"};
            case east : {"east"};
            default {"independent"};
        };
        _return = missionNamespace getVariable ("TFAR_freq_sr_" + _sideName);
        if (isNil "_return") then {
            // Missing until the server's public variable arrived. Build them like the server does,
            // TFAR_fnc_getSwSettings doesn't store these provisional settings.
            GVAR(defaultSettingsProvisional) = true;
            _return = false call DFUNC(generateSRSettings);
            _return set [2, +(missionNamespace getVariable ["TFAR_defaultFrequencies_sr_" + _sideName, _return select 2])];
        } else {
            // the side settings were generated on the server, so they carry the server's owner UID
            _return = +_return;
            _return set [RADIO_OWNER, getPlayerUID player];
        };
    } else {
        if (isNil "_frequencies") then {
            _return = true call DFUNC(generateSRSettings);
        } else {
            _return = false call DFUNC(generateSRSettings);
            _return set [2, +_frequencies];
        };
    };

    private _encryptionCode = [_radioClass, "tf_encryptionCode", ""] call DFUNC(getWeaponConfigProperty);
    if (_encryptionCode == "tf_guer_radio_code") then {_encryptionCode = "tf_independent_radio_code"};

    _return set [TFAR_CODE_OFFSET, missionNamespace getVariable [_encryptionCode, ""]];

} else {

    private _frequencies = _unit getVariable ["TFAR_freq_lr", (group _unit) getVariable "TFAR_freq_lr"];

    if (TFAR_SameLRFrequenciesForSide && {isNil "_frequencies"}) then {
        private _sideName = switch (_unit call BIS_fnc_objectSide) do {
            case west : {"west"};
            case east : {"east"};
            default {"independent"};
        };
        _return = missionNamespace getVariable ("TFAR_freq_lr_" + _sideName);
        if (isNil "_return") then {
            // Missing until the server's public variable arrived. Build them like the server does,
            // TFAR_fnc_getLrSettings doesn't store these provisional settings.
            GVAR(defaultSettingsProvisional) = true;
            _return = false call DFUNC(generateLRSettings);
            _return set [2, +(missionNamespace getVariable ["TFAR_defaultFrequencies_lr_" + _sideName, _return select 2])];
        } else {
            _return = +_return;
        };
    } else {
        if (isNil "_frequencies") then {
            _return = true call DFUNC(generateLRSettings);
        } else {
            _return = false call DFUNC(generateLRSettings);
            _return set [2, +_frequencies];
        };
    };

    private _encryptionCode = [_radioClass, "tf_encryptionCode", ""] call DFUNC(getVehicleConfigProperty);
    if (_encryptionCode == "tf_guer_radio_code") then {_encryptionCode = "tf_independent_radio_code"};

    _return set [TFAR_CODE_OFFSET, missionNamespace getVariable [_encryptionCode, ""]];

};

_return
