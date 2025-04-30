#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <builtinvotes>
#include <colors>
#include <imatchext>

#undef REQUIRE_PLUGIN
#include <l4d2_changelevel>

#define PLUGIN_VERSION "2.2"

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
	LoadPluginTranslations("vote_custom_campaigns.phrases");
	LoadPluginTranslations("missions.phrases");
	
	g_cVotePercent =	CreateConVar(	"vcc_votes_percent",	"0.6",		"Votes more than this percent of non-spectator players can a vote result.", FCVAR_NOTIFY);
	g_cPassPercent =	CreateConVar(	"vcc_pass_percent",		"0.6",		"Approvals greater than this percent of votes can a vote pass.", FCVAR_NOTIFY);
	
	RegConsoleCmd("sm_vcc",		Command_VoteCampaign, "Show custom campaigns menu");
	RegConsoleCmd("sm_mapvote",	Command_VoteCampaign, "Show custom campaigns menu");
	
	RegAdminCmd("sm_vcc_reload", Command_ReloadCampaigns, ADMFLAG_CHANGEMAP, "Reload lists of custom campaigns");
	
	AutoExecConfig(true);
	
	g_aCampaignList = new ArrayList();
}

public void OnMissionCacheReload()
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
	if( !client || !IsClientInGame(client) ) { return Plugin_Continue; }
	
	int arraysize = g_aCampaignList.Length;
	if( !arraysize ) { return Plugin_Handled; }
	
	Menu menu = new Menu(MapMenuHandler, MenuAction_DisplayItem|MenuAction_Select|MenuAction_End);
	menu.SetTitle( "%T", "Command_VoteMenuTitle", client, arraysize );
	
	char sMission[128], sMissionName[128];
	for( int i = 0; i < arraysize; ++i )
	{
		MissionSymbol mission = g_aCampaignList.Get(i);
		if( !MissionSymbol.IsValid(mission)/* || mission.IsDisabled()*/ )
			continue;
		
		if( CurrentMode.GetNumChapters(mission) == 0 )
			continue;
		
		mission.GetName(sMission, sizeof(sMission));
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
	if( action == MenuAction_DisplayItem )
	{
		char sMission[128], sMissionName[128];
		menu.GetItem(param2, sMission, sizeof(sMission));

		if (GetMissionLocalizedName(sMission, sMissionName, sizeof(sMissionName), param1) == 0)
			return RedrawMenuItem(sMissionName);
	}
	else if( action == MenuAction_Select ) 
	{
		char sMission[128], sMissionName[128];
		menu.GetItem(param2,
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
		
		MissionSymbol mission = GetMissionSymbol(g_sVoteCampaign);
		if( MissionSymbol.IsValid(mission) )
		{
			char buffer[255];
			
			for (int i = 1; i <= MaxClients; ++i)
			{
				if( !IsClientInGame(i) || IsFakeClient(i) )
					continue;
				
				if( GetMissionLocalizedName(g_sVoteCampaign, buffer, sizeof(buffer), i) )
				{
					CPrintToChat(i, "%t", "Announce_VotePass", buffer);
				}
				else
				{
					CPrintToChat(i, "%t", "Announce_VotePass", g_sVoteCampaignName);
				}
			}
			
			CreateTimer(3.0, Timer_Changelevel, mission, TIMER_FLAG_NO_MAPCHANGE);
		}
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
Action Timer_Changelevel(Handle timer, MissionSymbol mission)
{
	if( !MissionSymbol.IsValid(mission) )
	{
		CPrintToChatAll("%t", "Announce_ChangeLevelFailure", "N/A");
		return Plugin_Stop;
	}
	
	KeyValues kv = new KeyValues("mission");
	CurrentMode.ExportChapter(mission, 1, kv);
	
	char buffer[255];
	kv.GetString("Map", buffer, sizeof(buffer));
	delete kv;
	
	if( !IsMapValid(buffer) )
	{
		CPrintToChatAll("%t", "Announce_ChangeLevelFailure", buffer);
		return Plugin_Stop;
	}
	
	if( GetFeatureStatus(FeatureType_Native, "L4D2_ChangeLevel") == FeatureStatus_Available )
	{
		L4D2_ChangeLevel(buffer);
	}
	else
	{
		ForceChangeLevel(buffer, "Vote custom campaigns");
	}
	
	return Plugin_Stop;
}



/**
 * Misc
 */
int GetMissionLocalizedName(const char[] missionName, char[] localizedName, int maxlen, int client = LANG_SERVER)
{
	if( TranslationPhraseExists(missionName) && (client == LANG_SERVER || IsTranslatedForLanguage(missionName, GetClientLanguage(client))) )
		return FormatEx(localizedName, maxlen, "%T", missionName, client);
	
	return 0;
}

bool ParseCampaigns()
{
	g_aCampaignList.Clear();
	
	char buffer[128];
	for( MissionSymbol mission = MissionSymbol.First(); MissionSymbol.IsValid(mission); mission = mission.Next() )
	{
		mission.GetName(buffer, sizeof(buffer));
		
		if( OfficialMapFilter().ContainsKey(buffer) )
			continue;
		
		g_aCampaignList.Push(mission);
	}
	
	return g_aCampaignList.Length > 0;
}

StringMap OfficialMapFilter()
{
	static StringMap s_OfficialMapFilter = null;
	if (s_OfficialMapFilter == null)
	{
		s_OfficialMapFilter = new StringMap();
		s_OfficialMapFilter.SetValue("credits", 1);
		s_OfficialMapFilter.SetValue("HoldoutTraining", 1);
		s_OfficialMapFilter.SetValue("HoldoutChallenge", 1);
		s_OfficialMapFilter.SetValue("shootzones", 1);
		s_OfficialMapFilter.SetValue("parishdash", 1);
		s_OfficialMapFilter.SetValue("L4D2C1", 1);
		s_OfficialMapFilter.SetValue("L4D2C2", 1);
		s_OfficialMapFilter.SetValue("L4D2C3", 1);
		s_OfficialMapFilter.SetValue("L4D2C4", 1);
		s_OfficialMapFilter.SetValue("L4D2C5", 1);
		s_OfficialMapFilter.SetValue("L4D2C6", 1);
		s_OfficialMapFilter.SetValue("L4D2C7", 1);
		s_OfficialMapFilter.SetValue("L4D2C8", 1);
		s_OfficialMapFilter.SetValue("L4D2C9", 1);
		s_OfficialMapFilter.SetValue("L4D2C10", 1);
		s_OfficialMapFilter.SetValue("L4D2C11", 1);
		s_OfficialMapFilter.SetValue("L4D2C12", 1);
		s_OfficialMapFilter.SetValue("L4D2C13", 1);
		s_OfficialMapFilter.SetValue("L4D2C14", 1);
	}
	return s_OfficialMapFilter;
}

void LoadPluginTranslations(const char[] file)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/%s.txt", file);
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation file \"%s.txt\"", file);
	}
	LoadTranslations(file);
}
