/**
 * Documentation
 *
 * =========================================================================================================
 * 
 * Methods of `CTerrorPlayerAnimState` (peeks into `CTerrorPlayer`):
 *    [1]. `ResetMainActivity()`: Invoke recalculation of animation to be played.
 *
 * Flags of `CTerrorPlayerAnimState`:
 *    See `AnimStateFlag` for an incomplete list.
 * 
 * =========================================================================================================
 * 
 * Fixes for cappers respectively:
 *
 *    Smoker:
 *      1) [DISABLED] Charged get-ups keep playing during pull.			(Event_TongueGrab)
 *      2) [DISABLED] Punch/Rock get-up keeps playing during pull.		(Event_TongueGrab)
 *      3) Hunter get-up replayed when pull released.					(Event_TongueGrab)
 *
 *    Jockey:
 *      1) No get-up if forced off by any other capper.					(Event_JockeyRideEnd)
 *      2) Bowling/Wallslam get-up keeps playing during ride.			(Event_JockeyRide)
 *    
 *    Hunter:
 *      1) Double get-up when pounce on charger victims.				(Event_ChargerPummelStart Event_ChargerKilled)
 *      2) Bowling/Pummel/Slammed get-up keeps playing when pounced.	(Event_LungePounce)
 *      3) Punch/Rock get-up keeps playing when pounced.				(Event_LungePounce)
 *    
 *    Charger:
 *      1) Prevent get-up for self-clears.								(Event_ChargerKilled)
 *      2) Fix no godframe for long get-up.								(Event_ChargerKilled)
 *      3) Punch/Charger get-up keeps playing during carry.				(Event_ChargerCarryStart)
 *      4) Fix possible slammed get-up not playing on instant slam.		(SDK_OnTakeDamage)
 *    
 *    Tank:
 *      1) Double get-up if punch/rock on chargers with victims to die.	(OnPlayerHit_Post OnKnockedDown_Post)
 *         Do not play punch/rock get-up to keep consistency.
 *      2) No get-up if do rock-punch combo.							(OnPlayerHit_Post OnKnockedDown_Post)
 *      3) Double get-up if punch/rock on survivors in bowling.			(OnPlayerHit_Post OnKnockedDown_Post)
 */


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <left4dhooks>
#include <l4d2util_constants>

native void GiveClientGodFrames(int client, float time, int zclass);

#define PLUGIN_VERSION "4.20"

public Plugin myinfo = 
{
	name = "[L4D2] Merged Get-Up Fixes",
	author = "Forgetest",
	description = "Fixes all double/missing get-up cases.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

enum struct SDKCallParamsWrapper {
	SDKType type;
	SDKPassMethod pass;
	int decflags;
	int encflags;
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	property GameData Super {
		public get() { return view_as<GameData>(this); }
	}
	public int GetOffset(const char[] key) {
		int offset = this.Super.GetOffset(key);
		if (offset == -1) SetFailState("Missing offset \"%s\"", key);
		return offset;
	}
	public DynamicDetour CreateDetourOrFail(
			const char[] name,
			DHookCallback preHook = INVALID_FUNCTION,
			DHookCallback postHook = INVALID_FUNCTION) {
		DynamicDetour hSetup = DynamicDetour.FromConf(this, name);
		if (!hSetup)
			SetFailState("Missing detour setup \"%s\"", name);
		if (preHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Pre, preHook))
			SetFailState("Failed to pre-detour \"%s\"", name);
		if (postHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Post, postHook))
			SetFailState("Failed to post-detour \"%s\"", name);
		return hSetup;
	}
	public Handle CreateSDKCallOrFail(
			SDKCallType type,
			SDKFuncConfSource src,
			const char[] name,
			const SDKCallParamsWrapper[] params = {},
			int numParams = 0,
			bool hasReturnValue = false,
			const SDKCallParamsWrapper ret = {}) {
		static const char k_sSDKFuncConfSource[SDKFuncConfSource][] = { "offset", "signature", "address" };
		Handle result;
		StartPrepSDKCall(type);
		if (!PrepSDKCall_SetFromConf(this, src, name))
			SetFailState("Missing %s \"%s\"", k_sSDKFuncConfSource[src], name);
		for (int i = 0; i < numParams; ++i)
			PrepSDKCall_AddParameter(params[i].type, params[i].pass, params[i].decflags, params[i].encflags);
		if (hasReturnValue)
			PrepSDKCall_SetReturnInfo(ret.type, ret.pass, ret.decflags, ret.encflags);
		if (!(result = EndPrepSDKCall()))
			SetFailState("Failed to prep sdkcall \"%s\"", name);
		return result;
	}
}

