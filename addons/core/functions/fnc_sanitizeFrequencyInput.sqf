#include "script_component.hpp"

/*
  Name: TFAR_fnc_sanitizeFrequencyInput

  Author: Smith
    Keeps a radio dialog's frequency field a number while the player types: digits stay, letters are removed and
    any other character (comma, space, ...) becomes a dot. Only the first dot is kept. The cursor stays in place.

  Arguments:
    0: Frequency edit control <CONTROL>
    1: New text <STRING>

  Return Value:
    None

  Example:
    onEditChanged = "_this call TFAR_fnc_sanitizeFrequencyInput";

  Public: No
*/

params [["_control", controlNull, [controlNull]], ["_text", "", [""]]];

if (isNull _control) exitWith {};
//Only while the player edits the frequency: the field also shows the channel name (TFAR_fnc_updateRadioDialogFrequency)
if !(_control getVariable ["TFAR_frequencyEditing", false]) exitWith {};
if (_control getVariable ["TFAR_frequencyIsName", false]) exitWith {};

(ctrlTextSelection _control) params [["_selectionStart", 0, [0]], ["_selectionLength", 0, [0]]];
private _cursor = _selectionStart + _selectionLength;

private _sanitized = [];
private _hasDot = false;
private _newCursor = 0;
{
    private _keep = -1;
    if (_x >= 48 && {_x <= 57}) then { //0-9
        _keep = _x;
    } else {
        private _char = toString [_x];
        //Not a letter (no case): becomes the dot, if there is none yet
        if (!_hasDot && {toLower _char isEqualTo toUpper _char}) then {
            _keep = 46;
            _hasDot = true;
        };
    };
    if (_keep != -1) then {
        _sanitized pushBack _keep;
        if (_forEachIndex < _cursor) then {_newCursor = _newCursor + 1};
    };
} forEach (toArray _text);

_sanitized = toString _sanitized;
if (_sanitized isEqualTo _text) exitWith {};

//Fires onEditChanged again, with nothing left to change
_control ctrlSetText _sanitized;
_control ctrlSetTextSelection [_newCursor, 0];
