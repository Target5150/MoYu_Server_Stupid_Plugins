#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Fix Nextbot Collision",
	author = "Forgetest",
	description = "Reduce the possibility that commons jiggle around when close to each other.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

#define GAMEDATA_FILE "l4d_fix_nextbot_collision"

float g_flResolveScale = 3.0;

public void OnPluginStart()
{
	GameData gd = new GameData(GAMEDATA_FILE);
	if (!gd)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	MemoryPatch hPatch = CreateEnabledPatch(gd, "ZombieBotLocomotion::ResolveZombieCollisions__result_multiple_dummypatch");
	
	delete gd;
	
	Address pResultMultiple = hPatch.Address + view_as<Address>(4);
	StoreToAddress(pResultMultiple, GetAddressOfCell(g_flResolveScale), NumberType_Int32); 
	
	CreateConVarHook("l4d_nextbot_collision_resolve_scale",
					"0.33333333",
					"How much to scale the move vector as a result of resolving zombie collision.",
					FCVAR_CHEAT,
					true, 0.0, false, 0.0,
					CvarChg_ResolveScale);
}

void CvarChg_ResolveScale(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flResolveScale = 3.0 * convar.FloatValue;
}

MemoryPatch CreateEnabledPatch(GameData gd, const char[] name)
{
	MemoryPatch hPatch = MemoryPatch.CreateFromConf(gd, name);
	if (!hPatch.Enable())
		SetFailState("Failed to patch \"%s\"", name);
	
	return hPatch;
}

ConVar CreateConVarHook(const char[] name,
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