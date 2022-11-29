#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>

/*
* Version 0.6.6
* - Better looking Output.
* - Added Tank Name display when Tank dies, normally it only showed the Tank's name if the Tank survived
* 
* Version 0.6.6b
* - Fixed Printing Two Tanks when last map Tank survived.
* Added by; Sir

* Version 0.6.7
* - Added Campaign Difficulty Support.
* Added by; Sir

* Version 2.0
* - Full support for multiple tanks.
* - Merged with `l4d2_tank_facts_announce`
* - DONE: Some style settings. (See Version 2.2)
* @Forgetest

* Version 2.1
* - Added support to print names of AI Tank.
* @Forgetest

* Version 2.2
* - Fixed no print when Tank dies to "world". (Thanks to @Alan)
* - Fixed incorrect remaining health if Tank is full healthy. (Thanks to @nikita1824)
* - Fixed death remaining unchanged if Survivor dies to anything else than Tank.
* - Added another 3 text styles (one is disabling extra prints).
* - Added a few natives written by @nikita1824.
* @Forgetest
*/    

#define PLUGIN_VERSION "2.2.1"

public Plugin myinfo =
{
	name = "Tank Damage Announce L4D2",
	author = "Griffin and Blade, Sir, Forgetest",
	description = "Announce damage dealt to tanks by survivors",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZOMBIECLASS_TANK 8							// Zombie class of the tank, used to find tank after he have been passed to another player

/**
 * Entity-Relationship: UserVector(Userid, ...)
 */
methodmap UserVector < ArrayList
{
	public UserVector(int blocksize = 1) {
		return view_as<UserVector>(new ArrayList(blocksize + 1, 0)); // extended by 1 cell for userid field
	}
	
	public any Get(int index, int type) {
		return GetArrayCell(this, index, type + 1);
	}
	
	public void Set(int index, any value, int type) {
		SetArrayCell(this, index, value, type + 1);
	}
	
	public int User(int index) {
		return GetArrayCell(this, index, 0);
	}
	
	public int Push(any value) {
		int blocksize = this.BlockSize;
		
		any[] array = new any[blocksize];
		array[0] = value;
		
		return this.PushArray(array);
	}
	
	public bool UserIndex(int userid, int &index, bool create = false) {
		index = this.FindValue(userid, 0);
		if (index == -1)
		{
			if (!create)
				return false;
			
			index = this.Push(userid);
		}
		
		return true;
	}
	
	public bool UserReplace(int userid, int replacer) {
		int index;
		if (!this.UserIndex(userid, index, false))
			return false;
		
		SetArrayCell(this, index, replacer, 0);
		return true;
	}
	
	public bool UserGet(int userid, int type, any &value) {
		int index;
		if (!this.UserIndex(userid, index, false))
			return false;
		
		value = this.Get(index, type);
		return true;
	}
	
	public bool UserSet(int userid, int type, any value, bool create = false) {
		int index;
		if (!this.UserIndex(userid, index, create))
			return false;
		
		this.Set(index, value, type);
		return true;
	}
	
	public bool UserAdd(int userid, int type, any amount, bool create = false) {
		int index;
		if (!this.UserIndex(userid, index, create))
			return false;
		
		int val = this.Get(index, type);
		this.Set(index, val + amount, type);
		return true;
	}
}

enum
{
	DamageDone,				// Damage to Tank
	Punch,					// Punch hits
	Rock,					// Rock hits
	Hittable,				// Hittable hits
	DamageReceived,			// Damage from Tank
	
	NUM_SURVIVOR_INFO
};

enum
{
	Incap,					// Total Survivor incaps
	Death,					// Total Survivor death
	TotalDamage,			// Total damage done to Survivors
	AliveSince,				// Initial spawn time
	TankLastHealth,			// Last HP after hit
	LastControlUserid,		// Last human control
	SurvivorInfoVector,		// UserVector storing info described above
	
	NUM_TANK_INFO
};
UserVector g_aTankInfo;		// Every Tank has a slot here along with relationships.

StringMap g_smUserNames;	// Simple map from userid to player names.

int 
	g_iPlayerLastHealth[MAXPLAYERS+1];				// Used for Tank damage record

bool
	g_bIsTankInPlay				= false,            // Whether or not the tank is active
	g_bLateLoad					= false;

ConVar
	g_hCvarEnabled              = null;

enum
{
	Style_Nothing = 0,
	
	STYLE_FACTS_BEGIN,
	Style_Combined = 1,
	
	STYLE_SEPARATE_BEGIN,
	Style_Separate = 2,
	Stype_SeparateDelay,
	
	NUM_TEXT_STYLE
}
ConVar
	g_hTextStyle				= null;
	
GlobalForward
	fwdOnTankDeath				= null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	fwdOnTankDeath = new GlobalForward("OnTankDeath", ET_Ignore); // is it even useful?
	
	CreateNative("TFA_Punches", Native_Punches);
	CreateNative("TFA_Rocks", Native_Rocks);
	CreateNative("TFA_Hittables", Native_Hittables);
	CreateNative("TFA_TotalDmg", Native_TotalDamage);
	CreateNative("TFA_UpTime", Native_UpTime);
	
	RegPluginLibrary("l4d_tank_damage_announce");
	
	g_bLateLoad = late;
	return APLRes_Success;
}

