#if defined _readyup_action_included
 #endinput
#endif
#define _readyup_action_included

#pragma semicolon 1
#pragma newdecls required

#include "readyup/forward.inc"
#include "readyup/player.inc"

enum AutoStartState
{
	AutoStartState_PreCheck,
	AutoStartState_Wait,
	AutoStartState_Countdown,
};

static bool s_inReadyUp, s_inLiveCountdown, s_isForceStart;
static int s_readyDelay, s_autoStartDelay;
static ReadyMode s_readyMode;
static Handle s_readyCountdownTimer, s_autoStartTimer;
static bool s_isPlayerReady[MAXPLAYERS+1], s_isTeamReady[ReadyTeam];
static AutoStartState s_autoStartState;
static Handle s_customReadyUpOwner;
static ConVar l4d_ready_delay, l4d_ready_force_extra, l4d_ready_autostart_delay, l4d_ready_autostart_wait;

methodmap ReadyManager
{
	public static void Init()
	{
		static bool s_bInit = false;
		if (s_bInit)
			return;
		
		l4d_ready_delay				= CreateConVar("l4d_ready_delay", "3", "Number of seconds to count down before the round goes live.", FCVAR_NOTIFY, true, 0.0);
		l4d_ready_force_extra		= CreateConVar("l4d_ready_force_extra", "2", "Number of seconds added to the duration of live count down.", FCVAR_NOTIFY, true, 0.0);
		l4d_ready_autostart_delay	= CreateConVar("l4d_ready_autostart_delay", "5", "Number of seconds to count down before auto-start kicks in.", FCVAR_NOTIFY, true, 0.0);
		l4d_ready_autostart_wait	= CreateConVar("l4d_ready_autostart_wait", "20", "Number of seconds to wait for connecting players before auto-start is forced.", FCVAR_NOTIFY, true, 0.0);
		
		s_bInit = true;
	}
	
	public static void Create(ReadyMode mode)
	{
		if (s_inReadyUp)
			return;
		
		EventDispatcher.OnReadyUpInitiatePre();
		
		s_readyMode = mode;
		s_inReadyUp = true;
		s_inLiveCountdown = false;
		s_isForceStart = false;
		
		s_readyCountdownTimer = null;
		s_autoStartTimer = null;
		
		InitiateReadyMode();
		
		EventDispatcher.OnReadyUpInitiate();
	}
	
	public static void Finish()
	{
		if (!s_inReadyUp)
			return;
		
		s_inReadyUp = false;
		s_inLiveCountdown = false;
		s_isForceStart = false;
		
		delete s_readyCountdownTimer;
		delete s_autoStartTimer;
		
		s_customReadyUpOwner = null;
		EventDispatcher.SetRecipient(null);
		
		EventDispatcher.OnReadyUpFinished();
	}
	
	public static bool AdminForceStart(int client)
	{
		if (!s_inReadyUp)
			return false;
		
		if (s_readyMode == ReadyMode_AutoStart)
			return true;
		
		s_isForceStart = true;
		InitiateLiveCountdown();
		EventDispatcher.OnAdminForceStart(client);
		return true;
	}
	
	public static bool PlayerReady(int client)
	{
		if (!s_inReadyUp)
			return false;
		
		if (!IsPlayer(client))
			return false;
		
		switch (s_readyMode)
		{
			case ReadyMode_PlayerReady:
			{
				if (SetPlayerReady(client, true) == false)
				{
					EventDispatcher.OnPlayerReady(client);
				}
			}
			case ReadyMode_TeamReady:
			{
				ReadyTeam team = GetPlayerTeam(client);
				if (team == ReadyTeam_Invalid)
					return false;
				
				if (SetTeamReady(team, true) == false)
				{
					EventDispatcher.OnTeamReady(team, client);
				}
			}
		}
		
		if (CheckFullReady())
		{
			InitiateLiveCountdown();
		}
		
		return true;
	}
	
	public static bool PlayerUnready(int client, DisruptType type)
	{
		if (!s_inReadyUp)
			return false;
		
		if (!IsPlayer(client) && !IsAdmin(client))
			return false;
		
		switch (s_readyMode)
		{
			case ReadyMode_PlayerReady:
			{
				if (IsPlayer(client) && SetPlayerReady(client, false) == true)
				{
					EventDispatcher.OnPlayerUnready(client);
				}
			}
			case ReadyMode_TeamReady:
			{
				ReadyTeam team = GetPlayerTeam(client);
				if (team != ReadyTeam_Invalid)
				{
					if (SetTeamReady(team, false) == true)
					{
						EventDispatcher.OnTeamUnready(team, client);
					}
				}
				else if (!IsAdmin(client))
				{
					return false;
				}
			}
		}
		
		if (s_isForceStart)
		{
			if (!IsAdmin(client) || type != readyStatus)
				return true;
			
			type = adminAbort;
			s_isForceStart = false;
		}
		
		CancelFullReady(client, type);
		
		return true;
	}
	
	public static bool IsCustomReadyUp()
	{
		return s_customReadyUpOwner != null;
	}
	
	public static Handle GetCustomReadyUpOwner()
	{
		return s_customReadyUpOwner;
	}
	
	public static bool SetCustomReadyUpOwner(Handle plugin)
	{
		if (s_inReadyUp)
			return false;
		
		s_customReadyUpOwner = plugin;
		EventDispatcher.SetRecipient(plugin);
		
		return true;
	}
	
	public static bool InReadyUp()
	{
		return s_inReadyUp;
	}
	
	public static bool InLiveCountdown()
	{
		return s_inLiveCountdown;
	}
	
	public static ReadyMode GetReadyMode()
	{
		return s_readyMode;
	}
	
	public static bool IsPlayerReady(int client)
	{
		if (s_readyMode == ReadyMode_PlayerReady)
			return s_isPlayerReady[client];
		
		return false;
	}
	
	public static bool IsTeamReady(ReadyTeam team)
	{
		if (s_readyMode == ReadyMode_TeamReady)
			return s_isTeamReady[team];
		
		return false;
	}
}

