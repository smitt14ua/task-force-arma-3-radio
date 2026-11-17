#include "script_component.hpp"

/*
  Name: TFAR_fnc_processPlayerPositions

  Author: NKey
    Process some player positions on each call and sends it to the plugin.

  Arguments:
    None

  Return Value:
    None

  Example:
    call TFAR_fnc_processPlayerPositions;

  Public: No
*/

if (getClientStateNumber != 10) exitWith {};

private _startTime = diag_tickTime;

//Process queued Near Players
if (!TFAR_currentNearPlayersProcessed) then {

    if (TFAR_currentNearPlayersProcessing isEqualTo []) exitWith {TFAR_currentNearPlayersProcessed = true};

    private _nearPlayersCount = count TFAR_currentNearPlayersProcessing;

    private _playersToProcessCount = _nearPlayersCount min 30; //Plugin POS info takes about 100 microseconds meaning 10 position updates block for 1 ms
    if (_playersToProcessCount == 0) exitWith {TFAR_currentNearPlayersProcessed = true};

    //Skip dead players (spectators aside): every POS revalidates the plugin's data of that client, undoing its KILLED mark
    private _playersToProcess = (TFAR_currentNearPlayersProcessing select [0, _playersToProcessCount]) select {alive _x || {_x getVariable ["TFAR_forceSpectator", false]}};

    // Bulk calculate object interception, we can use multithreading for it and its quite expensive
    if (TFAR_objectInterceptionEnabled) then {
        //#define _MT_LINE_INTERSECT // Crashy?
        #ifdef _MT_LINE_INTERSECT
        //GVAR(ObjectInterceptionCache) = createHashMap; // We don't need to reset, we will just overwrite when we insert anyway. Downside is that we accumulate all players that ever were on the server. But a hundred hashmap entries is fine.
        _playersToProcess call TFAR_fnc_objectInterceptionBulkToCache;
        #else
        GVAR(ObjectInterceptionCache) = createHashMap; // The normal updates will write to cache, if we don't clear it we'll keep sending stale data
        #endif
    };

    private _unitNames = [];
    {
        private _controlled = _x getVariable ["TFAR_controlledUnit", objNull];
        private _unitName = _x getVariable ["TFAR_unitName", name _x];
        if (_x getVariable ["TFAR_forceSpectator", false]) then {
            _unitName = _x getVariable ["TFAR_spectatorName", _unitName];
        };
        _unitNames pushBack _unitName;

        [[_controlled, _x] select (isNull _controlled), true, _unitName] call TFAR_fnc_sendPlayerInfo;
    } count _playersToProcess; //commy2

    // Fetch their isSpeaking state, in bulk, using the same names as POS.
    // The empty last name ends the request with a tab: a request ending in '~' is sent as async by the extension.
    // Returns one status per name, or [] if the plugin's answer doesn't match.
    private _fnc_isSpeakingBulk = {
        private _request = "IS_SPEAKING_BULK	" + ((_this + [""]) joinString "	");
        private _result = ("task_force_radio_pipe" callExtension _request) splitString "	";
        if (count _result != count _this + 1) exitWith {[]};
        _result resize (count _this);
        _result
    };

    // The request is synchronous and a message over 2040 bytes crashes the plugin, so split it by byte length
    // (count without forceUnicode counts bytes). Each name takes its length plus one tab, the prefix 17 bytes.
    private _pPSS = []; // perPlayerSpeakingStatus
    private _batch = [];
    private _batchSize = 0;
    {
        private _name = _x;
        if (count _name > 1000) then {_name = ""}; //Can't be sent, report as not speaking
        private _size = count _name + 1;
        if (_batchSize + _size > 2000) then {
            _pPSS append (_batch call _fnc_isSpeakingBulk);
            _batch = [];
            _batchSize = 0;
        };
        _batch pushBack _name;
        _batchSize = _batchSize + _size;
    } forEach _unitNames;
    if (_batch isNotEqualTo []) then {
        _pPSS append (_batch call _fnc_isSpeakingBulk);
    };

    private _gVarIsSpe = ["TFAR_isSpeaking", false]; // Micro optimization (Though ASC optimizer would turn this into constant anyway)
    private _gVarIsRec = ["TFAR_isReceiving", false]; // Micro optimization (Though ASC optimizer would turn this into constant anyway)
    if (count _pPSS == count _playersToProcess) then { // if not, then something went weirdly wrong?
        {
            //private _player = _x;
            private _splitResult = (_pPSS select _forEachIndex) splitString "";

            (_splitResult apply {_x isEqualTo "1"}) params ["_isSpeaking", "_isReceiving"];

            // Only run this code if speaking state has changed
            if ((_x getVariable _gVarIsSpe) isNotEqualTo _isSpeaking) then {

                _x setRandomLip _isSpeaking;

                if (_isSpeaking) then {
                    _x setVariable ["TFAR_speakingSince", diag_tickTime];
                };

                _x setVariable ["TFAR_isSpeaking", _isSpeaking];
                _x setVariable ["TF_isSpeaking", _isSpeaking];//#Deprecated variable
                ["OnSpeak", [_x, _isSpeaking]] call TFAR_fnc_fireEventHandlers;
            };

            if ((_x getVariable _gVarIsRec) isNotEqualTo _isReceiving) then {
                _x setVariable ["TFAR_isReceiving", _isReceiving];
                ["OnRadioReceive", [_x, _isReceiving]] call TFAR_fnc_fireEventHandlers;
            };
        } forEach _playersToProcess;
    } else {
        //diag_log ["###", _pPSS, _playersToProcess];
    };

    //Remove processed Units from array
    TFAR_currentNearPlayersProcessing deleteRange [0, _playersToProcessCount];
    //We just processed the last players
    if ((_nearPlayersCount - _playersToProcessCount) isEqualTo 0) exitWith {TFAR_currentNearPlayersProcessed = true};
};