#define TRANSLATION_FILE "l4d_tank_damage_announce.phrases"
void LoadPluginTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/"...TRANSLATION_FILE...".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translations \""...TRANSLATION_FILE..."\"");
	}
	LoadTranslations(TRANSLATION_FILE);
}

public void OnPluginStart()
{
	LoadPluginTranslations();
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_incapacitated", Event_PlayerIncap);
	HookEvent("player_death", Event_PlayerKilled);
	
	g_aTankInfo = new UserVector(NUM_TANK_INFO);
	g_smUserNames = new StringMap();
	
	g_hCvarEnabled = CreateConVar("l4d_tankdamage_enabled",
										"1",
										"Announce damage done to tanks when enabled",
										FCVAR_SPONLY|FCVAR_NOTIFY,
										true, 0.0, true, 1.0);
	g_hTextStyle = CreateConVar("l4d_tankdamage_text_style",
										"2",
										"Text style for how tank facts are printed.\n"
									...	"0 = Nothing, 1 = Combine with damage print, 2 = Separate lines, 3 = Individually print with a delay.",
										FCVAR_SPONLY|FCVAR_NOTIFY,
										true, 0.0, true, 3.0);
	
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
}

public void OnClientDisconnect(int client)
{
	int userid = GetClientUserId(client);
	
	char key[16], name[MAX_NAME_LENGTH];
	IntToString(userid, key, sizeof(key));
	GetClientName(client, name, sizeof(name));
	g_smUserNames.SetString(key, name);
}

Action SDK_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_bIsTankInPlay) return Plugin_Continue;
	
	if (!IsValidEntity(victim) || !IsValidEntity(attacker) || !IsValidEdict(inflictor)) return Plugin_Continue;
	
	if (!attacker || attacker > MaxClients) return Plugin_Continue;
	
	if (GetClientTeam(victim) != TEAM_SURVIVOR || !IsTank(attacker)) return Plugin_Continue;
	
	//char classname[64];
	//GetEdictClassname(inflictor, classname, sizeof(classname));
	
	//if (/*|| IsTankHittable(classname)*/)
	{
		int playerHealth = GetClientHealth(victim) + RoundToCeil(L4D_GetTempHealth(victim));
		if (RoundToFloor(damage) >= playerHealth)
		{
			/* Store HP only when the damage is greater than this, so we can turn to IncapStart for Damage record */
			g_iPlayerLastHealth[victim] = playerHealth;
		}
	}
		
	return Plugin_Continue;
}


/**
 * Events
 */
public void L4D_OnSpawnTank_Post(int client, const float vecPos[3], const float vecAng[3])
{
	if (client <= 0)
		return;
	
	int userid = GetClientUserId(client);
	
	// New tank, damage has not been announced
	g_bIsTankInPlay = true;
	g_aTankInfo.UserSet(userid, SurvivorInfoVector, new UserVector(NUM_SURVIVOR_INFO), true);
	g_aTankInfo.UserSet(userid, AliveSince, GetGameTime());
	g_aTankInfo.UserSet(userid, TankLastHealth, GetEntProp(client, Prop_Send, "m_iMaxHealth"));
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsTankInPlay = false;
	g_smUserNames.Clear();
	ClearTankInfo(); // Probably redundant
}

