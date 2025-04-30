#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Revive Health Decay",
	author = "Forgetest",
	description = "Decay revive health at a percent as much as incap health.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define KEY_FUNCTION "L4DD::CTerrorPlayer::OnRevived"

ConVar survivor_incap_health;

public void OnPluginStart()
{
	int bLeft4Dead2;
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: bLeft4Dead2 = false;
		case Engine_Left4Dead2: bLeft4Dead2 = true;
		default:
		{
			SetFailState("Unsupported engine");
		}
	}
	
	char sGameData[2][] = {"left4dhooks.l4d1", "left4dhooks.l4d2"};
	GameData conf = new GameData(sGameData[bLeft4Dead2]);
	if (conf == null)
		SetFailState("Missing gamedata \"%s\"", sGameData[bLeft4Dead2]);
	
	DynamicDetour hDetour = DynamicDetour.FromConf(conf, KEY_FUNCTION);
	if (!hDetour)
		SetFailState("Missing detour setup for \""...KEY_FUNCTION..."\"");
	if (!hDetour.Enable(Hook_Pre, DTR_CTerrorPlayer_OnRevived))
		SetFailState("Failed to detour \""...KEY_FUNCTION..."\"");
	
	delete hDetour;
	delete conf;
	
	survivor_incap_health = FindConVar("survivor_incap_health");
}

float flHealthPercent;
MRESReturn DTR_CTerrorPlayer_OnRevived(int pThis, DHookReturn hReturn)
{
	flHealthPercent = 1.0;
	
	if (L4D_IsPlayerIncapacitated(pThis))
	{
		float flHealth = GetClientHealth(pThis) + 0.0;
		
		flHealthPercent = flHealth / survivor_incap_health.FloatValue;
	}
	
	return MRES_Ignored;
}

public void L4D2_OnRevived(int client)
{
	L4D_SetTempHealth(client, L4D_GetTempHealth(client) * flHealthPercent);
}