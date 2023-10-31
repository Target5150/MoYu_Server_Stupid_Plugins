#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>

#include <uservector>

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

* Version 2.3
* - Fixed a case where there's no print if an AI as Tank is kicked. (Reported by @Alan)
* - Added a variant to separate lines printing style. (Requested by @Alan)
* - Added a new field "Index" to Tank info to indicate the number of Tank spawned on current map.
* @Forgetest

* Version 3.0
* - Reworked "UserVector" and related codes.
* - Replaced enums with enum structs.
* - Fixed a few cases where damage is incorrect.
* - Fixed not detecting manually spawned tanks.
* @Forgetest
*/

#define PLUGIN_VERSION "3.0"

public Plugin myinfo =
{
	name = "Tank Damage Announce L4D2",
	author = "Griffin and Blade, Sir, Forgetest",
	description = "Announce damage dealt to tanks by survivors",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define TRANSLATION_FILE "l4d_tank_damage_announce.phrases"

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZOMBIECLASS_TANK 8							// Zombie class of the tank, used to find tank after he have been passed to another player

enum struct SurvivorInfo
{
	int userid;
	int damageDone;				// Damage to Tank
	int punch;					// Punch hits
	int rock;					// Rock hits
	int hittable;				// Hittable hits
	int damageReceived;			// Damage from Tank
}

enum struct TankInfo
{
	int userid;
	int index;							// Serial number of Tanks spawned on this map
	int incap;							// Total Survivor incaps
	int death;							// Total Survivor death
	int totalDamage;					// Total damage done to Survivors
	float aliveSince;					// Initial spawn time
	int lastHealth;						// Last HP after hit
	int maxHealth;
	int lastControlUserid;				// Last human control
	AutoUserVector survivorInfoVector;	// UserVector storing info described above
	int friendlyDamage;					// Damage done by teammates (infected)
	int unknownDamage;
}
UserVector g_aTankInfo;		// Every Tank has a slot here along with relationships.

StringMap g_smUserNames;	// Simple map from userid to player names.

int 
	g_iPlayerLastHealth[MAXPLAYERS+1],				// Used for Tank damage record
	g_iTankIndex;									// Used to index every Tank

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
	
	STYLE_SEPARATE_REVERSE_BEGIN,
	Style_Separate_Reverse = 2,
	
	STYLE_SEPARATE_BEGIN,
	Style_Separate = 3,
	Stype_SeparateDelay,
	
	NUM_TEXT_STYLE
}
ConVar
	g_hTextStyle				= null;
	
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TFA_Punches", Native_Punches);
	CreateNative("TFA_Rocks", Native_Rocks);
	CreateNative("TFA_Hittables", Native_Hittables);
	CreateNative("TFA_TotalDmg", Native_TotalDamage);
	CreateNative("TFA_UpTime", Native_UpTime);
	
	RegPluginLibrary("l4d_tank_damage_announce");
	
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadPluginTranslations(TRANSLATION_FILE);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_incapacitated", Event_PlayerIncap);
	HookEvent("player_death", Event_PlayerKilled);
	
	g_aTankInfo = new UserVector(sizeof(TankInfo));
	g_smUserNames = new StringMap();
	
	g_hCvarEnabled = CreateConVar("l4d_tankdamage_enabled",
										"1",
										"Announce damage done to tanks when enabled",
										FCVAR_NONE,
										true, 0.0, true, 1.0);
	g_hTextStyle = CreateConVar("l4d_tankdamage_text_style",
										"2",
										"Text style for how tank facts are printed.\n"
									...	"0 = Nothing\n"
									...	"1 = Combine with damage print\n"
									...	"2 = Separate lines before damage print\n"
									...	"3 = Separate lines after damage print\n"
									...	"4 = Individually print with a delay.",
										FCVAR_NONE,
										true, 0.0, true, 4.0);
	
	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i)) OnClientPutInServer(i);
		}
	}
}



/**
 * Rounds & Clients
 */
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlive, SDK_OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, SDK_OnTakeDamageAlive_Post);
}

public void OnClientDisconnect(int client)
{
	int userid = GetClientUserId(client);
	
	char key[16], name[MAX_NAME_LENGTH];
	IntToString(userid, key, sizeof(key));
	GetClientName(client, name, sizeof(name));
	g_smUserNames.SetString(key, name);
	
	if (IsFakeClient(client))
	{
		CheckTank(userid);
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iTankIndex = 0;
	g_smUserNames.Clear();
	ClearTankInfo();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	PrintTankInfo();
}

void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(event.GetInt("bot"), event.GetInt("player"));
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(event.GetInt("player"), event.GetInt("bot"));
}