// When survivors wipe or juke tank, announce damage
void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// But only if a tank that hasn't been killed exists
	PrintTankInfo();
	ClearTankInfo();
	g_bIsTankInPlay = false;
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
	int client = GetClientOfUserId(replacer);
	if (!client || !IsClientInGame(client))
		return;
	
	if (!IsTank(client))
		return;
	
	g_aTankInfo.UserReplace(replacee, replacer);
	
	client = GetClientOfUserId(replacee);
	if (!client || !IsClientInGame(client) || !IsFakeClient(client))
		g_aTankInfo.UserSet(replacer, LastControlUserid, replacee);
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay)			// No tank in play; no damage to record
		return;
	
	int victimid = event.GetInt("userid");
	int victim = GetClientOfUserId(victimid);
	if (!victim || !IsClientInGame(victim))
		return;
	
	if (IsTank(victim))			// Victim isn't tank; no damage to record
	{
		if (IsIncapacitated(victim))	// Something buggy happens when tank is dying with regards to damage
			return;
		
		int attackerid = event.GetInt("attacker");
		int attacker = GetClientOfUserId(attackerid);
		// We only care about damage dealt by survivors, though it can be funny to see
		// claw/self inflicted hittable damage, so maybe in the future we'll do that
		if (!attacker || !IsClientInGame(attacker))
			return;
		
		if (GetClientTeam(attacker) != TEAM_SURVIVOR)
			return;
		
		g_aTankInfo.UserSet(victimid, TankLastHealth, event.GetInt("health"));
		
		UserVector survivorVector;
		g_aTankInfo.UserGet(victimid, SurvivorInfoVector, survivorVector);
		survivorVector.UserAdd(attackerid, DamageDone, event.GetInt("dmg_health"), true);
	}
	else if (GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		if (IsIncapacitated(victim))
			return;
		
		int attackerid = event.GetInt("attacker");
		int attacker = GetClientOfUserId(attackerid);
		// We only care about damage dealt by survivors, though it can be funny to see
		// claw/self inflicted hittable damage, so maybe in the future we'll do that
		if (!attacker || !IsClientInGame(attacker))
			return;
		
		if (!IsTank(attacker))
			return;
		
		char weapon[64];
		event.GetString("weapon", weapon, sizeof(weapon));
	
		UserVector survivorVector;
		g_aTankInfo.UserGet(attackerid, SurvivorInfoVector, survivorVector);
		
		int dmg = event.GetInt("dmg_health");
		if (dmg > 0)
		{
			if (strcmp(weapon, "tank_claw") == 0) {
				survivorVector.UserAdd(victimid, Punch, 1, true);
			} else if (strcmp(weapon, "tank_rock") == 0) {
				survivorVector.UserAdd(victimid, Rock, 1, true);
			//} else if (IsTankHittable(weapon)) {
			} else { // workaround due to "l4d2_hittable_control" setting 'inflictor' to 0 for hittables
				survivorVector.UserAdd(victimid, Hittable, 1, true);
			}
			
			survivorVector.UserAdd(victimid, DamageReceived, dmg);
			g_aTankInfo.UserAdd(attackerid, TotalDamage, dmg);
		}
	}
}

