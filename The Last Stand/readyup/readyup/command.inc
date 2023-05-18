#if defined _readyup_command_included
 #endinput
#endif
#define _readyup_command_included

#pragma semicolon 1
#pragma newdecls required

void SetupCommands()
{
	// Ready Commands
	RegConsoleCmd("sm_ready",			Ready_Cmd, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_r",				Ready_Cmd, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_toggleready",		ToggleReady_Cmd, "Toggle your ready status");
	RegConsoleCmd("sm_unready",			Unready_Cmd, "Mark yourself as not ready if you have set yourself as ready");
	RegConsoleCmd("sm_nr",				Unready_Cmd, "Mark yourself as not ready if you have set yourself as ready");
	
	// Admin Commands
	RegAdminCmd("sm_forcestart",		ForceStart_Cmd, ADMFLAG_BAN, "Forces the round to start regardless of player ready status.");
	RegAdminCmd("sm_fs",				ForceStart_Cmd, ADMFLAG_BAN, "Forces the round to start regardless of player ready status.");

	// Player Commands
	RegConsoleCmd("sm_hide",			Hide_Cmd, "Hides the ready-up panel so other menus can be seen");
	RegConsoleCmd("sm_show",			Show_Cmd, "Shows a hidden ready-up panel");
	RegConsoleCmd("sm_return",			Return_Cmd, "Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
}

void ToggleCommandListeners(bool hook)
{
	static bool hooked = false;
	if (hooked && !hook)
	{
		RemoveCommandListener(Vote_Callback, "Vote");
		hooked = false;
	}
	else if (!hooked && hook)
	{
		AddCommandListener(Vote_Callback, "Vote");
		hooked = true;
	}
}

// ========================
//  Command Listener
// ========================

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	SetButtonTime(client);
	return Plugin_Continue;
}

static Action Vote_Callback(int client, const char[] command, int argc)
{
	// Fast ready / unready through default keybinds for voting
	if (!client) return Plugin_Continue;
	if (BuiltinVote_IsVoteInProgress() && IsClientInBuiltinVotePool(client)) return Plugin_Continue;
	
	if (Game_IsVoteInProgress())
	{
		int voteteam = Game_GetVoteTeam();
		if (voteteam == -1 || voteteam == GetClientTeam(client))
		{
			return Plugin_Continue;
		}
	}
	
	char sArg[8];
	GetCmdArg(1, sArg, sizeof(sArg));
	if (strcmp(sArg, "Yes", false) == 0)
		ReadyManager.PlayerReady(client);
	else if (strcmp(sArg, "No", false) == 0)
		ReadyManager.PlayerUnready(client, readyStatus);

	return Plugin_Continue;
}

// ========================
//  Ready Commands
// ========================

Action Ready_Cmd(int client, int args)
{
	if (!client)
		return Plugin_Continue;
	
	if (!ReadyManager.InReadyUp())
		return Plugin_Continue;
	
	return ReadyManager.PlayerReady(client) ? Plugin_Handled : Plugin_Continue;
}

Action Unready_Cmd(int client, int args)
{
	if (!client)
		return Plugin_Continue;
	
	if (!ReadyManager.InReadyUp())
		return Plugin_Continue;
	
	return ReadyManager.PlayerUnready(client, readyStatus) ? Plugin_Handled : Plugin_Continue;
}

Action ToggleReady_Cmd(int client, int args)
{
	if (!ReadyManager.InReadyUp())
		return Plugin_Continue;
	
	return ReadyManager.IsPlayerReady(client) ? Unready_Cmd(client, 0) : Ready_Cmd(client, 0);
}

// ========================
//  Admin Commands
// ========================

Action ForceStart_Cmd(int client, int args)
{
	if (!client)
		return Plugin_Continue;
	
	if (!ReadyManager.InReadyUp())
		return Plugin_Continue;
	
	return ReadyManager.AdminForceStart(client) ? Plugin_Handled : Plugin_Continue;
}

// ========================
//  Player Commands
// ========================

Action Hide_Cmd(int client, int args)
{
	if (ReadyPanel.IsActive())
	{
		ReadyPanel.SetHiddenTo(client, true);
		CPrintToChat(client, "%t", "PanelHide");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action Show_Cmd(int client, int args)
{
	if (ReadyPanel.IsActive())
	{
		ReadyPanel.SetHiddenTo(client, false);
		CPrintToChat(client, "%t", "PanelShow");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action Return_Cmd(int client, int args)
{
	if (ReadyManager.InReadyUp()
			&& !ReadyManager.IsCustomReadyUp()
			&& client > 0
			&& GetClientTeam(client) == L4D2Team_Survivor)
	{
		ReturnPlayerToSaferoom(client, false);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
