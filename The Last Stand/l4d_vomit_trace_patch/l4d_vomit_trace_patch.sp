#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define PLUGIN_VERSION "2.4.1"

public Plugin myinfo =
{
	name = "[L4D] Vomit Trace Patch",
	author = "Forgetest",
	description = "Fix vomit stuck on Infected teammates.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d_vomit_trace_patch"
#define OP_CALL_SIZE 5

MemoryPatch g_hPatch;
DynamicHook g_hDHook;
int g_iPatchOffs, g_iFuncOffs;

DynamicHook g_hDHook_PhysicsSolidMaskForEntity;

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_Left4Dead)
		SetFailState("Plugin supports L4D only");
	
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	g_hPatch = MemoryPatch.CreateFromConf(conf, "ShouldHitEntity_MyInfectedPointer");
	if (!g_hPatch.Validate())
		SetFailState("Failed to validate patch \"ShouldHitEntity_MyInfectedPointer\"");
	
	g_hDHook = DynamicHook.FromConf(conf, "CBaseAbility::UpdateAbility");
	if (g_hDHook == null)
		SetFailState("Failed to create dynamic hook on \"CBaseAbility::UpdateAbility\"");
	
	g_hDHook_PhysicsSolidMaskForEntity = DynamicHook.FromConf(conf, "CBaseEntity::PhysicsSolidMaskForEntity");
	if (g_hDHook_PhysicsSolidMaskForEntity == null)
		SetFailState("Failed to create dynamic hook on \"CBaseEntity::PhysicsSolidMaskForEntity\"");
	
	Address pGetTeamNumberFuncAddr = GameConfGetAddress(conf, "CBaseEntity_GetTeamNumber");
	if (pGetTeamNumberFuncAddr == Address_Null)
		SetFailState("Missing address/signature \"CBaseEntity_GetTeamNumber\"");
	
	g_iPatchOffs = GameConfGetOffset(conf, "PatchOffset");
	if (g_iPatchOffs == -1)
		SetFailState("Missing offset \"PatchOffset\"");
	
	g_iFuncOffs =
		view_as<int>(pGetTeamNumberFuncAddr) - (view_as<int>(g_hPatch.Address) + (g_iPatchOffs - 1) + OP_CALL_SIZE);
	
	if (!MemoryPatch.CreateFromConf(conf, "OnVomitCollide__TraceRayMask_patch").Enable())
		SetFailState("Failed to patch \"OnVomitCollide__TraceRayMask_patch\"");
	
	if (!MemoryPatch.CreateFromConf(conf, "OnVomitCollide__ClipRayMask_patch").Enable())
		SetFailState("Failed to patch \"OnVomitCollide__ClipRayMask_patch\"");
	
	delete conf;
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

void ApplyPatch(bool patch)
{
	static bool patched = false;
	if (patch && !patched)
	{
		if (!g_hPatch.Enable())
			SetFailState("Failed to enable patch \"ShouldHitEntity_MyInfectedPointer\"");
		
		StoreToAddress(g_hPatch.Address + view_as<Address>(g_iPatchOffs), g_iFuncOffs, NumberType_Int32);
		patched = true;
	}
	else if (!patch && patched)
	{
		g_hPatch.Disable();
		patched = false;
	}
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 2)
		return;
		
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (ability != -1)
	{
		g_hDHook.HookEntity(Hook_Pre, ability, CVomit_UpdateAbility);
		g_hDHook.HookEntity(Hook_Post, ability, CVomit_UpdateAbility_Post);
		
		g_hDHook_PhysicsSolidMaskForEntity.HookEntity(Hook_Pre, ability, CVomit_PhysicsSolidMaskForEntity);
	}
}

MRESReturn CVomit_UpdateAbility(int pThis)
{
	if (GetEntProp(pThis, Prop_Send, "m_isSpraying"))
	{
		ApplyPatch(true);
	}
	
	return MRES_Ignored;
}

MRESReturn CVomit_UpdateAbility_Post(int pThis)
{
	ApplyPatch(false);
	
	return MRES_Ignored;
}

MRESReturn CVomit_PhysicsSolidMaskForEntity(DHookReturn hReturn)
{
	hReturn.Value = 0x2004003;
	return MRES_Supercede;
}