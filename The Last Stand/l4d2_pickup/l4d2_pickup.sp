/*
//-------------------------------------------------------------------------------------------------------------------
// Version 1: Prevents Survivors from picking up Players in the following situations:
//-------------------------------------------------------------------------------------------------------------------
// - Incapped Player is taking Spit Damage.
// - Players doing the pick-up gets hit by the Tank (Punch or Rock)
//
//-------------------------------------------------------------------------------------------------------------------
// Version 1.1: Prevents Survivors from switching from their current item to another without client requesting so:
//-------------------------------------------------------------------------------------------------------------------
// - Player no longer switches to pills when a teammate passes them pills through "M2".
// - Player picks up a Secondary Weapon while not on their Secondary Weapon. (Dual Pistol will force a switch though)
// - Added CVars for Pick-ups/Switching Item
//
//-------------------------------------------------------------------------------------------------------------------
// Version 1.2: Added Client-side Flags so that players can choose whether or not to make use of the Server's flags.
//-------------------------------------------------------------------------------------------------------------------
// - Welp, there's only one change.. so yeah. Enjoy!
//
//-------------------------------------------------------------------------------------------------------------------
// Version 2.0: Added way to detect Dual Pistol pick-up and block so.
//-------------------------------------------------------------------------------------------------------------------
// - Via hacky memory patch. 
//
//-------------------------------------------------------------------------------------------------------------------
// Version 3.0: General rework and dualies patch review
//-------------------------------------------------------------------------------------------------------------------
// - Should be perfect now? (hurray)
//
//-------------------------------------------------------------------------------------------------------------------
// Version 4.0: No switch to primary as well
//-------------------------------------------------------------------------------------------------------------------
// - Behave like a modern.
//
//-------------------------------------------------------------------------------------------------------------------
// DONE:
//-------------------------------------------------------------------------------------------------------------------
// - Be a nice guy and less lazy, allow the plugin to work flawlessly with other's peoples needs.. It doesn't require much attention.
// - Find cleaner methods to detect and handle functions.
*/

#define PLUGIN_VERSION "4.0"

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util> //#include <weapons>
#include <colors>
#include <dhooks>
#include <sourcescramble>
#include <left4dhooks>
#include <clientprefs>

#define FLAGS_SWITCH_MELEE                1
#define FLAGS_SWITCH_PILLS                2

#define FLAGS_INCAP_SPIT                  1
#define FLAGS_INCAP_TANKPUNCH             2
#define FLAGS_INCAP_TANKROCK              4

#define TEAM_SURVIVOR                     2
#define TEAM_INFECTED                     3

#define DMG_TYPE_SPIT (DMG_RADIATION|DMG_ENERGYBEAM)

bool
	bLateLoad,
	bCantSwitchHealth[MAXPLAYERS+1],
	bCantSwitchSecondary[MAXPLAYERS+1],
	bPreventValveSwitch[MAXPLAYERS+1];
	
int
	iSwitchFlags[MAXPLAYERS+1],
	SwitchFlags,
	IncapFlags;

bool
	g_bLeft4Dead2;

MemoryPatch
	g_hPatch;

Cookie 
	g_hSwitchCookie;

