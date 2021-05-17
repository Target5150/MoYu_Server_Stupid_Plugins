#include <sourcemod>
#include <builtinvotes>

#undef REQUIRE_PLUGIN
#tryinclude <l4d2_changelevel>
#define REQUIRE_PLUGIN

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.3"

public Plugin myinfo =
{
	name = "Vote Custom Campaign",
	author = "Forgetest",
	description = "ez",
	version = PLUGIN_VERSION,
	url = ""
};

/**
 * Globals
 */
#define PLURAL(%0) ((%0) > 1 ? "s" : "")
#define CAMPAIGN_FILE "configs/VoteCustomCampaigns.txt"
 
ArrayList g_aCampaignList;

ConVar g_cVotePercent;
ConVar g_cPassPercent;

char g_sVoteCampaign[128];
char g_sVoteCampaignName[128];

/**
 * Pre-check
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch( GetEngineVersion() )
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			return APLRes_Success;
		}
		default:
		{
			strcopy(error, err_max, "Plugin supports only Left 4 Dead & 2!");
			return APLRes_SilentFailure;
		}
	}
}

/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
	g_cVotePercent =	CreateConVar(	"vcc_votes_percent",	"0.6",		"Votes more than this percent of non-spectator players can a vote result.", FCVAR_NOTIFY);
	g_cPassPercent =	CreateConVar(	"vcc_pass_percent",		"0.6",		"Approvals greater than this percent of votes can a vote pass.", FCVAR_NOTIFY);
	
	RegConsoleCmd("sm_vcc",		Command_VoteCampaign, "Show custom campaigns menu");
	RegConsoleCmd("sm_mapvote",	Command_VoteCampaign, "Show custom campaigns menu");
	
	RegAdminCmd("sm_vcc_reload", Command_ReloadCampaigns, ADMFLAG_CHANGEMAP, "Reload lists of custom campaigns");
	
	AutoExecConfig(true);
	
	g_aCampaignList = new ArrayList(ByteCountToCells(128));
	
	ParseCampaigns();
}

/**
 * Commands
 */
public Action Command_ReloadCampaigns(int client, int args)
{
	if( ParseCampaigns() ) {
		ReplyToCommand(client, "[VCC] Successfully reloaded custom campaign list.");
	} else {
		ReplyToCommand(client, "[VCC] Failed to reload custom campaign list. (See error logs)");
	}
}

public Action Command_VoteCampaign(int client, int args) 
{ 
	if( !client ) { return Plugin_Handled; }
	
	int arraysize = g_aCampaignList.Length;
	
	Menu menu = new Menu(MapMenuHandler);
	menu.SetTitle( "▲ Vote Custom Campaigns <%d map%s>", arraysize / 2, PLURAL(arraysize) );
	
	char sCode[128], sName[128];
	for( int i = 0; i < arraysize; i += 2 )
	{
		g_aCampaignList.GetString(i, sCode, sizeof sCode);
		g_aCampaignList.GetString(i + 1, sName, sizeof sName);
		menu.AddItem(sCode, sName);
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, 60);

	return Plugin_Handled;
}


/**
 * Menu Handlers
 */
public int MapMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if( action == MenuAction_Select ) 
	{
		GetMenuItem(menu,
				itemNum,
				g_sVoteCampaign, sizeof g_sVoteCampaign,
				_,
				g_sVoteCampaignName, sizeof g_sVoteCampaignName);
				
		DisplayVoteMapsMenu(client);
	}
	else if( action == MenuAction_End )
	{
		delete menu;
	}
}

