#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_sound>
#include <sdkhooks>
#include <dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Charge Fall Damaga",
	author = "Forgetest",
	description = "Take fall damages while being charged.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
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
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d2_charge_fall_damage");
	delete gd.CreateDetourOrFail("CTerrorPlayer::OnFallDamage", DTR_OnFallDamage);
	delete gd;
}

MRESReturn DTR_OnFallDamage(int client, DHookParam hParams)
{
	if (GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 6)
		return MRES_Ignored;

	int victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
	if (victim == -1)
		return MRES_Ignored;

	float damage = hParams.Get(1);
	SDKHooks_TakeDamage(victim, 0, client, damage, DMG_FALL, .bypassHooks = false);

	float pos[3];
	GetClientAbsOrigin(victim, pos);
	EmitGameSoundToAll("Player.FallDamage", .origin = pos);

	return MRES_Ignored;
}