void Event_PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay) return;
	
	int victimid = event.GetInt("userid");
	int victim = GetClientOfUserId(victimid);
	if (!victim || !IsClientInGame(victim))
		return;
	
	if (GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		int attackerid = event.GetInt("attacker");
		int attacker = GetClientOfUserId(attackerid);
		if (!attacker || !IsClientInGame(attacker))
			return;
		
		if (!IsTank(attacker))
			return;
		
		UserVector survivorVector;
		g_aTankInfo.UserGet(attackerid, SurvivorInfoVector, survivorVector);
			
		char weapon[64];
		event.GetString("weapon", weapon, sizeof(weapon));
		
		if (StrEqual(weapon, "tank_claw")) {
			survivorVector.UserAdd(victimid, Punch, 1, true);
		} else if (StrEqual(weapon, "tank_rock")) {
			survivorVector.UserAdd(victimid, Rock, 1, true);
		//} else if (IsTankHittable(weapon)) {
		} else { // workaround due to "l4d2_hittable_control" setting 'inflictor' to 0 for hittables
			survivorVector.UserAdd(victimid, Hittable, 1, true);
		}
		
		survivorVector.UserAdd(victimid, DamageReceived, g_iPlayerLastHealth[victim]);
		g_aTankInfo.UserAdd(attackerid, Incap, 1);
		g_aTankInfo.UserAdd(attackerid, TotalDamage, g_iPlayerLastHealth[victim]);
	}
}

void Event_PlayerKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay)			// No tank in play; no damage to record
		return;
	
	int victimid = event.GetInt("userid");
	int victim = GetClientOfUserId(victimid);
	if (!victim || !IsClientInGame(victim))
		return;
	
	int attackerid = event.GetInt("attacker");
	
	if (IsTank(victim))			// Victim isn't tank; no damage to record
	{
		// Damage announce could probably happen right here...
		CreateTimer(0.1, Timer_CheckTank, victimid); // Use a delayed timer due to bugs where the tank passes to another player
		
		// Award the killing blow's damage to the attacker; we don't award
		// damage from player_hurt after the tank has died/is dying
		// If we don't do it this way, we get wonky/inaccurate damage values
		int attacker = GetClientOfUserId(attackerid);
		if (!attacker || !IsClientInGame(attacker))
			return;
		
		if (GetClientTeam(attacker) == TEAM_SURVIVOR)
		{
			int iTankLastHealth;
			g_aTankInfo.UserGet(victimid, TankLastHealth, iTankLastHealth);
			
			UserVector survivorVector;
			g_aTankInfo.UserGet(victimid, SurvivorInfoVector, survivorVector);
			survivorVector.UserAdd(attackerid, DamageDone, iTankLastHealth, true);
		}
	}
	else if (GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		g_aTankInfo.UserAdd(attackerid, Death, 1);
	}
}

Action Timer_CheckTank(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;
	
	if (!IsTank(client))
		return Plugin_Stop;
	
	PrintTankInfo(userid);
	ClearTankInfo(userid);
	Call_StartForward(fwdOnTankDeath);
	Call_Finish();
	
	return Plugin_Stop;
}

bool FindTankControlName(int userid, char[] name, int maxlen)
{
	int client = GetClientOfUserId(userid);
	
	if (!IsFakeClient(client))
	{
		return GetClientName(client, name, maxlen);
	}
	
	int lastControlUserid;
	if (g_aTankInfo.UserGet(userid, LastControlUserid, lastControlUserid))
	{
		return GetClientNameFromUserId(lastControlUserid, name, maxlen);
	}
	
	GetClientName(client, name, maxlen);
	return false;
}

void PrintTitle(const char[] name, int lastHealth, bool bAI, bool bAlive, bool bHumanControlled, bool bFacts)
{
	char sTranslation[64];
	FormatEx(sTranslation,
			sizeof(sTranslation),
			"%s_%s",
			bFacts ? "FactsTitle" : (bAlive ? "RemainingHealth" : "DamageDealt"),
			bAI ? (bHumanControlled ? "Frustrated" : "AI") : "HumanControlled");
	
	if (bAlive)
		CPrintToChatAll("%t", sTranslation, name, lastHealth);
	else
		CPrintToChatAll("%t", sTranslation, name);
}

