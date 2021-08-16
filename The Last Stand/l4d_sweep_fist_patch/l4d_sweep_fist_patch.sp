#include <sourcemod>
#include <sourcescramble>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Coop Tank Sweep Fist Patch",
	author = "Forgetest (Big thanks to Crasher_3637), Dragokas",
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
#define KEY_GROUNDPOUND "CTankClaw::GroundPound"
#define KEY_GROUNDPOUND_CHECK "CTankClaw::GroundPound::Check"

MemoryPatch g_hPatcher_Check1;
MemoryPatch g_hPatcher_Check2;
MemoryPatch g_hPatcher_GroundPound;

Handle g_hDetour;
//Handle g_hDetour_GroundPound;

bool g_bLeft4Dead2, g_bLinux;

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
// Plugin OnOff
// =======================================

public void OnPluginStart()
{
	GameData hGameData = new GameData(GAMEDATA_FILE);
	if (hGameData == null)
		SetFailState("Missing gamedata file (" ... GAMEDATA_FILE ... ")");
	
	g_bLinux = (hGameData.GetOffset("OS") == 2);
	
	g_hPatcher_Check1 = MemoryPatch.CreateFromConf(hGameData, KEY_SWEEPFIST_CHECK1);
	g_hPatcher_Check2 = MemoryPatch.CreateFromConf(hGameData, KEY_SWEEPFIST_CHECK2);
	g_hPatcher_GroundPound = MemoryPatch.CreateFromConf(hGameData, KEY_GROUNDPOUND_CHECK);
	
	if (g_hPatcher_Check1 == null || g_hPatcher_Check2 == null || g_hPatcher_GroundPound == null)
		SetFailState("Missing \"MemPatches\" key in gamedata file.");
	
	if (!g_hPatcher_Check1.Validate() || !g_hPatcher_Check2.Validate() || !g_hPatcher_GroundPound.Validate())
		SetFailState("Failed to validate memory patches.");
		
	SetupDetour(hGameData);
	
	delete hGameData;
	
	PrintToServer("[SweepFist] Successfully validated patch for 2 check in \"" ... KEY_SWEEPFIST ... "\"");

	FindConVar("mp_gamemode").AddChangeHook(OnGameModeChanged);
	
	PatchGroundPound(true);
}

public void OnPluginEnd()
{
	PatchSweepFist(false);
	PatchGroundPound(false);
	ToggleDetour(false);
}

// =======================================
// Detour Setup
// =======================================

void SetupDetour(GameData &hGameData)
{
	g_hDetour = DHookCreateFromConf(hGameData, KEY_SWEEPFIST);
	//g_hDetour_GroundPound = DHookCreateFromConf(hGameData, KEY_GROUNDPOUND);
	if (g_hDetour == null/* || g_hDetour_GroundPound == null*/)
		SetFailState("Missing detour settings for or signature of \"%s\"", g_hDetour == null ? KEY_SWEEPFIST : KEY_GROUNDPOUND);
}

// =======================================
// Forwards
// =======================================

public void OnConfigsExecuted()
{
	bool bIsAllowedGamemode = IsAllowedGamemode();
	if (!bIsAllowedGamemode) { PatchSweepFist(false); PatchGroundPound(false); }
	
	ToggleDetour(bIsAllowedGamemode);
}

public void OnGameModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	OnConfigsExecuted();
}

// =======================================
// IsAllowedGamemode() credie to Silvers
// =======================================

bool g_bMapStarted;
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
			patched = true;
		else
			SetFailState("Failed in patching checks for \"" ... KEY_SWEEPFIST ... "\"");
	}
}

void PatchGroundPound(bool patch)
{
	static bool patched = false;
	if (patched && !patch)
	{
		g_hPatcher_GroundPound.Disable();
		patched = false;
	}
	else if (!patched && patch)
	{
		if (g_hPatcher_GroundPound.Enable())
			patched = true;
		else
			SetFailState("Failed in patching checks for \"" ... KEY_GROUNDPOUND ... "\"");
	}
}

