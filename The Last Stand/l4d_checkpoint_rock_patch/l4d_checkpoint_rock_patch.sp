#include <sourcemod>
#include <sourcescramble>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Checkpoint Rock Patch",
	author = "Forgetest",
	description = "Memory patch for rock hitbox being stricter to land survivors in saferoom.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d_checkpoint_rock_patch"
#define PATCH_KEY "ForEachPlayer_ProximityCheck"

MemoryPatch g_hPatch;

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	g_hPatch = MemoryPatch.CreateFromConf(conf, PATCH_KEY);
	
	delete conf;
	
	if (g_hPatch == null)
		SetFailState("Failed to create MemoryPatch \"" ... PATCH_KEY ... "\"");
	
	if (!g_hPatch.Validate())
		SetFailState("Failed to validate MemoryPatch \"" ... PATCH_KEY ... "\"");
		
	ApplyPatch(true);
}

public void OnPluginEnd()
{
	ApplyPatch(false);
}

void ApplyPatch(bool patch)
{
	if (patch)
	{
		if (!g_hPatch.Enable()) SetFailState("Failed to enable MemoryPatch \"" ... PATCH_KEY ... "\"");
	}
	else
	{
		g_hPatch.Disable();
	}
}