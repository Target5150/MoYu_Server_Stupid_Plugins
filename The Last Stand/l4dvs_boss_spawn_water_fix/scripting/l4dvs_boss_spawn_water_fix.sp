#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Boss Spawn Water Fix",
	author = "Forgetest",
	description = "Fix boss unable to spawn on watery areas.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4dvs_boss_spawn_water_fix"

#define KEY_PATCH_TANKSPAWN "UpdateVersusBossSpawning__tankspawn_underwater_patch"
#define KEY_PATCH_WITCHSPAWN "UpdateVersusBossSpawning__witchspawn_underwater_patch"

public void OnPluginStart()
{
	GameData gd = new GameData(GAMEDATA_FILE);
	if (gd == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	CreateEnabledPatch(gd, KEY_PATCH_TANKSPAWN);
	CreateEnabledPatch(gd, KEY_PATCH_WITCHSPAWN);
	
	delete gd;
}

MemoryPatch CreateEnabledPatch(GameData gd, const char[] name)
{
	MemoryPatch hPatch = MemoryPatch.CreateFromConf(gd, name);
	if (!hPatch.Enable())
		SetFailState("Failed to patch \"%s\"", name);
	
	return hPatch;
}
