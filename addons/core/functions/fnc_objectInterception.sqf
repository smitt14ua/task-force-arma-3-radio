#include "script_component.hpp"

/*
  Name: TFAR_fnc_objectInterception

  Author: Dedmen
    Returns the number of voice-blocking Objects between player and _unit

  Arguments:
    Object

  Return Value:
    Amount of objects between player and _unit <NUMBER>

  Example:
    _unit call TFAR_fnc_objectInterception;

  Public: Yes
*/
//#TODO check isKindOf "House" and other types and transmit that. Houses isolate stronger than freestanding walls


//The raycast is the most expensive part of a position update. Reuse the last result while both ends stayed
//(nearly) where they were, for 0.3 seconds at most.
private _from = eyePos TFAR_currentUnit;
private _to = eyePos _this;
private _key = hashValue _this;
private _cached = GVAR(ObjectInterceptionCache) get _key;
//A plain number comes from TFAR_fnc_objectInterceptionBulkToCache
if (!isNil "_cached" && {_cached isEqualType 0}) exitWith {_cached};
if (!isNil "_cached" && {
    _cached params ["_time", "_cachedFrom", "_cachedTo"];
    diag_tickTime - _time < 0.3 && {_from distance _cachedFrom < 0.5} && {_to distance _cachedTo < 0.5}
}) exitWith {_cached select 3};

private _ins = lineIntersectsSurfaces [
    _from,
    _to,
    TFAR_currentUnit,
    _this,
    true,
    10,
    "FIRE",
    "NONE"
];

private _localParent = objectParent TFAR_currentUnit;
private _remoteParent = objectParent _this;
private _count = {
    private _obj = (_x select 2);
    !isNull _obj && {!(_obj isEqualTo _localParent || _obj isEqualTo _remoteParent) && !isPlayer _obj} //objNull is terrain
} count _ins;

GVAR(ObjectInterceptionCache) set [_key, [diag_tickTime, _from, _to, _count]];
_count
