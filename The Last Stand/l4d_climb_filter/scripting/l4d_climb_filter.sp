#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Climb Filter",
	author = "Forgetest",
	description = "Prevent tank from climbing onto certain entities (i.e. projectiles).",
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

StringMap g_FilterMap;
StringMap g_FuzzyFilterMap;
StringMapSnapshot g_FuzzyFilterSnapshot;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_climb_filter");

	delete gd.CreateDetourOrFail("PlayerLocomotion::IsClimbPossible", DTR__IsClimbPossible);
	delete gd;

	g_FilterMap = new StringMap();
	g_FilterMap.SetValue("pipe_bomb_projectile", true);
	g_FilterMap.SetValue("molotov_projectile", true);
	g_FilterMap.SetValue("vomitjar_projectile", true);
	g_FilterMap.SetValue("grenade_launcher_projectile", true);

	g_FuzzyFilterMap = new StringMap();
	g_FuzzyFilterSnapshot = g_FuzzyFilterMap.Snapshot();

	RegServerCmd("climb_filter_add_class", Cmd_AddClass);
	RegServerCmd("climb_filter_remove_class", Cmd_RemoveClass);
}

Action Cmd_AddClass(int args)
{
	if (args != 1)
	{
		PrintToServer("[SM] Usage: climb_filter_add_class <classname>");
		return Plugin_Handled;
	}

	char cls[64];
	int len = GetCmdArg(1, cls, sizeof(cls));

	// len must be > 0
	if (cls[len-1] == '*')
	{
		if (!g_FuzzyFilterMap.SetValue(cls, true, false))
		{
			PrintToServer("[l4d_climb_filter] Class (%s) already exists!", cls);
			return Plugin_Handled;
		}
		delete g_FuzzyFilterSnapshot;
		g_FuzzyFilterSnapshot = g_FuzzyFilterMap.Snapshot();
	}
	else
	{
		if (!g_FilterMap.SetValue(cls, true, false))
		{
			PrintToServer("[l4d_climb_filter] Class (%s) already exists!", cls);
			return Plugin_Handled;
		}
	}

	PrintToServer("[l4d_climb_filter] Added filter class (%s)", cls);
	return Plugin_Handled;
}

Action Cmd_RemoveClass(int args)
{
	if (args != 1)
	{
		PrintToServer("[SM] Usage: climb_filter_remove_class <classname>");
		return Plugin_Handled;
	}

	char cls[64];
	int len = GetCmdArg(1, cls, sizeof(cls));

	// len must be > 0
	if (cls[len-1] == '*')
	{
		if (!g_FuzzyFilterMap.Remove(cls))
		{
			PrintToServer("[l4d_climb_filter] Class (%s) doesn't exist!", cls);
			return Plugin_Handled;
		}
		delete g_FuzzyFilterSnapshot;
		g_FuzzyFilterSnapshot = g_FuzzyFilterMap.Snapshot();
	}
	else
	{
		if (!g_FilterMap.Remove(cls))
		{
			PrintToServer("[l4d_climb_filter] Class (%s) doesn't exist!", cls);
			return Plugin_Handled;
		}
	}

	PrintToServer("[l4d_climb_filter] Removed filter class (%s)", cls);
	return Plugin_Handled;
}

MRESReturn DTR__IsClimbPossible(DHookReturn hReturn, DHookParam hParams)
{
	int entity = -1;
	if (!hParams.IsNull(2))
		entity = hParams.Get(2);
	
	if (!IsValidEdict(entity))
		return MRES_Ignored;

	// probably we want to check if the climbing actor is a Tank or at least thr right target
	// but perhaps unnecessary

	char cls[64];
	GetEdictClassname(entity, cls, sizeof(cls));

	if (g_FilterMap.ContainsKey(cls))
	{
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	char query[64];
	for (int i = g_FuzzyFilterSnapshot.Length-1; i >= 0; --i)
	{
		g_FuzzyFilterSnapshot.GetKey(i, query, sizeof(query));

		if (NamesMatch(query, cls))
		{
			hReturn.Value = 0;
			return MRES_Supercede;
		}
	}

	return MRES_Ignored;
}

// https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/sp/src/game/server/baseentity.cpp#L2972
bool NamesMatch(const char[] pszQuery, const char[] pszNameToMatch)
{
	int queryPtr = 0;
	int namePtr = 0;

	while ( pszNameToMatch[namePtr] && pszQuery[queryPtr] )
	{
		char cName = pszNameToMatch[namePtr];
		char cQuery = pszQuery[queryPtr];
		// simple ascii case conversion
		if ( cName == cQuery )
		{}
		else if ( cName - 'A' <= 'Z' - 'A' && cName - 'A' + 'a' == cQuery )
		{}
		else if ( cName - 'a' <= 'z' - 'a' && cName - 'a' + 'A' == cQuery )
		{}
		else
			break;
		++namePtr;
		++queryPtr;
	}

	if ( pszQuery[queryPtr] == 0 && pszNameToMatch[namePtr] == 0 )
		return true;

	// @TODO (toml 03-18-03): Perhaps support real wildcards. Right now, only thing supported is trailing *
	if ( pszQuery[queryPtr] == '*' )
		return true;

	return false;
}
