#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "2.1"

public Plugin myinfo = 
{
	name = "[L4D2] Restore Blocked Vocalize",
	author = "Forgetest",
	description = "Annoyments outside TLS are back.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "tls_restore_vocalize"
#define KEY_APPEND "CTerrorPlayer::ModifyOrAppendCriteria"
#define KEY_GAMEMODE "CDirector::GetGameModeBase"

StringMap g_smVocalize;

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (!conf)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	DynamicDetour hDetour = DynamicDetour.FromConf(conf, KEY_APPEND);
	if (!hDetour)
		SetFailState("Missing detour setup for \""...KEY_APPEND..."\"");
	
	if (!hDetour.Enable(Hook_Pre, DTR_OnModifyOrAppendCriteria_Pre) || !hDetour.Enable(Hook_Post, DTR_OnModifyOrAppendCriteria_Post))
		SetFailState("Failed to detour \""...KEY_APPEND..."\"");
	
	hDetour = DynamicDetour.FromConf(conf, KEY_GAMEMODE);
	if (!hDetour)
		SetFailState("Missing detour setup for \""...KEY_GAMEMODE..."\"");
	
	if (!hDetour.Enable(Hook_Pre, DTR_OnGetGameModeBase_Pre))
		SetFailState("Failed to detour \""...KEY_GAMEMODE..."\"");
	
	delete conf;
	
	g_smVocalize = new StringMap();
	g_smVocalize.SetValue("PlayerLaugh", true);
	g_smVocalize.SetValue("PlayerTaunt", true);
	g_smVocalize.SetValue("Playerdeath", true);
	
	L4D_OnGameModeChange(L4D_GetGameModeType());
}

public void L4D_OnGameModeChange(int gamemode)
{
	ToggleCommandListeners(gamemode == GAMEMODE_VERSUS);
}

void ToggleCommandListeners(bool enable)
{
	static bool enabled = false;
	if (enable && !enabled)
	{
		AddCommandListener(CmdLis_OnVocalize, "vocalize");
		enabled = true;
	}
	else if (!enable && enabled)
	{
		RemoveCommandListener(CmdLis_OnVocalize, "vocalize");
		enabled = false;
	}
}

int g_iActor = -1;
Action CmdLis_OnVocalize(int client, const char[] command, int argc)
{
	if (!IsClientInGame(client) || GetClientTeam(client) != 2)
		return Plugin_Continue;
	
	if (!L4D_IsVersusMode())
		return Plugin_Continue;
	
	static char sVocalize[64];
	if (GetCmdArg(1, sVocalize, sizeof(sVocalize)) && g_smVocalize.GetValue(sVocalize, argc))
	{
		g_iActor = client;
		
		DataPack dp = new DataPack();
		dp.WriteCell(client);
		dp.WriteCell(GetClientUserId(client));
		RequestFrame(OnNextFrame_ResetActor, dp);
	}
	
	return Plugin_Continue;
}

void OnNextFrame_ResetActor(DataPack dp)
{
	dp.Reset();
	
	int client = dp.ReadCell();
	if (client == g_iActor && client == GetClientOfUserId(dp.ReadCell()))
	{
		g_iActor = -1;
	}
	
	delete dp;
}

bool bShouldOverride = false;
MRESReturn DTR_OnModifyOrAppendCriteria_Pre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if (g_iActor != -1)
	{
		bShouldOverride = true;
	}
	return MRES_Ignored;
}

MRESReturn DTR_OnModifyOrAppendCriteria_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	g_iActor = -1;
	bShouldOverride = false;
	return MRES_Ignored;
}

MRESReturn DTR_OnGetGameModeBase_Pre(int pThis, DHookReturn hReturn)
{
	if (bShouldOverride)
	{
		hReturn.SetString("coop");
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}