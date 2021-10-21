#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define PLUGIN_VERSION "2.1"

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
#define KEY_UPDATEABILITY "CBaseAbility::UpdateAbility"

MemoryPatch g_hPatch;
DynamicHook g_hDHook;

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	g_hPatch = MemoryPatch.CreateFromConf(conf, PATCH_MYINFECTEDPOINTER);
	if (!g_hPatch || !g_hPatch.Validate())
		SetFailState("Failed to validate patch \"" ... PATCH_MYINFECTEDPOINTER ... "\"");
	
	int iCVomit_UpdateAbility = GameConfGetOffset(conf, KEY_UPDATEABILITY);
	if (iCVomit_UpdateAbility == -1)
		SetFailState("Missing offset \"" ... KEY_UPDATEABILITY ... "\"");
	
	g_hDHook = new DynamicHook(iCVomit_UpdateAbility, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);
	if (g_hDHook == null)
		SetFailState("Failed to create dynamic hook on \"" ... KEY_UPDATEABILITY ... "\"");
	
	delete conf;
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

void ApplyPatch(bool patch)
{
	static bool patched = false;
	if (patch && !patched)
	{
		if (!g_hPatch.Enable())
			SetFailState("Failed to enable patch \"" ... PATCH_MYINFECTEDPOINTER ... "\"");
		
		patched = true;
	}
	else
	{
		g_hPatch.Disable();
		patched = false;
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 2)
		return;
		
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (ability != -1)
	{
		g_hDHook.HookEntity(Hook_Pre, ability, CVomit_UpdateAbility);
		g_hDHook.HookEntity(Hook_Post, ability, CVomit_UpdateAbility_Post);
	}
}

public MRESReturn CVomit_UpdateAbility(int pThis)
{
	if (GetEntProp(pThis, Prop_Send, "m_isSpraying"))
	{
		ApplyPatch(true);
	}
}

public MRESReturn CVomit_UpdateAbility_Post(int pThis)
{
	ApplyPatch(false);
}