#include <sourcemod>
#include <sdktools>
#include <colors>
#undef REQUIRE_PLUGIN
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1.1"

#define ABS(%0) (((%0) < 0) ? -(%0) : (%0))

public Plugin myinfo = 
{
	name = "L4D2 Score Difference",
	author = "Forgetest",
	description = "ez",
	version = PLUGIN_VERSION,
	url = "?"
};

#define TRANSLATION_FILE "l4d2_score_difference.phrases"
void LoadPluginTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/"...TRANSLATION_FILE...".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation \""...TRANSLATION_FILE..."\"");
	}
	LoadTranslations(TRANSLATION_FILE);
}

public void OnPluginStart()
{
	LoadPluginTranslations();
}

public void L4D2_OnEndVersusModeRound_Post()
{
	if (InSecondHalfOfRound())
		CreateTimer(5.0, Timer_PrintDifference, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PrintDifference(Handle timer)
{
	int iRoundDifference = ABS(GetChapterScore(0) - GetChapterScore(1));
	int iTotalDifference = ABS(GetCampaignScore(0) - GetCampaignScore(1));
	int iSurvivorDifference = GetCampaignScore(L4D2_TeamNumberToTeamIndex(2));
	int iInfectedDifference = GetCampaignScore(L4D2_TeamNumberToTeamIndex(3));
	
	if (iRoundDifference != iTotalDifference) 
	{
		CPrintToChatAll("%t", "Announce_Chapter", iRoundDifference);
		CPrintToChatAll("%t", "Announce_Total", iTotalDifference);
	}
	else 
	{
		CPrintToChatAll("%t", "Announce_ElseChapter", iRoundDifference);
	}
	
	CPrintToChatAll("%t", "Announce_Survivor", iSurvivorDifference);
	CPrintToChatAll("%t", "Announce_Infected", iInfectedDifference);
}

int GetChapterScore(int team)
{
	return GameRules_GetProp("m_iChapterScore", _, team);
}

int GetCampaignScore(int team)
{
	return GameRules_GetProp("m_iCampaignScore", _, team);
}


int InSecondHalfOfRound()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

stock int L4D2_TeamNumberToTeamIndex(int team)
{
    return (team - 2) ^ GameRules_GetProp("m_bAreTeamsFlipped");
}
