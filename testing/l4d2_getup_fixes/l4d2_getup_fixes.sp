/**
 * Documentations
 *
 * =========================================================================================================
 * 
 * Fundamental methods via `AnimState` (peeks into `CTerrorPlayer`):
 *    [1]. `ClearAnimationState()`: Clears all animation in play and therefore resets to normal state.
 *    [2]. `RestartMainSequence()`: Restarts the animation in play.
 *    [3]. `ResetMainActivity()`: Seems like the same as [2].
 *    [4]. `OnNextFrame_OverrideAnimation(int)`: Overrides with other animations accordingly using [1] & [2].
 * 
 * Helper variables to record info:
 *    - m_queuedPummelAttacker
 * 
 * =========================================================================================================
 * 
 * Fixes for cappers respectively:
 *    (to be done...)
 */


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <godframecontrol>

#define PLUGIN_VERSION "3.0"

public Plugin myinfo = 
{
	name = "[L4D2] Merged Get-Up Fixes",
	author = "Forgetest",
	description = "Fixes all double/missing get-up cases.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d2_getup_fixes"
#define KEY_ANIMSTATE "CTerrorPlayer::m_hAnimState"
#define KEY_CLEARANIMATIONSTATE "CTerrorPlayerAnimState::ClearAnimationState"
#define KEY_RESTARTMAINSEQUENCE "CTerrorPlayerAnimState::RestartMainSequence"
#define KEY_RESETMAINACTIVITY "CTerrorPlayerAnimState::ResetMainActivity"
#define KEY_QUEUEDPUMMELATTACKER "CTerrorPlayer->m_queuedPummelAttacker"

Handle
	g_hSDKCall_ClearAnimationState,
	g_hSDKCall_RestartMainSequence,
	g_hSDKCall_ResetMainActivity;

int
	m_hAnimState,
	m_queuedPummelAttacker;

methodmap AnimState
{
	public AnimState(int player) {
		return view_as<AnimState>(GetEntData(player, m_hAnimState, 4));
	}
	public void Assert() {
		if (view_as<Address>(this) == Address_Null)
			ThrowError("Invalid pointer to \"CTerrorPlayer::CTerrorPlayerAnimState\".");
	}
	public void ClearAnimationState() {
		this.Assert();
		SDKCall(g_hSDKCall_ClearAnimationState, this);
	}
	public void RestartMainSequence() {
		this.Assert();
		SDKCall(g_hSDKCall_RestartMainSequence, this);
	}
	public void ResetMainActivity() {
		this.Assert();
		SDKCall(g_hSDKCall_ResetMainActivity, this);
	}
}

enum 
{
	HUNTER_GETUP = 1,
	CHARGER_GETUP,
	PUNCH_GETUP,
	ROCK_GETUP
}

bool
	g_bLateLoad;

int
	g_iChargerVictim[MAXPLAYERS+1],
	g_iChargerAttacker[MAXPLAYERS+1],
	g_iQueuedGetupType[MAXPLAYERS+1],
	g_iLongChargedGetup[MAXPLAYERS+1];

ConVar
	g_hChargeDuration,
	g_hLongChargeDuration,
	cvar_keepWallSlamLongGetUp,
	cvar_keepLongChargeLongGetUp;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

void LoadSDK()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (!conf)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	m_hAnimState = GameConfGetOffset(conf, KEY_ANIMSTATE);
	if (m_hAnimState == -1)
		SetFailState("Missing offset \""...KEY_ANIMSTATE..."\"");
	
	m_queuedPummelAttacker = GameConfGetOffset(conf, KEY_QUEUEDPUMMELATTACKER);
	if (m_queuedPummelAttacker == -1)
		SetFailState("Missing offset \""...KEY_QUEUEDPUMMELATTACKER..."\"");
	
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, KEY_CLEARANIMATIONSTATE))
		SetFailState("Missing offset \""...KEY_CLEARANIMATIONSTATE..."\"");
	g_hSDKCall_ClearAnimationState = EndPrepSDKCall();
	if (!g_hSDKCall_ClearAnimationState)
		SetFailState("Failed to prepare SDKCall \""...KEY_CLEARANIMATIONSTATE..."\"");
	
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, KEY_RESTARTMAINSEQUENCE))
		SetFailState("Missing offset \""...KEY_RESTARTMAINSEQUENCE..."\"");
	g_hSDKCall_RestartMainSequence = EndPrepSDKCall();
	if (!g_hSDKCall_RestartMainSequence)
		SetFailState("Failed to prepare SDKCall \""...KEY_RESTARTMAINSEQUENCE..."\"");
	
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, KEY_RESETMAINACTIVITY))
		SetFailState("Missing offset \""...KEY_RESETMAINACTIVITY..."\"");
	g_hSDKCall_ResetMainActivity = EndPrepSDKCall();
	if (!g_hSDKCall_ResetMainActivity)
		SetFailState("Failed to prepare SDKCall \""...KEY_RESETMAINACTIVITY..."\"");
	
	delete conf;
}

