#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include <colors>
#include <l4d2_changelevel>

#pragma newdecls required
#pragma semicolon 1

#define MAX_CAMPAIGN_LIMIT 64

public Plugin myinfo =
{
	name = "Vote Custom Campaign",
	author = "Forgetest",
	description = "ez",
	version = "1.0",
	url = ""
};

/**
 * Globals
 */
int g_iCount;
char g_sMapinfo[MAX_CAMPAIGN_LIMIT][256];
char g_sMapname[MAX_CAMPAIGN_LIMIT][256];
char votemapinfo[256];
char votemapname[256];

Handle g_hVoteMenu;
KeyValues g_kvCampaigns;

ConVar g_hMenuLeaveTime;
ConVar g_hVotePercent;
ConVar g_hPassPercent;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
	char game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2"))
	{
		SetFailState("<VCC> Enable only for left4dead2.");
	}
	
	RegConsoleCmd("sm_vcc", Command_VoteCampaign, "Show custom campaigns menu");

	g_hMenuLeaveTime = CreateConVar("vcc_menu_leavetime", "20", "After this time(second) the menu should leave.", FCVAR_NOTIFY);
	g_hVotePercent = CreateConVar("vcc_vote_percent", "0.60", "Votes reaching this percent of clients(no-spec) can a vote result.", FCVAR_NOTIFY);
	g_hPassPercent = CreateConVar("vcc_pass_percent", "0.60", "Approvals reaching this percent of votes can a vote pass.", FCVAR_NOTIFY);
	
	ParseCampaigns();
}

public void OnMapStart()
{
	ParseCampaigns();
}


/**
 * Commands
 */
public Action Command_VoteCampaign(int client, int args) 
{ 
	if (!IsClientValid(client)) { return Plugin_Handled; }
	
	Menu menu = new Menu(MapMenuHandler);
	menu.SetTitle( "▲ Vote Custom Campaigns <%d map%s>", g_iCount, ((g_iCount > 1) ? "s": "") );
	
	for (int i = 0; i < g_iCount; i++)
	{
		menu.AddItem(g_sMapinfo[i], g_sMapname[i]);
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}


/**
 * Menu Handlers
 */
public int MapMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if ( action == MenuAction_Select ) 
	{
		GetMenuItem(menu,
				itemNum,
				votemapinfo, sizeof(votemapinfo),
				_,
				votemapname, sizeof(votemapname));
				
		DisplayVoteMapsMenu(client);
	}
	else if ( action == MenuAction_End )
	{
		delete menu;
	}
}

void DisplayVoteMapsMenu(int client)
{
	if (GetClientTeam(client) == 1) // 1 -> Spectator
	{
		CPrintToChat(client, "<{olive}VCC{default}> {olive}Spectator {default}cannot vote.");
		return;
	}
	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(client, "<{olive}VCC{default}> There has been a vote {olive}in progress{default}.");
		return;
	}
	if (CheckBuiltinVoteDelay() > 0)
	{
		CPrintToChat(client, "<{olive}VCC{default}> Wait for another {olive}%ds {default}to call a vote.", CheckBuiltinVoteDelay());
		return;
	}
	
	g_hVoteMenu = CreateBuiltinVote(CallBack_VoteProgress, BuiltinVoteType_ChgCampaign, BuiltinVoteAction_Select|BuiltinVoteAction_Cancel|BuiltinVoteAction_End);
	
	//CPrintToChatAll("<{olive}VCC{default}> {default}Player {lightgreen}%N {default}called a vote for {olive}custom campaign", client, votemapname);
	SetBuiltinVoteArgument(g_hVoteMenu, votemapname);
	SetBuiltinVoteInitiator(g_hVoteMenu, client);
	
	SetBuiltinVoteResultCallback(g_hVoteMenu, CallBack_VoteResult);
	DisplayBuiltinVoteToAllNonSpectators(g_hVoteMenu, g_hMenuLeaveTime.IntValue);
	//FakeClientCommand(client, "Vote Yes");
}


/**
 * Menu CallBacks
 */
public int CallBack_VoteProgress(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	if (action == BuiltinVoteAction_Select)
	{
		switch (param2)
		{
			case 0: { PrintToConsoleAll_YA("<VCC> Player %N vote for the campaign change.", param1); }
			case 1: { PrintToConsoleAll_YA("<VCC> Player %N vote against the campaign change.", param1); }
		}
	}
	else if (action == BuiltinVoteAction_Cancel)
	{
		DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
	}
	else if (action == BuiltinVoteAction_End)
	{
		CloseHandle(g_hVoteMenu);
		g_hVoteMenu = null;
	}
}

public int CallBack_VoteResult(Handle vote, int num_votes, int num_clients, const client_info[][2], int num_items, const item_info[][2])
{
	if ( float(num_votes) / float(num_clients) < g_hVotePercent.FloatValue)
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_NotEnoughVotes);
		return;
	}
	
	int votey = 0;
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{ votey = item_info[i][BUILTINVOTEINFO_ITEM_VOTES]; }
	}
	
	if ( float(votey) / float(num_votes) >= g_hPassPercent.FloatValue )
	{
		CreateTimer(0.1, Timer_PrintCampaignChanging);
		CreateTimer(3.0, Timer_Changelevel);
		
		DisplayBuiltinVotePass2(vote, TRANSLATION_L4D_VOTE_CHANGECAMPAIGN_PASSED, votemapname);
	}
	else
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	}
}


/**
 * Timers
 */
public Action Timer_PrintCampaignChanging(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i))
		{
			CPrintToChat(i, "<{olive}VCC{default}> Map changing... -> {green}%s", votemapname);
		}
	}
}

public Action Timer_Changelevel(Handle timer)
{
	if (!L4D2_ChangeLevel(votemapinfo))
	{
		CPrintToChatAll("<{olive}VCC{default}> {red}Failed {default}to change map {green}%s(default)", votemapname);
	}
	
	votemapinfo = "";
	votemapname = "";
}


/**
 * Stocks
 */
bool IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
	{return true;} else {return false;}
}

void PrintToConsoleAll_YA(const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i)) { PrintToConsole(i, buffer); }
	}
}


/**
 * Misc
 */
void ParseCampaigns()
{
	delete g_kvCampaigns;
	g_kvCampaigns = CreateKeyValues("VoteCustomCampaigns");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/VoteCustomCampaigns.txt");

	if ( !FileToKeyValues(g_kvCampaigns, sPath) ) 
	{
		SetFailState("<VCC> File doesn't exist! (%s)", sPath);
		return;
	}
	
	if (g_kvCampaigns.GotoFirstSubKey())
	{
		for (int i = 0; i < MAX_CAMPAIGN_LIMIT; i++)
		{
			g_kvCampaigns.GetString("mapinfo", g_sMapinfo[i], sizeof(g_sMapinfo));
			g_kvCampaigns.GetString("mapname", g_sMapname[i], sizeof(g_sMapname));
			
			if ( !g_kvCampaigns.GotoNextKey() )
			{
				g_iCount = ++i;
				break;
			}
		}
	}
	
	LogMessage("<VCC> %d custom campaign%s loaded.", g_iCount, g_iCount > 1 ? "s" : "");
}

