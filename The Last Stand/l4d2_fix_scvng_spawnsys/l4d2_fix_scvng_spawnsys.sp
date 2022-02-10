#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D2] Fix Scavenge First-Class",
	author = "Forgetest",
	description = "Fix first class varying between halves and staying the same for rounds.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d2_fix_scvng_spawnsys"
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
	
	g_cvAllow = CreateConVar("l4d2_scvng_firstclass_shuffle", "0", "Determine if scavenge rounds share no first class.", FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	
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
	
	if (g_cvAllow.BoolValue)
	{
		SetRandomSeed(GetTime());
		CDirector_SetFirstClassIndex(GetRandomInt(1, 6));
	}
}

void Event_PlayerTransitioned(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client) ResetClassSpawnSystem(client);
}

public void OnConfigsExecuted()
{
	if (g_cvAllow.BoolValue)
	{
		SetRandomSeed(GetTime());
		CDirector_SetFirstClassIndex(GetRandomInt(1, 6));
	}
}

void ResetClassSpawnSystem(int client)
{
	for (int i = 1; i <= 8; ++i)
		SetEntProp(client, Prop_Send, "m_classSpawnCount", 0, _, i);
	
	if (GetEntProp(client, Prop_Send, "m_isGhost", 1)) // failsafe
		SetEntProp(client, Prop_Send, "m_classSpawnCount", 1, _, GetEntProp(client, Prop_Send, "m_zombieClass"));
}

void CDirector_SetFirstClassIndex(int index)
{
	if (index >= 1 && index <= 6)
		StoreToAddress(L4D_GetPointer(POINTER_DIRECTOR) + view_as<Address>(m_nFirstClassIndex), index, NumberType_Int32);
}