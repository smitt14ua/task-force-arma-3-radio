#include "script_component.hpp"

/*
  Name: TFAR_fnc_updateDiaryControls

  Author: Smith
    Fills the "Controls" diary record with the keys currently bound to TFAR's CBA keybinds, so it shows what the
    player actually configured instead of the defaults. Called when the record is created and whenever the map
    (and with it the diary) is opened.

  Arguments:
    None

  Return Value:
    None

  Example:
    call TFAR_fnc_updateDiaryControls;

  Public: No
*/

if (isNil QGVAR(diaryControlsRecord) || {isNull player}) exitWith {};

//Order of the list in the diary, as in the CBA keybinding menu
private _actions = [
    "SWTransmit", "SWTransmitAdditional", "LRTransmit", "LRTransmitAdditional",
    "OpenSWRadioMenu", "OpenLRRadioMenu",
    "CycleSRRadiosNext", "CycleSRRadiosPrev", "CycleLRRadiosNext", "CycleLRRadiosPrev",
    "CycleSRRadioChannelNext", "CycleSRRadioChannelPrev", "CycleLRRadioChannelNext", "CycleLRRadioChannelPrev",
    "SWChannel1", "SWChannel2", "SWChannel3", "SWChannel4", "SWChannel5", "SWChannel6", "SWChannel7", "SWChannel8",
    "LRChannel1", "LRChannel2", "LRChannel3", "LRChannel4", "LRChannel5", "LRChannel6", "LRChannel7", "LRChannel8", "LRChannel9",
    "SWStereoBoth", "SWStereoLeft", "SWStereoRight", "LRStereoBoth", "LRStereoLeft", "LRStereoRight",
    "ChangeSpeakingVolume", "YellingModifier", "WhisperingModifier",
    "ToggleHeadset"
];

//Key and action names go into structured text
private _fnc_escape = {
    private _text = [_this, "&", "&amp;"] call CBA_fnc_replace;
    _text = [_text, "<", "&lt;"] call CBA_fnc_replace;
    [_text, ">", "&gt;"] call CBA_fnc_replace
};
private _fnc_line = {
    params ["_keys", "_description"];
    format ["<font color='#67ED24'>%1</font> - %2", _keys call _fnc_escape, _description call _fnc_escape]
};

private _lines = [[localize LSTRING(radio_control_ptt_key), localize LSTRING(radio_control_ptt)] call _fnc_line];

{
    private _entry = ["TFAR", _x] call CBA_fnc_getKeybind;
    if (!isNil "_entry") then {
        _entry params ["", "", ["_displayName", ""], "", "", "", "", "", ["_keybinds", []]];
        if (_displayName isEqualType []) then {_displayName = _displayName param [0, ""]};
        //A key of 0 or less is "not bound"
        private _keys = (_keybinds select {(_x param [0, -1]) > 0}) apply {_x call CBA_fnc_localizeKey};
        _lines pushBack ([[_keys joinString ", ", "-"] select (_keys isEqualTo []), _displayName] call _fnc_line);
    };
} forEach _actions;

_lines pushBack ([[1, [false, false, false]] call CBA_fnc_localizeKey, localize LSTRING(radio_control_esc)] call _fnc_line); //DIK_ESCAPE

player setDiaryRecordText [["radio", GVAR(diaryControlsRecord)], [localize LSTRING(radio_control), "<br/>" + (_lines joinString "<br/>")]];
