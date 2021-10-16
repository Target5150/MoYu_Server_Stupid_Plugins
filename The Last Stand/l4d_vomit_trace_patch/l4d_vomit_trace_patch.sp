#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "2.4"

public Plugin myinfo =
{
	name = "[L4D] Vomit Trace Patch",
	author = "Forgetest",
	description = "Fix vomit stuck on Infected teammates.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d_vomit_trace_patch"
#define PATCH_GAMERULES "UpdateAbility_GameRules"
#define PATCH_ISVERSUSMODE "UpdateAbility_IsVersusMode"

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	MemoryPatch hPatch = MemoryPatch.CreateFromConf(conf, PATCH_GAMERULES);
	if (!hPatch || !hPatch.Validate())
		SetFailState("Failed to validate patch \"" ... PATCH_GAMERULES ... "\"");
	
	if (!hPatch.Enable())
		SetFailState("Failed to enable patch \"" ... PATCH_GAMERULES ... "\"");
	
	hPatch = MemoryPatch.CreateFromConf(conf, PATCH_ISVERSUSMODE);
	if (!hPatch || !hPatch.Validate())
		SetFailState("Failed to validate patch \"" ... PATCH_ISVERSUSMODE ... "\"");
	
	if (!hPatch.Enable())
		SetFailState("Failed to enable patch \"" ... PATCH_ISVERSUSMODE ... "\"");
	
	delete conf;
}