Handle
	g_hSDKCall_ResetMainActivity;

int
	m_PlayerAnimState,
	m_bCharged;

enum AnimStateFlag // mid-way start from m_bCharged
{
	AnimState_Charged			= 0, // aka multi-charged
	AnimState_WallSlammed		= 2,
	AnimState_GroundSlammed		= 3,
	AnimState_Pounded			= 5, // Pummel get-up
	AnimState_TankPunched		= 7, // Rock get-up shares this
	AnimState_Pounced			= 9,
	AnimState_RiddenByJockey	= 14
}

methodmap AnimState
{
	public AnimState(int client) {
		int ptr = GetEntData(client, m_PlayerAnimState, 4);
		if (ptr == 0)
			ThrowError("Invalid pointer to \"CTerrorPlayer::CTerrorPlayerAnimState\" (client %d).", client);
		return view_as<AnimState>(ptr);
	}
	public void ResetMainActivity() { SDKCall(g_hSDKCall_ResetMainActivity, this); }
	public bool GetFlag(AnimStateFlag flag) {
		return view_as<bool>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(m_bCharged) + view_as<Address>(flag), NumberType_Int8));
	}
	public void SetFlag(AnimStateFlag flag, bool val) {
		StoreToAddress(view_as<Address>(this) + view_as<Address>(m_bCharged) + view_as<Address>(flag), view_as<int>(val), NumberType_Int8);
	}
}

bool
	g_bLateLoad,
	g_bGodframeControl;

int
	g_iChargeVictim[MAXPLAYERS+1] = {-1, ...},
	g_iChargeAttacker[MAXPLAYERS+1] = {-1, ...};

float 
	g_fLastChargedEndTime[MAXPLAYERS+1];

ConVar 
	g_hChargeDuration,
	g_hLongChargeDuration,
	cvar_keepWallSlamLongGetUp,
	cvar_keepLongChargeLongGetUp,
	g_cvGetupRestore;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	
	MarkNativeAsOptional("GiveClientGodFrames");

	return APLRes_Success;
}

void LoadSDK()
{
	GameDataWrapper gd = new GameDataWrapper("l4d2_getup_fixes");
	m_PlayerAnimState = gd.GetOffset("CTerrorPlayer::m_PlayerAnimState");
	m_bCharged = gd.GetOffset("CTerrorPlayerAnimState::m_bCharged");
	g_hSDKCall_ResetMainActivity = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Virtual, "CTerrorPlayerAnimState::ResetMainActivity");
	delete gd.CreateDetourOrFail("SurvivorReplacement::Save", DTR_SurvivorReplacement_Save);
	delete gd.CreateDetourOrFail("SurvivorReplacement::Restore", _, DTR_SurvivorReplacement_Restore_Post);
	delete gd.CreateDetourOrFail("CCSPlayer::SetModelIndex", DTR_SetModelIndex, DTR_SetModelIndex_Post);
	delete gd;
}

public void OnPluginStart()
{
	LoadSDK();
	
	g_hLongChargeDuration = CreateConVar("gfc_long_charger_duration", "2.2", "God frame duration for long charger getup animations");
	
	cvar_keepWallSlamLongGetUp = CreateConVar("charger_keep_wall_charge_animation", "1", "Enable the long wall slam animation (with god frames)");
	cvar_keepLongChargeLongGetUp = CreateConVar("charger_keep_far_charge_animation", "0", "Enable the long 'far' slam animation (with god frames)");
	
	g_cvGetupRestore = CreateConVar("getup_restore_replace", "1", "Restore get-up after survivor replacement", FCVAR_NONE, true, 0.0, true, 1.0);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
	HookEvent("revive_success", Event_ReviveSuccess);
	HookEvent("tongue_grab", Event_TongueGrab);
	HookEvent("lunge_pounce", Event_LungePounce);
	HookEvent("jockey_ride", Event_JockeyRide);
	HookEvent("jockey_ride_end", Event_JockeyRideEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("charger_carry_start", Event_ChargerCarryStart);
	HookEvent("charger_pummel_start", Event_ChargerPummelStart);
	HookEvent("charger_pummel_end", Event_ChargerPummelEnd);
	HookEvent("charger_killed", Event_ChargerKilled);
	
	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i)) OnClientPutInServer(i);
		}
	}
}

