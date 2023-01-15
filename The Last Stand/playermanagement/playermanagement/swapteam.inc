#if defined l4d_pm_swapteam_inc_
	#endinput
#endif
#define l4d_pm_swapteam_inc_

static const int oppositeTeamMap[L4D2Team_Size] = {
	L4D2Team_None,
	L4D2Team_Spectator,
	L4D2Team_Infected,
	L4D2Team_Survivor
};

void InitSwapTeam()
{
	RegAdminCmd("sm_swap", Swap_Cmd, ADMFLAG_KICK, "sm_swap <player1> [player2] ... [playerN] - swap all listed players to opposite teams");
	RegAdminCmd("sm_swapto", SwapTo_Cmd, ADMFLAG_KICK, "sm_swapto [force] <teamnum> <player1> [player2] ... [playerN] - swap all listed players to <teamnum> (1,2, or 3)");
	RegAdminCmd("sm_swapteams", SwapTeams_Cmd, ADMFLAG_KICK, "sm_swapteams - swap the players between both teams");
}

static Action SwapTeams_Cmd(int client, int args)
{
	int[] pendingSwaps = new int[MaxClients+1];
	
	for (int cli = 1; cli <= MaxClients; cli++)
	{
		if (IsClientInGame(cli) && !IsFakeClient(cli))
		{
			int team = GetClientTeam(cli);
			if (team == L4D2Team_Infected || team == L4D2Team_Survivor)
			{
				pendingSwaps[cli] = oppositeTeamMap[team];
			}
		}
	}
	
	ApplySwaps(client, pendingSwaps, false);
	
	return Plugin_Handled;
}

static Action Swap_Cmd(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_swap <player1> <player2> ... <playerN>");
		return Plugin_Handled;
	}

	int[] pendingSwaps = new int[MaxClients+1];
	
	char argbuf[MAX_NAME_LENGTH], target_name[MAX_TARGET_LENGTH];
	int[] targets = new int[MaxClients+1];
	int target, targetCount;
	bool tn_is_ml;

	for (int i = 1; i <= args; i++)
	{
		GetCmdArg(i, argbuf, sizeof(argbuf));
		targetCount = ProcessTargetString(
				argbuf,
				client,
				targets,
				MaxClients+1,
				COMMAND_FILTER_NO_BOTS,
				target_name,
				sizeof(target_name),
				tn_is_ml);
		
		for (int j = 0; j < targetCount; j++)
		{
			target = targets[j];
			if(IsClientInGame(target))
			{
				pendingSwaps[target] = oppositeTeamMap[GetClientTeam(target)];
			}
		}
	}

	ApplySwaps(client, pendingSwaps, false);

	return Plugin_Handled;
}

static Action SwapTo_Cmd(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_swapto <teamnum> <player1> <player2> ... <playerN>\n%d = Spectators, %d = Survivors, %d = Infected", L4D2Team_Spectator, L4D2Team_Survivor, L4D2Team_Infected);
		ReplyToCommand(client, "[SM] Usage: sm_swapto force <teamnum> <player1> <player2> ... <playerN>\n%d = Spectators, %d = Survivors, %d = Infected", L4D2Team_Spectator, L4D2Team_Survivor, L4D2Team_Infected);
		return Plugin_Handled;
	}

	char argbuf[MAX_NAME_LENGTH];
	bool force = false;

	GetCmdArg(1, argbuf, sizeof(argbuf));
	if (StrEqual(argbuf, "force"))
	{
		force = true;
		GetCmdArg(2, argbuf, sizeof(argbuf));
	}

	int team = StringToInt(argbuf);
	if (team < L4D2Team_Spectator || team > L4D2Team_Infected)
	{
		ReplyToCommand(client, "[SM] Valid teams: %d = Spectators, %d = Survivors, %d = Infected", L4D2Team_Spectator, L4D2Team_Survivor, L4D2Team_Infected);
		return Plugin_Handled;
	}

	int[] pendingSwaps = new int[MaxClients+1];
	
	int[] targets = new int[MaxClients+1];
	int target, targetCount;
	char target_name[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	for (int i = force?3:2; i <= args; i++)
	{
		GetCmdArg(i, argbuf, sizeof(argbuf));
		targetCount = ProcessTargetString(
				argbuf,
				client,
				targets,
				MaxClients+1,
				COMMAND_FILTER_NO_BOTS,
				target_name,
				sizeof(target_name),
				tn_is_ml);
		
		for (int j = 0; j < targetCount; j++)
		{
			target = targets[j];
			if(IsClientInGame(target))
			{
				pendingSwaps[target] = team;
			}
		}
	}

	ApplySwaps(client, pendingSwaps, force);

	return Plugin_Handled;
}

void ApplySwaps(int sender, int[] pendingSwaps, bool force)
{
	/* Swap everyone to spec first so we know the correct number of slots on the teams */
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if (GetClientTeam(client) != pendingSwaps[client] && pendingSwaps[client] != L4D2Team_None)
			{
				ChangeClientTeamEx(client, L4D2Team_Spectator, true);
			}
		}
	}

	/* Now lets try to put them on teams */
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && pendingSwaps[client] != L4D2Team_None)
		{
			if (!ChangeClientTeamEx(client, pendingSwaps[client], force))
			{
				if (sender > 0)
				{
					CPrintToChatEx(sender, client, "%t", "SwapTeam_ReplyFailure", client);
				}
			}
		}
	}
}