public Plugin myinfo = 
{
	name = "L4D2 Pick-up Changes",
	author = "Sir, Forgetest", //Update syntax A1m`
	description = "Alters a few things regarding picking up/giving items and incapped Players.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d2_pickup"
#define COOKIE_NAME "l4d2_pickup_switch_cookie"
#define KEY_FUNCTION "CTerrorGun::EquipSecondWeapon"
#define KEY_FUNCTION_2 "CTerrorGun::RemoveSecondWeapon"
#define KEY_FUNCTION_3 "CBaseCombatWeapon::SetViewModel"
#define KEY_PATCH_SURFIX "__SkipWeaponDeploy"

void LoadSDK()
{
	GameData conf = new GameData(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ..."\"");
	
	DynamicDetour hDetour = DynamicDetour.FromConf(conf, KEY_FUNCTION);
	if (!hDetour)
		SetFailState("Missing detour setup \""...KEY_FUNCTION..."\"");
	if (!hDetour.Enable(Hook_Pre, DTR_OnEquipSecondWeapon))
		SetFailState("Failed to pre-detour \""...KEY_FUNCTION..."\"");
	if (!hDetour.Enable(Hook_Post, DTR_OnEquipSecondWeapon_Post))
		SetFailState("Failed to post-detour \""...KEY_FUNCTION..."\"");
	
	delete hDetour;
	
	hDetour = DynamicDetour.FromConf(conf, KEY_FUNCTION_2);
	if (!hDetour)
		SetFailState("Missing detour setup \""...KEY_FUNCTION_2..."\"");
	if (g_bLeft4Dead2)
	{
		if (!hDetour.Enable(Hook_Pre, DTR_OnRemoveSecondWeapon_Eb))
			SetFailState("Failed to pre-detour \""...KEY_FUNCTION_2..."\"");
	}
	else
	{
		if (!hDetour.Enable(Hook_Pre, DTR_OnRemoveSecondWeapon_Ev))
			SetFailState("Failed to pre-detour \""...KEY_FUNCTION_2..."\"");
	}
	
	delete hDetour;
	
	hDetour = DynamicDetour.FromConf(conf, KEY_FUNCTION_3);
	if (!hDetour)
		SetFailState("Missing detour setup \""...KEY_FUNCTION_3..."\"");
	if (!hDetour.Enable(Hook_Pre, DTR_OnSetViewModel))
		SetFailState("Failed to pre-detour \""...KEY_FUNCTION_3..."\"");
	
	delete hDetour;
	
	g_hPatch = MemoryPatch.CreateFromConf(conf, KEY_FUNCTION...KEY_PATCH_SURFIX);
	if (!g_hPatch.Validate())
		SetFailState("Failed to validate memory patch \""...KEY_FUNCTION...KEY_PATCH_SURFIX..."\"");
	
	delete conf;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: { g_bLeft4Dead2 = false; }
		case Engine_Left4Dead2: { g_bLeft4Dead2 = true; }
		default:
		{
			strcopy(error, err_max, "Plugin supports only Left 4 Dead & 2");
			return APLRes_SilentFailure;
		}
	}
	bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadSDK();
	
	ConVar cv = CreateConVar("pickup_switch_flags", "3", "Flags for Switching from current item (1:Weapons, 2: Passed Pills)", _, true, 0.0, true, 3.0);
	SwitchCVarChanged(cv, "", "");
	cv.AddChangeHook(SwitchCVarChanged);
	
	if (g_bLeft4Dead2)
	{
		cv = CreateConVar("pickup_incap_flags", "7", "Flags for Stopping Pick-up progress on Incapped Survivors (1:Spit Damage, 2:TankPunch, 4:TankRock", _, true, 0.0, true, 7.0);
		IncapCVarChanged(cv, "", "");
		cv.AddChangeHook(IncapCVarChanged);
		
		HookEvent("player_hurt", Event_PlayerHurt);
	}
	
	InitSwitchCookie();
	
	RegConsoleCmd("sm_secondary", ChangeSecondaryFlags);
	
	if (bLateLoad)
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i))
				OnClientPutInServer(i);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientDisconnect(i);
}

void InitSwitchCookie()
{
	if ((g_hSwitchCookie = Cookie.Find(COOKIE_NAME)) == null)
	{
		g_hSwitchCookie = new Cookie(COOKIE_NAME,
								"Flags for Switching from current item for every client.",
								CookieAccess_Public);
	}
}


/* ---------------------------------
//                                 |
//       Standard Client Stuff     |
//                                 |
// -------------------------------*/
public void OnClientPutInServer(int client)
{
	HookValidClient(client, true);
	if (!QuerySwitchCookie(client, iSwitchFlags[client]))
		iSwitchFlags[client] = SwitchFlags & FLAGS_SWITCH_MELEE;
}

public void OnClientDisconnect(int client)
{
	HookValidClient(client, false);
	
	if (!IsFakeClient(client))
		SetSwitchCookie(client, iSwitchFlags[client] & FLAGS_SWITCH_MELEE);
}

Action ChangeSecondaryFlags(int client, int args)
{
	if (client && IsClientInGame(client)) {
		if (~iSwitchFlags[client] & FLAGS_SWITCH_MELEE) {
			iSwitchFlags[client] |= FLAGS_SWITCH_MELEE;
			CPrintToChat(client, "%t", "Command_SwitchOff");
		} else {
			iSwitchFlags[client] &= ~FLAGS_SWITCH_MELEE;
			CPrintToChat(client, "%t", "Command_SwitchOn");
		}
	}
	return Plugin_Handled;
}


/* ---------------------------------
//                                 |
//       Yucky Timer Method~       |
//                                 |
// -------------------------------*/
void DelaySwitchHealth(any client)
{
	bCantSwitchHealth[client] = false;
}

