#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = 
{
	name = "[L4D & 2] Unrestrict Panic Battlefield",
	author = "Forgetest",
	description = "Remove zombie spawning restrictions during panic events.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

// Enabling this makes "SPAWN_SPECIALS_ANYWHERE" is preferred over "SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS" during a panic.
MemoryPatch g_patch_GetRandomPZSpawnPosition;
bool g_bGetRandomPZSpawnPosition;

// Enabling this makes "SurvivorActiveSet" being used instead of only "BATTLEFIELD" areas when collecting spawn areas.
MemoryPatch g_patch_CollectSpawnAreas;
bool g_bCollectSpawnAreas;

// (L4D1) Enabling this prevents Common Infected from spawning on cleared areas.
// NOTE: In L4D2 provided a script value "ShouldIgnoreClearStateForSpawn"
MemoryPatch g_patch_AccumulateSpawnAreaCollection;
MemoryPatch g_patch_AccumulateSpawnAreaCollection_inlined[4];
bool g_bAccumulateSpawnAreaCollection;

// Enabling this allows specials to spawn on battlefield areas before/after a panic starts/ends.
MemoryPatch g_patch_BattlefieldSpecialSpawn;
bool g_bSpecialBattlefieldSpawn;

// Enabling this allows mobs to spawn when all survivors are in battlefield areas.
MemoryPatch g_patch_BattlefieldMobSpawn;
bool g_bMobBattlefieldSpawn;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_unrestrict_panic_battlefield");

	g_patch_GetRandomPZSpawnPosition = gd.CreatePatchOrFail("ZombieManager::GetRandomPZSpawnPosition__skip_PanicEventActive", false);
	g_patch_CollectSpawnAreas = gd.CreatePatchOrFail("ZombieManager::CollectSpawnAreas__skip_PanicEventActive", false);
	g_patch_BattlefieldSpecialSpawn = gd.CreatePatchOrFail("battlefield_special_spawn", false);
	g_patch_BattlefieldMobSpawn = gd.CreatePatchOrFail("battlefield_mob_spawn", false);
	g_patch_AccumulateSpawnAreaCollection = gd.CreatePatchOrFail("ZombieManager::AccumulateSpawnAreaCollection__skip_PanicEventActive", false);

	if (GetEngineVersion() == Engine_Left4Dead)
	{
		g_patch_AccumulateSpawnAreaCollection_inlined[0] = gd.CreatePatchOrFail("ZombieManager::AccumulateSpawnAreaCollection__skip_PanicEventActive_inlined_1", false);
		g_patch_AccumulateSpawnAreaCollection_inlined[1] = gd.CreatePatchOrFail("ZombieManager::AccumulateSpawnAreaCollection__skip_PanicEventActive_inlined_2", false);
		g_patch_AccumulateSpawnAreaCollection_inlined[2] = gd.CreatePatchOrFail("ZombieManager::AccumulateSpawnAreaCollection__skip_PanicEventActive_inlined_3", false);
		g_patch_AccumulateSpawnAreaCollection_inlined[3] = gd.CreatePatchOrFail("ZombieManager::AccumulateSpawnAreaCollection__skip_PanicEventActive_inlined_4", false);
	}

	delete gd;

	CreateConVarHook(
		"special_battlefield_spawn",
		"1",
		"Special should spawn in battlefield areas while panic event isn't active.",
		FCVAR_NONE,
		true, 0.0, true, 1.0,
		CvarChg_BattlefieldSpecialSpawn);
	CreateConVarHook(
		"z_mob_battlefield_spawn",
		"1",
		"Natural mob should spawn when all survivors are in battlefield areas.",
		FCVAR_NONE,
		true, 0.0, true, 1.0,
		CvarChg_BattlefieldMobSpawn);
	CreateConVarHook(
		"special_panic_spawn_anywhere",
		"1",
		"Special should spawn anywhere instead of only in front during a panic.",
		FCVAR_NONE,
		true, 0.0, true, 1.0,
		CvarChg_SpawnAnywhere);
	CreateConVarHook(
		"z_panic_outside_battlefield",
		"1",
		"Zombies can spawn on non-battlefield areas during a panic.",
		FCVAR_NONE,
		true, 0.0, true, 1.0,
		CvarChg_OutsideBattlefield);
	CreateConVarHook(
		"z_panic_ignore_clear_state",
		"1",
		"Zombies can spawn on cleared areas during a panic.",
		FCVAR_NONE,
		true, 0.0, true, 1.0,
		CvarChg_IgnoreClearState);
}

void CvarChg_BattlefieldSpecialSpawn(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bSpecialBattlefieldSpawn != convar.BoolValue)
	{
		g_bSpecialBattlefieldSpawn = convar.BoolValue;

		if (g_bSpecialBattlefieldSpawn)
			g_patch_BattlefieldSpecialSpawn.Enable();
		else
			g_patch_BattlefieldSpecialSpawn.Disable();
	}
}

void CvarChg_BattlefieldMobSpawn(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bMobBattlefieldSpawn != convar.BoolValue)
	{
		g_bMobBattlefieldSpawn = convar.BoolValue;

		if (g_bMobBattlefieldSpawn)
			g_patch_BattlefieldMobSpawn.Enable();
		else
			g_patch_BattlefieldMobSpawn.Disable();
	}
}

void CvarChg_SpawnAnywhere(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bGetRandomPZSpawnPosition != convar.BoolValue)
	{
		g_bGetRandomPZSpawnPosition = convar.BoolValue;

		if (g_bGetRandomPZSpawnPosition)
			g_patch_GetRandomPZSpawnPosition.Enable();
		else
			g_patch_GetRandomPZSpawnPosition.Disable();
	}
}

void CvarChg_OutsideBattlefield(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bCollectSpawnAreas != convar.BoolValue)
	{
		g_bCollectSpawnAreas = convar.BoolValue;

		if (g_bCollectSpawnAreas)
			g_patch_CollectSpawnAreas.Enable();
		else
			g_patch_CollectSpawnAreas.Disable();
	}
}

void CvarChg_IgnoreClearState(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bAccumulateSpawnAreaCollection != convar.BoolValue)
	{
		g_bAccumulateSpawnAreaCollection = convar.BoolValue;

		if (g_bAccumulateSpawnAreaCollection)
			g_patch_AccumulateSpawnAreaCollection.Enable();
		else
			g_patch_AccumulateSpawnAreaCollection.Disable();

		if (g_patch_AccumulateSpawnAreaCollection_inlined[0] != null)
		{
			for (int i = 0; i < sizeof(g_patch_AccumulateSpawnAreaCollection_inlined); ++i)
			{
				if (g_bAccumulateSpawnAreaCollection)
					g_patch_AccumulateSpawnAreaCollection_inlined[i].Enable();
				else
					g_patch_AccumulateSpawnAreaCollection_inlined[i].Disable();
			}
		}
	}
}

stock ConVar CreateConVarHook(const char[] name,
	const char[] defaultValue,
	const char[] description="",
	int flags=0,
	bool hasMin=false, float min=0.0,
	bool hasMax=false, float max=0.0,
	ConVarChanged callback)
{
	ConVar cv = CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
	
	Call_StartFunction(INVALID_HANDLE, callback);
	Call_PushCell(cv);
	Call_PushNullString();
	Call_PushNullString();
	Call_Finish();
	
	cv.AddChangeHook(callback);
	
	return cv;
}
