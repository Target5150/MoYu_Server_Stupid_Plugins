#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0
#define PLUGIN_VERSION "2.0"

#include <sourcemod>
#include <dhooks>
#include <sdktools>
#include <sourcescramble>
#include <@Forgetest/gamedatawrapper>

public Plugin myinfo = 
{
	name = "[L4D & 2] Transition Entity",
	author = "Forgetest",
	description = "Notify entity transition states.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

#define	MAX_EDICT_BITS 11
#define	MAX_EDICT_MASK ((1 << MAX_EDICT_BITS) - 1)

methodmap Address {}

Handle g_call_KeyValues_GetInt;
Handle g_call_KeyValues_SetInt;
Handle g_call_KeyValues_FindKey;
Handle g_call_KeyValues_GetName;
int g_offs_KeyValues_m_pPeer;
methodmap KeyValuesPtr < Address
{
	public int GetInt(const char[] key, int defValue = 0) {
		return SDKCall(g_call_KeyValues_GetInt, this, key, defValue);
	}
	public void SetInt(const char[] key, int value) {
		SDKCall(g_call_KeyValues_SetInt, this, key, value);
	}
	public KeyValuesPtr GetFirstSubKey() {
		return LoadFromAddress(this + view_as<Address>(g_offs_KeyValues_m_pPeer + 4), NumberType_Int32);
	}
	public KeyValuesPtr GetNextKey() {
		return LoadFromAddress(this + view_as<Address>(g_offs_KeyValues_m_pPeer), NumberType_Int32);
	}
	public KeyValuesPtr FindKey(const char[] key, bool bCreate = false) {
		return SDKCall(g_call_KeyValues_FindKey, this, key, bCreate);
	}
	public void GetName(char[] buffer, int maxlength) {
		SDKCall(g_call_KeyValues_GetName, this, buffer, maxlength);
	}
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

DynamicHook g_hook_PostSpawn;

GlobalForward g_fwdOnEntityTransitioning;
GlobalForward g_fwdOnEntityTransitioned;
GlobalForward g_fwdOnPlayerTransitioning;
GlobalForward g_fwdOnPlayerTransitioned;
GlobalForward g_fwdOnPlayerItemTransitioning;
GlobalForward g_fwdOnPlayerItemTransitioned;

bool g_bL4D2;
ArrayList g_HookIDs;

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
	g_fwdOnPlayerTransitioning = new GlobalForward("L4D_OnPlayerTransitioning", ET_Ignore, Param_Cell);
	g_fwdOnPlayerTransitioned = new GlobalForward("L4D_OnPlayerTransitioned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnPlayerItemTransitioning = new GlobalForward("L4D_OnPlayerItemTransitioning", ET_Ignore, Param_Cell, Param_Cell);
	g_fwdOnPlayerItemTransitioned = new GlobalForward("L4D_OnPlayerItemTransitioned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

	RegPluginLibrary("l4d_transition_entity");

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
		{SDKType_PlainOldData, SDKPass_Plain},
	};
	g_call_KeyValues_GetInt = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Signature, "KeyValues::GetInt", params, 2, true, params[1]);
	g_call_KeyValues_SetInt = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Signature, "KeyValues::SetInt", params, 2, false);

	g_hook_PostSpawn = gd.CreateDHookOrFail("l4d_transition_entity::SavedEntity::PostSpawn");

	delete gd.CreateDetourOrFail("l4d_transition_entity::InfoChangelevel::SaveEntities", DTR_SaveEntities, DTR_SaveEntities_Post);
	delete gd.CreateDetourOrFail("l4d_transition_entity::InfoChangelevel::IsEntitySaveable", _, DTR_IsEntitySaveable_Post);
	delete gd.CreateDetourOrFail("l4d_transition_entity::PlayerSaveData::PlayerSaveData", _, DTR_PlayerSaveData_Post);
	delete gd.CreateDetourOrFail("l4d_transition_entity::PlayerSaveData::Restore", DTR_PlayerSaveData_Restore, DTR_PlayerSaveData_Restore_Post);
	delete gd.CreateDetourOrFail("l4d_transition_entity::CTerrorPlayer::GiveNamedItem", DTR_GiveNamedItem, DTR_GiveNamedItem_Post);

	if (g_bL4D2)
	{
		g_offs_KeyValues_m_pPeer = gd.GetOffset("KeyValues::m_pPeer");
		g_call_KeyValues_GetName = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Signature, "KeyValues::GetName", _, 0, true, params[0]);
		gd.CreatePatchOrFail("restore_last_secondary_hack", true);
	}
	else
	{
		g_call_KeyValues_FindKey = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Signature, "KeyValues::FindKey", params, 2, true, params[1]);
	}

	delete gd;

	g_HookIDs = new ArrayList();
}

