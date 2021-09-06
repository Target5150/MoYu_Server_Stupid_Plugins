#include <sourcemod>
#include <sourcescramble>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Witch Spawn Fix",
	author = "Forgetest",
	description = "Fix witch unable to spawn when tank is in play.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4dvs_witch_spawn_fix"

#define KEY_PATCH_TANKCOUNT "UpdateVersusBossSpawning__tankcount_patch"

MemoryPatch g_hPatch_TankCount;

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	g_hPatch_TankCount = MemoryPatch.CreateFromConf(conf, KEY_PATCH_TANKCOUNT);
	if (!g_hPatch_TankCount || !g_hPatch_TankCount.Validate())
		SetFailState("Failed to validate patch \"" ... KEY_PATCH_TANKCOUNT ... "\"");
	
	delete conf;
	
	ApplyPatch(true);
}

public void OnPluginEnd()
{
	ApplyPatch(false);
}

void ApplyPatch(bool patch)
{
	static bool patched = false;
	if (patch && !patched)
	{
		if (!g_hPatch_TankCount.Enable())
			SetFailState("Failed to enable patch \"" ... KEY_PATCH_TANKCOUNT ... "\"");
		patched = true;
	}
	else if (!patch && patched)
	{
		g_hPatch_TankCount.Disable();
		patched = false;
	}
}