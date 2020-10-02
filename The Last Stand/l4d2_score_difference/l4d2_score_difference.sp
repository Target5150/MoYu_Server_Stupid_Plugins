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

public void L4D2_OnEndVersusModeRound_Post()
{
	if (InSecondHalfOfRound())
		CreateTimer(5.0, Timer_PrintDifference, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PrintDifference(Handle timer)
{
	int iRoundDifference = ABS(GetChapterScore(0) - GetChapterScore(1));
	int iTotalDifference = ABS(GetCampaignScore(0) - GetCampaignScore(1));
	
	if (iRoundDifference != iTotalDifference) {
		CPrintToChatAll("{red}[{default}!{red}] {default}Difference: {olive}%d {green}({olive}%d {default}in total{green})", iRoundDifference, iTotalDifference);
	} else {
		CPrintToChatAll("{red}[{default}!{red}] {default}Difference: {olive}%d", iRoundDifference);
	}
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