void OnSavingEntity(int entity, KeyValuesPtr pKV)
{
	pKV.SetInt("l4d_transition_entity_oldindex", entity);

#if DEBUG
	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	PrintToServer("OnSavingEntity (%d) [%s]", entity, classname);
#endif

	CallOnEntityTransitioning(entity);
}

void HookSavedEntities(CUtlVector vec, bool isPtr)
{
	for (int i = vec.m_Size-1; i >= 0; --i)
	{
		Address pSavedEntity = isPtr ?
						LoadFromAddress(vec.m_pElements + view_as<Address>(4 * i), NumberType_Int32) :
						(vec.m_pElements + view_as<Address>(8 * i));

		int hookid = g_hook_PostSpawn.HookRaw(Hook_Post, pSavedEntity, Hook_SavedEntity_PostSpawnPost);
		if (hookid == INVALID_HOOK_ID)
		{
			LogError("Failed to hook SavedEntity_PostSpawn");
			continue;
		}
		g_HookIDs.Push(hookid);
	}
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
		HookSavedEntities(g_SavedPropPhysics, false);
		HookSavedEntities(g_SavedWeapons, true);
		HookSavedEntities(g_SavedWeaponSpawns, true);
	#if DEBUG
		PrintToServer("PostSaveEntities (%d physics) (%d weapons) (%d spawners)", g_SavedPropPhysics.m_Size, g_SavedWeapons.m_Size, g_SavedWeaponSpawns.m_Size);
	#endif
	}
	else
	{
		HookSavedEntities(g_SavedWeapons, false);
		HookSavedEntities(g_SavedWeaponSpawns, false);
	#if DEBUG
		PrintToServer("PostSaveEntities (%d weapons) (%d spawners)", g_SavedWeapons.m_Size, g_SavedWeaponSpawns.m_Size);
	#endif
	}
}

MRESReturn Hook_SavedEntity_PostSpawnPost(Address pThis, DHookParam hParams)
{
	KeyValuesPtr pKV = LoadFromAddress(pThis + view_as<Address>(4), NumberType_Int32);
	int oldindex = pKV.GetInt("l4d_transition_entity_oldindex", -1);

	int entity = -1;
	if (!hParams.IsNull(1))
		entity = hParams.Get(1);

	if (!IsValidEntity(entity))
	{
	#if DEBUG
		PrintToServer("SavedEntity_PostSpawn !! failed to spawn entity (%d)", oldindex);
	#endif
		return MRES_Ignored;
	}

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

void ClearHookIDs()
{
	for (int i = g_HookIDs.Length-1; i >= 0; --i)
	{
		DynamicHook.RemoveHook(g_HookIDs.Get(i));
	}

	g_HookIDs.Clear();
}

static int g_iLastEntity;
static int g_iLastPhysicProps;
static int g_iLastWeapons;
static int g_iLastWeaponSpawns;
MRESReturn DTR_SaveEntities(int entity, DHookParam hParams)
{
	g_iLastEntity = -1;
	g_iLastPhysicProps = 0;
	g_iLastWeapons = 0;
	g_iLastWeaponSpawns = 0;
	ClearHookIDs();
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
		PrintToServer("CheckLastSavedEntity (physic) (%d now)", g_SavedPropPhysics.m_Size);
	else if (g_SavedWeaponSpawns.m_Size - 1 == g_iLastWeaponSpawns)
		PrintToServer("CheckLastSavedEntity (spawner) (%d now)", g_SavedWeaponSpawns.m_Size);
	else if (g_SavedWeapons.m_Size - 1 == g_iLastWeapons)
		PrintToServer("CheckLastSavedEntity (weapon) (%d now)", g_SavedWeapons.m_Size);
#endif

	if (g_bL4D2)
	{
		g_iLastPhysicProps = g_SavedPropPhysics.m_Size;
	}
	g_iLastWeaponSpawns = g_SavedWeaponSpawns.m_Size;
	g_iLastWeapons = g_SavedWeapons.m_Size;

	if (pSavedEntity == Address_Null)
		return;
	
	KeyValuesPtr pKV = LoadFromAddress(pSavedEntity + view_as<Address>(4), NumberType_Int32);
	OnSavingEntity(entity, pKV);
}

MRESReturn DTR_IsEntitySaveable_Post(int entity, DHookReturn hReturn, DHookParam hParams)
{
	CheckLastSavedEntity(g_iLastEntity);
	g_iLastEntity = hReturn.Value == true ? hParams.Get(1) : -1;
	
	return MRES_Ignored;
}

MRESReturn DTR_SaveEntities_Post(int entity, DHookParam hParams)
{
	CheckLastSavedEntity(g_iLastEntity);
	PostSaveEntities();

	return MRES_Ignored;
}

void OnSavingPlayerItem(int client, int weapon)
{
#if DEBUG
	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));
	PrintToServer("OnSavingPlayerItem (%N [#%d]) (%s [#%d])", client, client, classname, weapon);
