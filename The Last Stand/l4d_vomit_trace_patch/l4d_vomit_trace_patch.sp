#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "2.0"

public Plugin myinfo =
{
	name = "[L4D] Vomit Trace Patch",
	author = "Forgetest",
	description = "Fix vomit stuck on Infected teammates.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d_vomit_trace_patch"
#define PATCH_MYINFECTEDPOINTER "ShouldHitEntity_MyInfectedPointer"

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	MemoryPatch hPatch = MemoryPatch.CreateFromConf(conf, PATCH_MYINFECTEDPOINTER);
	if (!hPatch || !hPatch.Validate())
		SetFailState("Failed to validate patch \"" ... PATCH_MYINFECTEDPOINTER ... "\"");
	
	if (!hPatch.Enable())
		SetFailState("Failed to enable patch \"" ... PATCH_MYINFECTEDPOINTER ... "\"");
	
	delete conf;
}