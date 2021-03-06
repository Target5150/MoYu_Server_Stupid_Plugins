#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <colors>

#pragma newdecls required

#define ABS(%0) (((%0) < 0) ? -(%0) : (%0))

public Plugin myinfo = 
{
	name = "L4D2 Score Difference",
	author = "Forgetest",
	description = "ez",
	version = "1.0",
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
	
	CPrintToChatAll("{red}[{default}!{red}] {default}Difference: {olive}%d {default}({olive}%d {default}in total)", iRoundDifference, iTotalDifference);
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