#endif

	CallOnPlayerItemTransitioning(client, weapon);
}

MRESReturn DTR_PlayerSaveData_Post(Address pThis, DHookParam hParams)
{
	if (hParams.IsNull(1))
		return MRES_Ignored;

	KeyValuesPtr pKV = LoadFromAddress(pThis, NumberType_Int32);
	if (pKV == Address_Null)
		return MRES_Ignored;

	int client = hParams.Get(1);
	pKV.SetInt("l4d_transition_entity_oldindex", client);

	#if DEBUG
	{
		PrintToServer("PlayerSaveData (#%d / userid #%d) [%N]", client, GetClientUserId(client), client);
	}
	#endif

	CallOnPlayerTransitioning(client);
	
	if (g_bL4D2)
	{
		char keyname[64];
		for (KeyValuesPtr pSub = pKV.GetFirstSubKey(); pSub != Address_Null; pSub = pSub.GetNextKey())
		{
			pSub.GetName(keyname, sizeof(keyname));
			if (!strcmp(keyname, "weapon", false))
			{
				int weaponid = pSub.GetInt("weaponID", 0);
				if (weaponid <= 0)
					continue;
				
				int weapon = GetPlayerWeaponFromID(client, weaponid);
				if (weapon == -1)
					continue;
				
				int reloaded = pSub.GetInt("reloaded", 0);
				reloaded |= (weapon << 8);
				pSub.SetInt("reloaded", reloaded);

				OnSavingPlayerItem(client, weapon);
			}
		}

		int lastSecondary = L4D2_GetPlayerLastSecondaryWeapon(client);
		if (lastSecondary != -1)
		{
			#if DEBUG
			{
				char classname[64];
				GetEntityClassname(lastSecondary, classname, sizeof(classname));
				PrintToServer("PlayerSaveData - last secondary (%s [#%d])", classname, lastSecondary);
			}
			#endif
			
			pKV.SetInt("l4d_transition_entity_oldsecondary", lastSecondary);
			OnSavingPlayerItem(client, lastSecondary);
		}
	}
	else
	{
		// Ordered by weaponid
		static const char WeaponAlias[][] = {
			"none", "pistol", "smg", "pumpshotgun", "autoshotgun", "rifle", "hunting_rifle", "machinegun", 
			"first_aid_kit", "molotov", "pipe_bomb", "flare", "pain_pills", 
			"law_rocket", "gascan", "propanetank", "oxygentank", 
			// "tank_claw", "hunter_claw", "boomer_claw", 
			// "smoker_claw", "vomit", "splat", "pounce", 
			// "lounge", "pull", "choke", "rock", "physics", "ammo"
		};

		for (int weaponid = 1; weaponid < sizeof(WeaponAlias); ++weaponid)
		{
			KeyValuesPtr pSub = pKV.FindKey(WeaponAlias[weaponid], false);
			if (pSub == Address_Null)
				continue;
			
			int weapon = GetPlayerWeaponFromID(client, weaponid);
			if (weapon == -1)
				continue;
			
			int reloaded = pSub.GetInt("reloaded", 0);
			reloaded |= (weapon << 8);
			pSub.SetInt("reloaded", reloaded);

			OnSavingPlayerItem(client, weapon);
		}
	}

	return MRES_Ignored;
}

static bool g_bRestorePlayerData = false;
static int g_iPlayerItemOldIndex = -1;
static int g_iPlayerLastSecondaryOldIndex = -1;
static ArrayList g_RestoredPlayerItem = null;
MRESReturn DTR_PlayerSaveData_Restore(Address pThis, DHookParam hParams)
{
	KeyValuesPtr pKV = LoadFromAddress(pThis, NumberType_Int32);
	if (pKV == Address_Null)
		return MRES_Ignored;

	g_bRestorePlayerData = true;
	g_iPlayerItemOldIndex = -1;
	g_iPlayerLastSecondaryOldIndex = pKV.GetInt("l4d_transition_entity_oldsecondary", -1);

	if (g_RestoredPlayerItem == null)
		g_RestoredPlayerItem = new ArrayList(2);
	else
		g_RestoredPlayerItem.Clear();

	return MRES_Ignored;
}

MRESReturn DTR_GiveNamedItem(int client, DHookReturn hReturn, DHookParam hParams)
{
	if (!g_bRestorePlayerData)
		return MRES_Ignored;

	int reloaded = hParams.Get(2);
	int oldindex = (reloaded >> 8) & MAX_EDICT_MASK;
	reloaded = reloaded & 0xFF;

	if (oldindex == 0)
	{
		if (g_bL4D2 && reloaded == 42) // See "restore_last_secondary_hack"
			g_iPlayerItemOldIndex = g_iPlayerLastSecondaryOldIndex;
		else
			g_iPlayerItemOldIndex = -1;

		return MRES_Ignored;
	}
	else
	{
		g_iPlayerItemOldIndex = oldindex;
	}

	hParams.Set(2, reloaded);
	return MRES_ChangedHandled;
}

