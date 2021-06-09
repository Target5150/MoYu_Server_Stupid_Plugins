#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <builtinvotes>
#include <colors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "9.1.6"

#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})

#define L4D2Team_None		0
#define L4D2Team_Spectator	1
#define L4D2Team_Survivor	2
#define L4D2Team_Infected	3

#define MAX_FOOTERS 10
#define MAX_FOOTER_LEN 65
#define MAX_SOUNDS 5

#define SECRET_SOUND "/level/gnomeftw.wav"
#define DEFAULT_COUNTDOWN_SOUND "weapons/hegrenade/beep.wav"
#define DEFAULT_LIVE_SOUND "ui/survival_medal.wav"
#define DEFAULT_AUTOSTART_SOUND "ui/buttonrollover.wav"

#define TRANSLATION_COMMON "common.phrases"
#define TRANSLATION_READYUP "readyup.phrases"

#define READY_MODE_MANUAL 1
#define READY_MODE_AUTOSTART 2

#define DEBUG 0

public Plugin myinfo =
{
	name = "L4D2 Ready-Up with convenience fixes",
	author = "CanadaRox, Target",
	description = "New and improved ready-up plugin with optimal for convenience.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

// Game Cvars
ConVar	director_no_specials, god, sb_stop, survivor_limit, z_max_player_zombies, sv_infinite_primary_ammo, scavenge_round_setup_time;

// Plugin Cvars
ConVar	l4d_ready_enabled,
		l4d_ready_disable_spawns, l4d_ready_survivor_freeze,
		l4d_ready_cfg_name, l4d_ready_max_players,
		l4d_ready_delay, l4d_ready_autostart_delay, l4d_ready_autostart_wait,
		l4d_ready_enable_sound, l4d_ready_chuckle, l4d_ready_countdown_sound, l4d_ready_live_sound, l4d_ready_autostart_sound,
		l4d_ready_secret,
		l4d_ready_unbalanced_start;

// Plugin Handles
ConVar ServerNamer;
Handle g_hVote;
GlobalForward liveForward;
Handle readyCountdownTimer;
StringMap casterTrie;
//StringMap allowedCastersTrie;
Handle blockSecretSpam[MAXPLAYERS+1];

// Ready Panel
bool hiddenPanel[MAXPLAYERS+1], hiddenManually[MAXPLAYERS+1];
char sCmd[32], readyFooter[MAX_FOOTERS][MAX_FOOTER_LEN];
int iCmd, footerCounter;
float fStartTimestamp;

// Plugin Vars
bool inLiveCountdown, inReadyUp, bSkipWarp, readySurvFreeze, isPlayerReady[MAXPLAYERS+1];
char countdownSound[PLATFORM_MAX_PATH], liveSound[PLATFORM_MAX_PATH], autostartSound[PLATFORM_MAX_PATH];
int readyDelay;

//AFK?!
float g_fButtonTime[MAXPLAYERS+1];

// Spectate Fix
Handle g_hChangeTeamTimer[MAXPLAYERS+1];

// Auto Start
bool isAutoStartMode, inAutoStart;
Handle autoStartTimer;
int autoStartDelay, expireTime;

// Reason enum for Countdown cancelling
enum disruptType
{
	readyStatus,
	teamShuffle,
	playerDisconn
};

static const char chuckleSound[MAX_SOUNDS][] =
{
	"/npc/moustachio/strengthattract01.wav",
	"/npc/moustachio/strengthattract02.wav",
	"/npc/moustachio/strengthattract05.wav",
	"/npc/moustachio/strengthattract06.wav",
	"/npc/moustachio/strengthattract09.wav"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("AddStringToReadyFooter",	Native_AddStringToReadyFooter);
	CreateNative("EditFooterStringAtIndex", Native_EditFooterStringAtIndex);
	CreateNative("FindIndexOfFooterString", Native_FindIndexOfFooterString);
	CreateNative("GetFooterStringAtIndex",	Native_GetFooterStringAtIndex);
	CreateNative("IsInReady",				Native_IsInReady);
	CreateNative("IsClientCaster", 			Native_IsClientCaster);
	CreateNative("IsIDCaster", 				Native_IsIDCaster);
	liveForward = new GlobalForward("OnRoundIsLive", ET_Event);
	RegPluginLibrary("readyup");
	return APLRes_Success;
}

public void OnPluginStart()
{
	l4d_ready_enabled			= CreateConVar("l4d_ready_enabled", "1", "Enable this plugin. (Values: 1 = Manual ready, 2 = Auto start)", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	l4d_ready_cfg_name			= CreateConVar("l4d_ready_cfg_name", "", "Configname to display on the ready-up panel", FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	l4d_ready_disable_spawns	= CreateConVar("l4d_ready_disable_spawns", "0", "Prevent SI from having spawns during ready-up", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_survivor_freeze	= CreateConVar("l4d_ready_survivor_freeze", "1", "Freeze the survivors during ready-up.  When unfrozen they are unable to leave the saferoom but can move freely inside", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_max_players		= CreateConVar("l4d_ready_max_players", "12", "Maximum number of players to show on the ready-up panel.", FCVAR_NOTIFY, true, 0.0, true, MAXPLAYERS+1.0);
	l4d_ready_delay				= CreateConVar("l4d_ready_delay", "5", "Number of seconds to count down before the round goes live.", FCVAR_NOTIFY, true, 0.0);
	l4d_ready_autostart_delay	= CreateConVar("l4d_ready_autostart_delay", "5", "Number of seconds to count down before auto-start kicks in.", FCVAR_NOTIFY, true, 0.0);
	l4d_ready_autostart_wait	= CreateConVar("l4d_ready_autostart_wait", "20", "Number of seconds to wait for connecting players before auto-start is forced.", FCVAR_NOTIFY, true, 0.0);
	l4d_ready_enable_sound		= CreateConVar("l4d_ready_enable_sound", "1", "Enable sound during autostart & countdown & on live", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_countdown_sound	= CreateConVar("l4d_ready_countdown_sound", DEFAULT_COUNTDOWN_SOUND, "The sound that plays when a round goes on countdown");	
	l4d_ready_live_sound		= CreateConVar("l4d_ready_live_sound", DEFAULT_LIVE_SOUND, "The sound that plays when a round goes live");
	l4d_ready_autostart_sound	= CreateConVar("l4d_ready_autostart_sound", DEFAULT_AUTOSTART_SOUND, "The sound that plays when auto-start goes on countdown");
	l4d_ready_chuckle			= CreateConVar("l4d_ready_chuckle", "0", "Enable random moustachio chuckle during countdown");
	l4d_ready_secret			= CreateConVar("l4d_ready_secret", "1", "Play something good", _, true, 0.0, true, 1.0);
	l4d_ready_unbalanced_start	= CreateConVar("l4d_ready_unbalanced_start", "0", "Allow game to go live when teams are not full.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("player_team", PlayerTeam_Event, EventHookMode_Pre);
	HookEvent("gameinstructor_draw", GameInstructorDraw_Event, EventHookMode_PostNoCopy);

	casterTrie = new StringMap();
	//allowedCastersTrie = new StringMap();

	director_no_specials = FindConVar("director_no_specials");
	god = FindConVar("god");
	sb_stop = FindConVar("sb_stop");
	survivor_limit = FindConVar("survivor_limit");
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	sv_infinite_primary_ammo = FindConVar("sv_infinite_primary_ammo");
	scavenge_round_setup_time = FindConVar("scavenge_round_setup_time");

	// Ready Commands
	RegConsoleCmd("sm_ready",		Ready_Cmd, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_r",			Ready_Cmd, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_toggleready",	ToggleReady_Cmd, "Toggle your ready status");
	RegConsoleCmd("sm_unready",		Unready_Cmd, "Mark yourself as not ready if you have set yourself as ready");
	RegConsoleCmd("sm_nr",			Unready_Cmd, "Mark yourself as not ready if you have set yourself as ready");
	
	// Caster System
	RegAdminCmd("sm_caster",		Caster_Cmd, ADMFLAG_BAN, "Registers a player as a caster so the round will not go live unless they are ready");
	RegConsoleCmd("sm_cast",		Cast_Cmd, "Registers the calling player as a caster so the round will not go live unless they are ready");
	RegConsoleCmd("sm_notcasting",	NotCasting_Cmd, "Deregister yourself as a caster or allow admins to deregister other players");
	RegConsoleCmd("sm_uncast",		NotCasting_Cmd, "Deregister yourself as a caster or allow admins to deregister other players");
	//RegServerCmd("sm_resetcasters", ResetCaster_Cmd, "Used to reset casters between matches.  This should be in confogl_off.cfg or equivalent for your system");
	//RegServerCmd("sm_add_caster_id", AddCasterSteamID_Cmd, "Used for adding casters to the whitelist -- i.e. who's allowed to self-register as a caster");
	
	// Player Commands
	RegConsoleCmd("sm_hide",		Hide_Cmd, "Hides the ready-up panel so other menus can be seen");
	RegConsoleCmd("sm_show",		Show_Cmd, "Shows a hidden ready-up panel");
	RegConsoleCmd("sm_return",		Return_Cmd, "Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
	RegConsoleCmd("sm_forcestart",	ForceStart_Cmd, "Forces the round to start regardless of player ready status.  Players can unready to stop a force");
	RegConsoleCmd("sm_fs",			ForceStart_Cmd, "Forces the round to start regardless of player ready status.  Players can unready to stop a force");
	RegConsoleCmd("sm_kickspecs",	KickSpecs_Cmd, "Let's vote to kick those Spectators!");
	
#if DEBUG
	RegAdminCmd("sm_initready", InitReady_Cmd, ADMFLAG_ROOT);
	RegAdminCmd("sm_initlive", InitLive_Cmd, ADMFLAG_ROOT);
#endif

	AddCommandListener(Say_Callback, "say");
	AddCommandListener(Say_Callback, "say_team");
	AddCommandListener(Vote_Callback, "Vote");

	LoadTranslation();

	readySurvFreeze = l4d_ready_survivor_freeze.BoolValue;
	l4d_ready_survivor_freeze.AddChangeHook(SurvFreezeChange);
}

public void OnPluginEnd()
{
	InitiateLive(false);
}

public void OnAllPluginsLoaded()
{
	FillServerNamer();
}

void LoadTranslation()
{
	char sPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sPath, sizeof sPath, "translations/" ... TRANSLATION_COMMON ... ".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation file \"" ... TRANSLATION_COMMON ... ".txt\"");
	}
	LoadTranslations(TRANSLATION_COMMON);
	
	BuildPath(Path_SM, sPath, sizeof sPath, "translations/" ... TRANSLATION_READYUP ... ".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation file \"" ... TRANSLATION_READYUP ... ".txt\"");
	}
	LoadTranslations(TRANSLATION_READYUP);
}

void FillServerNamer()
{
	if ((ServerNamer = FindConVar("sn_main_name")) == null)
		ServerNamer = FindConVar("hostname");
}



// ========================
//  Events
// ========================

public void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	InitiateReadyUp();
}

public void GameInstructorDraw_Event(Event event, const char[] name, bool dontBroadcast)
{
	// Workaround for remove countdown after scavenge intro
	CreateTimer(0.1, Timer_RemoveCountdown, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

public void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!inReadyUp || isAutoStartMode) return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || IsFakeClient(client)) return;
	
	isPlayerReady[client] = false;
	SetEngineTime(client);
	
	int team = event.GetInt("team");
	int oldteam = event.GetInt("oldteam");
	if (team == L4D2Team_None && oldteam != L4D2Team_Spectator) // Player disconnecting
	{
		CancelFullReady(client, playerDisconn);
	}
	
	else if (!g_hChangeTeamTimer[client]) // Player in-game swapping team
	{
		ArrayStack stack = new ArrayStack();
		stack.Push(client);
		stack.Push(GetClientUserId(client));
		stack.Push(oldteam);
		g_hChangeTeamTimer[client] = CreateTimer(0.1, Timer_PlayerTeam, stack, TIMER_DATA_HNDL_CLOSE);
	}
}

public Action Timer_PlayerTeam(Handle timer, ArrayStack stack)
{
	int oldteam = stack.Pop();
	int userid = stack.Pop();
	int client = stack.Pop();
	
	if (client == GetClientOfUserId(userid) && IsClientInGame(client))
	{
		if (inLiveCountdown)
		{
			int team = GetClientTeam(client);
			if (team != oldteam)
			{
				if (oldteam != L4D2Team_None || team != L4D2Team_Spectator) // Client joined but not player
				{
					CancelFullReady(client, teamShuffle);
				}
			}
		}
	}
	
	g_hChangeTeamTimer[client] = null;
}



// ========================
//  Forwards
// ========================

public void OnMapStart()
{
	/* OnMapEnd needs this to work */
	char szPath[PLATFORM_MAX_PATH];
	
	l4d_ready_countdown_sound.GetString(countdownSound, sizeof(countdownSound));
	l4d_ready_live_sound.GetString(liveSound, sizeof(liveSound));
	l4d_ready_autostart_sound.GetString(autostartSound, sizeof(autostartSound));
	
	Format(szPath, sizeof(szPath), "sound/%s", countdownSound);
	if (!FileExists(szPath, true)) {
		strcopy(countdownSound, sizeof(countdownSound), DEFAULT_COUNTDOWN_SOUND);
	}
	
	Format(szPath, sizeof(szPath), "sound/%s", liveSound);
	if (!FileExists(szPath, true)) {
		strcopy(liveSound, sizeof(liveSound), DEFAULT_LIVE_SOUND);
	}
	
	Format(szPath, sizeof(szPath), "sound/%s", autostartSound);
	if (!FileExists(szPath, true)) {
		strcopy(autostartSound, sizeof(autostartSound), DEFAULT_AUTOSTART_SOUND);
	}
	
	PrecacheSound(SECRET_SOUND);
	PrecacheSound(countdownSound);
	PrecacheSound(liveSound);
	PrecacheSound(autostartSound);
	for (int i = 0; i < MAX_SOUNDS; i++)
	{
		PrecacheSound(chuckleSound[i]);
	}
	for (int client = 1; client <= MAXPLAYERS; client++)
	{
		blockSecretSpam[client] = null;
		g_hChangeTeamTimer[client] = null;
	}
	readyCountdownTimer = null;
}

/* This ensures all cvars are reset if the map is changed during ready-up */
public void OnMapEnd()
{
	if (inReadyUp)
	{
		InitiateAutoStart(false);
		InitiateLive(false);
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (inReadyUp && IsScavenge() && !IsFakeClient(client))
	{
		ToggleCountdownPanel(false, client);
	}
}

public void OnClientDisconnect(int client)
{
	hiddenPanel[client] = false;
	hiddenManually[client] = false;
	isPlayerReady[client] = false;
	g_fButtonTime[client] = 0.0;
	g_hChangeTeamTimer[client] = null;
}

/* No need to do any other checks since it seems like this is required no matter what since the intros unfreezes players after the animation completes */
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (inReadyUp && IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
			if (buttons || impulse) SetEngineTime(client);
			
			static int iLastMouse[MAXPLAYERS+1][2];
			
			// Mouse Movement Check
			if (mouse[0] != iLastMouse[client][0] || mouse[1] != iLastMouse[client][1])
			{
				iLastMouse[client][0] = mouse[0];
				iLastMouse[client][1] = mouse[1];
				SetEngineTime(client);
			}
		}
		
		if (GetClientTeam(client) == L4D2Team_Survivor)
		{
			if (readySurvFreeze)
			{
				MoveType iMoveType = GetEntityMoveType(client);
				if (!(iMoveType == MOVETYPE_NONE || iMoveType == MOVETYPE_NOCLIP))
				{
					SetClientFrozen(client, true);
				}
			}
			else
			{
				if (GetEntityFlags(client) & FL_INWATER)
				{
					ReturnPlayerToSaferoom(client, false);
				}
			}
		}
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if (inReadyUp)
	{
		ReturnPlayerToSaferoom(client, false);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}



// ========================
//  Command Listener
// ========================

public Action Say_Callback(int client, const char[] command, int argc)
{
	SetEngineTime(client);
}

public Action Vote_Callback(int client, const char[] command, int argc)
{
	// Used to fast ready/unready through default keybinds for voting
	if (!inReadyUp) return;
	if (IsBuiltinVoteInProgress()) return;
	if (!client) return;
	
	char sArg[8];
	GetCmdArg(1, sArg, sizeof(sArg));
	if (strcmp(sArg, "Yes", false) == 0)
		Ready_Cmd(client, 0);
	else if (strcmp(sArg, "No", false) == 0)
		Unready_Cmd(client, 0);
}



// ========================
//  ConVar Change
// ========================

public void SurvFreezeChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	readySurvFreeze = convar.BoolValue;
	
	if (inReadyUp)
	{
		ReturnTeamToSaferoom(L4D2Team_Survivor);
		SetTeamFrozen(L4D2Team_Survivor, readySurvFreeze);
	}
}



// ========================
//  Ready Commands
// ========================

public Action Ready_Cmd(int client, int args)
{
	if (inReadyUp && IsPlayer(client))
	{
		isPlayerReady[client] = true;
		if (l4d_ready_secret.BoolValue)
			DoSecrets(client);
		if (!inAutoStart && CheckFullReady())
			InitiateLiveCountdown();
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Unready_Cmd(int client, int args)
{
	if (inReadyUp && !isAutoStartMode)
	{
		if (IsPlayer(client))
		{
			SetEngineTime(client);
			isPlayerReady[client] = false;
		}
		else
		{
			AdminId id = GetUserAdmin(client);
			if (id != INVALID_ADMIN_ID && GetAdminFlag(id, Admin_Ban)) // Check for specific admin flag
			{
				return Plugin_Handled;
			}
		}
		
		// Client must be a player or an admin with ban flag to request.
		CancelFullReady(client, readyStatus);
		
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action ToggleReady_Cmd(int client, int args)
{
	if (inReadyUp && IsPlayer(client))
	{
		return isPlayerReady[client] ? Unready_Cmd(client, 0) : Ready_Cmd(client, 0);
	}
	return Plugin_Continue;
}



// ========================
//  Caster System
// ========================

public Action Cast_Cmd(int client, int args)
{
	if (!client) return Plugin_Continue;
	
 	char buffer[64];
	GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
	
	bool temp;
	if (!casterTrie.GetValue(buffer, temp))
	{
		if (GetClientTeam(client) != L4D2Team_Spectator)
		{
			ChangeClientTeam(client, L4D2Team_Spectator);
		}
		casterTrie.SetValue(buffer, true);
		CPrintToChat(client, "{blue}[{default}Cast{blue}] {default}%t", "SelfCast1");
		CPrintToChat(client, "{blue}[{default}Cast{blue}] {default}%t", "SelfCast2");
	}
	
	return Plugin_Handled;
}

public Action Caster_Cmd(int client, int args)
{	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_caster <player>");
		return Plugin_Handled;
	}
	
	char buffer[64];
	GetCmdArg(1, buffer, sizeof(buffer));
	
	int target = FindTarget(client, buffer, true, false);
	if (target > 0) // If FindTarget fails we don't need to print anything as it prints it for us!
	{
		if (GetClientAuthId(target, AuthId_Steam2, buffer, sizeof(buffer)))
		{
			casterTrie.SetValue(buffer, true);
			ReplyToCommand(client, "\x01%t", "RegCasterReply", target);
			CPrintToChat(target, "{blue}[{olive}!{blue}] %t", "RegCasterTarget", client);
			CPrintToChat(target, "{blue}[{default}Cast{blue}] {default}%t", "SelfCast2");
		}
		else
		{
			ReplyToCommand(client, "\x01%t", "CasterSteamIDError");
		}
	}
	
	return Plugin_Handled;
}

public Action NotCasting_Cmd(int client, int args)
{
	char buffer[64];
	
	if (args < 1) // If no target is specified, assumes self-uncasting
	{
		GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
		if (casterTrie.Remove(buffer))
		{
			CPrintToChat(client, "{blue}[{default}Reconnect{blue}] {default}%t", "Reconnect1");
			CPrintToChat(client, "{blue}[{default}Reconnect{blue}] {default}%t", "Reconnect2");
			
			// Reconnection to disable their addons
			CreateTimer(3.0, Reconnect, client);
		}
	}
	else // If a target is specified
	{
		AdminId id = GetUserAdmin(client);
		if (id != INVALID_ADMIN_ID && GetAdminFlag(id, Admin_Ban)) // Check for specific admin flag
		{
			ReplyToCommand(client, "\x01%t", "UnregCasterNonAdmin");
			return Plugin_Handled;
		}
		
		GetCmdArg(1, buffer, sizeof(buffer));
		
		int target = FindTarget(client, buffer, true, true);
		if (target > 0) // If FindTarget fails we don't need to print anything as it prints it for us!
		{
			if (GetClientAuthId(target, AuthId_Steam2, buffer, sizeof(buffer)))
			{
				if (casterTrie.Remove(buffer))
				{
					CPrintToChat(target, "{blue}[{olive}!{blue}] {default}%t", "UnregCasterTarget", client);
					NotCasting_Cmd(target, 0);
				}
				ReplyToCommand(client, "\x01%t", "UnregCasterSuccess", target);
			}
			else
			{
				ReplyToCommand(client, "\x01%t", "CasterSteamIDError");
			}
		}
	}
	return Plugin_Handled;
}

public Action Reconnect(Handle timer, int client)
{
	if (IsClientConnected(client)) ReconnectClient(client);
}

/*public Action ResetCaster_Cmd(int args)
{
	casterTrie.Clear();
}

public Action AddCasterSteamID_Cmd(int args)
{
	char buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (buffer[0] != EOS) 
	{
		int index = FindStringInArray(allowedCastersTrie, buffer);
		if (index == -1)
		{
			PushArrayString(allowedCastersTrie, buffer);
			PrintToServer("[casters_database] Added '%s'", buffer);
		}
		else PrintToServer("[casters_database] '%s' already exists", buffer);
	}
	else PrintToServer("[casters_database] No args specified / empty buffer");
}*/



// ========================
//  Player Commands
// ========================

public Action Hide_Cmd(int client, int args)
{
	if (inReadyUp)
	{
		hiddenPanel[client] = true;
		hiddenManually[client] = true;
		CPrintToChat(client, "[{olive}Readyup{default}] %t", "PanelHide");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Show_Cmd(int client, int args)
{
	if (inReadyUp)
	{
		hiddenPanel[client] = false;
		hiddenManually[client] = false;
		CPrintToChat(client, "[{olive}Readyup{default}] %t", "PanelShow");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Return_Cmd(int client, int args)
{
	if (inReadyUp
			&& client > 0
			&& GetClientTeam(client) == L4D2Team_Survivor)
	{
		ReturnPlayerToSaferoom(client, false);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action ForceStart_Cmd(int client, int args)
{
	if (inReadyUp && !isAutoStartMode)
	{		
		// Check if admin always allowed to do so
		AdminId id = GetUserAdmin(client);
		if (id != INVALID_ADMIN_ID && GetAdminFlag(id, Admin_Ban)) // Check for specific admin flag
		{
			InitiateLiveCountdown();
			CPrintToChatAll("[{green}!{default}] %t", "ForceStartAdmin", client);
			return Plugin_Handled;
		}
		
		// ----------------------------------------------
		// * Additional voting function, prepared for PUG
		// ----------------------------------------------
		
		// Filter spectator
		if (!IsPlayer(client))
		{
			CPrintToChat(client, "[{olive}Readyup{default}] %t", "ForceStartVoteSpec");
			return Plugin_Handled;
		}
		
		// No reason to call this when players are full
		int playercount = GetTeamHumanCount(L4D2Team_Survivor) + GetTeamHumanCount(L4D2Team_Infected);
		if (playercount == survivor_limit.IntValue + z_max_player_zombies.IntValue)
		{
			CPrintToChat(client, "[{olive}Readyup{default}] %t", "ForceStartFullPlayers");
			return Plugin_Handled;
		}
		
		// Vote section
		StartForceStartVote(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action KickSpecs_Cmd(int client, int args)
{
	if (inReadyUp)
	{
		AdminId id = GetUserAdmin(client);
		if (id != INVALID_ADMIN_ID && GetAdminFlag(id, Admin_Ban)) // Check for specific admin flag
		{
			CreateTimer(2.0, Timer_KickSpecs);
			CPrintToChatAll("[{green}!{default}] %t", "KickSpecsAdmin", client);
			return Plugin_Handled;
		}
		
		// Filter spectator
		if (!IsPlayer(client))
		{
			CPrintToChat(client, "[{olive}Readyup{default}] %t", "KickSpecsVoteSpec");
			return Plugin_Handled;
		}
		
		StartKickSpecsVote(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}



// ========================
//  Vote
// ========================

void StartForceStartVote(int client)
{
	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(client, "[{olive}Readyup{default}] %t", "VoteInProgress");
		return;
	}
	if (CheckBuiltinVoteDelay() > 0)
	{
		CPrintToChat(client, "[{olive}Readyup{default}] %t", "VoteDelay", CheckBuiltinVoteDelay());
		return;
	}
	
	g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

	char sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "%T (100%%%%)", "ForceStartVoteTitle", LANG_SERVER); // kinda format :D
	SetBuiltinVoteArgument(g_hVote, sBuffer);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, ForceStartVoteResultHandler);
	
	// Display to players and admins
	int total = 0;
	int[] players = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
			
		AdminId id = GetUserAdmin(i);
		if (!IsPlayer(i) && (id == INVALID_ADMIN_ID || !GetAdminFlag(id, Admin_Ban))) continue;
		
		players[total++] = i;
	}
	DisplayBuiltinVote(g_hVote, players, total, FindConVar("sv_vote_timer_duration").IntValue);

	// Client is voting for
	FakeClientCommand(client, "Vote Yes");
}

void StartKickSpecsVote(int client)
{
	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(client, "[{olive}Readyup{default}] %t", "VoteInProgress");
		return;
	}
	if (CheckBuiltinVoteDelay() > 0)
	{
		CPrintToChat(client, "[{olive}Readyup{default}] %t", "VoteDelay", CheckBuiltinVoteDelay());
		return;
	}
	
	g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

	char sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "%T", "KickSpecsVoteTitle", LANG_SERVER);
	SetBuiltinVoteArgument(g_hVote, sBuffer);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, KickSpecsVoteResultHandler);
	
	// Display to players
	int total = 0;
	int[] players = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayer(i))
			continue;
		players[total++] = i;
	}
	DisplayBuiltinVote(g_hVote, players, total, FindConVar("sv_vote_timer_duration").IntValue);

	// Client is voting for
	FakeClientCommand(client, "Vote Yes");
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hVote = null;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
		}
	}
}

public void ForceStartVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if (!inReadyUp || inLiveCountdown)
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
		return;
	}
	
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] < num_clients)
			{
				DisplayBuiltinVoteFail(vote, BuiltinVoteFail_NotEnoughVotes);
				return;
			}
			
			char buffer[64];
			FormatEx(buffer, sizeof(buffer), "%T", "ForceStartVoteSuccess", LANG_SERVER);
			DisplayBuiltinVotePass(vote, buffer);
			
			float delay = FindConVar("sv_vote_command_delay").FloatValue;
			CreateTimer(delay, Timer_ForceStart);
			return;
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action Timer_ForceStart(Handle timer)
{
	InitiateLiveCountdown();
}

public void KickSpecsVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				char buffer[64];
				FormatEx(buffer, sizeof(buffer), "%T", "KickSpecsVoteSuccess", LANG_SERVER);
				DisplayBuiltinVotePass(vote, buffer);
				
				float delay = FindConVar("sv_vote_command_delay").FloatValue;
				CreateTimer(delay, Timer_KickSpecs);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action Timer_KickSpecs(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i)) { continue; }
		if (IsPlayer(i)) { continue; }
		if (IsClientCaster(i)) { continue; }
		if (GetUserAdmin(i) != INVALID_ADMIN_ID) { continue; }
					
		KickClient(i, "%t", "KickSpecsReason");
	}
}



