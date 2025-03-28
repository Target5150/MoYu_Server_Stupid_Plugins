#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <actions>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Aggressive Coop Tank",
	author = "Forgetest",
	description = "Force Tank in coop to attack instead of waiting.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	public MemoryPatch CreatePatchOrFail(const char[] name, bool enable = false) {
		MemoryPatch hPatch = MemoryPatch.CreateFromConf(this, name);
		if (!(enable ? hPatch.Enable() : hPatch.Validate()))
			SetFailState("Failed to patch \"%s\"", name);
		return hPatch;
	}
}

MemoryPatch g_AggressivePatch;
ActionConstructor g_TankAttackCtor;
int g_iTankClass = 8;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_iTankClass = 5;
		case Engine_Left4Dead2: g_iTankClass = 8;
		default: { strcopy(error, err_max, "Plugin supports L4D & 2 only"); return APLRes_SilentFailure; }
	}

	CreateNative("ForceAITankAttack", Ntv_ForceAITankAttack);
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_aggressive_coop_tank");

	g_AggressivePatch = gd.CreatePatchOrFail("aggressive_tank_patch", false);

	g_TankAttackCtor = ActionConstructor.SetupFromConf(gd, "TankAttack::TankAttack");
	if (!g_TankAttackCtor.Finish())
		SetFailState("Failed to build ActionConstructor for \"TankAttack::TankAttack\"");

	delete gd;

	CreateConVarHook("l4d_aggressive_coop_tank_enable", "1", "Always force coop tank to attack.", FCVAR_NONE, true, 0.0, true, 1.0, CvarChg_Enable);
}

void CvarChg_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar.BoolValue) 
		g_AggressivePatch.Enable();
	else
		g_AggressivePatch.Disable();
}

any Ntv_ForceAITankAttack(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || !IsClientInGame(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d not in-game", client);
	
	if (GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != g_iTankClass || !IsPlayerAlive(client))
		return false;
	
	return ForceAITankAttack(client);
}

bool ForceAITankAttack(int client)
{
	BehaviorAction action = ActionsManager.GetAction(client, "TankIdle");
	if (action == INVALID_ACTION)
		return false;
	
	action.UpdatePost = TankIdle_OnUpdatePost;
	return true;
}

Action TankIdle_OnUpdatePost(BehaviorAction action, int actor, float interval, ActionResult result)
{
	return action.ChangeTo(g_TankAttackCtor.Execute(), "Forced by plugin \""..."l4d_aggressive_coop_tank"..."\"");
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