void PrintTankInfo(int paramuserid = 0)
{
	if (!g_hCvarEnabled.BoolValue)
		return;
	
	int index = 0;
	if (paramuserid > 0 && !g_aTankInfo.UserIndex(paramuserid, index, false))
		return;
	
	int style = g_hTextStyle.IntValue;
	
	for (; index < g_aTankInfo.Length; ++index)
	{
		int userid = g_aTankInfo.User(index);
		int client = GetClientOfUserId(userid);
		
		char name[MAX_NAME_LENGTH];
		bool bHumanControlled = FindTankControlName(userid, name, sizeof(name));
		
		int lastHealth = g_aTankInfo.Get(index, TankLastHealth);
		PrintTitle(name,
				lastHealth,
				IsFakeClient(client),
				IsPlayerAlive(client),
				bHumanControlled,
				false);
		
		UserVector survivorVector = g_aTankInfo.Get(index, SurvivorInfoVector);
		survivorVector.SortCustom(SortADT_DamageDesc);
		
		float flMaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth") + 0.0;
		
		int damage, damageReceived, percent;
		int total_punch, total_rock, total_hittable;
		
		for (int i = 0; i < survivorVector.Length; ++i)
		{
			// generally needed
			GetClientNameFromUserId(survivorVector.User(i), name, sizeof(name));
			
			// basic tank damage announce
			damage = survivorVector.Get(i, DamageDone);
			percent = RoundToNearest(float(damage) / flMaxHealth * 100.0);
			
			// see what type of facts announce is used
			if (style == Style_Combined) // dont need to add up
			{
				total_punch = survivorVector.Get(i, Punch);
				total_rock = survivorVector.Get(i, Rock);
				total_hittable = survivorVector.Get(i, Hittable);
			}
			else if (style >= STYLE_SEPARATE_BEGIN)
			{
				total_punch += survivorVector.Get(i, Punch);
				total_rock += survivorVector.Get(i, Rock);
				total_hittable += survivorVector.Get(i, Hittable);
				damageReceived = survivorVector.Get(i, DamageReceived);
			}
			
			// ignore cases printing zeros only
			if (damage > 0 || (style == Style_Combined && damageReceived))
			{
				if (style == Style_Combined)
					CPrintToChatAll("%t", "DamageToTank_Combined", damage, percent, name, total_punch, total_rock, total_hittable, damageReceived);
				else
					CPrintToChatAll("%t", "DamageToTank", damage, percent, name);
			}
		}
		
		if (style >= STYLE_SEPARATE_BEGIN)
		{
			int total_incap = g_aTankInfo.Get(index, Incap);
			int total_death = g_aTankInfo.Get(index, Death);
			int total_damage = g_aTankInfo.Get(index, TotalDamage);
			
			int iAliveDuration = RoundToFloor(GetGameTime() - view_as<float>(g_aTankInfo.Get(index, AliveSince)));
	
			DataPack dp = new DataPack();
			dp.WriteCell(total_punch);
			dp.WriteCell(total_rock);
			dp.WriteCell(total_hittable);
			dp.WriteCell(total_incap);
			dp.WriteCell(total_death);
			dp.WriteCell(total_damage);
			dp.WriteCell(iAliveDuration);
			
			if (style == Style_Separate)
			{
				Timer_PrintTankFacts(null, dp);
				delete dp;
			}
			else // Stype_SeparateDelay
			{
				dp.WriteString(name);
				dp.WriteCell(IsFakeClient(client));
				dp.WriteCell(IsPlayerAlive(client));
				dp.WriteCell(bHumanControlled);
				CreateTimer(3.0, Timer_PrintTankFacts, dp, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
			}
		}
		
		if (paramuserid > 0)
			break;
	}
}

Action Timer_PrintTankFacts(Handle timer, DataPack dp)
{
	dp.Reset();
	
	int total_punch = dp.ReadCell();
	int total_rock = dp.ReadCell();
	int total_hittable = dp.ReadCell();
	int total_incap = dp.ReadCell();
	int total_death = dp.ReadCell();
	int total_damage = dp.ReadCell();
	int iAliveDuration = dp.ReadCell();
	
	// [!] Facts of the Tank (AI)
	// > Punch: 4 / Rock: 2 / Hittable: 0
	// > Incap: 1 / Death: 0 from Survivors
	// > Duration: 1min 7s / Total Damage: 144
	
	if (timer != null) // need a title for the delayed announce
	{
		char name[MAX_NAME_LENGTH];
		dp.ReadString(name, sizeof(name));
		
		bool bAI = dp.ReadCell();
		bool bAlive = dp.ReadCell();
		bool bHumanControlled = dp.ReadCell();
		
		PrintTitle(name, 0, bAI, bAlive, bHumanControlled, true);
	}
	
	CPrintToChatAll("%t", "Announce_TankAttack", total_punch, total_rock, total_hittable);
	CPrintToChatAll("%t", "Announce_AttackResult", total_incap, total_death);
	if (iAliveDuration > 60)
		CPrintToChatAll("%t", "Announce_Summary_WithMinute", iAliveDuration / 60, iAliveDuration % 60, total_damage);
	else
		CPrintToChatAll("%t", "Announce_Summary_WithoutMinute", iAliveDuration, total_damage);
	
	return Plugin_Stop;
}

void ClearTankInfo(int userid = 0)
{
	int index = 0;
	if (userid > 0 && !g_aTankInfo.UserIndex(userid, index, false))
		return;
	
	while (g_aTankInfo.Length)
	{
		UserVector survivorVector = g_aTankInfo.Get(index, SurvivorInfoVector);
		delete survivorVector;
		
		g_aTankInfo.Erase(index);
		
		if (userid > 0)
			break;
	}
	
	// TODO: Move this to somewhere else? not quite satisfying
	g_bIsTankInPlay = g_aTankInfo.Length > 0;
}

// utilize our map g_smUserNames
bool GetClientNameFromUserId(int userid, char[] name, int maxlen)
{
	int client = GetClientOfUserId(userid);
	
	if (client && IsClientInGame(client))
	{
		return GetClientName(client, name, maxlen);
	}
	
	char key[16];
	IntToString(userid, key, sizeof(key));
	return g_smUserNames.GetString(key, name, maxlen);
}

bool IsTank(int client)
{
	return GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK;
}

bool IsIncapacitated(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) != 0;
}

