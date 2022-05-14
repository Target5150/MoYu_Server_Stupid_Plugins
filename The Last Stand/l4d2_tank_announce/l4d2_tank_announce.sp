#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_sound>
#include <left4dhooks>
#include <colors>

#define PLUGIN_VERSION "2.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Tank Announcer",
	author = "Visor, Forgetest, xoxo",
	description = "Announce in chat and via a sound when a Tank has spawned",
	version = PLUGIN_VERSION,
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

ConVar g_cvSound;
char g_sSound[PLATFORM_MAX_PATH];

#define TRANSLATION_FILE "l4d2_tank_announce.phrases"
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
	
	g_cvSound = CreateConVar("l4d2_tank_announce_sound", "ui/pickup_secret01.wav", "Sound emitted every tank spawn .", FCVAR_SPONLY);
	g_cvSound.AddChangeHook(ConVarChanged_Sound);
	ConVarChanged_Sound(g_cvSound, "", "");
}

void ConVarChanged_Sound(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sSound, sizeof(g_sSound));
}

public void OnMapStart()
{
	PrecacheSound(g_sSound);
}

public void L4D_OnSpawnTank_Post(int client, const float vecPos[3], const float vecAng[3])
{
	if (client <= 0 || !IsClientInGame(client))
		return;
	
	EmitSoundToAll(g_sSound);
	CreateTimer(0.1, Timer_Announce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_Announce(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;
	
	if (IsFakeClient(client))
	{
		client = GetEntProp(L4D_GetResourceEntity(), Prop_Send, "m_pendingTankPlayerIndex");
		if (client && IsClientInGame(client))
		{
			CPrintToChatAll("%t", "Announce_PlayerControlled", client);
			return Plugin_Stop;
		}
	}
	
	CPrintToChatAll("%t", "Announce_AI");
	return Plugin_Stop;
}