void ToggleDetour(bool enable)
{
	static bool detoured = false;
	if (detoured && !enable)
	{
		if (!g_bLeft4Dead2 && g_bLinux) {
			if (!DHookDisableDetour(g_hDetour, false, OnSweepFistPre_L4D1Linux) || !DHookDisableDetour(g_hDetour, true, OnSweepFistPost_L4D1Linux)) {
				SetFailState("Failed to disable detour for \"" ... KEY_SWEEPFIST ... "\"");
			}
		} else {
			if (!DHookDisableDetour(g_hDetour, false, OnSweepFistPre) || !DHookDisableDetour(g_hDetour, true, OnSweepFistPost)) {
				SetFailState("Failed to disable detour for \"" ... KEY_SWEEPFIST ... "\"");
			}
		}
		/*if (g_bLeft4Dead2 && g_bLinux) {
			if (!DHookDisableDetour(g_hDetour_GroundPound, false, OnGroundPoundPre) || DHookDisableDetour(g_hDetour_GroundPound, true, OnGroundPoundPost)) {
				SetFailState("Failed to disable detour for \"" ... KEY_GROUNDPOUND ... "\"");
			}
		}*/
		detoured = false;
	}
	else if (!detoured && enable)
	{
		if (!g_bLeft4Dead2 && g_bLinux) {
			if (!DHookEnableDetour(g_hDetour, false, OnSweepFistPre_L4D1Linux) || !DHookEnableDetour(g_hDetour, true, OnSweepFistPost_L4D1Linux)) {
				SetFailState("Failed to enable detour for \"" ... KEY_SWEEPFIST ... "\"");
			}
		} else {
			if (!DHookEnableDetour(g_hDetour, false, OnSweepFistPre) || !DHookEnableDetour(g_hDetour, true, OnSweepFistPost)) {
				SetFailState("Failed to enable detour for \"" ... KEY_SWEEPFIST ... "\"");
			}
		}
		/*if (g_bLeft4Dead2 && g_bLinux) {
			if (!DHookEnableDetour(g_hDetour_GroundPound, false, OnGroundPoundPre) || DHookEnableDetour(g_hDetour_GroundPound, true, OnGroundPoundPost)) {
				SetFailState("Failed to enable detour for \"" ... KEY_GROUNDPOUND ... "\"");
			}
		}*/
		detoured = true;
	}
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

public MRESReturn OnSweepFistPre_L4D1Linux(Handle hParams)
{
	int iFist = DHookGetParam(hParams, 1);
	
	if (!IsValidEntity(iFist)) return;
	
	int tank = GetEntPropEnt(iFist, Prop_Send, "m_hOwner");
	if (IsTank(tank))
	{
		PatchSweepFist(true);
	}
}

public MRESReturn OnSweepFistPost(int pThis, Handle hParams)
{
	if (IsValidEntity(pThis))
		PatchSweepFist(false);
}

public MRESReturn OnSweepFistPost_L4D1Linux(Handle hParams)
{
	int iFist = DHookGetParam(hParams, 1);
	
	if (IsValidEntity(iFist))
		PatchSweepFist(false);
}

/*public MRESReturn OnGroundPoundPre(Handle hReturn, Handle hParams)
{
	//if (IsValidEntity(pThis))
		PatchGroundPound(true);
}

public MRESReturn OnGroundPoundPost(Handle hReturn, Handle hParams)
{
	//if (IsValidEntity(pThis))
		PatchGroundPound(false);
}*/

// =======================================
// Helper
// =======================================

#define IS_VALID_CLIENT_INGAME(%0) ((%0) <= MaxClients && (%0) > 0 && IsClientInGame(%0))
stock bool IsTank(int client) {
	return IS_VALID_CLIENT_INGAME(client)
		&& GetClientTeam(client) == 3
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == (g_bLeft4Dead2 ? 8 : 5);
}