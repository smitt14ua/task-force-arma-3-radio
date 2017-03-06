#include "script_component.hpp"

if (alive TFAR_currentUnit) then {
    private _localName = "STR_voice_normal";
    if (TF_speak_volume_level == "Whispering") then {
        TF_speak_volume_level = "normal";
        TF_speak_volume_meters = TFAR_VOLUME_NORMAL;
        _localName = localize "STR_voice_normal";
    } else {
        if (TF_speak_volume_level == "Normal") then {
            TF_speak_volume_level = "yelling";
            TF_speak_volume_meters = TFAR_VOLUME_YELLING;
            _localName = localize "STR_voice_yelling";
        } else {
            TF_speak_volume_level = "whispering";
            TF_speak_volume_meters = TFAR_VOLUME_WHISPERING;
            _localName = localize "STR_voice_whispering";
        }
    };
    private _hintText = format[localize "STR_voice_volume", _localName];
    [parseText (_hintText), 5] call TFAR_fnc_showHint;
    //							unit, range
    ["OnSpeakVolume", [TFAR_currentUnit, TF_speak_volume_meters]] call TFAR_fnc_fireEventHandlers;
};
true