#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo =
{
	name = "[L4D & 2] Infected Slowdown Protect",
	author = "Forgetest",
	description = "Prevent infected slowdown being overridden by other damage.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

bool g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i)) OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, SDK_OnTakeDamage_Post);
}

float flVelocityMod = -1.0;
Action SDK_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (flVelocityMod != -1.0)
		flVelocityMod = -1.0;
	
	if (!attacker || attacker > MaxClients)
		return Plugin_Continue;
	
	if (!IsClientInGame(attacker))
		return Plugin_Continue;
	
	if (GetClientTeam(victim) != 2)
		return Plugin_Continue;
	
	float flTemp = GetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier");
	if (flTemp < 1.0)
		flVelocityMod = flTemp;
	
	return Plugin_Continue;
}

void SDK_OnTakeDamage_Post(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (flVelocityMod == -1.0)
		return;
	
	if (!IsClientInGame(victim))
		return;
	
	if (IsIncapacitated(victim) || !IsPlayerAlive(victim))
		return;
	
	if (1.0 == GetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier"))
		SetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier", flVelocityMod);
}

stock bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1));
}
