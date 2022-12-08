#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>

#define PLUGIN_VERSION "1.2"

public Plugin myinfo = 
{
	name = "[L4D & 2] Score Difference",
	author = "Forgetest, vikingo12",
	description = "ez",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define ABS(%0) (((%0) < 0) ? -(%0) : (%0))

float g_flDelay;

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
	
	ConVar cv = CreateConVar("l4d2_scorediff_print_delay", "5.0", "Delay in printing score difference.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0);
	OnConVarChanged(cv, "", "");
	cv.AddChangeHook(OnConVarChanged);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flDelay = convar.FloatValue;
}

public void L4D2_OnEndVersusModeRound_Post()
{
	if (InSecondHalfOfRound())
	{
		if (g_flDelay >= 0.1)
			CreateTimer(g_flDelay, Timer_PrintDifference, _, TIMER_FLAG_NO_MAPCHANGE);
		else
			Timer_PrintDifference(null);
	}
}

Action Timer_PrintDifference(Handle timer)
{
	int iSurvRoundScore = GetChapterScore(L4D2_TeamNumberToTeamIndex(2));
	int iInfRoundScore = GetChapterScore(L4D2_TeamNumberToTeamIndex(3));
	int iSurvCampaignScore = GetCampaignScore(L4D2_TeamNumberToTeamIndex(2));
	int iInfCampaignScore = GetCampaignScore(L4D2_TeamNumberToTeamIndex(3));
	
	int iRoundDifference = ABS(iSurvRoundScore - iInfRoundScore);
	int iTotalDifference = ABS(iSurvCampaignScore - iInfCampaignScore);
	
	if (iRoundDifference != iTotalDifference) 
	{
		CPrintToChatAll("%t", "Announce_Chapter", iRoundDifference);
		CPrintToChatAll("%t", "Announce_Total", iTotalDifference);
	}
	else 
	{
		CPrintToChatAll("%t", "Announce_ElseChapter", iRoundDifference);
	}
	
	if (TranslationPhraseExists("Announce_Survivor"))
		CPrintToChatAll("%t", "Announce_Survivor", iSurvCampaignScore);
	
	if (TranslationPhraseExists("Announce_Infected"))
		CPrintToChatAll("%t", "Announce_Infected", iInfCampaignScore);
	
	int iMapDistance = L4D_GetVersusMaxCompletionScore();
	if (iTotalDifference <= iMapDistance)
	{
		if (TranslationPhraseExists("Announce_ComebackWithDistance"))
			CPrintToChatAll("%t", "Announce_ComebackWithDistance", iTotalDifference);
	}
	else
	{
		if (TranslationPhraseExists("Announce_ComebackWithBonus"))
			CPrintToChatAll("%t", "Announce_ComebackWithBonus", iMapDistance, iTotalDifference - iMapDistance);
	}
	
	return Plugin_Stop;
}

int GetChapterScore(int team)
{
	if (L4D_IsEngineLeft4Dead1())
	{
		switch (team)
		{
		case 0:
			{
				return GameRules_GetProp("m_iVersusMapScoreTeam1", _, L4D_GetCurrentChapter() - 1);
			}
		case 1:
			{
				return GameRules_GetProp("m_iVersusMapScoreTeam2", _, L4D_GetCurrentChapter() - 1);
			}
		}
	}
	
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