static void InitiateReadyMode()
{
	ResetPlayerReady();
	ResetTeamReady();
	
	if (s_readyMode == ReadyMode_AutoStart)
	{
		InitiateAutoStart();
	}
}

static void InitiateAutoStart()
{
	if (s_autoStartTimer == null)
	{
		s_autoStartState = AutoStartState_PreCheck;
		s_autoStartTimer = CreateTimer(1.0, AutoStartDelay_Timer, _, TIMER_REPEAT);
	}
}

static Action AutoStartDelay_Timer(Handle timer)
{
	switch (s_autoStartState)
	{
		case AutoStartState_PreCheck:
		{
			if (CheckAutoStart())
			{
				s_autoStartState = AutoStartState_Wait;
				s_autoStartDelay = l4d_ready_autostart_wait.IntValue;
			}
			return Plugin_Continue;
		}
		
		case AutoStartState_Wait:
		{
			if (s_autoStartDelay > 0)
			{
				s_autoStartDelay--;
				return Plugin_Continue;
			}
			
			EventDispatcher.OnAutoStartCountdown();
			s_autoStartState = AutoStartState_Countdown;
			s_autoStartDelay = l4d_ready_autostart_delay.IntValue;
			return Plugin_Continue;
		}
		
		case AutoStartState_Countdown:
		{
			if (s_autoStartDelay == 0)
			{
				s_autoStartTimer = null;
				InitiateLiveCountdown();
				return Plugin_Stop;
			}
			
			EventDispatcher.OnAutoStartCountdownTick(s_autoStartDelay);
			s_autoStartDelay--;
			return Plugin_Continue;
		}
	}
	
	return Plugin_Stop;
}

static void InitiateLive()
{
	EventDispatcher.OnRoundIsLivePre();
	ReadyManager.Finish();
	EventDispatcher.OnRoundIsLive();
}

static void InitiateLiveCountdown()
{
	if (s_readyCountdownTimer == null)
	{
		EventDispatcher.OnRoundLiveCountdownPre();
		
		s_inLiveCountdown = true;
		s_readyDelay = l4d_ready_delay.IntValue + (s_isForceStart ? l4d_ready_force_extra.IntValue : 0);
		s_readyCountdownTimer = CreateTimer(1.0, ReadyCountdownDelay_Timer, _, TIMER_REPEAT);
	
		EventDispatcher.OnRoundLiveCountdown();
	}
}

static Action ReadyCountdownDelay_Timer(Handle timer)
{
	if (s_readyDelay == 0)
	{
		InitiateLive();
		s_readyCountdownTimer = null;
		return Plugin_Stop;
	}
	
	EventDispatcher.OnRoundLiveCountdownTick(s_readyDelay);
	
	s_readyDelay--;
	return Plugin_Continue;
}

static bool CheckAutoStart()
{
	bool ret = false;
	EventDispatcher.OnCheckAutoStart(ret);
	return ret;
}

static bool CheckFullReady()
{
	if (s_readyMode == ReadyMode_AutoStart)
		return false;
	
	bool ret = false;
	EventDispatcher.OnCheckFullReady(ret);
	return ret;
}

static void CancelFullReady(int client, DisruptType type)
{
	if (s_readyMode == ReadyMode_AutoStart)
		return;
	
	if (s_readyMode == ReadyMode_TeamReady)
	{
		if (type == teamShuffle || type == playerDisconn)
			return;
	}
	
	if (s_readyCountdownTimer != null)
	{
		s_inLiveCountdown = false;
		s_isForceStart = false;
		delete s_readyCountdownTimer;
		
		EventDispatcher.OnReadyCountdownCancelled(client, g_sDisruptReason[type]);
		EventDispatcher.OnReadyCountdownCancelled2(client, type);
	}
}

static void ResetPlayerReady()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		SetPlayerReady(i, false);
	}
}

static void ResetTeamReady()
{
	FOR_EACH_READY_TEAM(i)
	{
		SetTeamReady(i, false);
	}
}

static bool SetPlayerReady(int client, bool ready)
{
	bool prev = s_isPlayerReady[client];
	s_isPlayerReady[client] = ready;
	
	return prev;
}

static bool SetTeamReady(ReadyTeam team, bool ready)
{
	bool prev = s_isTeamReady[team];
	s_isTeamReady[team] = ready;
	
	return prev;
}

static ReadyTeam GetPlayerTeam(int client)
{
	switch (GetClientTeam(client))
	{
		case 2: { return ReadyTeam_Survivor; }
		case 3: { return ReadyTeam_Infected; }
	}
	
	return ReadyTeam_Invalid;
}
