#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Compensated Ghost Time",
	author = "Forgetest",
	description = "Compensate ghost spawn time to catch up your teammates.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

bool g_bDeadAsInfected[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("round_start", Event_round_start);
	HookEvent("player_death", Event_player_death);
	HookEvent("player_team", Event_player_team);
	HookEvent("ghost_spawn_time", Event_ghost_spawn_time);
}

void Event_round_start(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bDeadAsInfected[i] = false;
	}
}

void Event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return;
	
	if (GetClientTeam(client) != 3)
		return;
	
	g_bDeadAsInfected[client] = true;
}

void Event_player_team(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetInt("oldteam") != 3 || event.GetInt("oldteam") == event.GetInt("team"))
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return;
	
	g_bDeadAsInfected[client] = false;
}

void Event_ghost_spawn_time(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return;

	if (!g_bDeadAsInfected[client])
		return;

	float flSpawnTime = L4D_GetPlayerSpawnTime(client);
	float flCompensated = CompensateSpawnTime(flSpawnTime);

	if (flCompensated < flSpawnTime)
		L4D_SetBecomeGhostAt(client, flCompensated);
}

float CompensateSpawnTime(float flBase)
{
	float sum = 0.0;
	int numPlayers = 0;

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
		{
			numPlayers++;

			float flSpawnTime = L4D_GetPlayerSpawnTime(i);

			if (IsPlayerAlive(i) || flSpawnTime < 0.0)
				sum += flBase;
			else
				sum += flSpawnTime;
		}
	}

	return sum / numPlayers;
}