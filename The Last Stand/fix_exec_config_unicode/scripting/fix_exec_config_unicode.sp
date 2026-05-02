#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[Any] Fix Exec Config Unicode",
	author = "Forgetest",
	description = "Fix **quoted** unicode characters being ignored when execing configs.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("fix_exec_config_unicode");
	gd.CreatePatchOrFail("COM_ParseLine_unsigned_patch1", true);
	gd.CreatePatchOrFail("COM_ParseLine_unsigned_patch2", true);
	gd.CreatePatchOrFail("COM_ParseLine_unsigned_patch3", true);
	gd.CreatePatchOrFail("COM_ParseLine_unsigned_patch4", true);
	delete gd;
}
