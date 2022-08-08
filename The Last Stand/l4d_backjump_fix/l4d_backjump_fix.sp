#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "2.1"

public Plugin myinfo =
{
	name = "[L4D & 2] Backjump Fix",
	author = "Forgetest",
	description = "Fix hunter being unable to pounce off non-static props",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;
	
	if (GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 3)
	{
		SDKHook(client, SDKHook_TouchPost, SDK_OnTouch_Post);
	}
	else
	{
		SDKUnhook(client, SDKHook_TouchPost, SDK_OnTouch_Post);
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;
	
	int oldteam = event.GetInt("oldteam");
	if (oldteam != 3 || oldteam == event.GetInt("team"))
		return;
	
	SDKUnhook(client, SDKHook_TouchPost, SDK_OnTouch_Post);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;
	
	if (GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 3)
		return;
	
	SDKUnhook(client, SDKHook_TouchPost, SDK_OnTouch_Post);
}

void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(GetClientOfUserId(event.GetInt("bot")), GetClientOfUserId(event.GetInt("player")));
}

void HandlePlayerReplace(int replacer, int replacee)
{
	if (!replacer || !IsClientInGame(replacer))
		return;
	
	if (GetClientTeam(replacer) != 3 || GetEntProp(replacer, Prop_Send, "m_zombieClass") != 3)
		return;
	
	if (IsPlayerAlive(replacer))
	{
		SDKHook(replacer, SDKHook_TouchPost, SDK_OnTouch_Post);
	}
	
	if (replacee && IsClientInGame(replacee))
	{
		SDKUnhook(replacee, SDKHook_TouchPost, SDK_OnTouch_Post);
	}
}

void SDK_OnTouch_Post(int entity, int other)
{
	// the moment player is disconnecting
	if (!IsClientInGame(entity))
		return;
	
	// mysterious questionable secret that Valve gifts, jk
	int ability = GetEntPropEnt(entity, Prop_Send, "m_customAbility");
	if (ability == -1)
	{
		SDKUnhook(entity, SDKHook_TouchPost, SDK_OnTouch_Post);
		return;
	}
	
	// not bouncing
	if (GetEntPropEnt(entity, Prop_Send, "m_hGroundEntity") != -1)
		return;
	
	// not valid touch
	if (!IsValidEdict(other))
		return;
	
	// impossible to pounce off players
	if (other <= MaxClients)
		return;
	
	// not solid entity, not bounceable
	if (!Entity_IsSolid(other))
		return;
	
	// except weapon entities
	static char clsname[64];
	if (!GetEdictClassname(other, clsname, sizeof(clsname)) || strncmp(clsname, "weapon_", 7) == 0)
		return;
	
	static int iOffs_BlockBounce = -1;
	if (iOffs_BlockBounce == -1)
		iOffs_BlockBounce = FindSendPropInfo("CLunge", "m_isLunging") + 16;
	
	// touched survivors before and therefore unable to bounce
	if (GetEntData(ability, iOffs_BlockBounce, 1))
		return;
	
	// confirm a bounce recharge
	SetEntPropFloat(ability, Prop_Send, "m_lungeAgainTimer", 0.5, 0);
	SetEntPropFloat(ability, Prop_Send, "m_lungeAgainTimer", GetGameTime() + 0.5, 1);
}

// https://forums.alliedmods.net/showthread.php?t=147732
#define SOLID_NONE 0
#define FSOLID_NOT_SOLID 0x0004
/**
 * Checks whether the entity is solid or not.
 *
 * @param entity            Entity index.
 * @return                    True if the entity is solid, false otherwise.
 */
stock bool Entity_IsSolid(int entity)
{
    return (GetEntProp(entity, Prop_Send, "m_nSolidType", 1) != SOLID_NONE &&
            !(GetEntProp(entity, Prop_Send, "m_usSolidFlags", 2) & FSOLID_NOT_SOLID));
}