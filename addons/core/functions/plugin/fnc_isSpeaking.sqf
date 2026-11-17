#include "script_component.hpp"

/*
  Name: TFAR_fnc_isSpeaking

  Author: Garth de Wet (L-H)
    Check whether a unit is speaking

  Arguments:
    Unit <OBJECT>

  Return Value:
    the unit is speaking <BOOL>

  Example:
    if (player call TFAR_fnc_isSpeaking) then {
        hint "You are speaking";
    };

  Public: Yes
*/

//Same name as the POS update of this unit (TFAR_fnc_processPlayerPositions)
private _unitName = _this getVariable ["TFAR_unitName", name _this];
if (_this getVariable ["TFAR_forceSpectator", false]) then {
    _unitName = _this getVariable ["TFAR_spectatorName", _unitName];
};

//Trailing tab: a request ending in '~' (a name ending in it) would be sent as async by the extension
private _splitResult = ("task_force_radio_pipe" callExtension format ["IS_SPEAKING	%1%2", _unitName, toString [9]]) splitString "";

//_splitResult
//1 - is Speaking
//2 - is Speaking on a Radio frequency that we can currently receive

(_splitResult param [0, "0"]) == "1" //Extension may return an empty string
