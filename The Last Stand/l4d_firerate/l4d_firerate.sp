#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Fire Rates",
	author = "Forgetest",
	description = "ConVars to change fire rates of guns.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d_firerate"

DynamicHook g_DHRateOfFire;

static const char g_ksWeapons[][] = {
	"weapon_pistol", "weapon_pistol_magnum",
	"weapon_smg", "weapon_smg_silenced", "weapon_smg_mp5",
	"weapon_pumpshotgun", "weapon_shotgun_chrome",
	"weapon_autoshotgun", "weapon_shotgun_spas",
	"weapon_rifle", "weapon_rifle_desert", "weapon_rifle_ak47", "weapon_rifle_sg552",
	"weapon_hunting_rifle", "weapon_sniper_military",
	"weapon_sniper_awp", "weapon_sniper_scout",
	"weapon_rifle_m60",
};
StringMap g_mapWeaponClass;

#define MAX_WEAPON_NUM sizeof(g_ksWeapons)
enum
{
	FIRERATE_NORMAL,
	FIRERATE_INCAPPED,
	
	FIRERATE_TYPE_SIZE,
};
ConVar g_cvFireRates[MAX_WEAPON_NUM][FIRERATE_TYPE_SIZE];

public void OnPluginStart()
{
	GameData gd = new GameData(GAMEDATA_FILE);
	if (!gd)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	g_DHRateOfFire = DynamicHook.FromConf(gd, "CTerrorGun::GetRateOfFire");
	if (!g_DHRateOfFire)
		SetFailState("Missing dhook setup \"CTerrorGun::GetRateOfFire\"");
	
	delete gd;
	
	g_mapWeaponClass = new StringMap();
	for (int i = 0; i < MAX_WEAPON_NUM; ++i)
	{
		g_mapWeaponClass.SetValue(g_ksWeapons[i], i);
		
		char name[64], description[64];
		
		FormatEx(name, sizeof(name), "l4d_firerate_%s_normal", g_ksWeapons[i][7]);
		FormatEx(description, sizeof(description), "Set normal fire rate of %s", g_ksWeapons[i][7]);
		g_cvFireRates[i][FIRERATE_NORMAL] = CreateConVar(name, "0.0", description, FCVAR_NONE, true, 0.0);
		
		FormatEx(name, sizeof(name), "l4d_firerate_%s_incap", g_ksWeapons[i][7]);
		FormatEx(description, sizeof(description), "Set incapped fire rate of %s", g_ksWeapons[i][7]);
		g_cvFireRates[i][FIRERATE_INCAPPED] = CreateConVar(name, "0.0", description, FCVAR_NONE, true, 0.0);
	}
	
	AutoExecConfig(true);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_mapWeaponClass.ContainsKey(classname))
		return;
	
	g_DHRateOfFire.HookEntity(Hook_Pre, entity, DTR_GetRateOfFire);
}

MRESReturn DTR_GetRateOfFire(int weapon, DHookReturn hReturn)
{
	static char classname[64];
	if (!GetEdictClassname(weapon, classname, sizeof(classname)))
		return MRES_Ignored;
	
	int id;
	if (!g_mapWeaponClass.GetValue(classname, id))
		return MRES_Ignored;
	
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
	if (client == -1 || !IsClientInGame(client))
		return MRES_Ignored;
	
	float flCycleTime = g_cvFireRates[id][GetFireRateType(client)].FloatValue;
	if (flCycleTime == 0.0)
		return MRES_Ignored;
	
	hReturn.Value = flCycleTime;
	
// 1.12.0.7000
// https://github.com/alliedmodders/sourcemod/commit/8e0039aaec2bd449bc4f73d82307bde
#if SOURCEMOD_V_MAJOR > 1
  || (SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR >= 12 && SOURCEMOD_V_REV >= 7000)
	return MRES_Supercede;
#else
	return MRES_Override;
#endif
}

int GetFireRateType(int client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		return FIRERATE_INCAPPED;
	
	return FIRERATE_NORMAL;
}