public void L4D_OnReplaceTank(int tank, int newtank)
{
	if (!tank || !newtank || tank == newtank)
		return;
	
	// This is a pre-hook so make sure the replace actually happens via a delayed check.
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientUserId(tank));
	dp.WriteCell(GetClientUserId(newtank));
	
	RequestFrame(OnFrame_HandlePlayerReplace, dp);
}

void OnFrame_HandlePlayerReplace(DataPack dp)
{
	int tank, newtank;
	
	dp.Reset();
	tank = dp.ReadCell();
	newtank = dp.ReadCell();
	
	delete dp;
	
	HandlePlayerReplace(newtank, tank);
}

void HandlePlayerReplace(int replacer, int replacee)
{
	int client = GetClientOfUserId(replacer);
	if (!client || !IsClientInGame(client))
		return;
	
	if (!IsTank(client))
		return;
	
	if (g_aTankInfo.FindOrCreate(replacer) != -1)
	{
		--g_iTankIndex;
		ClearTankInfo(replacer);
	}

	g_aTankInfo.Set(replacee, replacer, TankInfo::userid);
	
	client = GetClientOfUserId(replacee);
	if (!client || !IsClientInGame(client) || !IsFakeClient(client))
		g_aTankInfo.Set(replacer, replacee, TankInfo::lastControlUserid);
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return;

	++g_iTankIndex;
	
	g_bIsTankInPlay = true;
	g_aTankInfo.FindOrCreate(userid, true);
	
	AutoUserVector survivorVector = new AutoUserVector(sizeof(SurvivorInfo));
	g_aTankInfo.Set(userid, survivorVector, TankInfo::survivorInfoVector);
	g_aTankInfo.Set(userid, GetGameTime(), TankInfo::aliveSince);
	g_aTankInfo.Set(userid, g_iTankIndex, TankInfo::index);

	UpdateTankHealth(client);
}



/**
 * Game events
 */
Action SDK_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_bIsTankInPlay)
		return Plugin_Continue;
	
	if (GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		int playerHealth = 0;
		if (!IsIncapacitated(victim))
			playerHealth = GetClientHealth(victim) + L4D_GetPlayerTempHealth(victim);

		g_iPlayerLastHealth[victim] = playerHealth;
	}
	
	return Plugin_Continue;
}

float g_flDamageAccumulator;
Action SDK_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_bIsTankInPlay)
		return Plugin_Continue;
	
	g_flDamageAccumulator = GetEntPropFloat(victim, Prop_Data, "m_flDamageAccumulator");
	
	return Plugin_Continue;
}

void SDK_OnTakeDamageAlive_Post(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!g_bIsTankInPlay)
		return;
	
	if (!IsValidEdict(inflictor))
		return;
	
	int iFixedDamage = RoundToFloor(damage + g_flDamageAccumulator);
	if (iFixedDamage <= 0)
		return;
	
	if (IsTank(victim))
	{
		if (IsIncapacitated(victim))
			return;
		
		OnTankTakeDamage(victim, attacker, iFixedDamage);
	}
	else if (GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		if (IsIncapacitated(victim))
			return;
		
		if (!IsTank(attacker))
			return;
		
		if (GetClientHealth(victim) <= 0)
			iFixedDamage = g_iPlayerLastHealth[victim];

		char weapon[64];
		GetEdictClassname(inflictor, weapon, sizeof(weapon));
		OnTankAttackDamage(attacker, victim, iFixedDamage, weapon);
	}
}

void Event_PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay)			// No tank in play; no damage to record
		return;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim))
		return;
	
	if (GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		int attacker = GetClientOfUserId(event.GetInt("attacker"));
		if (!attacker || !IsClientInGame(attacker))
			return;
		
		if (!IsTank(attacker))
			return;
		
		char weapon[64];
		event.GetString("weapon", weapon, sizeof(weapon));
		OnTankAttackDamage(attacker, victim, g_iPlayerLastHealth[victim], weapon);

		OnSurvivorIncap(victim);
	}
}