#if DEBUG
public Action:InitReady_Cmd(client, args)
{
	InitiateReadyUp();
	return Plugin_Handled;
}

public Action:InitLive_Cmd(client, args)
{
	InitiateLive();
	return Plugin_Handled;
}
#endif



// ========================
//  Readyup Stuff
// ========================

public int DummyHandler(Handle menu, MenuAction action, int param1, int param2) { }

public Action MenuRefresh_Timer(Handle timer)
{
	if (inReadyUp)
	{
		UpdatePanel();
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

public Action MenuCmd_Timer(Handle timer)
{
	if (inReadyUp)
	{
		iCmd > 9 ? (iCmd = 1) : (iCmd += 1);
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

void PrintCmd()
{
	switch (iCmd)
	{
		case 1: FormatEx(sCmd, sizeof(sCmd), "->1. !ready|!r / !unready|!nr");
		case 2: FormatEx(sCmd, sizeof(sCmd), "->2. !slots #");
		case 3: FormatEx(sCmd, sizeof(sCmd), "->3. !voteboss <tank> <witch>");
		case 4: FormatEx(sCmd, sizeof(sCmd), "->4. !match / !rmatch");
		case 5: FormatEx(sCmd, sizeof(sCmd), "->5. !show / !hide");
		case 6: FormatEx(sCmd, sizeof(sCmd), "->6. !setscores <survs> <inf>");
		case 7: FormatEx(sCmd, sizeof(sCmd), "->7. !lerps");
		case 8: FormatEx(sCmd, sizeof(sCmd), "->8. !secondary");
		case 9: FormatEx(sCmd, sizeof(sCmd), "->9. !forcestart / !fs");
	}
}

void UpdatePanel()
{
	if (BuiltinVote_IsVoteInProgress())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsClientInBuiltinVotePool(i))
				hiddenPanel[i] = true;
		}
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !hiddenManually[i])
				hiddenPanel[i] = false;
		}
	}
	
	char survivorBuffer[800] = "";
	char infectedBuffer[800] = "";
	char casterBuffer[600] = "";
	char specBuffer[400] = "";
	int playerCount = 0;
	int casterCount = 0;
	int specCount = 0;

	Panel menuPanel = new Panel();

	char ServerBuffer[128];
	char ServerName[32];
	char cfgName[32];
	PrintCmd();

	int iPassTime = RoundToFloor(GetGameTime() - fStartTimestamp);

	ServerNamer.GetString(ServerName, sizeof(ServerName));
	
	l4d_ready_cfg_name.GetString(cfgName, sizeof(cfgName));
	Format(ServerBuffer, sizeof(ServerBuffer), "▸ Server: %s \n▸ Slots: %d/%d\n▸ Config: %s", ServerName, GetSeriousClientCount(), FindConVar("sv_maxplayers").IntValue, cfgName);
	menuPanel.DrawText(ServerBuffer);
	
	FormatTime(ServerBuffer, sizeof(ServerBuffer), "▸ %m/%d/%Y - %I:%M%p");
	Format(ServerBuffer, sizeof(ServerBuffer), "%s (%02d:%02d)", ServerBuffer, iPassTime / 60, iPassTime % 60);
	menuPanel.DrawText(ServerBuffer);
	
	menuPanel.DrawText(" ");
	menuPanel.DrawText("▸ Commands:");
	menuPanel.DrawText(sCmd);
	menuPanel.DrawText(" ");
	
	char nameBuf[64];
	char authBuffer[64];
	bool caster;
	bool dummy;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			++playerCount;
			GetClientName(client, nameBuf, sizeof(nameBuf));
			GetClientAuthId(client, AuthId_Steam2, authBuffer, sizeof(authBuffer));
			caster = casterTrie.GetValue(authBuffer, dummy);
			
			if (IsPlayer(client))
			{
				if (isPlayerReady[client])
				{
					if (!inLiveCountdown && !isAutoStartMode) PrintHintText(client, "%t", "HintReady");
					Format(nameBuf, sizeof(nameBuf), isAutoStartMode ? "%s\n" : "☑ %s\n", nameBuf);
					GetClientTeam(client) == L4D2Team_Survivor ? StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf) : StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
				}
				else 
				{
					if (!inLiveCountdown && !isAutoStartMode) PrintHintText(client, "%t", "HintUnready");
					Format(nameBuf, sizeof(nameBuf), isAutoStartMode ? "%s\n" : "☐ %s%s\n", nameBuf, ( IsPlayerAfk(client) ? " [AFK]" : "" ));
					GetClientTeam(client) == L4D2Team_Survivor ? StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf) : StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
				}
			}
			else
			{
				++specCount;
				if (caster)
				{
					++casterCount;
					Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
					StrCat(casterBuffer, sizeof(casterBuffer), nameBuf);
				}
				else
				{
					if (playerCount <= l4d_ready_max_players.IntValue)
					{
						Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
						StrCat(specBuffer, sizeof(specBuffer), nameBuf);
					}
				}
			}
		}
	}
	
	int textCount = 0;
	int bufLen = strlen(survivorBuffer);
	if (bufLen != 0)
	{
		survivorBuffer[bufLen] = '\0';
		ReplaceString(survivorBuffer, sizeof(survivorBuffer), "#buy", "<- TROLL");
		ReplaceString(survivorBuffer, sizeof(survivorBuffer), "#", "_");
		Format(nameBuf, sizeof(nameBuf), "->%d. Survivors", ++textCount);
		menuPanel.DrawText(nameBuf);
		menuPanel.DrawText(survivorBuffer);
	}

	bufLen = strlen(infectedBuffer);
	if (bufLen != 0)
	{
		infectedBuffer[bufLen] = '\0';
		ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#buy", "<- TROLL");
		ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#", "_");
		Format(nameBuf, sizeof(nameBuf), "->%d. Infected", ++textCount);
		menuPanel.DrawText(nameBuf);
		menuPanel.DrawText(infectedBuffer);
	}
	
	if (specCount && textCount) menuPanel.DrawText(" ");

	bufLen = strlen(casterBuffer);
	if (bufLen != 0)
	{
		casterBuffer[bufLen] = '\0';
		Format(nameBuf, sizeof(nameBuf), "->%d. Caster%s", ++textCount, casterCount > 1 ? "s" : "");
		menuPanel.DrawText(nameBuf);
		ReplaceString(casterBuffer, sizeof(casterBuffer), "#", "_", true);
		menuPanel.DrawText(casterBuffer);
	}
	
	bufLen = strlen(specBuffer);
	if (bufLen != 0)
	{
		specBuffer[bufLen] = '\0';
		Format(nameBuf, sizeof(nameBuf), "->%d. Spectator%s", ++textCount, specCount > 1 ? "s" : "");
		menuPanel.DrawText(nameBuf);
		ReplaceString(specBuffer, sizeof(specBuffer), "#", "_");
		if (playerCount > l4d_ready_max_players.IntValue && specCount - casterCount > 1)
			FormatEx(specBuffer, sizeof(specBuffer), "**Many** (%d)", specCount - casterCount);
		menuPanel.DrawText(specBuffer);
	}

	bufLen = strlen(readyFooter[0]);
	if (bufLen != 0)
	{
		menuPanel.DrawText(" ");
		for (int i = 0; i < footerCounter; i++)
		{
			menuPanel.DrawText(readyFooter[i]);
		}
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !hiddenPanel[client])
		{
			menuPanel.Send(client, DummyHandler, 1);
		}
	}
	
	delete menuPanel;
}

