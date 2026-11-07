#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Fix Replace Max HP",
	author = "Forgetest",
	description = "Fix max health not restored after replacements.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_fix_replace_maxhp");
	delete gd.CreateDetourOrFail("l4d_fix_replace_maxhp::ZombieReplacement::Save", _, DTR_Replacement_Save);
	delete gd.CreateDetourOrFail("l4d_fix_replace_maxhp::ZombieReplacement::Restore", _, DTR_Replacement_Restore);
	delete gd.CreateDetourOrFail("l4d_fix_replace_maxhp::SurvivorReplacement::Save", _, DTR_Replacement_Save);
	delete gd.CreateDetourOrFail("l4d_fix_replace_maxhp::SurvivorReplacement::Restore", _, DTR_Replacement_Restore);
	delete gd.CreateDetourOrFail("l4d_fix_replace_maxhp::ZombieManager::ReplaceTank", DTR_ReplaceTank, DTR_ReplaceTank_Post);
	delete gd;
}

static int g_iSavedMaxhp[MAXPLAYERS+1];

MRESReturn DTR_Replacement_Save(Address pThis, DHookParam hParams)
{
	int replaced = hParams.Get(1);
	g_iSavedMaxhp[replaced] = GetEntProp(replaced, Prop_Data, "m_iMaxHealth");
	return MRES_Ignored;
}

MRESReturn DTR_Replacement_Restore(Address pThis, DHookParam hParams)
{
	int replaced = hParams.Get(1);
	int client = hParams.Get(2);
	SetEntProp(client, Prop_Data, "m_iMaxHealth", g_iSavedMaxhp[replaced]);
	return MRES_Ignored;
}

MRESReturn DTR_ReplaceTank(DHookReturn hReturn, DHookParam hParams)
{
	int replaced = hParams.Get(1);
	g_iSavedMaxhp[replaced] = GetEntProp(replaced, Prop_Data, "m_iMaxHealth");
	return MRES_Ignored;
}

MRESReturn DTR_ReplaceTank_Post(DHookReturn hReturn, DHookParam hParams)
{
	if (hReturn.Value == false)
		return MRES_Ignored;

	int replaced = hParams.Get(1);
	int client = hParams.Get(2);
	SetEntProp(client, Prop_Data, "m_iMaxHealth", g_iSavedMaxhp[replaced]);
	return MRES_Ignored;
}