public void OnPluginStart()
{
	LoadSDK();
	
	g_hChargeDuration = FindConVar("gfc_charger_duration");
	g_hLongChargeDuration = CreateConVar("gfc_long_charger_duration", "2.2", "God frame duration for long charger getup animations");
	
	cvar_keepWallSlamLongGetUp = CreateConVar("charger_keep_wall_charge_animation", "1", "Enable the long wall slam animation (with god frames)");
	cvar_keepLongChargeLongGetUp = CreateConVar("charger_keep_far_charge_animation", "0", "Enable the long 'far' slam animation (with god frames)");
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
	HookEvent("revive_success", Event_ReviveSuccess);
	HookEvent("tongue_release", Event_TongueRelease);
	HookEvent("pounce_end", Event_PounceEnd);
	HookEvent("charger_killed", Event_ChargerKilled);
	HookEvent("charger_carry_start", Event_CarryStart);
	HookEvent("charger_pummel_start", Event_PummelStart);
	HookEvent("charger_charge_end", Event_ChargeEnd);
	
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
	g_iChargerVictim[client] = -1;
	g_iChargerAttacker[client] = -1;
	g_iQueuedGetupType[client] = 0;
	g_iLongChargedGetup[client] = 0;
		
	SDKHook(client, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		g_iChargerVictim[i] = -1;
		g_iChargerAttacker[i] = -1;
		g_iQueuedGetupType[i] = 0;
		g_iLongChargedGetup[i] = 0;
	}
}

void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int replacer = GetClientOfUserId(event.GetInt("bot"));
	int replacee = GetClientOfUserId(event.GetInt("userid"));
	if (replacer && replacee)
		HandlePlayerReplace(replacer, replacee);
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	int replacer = GetClientOfUserId(event.GetInt("userid"));
	int replacee = GetClientOfUserId(event.GetInt("bot"));
	if (replacer && replacee)
		HandlePlayerReplace(replacer, replacee);
}

void HandlePlayerReplace(int replacer, int replacee)
{
	if (GetClientTeam(replacer) == 3)
	{
		if (g_iChargerVictim[replacee] != -1)
		{
			g_iChargerVictim[replacer] = g_iChargerVictim[replacee];
			g_iChargerAttacker[g_iChargerVictim[replacee]] = replacer;
			g_iChargerVictim[replacee] = -1;
		}
	}
	else
	{
		if (g_iChargerAttacker[replacee] != -1)
		{
			g_iChargerAttacker[replacer] = g_iChargerAttacker[replacee];
			g_iChargerVictim[g_iChargerAttacker[replacee]] = replacer;
			g_iChargerAttacker[replacee] = -1;
		}
		
		g_iQueuedGetupType[replacer] = g_iQueuedGetupType[replacee];
		g_iQueuedGetupType[replacee] = 0;
		g_iLongChargedGetup[replacer] = g_iLongChargedGetup[replacee];
		g_iLongChargedGetup[replacee] = 0;
	}
}


/*
 * Survivor Incap
 */

void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if (client) AnimState(client).ClearAnimationState();
}


/*
 * Smoker
 */

// Clear charger get-up animation
public Action L4D_OnGrabWithTongue(int victim, int attacker)
{
	AnimState(victim).ClearAnimationState();
	
	return Plugin_Continue;
}

// Clear hunter get-up animation
void Event_TongueRelease(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client) AnimState(client).ClearAnimationState();
}


/*
 * Hunter
 */
