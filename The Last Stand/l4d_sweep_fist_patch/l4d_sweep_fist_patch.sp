#include <sourcemod>
#include <sourcescramble>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.3a"

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

#define KEY_SWEEPFIST_CHECK1 "CTankClaw::SweepFist::Check1"
#define KEY_SWEEPFIST_CHECK2 "CTankClaw::SweepFist::Check2"
#define KEY_GROUNDPOUND_CHECK "CTankClaw::GroundPound::Check"

#define KEY_DOSWING "CTankClaw::DoSwing"
#define KEY_GROUNDPOUND "CTankClaw::GroundPound"

MemoryPatch g_hPatcher_Check1;
MemoryPatch g_hPatcher_Check2;
MemoryPatch g_hPatcher_GroundPound;

enum PatcherException
{
	PATCHER_NOERROR			= 0,
	PATCHER_CHECK1			= (1 << 0),
	PATCHER_CHECK2			= (1 << 1),
	PATCHER_GROUNDPOUND		= (1 << 2)
}

Handle g_hDetour_DoSwing;
Handle g_hDetour_GroundPound;

bool g_bMapStarted;
bool g_bLeft4Dead2;

// =======================================
// Engine Detect
// =======================================

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bMapStarted = late;
	
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
	
	g_hPatcher_Check1 = MemoryPatch.CreateFromConf(hGameData, KEY_SWEEPFIST_CHECK1);
	g_hPatcher_Check2 = MemoryPatch.CreateFromConf(hGameData, KEY_SWEEPFIST_CHECK2);
	g_hPatcher_GroundPound = MemoryPatch.CreateFromConf(hGameData, KEY_GROUNDPOUND_CHECK);
	
	PatcherException e = ValidatePatches();
	if (e != PATCHER_NOERROR)
		SetFailState("Failed to validate memory patches (exception %i).", view_as<int>(e));
	
	SetupDetour(hGameData);
	
	delete hGameData;
	
	FindConVar("mp_gamemode").AddChangeHook(OnGameModeChanged);
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

PatcherException ValidatePatches()
{
	PatcherException e = PATCHER_NOERROR;
	if (g_hPatcher_Check1 == null || !g_hPatcher_Check1.Validate())
		e |= PATCHER_CHECK1;
		
	if (g_hPatcher_Check2 == null || !g_hPatcher_Check2.Validate())
		e |= PATCHER_CHECK2;
	
	if (g_hPatcher_GroundPound == null || !g_hPatcher_GroundPound.Validate())
		e |= PATCHER_GROUNDPOUND;
		
	return e;
}

void SetupDetour(GameData &hGameData)
{
	g_hDetour_DoSwing = DHookCreateFromConf(hGameData, KEY_DOSWING);
	g_hDetour_GroundPound = DHookCreateFromConf(hGameData, KEY_GROUNDPOUND);
	if (g_hDetour_DoSwing == null || g_hDetour_GroundPound == null)
		SetFailState("Missing detour settings for or signature of \"%s\"", g_hDetour_DoSwing == null ? KEY_DOSWING : KEY_GROUNDPOUND);
}

// =======================================
// Patch Control
// =======================================

public void OnConfigsExecuted()
{
	bool bIsAllowedGamemode = IsAllowedGamemode();
	if (!bIsAllowedGamemode)
	{
		PatchSweepFist(false);
		PatchGroundPound(false);
	}
	ToggleDetour(bIsAllowedGamemode);
}

public void OnGameModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	OnConfigsExecuted();
}

// =======================================
// IsAllowedGamemode() credit to Silvers
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
		if (g_bLeft4Dead2) HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
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
// Patch methods
// =======================================

void PatchSweepFist(bool patch)
{
	static bool patched = false;
	if (!patched && patch)
	{
		if (!g_hPatcher_Check1.Enable() || !g_hPatcher_Check2.Enable())
			SetFailState("Failed in patching checks for \"" ... KEY_DOSWING ... "\"");
		patched = true;
	}
	else if (patched && !patch)
	{
		g_hPatcher_Check1.Disable();
		g_hPatcher_Check2.Disable();
		patched = false;
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
	if (enable && !detoured)
	{
		if (!DHookEnableDetour(g_hDetour_DoSwing, false, OnDoSwingPre) || !DHookEnableDetour(g_hDetour_DoSwing, true, OnDoSwingPost)) {
			SetFailState("Failed to enable detours for \"" ... KEY_DOSWING ... "\"");
		}
		if (!DHookEnableDetour(g_hDetour_GroundPound, false, OnGroundPoundPre) || !DHookEnableDetour(g_hDetour_GroundPound, true, OnGroundPoundPost)) {
			SetFailState("Failed to enable detours for \"" ... KEY_GROUNDPOUND ... "\"");
		}
		detoured = true;
	}
	else if (!enable && detoured)
	{
		if (!DHookDisableDetour(g_hDetour_DoSwing, false, OnDoSwingPre) || !DHookDisableDetour(g_hDetour_DoSwing, true, OnDoSwingPost)) {
			SetFailState("Failed to disable detours for \"" ... KEY_DOSWING ... "\"");
		}
		if (!DHookDisableDetour(g_hDetour_GroundPound, false, OnGroundPoundPre) || !DHookDisableDetour(g_hDetour_GroundPound, true, OnGroundPoundPost)) {
			SetFailState("Failed to disable detours for \"" ... KEY_GROUNDPOUND ... "\"");
		}
		detoured = false;
	}
}

// =======================================
// Detour CBs
// =======================================

public MRESReturn OnDoSwingPre(int pThis)
{
	if (IsValidEntity(pThis)) PatchSweepFist(true);
	return MRES_Ignored;
}

public MRESReturn OnDoSwingPost(int pThis)
{
	if (IsValidEntity(pThis)) PatchSweepFist(false);
	return MRES_Ignored;
}

public MRESReturn OnGroundPoundPre(int pThis)
{
	if (IsValidEntity(pThis)) PatchGroundPound(true);
	return MRES_Ignored;
}

public MRESReturn OnGroundPoundPost(int pThis)
{
	if (IsValidEntity(pThis)) PatchGroundPound(false);
	return MRES_Ignored;
}