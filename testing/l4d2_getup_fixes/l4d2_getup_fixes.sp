#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define GAMEDATA_FILE "l4d2_getup_fixes"
#define KEY_ANIMSTATE "CTerrorPlayerAnimState::m_hAnimState"
#define KEY_CLEARANIMATIONSTATE "CTerrorPlayerAnimState::ClearAnimationState"
#define KEY_RESTARTMAINSEQUENCE "CTerrorPlayerAnimState::RestartMainSequence"
#define KEY_ISGETTINGUP "CTerrorPlayer::IsGettingUp"

Handle
	g_hSDKCall_ClearAnimationState,
	g_hSDKCall_RestartMainSequence;

int m_hAnimState;

methodmap CTerrorPlayerAnimState
{
	public CTerrorPlayerAnimState(int player) {
		return view_as<CTerrorPlayerAnimState>(GetEntData(player, m_hAnimState, 4));
	}
	public void ClearAnimationState() {
		if (view_as<Address>(this) == Address_Null)
			ThrowError("Invalid pointer to \"CTerrorPlayer::CTerrorPlayerAnimState\".");
		
		SDKCall(g_hSDKCall_ClearAnimationState, this);
	}
	public void RestartMainSequence() {
		if (view_as<Address>(this) == Address_Null)
			ThrowError("Invalid pointer to \"CTerrorPlayer::CTerrorPlayerAnimState\".");
		
		SDKCall(g_hSDKCall_RestartMainSequence, this);
	}
}

bool
	g_bLateLoad;

int
	g_iChargerVictim[MAXPLAYERS+1],
	g_iChargerAttacker[MAXPLAYERS+1],
	g_iWasPouncedOrPummeled[MAXPLAYERS+1];

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
	
	delete conf;
}

public void OnPluginStart()
{
	LoadSDK();
	
	HookEvent("tongue_release", Event_TongueRelease);
	HookEvent("pounce_end", Event_PounceEnd);
	HookEvent("lunge_pounce", Event_LungePounce);
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
	g_iWasPouncedOrPummeled[client] = 0;
	
	SDKHook(client, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
}


/*
 * Smoker
 */

// Clear charger get-up animation
public Action L4D_OnGrabWithTongue(int victim, int attacker)
{
	CTerrorPlayerAnimState(victim).ClearAnimationState();
	
	return Plugin_Continue;
}

// Clear hunter get-up animation
void Event_TongueRelease(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"))
	if (client) CTerrorPlayerAnimState(client).ClearAnimationState();
}


/*
 * Hunter
 */
// Remind that the victim was pounced and should be in hunter get-up
void Event_PounceEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"))
	if (client)
	{
		g_iWasPouncedOrPummeled[client] = 1;
		CreateTimer(0.04, Timer_ResetCappedInfo, client);
	}
}

// Lunge into survivor that is charged
void Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client)
	{
		if (GetEntProp(client, Prop_Send, "m_carryAttacker") != -1 || g_iChargerAttacker[client] != -1)
		{
			CTerrorPlayerAnimState(client).ClearAnimationState();
			L4D2Direct_DoAnimationEvent(client, 80); // ANIM_CHARGER_SLAMMED
		}
	}
}

// Clear jockeyed animation so hunter get-up can be played
public Action L4D_OnPouncedOnSurvivor(int victim, int attacker)
{
	if (GetEntProp(victim, Prop_Send, "m_jockeyAttacker") != -1)
	{
		CTerrorPlayerAnimState(victim).ClearAnimationState();
	}
	
	return Plugin_Continue;
}


/*
 * Charger & Tank
 */
// 1. Handle self-clear levels
// 2. Remind that the victim was pummeled
void Event_ChargerKilled(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (victim)
	{
		int attacker = GetClientOfUserId(event.GetInt("attacker"));
		//PrintToChatAll("Event_ChargerKilled: %N, %i", victim, attacker);
		if (attacker && g_iChargerVictim[victim] == attacker)
		{
			CTerrorPlayerAnimState(attacker).ClearAnimationState();
		}
		
		if (g_iChargerVictim[victim] != -1)
		{
			g_iWasPouncedOrPummeled[g_iChargerVictim[victim]] = 2;
			CreateTimer(0.04, Timer_ResetCappedInfo, g_iChargerVictim[victim]);
			g_iChargerAttacker[g_iChargerVictim[victim]] = -1;
		}
		
		g_iChargerVictim[victim] = -1;
	}
}

Action Timer_ResetCappedInfo(Handle timer, int client)
{
	g_iWasPouncedOrPummeled[client] = 0;
	return Plugin_Stop;
}

// Clear jockeyed animation so charger get-up can be played
void Event_CarryStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client) CTerrorPlayerAnimState(client).ClearAnimationState();
}

// Clear tanked animation to prevent double get-ups
void Event_PummelStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client) CTerrorPlayerAnimState(client).ClearAnimationState();
}

// Clear all other animation so charger slammed can be played
void Event_ChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && g_iChargerVictim[client] != -1)
	{
		//PrintToChatAll("Event_ChargeEnd: %N", client);
		RequestFrame(OnNextFrame_OverrideAnimation, GetClientUserId(g_iChargerVictim[client]));
	}
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
			if (strcmp(cls, "weapon_tank_claw") == 0 || strcmp(cls, "tank_rock") == 0)
			{
				if (GetEntPropEnt(victim, Prop_Send, "m_pummelAttacker") == -1
				&& GetEntPropEnt(victim, Prop_Send, "m_carryAttacker") == -1
				&& GetEntPropEnt(victim, Prop_Send, "m_pounceAttacker") == -1)
					RequestFrame(OnNextFrame_OverrideAnimation, GetClientUserId(victim));
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
	if (client && GetClientTeam(client) == 2 && IsPlayerAlive(client) && GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") == -1)
	{
		CTerrorPlayerAnimState hAnimState = CTerrorPlayerAnimState(client);
		hAnimState.ClearAnimationState();
		
		int animation;
		if (g_iChargerAttacker[client] != -1 && GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") == -1)
			animation = 80; // ANIM_CHARGER_SLAMMED
		else if (g_iWasPouncedOrPummeled[client] == 1)
			animation = 86;
		else if (g_iWasPouncedOrPummeled[client] == 2)
			animation = 78;
		else
			animation = 96;
		
		L4D2Direct_DoAnimationEvent(client, animation);
		//PrintToChatAll("OverrideAnimation: %N, %i", client, animation);
		
		hAnimState.RestartMainSequence();
	}
}

public Action L4D_TankClaw_OnPlayerHit_Pre(int tank, int claw, int player)
{
	if (GetClientTeam(player) == 2 && GetEntPropEnt(player, Prop_Send, "m_pummelAttacker") != -1)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