// Remind that the victim was pounced and should be in hunter get-up
// v2.3: check for pouncing into charger carry victims
void Event_PounceEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client && g_iChargerAttacker[client] == -1)
	{
		g_iQueuedGetupType[client] = HUNTER_GETUP;
		RequestFrame(OnNextFrame_OverrideAnimation, GetClientUserId(client));
		CreateTimer(0.04, Timer_ResetGetupInfo, GetClientUserId(client));
		//PrintToChatAll("Event_PounceEnd");
	}
}

public Action L4D_OnPouncedOnSurvivor(int victim, int attacker)
{
	int charger = GetEntPropEnt(victim, Prop_Send, "m_carryAttacker");
	if (charger != -1)
	{
		g_iChargerVictim[charger] = victim;
		g_iChargerAttacker[victim] = charger;
		g_iLongChargedGetup[victim] = 0;
	}
	
	if (g_iChargerAttacker[victim] == -1)
	{
		AnimState(victim).ClearAnimationState();
	}
	
	return Plugin_Continue;
}


/*
 * Charger & Tank
 */
// 1. Handle self-clear levels
// 2. Check if the victim was slammed and therefore should be in charger get-up
void Event_ChargerKilled(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client)
	{
		int victim = g_iChargerVictim[client];
		if (victim != -1)
		{
			if (GetEntPropEnt(victim, Prop_Send, "m_pounceAttacker") == -1)
			{
				int attacker = GetClientOfUserId(event.GetInt("attacker"));
				if (attacker && victim == attacker)
				{
					AnimState(victim).ClearAnimationState();
				}
				else 
				{
					g_iQueuedGetupType[victim] = CHARGER_GETUP;
					
					if (g_iLongChargedGetup[victim])
					{
						if( (!cvar_keepWallSlamLongGetUp.BoolValue && g_iLongChargedGetup[victim] == 1) 
							|| (!cvar_keepLongChargeLongGetUp.BoolValue && g_iLongChargedGetup[victim] == 2) )
						{
							g_iLongChargedGetup[victim] = 0;
							//PrintToChatAll("No long animation (isLong = %s)", g_iLongChargedGetup[victim] == 2 ? "true" : "false");
							GiveClientGodFrames(victim, g_hChargeDuration.FloatValue, 6);
						}
						else
						{
							//PrintToChatAll("Yes long animation (isLong = %s)", g_iLongChargedGetup[victim] == 2 ? "true" : "false");
							GiveClientGodFrames(victim, g_hLongChargeDuration.FloatValue, 6);
						}
					}
					
					//PrintToChatAll("Normal charger getup animation");
					RequestFrame(OnNextFrame_OverrideAnimation, GetClientUserId(victim));
					CreateTimer(0.04, Timer_ResetGetupInfo, GetClientUserId(victim));
				}
			}
			
			g_iChargerAttacker[victim] = -1;
			g_iChargerVictim[client] = -1;
		}
	}
}

Action Timer_ResetGetupInfo(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	g_iQueuedGetupType[client] = 0;
	g_iLongChargedGetup[client] = 0;
	return Plugin_Stop;
}

// Clear jockeyed animation so charger get-up can be played
void Event_CarryStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client) AnimState(client).ClearAnimationState();
}

void Event_PummelStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client) g_iLongChargedGetup[client] = 0;
}

// Clear all other animation so charger slammed can be played
void Event_ChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && g_iChargerVictim[client] != -1 && GetQueuedPummelAttacker(g_iChargerVictim[client]) != -1)
	{
		static ConVar z_charge_duration = null;
		if (z_charge_duration == null)
			z_charge_duration = FindConVar("z_charge_duration");
		
		int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
		if (GetGameTime() - GetEntPropFloat(ability, Prop_Send, "m_chargeStartTime") >= z_charge_duration.FloatValue)
			g_iLongChargedGetup[g_iChargerVictim[client]] = 2;
		else
			g_iLongChargedGetup[g_iChargerVictim[client]] = 1;
	}
	//PrintToChatAll("Event_ChargeEnd");
}

