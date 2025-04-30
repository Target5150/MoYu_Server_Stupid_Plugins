#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D] Immediate Respawn Patch",
	author = "Forgetest",
	description = "Fix SI immediately respawning despite all survivors not leaving saferoom.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d_immediate_respawn_patch"
#define PATCH_LASTSURVIVOR "CanBecomeGhost_LastSurvivorLeftStartArea"

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	MemoryPatch hPatch = MemoryPatch.CreateFromConf(conf, PATCH_LASTSURVIVOR);
	if (hPatch == null || !hPatch.Validate())
		SetFailState("Failed to validate patch \"" ... PATCH_LASTSURVIVOR ... "\"");
	
	if (!hPatch.Enable())
		SetFailState("Failed to enable patch \"" ... PATCH_LASTSURVIVOR ... "\"");
	
	delete conf;
}