#include <sourcemod>
#include <builtinvotes>

#undef REQUIRE_PLUGIN
#tryinclude <l4d2_changelevel>
#include <l4d2_mission_manager>
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
	
	g_aCampaignList = new ArrayList();
}

public void OnLMMUpdateList()
{
	ParseCampaigns();
}

public void OnConfigsExecuted()
{
	ParseCampaigns();
}


/**
 * Commands
 */
Action Command_ReloadCampaigns(int client, int args)
{
	if( ParseCampaigns() ) {
		ReplyToCommand(client, "[VCC] Successfully reloaded custom campaign list.");
	} else {
		ReplyToCommand(client, "[VCC] Failed to reload custom campaign list. (See error logs)");
	}
	
	return Plugin_Handled;
}

Action Command_VoteCampaign(int client, int args) 
{
	if( !client ) { return Plugin_Handled; }
	
	int arraysize = g_aCampaignList.Length;
	if( !arraysize ) { return Plugin_Handled; }
	
	Menu menu = new Menu(MapMenuHandler);
	menu.SetTitle( "▲ Vote Custom Campaigns <%d map%s>", arraysize, PLURAL(arraysize) );
	
	LMM_GAMEMODE gamemode = LMM_GetCurrentGameMode();
	
	char sMission[128], sMissionName[128];
	for( int i = 0; i < arraysize; ++i )
	{
		int missionIndex = g_aCampaignList.Get(i);
		
		LMM_GetMapName(gamemode, missionIndex, 0, sMission, sizeof(sMission));
		LMM_GetMissionLocalizedName(gamemode, missionIndex, sMissionName, sizeof(sMissionName), client);
		
		menu.AddItem(sMission, sMissionName);
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, 60);

	return Plugin_Handled;
}


/**
 * Menu Handlers
 */
int MapMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if( action == MenuAction_Select ) 
	{
		char sMission[128], sMissionName[128];
		GetMenuItem(menu,
				param2,
				sMission, sizeof(sMission),
				_,
				sMissionName, sizeof(sMissionName));
				
		DisplayVoteMapsMenu(param1, sMission, sMissionName);
	}
	else if( action == MenuAction_End )
	{
		delete menu;
	}
	
	return 1;
}

void DisplayVoteMapsMenu(int client, const char[] sMission, const char[] sMissionName)
{
	if (!CheckVoteAccess(client)) return;
	
	Handle vote = CreateBuiltinVote(CampaignVoteHandler, BuiltinVoteType_ChgCampaign, BuiltinVoteAction_Select|BuiltinVoteAction_Cancel|BuiltinVoteAction_End);
	
	int total = 0;
	int[] players = new int[MaxClients];
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 1 )
			players[total++] = i;
	}
	
	strcopy(g_sVoteCampaign, sizeof(g_sVoteCampaign), sMission);
	strcopy(g_sVoteCampaignName, sizeof(g_sVoteCampaignName), sMissionName);
	
	SetBuiltinVoteArgument(vote, g_sVoteCampaignName);
	SetBuiltinVoteInitiator(vote, client);
	SetBuiltinVoteResultCallback(vote, CampaignVoteResult);
	
	DisplayBuiltinVote(vote, players, total, FindConVar("sv_vote_timer_duration").IntValue);
}

bool CheckVoteAccess(int client)
{
	if( GetClientTeam(client) == 1 ) // 1 -> Spectator
	{
		PrintToChat(client, "\x01<\x05VCC\x01> \x05Spectators \x01cannot vote.");
		return false;
	}
	if( IsBuiltinVoteInProgress() )
	{
		PrintToChat(client, "\x01<\x05VCC\x01> There's a vote \x05in progress\x01.");
		return false;
	}
	if( CheckBuiltinVoteDelay() > 0 )
	{
		PrintToChat(client, "\x01<\x05VCC\x01> Wait for \x04%ds \x01to call another vote.", CheckBuiltinVoteDelay());
		return false;
	}
	
	return true;
}

/**
 * Menu CallBacks
 */
int CampaignVoteHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
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
	
	return 1;
}

int CampaignVoteResult(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if( (float(num_votes) / float(num_clients)) < g_cVotePercent.FloatValue )
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_NotEnoughVotes);
		return 0;
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
		CreateTimer(3.0, Timer_Changelevel, .flags = TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	}
	
	return 1;
}


/**
 * Timers
 */
Action Timer_Changelevel(Handle timer)
{
	if( !IsMapValid(g_sVoteCampaign) )
	{
		PrintToChatAll("\x01<\x05VCC\x01> \x04Failed \x01to change map (\x03%s\x01)", g_sVoteCampaignName);
		return Plugin_Stop;
	}
	
	if( GetFeatureStatus(FeatureType_Native, "L4D2_ChangeLevel") == FeatureStatus_Available )
	{
		L4D2_ChangeLevel(g_sVoteCampaign);
	}
	else
	{
		ForceChangeLevel(g_sVoteCampaign, "Vote custom campaigns");
	}
	
	return Plugin_Stop;
}



/**
 * Misc
 */
bool ParseCampaigns()
{
	g_aCampaignList.Clear();
	
	if( GetFeatureStatus(FeatureType_Native, "LMM_GetCurrentGameMode") != FeatureStatus_Available )
	{
		return false;
	}
	
	LMM_GAMEMODE gamemode = LMM_GetCurrentGameMode();
	if( gamemode == LMM_GAMEMODE_UNKNOWN )
	{
		return false;
	}
	
	int missionNum = LMM_GetNumberOfMissions(gamemode);
	if( missionNum <= 0 )
	{
		return false;
	}
	
	char buffer[128];
	for( int i = 0; i < missionNum; ++i )
	{
		if( LMM_GetMissionName(gamemode, i, buffer, sizeof(buffer)) != -1 && strncmp(buffer, "L4D2C", 5) != 0 )
		{
			g_aCampaignList.Push(i);
		}
	}
	
	return g_aCampaignList.Length > 0;
}

