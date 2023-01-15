#if defined l4d_pm_jointeam_inc_
	#endinput
#endif
#define l4d_pm_jointeam_inc_

static ConVar 
	l4d_pm_team_jointimer;

static float 
	nextSwitchTime[MAXPLAYERS+1] = {-1.0, ...};

void InitJoinTeam()
{
	l4d_pm_team_jointimer = CreateConVar("l4d_pm_team_jointimer", "0.0", "Block players switching team too fast", FCVAR_SPONLY, true, 0.0);
	
	AddCommandListener(TeamChange_Listener, "jointeam");
	
	HookEvent("player_connect_full", Event_PlayerConnectFull);
}

static void Event_PlayerConnectFull(Event event, const char[] name, bool dontBroadcast)
{
	nextSwitchTime[GetClientOfUserId(event.GetInt("userid"))] = -1.0;
}

static Action TeamChange_Listener(int client, const char[] command, int argc)
{
	// Invalid 
	if (argc < 1)
		return Plugin_Continue;
	
	if (!client || !IsClientInGame(client)) 
		return Plugin_Continue;
	
	if (IsFakeClient(client))
		return Plugin_Continue;
	
	// Block Jockey from switching team.
	if (GetClientTeam(client) == L4D2Team_Infected
	  && GetInfectedClass(client) == L4D2Infected_Jockey
	  && GetEntProp(client, Prop_Send, "m_jockeyVictim") != -1)
		return Plugin_Stop;
	
	if (nextSwitchTime[client] != -1.0)
	{
		float flRemainingTime = nextSwitchTime[client] - GetGameTime();
		if (flRemainingTime > 0.0)
		{
			CPrintToChat(client, "%t", "JoinTeam_Cooldown", flRemainingTime);
			return Plugin_Stop;
		}
	}
	
	nextSwitchTime[client] = GetGameTime() + l4d_pm_team_jointimer.FloatValue;
	
	char buffer[16];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (buffer[0] == '2' || strcmp(buffer, "Survivor", false) == 0)
	{
		if (FindAliveSurvivorBot() == -1)
		{
			ChangeClientTeamEx(client, L4D2Team_Survivor, false);
			
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}