//Don't process anymore if we already blocked too long (5 millisec)
if ((diag_tickTime - _startTime) > 0.005) exitWith {};

//Process queued Far players
if (!TFAR_currentFarPlayersProcessed) then {
    if (TFAR_currentFarPlayersProcessing isEqualTo []) exitWith {
        TFAR_lastFarPlayerProcessTime = diag_tickTime;
        TFAR_currentFarPlayersProcessed = true;
    };

    private _farPlayersCount = count TFAR_currentFarPlayersProcessing;
    private _playersToProcess = _farPlayersCount min 50; //Plugin POS info takes about 10 microseconds meaning 10 position updates block for 0.1 ms
    if (_playersToProcess isEqualTo 0) exitWith {
        TFAR_lastFarPlayerProcessTime = diag_tickTime;
        TFAR_currentFarPlayersProcessed = true;
    };

    {
        private _controlled = _x getVariable ["TFAR_controlledUnit", objNull];
        private _unitName = _x getVariable ["TFAR_unitName", name _x];
        if (_x getVariable ["TFAR_forceSpectator", false]) then {
            _unitName = _x getVariable ["TFAR_spectatorName", _unitName];
        };
        if (isNull _controlled) then {
            [_x, false, _unitName] call TFAR_fnc_sendPlayerInfo;
        } else {
            [_controlled, false, _unitName] call TFAR_fnc_sendPlayerInfo;
        };
    } count ((TFAR_currentFarPlayersProcessing select [0, _playersToProcess]) select {alive _x || {_x getVariable ["TFAR_forceSpectator", false]}}); //commy2 //Skip dead players, see near players

    //Remove processed Units from array
    TFAR_currentFarPlayersProcessing deleteRange [0, _playersToProcess];
    //We just processed the last players
    if ((_farPlayersCount - _playersToProcess) isEqualTo 0) exitWith {
        TFAR_lastFarPlayerProcessTime = diag_tickTime;
        TFAR_currentFarPlayersProcessed = true;
    };
};



//Rescan Players
private _needNearPlayerScan = TFAR_currentNearPlayersProcessed && {(diag_tickTime - TFAR_lastPlayerScanTime) > TFAR_PLAYER_RESCAN_TIME};

if (_needNearPlayerScan) then {
    TFAR_currentNearPlayers = call TFAR_fnc_getNearPlayers;
    /*
    Want to process Curators on NearPlayers because even if they are not near,
    their controlled unit may be.
    */

    TFAR_currentNearPlayers append (allCurators apply {getAssignedCuratorUnit _x} select {!isNull _x});//Add curators

    TFAR_currentNearPlayers = TFAR_currentNearPlayers arrayIntersect TFAR_currentNearPlayers; //Remove duplicates

    //allPlayers includes dead players, they are skipped (spectators aside) when processed
    TFAR_currentFarPlayers = (allPlayers - TFAR_currentNearPlayers) select {isPlayer _x};

    TFAR_lastPlayerScanTime = diag_tickTime;
};

//Queue new updates to plugin if last one processed
if (TFAR_currentNearPlayersProcessed) then {
    call PROFCONTEXT_NORTN(TFAR_fnc_sendSpeakerRadios);//send Speaker radio infos to plugin Has to be here because it needs a variable from NearPlayer processing
    TFAR_currentNearPlayersProcessing = +TFAR_currentNearPlayers;//Copy array for processing
    TFAR_currentNearPlayersProcessed = false;
};

//Process FarPlayers only once a TFAR_FAR_PLAYER_UPDATE_TIME - OR every 0.5 seconds when in spectator
//(not every frame: up to 50 POS plus a DFRAME per frame would overflow the plugin's async queue and drop other messages)
private _farPlayerUpdateTime = [TFAR_FAR_PLAYER_UPDATE_TIME, 0.5] select (TFAR_currentUnit getVariable ["TFAR_forceSpectator", false]);
if ((diag_tickTime - TFAR_lastFarPlayerProcessTime) < _farPlayerUpdateTime) exitWith {};

//Queue new updates to plugin if last one processed
if (TFAR_currentFarPlayersProcessed) then {
    call TFAR_fnc_pluginNextDataFrame;//Doing this here causes NearPlayers to only expire after TFAR_FAR_PLAYER_UPDATE_TIME
    TFAR_currentFarPlayersProcessing = +TFAR_currentFarPlayers;//Copy array for processing
    TFAR_currentFarPlayersProcessed = false;
};
