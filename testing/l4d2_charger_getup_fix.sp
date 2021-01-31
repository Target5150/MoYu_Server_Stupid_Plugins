#include <sourcemod>
#include <left4dhooks>
#include <sdkhooks>
#include <colors>
#include <godframecontrol>


// Charges that land against a wall and are cleared instantly
#define SEQ_INSTANT_NICK 671
#define SEQ_INSTANT_COACH 660
#define SEQ_INSTANT_ELLIS 675
#define SEQ_INSTANT_ROCHELLE 678
#define SEQ_INSTANT_ZOEY 823
#define SEQ_INSTANT_BILL 763
#define SEQ_INSTANT_LOUIS 763
#define SEQ_INSTANT_FRANCIS 766

// Charges charge all the way and are then cleared instantly
#define SEQ_LONG_NICK 672
#define SEQ_LONG_COACH 661
#define SEQ_LONG_ELLIS 676
#define SEQ_LONG_ROCHELLE 679
#define SEQ_LONG_ZOEY 824
#define SEQ_LONG_BILL 764
#define SEQ_LONG_LOUIS 764
#define SEQ_LONG_FRANCIS 767

#define ZC_JOCKEY 5
#define ZC_CHARGER 6
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define TEAM_SPECTATOR 1

// Cvars
new Handle:cvar_longChargeGetUpFixEnabled = INVALID_HANDLE;
new Handle:cvar_keepWallSlamLongGetUp = INVALID_HANDLE;
new Handle:cvar_keepLongChargeLongGetUp = INVALID_HANDLE;

// Fake godframe event variables
new Handle:g_hLongChargeDuration;
new Handle:g_hChargeDuration;

// Variables
new ChargerTarget[MAXPLAYERS+1];
bool bLateLoad, bWallSlamed[MAXPLAYERS+1], bInForcedGetUp[MAXPLAYERS+1], bIgnoreJockeyed[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "[L4D2] Long Charger Get-Up Fix",
	author = "Spoon",
	description = "Allows control over long charger get ups.",
	version = "2.0.1",
	url = "https://github.com/spoon-l4d2"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLateLoad = late;
}

public OnPluginStart()
{
	// Event Hooks
	HookEvent("charger_killed", Event_ChargerKilled, EventHookMode_Post);
	HookEvent("charger_carry_start", Event_ChargeCarryStart, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("charger_pummel_start", Event_PummelStart, EventHookMode_Post);
	HookEvent("charger_pummel_end", Event_PummelStart, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("jockey_ride", Event_JockeyRide, EventHookMode_Pre);
	HookEvent("jockey_ride_end", Event_JockeyRideEnd, EventHookMode_Pre);
	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Post);
	HookEvent("bot_player_replace", Event_BotPlayerReplace, EventHookMode_Post);
	
	g_hChargeDuration = FindConVar("gfc_charger_duration");
	g_hLongChargeDuration = CreateConVar("gfc_long_charger_duration", "2.2", "God frame duration for long charger getup animations");
	
	
	// Cvars
	cvar_longChargeGetUpFixEnabled = CreateConVar("charger_long_getup_fix", "1", "Enable the long Charger get-up fix?");
	cvar_keepWallSlamLongGetUp = CreateConVar("charger_keep_wall_charge_animation", "1", "Enable the long wall slam animation (with god frames)");
	cvar_keepLongChargeLongGetUp = CreateConVar("charger_keep_far_charge_animation", "0", "Enable the long 'far' slam animation (with god frames)");


	if (bLateLoad)
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i)) OnClientPutInServer(i);

}

// ==========================================
// ================= Events =================
// ==========================================