void InitiateReadyUp()
{
	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		isPlayerReady[i] = false;
	}

	UpdatePanel();
	CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(4.0, MenuCmd_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	inReadyUp = true;
	inLiveCountdown = false;
	readyCountdownTimer = null;
	
	fStartTimestamp = GetGameTime();
	
	isAutoStartMode = (l4d_ready_enabled.IntValue == READY_MODE_AUTOSTART);

	if (l4d_ready_disable_spawns.BoolValue)
	{
		director_no_specials.SetBool(true);
	}

	sv_infinite_primary_ammo.Flags &= ~FCVAR_NOTIFY;
	sv_infinite_primary_ammo.SetBool(true);
	sv_infinite_primary_ammo.Flags |= FCVAR_NOTIFY;
	god.Flags &= ~FCVAR_NOTIFY;
	god.SetBool(true);
	god.Flags |= FCVAR_NOTIFY;
	sb_stop.SetBool(true);

	for (int i = 0; i < MAX_FOOTERS; i++)
	{
		readyFooter[i][0] = '\0';
	}
	footerCounter = 0;

	if (IsScavenge()) {
		CreateTimer(0.1, Timer_RemoveCountdown, .flags = TIMER_FLAG_NO_MAPCHANGE);
	}
	else L4D2_CTimerStart(L4D2CT_VersusStartTimer, 99999.0);
	
	if (isAutoStartMode)
	{
		expireTime = l4d_ready_autostart_wait.IntValue;
		CreateTimer(1.0, Timer_AutoStartHelper, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
}

public Action Timer_RemoveCountdown(Handle timer)
{
	RestartScavengeCountdown(99999.0, false);
}

public Action Timer_AutoStartHelper(Handle timer)
{
	if (GetSeriousClientCount(true) == 0)
	{
		// no player in game
		expireTime = l4d_ready_autostart_wait.IntValue;
		return Plugin_Continue;
	}
	
	if (IsAnyPlayerLoading())
	{
		if (expireTime > 0)
		{
			expireTime--;
			PrintHintTextToAll("%t", "AutoStartWaiting");
			return Plugin_Continue;
		}
	}
	
	CreateTimer(8.0, Timer_InitiateAutoStart, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

public Action Timer_InitiateAutoStart(Handle timer)
{
	InitiateAutoStart();
}

void InitiateAutoStart(bool real = true)
{
	if (!real)
	{
		inAutoStart = false;
		autoStartTimer = null;
		return;
	}
	
	if (autoStartTimer == null)
	{
		PrintHintTextToAll("%t", "InitiateAutoStart");
		inAutoStart = true;
		autoStartDelay = l4d_ready_autostart_delay.IntValue;
		autoStartTimer = CreateTimer(1.0, AutoStartDelay_Timer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
}

public Action AutoStartDelay_Timer(Handle timer)
{
	if (autoStartDelay == 0)
	{
		InitiateLiveCountdown();
		autoStartTimer = null;
		inAutoStart = false;
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("%t", "AutoStartCountdown", autoStartDelay);
		if (l4d_ready_enable_sound.BoolValue)
		{
			EmitSoundToAll(autostartSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		}
		autoStartDelay--;
	}
	return Plugin_Continue;
}

void InitiateLive(bool real = true)
{
	inReadyUp = false;
	inLiveCountdown = false;

	SetTeamFrozen(L4D2Team_Survivor, false);

	sv_infinite_primary_ammo.Flags &= ~FCVAR_NOTIFY;
	sv_infinite_primary_ammo.SetBool(false);
	sv_infinite_primary_ammo.Flags |= FCVAR_NOTIFY;
	director_no_specials.SetBool(false);
	god.Flags &= ~FCVAR_NOTIFY;
	god.SetBool(false);
	god.Flags |= FCVAR_NOTIFY;
	sb_stop.SetBool(false);
	
	if (IsScavenge()) {
		RestartScavengeCountdown(scavenge_round_setup_time.FloatValue, true);
	}
	else L4D2_CTimerStart(L4D2CT_VersusStartTimer, 60.0);

	for (int i = 0; i < 4; i++)
	{
		GameRules_SetProp("m_iVersusDistancePerSurvivor", 0, _,
				i + 4 * GameRules_GetProp("m_bAreTeamsFlipped"));
	}

	if (real)
	{
		Call_StartForward(liveForward);
		Call_Finish();
	}
	else
	{
		// TIMER_FLAG_NO_MAPCHANGE doesn't free the timer handle.
		// So here manually clear it to prevent issues.
		if (readyCountdownTimer != null) readyCountdownTimer = null;
	}
}

void InitiateLiveCountdown()
{
	if (readyCountdownTimer == null)
	{
		ReturnTeamToSaferoom(L4D2Team_Survivor);
		SetTeamFrozen(L4D2Team_Survivor, true);
		PrintHintTextToAll("%t", "LiveCountdownBegin");
		inLiveCountdown = true;
		readyDelay = l4d_ready_delay.IntValue;
		readyCountdownTimer = CreateTimer(1.0, ReadyCountdownDelay_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ReadyCountdownDelay_Timer(Handle timer)
{
	if (readyDelay == 0)
	{
		PrintHintTextToAll("%t", "RoundIsLive");
		InitiateLive();
		readyCountdownTimer = null;
		if (l4d_ready_enable_sound.BoolValue)
		{
			if (l4d_ready_chuckle.BoolValue)
			{
				EmitSoundToAll(chuckleSound[GetRandomInt(0,MAX_SOUNDS-1)]);
			}
			else { EmitSoundToAll(liveSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5); }
		}
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("%t", "LiveCountdown", readyDelay);
		if (l4d_ready_enable_sound.BoolValue)
		{
			EmitSoundToAll(countdownSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		}
		readyDelay--;
	}
	return Plugin_Continue;
}

bool CheckFullReady()
{
	int readyCount = 0;
	bool foundSurv = false, foundInf = false;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (IsPlayer(client) && isPlayerReady[client])
			{
				readyCount++;
				GetClientTeam(client) == L4D2Team_Survivor ? (foundSurv = true) : (foundInf = true);
			}
		}
	}
	
	if (l4d_ready_unbalanced_start.BoolValue)
	{
		return foundSurv
			&& foundInf
			&& readyCount >= GetTeamHumanCount(L4D2Team_Survivor) + GetTeamHumanCount(L4D2Team_Infected);
	}
	else
	{
		return readyCount >= GetConVarInt(survivor_limit) + GetConVarInt(z_max_player_zombies);
	}
}

void CancelFullReady(int client, disruptType type)
{
	if (readyCountdownTimer != null)
	{
		if (bSkipWarp)
		{
			SetTeamFrozen(L4D2Team_Survivor, true);
		}
		else
		{
			SetTeamFrozen(L4D2Team_Survivor, GetConVarBool(l4d_ready_survivor_freeze));
			if (type == teamShuffle) SetClientFrozen(client, false);
		}
		inLiveCountdown = false;
		KillTimer(readyCountdownTimer);
		readyCountdownTimer = null;
		PrintHintTextToAll("%t", "LiveCountdownCancelled");
		
		switch (type)
		{
			case readyStatus: CPrintToChatAllEx(client, "{default}[{green}!{default}] %t", "DisruptReadyStatus", client);
			case teamShuffle: CPrintToChatAllEx(client, "{default}[{green}!{default}] %t", "DisruptTeamShuffle", client);
			case playerDisconn: CPrintToChatAllEx(client, "{default}[{green}!{default}] %t", "DisruptPlayerDisc", client);
		}
	}
}

void ReturnPlayerToSaferoom(int client, bool flagsSet = true)
{
	int warp_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		L4D_ReviveSurvivor(client);
	}

	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
	}
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
}

void ReturnTeamToSaferoom(int team)
{
	int warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team)
		{
			ReturnPlayerToSaferoom(client, true);
		}
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
}

void SetTeamFrozen(int team, bool freezeStatus)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team)
		{
			SetClientFrozen(client, freezeStatus);
		}
	}
}

void SetEngineTime(int client)
{
	g_fButtonTime[client] = GetEngineTime();
}

bool IsScavenge()
{
	static ConVar mp_gamemode;
	
	if (mp_gamemode == null)
	{
		mp_gamemode = FindConVar("mp_gamemode");
	}
	
	char sGamemode[16];
	mp_gamemode.GetString(sGamemode, sizeof(sGamemode));
	
	return strcmp(sGamemode, "scavenge") == 0;
}

void RestartScavengeCountdown(float duration, bool startOn)
{
	CTimer_Invalidate(L4D2Direct_GetScavengeRoundSetupTimer());
	CTimer_Start(L4D2Direct_GetScavengeRoundSetupTimer(), duration);
	ToggleCountdownPanel(startOn);
}

void ToggleCountdownPanel(bool onoff, int client = 0)
{
	if (client > 0 && IsClientInGame(client)) ShowVGUIPanel(client, "ready_countdown", _, onoff);
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				ShowVGUIPanel(i, "ready_countdown", _, onoff);
			}
		}
	}
}


