#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D & 2] No Drag Shove",
	author = "Forgetest",
	description = "Shoot your gun in defence.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

int g_iShovePenalty[MAXPLAYERS+1];
float g_flNextShoveTime[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("tongue_grab", Event_TongueGrab);
	HookEvent("tongue_release", Event_TongueRelease);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
}

void Event_TongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (!client || !IsClientInGame(client))
		return;
	
	g_flNextShoveTime[client] = GetEntPropFloat(client, Prop_Send, "m_flNextShoveTime");
	
	float flTimeBeforeChoke = GetGameTime() + 1.0;
	if ( flTimeBeforeChoke > g_flNextShoveTime[client] )
	{
		SetEntPropFloat(client, Prop_Send, "m_flNextShoveTime", flTimeBeforeChoke);
	}
	
	// Only used for visual feedback.
	g_iShovePenalty[client] = GetEntProp(client, Prop_Send, "m_iShovePenalty");
	
	int iMinShovePenalty = GetMinShovePenalty() + 2;
	if (g_iShovePenalty[client] < iMinShovePenalty)
	{
		SetEntProp(client, Prop_Send, "m_iShovePenalty", iMinShovePenalty);
	}
}

void Event_TongueRelease(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (!client || !IsClientInGame(client))
		return;
	
	SetEntPropFloat(client, Prop_Send, "m_flNextShoveTime", g_flNextShoveTime[client]);
	SetEntProp(client, Prop_Send, "m_iShovePenalty", g_iShovePenalty[client]);
}

void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(event.GetInt("bot"), event.GetInt("player"));
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(event.GetInt("player"), event.GetInt("bot"));
}

void HandlePlayerReplace(int replacer, int replacee)
{
	replacer = GetClientOfUserId(replacer);
	replacee = GetClientOfUserId(replacee);
	
	if (!replacer || !replacee)
		return;
	
	if (!IsClientInGame(replacer))
		return;
	
	if (GetClientTeam(replacer) != 2)
		return;
	
	g_flNextShoveTime[replacer] = g_flNextShoveTime[replacee];
	g_iShovePenalty[replacer] = g_iShovePenalty[replacee];
}

int GetMinShovePenalty()
{
	static ConVar 
		z_gun_swing_coop_min_penalty,
		z_gun_swing_vs_min_penalty;
	
	if (!z_gun_swing_coop_min_penalty || !z_gun_swing_vs_min_penalty)
	{
		z_gun_swing_coop_min_penalty = FindConVar("z_gun_swing_coop_min_penalty");
		z_gun_swing_vs_min_penalty = FindConVar("z_gun_swing_vs_min_penalty");
	}
	
	return L4D_IsCoopMode() ? z_gun_swing_coop_min_penalty.IntValue : z_gun_swing_vs_min_penalty.IntValue;
}