void Event_PlayerKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay)			// No tank in play; no damage to record
		return;
	
	if (event.GetBool("abort"))		// A Tank replace is happening
		return;
	
	int victimid = event.GetInt("userid");
	int victim = GetClientOfUserId(victimid);
	if (!victim || !IsClientInGame(victim))
		return;
	
	if (IsTank(victim))			// Victim isn't tank; no damage to record
	{
		// Award the killing blow's damage to the attacker; we don't award
		// damage from player_hurt after the tank has died/is dying
		// If we don't do it this way, we get wonky/inaccurate damage values

		int iTankLastHealth;
		g_aTankInfo.Get(victimid, iTankLastHealth, TankInfo::lastHealth);
		
		int attacker = GetClientOfUserId(event.GetInt("attacker"));
		if (!attacker || !IsClientInGame(attacker))
			attacker = event.GetInt("attackerentid");
		
		OnTankTakeDamage(victim, attacker, iTankLastHealth);
		
		// Damage announce could probably happen right here...
		CheckTank(victimid);
	}
	else if (GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		// Attack damage is handled in "SDK_OnTakeDamageAlive_Post",
		// so handle death only.
		OnSurvivorDeath(victim);
	}
}



/**
 * Handler
 */
void UpdateTankHealth(int tank)
{
	int tankid = GetClientUserId(tank);

	g_aTankInfo.Set(tankid, GetEntProp(tank, Prop_Data, "m_iMaxHealth"), TankInfo::maxHealth);
	g_aTankInfo.Set(tankid, GetClientHealth(tank), TankInfo::lastHealth);
}

