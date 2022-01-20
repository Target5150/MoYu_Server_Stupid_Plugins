#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D2] Fix DeathFall Camera",
	author = "Forgetest",
	description = "Prevent \"point_deathfall_camera\" permanently locking view.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d2_fix_deathfall_cam"

ArrayList g_aDeathFallClients;
Handle g_hSDKCall_SetViewEntity;
int m_bShowViewModel;

void LoadSDK()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (!conf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CBasePlayer::SetViewEntity"))
		SetFailState("Missing signature \"CBasePlayer::SetViewEntity\"");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hSDKCall_SetViewEntity = EndPrepSDKCall()) == null)
		SetFailState("Failed to finish SDkCall \"CBasePlayer::SetViewEntity\"");
	
	m_bShowViewModel = GameConfGetOffset(conf, "m_bShowViewModel");
	if (m_bShowViewModel == -1)
		SetFailState("Missing offset \"m_bShowViewModel\"");
	
	delete conf;
}

public void OnPluginStart()
{
	LoadSDK();
	
	CreateConVar("l4d2_fix_deathfall_cam_version", PLUGIN_VERSION, "Fix Deathfall Camera Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY);
	
	g_aDeathFallClients = new ArrayList();
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_aDeathFallClients.Clear();
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_aDeathFallClients.Length) return;
	
	int userid = event.GetInt("userid");
	
	int index = g_aDeathFallClients.FindValue(userid);
	if (index != -1)
	{
		Timer_ReleaseView(null, userid);
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_aDeathFallClients.Length) return;
	
	int userid = event.GetInt("userid");
	if (g_aDeathFallClients.FindValue(userid) == -1)
		return;
	
	CreateTimer(6.0, Timer_ReleaseView, userid, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ReleaseView(Handle tiemr, any userid)
{
	int index = g_aDeathFallClients.FindValue(userid);
	if (index == -1)
		return Plugin_Stop;
	
	g_aDeathFallClients.Erase(index);
	ReleaseFromDeathfallCamera(userid);
	
	return Plugin_Stop;
}

public Action L4D_OnFatalFalling(int client, int camera)
{
	if (GetClientTeam(client) == 2 && !IsFakeClient(client) && IsPlayerAlive(client))
	{
		int userid = GetClientUserId(client);
		if (g_aDeathFallClients.FindValue(userid) == -1)
			g_aDeathFallClients.Push(userid);
		
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

void SetViewEntity(int client, int view)
{
	SDKCall(g_hSDKCall_SetViewEntity, client, view);
}

stock void ReleaseFromDeathfallCamera(int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client) return;
	
	int flags = GetEntityFlags(client);
	SetEntityFlags(client, flags & ~FL_FROZEN);
	SetEntData(client, m_bShowViewModel, 1, 1);
	SetViewEntity(client, -1);
}