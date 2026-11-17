#include "script_component.hpp"

//Only loaded with ACE: ArsenalStats.hpp inherits from ACE Arsenal's statBase
class CfgPatches {
    class ADDON {
        name = "TFAR - ACE Arsenal compatibility";
        units[] = {};
        weapons[] = {};
        requiredVersion = REQUIRED_VERSION;
        requiredAddons[] = {
            "tfar_core",
            "tfar_external_intercom",
            "ace_arsenal"
        };
        skipWhenMissingDependencies = 1;
        author = ECSTRING(core,AUTHORS);
        server_api = SERVER_API_VERSION;
        VERSION_CONFIG;
    };
};

#include "ArsenalStats.hpp"
