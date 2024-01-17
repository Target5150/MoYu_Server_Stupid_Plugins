#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Unlock Versus Shove",
	author = "Forgetest",
	description = "Unlocks versus-only shove features for all gamemodes.",
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

MemoryPatch g_PatchShoveFOV[2];
MemoryPatch g_PatchTongueShove;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_unlock_versus_shove");
	g_PatchShoveFOV[0] = gd.CreatePatchOrFail("CTerrorWeapon::OnHit__hunter_fov");
	g_PatchShoveFOV[1] = gd.CreatePatchOrFail("CTerrorPlayer::OnShovedByLunge__shove_fov");
	g_PatchTongueShove = gd.CreatePatchOrFail("CTerrorWeapon::OnHit__tongue_shove");
	delete gd;

	CreateConVarHook("l4d_unlock_versus_shove_fov", "0", "Patch to enable fov check on shoves.", FCVAR_CHEAT, true, 0.0, true, 1.0, CvatChg_ShoveFOV);
	CreateConVarHook("l4d_unlock_versus_tongue_shove", "0", "Patch to block instant clears on pulled survivors.", FCVAR_CHEAT, true, 0.0, true, 1.0, CvatChg_TongueShove);
}

void CvatChg_ShoveFOV(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar.BoolValue)
	{
		g_PatchShoveFOV[0].Enable();
		g_PatchShoveFOV[1].Enable();
	}
	else
	{
		g_PatchShoveFOV[0].Disable();
		g_PatchShoveFOV[1].Disable();
	}
}

void CvatChg_TongueShove(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar.BoolValue)
	{
		g_PatchTongueShove.Enable();
	}
	else
	{
		g_PatchTongueShove.Disable();
	}
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