// ========================
// :D
// ========================

void DoSecrets(int client)
{
	if (GetClientTeam(client) == L4D2Team_Survivor && !blockSecretSpam[client])
	{
		int particle = CreateEntityByName("info_particle_system");
		float pos[3];
		GetClientAbsOrigin(client, pos);
		pos[2] += 80;
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", "achieved");
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(5.0, killParticle, particle, TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll("/level/gnomeftw.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		CreateTimer(2.5, killSound);
		blockSecretSpam[client] = CreateTimer(5.0, SecretSpamDelay, client);
	}
	PrintCenterTextAll("\x42\x4f\x4e\x45\x53\x41\x57\x20\x49\x53\x20\x52\x45\x41\x44\x59\x21");
}

public Action SecretSpamDelay(Handle timer, int client)
{
	blockSecretSpam[client] = null;
}

public Action killParticle(Handle timer, int entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public Action killSound(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	if (IsClientInGame(i) && !IsFakeClient(i))
	StopSound(i, SNDCHAN_AUTO, SECRET_SOUND);
}



// ========================
//  Natives
// ========================

public int Native_AddStringToReadyFooter(Handle plugin, int numParams)
{
	char footer[MAX_FOOTER_LEN];
	GetNativeString(1, footer, sizeof(footer));
	if (footerCounter < MAX_FOOTERS)
	{
		int len = strlen(footer);
		if (0 < len < MAX_FOOTER_LEN && !IsEmptyString(footer, len))
		{
			strcopy(readyFooter[footerCounter], MAX_FOOTER_LEN, footer);
			footerCounter++;
			return footerCounter-1;
		}
	}
	return -1;
}

public int Native_EditFooterStringAtIndex(Handle plugin, int numParams)
{
	char newString[MAX_FOOTER_LEN];
	GetNativeString(2, newString, sizeof(newString));
	int index = GetNativeCell(1);
	
	if (footerCounter < MAX_FOOTERS)
	{
		if (strlen(newString) < MAX_FOOTER_LEN)
		{
			readyFooter[index] = newString;
			return true;
		}
	}
	return false;
}

public int Native_FindIndexOfFooterString(Handle plugin, int numParams)
{
	char stringToSearchFor[MAX_FOOTER_LEN];
	GetNativeString(1, stringToSearchFor, sizeof(stringToSearchFor));
	
	for (int i = 0; i < footerCounter; i++){
		if (strlen(readyFooter[i]) == 0) continue;
		
		if (StrContains(readyFooter[i], stringToSearchFor, false) > -1){
			return i;
		}
	}
	
	return -1;
}

public int Native_GetFooterStringAtIndex(Handle plugin, int numParams)
{
	int index = GetNativeCell(1), maxlen = GetNativeCell(3);
	char buffer[MAX_FOOTER_LEN];
	
	if (index < MAX_FOOTERS) {
		strcopy(buffer, sizeof(buffer), readyFooter[index]);
	}
	
	SetNativeString(2, buffer, maxlen, true);
}

public int Native_IsInReady(Handle plugin, int numParams)
{
	return inReadyUp;
}

public int Native_IsClientCaster(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return IsClientCaster(client);
}

public int Native_IsIDCaster(Handle plugin, int numParams)
{
	char buffer[64];
	GetNativeString(1, buffer, sizeof(buffer));
	return IsIDCaster(buffer);
}



// ========================
//  Stocks
// ========================

bool IsEmptyString(const char[] str, int length)
{
	for (int i = 0; i < length; ++i)
	{
		if (!IsCharSpace(str[i]))
		{
			switch (str[i])
			{
				case '\r', '\n': continue;
				
				default: return false;
			}
		}
	}
	return true;
}

bool IsClientCaster(int client)
{
	char buffer[64];
	return GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer)) && IsIDCaster(buffer);
}

bool IsIDCaster(const char[] AuthID)
{
	bool dummy;
	return GetTrieValue(casterTrie, AuthID, dummy);
}

stock bool IsAnyPlayerLoading()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && (!IsClientInGame(i) || GetClientTeam(i) == L4D2Team_None))
		{
			return true;
		}
	}
	return false;
}

stock int GetSeriousClientCount(bool inGame = false)
{
	int clients = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if ((inGame ? IsClientInGame(i) : IsClientConnected(i)))
		{
			if (!IsFakeClient(i)) clients++;
		}
	}
	
	return clients;
}

stock int SetClientFrozen(int client, bool freeze)
{
	SetEntityMoveType(client, freeze ? MOVETYPE_NONE : (GetClientTeam(client) == L4D2Team_Spectator ? MOVETYPE_NOCLIP : MOVETYPE_WALK));
}

stock bool IsPlayerAfk(int client)
{
	return GetEngineTime() - g_fButtonTime[client] > 15.0;
}

stock bool IsPlayer(int client)
{
	int team = GetClientTeam(client);
	return (team == L4D2Team_Survivor || team == L4D2Team_Infected);
}

stock int GetTeamHumanCount(int team)
{
	int humans = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == team)
		{
			humans++;
		}
	}
	
	return humans;
}