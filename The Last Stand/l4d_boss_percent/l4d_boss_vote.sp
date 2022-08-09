#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <builtinvotes>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util_rounds>
#undef REQUIRE_PLUGIN
#include <readyup>
#include <l4d2_boss_percents>
#include <witch_and_tankifier>

#define PLUGIN_VERSION "3.3"

public Plugin myinfo =
{
	name = "[L4D2] Vote Boss",
	author = "Spoon, Forgetest",
	version = PLUGIN_VERSION,
	description = "Votin for boss change.",
	url = "https://github.com/spoon-l4d2"
};

GlobalForward
	g_forwardUpdateBosses;

ConVar
	g_hCvarBossVoting;
	
bool
	bv_bTank,
	bv_bWitch;

int
	bv_iTank,
	bv_iWitch;

#define TRANSLATION_FILE "l4d_boss_vote.phrases.txt"
void LoadPluginTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/" ... TRANSLATION_FILE);
	if (!FileExists(sPath))
	{
		SetFailState("Missing translations \"" ... TRANSLATION_FILE ... "\"");
	}
	LoadTranslations(TRANSLATION_FILE);
}

public void OnPluginStart()
{
	LoadPluginTranslations();
	
	g_forwardUpdateBosses = new GlobalForward("OnUpdateBosses", ET_Ignore, Param_Cell, Param_Cell);
	
	g_hCvarBossVoting = CreateConVar("l4d_boss_vote", "1", "Enable boss voting", FCVAR_NOTIFY, true, 0.0, true, 1.0); // Sets if boss voting is enabled or disabled
	
	RegConsoleCmd("sm_voteboss", VoteBossCmd); // Allows players to vote for custom boss spawns
	RegConsoleCmd("sm_bossvote", VoteBossCmd); // Allows players to vote for custom boss spawns
	
	RegAdminCmd("sm_ftank", ForceTankCommand, ADMFLAG_BAN);
	RegAdminCmd("sm_fwitch", ForceWitchCommand, ADMFLAG_BAN);
}

Action VoteBossCmd(int client, int args)
{
	if (!g_hCvarBossVoting.BoolValue)
		return Plugin_Continue;
	
	if (!IsInReady() || InSecondHalfOfRound())
	{
		CReplyToCommand(client, "%t", "VoteCheck_FirstHalfReadyUp");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) <= 1)
	{
		CReplyToCommand(client, "%t", "VoteCheck_NonPlayer");
		return Plugin_Handled;
	}
	if (!IsNewBuiltinVoteAllowed())
	{
		CReplyToCommand(client, "%t", "VoteCheck_VoteTimer", CheckBuiltinVoteDelay());
		return Plugin_Handled;
	}
	
	if (args != 2)
	{
		CReplyToCommand(client, "%t", "Usage_Format");
		CReplyToCommand(client, "%t", "Usage_Description");
		return Plugin_Handled;
	}
	
	// Get all non-spectating players
	int iNumPlayers;
	int[] iPlayers = new int[MaxClients];
	for (int i=1; i<=MaxClients; ++i)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) > 1)
		{
			iPlayers[iNumPlayers++] = i;
		}
	}
	
	bv_iTank = -1;
	bv_iWitch = -1;
	
	// Get Requested Boss Percents
	char bv_sTank[8];
	char bv_sWitch[8];
	
	GetCmdArg(1, bv_sTank, sizeof(bv_sTank));
	GetCmdArg(2, bv_sWitch, sizeof(bv_sWitch));
	
	bv_bTank = StringToIntEx2(bv_sTank, bv_iTank);
	bv_bWitch = StringToIntEx2(bv_sWitch, bv_iWitch);
	
	if (bv_iTank == 0) strcopy(bv_sTank, sizeof(bv_sTank), strDisabled());
	if (bv_iWitch == 0) strcopy(bv_sWitch, sizeof(bv_sWitch), strDisabled());
	
	// Check to make sure static bosses don't get changed
	if (IsStaticTankMap())
	{
		bv_bTank = false;
		CReplyToCommand(client, "%t", "ValidatePercent_StaticTank");
	}
	
	if (IsStaticWitchMap())
	{
		bv_bWitch = false;
		CReplyToCommand(client, "%t", "ValidatePercent_StaticWitch");
	}
	
	// Check if percent is within limits
	if (bv_bTank && !IsTankPercentValid(bv_iTank))
	{
		CReplyToCommand(client, "%t", "ValidatePercent_BannedTank");
		return Plugin_Handled;
	}
	
	if (bv_bWitch && !IsWitchPercentValid(bv_iWitch))
	{
		CReplyToCommand(client, "%t", "ValidatePercent_BannedWitch");
		return Plugin_Handled;
	}
	
	char bv_voteTitle[64];
	
	// Set vote title
	if (bv_bTank && bv_bWitch)	// Both Tank and Witch can be changed 
	{
		FormatEx(bv_voteTitle, sizeof(bv_voteTitle), "%T", "VoteTitle_Both", LANG_SERVER, bv_sTank, bv_sWitch);
	}
	else if (bv_bTank)	// Only Tank can be changed
	{
		FormatEx(bv_voteTitle, sizeof(bv_voteTitle), "%T", "VoteTitle_Tank", LANG_SERVER, bv_sTank);
	}
	else if (bv_bWitch) // Only Witch can be changed
	{
		FormatEx(bv_voteTitle, sizeof(bv_voteTitle), "%T", "VoteTitle_Witch", LANG_SERVER, bv_sWitch);
	}
	else // Neither can be changed... ok...
	{
		return Plugin_Handled;
	}
	
	// Start the vote!
	Handle bv_hVote = CreateBuiltinVote(BossVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(bv_hVote, bv_voteTitle);
	SetBuiltinVoteInitiator(bv_hVote, client);
	SetBuiltinVoteResultCallback(bv_hVote, BossVoteResultHandler);
	DisplayBuiltinVote(bv_hVote, iPlayers, iNumPlayers, FindConVar("sv_vote_timer_duration").IntValue);
	FakeClientCommand(client, "Vote Yes");
	
	return Plugin_Handled;
}

void BossVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

void BossVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				// One last ready-up check.
				if (!IsInReady()) {
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
					CPrintToChatAll("%t", "VoteCheck_FirstHalfReadyUp");
					return;
				}
				
				char bv_voteResult[64];
				
				if (bv_bTank && bv_bWitch)	// Both Tank and Witch can be changed 
				{
					FormatEx(bv_voteResult, sizeof(bv_voteResult), "%T", "VoteResult_SettingBoth", LANG_SERVER);
				}
				else if (bv_bTank)	// Only Tank can be changed -- Witch must be static
				{
					FormatEx(bv_voteResult, sizeof(bv_voteResult), "%T", "VoteResult_SettingTank", LANG_SERVER);
				}
				else if (bv_bWitch) // Only Witch can be changed -- Tank must be static
				{
					FormatEx(bv_voteResult, sizeof(bv_voteResult), "%T", "VoteResult_SettingWitch", LANG_SERVER);
				}
				
				DisplayBuiltinVotePass(vote, bv_voteResult);
				
				SetTankPercent(bv_iTank);
				SetWitchPercent(bv_iWitch);
				
				// Forward da message man :)
				Call_StartForward(g_forwardUpdateBosses);
				Call_PushCell(bv_iTank);
				Call_PushCell(bv_iWitch);
				Call_Finish();
				
				return;
			}
		}
	}
	
	// Vote Failed
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

/* ========================================================
// ==================== Admin Commands ====================
// ========================================================
 *
 * Where the admin commands for setting boss spawns will go
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

Action ForceTankCommand(int client, int args)
{
	if (!g_hCvarBossVoting.BoolValue)
		return Plugin_Continue;
	
	if (!IsInReady() || InSecondHalfOfRound())
	{
		CPrintToChat(client, "%t", "VoteCheck_FirstHalfReadyUp");
		return Plugin_Handled;
	}
	if (IsStaticTankMap())
	{
		CPrintToChat(client, "%t", "ValidatePercent_StaticTank");
		return Plugin_Handled;
	}
	
	// Get Requested Tank Percent
	char bv_sTank[8];
	GetCmdArg(1, bv_sTank, sizeof(bv_sTank));
	
	int p_iRequestedPercent;
	
	// Make sure the cmd argument is a number
	if (!StringToIntEx2(bv_sTank, p_iRequestedPercent))
	{
		return Plugin_Handled;
	}
	
	// Check if percent is within limits
	if (!IsTankPercentValid(p_iRequestedPercent))
	{
		CPrintToChat(client, "%t", "ValidatePercent_BannedTank");
		return Plugin_Handled;
	}
	
	// Set the boss
	SetTankPercent(p_iRequestedPercent);
	
	// Let everybody know
	CPrintToChatAll("%t", "ForceTank_Announce", p_iRequestedPercent, client);
	
	// Forward da message man :)
	Call_StartForward(g_forwardUpdateBosses);
	Call_PushCell(p_iRequestedPercent);
	Call_PushCell(-1);
	Call_Finish();
	
	return Plugin_Handled;
}

Action ForceWitchCommand(int client, int args)
{
	if (!g_hCvarBossVoting.BoolValue)
		return Plugin_Continue;
	
	if (!IsInReady() || InSecondHalfOfRound())
	{
		CPrintToChat(client, "%t", "VoteCheck_FirstHalfReadyUp");
		return Plugin_Handled;
	}
	if (IsStaticWitchMap())
	{
		CPrintToChat(client, "%t", "ValidatePercent_StaticWitch");
		return Plugin_Handled;
	}
	
	// Get Requested Tank Percent
	char bv_sWitch[8];
	GetCmdArg(1, bv_sWitch, sizeof(bv_sWitch));
	
	int p_iRequestedPercent;
	
	// Make sure the cmd argument is a number
	if (!StringToIntEx2(bv_sWitch, p_iRequestedPercent)) // Convert it to in int boy
	{
		return Plugin_Handled;
	}
	
	// Check if percent is within limits
	if (!IsWitchPercentValid(p_iRequestedPercent))
	{
		CPrintToChat(client, "%t", "ValidatePercent_BannedWitch");
		return Plugin_Handled;
	}
	
	// Set the boss
	SetWitchPercent(p_iRequestedPercent);
	
	// Let everybody know
	CPrintToChatAll("%t", "ForceWitch_Announce", p_iRequestedPercent, client);
	
	// Forward da message man :)
	Call_StartForward(g_forwardUpdateBosses);
	Call_PushCell(-1);
	Call_PushCell(p_iRequestedPercent);
	Call_Finish();
	
	return Plugin_Handled;
}

char[] strDisabled()
{
	static char str[32] = "";
	if (str[0] == '\0')
	{
		FormatEx(str, sizeof(str), "%T", "Disabled", LANG_SERVER);
	}
	return str;
}

bool StringToIntEx2(const char[] str, int &result, int nBase=10)
{
	int bytes = StringToIntEx(str, result, nBase);
	return bytes == strlen(str) && bytes > 0;
}