public void OnAllPluginsLoaded()
{
	g_bGodframeControl = LibraryExists("l4d2_godframes_control_merge");
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "l4d2_godframes_control_merge") == 0)
		g_bGodframeControl = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "l4d2_godframes_control_merge") == 0)
		g_bGodframeControl = false;
}

public void OnConfigsExecuted()
{
	if (g_bGodframeControl)
	{
		g_hChargeDuration = FindConVar("gfc_charger_duration");
	}
}

public void OnClientPutInServer(int client)
{
	g_iChargeVictim[client] = -1;
	g_iChargeAttacker[client] = -1;
	g_fLastChargedEndTime[client] = 0.0;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		g_iChargeVictim[i] = -1;
		g_iChargeAttacker[i] = -1;
		g_fLastChargedEndTime[i] = 0.0;
	}
}

void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int replacer = GetClientOfUserId(event.GetInt("bot"));
	int replacee = GetClientOfUserId(event.GetInt("player"));
	if (replacer && replacee)
		HandlePlayerReplace(replacer, replacee);
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	int replacer = GetClientOfUserId(event.GetInt("player"));
	int replacee = GetClientOfUserId(event.GetInt("bot"));
	if (replacer && replacee)
		HandlePlayerReplace(replacer, replacee);
}

void HandlePlayerReplace(int client, int replaced)
{
	if (GetClientTeam(client) == 3)
	{
		if (g_iChargeVictim[replaced] != -1)
		{
			g_iChargeVictim[client] = g_iChargeVictim[replaced];
			g_iChargeAttacker[g_iChargeVictim[replaced]] = client;
			g_iChargeVictim[replaced] = -1;
		}
	}
	else
	{
		if (g_iChargeAttacker[replaced] != -1)
		{
			g_iChargeAttacker[client] = g_iChargeAttacker[replaced];
			g_iChargeVictim[g_iChargeAttacker[replaced]] = client;
			g_iChargeAttacker[replaced] = -1;
		}
	}
}

enum struct GetupRestore
{
	float cycle;
	AnimStateFlag flag;
	float pummelTime;
}
GetupRestore g_GetupRestore[MAXPLAYERS+1];

MRESReturn DTR_SurvivorReplacement_Save(DHookParam hParams)
{
	if (hParams.IsNull(1))
		return MRES_Ignored;
	
	int replaced = hParams.Get(1);
	AnimState anim = AnimState(replaced);

	if (anim.GetFlag(AnimState_Charged))
		g_GetupRestore[replaced].flag = AnimState_Charged;
	else if (anim.GetFlag(AnimState_GroundSlammed))
		g_GetupRestore[replaced].flag = cvar_keepLongChargeLongGetUp.BoolValue ? AnimState_GroundSlammed : AnimState_Pounded;
	else if (anim.GetFlag(AnimState_WallSlammed))
		g_GetupRestore[replaced].flag = cvar_keepWallSlamLongGetUp.BoolValue ? AnimState_WallSlammed : AnimState_Pounded;
	else if (anim.GetFlag(AnimState_TankPunched))
		g_GetupRestore[replaced].flag = AnimState_TankPunched;
	else if (anim.GetFlag(AnimState_Pounced))
		g_GetupRestore[replaced].flag = AnimState_Pounced;
	else if (anim.GetFlag(AnimState_Pounded))
		g_GetupRestore[replaced].flag = AnimState_Pounded;
	else
	{
		g_GetupRestore[replaced].cycle = -1.0;
		return MRES_Ignored;
	}

	g_GetupRestore[replaced].cycle = GetEntPropFloat(replaced, Prop_Send, "m_flCycle");

	g_GetupRestore[replaced].pummelTime = -1.0;
	int attacker = L4D2_GetQueuedPummelAttacker(replaced);
	if (attacker != -1)
		g_GetupRestore[replaced].pummelTime = L4D2_GetQueuedPummelStartTime(attacker);

	// PrintToChatAll("%d Save %N %d %.2f", GetGameTickCount(), replaced, g_GetupRestore[replaced].flag, g_GetupRestore[replaced].cycle);

	return MRES_Ignored;
}

