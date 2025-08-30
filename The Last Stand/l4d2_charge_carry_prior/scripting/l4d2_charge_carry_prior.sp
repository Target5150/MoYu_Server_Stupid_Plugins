#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D2] Charge Carry Prior",
	author = "Forgetest",
	description = "Optimize for charges from above and potential multi-charges at corner.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d2_charge_carry_prior");
	gd.CreatePatchOrFail("charge_start_carry_collision_test", true);
	delete gd;
}