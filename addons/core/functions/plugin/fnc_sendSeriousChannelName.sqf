#include "script_component.hpp"

/*
  Name: TFAR_fnc_sendSeriousChannelName

  Author: Smith
    Sends the TeamSpeak channel name to the plugin, which moves the player into that channel with the password set
    at that moment. Sent 0.1 s after the last call, so a password sent just before is applied first (older plugins
    take queued messages newest first), and the calls at mission start (plugin config request, the name and
    password CBA settings) give one send: each send was a move request, the second one failing with
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

GVAR(channelNameRequest) = (missionNamespace getVariable [QGVAR(channelNameRequest), 0]) + 1;
[{
    if (_this != GVAR(channelNameRequest)) exitWith {}; //a later call sends it
    ["serious_channelName", missionNamespace getVariable ["TFAR_Teamspeak_Channel_Name", "TaskForceRadio"]] call TFAR_fnc_setPluginSetting;
}, GVAR(channelNameRequest), 0.1] call CBA_fnc_waitAndExecute;