MRESReturn DTR_SurvivorReplacement_Restore_Post(DHookParam hParams)
{
	if (hParams.IsNull(1) || hParams.IsNull(2))
		return MRES_Ignored;
	
	int replaced = hParams.Get(1);
	int client = hParams.Get(2);

	if (g_GetupRestore[replaced].cycle == -1.0)
		return MRES_Ignored;

	if (g_cvGetupRestore.BoolValue)
	{
		if (L4D2_GetQueuedPummelAttacker(client) != -1)
		{
			int attacker = L4D2_GetQueuedPummelAttacker(client);
			if (g_GetupRestore[replaced].pummelTime != -1.0)
				L4D2_SetQueuedPummelStartTime(attacker, g_GetupRestore[replaced].pummelTime);
		}

		AnimState anim = AnimState(client);
		anim.SetFlag(g_GetupRestore[replaced].flag, true);

		g_GetupRestore[client] = g_GetupRestore[replaced];
		SDKHook(client, SDKHook_PostThinkPost, SDK_OnPostThink_Post_Once);
	}

	// PrintToChatAll("%d Restore %N %d %.2f", GetGameTickCount(), client, g_GetupRestore[client].flag, g_GetupRestore[client].cycle);
	return MRES_Ignored;
}

MRESReturn DTR_SetModelIndex(int client, DHookParam hParams)
{
	if (client == -1)
		return MRES_Ignored;

	AnimState anim = AnimState(client);

	if (anim.GetFlag(AnimState_Charged))
		g_GetupRestore[client].flag = AnimState_Charged;
	else if (anim.GetFlag(AnimState_GroundSlammed))
		g_GetupRestore[client].flag = cvar_keepLongChargeLongGetUp.BoolValue ? AnimState_GroundSlammed : AnimState_Pounded;
	else if (anim.GetFlag(AnimState_WallSlammed))
		g_GetupRestore[client].flag = cvar_keepWallSlamLongGetUp.BoolValue ? AnimState_WallSlammed : AnimState_Pounded;
	else if (anim.GetFlag(AnimState_TankPunched))
		g_GetupRestore[client].flag = AnimState_TankPunched;
	else if (anim.GetFlag(AnimState_Pounced))
		g_GetupRestore[client].flag = AnimState_Pounced;
	else if (anim.GetFlag(AnimState_Pounded))
		g_GetupRestore[client].flag = AnimState_Pounded;
	else
	{
		g_GetupRestore[client].cycle = -1.0;
		return MRES_Ignored;
	}

	g_GetupRestore[client].cycle = GetEntPropFloat(client, Prop_Send, "m_flCycle");

	// PrintToChatAll("%d SetModelIndex %N %d %.2f", GetGameTickCount(), client, g_GetupRestore[client].flag, g_GetupRestore[client].cycle);

	return MRES_Ignored;
}

MRESReturn DTR_SetModelIndex_Post(int client, DHookParam hParams)
{
	if (client == -1)
		return MRES_Ignored;

	if (g_GetupRestore[client].cycle == -1.0)
		return MRES_Ignored;

	if (g_cvGetupRestore.BoolValue)
	{
		AnimState anim = AnimState(client);
		anim.SetFlag(g_GetupRestore[client].flag, true);

		SDKHook(client, SDKHook_PostThinkPost, SDK_OnPostThink_Post_Once);
	}

	// PrintToChatAll("%d SetModelIndex_Post %N %d %.2f", GetGameTickCount(), client, g_GetupRestore[client].flag, g_GetupRestore[client].cycle);
	return MRES_Ignored;
}

void SDK_OnPostThink_Post_Once(int client)
{
	SDKUnhook(client, SDKHook_PostThinkPost, SDK_OnPostThink_Post_Once);

	if (GetClientTeam(client) != 2
	 || L4D_IsPlayerIncapacitated(client)
	 || !IsPlayerAlive(client))
		return;

	AnimState anim = AnimState(client);
	if (!anim.GetFlag(g_GetupRestore[client].flag))
		return;
	
	SetEntPropFloat(client, Prop_Send, "m_flCycle", g_GetupRestore[client].cycle);
	// PrintToChatAll("%d PostThink %N %d %.2f", GetGameTickCount(), client, g_GetupRestore[client].flag, g_GetupRestore[client].cycle);
}


/**
 * Survivor Incap
 */
void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if (client)
	{
		// Clear all get-up flags
		AnimState pAnim = AnimState(client);
		pAnim.SetFlag(AnimState_GroundSlammed, false);
		pAnim.SetFlag(AnimState_WallSlammed, false);
		pAnim.SetFlag(AnimState_Pounded, false); // probably no need
		pAnim.SetFlag(AnimState_Pounced, false); // probably no need
	}
}