public void OnClientPutInServer(int client)
{
	bWallSlamed[client] = false;
	bInForcedGetUp[client] = false;
	bIgnoreJockeyed[client] = false;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnClientDisconnect(int client)
{
	bWallSlamed[client] = false;
	bInForcedGetUp[client] = false;
	bIgnoreJockeyed[client] = false;
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	
	if (!GetConVarBool(cvar_longChargeGetUpFixEnabled)) return;
	if (!IsClientInGame(client)) return;
	
	if (GetClientTeam(client) == TEAM_INFECTED)
	{
		ChargerTarget[client] = -1;
	}
	else if (GetClientTeam(client) == TEAM_SURVIVOR)
	{
		for (new i = 0; i < (MAXPLAYERS+1); i++)
		{
			if (ChargerTarget[i] == client)
			{
				new newChargerTarget = GetEntDataEnt2(i, 15972);
				ChargerTarget[i] = newChargerTarget;
			}
		}
	}
} 

public Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{ // Wall Slam Charge Checks

	if (!GetConVarBool(cvar_longChargeGetUpFixEnabled)) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0) return;
	new oldTeam = GetEventInt(event, "oldteam");
	
	if (oldTeam == TEAM_INFECTED)
	{ // Not really needed but better safe than sorry I guess
		ChargerTarget[client] = -1;
	}
	else if (oldTeam == TEAM_SURVIVOR)
	{
		for (new i = 0; i < (MAXPLAYERS+1); i++)
		{
			if (ChargerTarget[i] == client)
			{
				new newChargerTarget = GetEntDataEnt2(i, 15972);
				ChargerTarget[i] = newChargerTarget;
				
				if (bInForcedGetUp[client])
				{
					bInForcedGetUp[client] = false;
					bInForcedGetUp[newChargerTarget] = true;
				}
			}
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!inflictor || !IsValidEdict(victim) || !IsValidEdict(inflictor)) return;
	if (!IsCharger(attacker) || !IsSurvivor(victim)) return;
	
	static char classname[64];
	GetClientWeapon(attacker, classname, sizeof(classname));
	if (strcmp(classname, "weapon_charger_claw") != 0) return;
	
	if (damage == 10.0 && GetVectorLength(damageForce) == 0.0)
	{
		// CHARGE IMPACT
		bWallSlamed[victim] = true;
	}
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (IsSurvivor(victim))
	{
		if (bWallSlamed[victim])
		{
			bWallSlamed[victim] = false;
			if (IsPlayerAlive(victim) && !IsPlayerIncap(victim))
			{
				//int jockeyAttacker = GetJockeyAttacker(victim);
				//if (IsJockey(jockeyAttacker)) {
				//	PrintToChatAll("\x01 - \x03Checked being Jockeyed");
				//	ForceJockeyDismount(jockeyAttacker);
				//}
				ChargerTarget[attacker] = victim;
				bInForcedGetUp[victim] = true;
				PlayClientGetUpAnimation(victim);
			}
		}
	}
}

//void ForceJockeyDismount(int client)
//{
//	ExecuteCommand(client, "dismount");
//}

//void ExecuteCommand(int client, const char[] command)
//{
//	int flags = GetCommandFlags(command);
//	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
//	FakeClientCommand(client, "%s", command);
//	SetCommandFlags(command, flags);
//}

public PlayClientGetUpAnimation(client)
{
	L4D2Direct_DoAnimationEvent(client, 78);
}

public CancelGetUpAnimation(client)
{
	SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	for (new i = 0; i < MAXPLAYERS+1; i++)
	{
		bWallSlamed[i] = false;
		bInForcedGetUp[i] = false;
		bIgnoreJockeyed[i] = false;
		if (ChargerTarget[i] != -1)
			ChargerTarget[i] = -1;
	}
}

public Event_PummelStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvar_longChargeGetUpFixEnabled)) return;

	new chargerClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new survivorClient = GetClientOfUserId(GetEventInt(event, "victim"));
	
	if (survivorClient > 0 && chargerClient > 0)
	{
		ChargerTarget[chargerClient] = survivorClient;
		bInForcedGetUp[survivorClient] = false;
		bIgnoreJockeyed[survivorClient] = false;
	}
}

