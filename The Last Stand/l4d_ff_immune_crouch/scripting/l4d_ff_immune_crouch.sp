#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] FF Immune Crouch",
	author = "Forgetest",
	description = "Feature from B4B. Deal/Receive no friendly fire when crouching.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)) OnClientPutInServer(i);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, SDK_OnTakeDamageAlive);
}

Action SDK_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damagetype & DMG_BURN)
		return Plugin_Continue;

	if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker))
		return Plugin_Continue;

	if (GetClientTeam(victim) != 2 || GetClientTeam(attacker) != 2)
		return Plugin_Continue;

	if (GetEntityFlags(victim) & (FL_DUCKING|FL_ONGROUND) != (FL_DUCKING|FL_ONGROUND)
	 || GetEntityFlags(attacker) & (FL_DUCKING|FL_ONGROUND) != (FL_DUCKING|FL_ONGROUND))
		return Plugin_Continue;

	damage = 0.0;
	return Plugin_Changed;
}