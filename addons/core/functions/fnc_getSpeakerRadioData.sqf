#include "script_component.hpp"

/*
  Name: TFAR_fnc_getSpeakerRadioData

  Author: Darojax
    Builds one existing-protocol speaker record per receive frequency, so
    main and additional channels retain their independent volumes.

  Arguments:
    0: Radio <STRING|ARRAY>
    1: Radio ID <STRING>
    2: Owner nickname <STRING>
    3: Position (empty for a carried radio) <ARRAY>
    4: Vehicle descriptor <STRING>
    5: Water height <NUMBER> (optional)

  Return Value:
    Encoded speaker records <ARRAY>

  Public: No
*/

params ["_radio", "_radioId", "_nickname", "_position", "_vehicle"];
private _includeWaveZ = count _this > 5;
private _waveZ = _this param [5, 0];

// Channels with the same volume share one record ("f1|f2", the plugin splits the frequency field on |).
// Keeps the SPEAKERS message small, the extension drops messages over ~2 KB.
private _byVolume = [];
{
    _x params ["_frequency", "_volume"];
    private _index = _byVolume findIf {(_x select 1) isEqualTo _volume};
    if (_index < 0) then {
        _byVolume pushBack [[_frequency], _volume];
    } else {
        ((_byVolume select _index) select 0) pushBack _frequency;
    };
} forEach (_radio call TFAR_fnc_getRadioChannelSettings);

_byVolume apply {
    _x params ["_frequencies", "_volume"];
    private _entry = [_radioId, _frequencies joinString "|", _nickname, _position, _volume, _vehicle];
    if (_includeWaveZ) then {
        _entry pushBack _waveZ;
    };
    _entry joinString TF_new_line
}
