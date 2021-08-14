#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sourcescramble>

#define PLUGIN_VERSION "1.1"

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

bool g_bMapStarted = false;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bMapStarted = late;
}

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
	
	FindConVar("mp_gamemode").AddChangeHook(OnGamemodeChanged);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	ApplyPatch(IsAllowedGamemode());
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

public void OnGamemodeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ApplyPatch(IsAllowedGamemode());
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ApplyPatch(IsAllowedGamemode());
}

// =======================================
// IsAllowedGamemode() credie to Silvers
// =======================================

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

int g_iGamemode;
bool IsAllowedGamemode()
{
	if (!g_bMapStarted) return false;
	
	g_iGamemode = 0;
	
	int entity = CreateEntityByName("info_gamemode");
	if( IsValidEntity(entity) )
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
			RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
	}
	
	return g_iGamemode == 4; // Scavenge only
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )				g_iGamemode = 1;
	else if( strcmp(output, "OnVersus") == 0 )		g_iGamemode = 2;
	else if( strcmp(output, "OnSurvival") == 0 )	g_iGamemode = 3;
	else if( strcmp(output, "OnScavenge") == 0 )	g_iGamemode = 4;
}
