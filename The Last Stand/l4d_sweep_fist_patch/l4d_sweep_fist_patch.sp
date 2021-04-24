#include <sourcemod>
#include <sourcescramble>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = 
{
	name = "[L4D & 2] Coop Tank Sweep Fist Patch",
	author = "Forgetest (Big thanks to Crasher_3637)",
	description = "Kinda destroyed by AIs won't be suck anymore! well nah it is.",
	version = PLUGIN_VERSION,
	url = "verygood"
};

// =======================================
// Variables
// =======================================

#define GAMEDATA_FILE "l4d_sweep_fist_patch"

#define KEY_SWEEPFIST "CTankClaw::SweepFist"
#define KEY_SWEEPFIST_CHECK1 "CTankClaw::SweepFist::Check1"
#define KEY_SWEEPFIST_CHECK2 "CTankClaw::SweepFist::Check2"

MemoryPatch g_hPatcher_Check1;
MemoryPatch g_hPatcher_Check2;

Handle g_hDetour;

bool g_bLeft4Dead2;

// =======================================
// Engine Detect
// =======================================

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead:
		{
			g_bLeft4Dead2 = false;
			return APLRes_Success;
		}
		case Engine_Left4Dead2:
		{
			g_bLeft4Dead2 = true;
			return APLRes_Success;
		}
	}
	
	strcopy(error, err_max, "Plugin supports only Left 4 Dead & 2.");
	return APLRes_SilentFailure;
}

// =======================================
// Plugin Setup
// =======================================

public void OnPluginStart()
{
	GameData hGameData = new GameData(GAMEDATA_FILE);
	if (hGameData == null)
		SetFailState("Missing gamedata file (" ... GAMEDATA_FILE ... ")");
	
	g_hPatcher_Check1 = MemoryPatch.CreateFromConf(hGameData, KEY_SWEEPFIST_CHECK1);
	g_hPatcher_Check2 = MemoryPatch.CreateFromConf(hGameData, KEY_SWEEPFIST_CHECK2);
	
	if (g_hPatcher_Check1 == null || g_hPatcher_Check2 == null)
		SetFailState("Missing \"MemPatches\" key in gamedata file.");
	
	if (!g_hPatcher_Check1.Validate() || !g_hPatcher_Check2.Validate())
		SetFailState("Failed to validate memory patches");
		
	SetupDetour(hGameData);
	
	delete hGameData;
}

// =======================================
// Detour Setup
// =======================================

void SetupDetour(GameData &hGameData)
{
	g_hDetour = DHookCreateFromConf(hGameData, KEY_SWEEPFIST);
	if (g_hDetour == null)
		SetFailState("Missing detour settings for or signature of \"" ... KEY_SWEEPFIST ... "\"");
}

// =======================================
// Forwards
// =======================================

public void OnPluginEnd()
{
	PatchSweepFist(false);
	ToggleDetour(false);
}

public void OnConfigsExecuted()
{
	bool bIsAllowedMode = IsAllowedGamemode();
	PatchSweepFist(bIsAllowedMode);
	ToggleDetour(bIsAllowedMode);
}

// =======================================
// Toggle methods
// =======================================

void PatchSweepFist(bool patch)
{
	static bool patched = false;
	if (patched && !patch)
	{
		g_hPatcher_Check1.Disable();
		g_hPatcher_Check2.Disable();
		patched = false;
	}
	else if (!patched && patch)
	{
		if (g_hPatcher_Check1.Enable() && g_hPatcher_Check2.Enable())
		{
			PrintToServer("[SweepFist] Successfully patched 2 checks in \"" ... KEY_SWEEPFIST ... "\"");
			patched = true;
		}
		else
		{
			SetFailState("Failed in patching checks for \"" ... KEY_SWEEPFIST ... "\"");
		}
	}
}

void ToggleDetour(bool enable)
{
	static bool detoured = false;
	if (detoured && !enable)
	{
		if (!DHookDisableDetour(g_hDetour, false, OnSweepFistPre) || !DHookDisableDetour(g_hDetour, true, OnSweepFistPost))
			SetFailState("Failed to disable detour for \"" ... KEY_SWEEPFIST ... "\"");
		
		detoured = false;
	}
	else if (!detoured && enable)
	{
		if (!DHookEnableDetour(g_hDetour, false, OnSweepFistPre) || !DHookEnableDetour(g_hDetour, true, OnSweepFistPost))
			SetFailState("Failed to enable detour for \"" ... KEY_SWEEPFIST ... "\"");
			
		detoured = true;
	}
}

// =======================================
// IsAllowedGamemode() credie to Silvers
// =======================================

int g_iGamemode;
bool IsAllowedGamemode()
{
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
	
	return g_iGamemode == 1; // Coop or Realism
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )				g_iGamemode = 1;
	else if( strcmp(output, "OnVersus") == 0 )		g_iGamemode = 2;
	else if( strcmp(output, "OnSurvival") == 0 )	g_iGamemode = 3;
	else if( strcmp(output, "OnScavenge") == 0 )	g_iGamemode = 4;
}

// =======================================
// Detour CBs
// =======================================

public MRESReturn OnSweepFistPre(int pThis, Handle hParams)
{
	if (!IsValidEntity(pThis)) return;
	
	int tank = GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
	if (IsTank(tank))
		PatchSweepFist(true);
}

public MRESReturn OnSweepFistPost(int pThis, Handle hParams)
{
	if (IsValidEntity(pThis))
		PatchSweepFist(false);
}

#define IS_VALID_CLIENT_INGAME(%0) ((%0) <= MaxClients && (%0) > 0 && IsClientInGame(%0))
stock bool IsTank(int client) {
	return IS_VALID_CLIENT_INGAME(client)
		&& GetClientTeam(client) == 3
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == (g_bLeft4Dead2 ? 8 : 5);
}