Action SDK_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!attacker || attacker > MaxClients)
		return Plugin_Continue;
	
	if (GetClientTeam(victim) != 2 || GetClientTeam(attacker) != 3)
		return Plugin_Continue;
	
	switch (GetEntProp(attacker, Prop_Send, "m_zombieClass"))
	{
		case 8:
		{
			static char cls[64];
			GetEdictClassname(inflictor, cls, sizeof(cls));
			if (strcmp(cls, "tank_rock") == 0)
			{
				if (GetEntPropEnt(victim, Prop_Send, "m_pummelAttacker") == -1
				&& GetEntPropEnt(victim, Prop_Send, "m_carryAttacker") == -1
				&& GetEntPropEnt(victim, Prop_Send, "m_pounceAttacker") == -1
				&& GetQueuedPummelAttacker(victim) == -1)
				{
					if (g_iQueuedGetupType[victim] == 0)
					{
						g_iQueuedGetupType[victim] = ROCK_GETUP;
						CreateTimer(0.04, Timer_ResetGetupInfo, GetClientUserId(victim));
					}
					RequestFrame(OnNextFrame_OverrideAnimation, GetClientUserId(victim));
				}
			}
		}
		case 6:
		{
			if (RoundToFloor(damage) == 10 && GetVectorLength(damageForce) == 0.0)
			{
				g_iChargerVictim[attacker] = victim;
				g_iChargerAttacker[victim] = attacker;
			}
		}
	}
	
	return Plugin_Continue;
}

void OnNextFrame_OverrideAnimation(int userid)
{
	int client = GetClientOfUserId(userid);
	if (client && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client) && !L4D_IsPlayerHangingFromLedge(client) && GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") == -1)
	{
		AnimState hAnimState = AnimState(client);
		
		int animation;
		if (g_iQueuedGetupType[client] == HUNTER_GETUP)
		{
			animation = 86; // ANIM_HUNTER_GETUP
		}
		else if (g_iQueuedGetupType[client] == CHARGER_GETUP)
		{
			switch (g_iLongChargedGetup[client])
			{
				case 0: animation = 78; // ANIM_CHARGER_GETUP
				case 1: animation = 80; // ANIM_CHARGER_SLAMMED
				case 2: animation = 81; // ANIM_CHARGER_LONG_SLAMMED
			}
		}
		else if (g_iQueuedGetupType[client] != 0)
		{
			animation = 96; // ANIM_TANK_PUNCH_GETUP;
		}
		
		if (animation)
		{
			hAnimState.ClearAnimationState();
			
			if (animation == 86)
			{
				float fVel[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVel);
				
				// hunter get-up cancelled if velocity > 50.0
				if (NormalizeVector(fVel, fVel) > 50.0)
				{
					ScaleVector(fVel, 50.0);
					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
				}
			}
			
			L4D2Direct_DoAnimationEvent(client, animation);
			//PrintToChatAll("OverrideAnimation: %N, %i", client, animation);
			
			hAnimState.ResetMainActivity();
		}
	}
}

// Stop tank queuing stumbles to victims being pummeled
public Action L4D_TankClaw_OnPlayerHit_Pre(int tank, int claw, int player)
{
	//PrintToChatAll("L4D_TankClaw_OnPlayerHit_Pre: %N", player);
	if (GetClientTeam(player) == 2)
	{
		if (GetEntPropEnt(player, Prop_Send, "m_pummelAttacker") != -1
		|| GetEntPropEnt(player, Prop_Send, "m_carryAttacker") != -1
		|| GetEntPropEnt(player, Prop_Send, "m_pounceAttacker") != -1
		|| GetQueuedPummelAttacker(player) != -1)
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public void L4D_TankClaw_OnPlayerHit_Post(int tank, int claw, int player)
{
	if (GetClientTeam(player) == 2)
	{
		//PrintToChatAll("L4D_TankClaw_OnPlayerHit_Post");
		if (GetEntPropEnt(player, Prop_Send, "m_pummelAttacker") != -1
		|| GetEntPropEnt(player, Prop_Send, "m_carryAttacker") != -1
		|| GetEntPropEnt(player, Prop_Send, "m_pounceAttacker") != -1
		|| GetQueuedPummelAttacker(player) != -1)
		{
			//PrintToChatAll("L4D_TankClaw_OnPlayerHit_Post: block");
			return;
		}
		
		AnimState(player).ClearAnimationState();
		if (g_iQueuedGetupType[player] == 0)
		{
			g_iQueuedGetupType[player] = PUNCH_GETUP;
			CreateTimer(0.04, Timer_ResetGetupInfo, GetClientUserId(player));
		}
		RequestFrame(OnNextFrame_OverrideAnimation, GetClientUserId(player));
	}
}

stock int GetQueuedPummelAttacker(int client)
{
	return GetEntDataEnt2(client, m_queuedPummelAttacker);
}
