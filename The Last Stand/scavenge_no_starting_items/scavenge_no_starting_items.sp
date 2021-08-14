#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D2] Scavenge No Starting Items",
	author = "Forgetest",
	description = "Memory patch to remove starting kits and pills in scavenge mode.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "scavenge_no_starting_items"
#define PATCH_KEY "CTerrorPlayer_GiveDefaultItem"

MemoryPatch g_hPatch;

public void OnPluginStart()
{
	Handle data = LoadGameConfigFile(GAMEDATA_FILE);
	if (data == null)
	{
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	}
	
	g_hPatch = MemoryPatch.CreateFromConf(data, PATCH_KEY);
	if (g_hPatch == null)
	{
		SetFailState("Failed to create MemoryPatch \"" ... PATCH_KEY ..."\"");
	}
	
	if (!g_hPatch.Validate())
	{
		SetFailState("Failed to validate MemoryPatch \"" ... PATCH_KEY ..."\"");
	}
	
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
		if (!g_hPatch.Enable()) SetFailState("Failed to enable MemoryPatch \"" ... PATCH_KEY ..."\"");
		patched = true;
	}
	else if (!patch && patched)
	{
		g_hPatch.Disable();
		patched = false;
	}
}