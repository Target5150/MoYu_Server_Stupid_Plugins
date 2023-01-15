#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <builtinvotes>
#include <colors>

#undef REQUIRE_PLUGIN
#tryinclude <l4d2_changelevel>
#include <l4d2_mission_manager>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "2.1"

public Plugin myinfo =
{
	name = "[L4D2] Vote Custom Campaign",
	author = "Forgetest",
	description = "ez",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

/**
 * Globals
 */
#define TRANSLATION_FILE "vote_custom_campaigns.phrases"

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
	LoadPluginTranslations();
	
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
		CReplyToCommand(client, "%t", "Command_ReloadSuccess");
	} else {
		CReplyToCommand(client, "%t", "Command_ReloadFailure");
	}
	
	return Plugin_Handled;
}

Action Command_VoteCampaign(int client, int args) 
{
	if( !client ) { return Plugin_Handled; }
	
	int arraysize = g_aCampaignList.Length;
	if( !arraysize ) { return Plugin_Handled; }
	
	Menu menu = new Menu(MapMenuHandler);
	menu.SetTitle( "%T", "Command_VoteMenuTitle", client, arraysize );
	
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
		CPrintToChat(client, "%t", "VoteAccess_Spectator");
		return false;
	}
	if( IsBuiltinVoteInProgress() )
	{
		CPrintToChat(client, "%t", "VoteAccess_InProgress");
		return false;
	}
	if( CheckBuiltinVoteDelay() > 0 )
	{
		CPrintToChat(client, "%t", "VoteAccess_Cooldown", CheckBuiltinVoteDelay());
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
		
		int missionIndex;
		char buffer[256];
		LMM_GAMEMODE gamemode = LMM_GetCurrentGameMode();
		LMM_FindMapIndexByName(gamemode, missionIndex, g_sVoteCampaign);
		
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;
			
			if (LMM_GetMissionLocalizedName(gamemode, missionIndex, buffer, sizeof(buffer), i) == 1)
			{
				CPrintToChat(i, "%t", "Announce_VotePass", buffer);
			}
			else
			{
				CPrintToChat(i, "%t", "Announce_VotePass", g_sVoteCampaignName);
			}
		}
		
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
		CPrintToChatAll("%t", "Announce_ChangeLevelFailure", g_sVoteCampaignName);
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

void LoadPluginTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "translations/"...TRANSLATION_FILE... ".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation file \""...TRANSLATION_FILE...".txt\"");
	}
	LoadTranslations(TRANSLATION_FILE);
}
