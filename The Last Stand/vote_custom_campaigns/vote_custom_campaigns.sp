#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include <colors>
#undef REQUIRE_PLUGIN
#include <l4d2_changelevel>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Vote Custom Campaign",
	author = "Forgetest",
	description = "ez",
	version = "1.1",
	url = ""
};

/**
 * Globals
 */
int g_iCount;

enum struct Campaign
{
	char code[128];
	char name[256];
} 

Campaign g_Campaign;
ArrayList g_CampaignList;

Handle g_hVoteMenu;

ConVar g_hMenuLeaveTime;
ConVar g_hVotePercent;
ConVar g_hPassPercent;

bool l4d2_changelevel;

/**
 * Pre-check
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin Support Only Left 4 Dead & 2!");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
	g_hMenuLeaveTime = CreateConVar("vcc_menu_leavetime",	"20",	"After this time(second) vote menu should leave.", FCVAR_NOTIFY);
	g_hVotePercent = CreateConVar(	"vcc_votes_percent",	"0.60",	"Votes reaching this percent of clients(no-spec) can a vote result.", FCVAR_NOTIFY);
	g_hPassPercent = CreateConVar(	"vcc_pass_percent",		"0.60",	"Approvals reaching this percent of votes can a vote pass.", FCVAR_NOTIFY);
	
	RegConsoleCmd("sm_mapvote",	Command_VoteCampaign, "Show custom campaigns menu");
	RegConsoleCmd("sm_vcc",		Command_VoteCampaign, "Show custom campaigns menu");
	
	RegAdminCmd("sm_rcc", Command_ReloadCampaigns, ADMFLAG_CHANGEMAP, "Reload lists of custom campaigns");
	
	ParseCampaigns();
}

public void OnMapStart()
{
	ParseCampaigns();
}

public void OnAllPluginsLoaded() { l4d2_changelevel = LibraryExists("l4d2_changelevel"); }
public void OnLibraryAdded(const char[] name) { if (StrEqual(name, "l4d2_changelevel")) l4d2_changelevel = true; }
public void OnLibraryRemoved(const char[] name) { if (StrEqual(name, "l4d2_changelevel")) l4d2_changelevel = false; }


/**
 * Commands
 */
public Action Command_ReloadCampaigns(int client, int args)
{
	if (ParseCampaigns()) {
		ReplyToCommand(client, "[SM] Successfully reloaded custom campaigns.");
	} else {
		ReplyToCommand(client, "[SM] Failed to reload custom campaigns. See error logs.");
	}
}

public Action Command_VoteCampaign(int client, int args) 
{ 
	if (!client) { return Plugin_Handled; }
	
	Menu menu = new Menu(MapMenuHandler);
	menu.SetTitle( "▲ Vote Custom Campaigns <%d map%s>", g_iCount, ((g_iCount > 1) ? "s": "") );
	
	Campaign campaign;
	for (int i = 0; i < g_CampaignList.Length; i++)
	{
		g_CampaignList.GetArray(i, campaign, sizeof(campaign));
		menu.AddItem(campaign.code, campaign.name);
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
				g_Campaign.code, sizeof(g_Campaign.code),
				_,
				g_Campaign.name, sizeof(g_Campaign.name));
				
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
		CPrintToChat(client, "<{olive}VCC{default}> Wait for another {blue}%ds {default}to call a vote.", CheckBuiltinVoteDelay());
		return;
	}
	
	g_hVoteMenu = CreateBuiltinVote(CallBack_VoteProgress, BuiltinVoteType_ChgCampaign, BuiltinVoteAction_Select|BuiltinVoteAction_Cancel|BuiltinVoteAction_End);
	
	int total = 0;
	int[] players = new int[MaxClients];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 1)
			players[total++] = i;
	}
	
	SetBuiltinVoteArgument(g_hVoteMenu, g_Campaign.name);
	SetBuiltinVoteInitiator(g_hVoteMenu, client);
	SetBuiltinVoteResultCallback(g_hVoteMenu, CallBack_VoteResult);
	
	DisplayBuiltinVote(g_hVoteMenu, players, total, g_hMenuLeaveTime.IntValue);
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
			case 0: PrintToConsoleAll("<VCC> Player %N vote for the campaign change.", param1);
			case 1: PrintToConsoleAll("<VCC> Player %N vote against the campaign change.", param1);
		}
	}
	else if (action == BuiltinVoteAction_Cancel)
	{
		DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
	}
	else if (action == BuiltinVoteAction_End)
	{
		delete g_hVoteMenu;
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
		DisplayBuiltinVotePass2(vote, TRANSLATION_L4D_VOTE_CHANGECAMPAIGN_PASSED, g_Campaign.name);
		
		CreateTimer(0.1, Timer_PrintChanging);
		CreateTimer(3.0, Timer_Changelevel);
	}
	else
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	}
}


/**
 * Timers
 */
public Action Timer_PrintChanging(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			CPrintToChat(i, "<{olive}VCC{default}> Map changing... -> {green}%s", g_Campaign.name);
		}
	}
}

public Action Timer_Changelevel(Handle timer)
{
	if (l4d2_changelevel)
	{
		if (!L4D2_ChangeLevel(g_Campaign.code))
		{
			CPrintToChatAll("<{olive}VCC{default}> {red}Failed {default}to change map {green}%s(default)", g_Campaign.name);
		}
	}
	else
	{
		ServerCommand("changelevel %s", g_Campaign.code);
	}
	
	strcopy(g_Campaign.code, sizeof(g_Campaign.code), "");
	strcopy(g_Campaign.name, sizeof(g_Campaign.name), "");
}



/**
 * Misc
 */
bool ParseCampaigns()
{
	g_iCount = 0;
	strcopy(g_Campaign.code, sizeof(g_Campaign.code), "");
	strcopy(g_Campaign.name, sizeof(g_Campaign.name), "");
	
	delete g_CampaignList;
	g_CampaignList = new ArrayList(sizeof(Campaign));
	
	KeyValues kv = new KeyValues("VoteCustomCampaigns");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/VoteCustomCampaigns.txt");

	if ( !kv.ImportFromFile(sPath) ) 
	{
		LogError("<VCC> File doesn't exist! (%s)", sPath);
		return false;
	}
	if ( !kv.GotoFirstSubKey() )
	{
		LogError("<VCC> Failed to locate first key.");
		return false;
	}
	
	Campaign campaign;
	do
	{
		kv.GetString("mapinfo", campaign.code, sizeof(campaign.code));
		kv.GetString("mapname", campaign.name, sizeof(campaign.name));
		
		g_CampaignList.PushArray(campaign, sizeof(campaign)) >= 0 ? ++g_iCount : 0;
	}
	while (kv.GotoNextKey());
	
	delete kv;
	
	return true;
}