MRESReturn DTR_GiveNamedItem_Post(int client, DHookReturn hReturn, DHookParam hParams)
{
	if (!g_bRestorePlayerData)
		return MRES_Ignored;
	
	int weapon = hReturn.Value;
	if (weapon == -1)
		return MRES_Ignored;
	
	#if DEBUG
	{
		char classname[64];
		GetEntityClassname(weapon, classname, sizeof(classname));
		PrintToServer("GiveNamedItem_Post (%s) [oldindex #%d]", classname, g_iPlayerItemOldIndex);
	}
	#endif

	if (g_iPlayerItemOldIndex != -1)
	{
		int set[2];
		set[0] = EntIndexToEntRef(weapon);
		set[1] = g_iPlayerItemOldIndex;
		g_RestoredPlayerItem.PushArray(set);
	}

	return MRES_Ignored;
}

MRESReturn DTR_PlayerSaveData_Restore_Post(Address pThis, DHookParam hParams)
{
	g_bRestorePlayerData = false;

	if (hParams.IsNull(1))
		return MRES_Ignored;

	KeyValuesPtr pKV = LoadFromAddress(pThis, NumberType_Int32);
	if (pKV == Address_Null)
		return MRES_Ignored;

	int client = hParams.Get(1);
	int oldindex = pKV.GetInt("l4d_transition_entity_oldindex", -1);
	int olduserid = pKV.GetInt("userID", 0);

	if (oldindex == -1)
	{
		LogError("Unhandled PlayerSaveData_Restore (olduserid #%d) [%N]", olduserid, client);
		return MRES_Ignored;
	}

#if DEBUG
	PrintToServer("PlayerSaveData_Restore (oldindex #%d / olduserid #%d) [%N]", oldindex, olduserid, client);
#endif

	CallOnPlayerTransitioned(client, oldindex, olduserid);

	for (int i = g_RestoredPlayerItem.Length-1; i >= 0; --i)
	{
		int set[2];
		g_RestoredPlayerItem.GetArray(i, set);

		if (IsValidEdict(set[0]))
		{
			CallOnPlayerItemTransitioned(client, EntRefToEntIndex(set[0]), set[1]);
		}
	}

	return MRES_Ignored;
}

void CallOnPlayerTransitioning(int client)
{
	if (g_fwdOnPlayerTransitioning.FunctionCount == 0)
		return;
	
	Call_StartForward(g_fwdOnPlayerTransitioning);
	Call_PushCell(client);
	Call_Finish();
}

void CallOnPlayerTransitioned(int client, int oldindex, int olduserid)
{
	if (g_fwdOnPlayerTransitioned.FunctionCount == 0)
		return;
	
	Call_StartForward(g_fwdOnPlayerTransitioned);
	Call_PushCell(client);
	Call_PushCell(oldindex);
	Call_PushCell(olduserid);
	Call_Finish();
}

void CallOnPlayerItemTransitioning(int client, int weapon)
{
	if (g_fwdOnPlayerItemTransitioning.FunctionCount == 0)
		return;
	
	Call_StartForward(g_fwdOnPlayerItemTransitioning);
	Call_PushCell(client);
	Call_PushCell(weapon);
	Call_Finish();
}

void CallOnPlayerItemTransitioned(int client, int weapon, int oldindex)
{
	if (g_fwdOnPlayerItemTransitioned.FunctionCount == 0)
		return;
	
	Call_StartForward(g_fwdOnPlayerItemTransitioned);
	Call_PushCell(client);
	Call_PushCell(weapon);
	Call_PushCell(oldindex);
	Call_Finish();
}

int GetPlayerWeaponFromID(int client, int weaponid)
{
	static int offs_m_weaponIDToIndex = -1;
	if (offs_m_weaponIDToIndex == -1)
		offs_m_weaponIDToIndex = FindSendPropInfo("CBaseCombatCharacter", "m_flNextAttack") + 36;
	
	int index = GetEntData(client, offs_m_weaponIDToIndex + weaponid, 1);
	if (index == 0)
		return -1;
	
	return GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", index-1);
}

int L4D2_GetPlayerLastSecondaryWeapon(int client)
{
	static int offs_m_hLastSecondaryWeapon = -1;
	if (offs_m_hLastSecondaryWeapon == -1)
		offs_m_hLastSecondaryWeapon = FindSendPropInfo("CTerrorPlayer", "m_iVersusTeam") - 20;

	return GetEntDataEnt2(client, offs_m_hLastSecondaryWeapon);
}
