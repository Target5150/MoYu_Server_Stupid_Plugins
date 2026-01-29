#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <dhooks>
#include <sdktools>
#include <@Forgetest/gamedatawrapper>

public Plugin myinfo = 
{
	name = "[L4D & 2] Transition Entity",
	author = "Forgetest",
	description = "Notify entity transition states.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

methodmap CUtlVector
{
	property Address m_pElements {
		public get() { return LoadFromAddress(view_as<Address>(this), NumberType_Int32); }
	}

	property int m_Size {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(12), NumberType_Int32); }
	}
}
CUtlVector g_SavedPropPhysics;		// (L4D2 only) CUtlVector<SavedEntity>
CUtlVector g_SavedWeapons;			// (L4D1) CUtlVector<SavedEntity> / (L4D2) CUtlVector<SavedEntity*>
CUtlVector g_SavedWeaponSpawns;		// (L4D1) CUtlVector<SavedEntity> / (L4D2) CUtlVector<SavedEntity*>

Handle g_call_KeyValues_GetString;
Handle g_call_KeyValues_SetString;

DynamicHook g_hook_PostSpawn;

GlobalForward g_fwdOnEntityTransitioning;
GlobalForward g_fwdOnEntityTransitioned;

bool g_bL4D2;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: { g_bL4D2 = false; }
		case Engine_Left4Dead2: { g_bL4D2 = true; }
		default:
		{
			strcopy(error, err_max, "Plugin supports L4D! & 2 only");
			return APLRes_SilentFailure;
		}
	}

	g_fwdOnEntityTransitioning = new GlobalForward("L4D_OnEntityTransitioning", ET_Ignore, Param_Cell);
	g_fwdOnEntityTransitioned = new GlobalForward("L4D_OnEntityTransitioned", ET_Ignore, Param_Cell, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_transition_entity");

	if (g_bL4D2)
	{
		g_SavedPropPhysics = view_as<CUtlVector>(gd.GetAddress("g_SavedPropPhysics"));
	}
	g_SavedWeapons = view_as<CUtlVector>(gd.GetAddress("g_SavedWeapons"));
	g_SavedWeaponSpawns = view_as<CUtlVector>(gd.GetAddress("g_SavedWeaponSpawns"));

	SDKCallParamsWrapper params[] = {
		{SDKType_String, SDKPass_Pointer},
		{SDKType_String, SDKPass_Pointer},
	};
	g_call_KeyValues_GetString = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Signature, "KeyValues::GetString", params, 2, true, params[0]);
	g_call_KeyValues_SetString = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Signature, "KeyValues::SetString", params, 2, false);

	g_hook_PostSpawn = gd.CreateDHookOrFail("l4d_transition_entity::SavedEntity::PostSpawn");

	delete gd.CreateDetourOrFail("l4d_transition_entity::InfoChangelevel::SaveEntities", DTR_SaveEntities, DTR_SaveEntities_Post);
	delete gd.CreateDetourOrFail("l4d_transition_entity::InfoChangelevel::IsEntitySaveable", _, DTR_IsEntitySaveable_Post);

	delete gd;
}

void OnSavingEntity(int entity, Address pKV)
{
	char buffer[16];
	IntToString(entity, buffer, sizeof(buffer));
	SDKCall(g_call_KeyValues_SetString, pKV, "l4d_transition_entity_oldindex", buffer);

#if DEBUG
	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	PrintToServer("OnSavingEntity (%d) [%s]", entity, classname);
#endif

	CallOnEntityTransitioning(entity);
}

void CallOnEntityTransitioning(int entity)
{
	if (g_fwdOnEntityTransitioning.FunctionCount == 0)
		return;
	
	Call_StartForward(g_fwdOnEntityTransitioning);
	Call_PushCell(entity);
	Call_Finish();
}

void PostSaveEntities()
{
	if (g_bL4D2)
	{
		for (int i = g_SavedPropPhysics.m_Size-1; i >= 0; --i)
		{
			Address pSavedEntity = g_SavedPropPhysics.m_pElements + view_as<Address>(8 * i);
			g_hook_PostSpawn.HookRaw(Hook_Post, pSavedEntity, Hook_SavedEntity_PostSpawnPost);
		}
		for (int i = g_SavedWeapons.m_Size-1; i >= 0; --i)
		{
			Address pSavedEntity = LoadFromAddress(g_SavedWeapons.m_pElements + view_as<Address>(4 * i), NumberType_Int32);
			g_hook_PostSpawn.HookRaw(Hook_Post, pSavedEntity, Hook_SavedEntity_PostSpawnPost);
		}
		for (int i = g_SavedWeaponSpawns.m_Size-1; i >= 0; --i)
		{
			Address pSavedEntity = LoadFromAddress(g_SavedWeaponSpawns.m_pElements + view_as<Address>(4 * i), NumberType_Int32);
			g_hook_PostSpawn.HookRaw(Hook_Post, pSavedEntity, Hook_SavedEntity_PostSpawnPost);
		}
	}
	else
	{
		for (int i = g_SavedWeapons.m_Size-1; i >= 0; --i)
		{
			Address pSavedEntity = g_SavedWeapons.m_pElements + view_as<Address>(8 * i);
			g_hook_PostSpawn.HookRaw(Hook_Post, pSavedEntity, Hook_SavedEntity_PostSpawnPost);
		}
		for (int i = g_SavedWeaponSpawns.m_Size-1; i >= 0; --i)
		{
			Address pSavedEntity = g_SavedWeaponSpawns.m_pElements + view_as<Address>(8 * i);
			g_hook_PostSpawn.HookRaw(Hook_Post, pSavedEntity, Hook_SavedEntity_PostSpawnPost);
		}
	}

#if DEBUG
	PrintToServer("PostSaveEntities (%d physics) (%d weapons) (%d weapon spawns)", g_bL4D2 ? g_SavedPropPhysics.m_Size : 0, g_SavedWeapons.m_Size, g_SavedWeaponSpawns.m_Size);
#endif
}