void DisplayVoteMapsMenu(int client)
{
	if( GetClientTeam(client) == 1 ) // 1 -> Spectator
	{
		PrintToChat(client, "\x01<\x05VCC\x01> \x05Spectators \x01cannot vote.");
		return;
	}
	if( IsBuiltinVoteInProgress() )
	{
		PrintToChat(client, "\x01<\x05VCC\x01> There's a vote \x05in progress\x01.");
		return;
	}
	if( CheckBuiltinVoteDelay() > 0 )
	{
		PrintToChat(client, "\x01<\x05VCC\x01> Wait for \x04%ds \x01to call another vote.", CheckBuiltinVoteDelay());
		return;
	}
	
	Handle vote = CreateBuiltinVote(CampaignVoteHandler, BuiltinVoteType_ChgCampaign, BuiltinVoteAction_Select|BuiltinVoteAction_Cancel|BuiltinVoteAction_End);
	
	int total = 0;
	int[] players = new int[MaxClients];
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 1 )
			players[total++] = i;
	}
	
	SetBuiltinVoteArgument(vote, g_sVoteCampaignName);
	SetBuiltinVoteInitiator(vote, client);
	SetBuiltinVoteResultCallback(vote, CampaignVoteResult);
	
	DisplayBuiltinVote(vote, players, total, FindConVar("sv_vote_timer_duration").IntValue);
}


/**
 * Menu CallBacks
 */
public int CampaignVoteHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch( action )
	{
		case BuiltinVoteAction_Select:
		{
			switch( param2 )
			{
				case 0: PrintToConsoleAll("<VCC> Player %N vote against the campaign change.", param1);
				case 1: PrintToConsoleAll("<VCC> Player %N vote for the campaign change.", param1);
			}
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
		}
		case BuiltinVoteAction_End:
		{
			delete vote;
		}
	}
}

public int CampaignVoteResult(Handle vote, int num_votes, int num_clients, const client_info[][2], int num_items, const item_info[][2])
{
	if( (float(num_votes) / float(num_clients)) < g_cVotePercent.FloatValue )
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_NotEnoughVotes);
		return;
	}
	
	int votey = 0;
	for( int i = 0; i < num_items; i++ )
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{ votey = item_info[i][BUILTINVOTEINFO_ITEM_VOTES]; }
	}
	
	if( float(votey) / float(num_votes) >= g_cPassPercent.FloatValue )
	{
		DisplayBuiltinVotePass2(vote, TRANSLATION_L4D_VOTE_CHANGECAMPAIGN_PASSED, g_sVoteCampaignName);
		
		PrintToChatAll("\x01<\x05VCC\x01> Map changing... -> \x04%s", g_sVoteCampaignName);
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
public Action Timer_Changelevel(Handle timer)
{
	if( !IsMapValid(g_sVoteCampaign) )
	{
		PrintToChatAll("\x01<\x05VCC\x01> \x04Failed \x01to change map (\x03%s\x01)", g_sVoteCampaignName);
		return;
	}
	
	if( GetFeatureStatus(FeatureType_Native, "L4D2_ChangeLevel") == FeatureStatus_Available )
	{
		L4D2_ChangeLevel(g_sVoteCampaign);
	}
	else
	{
		ServerCommand("changelevel %s", g_sVoteCampaign);
	}
}



/**
 * Misc
 */
bool ParseCampaigns()
{
	if (g_aCampaignList) g_aCampaignList.Clear();
	
	KeyValues kv = new KeyValues("VoteCustomCampaigns");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CAMPAIGN_FILE);

	if ( !kv.ImportFromFile(sPath) )
	{
		LogMessage("<VCC> File doesn't exist! (%s)", sPath);
		return false;
	}
	if ( !kv.GotoFirstSubKey() )
	{
		LogMessage("<VCC> Failed to locate first sub key.");
		return false;
	}
	
	char buffer[128];
	do
	{
		kv.GetSectionName(buffer, sizeof buffer);
		g_aCampaignList.PushString(buffer);
		
		kv.GetString("name", buffer, sizeof buffer, "ERROR NOT FOUND!");
		g_aCampaignList.PushString(buffer);
	}
	while (kv.GotoNextKey());
	
	delete kv;
	return true;
}