int SortADT_DamageDesc(int index1, int index2, Handle array, Handle hndl)
{
	UserVector survivorVector = view_as<UserVector>(array);
	
	int damage1 = survivorVector.Get(index1, DamageDone);
	int damage2 = survivorVector.Get(index2, DamageDone);
	
	if (damage1 > damage2)
		return -1;
	else if (damage1 < damage2)
		return 1;
	
	return 0;
}


/**
 * Thanks to @nikita1824 for wrtting
 */
any Native_Punches(Handle hPlugin, int iNumParams) {
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	
	int userid = GetClientUserId(client);
	
	UserVector survivorVector;
	if (!g_aTankInfo.UserGet(userid, SurvivorInfoVector, survivorVector))
		return 0;
	
	int sum = 0, size = survivorVector.Length;
	for (int i = 0; i < size; ++i)
		sum += survivorVector.Get(i, Punch);
	
	return sum;
}

any Native_Rocks(Handle hPlugin, int iNumParams) {
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	
	int userid = GetClientUserId(client);
	
	UserVector survivorVector;
	if (!g_aTankInfo.UserGet(userid, SurvivorInfoVector, survivorVector))
		return 0;
	
	int sum = 0, size = survivorVector.Length;
	for (int i = 0; i < size; ++i)
		sum += survivorVector.Get(i, Rock);
	
	return sum;
}

any Native_Hittables(Handle hPlugin, int iNumParams) {
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	
	int userid = GetClientUserId(client);
	
	UserVector survivorVector;
	if (!g_aTankInfo.UserGet(userid, SurvivorInfoVector, survivorVector))
		return 0;
	
	int sum = 0, size = survivorVector.Length;
	for (int i = 0; i < size; ++i)
		sum += survivorVector.Get(i, Hittable);
	
	return sum;
}

any Native_TotalDamage(Handle hPlugin, int iNumParams) {
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	
	int userid = GetClientUserId(client);
	
	int value = 0;
	g_aTankInfo.UserGet(userid, TotalDamage, value);
	return value;
}

any Native_UpTime(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	
	int userid = GetClientUserId(client);
	
	float value = -1.0;
	if (g_aTankInfo.UserGet(userid, AliveSince, value))
		value = GetGameTime() - value;
	
	return RoundToFloor(value);
}