MRESReturn Hook_SavedEntity_PostSpawnPost(Address pThis, DHookParam hParams)
{
	if (hParams.IsNull(1))
		return MRES_Ignored;

	int entity = hParams.Get(1);
	if (!IsValidEntity(entity)) // just in case
		return MRES_Ignored;

	Address pKV = LoadFromAddress(pThis + view_as<Address>(4), NumberType_Int32);

	char buffer[16];
	SDKCall(g_call_KeyValues_GetString, pKV, buffer, sizeof(buffer), "l4d_transition_entity_oldindex", "-1");

	int oldindex = StringToInt(buffer);
	if (oldindex == -1)
	{
		char classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		LogError("Unhandled SavedEntity (%s)", classname);
		return MRES_Ignored;
	}

#if DEBUG
	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	PrintToServer("SavedEntity_PostSpawn (%d / %d) [%s]", entity, oldindex, classname);
#endif

	CallOnEntityTransitioned(entity, oldindex);
	return MRES_Ignored;
}

void CallOnEntityTransitioned(int entity, int oldindex)
{
	if (g_fwdOnEntityTransitioned.FunctionCount == 0)
		return;
	
	Call_StartForward(g_fwdOnEntityTransitioned);
	Call_PushCell(entity);
	Call_PushCell(oldindex);
	Call_Finish();
}

static int g_iCurrentEntity;
static int g_iLastPhysicProps;
static int g_iLastWeapons;
static int g_iLastWeaponSpawns;
MRESReturn DTR_SaveEntities(int entity, DHookParam hParams)
{
	g_iCurrentEntity = -1;
	g_iLastPhysicProps = 0;
	g_iLastWeapons = 0;
	g_iLastWeaponSpawns = 0;
	return MRES_Ignored;
}

void CheckLastSavedEntity(int entity)
{
	if (entity == -1)
		return;
	
	Address pSavedEntity = Address_Null;

	if (g_bL4D2)
	{
		if (g_SavedPropPhysics.m_Size - 1 == g_iLastPhysicProps)
			pSavedEntity = g_SavedPropPhysics.m_pElements + view_as<Address>(8 * (g_SavedPropPhysics.m_Size - 1));
		else if (g_SavedWeaponSpawns.m_Size - 1 == g_iLastWeaponSpawns)
			pSavedEntity = LoadFromAddress(g_SavedWeaponSpawns.m_pElements + view_as<Address>(4 * (g_SavedWeaponSpawns.m_Size - 1)), NumberType_Int32);
		else if (g_SavedWeapons.m_Size - 1 == g_iLastWeapons)
			pSavedEntity = LoadFromAddress(g_SavedWeapons.m_pElements + view_as<Address>(4 * (g_SavedWeapons.m_Size - 1)), NumberType_Int32);
	}
	else
	{
		if (g_SavedWeaponSpawns.m_Size - 1 == g_iLastWeaponSpawns)
			pSavedEntity = g_SavedWeaponSpawns.m_pElements + view_as<Address>(8 * (g_SavedWeaponSpawns.m_Size - 1));
		else if (g_SavedWeapons.m_Size - 1 == g_iLastWeapons)
			pSavedEntity = g_SavedWeapons.m_pElements + view_as<Address>(8 * (g_SavedWeapons.m_Size - 1));
	}
	
#if DEBUG
	if (g_bL4D2 && g_SavedPropPhysics.m_Size - 1 == g_iLastPhysicProps)
		PrintToServer("CheckLastSavedEntity (physic)");
	else if (g_SavedWeaponSpawns.m_Size - 1 == g_iLastWeaponSpawns)
		PrintToServer("CheckLastSavedEntity (weapon spawn)");
	else if (g_SavedWeapons.m_Size - 1 == g_iLastWeapons)
		PrintToServer("CheckLastSavedEntity (weapon)");
#endif

	if (g_bL4D2)
	{
		g_iLastPhysicProps = g_SavedPropPhysics.m_Size;
	}
	g_iLastWeaponSpawns = g_SavedWeaponSpawns.m_Size;
	g_iLastWeapons = g_SavedWeapons.m_Size;

	if (pSavedEntity == Address_Null)
		return;
	
	Address pKV = LoadFromAddress(pSavedEntity + view_as<Address>(4), NumberType_Int32);
	OnSavingEntity(entity, pKV);
}

MRESReturn DTR_IsEntitySaveable_Post(int entity, DHookReturn hReturn, DHookParam hParams)
{
	CheckLastSavedEntity(g_iCurrentEntity);
	g_iCurrentEntity = hReturn.Value == true ? hParams.Get(1) : -1;
	
	return MRES_Ignored;
}

MRESReturn DTR_SaveEntities_Post(int entity, DHookParam hParams)
{
	CheckLastSavedEntity(g_iCurrentEntity);
	PostSaveEntities();

	return MRES_Ignored;
}