void OnTankTakeDamage(int tank, int attacker, int damage)
{
	int tankid = GetClientUserId(tank);
	
	if (attacker != tank && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
	{
		int attackerid = GetClientUserId(attacker);
		int team = GetClientTeam(attacker);
		if (team == TEAM_SURVIVOR)
		{
			AutoUserVector survivorVector;
			g_aTankInfo.Get(tankid, survivorVector, TankInfo::survivorInfoVector);
			survivorVector.Add(attackerid, damage, SurvivorInfo::damageDone);
		}
		else if (team == TEAM_INFECTED)
		{
			g_aTankInfo.Add(tankid, damage, TankInfo::friendlyDamage);
		}
	}
	else if (IsValidEntity(attacker))
	{
		if (GetEntProp(attacker, Prop_Send, "m_iTeamNum") == TEAM_INFECTED)
		{
			g_aTankInfo.Add(tankid, damage, TankInfo::friendlyDamage);
		}
		else
		{
			g_aTankInfo.Add(tankid, damage, TankInfo::unknownDamage);
		}
	}

	UpdateTankHealth(tank);
}

void OnTankAttackDamage(int tank, int victim, int damage, const char[] weapon)
{
	int attackerid = GetClientUserId(tank);
	int victimid = GetClientUserId(victim);
	
	AutoUserVector survivorVector;
	g_aTankInfo.Get(attackerid, survivorVector, TankInfo::survivorInfoVector);
	
	if (strcmp(weapon, "weapon_tank_claw") == 0 || strcmp(weapon, "tank_claw") == 0)
		survivorVector.Add(victimid, 1, SurvivorInfo::punch);
	else if (strcmp(weapon, "tank_rock") == 0)
		survivorVector.Add(victimid, 1, SurvivorInfo::rock);
	else if (strcmp(weapon, "prop_physics") == 0 || strcmp(weapon, "prop_car_alarm") == 0)
		survivorVector.Add(victimid, 1, SurvivorInfo::hittable);

	survivorVector.Add(victimid, damage, SurvivorInfo::damageReceived);
	g_aTankInfo.Add(attackerid, damage, TankInfo::totalDamage);
}

void OnSurvivorIncap(int survivor)
{
	g_aTankInfo.ForEach( OnSurvivorIncapInternal, survivor );
}

bool OnSurvivorIncapInternal(int userid)
{
	g_aTankInfo.Add(userid, 1, TankInfo::incap);
	return true;
}

void OnSurvivorDeath(int survivor)
{
	g_aTankInfo.ForEach( OnSurvivorDeathInternal, survivor );
}

bool OnSurvivorDeathInternal(int userid)
{
	g_aTankInfo.Add(userid, 1, TankInfo::death);
	return true;
}

void CheckTank(int userid)
{
	if (g_aTankInfo.FindOrCreate(userid) != -1)
	{
		PrintTankInfo(userid);
	}
}



/**
 * Print
 */
bool FindTankControlName(int userid, char[] name, int maxlen)
{
	int client = GetClientOfUserId(userid);
	
	if (!IsFakeClient(client))
	{
		return GetClientName(client, name, maxlen);
	}
	
	int lastControlUserid;
	if (g_aTankInfo.Get(userid, lastControlUserid, TankInfo::lastControlUserid) && lastControlUserid)
	{
		return GetClientNameFromUserId(lastControlUserid, name, maxlen);
	}
	
	GetClientName(client, name, maxlen);
	return false;
}

void PrintTankDamageTitle(const TankInfo info)
{
	int client = GetClientOfUserId(info.userid);
	
	char name[MAX_NAME_LENGTH];
	bool bHumanControlled = FindTankControlName(info.userid, name, sizeof(name));
	
	char sTranslation[64];
	FormatEx(sTranslation,
		sizeof(sTranslation),
		"%s_%s",
		IsPlayerAlive(client) ? "RemainingHealth" : "DamageDealt",
		IsFakeClient(client) ? (bHumanControlled ? "Frustrated" : "AI") : "HumanControlled");
	
	if (IsPlayerAlive(client))
		CPrintToChatAll("%t", sTranslation, name, info.lastHealth, info.index);
	else
		CPrintToChatAll("%t", sTranslation, name, info.index);
}

void PrintTankFactsTitle(const TankInfo info)
{
	int client = GetClientOfUserId(info.userid);
	
	char name[MAX_NAME_LENGTH];
	bool bHumanControlled = FindTankControlName(info.userid, name, sizeof(name));
	
	char sTranslation[64];
	FormatEx(sTranslation,
			sizeof(sTranslation),
			"FactsTitle_%s",
			IsFakeClient(client) ? (bHumanControlled ? "Frustrated" : "AI") : "HumanControlled");
	
	if (IsPlayerAlive(client))
		CPrintToChatAll("%t", sTranslation, name, info.lastHealth, info.index);
	else
		CPrintToChatAll("%t", sTranslation, name, info.index);
}

void PrintTankInfo(int userid = 0)
{
	if (!g_hCvarEnabled.BoolValue)
		return;
	
	if (userid > 0)
	{
		PrintTankInfoInternal(userid);
	}
	else
	{
		g_aTankInfo.ForEach( PrintTankInfoInternal );
	}
}

bool PrintTankInfoInternal(int userid)
{
	int style = g_hTextStyle.IntValue;
	
	if (style == Style_Separate_Reverse)
	{
		PrintTankFacts(userid);
	}
	
	PrintTankDamage(userid);
	
	if (style >= STYLE_SEPARATE_BEGIN)
	{
		float delay = 0.0;
		if (style == Stype_SeparateDelay)
			delay = 3.0;
		
		PrintTankFacts(userid, delay);
	}
	
	ClearTankInfo(userid);
	
	return true;
}

void PrintTankDamage(int userid)
{
	TankInfo info;
	g_aTankInfo.GetArray(userid, info);
	
	PrintTankDamageTitle(info);
	
	// survivor damages
	AutoUserVector survivorVector = info.survivorInfoVector;
	survivorVector.SortCustom( SortADT_DamageDesc );
	survivorVector.ForEach( PrintTankDamageInternal, userid );
	
	// friendly / unknown damages
	if (info.friendlyDamage)
	{
		int percent = RoundToNearest(float(info.friendlyDamage) / info.maxHealth * 100.0);
		CPrintToChatAll("%t", "DamageToTank_Friendly", info.friendlyDamage, percent);	
	}
	
	if (info.unknownDamage)
	{
		int percent = RoundToNearest(float(info.unknownDamage) / info.maxHealth * 100.0);
		CPrintToChatAll("%t", "DamageToTank_Unknown", info.unknownDamage, percent);
	}
}

bool PrintTankDamageInternal(int userid, any tankid)
{
	int style = g_hTextStyle.IntValue;
	
	AutoUserVector survivorVector;
	g_aTankInfo.Get(tankid, survivorVector, TankInfo::survivorInfoVector);
	
	SurvivorInfo info;
	survivorVector.GetArray(userid, info);
	
	char name[MAX_NAME_LENGTH];
	GetClientNameFromUserId(info.userid, name, sizeof(name));
	
	int maxHealth;
	g_aTankInfo.Get(tankid, maxHealth, TankInfo::maxHealth);
	
	// TODO:
	// Original version takes care of round up issue where sum of percentages goes over 100%.
	// I decided to keep it simple at first but might consider a restore if it happens a lot.
	int percent = RoundToNearest(float(info.damageDone) / maxHealth * 100.0);
	
	// ignore cases printing zeros only
	if (info.damageDone > 0 || (style == Style_Combined && info.damageReceived))
	{
		if (style == Style_Combined)
			CPrintToChatAll("%t", "DamageToTank_Combined", info.damageDone, percent, name, info.punch, info.rock, info.hittable, info.damageReceived);
		else
			CPrintToChatAll("%t", "DamageToTank", info.damageDone, percent, name);
	}
	
	return true;
}

void PrintTankFacts(int userid, float delay = 0.0)
{
	TankInfo info;
	g_aTankInfo.GetArray(userid, info);
	
	if (delay > 0.0)
	{
		info.survivorInfoVector = view_as<AutoUserVector>(info.survivorInfoVector.Clone());
		
		DataPack dp;
		CreateDataTimer(delay, Timer_PrintTankFacts, dp, TIMER_FLAG_NO_MAPCHANGE);
		dp.WriteCellArray(info, sizeof(info));
		
		return;
	}
	
	PrintTankFactsTitle(info);
	PrintTankFactsInternal(info);
}

Action Timer_PrintTankFacts(Handle timer, DataPack dp)
{
	TankInfo info;
	dp.ReadCellArray(info, sizeof(info));
	
	PrintTankFactsInternal(info);
	
	delete info.survivorInfoVector;
	
	return Plugin_Stop;
}

void PrintTankFactsInternal(const TankInfo info)
{
	AutoUserVector survivorVector = info.survivorInfoVector;
	
	int total_punch = survivorVector.Sum(SurvivorInfo::punch);
	int total_rock = survivorVector.Sum(SurvivorInfo::rock);
	int total_hittable = survivorVector.Sum(SurvivorInfo::hittable);
	int total_incap = info.incap;
	int total_death = info.death;
	int total_damage = info.totalDamage;
	
	int iAliveDuration = RoundToFloor(GetGameTime() - info.aliveSince);
	
	// [!] Facts of the Tank (AI)
	// > Punch: 4 / Rock: 2 / Hittable: 0
	// > Incap: 1 / Death: 0 from Survivors
	// > Duration: 1min 7s / Total Damage: 144
	
	CPrintToChatAll("%t", "Announce_TankAttack", total_punch, total_rock, total_hittable);
	CPrintToChatAll("%t", "Announce_AttackResult", total_incap, total_death);
	if (iAliveDuration > 60)
		CPrintToChatAll("%t", "Announce_Summary_WithMinute", iAliveDuration / 60, iAliveDuration % 60, total_damage);
	else
		CPrintToChatAll("%t", "Announce_Summary_WithoutMinute", iAliveDuration, total_damage);
}

void ClearTankInfo(int userid = 0)
{
	if (userid > 0)
	{
		ClearTankInfoInternal(userid);
		g_aTankInfo.Erase(userid);
	}
	else
	{
		g_aTankInfo.ForEach( ClearTankInfoInternal );
		g_aTankInfo.Clear();
	}
	
	g_bIsTankInPlay = g_aTankInfo.Length > 0;
}

bool ClearTankInfoInternal(int userid)
{
	AutoUserVector survivorVector;
	if (g_aTankInfo.Get(userid, survivorVector, TankInfo::survivorInfoVector))
		delete survivorVector;
	
	return true;
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
	AutoUserVector survivorVector = view_as<AutoUserVector>(array);
	
	int damage1, damage2;
	survivorVector.Get(survivorVector.At(index1), damage1, SurvivorInfo::damageDone);
	survivorVector.Get(survivorVector.At(index2), damage2, SurvivorInfo::damageDone);
	
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
	
	AutoUserVector survivorVector;
	if (!g_aTankInfo.Get(userid, survivorVector, TankInfo::survivorInfoVector))
		return -1;
	
	return survivorVector.Sum(SurvivorInfo::punch);
}

any Native_Rocks(Handle hPlugin, int iNumParams) {
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	
	int userid = GetClientUserId(client);
	
	AutoUserVector survivorVector;
	if (!g_aTankInfo.Get(userid, survivorVector, TankInfo::survivorInfoVector))
		return -1;
	
	return survivorVector.Sum(SurvivorInfo::rock);
}

any Native_Hittables(Handle hPlugin, int iNumParams) {
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	
	int userid = GetClientUserId(client);
	
	AutoUserVector survivorVector;
	if (!g_aTankInfo.Get(userid, survivorVector, TankInfo::survivorInfoVector))
		return -1;
	
	return survivorVector.Sum(SurvivorInfo::hittable);
}

any Native_TotalDamage(Handle hPlugin, int iNumParams) {
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	
	int userid = GetClientUserId(client);
	
	int value = -1;
	g_aTankInfo.Get(userid, value, TankInfo::totalDamage);
	return value;
}

any Native_UpTime(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	
	int userid = GetClientUserId(client);
	
	float value = -1.0;
	if (g_aTankInfo.Get(userid, value, TankInfo::aliveSince))
		value = GetGameTime() - value;
	
	return RoundToFloor(value);
}

stock void LoadPluginTranslations(const char[] file)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/%s.txt", file);
	if (!FileExists(sPath))
	{
		SetFailState("Missing translations \"%s\"", file);
	}
	LoadTranslations(file);
}