void DelaySwitchSecondary(any client)
{
	bCantSwitchSecondary[client] = false;
}

void DelayValveSwitch(any client)
{
	bPreventValveSwitch[client] = false;
}


/* ---------------------------------
//                                 |
//         SDK Hooks, Fun!         |
//                                 |
// -------------------------------*/
void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (!client || !IsClientInGame(client) || !attacker)
		return;
	
	char weapon[64];
	event.GetString("weapon", weapon, sizeof(weapon));
	
	// Spitter damaging player that's being picked up.
	// Read the damage input differently, forcing the pick-up to end with every damage tick. (NOTE: Bots still bypass this)
	if ((IncapFlags & FLAGS_INCAP_SPIT) && L4D_IsPlayerIncapacitated(client))
	{
		int type = event.GetInt("type");
		if ((type & DMG_TYPE_SPIT) == DMG_TYPE_SPIT)
		{
			if (strcmp(weapon, "insect_swarm") == 0)
			{
				L4D_StopReviveAction(client);
			}
		}
	}
	
	// Tank Rock or Punch.
	else if (IsTank(attacker))
	{
		if (strcmp(weapon, "tank_rock") == 0)
		{
			if (IncapFlags & FLAGS_INCAP_TANKROCK)
			{
				L4D_StopReviveAction(client);
			}
		}
		else if (IncapFlags & FLAGS_INCAP_TANKPUNCH)
		{
			L4D_StopReviveAction(client);
		}
	}
}

