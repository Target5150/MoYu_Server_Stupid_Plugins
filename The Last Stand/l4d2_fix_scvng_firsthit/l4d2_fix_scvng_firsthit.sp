#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_gamerules>
#include <left4dhooks>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo =
{
	name = "[L4D2] Fix Scavenge First-Hit",
	author = "Forgetest",
	description = "Fix first hit classes varying between halves and staying the same for rounds.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d2_fix_scvng_firsthit"
#define OFFS_FIRSTCLS "CDirector::m_nFirstClassIndex"

int m_nFirstClassIndex;
ConVar g_cvAllow;

void LoadSDK()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (!conf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	m_nFirstClassIndex = GameConfGetOffset(conf, OFFS_FIRSTCLS);
	if (m_nFirstClassIndex == -1) SetFailState("Missing offset \""...OFFS_FIRSTCLS..."\"");
	
	delete conf;
}

public void OnPluginStart()
{
	LoadSDK();
	
	g_cvAllow = CreateConVar("l4d2_scvng_firsthit_shuffle", "0", "Shuffle first hit classes.\nValue: 1 = Shuffle every round, 2 = Shuffle every match, 0 = Disable.", FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 2.0);
	
	HookEvent("round_start_pre_entity", Event_RoundStartPreEntity, EventHookMode_PostNoCopy);
	HookEvent("player_transitioned", Event_PlayerTransitioned);
}

void Event_RoundStartPreEntity(Event event, const char[] name, bool dontBroadcast)
{
	if (!L4D2_IsScavengeMode()) return;
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ResetClassSpawnSystem(i);
		}
	}
	
	if (g_cvAllow.IntValue == 1 && !GameRules_GetProp("m_bInSecondHalfOfRound", 1))
	{
		SetRandomSeed(GetTime());
		CDirector_SetFirstClassIndex(GetRandomInt(1, 6));
	}
}

void Event_PlayerTransitioned(Event event, const char[] name, bool dontBroadcast)
{
	if (!L4D2_IsScavengeMode()) return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client) ResetClassSpawnSystem(client);
}

public void OnConfigsExecuted()
{
	if (!L4D2_IsScavengeMode()) return;
	
	if (g_cvAllow.IntValue == 2)
	{
		SetRandomSeed(GetTime());
		CDirector_SetFirstClassIndex(GetRandomInt(1, 6));
	}
}

void ResetClassSpawnSystem(int client)
{
	for (int i = 1; i <= 8; ++i)
		SetEntProp(client, Prop_Send, "m_classSpawnCount", 0, _, i);
}

void CDirector_SetFirstClassIndex(int index)
{
	if (index >= 1 && index <= 6)
		StoreToAddress(L4D_GetPointer(POINTER_DIRECTOR) + view_as<Address>(m_nFirstClassIndex), index, NumberType_Int32);
}