/**
 * Smoker
 */
void Event_TongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client)
	{
		AnimState pAnim = AnimState(client);
		
		// Fix double get-up
		pAnim.SetFlag(AnimState_Pounced, false);
		
		// Commented to prevent unexpected buff
		
		// Fix get-up keeps playing
		//pAnim.SetFlag(AnimState_GroundSlammed, false);
		//pAnim.SetFlag(AnimState_WallSlammed, false);
		//pAnim.SetFlag(AnimState_TankPunched, false);
		//pAnim.SetFlag(AnimState_Pounded, false);
		//pAnim.SetFlag(AnimState_Charged, false);
	}
}


/**
 * Hunter
 */
void Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client)
	{
		AnimState pAnim = AnimState(client);
		
		// Fix get-up keeps playing
		pAnim.SetFlag(AnimState_TankPunched, false);
		pAnim.SetFlag(AnimState_Charged, false);
		pAnim.SetFlag(AnimState_Pounded, false);
		pAnim.SetFlag(AnimState_WallSlammed, false);
	}
}


/**
 * Jockey
 */
void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client)
	{
		// Fix get-up keeps playing
		AnimState pAnim = AnimState(client);
		pAnim.SetFlag(AnimState_Charged, false);
		pAnim.SetFlag(AnimState_WallSlammed, false);
	}
}

void Event_JockeyRideEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client)
	{
		// Fix no get-up
		AnimState(client).SetFlag(AnimState_RiddenByJockey, false);
	}
}


/**
 * Charger
 */
void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;
	
	int attacker = g_iChargeAttacker[client];
	if (attacker == -1)
		return;
	
	g_iChargeVictim[attacker] = -1;
	g_iChargeAttacker[client] = -1;
}

void Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (victim)
	{
		AnimState pAnim = AnimState(victim);
		
		// Fix get-up keeps playing
		pAnim.SetFlag(AnimState_TankPunched, false);
		
		/**
		 * FIXME:
		 * Tiny workaround for multiple chargers, but still glitchy.
		 * I would think charging victims away from other chargers
		 * is really an undefined behavior, better block it.
		 */
		pAnim.SetFlag(AnimState_Charged, false);
		pAnim.SetFlag(AnimState_Pounded, false);
		pAnim.SetFlag(AnimState_GroundSlammed, false);
		pAnim.SetFlag(AnimState_WallSlammed, false);
	}
}

// Take care of pummel transition and self-clears
void Event_ChargerKilled(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;
	
	int victim = g_iChargeVictim[client];
	if (victim == -1 || !IsClientInGame(victim))
		return;
	
	AnimState pAnim = AnimState(victim);
	
	// Chances that hunter pounces right on survivor queued for pummel
	if (GetEntPropEnt(victim, Prop_Send, "m_pounceAttacker") != -1)
	{
		// Fix double get-up
		pAnim.SetFlag(AnimState_GroundSlammed, false);
		pAnim.SetFlag(AnimState_WallSlammed, false);
	}
	else
	{
		int attacker = GetClientOfUserId(event.GetInt("attacker"));
		if (attacker && victim == attacker)
		{
			if (!L4D_IsPlayerIncapacitated(victim))
			{
				// No self-clear get-up
				pAnim.SetFlag(AnimState_GroundSlammed, false);
				pAnim.SetFlag(AnimState_WallSlammed, false);
			}
		}
		else
		{
			// long charged get-up
			float flElaspedAnimTime = 0.0;
			if (
				(pAnim.GetFlag(AnimState_GroundSlammed)
			  && ((flElaspedAnimTime = 119 / 30.0), // ACT_TERROR_SLAMMED_GROUND - frames: 119, fps: 30
					cvar_keepLongChargeLongGetUp.BoolValue))
			||
				(pAnim.GetFlag(AnimState_WallSlammed)
			  && ((flElaspedAnimTime = 116 / 30.0), // ACT_TERROR_SLAMMED_WALL - frames: 116, fps: 30
					cvar_keepWallSlamLongGetUp.BoolValue))
			) {
				flElaspedAnimTime *= GetEntPropFloat(victim, Prop_Send, "m_flCycle");
				SetInvulnerableForSlammed(victim, g_hLongChargeDuration.FloatValue - flElaspedAnimTime);
			}
			else
			{
				if (pAnim.GetFlag(AnimState_GroundSlammed) || pAnim.GetFlag(AnimState_WallSlammed))
				{
					float duration = 2.0;
					if (g_hChargeDuration != null)
					{
						duration = g_hChargeDuration.FloatValue;
					}
					SetInvulnerableForSlammed(victim, duration);
				}
				L4D2Direct_DoAnimationEvent(victim, ANIM_CHARGER_GETUP);
			}
			
			g_fLastChargedEndTime[victim] = GetGameTime();
		}
	}
	
	g_iChargeVictim[client] = -1;
	g_iChargeAttacker[victim] = -1;
}