public Event_ChargerKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvar_longChargeGetUpFixEnabled)) return;

	new chargerClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new survivorClient = ChargerTarget[chargerClient];

	if (survivorClient > 0 && chargerClient > 0)
	{
		PrintToChatAll("\x05Event_ChargerKilled \x01- seq: \x05%i", GetEntProp(survivorClient, Prop_Send, "m_nSequence"));
		if (bInForcedGetUp[survivorClient])
		{
			bInForcedGetUp[survivorClient] = false;
			if (!bIgnoreJockeyed[survivorClient])
			{
				PrintToChatAll("\x01 - \x03Checked in forced get-up");
				CancelGetUpAnimation(survivorClient);
			}
		}
		
		if (bIgnoreJockeyed[survivorClient]) bIgnoreJockeyed[survivorClient] = false;
		
		if (IsPlayingGetUpAnimation(survivorClient, 2))
		{ // Long Charge Get Up		
			PrintToChatAll("\x05Event_ChargerKilled \x01- \x04Long Charge");
			if (GetConVarBool(cvar_keepLongChargeLongGetUp))
			{
				GiveClientGodFrames(survivorClient, GetConVarFloat(g_hChargeDuration), 6);
			}
			else
			{
				CancelGetUpAnimation(survivorClient)
				PlayClientGetUpAnimation(survivorClient);
				GiveClientGodFrames(survivorClient, GetConVarFloat(g_hLongChargeDuration), 6);
			}
		} 
		else if (IsPlayingGetUpAnimation(survivorClient, 1))
		{ // Wall Slam Get Up
			PrintToChatAll("\x05Event_ChargerKilled \x01- \x04Wall Slam");
			if (GetConVarBool(cvar_keepWallSlamLongGetUp))
			{
				GiveClientGodFrames(survivorClient, GetConVarFloat(g_hChargeDuration), 6);
			}
			else
			{
				CancelGetUpAnimation(survivorClient)
				PlayClientGetUpAnimation(survivorClient);
				GiveClientGodFrames(survivorClient, GetConVarFloat(g_hLongChargeDuration), 6);
			}
		}
		else
		{
			// There's a weird case, where the game won't register the client as playing the animation, it's once in a blue moon
			CreateTimer(0.02, BlueMoonCaseCheck, survivorClient);
		}
		
		CreateTimer(0.06, ResetChargerTarget, chargerClient);
	}
}

public Action:ResetChargerTarget(Handle:timer, client)
{
	ChargerTarget[client] = -1;
}

public Action:BlueMoonCaseCheck(Handle:timer, survivorClient)
{
	PrintToChatAll("\x05BlueMoonCaseCheck \x01- seq: \x05%i", GetEntProp(survivorClient, Prop_Send, "m_nSequence"));
	if (IsPlayingGetUpAnimation(survivorClient, 2))
	{ // Long Charge Get Up
		PrintToChatAll("\x05BlueMoonCaseCheck \x01- \x04Long Charge");
		if (GetConVarBool(cvar_keepLongChargeLongGetUp))
		{
			GiveClientGodFrames(survivorClient, GetConVarFloat(g_hChargeDuration), 6);
		}
		else
		{
			CancelGetUpAnimation(survivorClient)
			PlayClientGetUpAnimation(survivorClient);
			GiveClientGodFrames(survivorClient, GetConVarFloat(g_hLongChargeDuration), 6);
		}
	} 
	else if (IsPlayingGetUpAnimation(survivorClient, 1))
	{ // Wall Slam Get Up
		PrintToChatAll("\x05BlueMoonCaseCheck \x01- \x04Wall Slam");
		if (GetConVarBool(cvar_keepWallSlamLongGetUp))
		{
			GiveClientGodFrames(survivorClient, GetConVarFloat(g_hChargeDuration), 6);
		}
		else
		{
			CancelGetUpAnimation(survivorClient)
			PlayClientGetUpAnimation(survivorClient);
			GiveClientGodFrames(survivorClient, GetConVarFloat(g_hLongChargeDuration), 6);
		}
	}
}

public Event_ChargeCarryStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(cvar_longChargeGetUpFixEnabled)) return;

	new chargerClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new survivorClient = GetClientOfUserId(GetEventInt(event, "victim"));
	
	if (survivorClient > 0 && chargerClient > 0)
	{
		PrintToChatAll("\x01[\x05Event_ChargeCarryStart\x01] victim: %N (#%i)", survivorClient, GetClientUserId(survivorClient));
		ChargerTarget[chargerClient] = survivorClient;
	}
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{ // Wall Slam Charge Checks

	if (!GetConVarBool(cvar_longChargeGetUpFixEnabled)) return;

	new survivorClient;
	new chargerClient;
	new survivorUserId =  GetEventInt(event, "userid");
	new chargerUserId = GetEventInt(event, "attacker");
	
	if (survivorUserId)
		survivorClient = GetClientOfUserId(survivorUserId);
	if (chargerUserId)
		chargerClient = GetClientOfUserId(chargerUserId);
		
	if (!IsCharger(chargerClient) && !IsSurvivor(survivorClient)) return;
	
	ChargerTarget[chargerClient] = survivorClient; 
}

