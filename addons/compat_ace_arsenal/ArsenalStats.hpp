class ace_arsenal_stats {
    class statBase;
    class TFAR_radioRangeSR: statBase {
        scope = 2;
        priority = 1;
        stats[] = {"tf_range"};
        displayName = "$STR_a3_rscdisplayarsenal_stat_range";
        showBar = 1;
        showText = 1;
        barStatement = QUOTE([ARR_3((_this select 0) select 0,_this select 1,[ARR_3([ARR_2(0,10000)],[ARR_2(0.01,1)],false)])] call ace_arsenal_fnc_statBarStatement_default);
        textStatement = QUOTE(params [ARR_2('_stat','_config')]; private _rng = getNumber (_config >> _stat select 0); format [ARR_2('%1m',_rng)]);
        condition = QUOTE(getNumber (_this select 1 >> (_this select 0) select 0) > 0);
        tabs[] = {{12}, {}};
    };
    class TFAR_radioRangeLR: statBase {
        scope = 2;
        priority = 1;
        stats[] = {"tf_range"};
        displayName = "$STR_a3_rscdisplayarsenal_stat_range";
        showBar = 1;
        showText = 1;
        barStatement = QUOTE([ARR_3((_this select 0) select 0,_this select 1,[ARR_3([ARR_2(0,100000)],[ARR_2(0.01,1)],false)])] call ace_arsenal_fnc_statBarStatement_default);
        textStatement = QUOTE(params [ARR_2('_stat','_config')]; private _rng = getNumber (_config >> _stat select 0); format [ARR_2('%1m',_rng)]);
        condition = QUOTE((getNumber (_this select 1 >> 'tf_hasLRradio') > 0) && getNumber (_this select 1 >> (_this select 0) select 0) > 0);
        tabs[] = {{5}, {}};
    };
    class TFAR_encryptionCode: statBase {
        scope = 2;
        priority = 1;
        stats[] = {"tf_encryptionCode"};
        displayName = ECSTRING(core,radio_encryption_code);
        showText= 1;
        textStatement = QUOTE(params [ARR_2('_stat','_config')]; private _enc = getText (_config >> _stat select 0); _enc);
        condition = QUOTE(call TFAR_fnc_statCondition_encryptionCode);
        tabs[] = {{12, 5}, {}};
    };
    class TFAR_ExternalIntercom_WirelessEnabled : statBase {
        scope = 2;
        displayName = "Wireless Intercom Enabled";
        priority = 1; // A higher value means the stat will be displayed higher on the page.
        stats[] = {"TFAR_ExternalIntercomWirelessCapable"};
        showBar = 0;
        showText = 1;
        textStatement = "params ['_stats','_config']; format ['%1',getNumber (_config >> _stats select 0) > 0 || {(configName _config) in (missionNamespace getVariable ['TFAR_externalIntercomWirelessHeadgear', []])}]";
        condition = "params ['','_config']; getNumber (_config >> 'TFAR_ExternalIntercomWirelessCapable') > 0 || {(configName _config) in (missionNamespace getVariable ['TFAR_externalIntercomWirelessHeadgear', []])}";
        tabs[] = {{6},{}}; // Arrays of tabs, left array is left tabs, right array is right tabs.
    };
};
