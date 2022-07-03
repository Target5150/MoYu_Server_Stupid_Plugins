#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "2.0"

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
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 3)
		return;
	
	SDKHook(client, SDKHook_TouchPost, SDK_OnTouch_Post);
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
	if (!client || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 3)
		return;
	
	SDKUnhook(client, SDKHook_TouchPost, SDK_OnTouch_Post);
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
	if (!replacer || GetClientTeam(replacer) != 3 || GetEntProp(replacer, Prop_Send, "m_zombieClass") != 3)
		return;
	
	replacee = GetClientOfUserId(replacee);
	if (!replacee || !IsClientInGame(replacee))
		return;
	
	SDKUnhook(replacee, SDKHook_TouchPost, SDK_OnTouch_Post);
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
	
	// not even materialized
	if (GetEntProp(entity, Prop_Send, "m_isGhost"))
		return;
	
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