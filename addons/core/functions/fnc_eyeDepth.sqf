#include "script_component.hpp"

/*
  Name: TFAR_fnc_eyeDepth

  Author: Garth de Wet (L-H)
    returns the eye height of a unit above the water surface (negative when underwater)

  Arguments:
    unit <OBJECT>

  Return Value:
    Eye height ASLW <NUMBER>

  Example:
    player call TFAR_fnc_eyeDepth;

  Public: Yes
*/

((eyepos _this) select 2) + ((getPosASLW _this) select 2) - ((getPosASL _this) select 2)
