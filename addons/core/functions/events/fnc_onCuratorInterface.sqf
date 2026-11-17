#include "script_component.hpp"

/*
  Name: TFAR_fnc_onCuratorInterface

  Author: Dedmen
    Eventhandler that fires when opening the Curator Interface

  Arguments:
    None

  Return Value:
    None

  Example:
    call TFAR_fnc_onCuratorInterface;

  Public: No
*/
params [["_display",displayNull],["_eventType","Close"]];

switch _eventType do {
    case "Open": {
        //CBA adds its keybinding handlers to the curator display itself

        if (player call TFAR_fnc_isForcedCurator) then {
            //Add PFH that moves curatorLogic's position to camera position,
            //so we can hear players relative to camera
            //Reopening the interface before the old handler noticed the closed camera must not add a second one
            if (!isNil QGVAR(curatorCameraPFH)) then {
                [GVAR(curatorCameraPFH)] call CBA_fnc_removePerFrameHandler;
            };
            GVAR(curatorCameraPFH) = [{
                params ["_args","_handle"];
                if !(isNull curatorCamera) then {
                    //setPosATL/setDir are synchronised over the network, skip them while the camera stands still
                    private _position = getPosATL curatorCamera;
                    private _direction = getDir curatorCamera;
                    if ((_position distance (getPosATL player)) > 0.1 || {abs (_direction - getDir player) > 1}) then {
                        player setPosATL _position;
                        player setDir _direction;
                    };
                } else {
                    [_handle] call CBA_fnc_removePerFrameHandler;
                    GVAR(curatorCameraPFH) = nil;
                };
            },0.1] call CBA_fnc_addPerFrameHandler;//Don't need every frame.. every 100ms is enough
        };


        if (TFAR_ShowVolumeHUD) then {
            (QGVAR(HUDVolumeIndicatorRsc) call BIS_fnc_rscLayer) cutText ["", "PLAIN"];
        };
        if (TFAR_curatorCamEars) then {
            player setVariable ["TF_fnc_position", {private _pctw = positionCameraToWorld [0,0,0]; [AGLToASL _pctw, (positionCameraToWorld [0,0,1]) vectorDiff _pctw]}];
        }
    };
    case "Close": {
        if (TFAR_ShowVolumeHUD) then {
            (QGVAR(HUDVolumeIndicatorRsc) call BIS_fnc_rscLayer) cutRsc [QGVAR(HUDVolumeIndicatorRsc), "PLAIN", 0, true];
        };
        call TFAR_fnc_updateSpeakVolumeUI;
        if (TFAR_curatorCamEars) then {
            player setVariable ["TF_fnc_position", nil];
        }
    };
};
