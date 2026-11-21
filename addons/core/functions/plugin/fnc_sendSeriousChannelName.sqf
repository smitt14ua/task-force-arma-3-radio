#include "script_component.hpp"

/*
  Name: TFAR_fnc_sendSeriousChannelName

  Author: Smith
    Sends the TeamSpeak channel name to the plugin, which moves the player into that channel.
    Sent 0.1 s later so a password sent just before is applied first (older plugins take queued messages newest
    first). Several callers send it at mission start (plugin config request, the name and password CBA settings),
    so calls are merged: one pending send at a time, and the same name and password again within 2 s is skipped.
    Each send made the plugin request a move; a second one before the server confirmed the first got
    "already member of channel".

  Arguments:
    None

  Return Value:
    None

  Example:
    call TFAR_fnc_sendSeriousChannelName;

  Public: No
*/

if (getClientStateNumber != 10) exitWith {}; //setPluginSetting would not send it yet either
if (!isNil QGVAR(channelNamePending)) exitWith {};
GVAR(channelNamePending) = true;

[{
    GVAR(channelNamePending) = nil;
    private _sent = [
        missionNamespace getVariable ["TFAR_Teamspeak_Channel_Name", "TaskForceRadio"],
        missionNamespace getVariable ["TFAR_Teamspeak_Channel_Password", "123"]
    ];
    (missionNamespace getVariable [QGVAR(channelNameLastSent), []]) params [["_lastSent", []], ["_lastTime", -1e9]];
    if (_lastSent isEqualTo _sent && {diag_tickTime - _lastTime < 2}) exitWith {};
    GVAR(channelNameLastSent) = [_sent, diag_tickTime];
    ["serious_channelName", _sent select 0] call TFAR_fnc_setPluginSetting;
}, [], 0.1] call CBA_fnc_waitAndExecute;