// Pounces on survivors being carried will invoke this instantly.
void Event_ChargerPummelStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (client && victim)
	{
		g_iChargeVictim[client] = victim;
		g_iChargeAttacker[victim] = client;
	}
}

void Event_ChargerPummelEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (client && victim)
	{
		AnimState pAnim = AnimState(victim);
		
		// Fix double get-up
		pAnim.SetFlag(AnimState_TankPunched, false);
		pAnim.SetFlag(AnimState_Pounced, false);
		
		// Normal processes don't need special care
		g_iChargeVictim[client] = -1;
		g_iChargeAttacker[victim] = -1;
		g_fLastChargedEndTime[victim] = GetGameTime();
	}
}

public void L4D2_OnSlammedSurvivor_Post(int victim, int attacker, bool bWallSlam, bool bDeadlyCharge)
{
	if (!victim || !IsClientInGame(victim))
		return;
	
	if (!IsPlayerAlive(victim))
		return;
	
	g_iChargeVictim[attacker] = victim;
	g_iChargeAttacker[victim] = attacker;
	
	AnimState pAnim = AnimState(victim);
	pAnim.SetFlag(AnimState_Pounded, false);
	pAnim.SetFlag(AnimState_Charged, false);
	pAnim.SetFlag(AnimState_TankPunched, false);
	pAnim.SetFlag(AnimState_Pounced, false);
	pAnim.ResetMainActivity();
	
	if (!IsPlayerAlive(attacker)) // compatibility with competitive 1v1
	{
		Event event = CreateEvent("charger_killed");
		event.SetInt("userid", GetClientUserId(attacker));
		
		Event_ChargerKilled(event, "charger_killed", false);
		
		event.Cancel();
	}
}

void SetInvulnerableForSlammed(int client, float duration)
{
	if (!IsPlayerAlive(client))
		return;
	
	if (g_bGodframeControl)
	{
		GiveClientGodFrames(client, duration, 8); // 1 - Hunter. 2 - Smoker. 4 - Jockey. 8 - Charger. fk u
	}
	else
	{
		CountdownTimer timer = L4D2Direct_GetInvulnerabilityTimer(client);
		if (timer != CTimer_Null)
		{
			CTimer_Start(timer, duration);
		}
	}
}

/**
 * Tank
 */
void ProcessAttackedByTank(int victim)
{
	if (GetEntPropEnt(victim, Prop_Send, "m_pummelAttacker") != -1)
	{
		return;
	}
	
	AnimState pAnim = AnimState(victim);
	
	// Fix double get-up
	pAnim.SetFlag(AnimState_Charged, false);
	
	// Fix double get-up when punching charger with victim to die
	// Keep in mind that do not mess up with later attacks to the survivor
	if (GetGameTime() - g_fLastChargedEndTime[victim] <= 0.1)
	{
		pAnim.SetFlag(AnimState_TankPunched, false);
	}
	else
	{
		// Remove charger get-up that doesn't pass the check above
		pAnim.SetFlag(AnimState_GroundSlammed, false);
		pAnim.SetFlag(AnimState_WallSlammed, false);
		pAnim.SetFlag(AnimState_Pounded, false);
		
		// Restart the get-up sequence if already playing
		pAnim.ResetMainActivity();
	}
}

public void L4D_TankClaw_OnPlayerHit_Post(int tank, int claw, int player)
{
	if (GetClientTeam(player) == 2 && !L4D_IsPlayerIncapacitated(player))
	{
		ProcessAttackedByTank(player);
	}
}

public void L4D_OnKnockedDown_Post(int client, int reason)
{
	if (reason == KNOCKDOWN_TANK && GetClientTeam(client) == 2)
	{
		ProcessAttackedByTank(client);
	}
}
