#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <sdkhooks>
#include <left4dhooks>

#include "include/countdowntimer"

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Auto Pick-up Weapon",
	author = "Forgetest",
	description = "Re-implement the broken feature from CS of auto picking-up weapons.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

int g_iOffs_DropInfo = -1;

bool g_bAbsorbDualWield;
float g_flAbsorbSelfDropInterval;

#include "l4d_auto_pickup_weapon/absorbpref.sp"

public void OnPluginStart()
{
	LoadPluginTranslations("l4d_auto_pickup_weapon.phrases");

	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: { g_iOffs_DropInfo = FindSendPropInfo("CTerrorWeapon", "m_flVsLastSwingTime") + 12; }
		case Engine_Left4Dead2: { g_iOffs_DropInfo = FindSendPropInfo("CTerrorWeapon", "m_DroppedByInfectedGender") - 32; }
		default: { SetFailState("Plugin supports L4D & 2 only."); }
	}

	AbsorbPref_Init();

	CreateConVarHook(
		"auto_pickup_weapon_dualwield",
		"1",
		"Auto equip guns that can be dual wielded.",
		FCVAR_NONE, true, 0.0, true, 1.0, CvarChg_DualWield);
	CreateConVarHook(
		"auto_pickup_weapon_self_drop_interval",
		"1.0",
		"Interval time for auto equipping guns dropped yourself.",
		FCVAR_NONE, true, 0.0, false, 0.0, CvarChg_SelfDropInterval);
	
	AutoExecConfig(true, "l4d_auto_pickup_weapon");

	RegConsoleCmd("sm_absorb", Cmd_Absorb);
	RegConsoleCmd("sm_pickup", Cmd_Absorb);
}

void CvarChg_DualWield(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bAbsorbDualWield = convar.BoolValue;
}

void CvarChg_SelfDropInterval(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flAbsorbSelfDropInterval = convar.FloatValue;
}

Action Cmd_Absorb(int client, int args)
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;
	
	if (AbsorbPref_Toggle(client))
	{
		CReplyToCommand(client, "%t", AbsorbPref_Get(client) ? "Cmd_Absorb_ToggleOn" : "Cmd_Absorb_ToggleOff");
	}
	
	return Plugin_Handled;
}

bool g_bMapStarted = false;
public void OnMapStart()
{
	g_bMapStarted = true;

	int entity = MaxClients+1;
	while ((entity = FindEntityByClassname(entity, "weapon_*")) != INVALID_ENT_REFERENCE)
	{
		HookWeapon(entity);
	}

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i)) OnClientPutInServer(i);
	}
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponDropPost, SDK_OnWeaponDrop_Post);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bMapStarted)
		return;

	if (classname[0] == 'w' && !strncmp(classname, "weapon_", 7))
	{
		HookWeapon(entity);
	}
}

void HookWeapon(int entity)
{
	if (!IsAbsorbableGun(entity))
		return;

	SDKHook(entity, SDKHook_TouchPost, SDK_OnTouch_Post);
}

void SDK_OnWeaponDrop_Post(int client, int weapon)
{
	if (!IsValidEdict(weapon))
		return;
	
	// Make it dropped for nobody, but could be overridden later (i.e. passing pills)
	GetDropTimer(weapon).Start(5.0);
	SetDroppingPlayer(weapon, client);
	SetDropTarget(weapon, -1);
}

void SDK_OnTouch_Post(int weapon, int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return;
	
	if (GetClientTeam(client) != 2 || !IsPlayerAlive(client) || L4D_IsPlayerIncapacitated(client))
		return;
	
	if (GetEntPropEnt(weapon, Prop_Send, "m_hOwner") == client)
		return;
	
	if (!AbsorbPref_Get(client))
		return;
	
	char cls[64];
	GetEdictClassname(weapon, cls, sizeof(cls));
	
	int slot = L4D2_GetIntWeaponAttribute(cls, L4D2IWA_Bucket);
	int slotWeapon = GetPlayerWeaponSlot(client, slot);

	// Don;t equip it if we already have one in its slot or it cannot be dual wielded
	if (slotWeapon != -1)
	{
		if (!IsSameWeapon(weapon, slotWeapon)
		 || !g_bAbsorbDualWield
		 || !WeaponCanBeDualWielded(slotWeapon))
		{
			return;
		}
	}

	CountdownTimerPtr ct = GetDropTimer(weapon);

	// Don't auto equip guns recently dropped by ourself
	if (ct.HasStarted() && !ct.IsElasped())
	{
		if (GetDroppingPlayer(weapon) == client
		 && ct.GetElapsedTime() < g_flAbsorbSelfDropInterval)
		{
			return;
		}
	}

	if (GetDroppingPlayer(weapon) != client && GetDropTarget(weapon) == -1) 
	{
		// Assume it was dropped for us and just say thanks :)
		SetDropTarget(weapon, client);
	}

	// NOTE: "EquipPlayerWeapon" doesn't work as expected for guns that can be dual wielded.
	AcceptEntityInput(weapon, "Use", client);
}

bool IsAbsorbableGun(int entity)
{
	char cls[64];
	GetEdictClassname(entity, cls, sizeof(cls));
	
	// FIXME: Do spawners really trigger touch?
	if (strncmp(cls, "weapon_", 7) || StrContains(cls, "_spawn") != -1)
		return false;
	
	if (!L4D2_IsValidWeapon(cls))
		return false;
	
	return true;
}

bool IsSameWeapon(int a, int b)
{
	char cls_a[32], cls_b[32];
	GetEdictClassname(a, cls_a, sizeof(cls_a));
	GetEdictClassname(b, cls_b, sizeof(cls_b));

	return strcmp(cls_a, cls_b) == 0; // *sigh*
}

bool WeaponCanBeDualWielded(int weapon)
{
	char cls[64];
	GetEdictClassname(weapon, cls, sizeof(cls));

	return strcmp(cls, "weapon_pistol") == 0;
}

/**
 * in CTerrorWeapon.LocalL4DWeaponData:
 * - m_hDropTarget (~ +0) (size 4)
 * - m_hDroppingPlayer (~ +4) (size 4)
 * - m_dropTimer (~ +8) (size 12)
 */

stock int GetDroppingPlayer(int weapon)
{
	return GetEntDataEnt2(weapon, g_iOffs_DropInfo);
}

stock void SetDroppingPlayer(int weapon, int client)
{
	SetEntDataEnt2(weapon, g_iOffs_DropInfo, client);
}

stock CountdownTimerPtr GetDropTimer(int weapon)
{
	return view_as<CountdownTimerPtr>(GetEntityAddress(weapon) + view_as<Address>(g_iOffs_DropInfo + 8));
}

stock int GetDropTarget(int weapon)
{
	return GetEntDataEnt2(weapon, g_iOffs_DropInfo + 4);
}

stock void SetDropTarget(int weapon, int client)
{
	SetEntDataEnt2(weapon, g_iOffs_DropInfo + 4, client);
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

stock ConVar CreateConVarHook(const char[] name,
	const char[] defaultValue,
	const char[] description="",
	int flags=0,
	bool hasMin=false, float min=0.0,
	bool hasMax=false, float max=0.0,
	ConVarChanged callback)
{
	ConVar cv = CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
	
	Call_StartFunction(INVALID_HANDLE, callback);
	Call_PushCell(cv);
	Call_PushNullString();
	Call_PushNullString();
	Call_Finish();
	
	cv.AddChangeHook(callback);
	
	return cv;
}
