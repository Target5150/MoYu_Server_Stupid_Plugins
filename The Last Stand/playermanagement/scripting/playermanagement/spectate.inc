#if defined l4d_pm_spectate_inc_
	#endinput
#endif
#define l4d_pm_spectate_inc_

static bool 
	blockVotes[MAXPLAYERS+1];

static float 
	lastSpectateTime[MAXPLAYERS+1] = { -1.0, ... };

static ConVar 
	l4d_pm_supress_spectate;
	
void InitSpectate()
{
	l4d_pm_supress_spectate = CreateConVar("l4d_pm_supress_spectate", "0", "Don't print messages when players spectate", FCVAR_SPONLY, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_spectate", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_spec", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_s", Spectate_Cmd, "Moves you to the spectator team");
	
	HookEvent("player_connect_full", Event_PlayerConnectFull);
}

static void Event_PlayerConnectFull(Event event, const char[] name, bool dontBroadcast)
{
	lastSpectateTime[GetClientOfUserId(event.GetInt("userid"))] = -1.0;
}

static bool ValidateSpectate(int client)
{
	switch (GetClientTeam(client))
	{
	case L4D2Team_Survivor:
		{
			bool isAllowed = true;
			
			if (L4D_IsPlayerIncapacitated(client))
			{
				int queuedPummelAttacker = L4D2_GetQueuedPummelAttacker(client);
				if (queuedPummelAttacker != -1 && L4D2_IsInQueuedPummel(queuedPummelAttacker))
					isAllowed = false;
			}
			else if (L4D2_GetInfectedAttacker(client) != -1)
			{
				isAllowed = false;
			}
			
			if (!isAllowed)
				CPrintToChat(client, "%t", "Disallowed_Spectate_Capped");
			
			return isAllowed;
		}
	
	case L4D2Team_Infected:
		{
			bool isAllowed = true;
			
			if (GetInfectedClass(client) == L4D2Infected_Tank)
			{
				isAllowed = !IsPlayerAlive(client);
			}
			
			if (!isAllowed) { }
			
			return isAllowed;
		}
	
	case L4D2Team_Spectator:
		{
			return true;
		}
	}
	
	return false;
}

static Action Spectate_Cmd(int client, int args)
{
	if (!client || !IsClientInGame(client))
		return Plugin_Continue;
	
	if (!ValidateSpectate(client))
		return Plugin_Handled;
	
	int team = GetClientTeam(client);
	if (team == L4D2Team_Spectator)
	{
		ChangeClientTeamEx(client, L4D2Team_Infected, true);
		L4D_State_Transition(client, STATE_DEATH_ANIM);
		
		blockVotes[client] = true;
		ToggleCommandListener(true);
		
		DataPack dp = new DataPack();
		dp.WriteCell(GetClientUserId(client));
		dp.WriteCell(client);
		RequestFrame(OnFrame_Respectate, dp);
	}
	else
	{
		ChangeClientTeamEx(client, L4D2Team_Spectator, true);
	}
	
	if (!l4d_pm_supress_spectate.BoolValue && team != L4D2Team_Spectator && GetGameTime() - lastSpectateTime[client] > 3.0)
	{
		CPrintToChatAllEx(client, "%t", "Announce_Spectate", client);
	}

	lastSpectateTime[client] = GetGameTime();
	
	return Plugin_Handled;
}

static void OnFrame_Respectate(DataPack dp)
{
	int userid, client;
	
	dp.Reset();
	userid = dp.ReadCell(), client = dp.ReadCell();
	
	if (GetClientOfUserId(userid) == client && IsClientInGame(client)) 
	{
		ChangeClientTeamEx(client, L4D2Team_Spectator, true);
	}
	
	blockVotes[client] = false;
	ToggleCommandListener(false);

	delete dp;
}

Action CmdListener_Global(int client, const char[] command, int argc)
{
	return blockVotes[client] ? Plugin_Handled : Plugin_Continue;
}

static void ToggleCommandListener(bool isEnable)
{
	static bool hasEnabled = false;
	
	if (isEnable == hasEnabled)
		return;
	
	if (isEnable)
		AddCommandListener(CmdListener_Global);
	else
		RemoveCommandListener(CmdListener_Global);
	
	hasEnabled = isEnable;
}
