#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Claw Damage",
	author = "Forgetest",
	description = "Make claw damage follow convar \"*_pz_claw_dmg\".",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	public DynamicHook CreateDHookOrFail(const char[] name) {
		DynamicHook hSetup = DynamicHook.FromConf(this, name);
		if (!hSetup) SetFailState("Missing dhook setup \"%s\"", name);
		return hSetup;
	}
}

DynamicHook g_DHookGetPlayerDamage;
StringMap g_MapClawDamageCvars;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_claw_dmg");
	g_DHookGetPlayerDamage = gd.CreateDHookOrFail("CClaw::GetPlayerDamage");
	delete gd;

	g_MapClawDamageCvars = new StringMap();
	g_MapClawDamageCvars.SetValue("weapon_smoker_claw", FindConVar("smoker_pz_claw_dmg"));
	g_MapClawDamageCvars.SetValue("weapon_boomer_claw", FindConVar("boomer_pz_claw_dmg"));
	g_MapClawDamageCvars.SetValue("weapon_hunter_claw", FindConVar("hunter_pz_claw_dmg"));
	g_MapClawDamageCvars.SetValue("weapon_spitter_claw", FindConVar("spitter_pz_claw_dmg"));
	g_MapClawDamageCvars.SetValue("weapon_jockey_claw", FindConVar("jockey_pz_claw_dmg"));
	g_MapClawDamageCvars.SetValue("weapon_charger_claw", FindConVar("charger_pz_claw_dmg"));
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= MaxClients || classname[0] != 'w')
		return;
	
	ConVar cv;
	if (g_MapClawDamageCvars.GetValue(classname, cv) && cv)
		g_DHookGetPlayerDamage.HookEntity(Hook_Pre, entity, DTR_CClaw_GetPlayerDamage);
}

MRESReturn DTR_CClaw_GetPlayerDamage(int claw, DHookReturn hReturn, DHookParam hParams)
{
	char cls[64];
	GetEdictClassname(claw, cls, sizeof(cls));

	ConVar cv;
	g_MapClawDamageCvars.GetValue(cls, cv);

	hReturn.Value = cv.FloatValue;
	return MRES_Supercede;
}