Action WeaponCanSwitchTo(int client, int weapon)
{
	int wep = IdentifyWeapon(weapon);
	
	if (wep == WEPID_NONE) {
		return Plugin_Continue;
	}
	
	int wepslot = GetSlotFromWeaponId(wep);
	if (wepslot == -1) {
		return Plugin_Continue;
	}

	// Health Items.
	if ((SwitchFlags & FLAGS_SWITCH_PILLS) && (wepslot == L4D2WeaponSlot_LightHealthItem) && bCantSwitchHealth[client]) {
		return Plugin_Stop;
	}
	
	//Weapons.
	if ((iSwitchFlags[client] & FLAGS_SWITCH_MELEE) && (wepslot == L4D2WeaponSlot_Primary || wepslot == L4D2WeaponSlot_Secondary) && bCantSwitchSecondary[client]) {
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

Action WeaponEquip(int client, int weapon)
{
	// New Weapon
	int wep = IdentifyWeapon(weapon);

	if (wep == WEPID_NONE) {
		return Plugin_Continue;
	}
	
	// Weapon Currently Using
	int active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int wepname = IdentifyWeapon(active_weapon);
	
	if (wepname == WEPID_NONE) {
		return Plugin_Continue;
	}
	
	// Also Check if Survivor is incapped to make sure no issues occur (Melee players get given a pistol for example)
	if (!L4D_IsPlayerIncapacitated(client) && !bPreventValveSwitch[client] && GetSlotFromWeaponId(wep) != GetSlotFromWeaponId(wepname)) {
		if (GetDropTarget(weapon) == client) {
			bCantSwitchHealth[client] = true;
			RequestFrame(DelaySwitchHealth, client);
			return Plugin_Continue;
		}
		
		bCantSwitchSecondary[client] = true;
		RequestFrame(DelaySwitchSecondary, client);
	}
	return Plugin_Continue;
}

Action WeaponDrop(int client, int weapon)
{
	int active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	// Check if Player is Alive/Incapped and just dropped his secondary for a different one
	if (!L4D_IsPlayerIncapacitated(client) && IsPlayerAlive(client)) {
		if (weapon == active_weapon) {
			bPreventValveSwitch[client] = true;
			RequestFrame(DelayValveSwitch, client);
		}
	}
	return Plugin_Continue;
}


/* ---------------------------------
//                                 |
//       Dualies Workaround        |
//                                 |
// -------------------------------*/
bool IsSwitchingToDualCase(int client, int weapon)
{
	if (!IsValidEdict(weapon))
		return false;
	
	static char clsname[64];
	if (!GetEdictClassname(weapon, clsname, sizeof clsname))
		return false;
	
	if (clsname[0] != 'w')
		return false;
	
	if (strcmp(clsname[6], "_spawn") == 0)
	{
		if (GetEntProp(weapon, Prop_Send, "m_weaponID") != 1) // WEPID_PISTOL
			return false;
	}
	else if (strncmp(clsname[6], "_pistol", 7) != 0)
	{
		return false;
	}
	
	int secondary = GetPlayerWeaponSlot(client, 1);
	if (secondary == -1)
		return false;
	
	if (!GetEdictClassname(secondary, clsname, sizeof clsname))
		return false;
	
	return strcmp(clsname, "weapon_pistol") == 0 && !GetEntProp(secondary, Prop_Send, "m_hasDualWeapons");
}

MRESReturn DTR_OnEquipSecondWeapon(int weapon, DHookReturn hReturn)
{
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
	if (client == -1 || !IsClientInGame(client))
		return MRES_Ignored;
	
	if (~iSwitchFlags[client] & FLAGS_SWITCH_MELEE)
		return MRES_Ignored;
	
	if (!IsSwitchingToDualCase(client, weapon))
		return MRES_Ignored;
	
	g_hPatch.Enable();
	return MRES_Ignored;
}

MRESReturn DTR_OnEquipSecondWeapon_Post(int weapon, DHookReturn hReturn)
{
	g_hPatch.Disable();
	return MRES_Ignored;
}

// prevent setting viewmodel and next attack time
MRESReturn DTR_OnRemoveSecondWeapon_Ev(int weapon, DHookReturn hReturn)
{
	if (!GetEntProp(weapon, Prop_Send, "m_hasDualWeapons"))
		return MRES_Ignored;
	
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
	if (client == -1 || !IsClientInGame(client))
		return MRES_Ignored;
	
	int active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (active_weapon == -1 || active_weapon == weapon)
		return MRES_Ignored;
	
	if (~iSwitchFlags[client] & FLAGS_SWITCH_MELEE)
		return MRES_Ignored;
	
	SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
	SetEntProp(weapon, Prop_Send, "m_hasDualWeapons", 0);
	
	int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
	SetEntProp(weapon, Prop_Send, "m_iClip1", clip / 2);
	
	hReturn.Value = 1;
	return MRES_Supercede;
}

MRESReturn DTR_OnRemoveSecondWeapon_Eb(int weapon, DHookReturn hReturn, DHookParam hParams)
{
	bool force = hParams.Get(1);
	if (!force)
		return MRES_Ignored;
	
	return DTR_OnRemoveSecondWeapon_Ev(weapon, hReturn);
}


/* ---------------------------------
//                                 |
//         Skins Workaround        |
//                                 |
// -------------------------------*/
MRESReturn DTR_OnSetViewModel(int weapon)
{
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
	if (client == -1)
		return MRES_Ignored;
	
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == weapon)
		return MRES_Ignored;
	
	return MRES_Supercede;
}


/* ---------------------------------
//                                 |
//        Stocks, Functions        |
//                                 |
// -------------------------------*/
bool QuerySwitchCookie(int client, int &val)
{
	char buffer[8] = "";
	g_hSwitchCookie.Get(client, buffer, sizeof(buffer));
	if (strlen(buffer) > 0)
	{
		val = StringToInt(buffer);
		return true;
	}
	
	return false;
}

void SetSwitchCookie(int client, int val)
{
	char buffer[8];
	IntToString(val, buffer, sizeof(buffer));
	g_hSwitchCookie.Set(client, buffer);
}

void HookValidClient(int client, bool Hook)
{
	if (Hook) {
		SDKHook(client, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo);
		SDKHook(client, SDKHook_WeaponEquip, WeaponEquip);
		SDKHook(client, SDKHook_WeaponDrop, WeaponDrop);
	} else {
		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo);
		SDKUnhook(client, SDKHook_WeaponEquip, WeaponEquip);
		SDKUnhook(client, SDKHook_WeaponDrop, WeaponDrop);
	}
}

int GetDropTarget(int weapon)
{
	static int iOffs_m_hDropTarget = -1;
	static int iOffs_m_dropTimer = -1;
	if (iOffs_m_hDropTarget == -1)
	{
		iOffs_m_hDropTarget = FindSendPropInfo("CTerrorWeapon", "m_DroppedByInfectedGender") - 28;
		iOffs_m_dropTimer = iOffs_m_hDropTarget + 4;
	}
	
	if (GetGameTime() >= GetEntDataFloat(weapon, iOffs_m_dropTimer + 8))
		return -1;
	
	return GetEntDataEnt2(weapon, iOffs_m_hDropTarget);
}


/* ---------------------------------
//                                 |
//          Cvar Changes!          |
//                                 |
// -------------------------------*/
void SwitchCVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	SwitchFlags = cvar.IntValue;
}

void IncapCVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	IncapFlags = cvar.IntValue;
}
