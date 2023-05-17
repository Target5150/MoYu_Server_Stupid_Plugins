#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <builtinvotes>
#include <colors>
#undef REQUIRE_PLUGIN
#include <caster_system>

#define PLUGIN_VERSION "11.0"

public Plugin myinfo =
{
	name = "L4D2 Ready-Up with convenience fixes",
	author = "CanadaRox, Target",
	description = "New and improved ready-up plugin with optimal for convenience.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

// ========================
//  Plugin Variables
// ========================
// Game Cvars
ConVar
	director_no_specials,
	god,
	sb_stop,
	survivor_limit,
	z_max_player_zombies,
	sv_infinite_primary_ammo;

// Plugin Cvars
ConVar 
	// basic
	l4d_ready_enabled,
	// game
	l4d_ready_disable_spawns, l4d_ready_survivor_freeze,
	// action
	l4d_ready_autostart_min, l4d_ready_unbalanced_start, l4d_ready_unbalanced_min;

// Server Name
bool
	readySurvFreeze;

// Sub modules is included here
#include "readyup/const.inc"
#include "readyup/action.inc"
#include "readyup/command.inc"
#include "readyup/game.inc"
#include "readyup/forward.inc"
#include "readyup/native.inc"
#include "readyup/panel.inc"
#include "readyup/player.inc"
// #include "readyup/setup.inc"
#include "readyup/sound.inc"
#include "readyup/util.inc"

// ========================
//  Plugin Setup
// ========================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	SetupNatives();
	SetupForwards();
	RegPluginLibrary("readyup");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadPluginTranslations(TRANSLATION_READYUP);
	
	l4d_ready_enabled			= CreateConVar("l4d_ready_enabled", "1", "Enable this plugin. (Values: 0 = Disabled, 1 = Manual ready, 2 = Auto start, 3 = Team ready)", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	l4d_ready_disable_spawns	= CreateConVar("l4d_ready_disable_spawns", "0", "Prevent SI from having spawns during ready-up", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_survivor_freeze	= CreateConVar("l4d_ready_survivor_freeze", "1", "Freeze the survivors during ready-up.  When unfrozen they are unable to leave the saferoom but can move freely inside", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_autostart_min		= CreateConVar("l4d_ready_autostart_min", "0.25", "Percent of max players (Versus = 8) in game to allow auto-start to proceed.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_unbalanced_start	= CreateConVar("l4d_ready_unbalanced_start", "0", "Allow game to go live when teams are not full.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_unbalanced_min	= CreateConVar("l4d_ready_unbalanced_min", "2", "Minimum of players in each team to allow a unbalanced start.", FCVAR_NOTIFY, true, 0.0);
	
	// game convars
	director_no_specials = FindConVar("director_no_specials");
	survivor_limit = FindConVar("survivor_limit");
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	god = FindConVar("god");
	sb_stop = FindConVar("sb_stop");
	sv_infinite_primary_ammo = FindConVar("sv_infinite_primary_ammo");
	
	SetupCommands();
	
	ReadyManager.Init();
	ReadyPanel.Init();
	ReadyEffect.Init();
	
	readySurvFreeze = l4d_ready_survivor_freeze.BoolValue;
	l4d_ready_survivor_freeze.AddChangeHook(CvarChg_SurvFreeze);
	
	HookEvent("round_start",			RoundStart_Event, EventHookMode_Pre);
	HookEvent("round_end",				RoundEnd_Event, EventHookMode_Pre);
	HookEvent("player_team",			PlayerTeam_Event, EventHookMode_Post);
	HookEvent("gameinstructor_draw",	GameInstructorDraw_Event, EventHookMode_PostNoCopy);
}

public void OnPluginEnd()
{
	ReadyManager.Finish();
}

public void OnNotifyPluginUnloaded(Handle plugin)
{
	if (plugin == ReadyManager.GetCustomReadyUpOwner())
		ReadyManager.Finish();
}

public void OnAllPluginsLoaded()
{
	ReadyPanel.OnPotentialLibraryUpdate();
}

public void OnLibraryRemoved(const char[] name)
{
	ReadyPanel.OnPotentialLibraryUpdate();
}

// ========================
//  ConVar Change
// ========================

void CvarChg_SurvFreeze(ConVar convar, const char[] oldValue, const char[] newValue)
{
	readySurvFreeze = convar.BoolValue;
	
	if (ReadyManager.InReadyUp() && !ReadyManager.IsCustomReadyUp())
	{
		ReturnTeamToSaferoom(L4D2Team_Survivor);
		SetTeamFrozen(L4D2Team_Survivor, readySurvFreeze);
	}
}

// ========================
//  Events
// ========================

void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	ReadyManager.Finish();
	
	ReadyMode readyUpMode = view_as<ReadyMode>(l4d_ready_enabled.IntValue);
	ReadyManager.Create(readyUpMode);
}

void RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	ReadyManager.Finish();
}

void GameInstructorDraw_Event(Event event, const char[] name, bool dontBroadcast)
{
	// Workaround for restarting countdown after scavenge intro
	CreateTimer(0.1, Timer_RestartCountdowns, false, TIMER_FLAG_NO_MAPCHANGE);
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (!client || IsFakeClient(client))
		return;
	
	SetButtonTime(client);
	
	if (!ReadyManager.InReadyUp())
		return;
	
	int team = event.GetInt("team");
	int oldteam = event.GetInt("oldteam");
	
	if (team == L4D2Team_None && oldteam != L4D2Team_Spectator) // Player disconnecting
	{
		ReadyManager.PlayerUnready(client, playerDisconn);
	}
	
	DataPack dp;
	CreateDataTimer(0.1, Timer_PlayerTeam, dp);
	dp.WriteCell(client);
	dp.WriteCell(userid);
	dp.WriteCell(oldteam);
}

Action Timer_PlayerTeam(Handle timer, DataPack dp)
{
	dp.Reset();
	
	int client = dp.ReadCell();
	int userid = dp.ReadCell();
	int oldteam = dp.ReadCell();
	
	if (client == GetClientOfUserId(userid))
	{
		int team = GetClientTeam(client);
		if (team != oldteam)
		{
			if (oldteam != L4D2Team_None || team != L4D2Team_Spectator)
			{
				ReadyManager.PlayerUnready(client, teamShuffle);
			}
		}
	}
	
	return Plugin_Stop;
}

// ========================
//  Forwards
// ========================

public void OnMapStart()
{
	ReadyEffect.Precache();
	
	HookEntityOutput("info_director", "OnGameplayStart", EntOutput_OnGameplayStart);
}

void EntOutput_OnGameplayStart(const char[] output, int caller, int activator, float delay)
{
	ReadyManager.Finish();
	
	ReadyMode readyUpMode = view_as<ReadyMode>(l4d_ready_enabled.IntValue);
	ReadyManager.Create(readyUpMode);
}

/* This ensures all cvars are reset if the map is changed during ready-up */
public void OnMapEnd()
{
	ReadyManager.Finish();
}

public void OnClientPostAdminCheck(int client)
{
	if (ReadyManager.InReadyUp() && L4D2_IsScavengeMode() && !IsFakeClient(client))
	{
		ToggleCountdownPanel(false, client);
	}
}

public void OnClientDisconnect(int client)
{
	ReadyPanel.SetHiddenTo(client, false);
}

/* No need to do any other checks since it seems like this is required no matter what since the intros unfreezes players after the animation completes */
public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (ReadyManager.InReadyUp() && IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
			static int iLastMouse[MAXPLAYERS+1][2];
			
			// Mouse Movement Check
			if (mouse[0] != iLastMouse[client][0] || mouse[1] != iLastMouse[client][1])
			{
				iLastMouse[client][0] = mouse[0];
				iLastMouse[client][1] = mouse[1];
				SetButtonTime(client);
			}
			else if (buttons || impulse) SetButtonTime(client);
		}
		
		if (!ReadyManager.IsCustomReadyUp())
		{
			if (GetClientTeam(client) == L4D2Team_Survivor)
			{
				if (readySurvFreeze || ReadyManager.InLiveCountdown())
				{
					MoveType iMoveType = GetEntityMoveType(client);
					if (iMoveType != MOVETYPE_NONE && iMoveType != MOVETYPE_NOCLIP)
					{
						SetClientFrozen(client, true);
					}
				}
				else
				{
					if (GetEntProp(client, Prop_Send, "m_nWaterLevel") == WL_Eyes)
					{
						ReturnPlayerToSaferoom(client, false);
					}
				}
			}
		}
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if (ReadyManager.InReadyUp() && !ReadyManager.IsCustomReadyUp())
	{
		if (!L4D_IsSurvivalMode()) // no saferoom for survival
		{
			CreateTimer(0.1, Timer_RestartCountdowns, false, TIMER_FLAG_NO_MAPCHANGE);
			ReturnPlayerToSaferoom(client, false);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

// ========================
//  Readyup Events
// ========================

public void OnReadyUpInitiate()
{
	ReadyPanel.Create();
	
	SetAllowSpawns(!l4d_ready_disable_spawns.BoolValue);
	
	sv_infinite_primary_ammo.SetBool(true, .notify = false);
	god.SetBool(true, .notify = false);
	sb_stop.SetBool(true, .notify = false);
	
	CreateTimer(0.3, Timer_RestartCountdowns, false, TIMER_FLAG_NO_MAPCHANGE);
	
	if (L4D_IsSurvivalMode())
	{
		LockUnlockSurvivalStart(true);
	}
}

public void OnReadyUpFinished()
{
	ReadyPanel.Destroy();
	
	SetAllowSpawns(true);
	SetTeamFrozen(L4D2Team_Survivor, false);
	
	sv_infinite_primary_ammo.SetBool(false, .notify = false);
	god.SetBool(false, .notify = false);
	sb_stop.SetBool(false, .notify = false);
	
	RestartCountdowns(true);
	
	if (L4D_IsSurvivalMode())
	{
		LockUnlockSurvivalStart(false);
	}
}

public void OnRoundIsLive()
{
	ClearSurvivorProgress();
	
	ReadyEffect.PlayLiveSound();
	PrintHintTextToAll("%t", "RoundIsLive");
}

public void OnRoundLiveCountdown()
{
	ReturnTeamToSaferoom(L4D2Team_Survivor);
	PrintHintTextToAll("%t", "LiveCountdownBegin");
}

public void OnRoundLiveCountdownTick(int countdown)
{
	PrintHintTextToAll("%t", "LiveCountdown", countdown);
	ReadyEffect.PlayCountdownSound();
}

public void OnReadyCountdownCancelled2(int client, DisruptType type)
{
	SetTeamFrozen(L4D2Team_Survivor, readySurvFreeze);
	if (type == teamShuffle) // fix spectating
		SetClientFrozen(client, false);
	
	PrintHintTextToAll("%t", "LiveCountdownCancelled");
	CPrintToChatAllEx(client, "%t", g_sDisruptReason[type], client);
}

public Action OnCheckFullReady(bool &retVal)
{
	if (ReadyManager.GetReadyMode() == ReadyMode_TeamReady)
	{
		retVal = ReadyManager.IsTeamReady(ReadyTeam_Survivor) && ReadyManager.IsTeamReady(ReadyTeam_Infected);
		return Plugin_Changed;
	}
	
	int survReadyCount = 0, infReadyCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && ReadyManager.IsPlayerReady(i))
		{
			switch (GetClientTeam(i))
			{
				case L4D2Team_Survivor: survReadyCount++;
				case L4D2Team_Infected: infReadyCount++;
			}
		}
	}
	
	int survLimit = survivor_limit.IntValue;
	int zombLimit = z_max_player_zombies.IntValue;
	
	if (l4d_ready_unbalanced_start.BoolValue)
	{
		int iBaseline = l4d_ready_unbalanced_min.IntValue;
		
		if (iBaseline > survLimit) iBaseline = survLimit;
		if (iBaseline > zombLimit) iBaseline = zombLimit;
		
		int survCount = GetTeamHumanCount(L4D2Team_Survivor);
		int infCount = GetTeamHumanCount(L4D2Team_Infected);
		
		retVal = (iBaseline <= survCount && survCount <= survReadyCount)
			&& (iBaseline <= infCount && infCount <= infReadyCount);
	}
	else
	{
		retVal = (survReadyCount + infReadyCount) >= survLimit + zombLimit;
	}
	
	return Plugin_Changed;
}

public Action OnCheckAutoStart(bool &retVal)
{
	if (GetSeriousClientCount(true) <= GetMaxAllowedPlayers() * l4d_ready_autostart_min.FloatValue)
	{
		// not enough players in game
		PrintHintTextToAll("%t", "AutoStartNotEnoughPlayers");
		retVal = false;
		return Plugin_Changed;
	}
	
	retVal = true;
	return Plugin_Changed;
}

public void OnAutoStartCountdown()
{
	PrintHintTextToAll("%t", "InitiateAutoStart");
}

public void OnAutoStartCountdownTick(int countdown)
{
	PrintHintTextToAll("%t", "AutoStartCountdown", countdown);
	ReadyEffect.PlayAutoStartSound();
}

public void OnPlayerReady(int client)
{
	ReadyEffect.PlayNotifySound(client);
	ReadyEffect.DoSecrets(client);
}

public void OnPlayerUnready(int client)
{
	ReadyEffect.PlayNotifySound(client);
	ReadyEffect.DoSecrets(client);
	SetButtonTime(client);
}

public void OnTeamReady(ReadyTeam team, int client)
{
	OnPlayerReady(client);
}

public void OnTeamUnready(ReadyTeam team, int client)
{
	OnPlayerUnready(client);
}

public void OnAdminForceStart(int client)
{
	CPrintToChatAll("%t", "ForceStartAdmin", client);
}