public void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
	int jockey = GetClientOfUserId(event.GetInt("userid"));
	int survivor = GetClientOfUserId(event.GetInt("victim"));
	
	if (jockey > 0 && survivor > 0)
	{
		PrintToChatAll("\x01[\x05Event_JockeyRide\x01] victim: %N (#%i)", survivor, GetClientUserId(survivor));
		bIgnoreJockeyed[survivor] = true;
	}
}

public void Event_JockeyRideEnd(Event event, const char[] name, bool dontBroadcast)
{
	int jockey = GetClientOfUserId(event.GetInt("userid"));
	int survivor = GetClientOfUserId(event.GetInt("victim"));
	
	if (jockey > 0 && survivor > 0)
	{
		PrintToChatAll("\x01[\x05Event_JockeyRideEnd\x01] victim: %N (#%i)", survivor, GetClientUserId(survivor));
		bIgnoreJockeyed[survivor] = false;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (ChargerTarget[i] == survivor) bIgnoreJockeyed[survivor] = true;
		}
	}
}

public void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	if (player > 0 && bot > 0)
	{
		if (bIgnoreJockeyed[player] && IsJockeyed(bot))
		{
			bIgnoreJockeyed[bot] = true;
		}
		bIgnoreJockeyed[player] = false;
	}
}

public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	
	if (player > 0 && bot > 0)
	{
		if (bIgnoreJockeyed[bot] && IsJockeyed(player))
		{
			bIgnoreJockeyed[player] = true;
		}
		bIgnoreJockeyed[bot] = false;
	}
}


// ==========================================
// ================= Checks =================
// ==========================================

stock GetSequenceInt(client, type)
{
	if (client < 1) return -1;

	decl String:survivorModel[PLATFORM_MAX_PATH];
	GetClientModel(client, survivorModel, sizeof(survivorModel));
	
	if(StrEqual(survivorModel, "models/survivors/survivor_coach.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_COACH;
			case 2: return SEQ_LONG_COACH;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_gambler.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_NICK;
			case 2: return SEQ_LONG_NICK;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_producer.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_ROCHELLE;
			case 2: return SEQ_LONG_ROCHELLE;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_mechanic.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_ELLIS;
			case 2: return SEQ_LONG_ELLIS;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_manager.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_LOUIS;
			case 2: return SEQ_LONG_LOUIS;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_teenangst.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_ZOEY;
			case 2: return SEQ_LONG_ZOEY;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_namvet.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_BILL;
			case 2: return SEQ_LONG_BILL;
		}
	}
	else if(StrEqual(survivorModel, "models/survivors/survivor_biker.mdl", false))
	{
		switch(type)
		{
			case 1: return SEQ_INSTANT_FRANCIS;
			case 2: return SEQ_LONG_FRANCIS;
		}
	}
	
	return -1;
}

bool:IsPlayingGetUpAnimation(survivor, type)  
{
	if (survivor < 1)
		return false;

	new sequence = GetEntProp(survivor, Prop_Send, "m_nSequence");
	if (sequence == GetSequenceInt(survivor, type)) return true;
	return false;
}

stock bool:IsCharger(client)  
{
	if (!IsInfected(client))
		return false;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_CHARGER)
		return false;

	return true;
}

stock bool IsJockey(int client)
{
	if (!IsInfected(client))
		return false;
		
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_JOCKEY)
		return false;

	return true;
}

stock bool IsJockeyed(int survivor)
{
	return IsJockey(GetJockeyAttacker(survivor));
}

stock int GetJockeyAttacker(int survivor)
{
	return GetEntDataEnt2(survivor, 16128);
}

stock bool IsPlayerIncap(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

stock bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock bool:IsInfected(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}