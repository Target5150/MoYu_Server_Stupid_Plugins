#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = 
{
	name = "[L4D & 2] Fix Nextbot Collision",
	author = "Forgetest",
	description = "Reduce the possibility that commons jiggle around when close to each other.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	property GameData Super {
		public get() { return view_as<GameData>(this); }
	}
	public int GetOffset(const char[] key) {
		int offset = this.Super.GetOffset(key);
		if (offset == -1) SetFailState("Missing offset \"%s\"", key);
		return offset;
	}
	public Address GetAddress(const char[] key) {
		Address ptr = this.Super.GetAddress(key);
		if (ptr == Address_Null) SetFailState("Missing address \"%s\"", key);
		return ptr;
	}
	public MemoryPatch CreatePatchOrFail(const char[] name, bool enable = false) {
		MemoryPatch hPatch = MemoryPatch.CreateFromConf(this, name);
		if (!(enable ? hPatch.Enable() : hPatch.Validate()))
			SetFailState("Failed to patch \"%s\"", name);
		return hPatch;
	}
}

Address g_pResolveScale = Address_Null;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_fix_nextbot_collision");
	
	MemoryBlock pMem = new MemoryBlock(4);
	pMem.StoreToOffset(0, view_as<int>(3.0), NumberType_Int32);
	g_pResolveScale = pMem.Address;

	MemoryPatch hPatch = gd.CreatePatchOrFail("ZombieBotLocomotion::ResolveZombieCollisions__result_multiple_dummypatch", true);
	StoreToAddress(hPatch.Address + view_as<Address>(4), g_pResolveScale, NumberType_Int32);

	if (gd.GetOffset("OS") == 1 && GetEngineVersion() == Engine_Left4Dead)
	{
		hPatch = gd.CreatePatchOrFail("ZombieBotLocomotion::ResolveZombieCollisions__result_multiple_dummypatch_linuxl4d1_p2", true);
		StoreToAddress(hPatch.Address + view_as<Address>(4), g_pResolveScale, NumberType_Int32);

		hPatch = gd.CreatePatchOrFail("ZombieBotLocomotion::ResolveZombieCollisions__result_multiple_dummypatch_linuxl4d1_p3", true);
		StoreToAddress(hPatch.Address + view_as<Address>(4), g_pResolveScale, NumberType_Int32);
	}

	delete gd;
	
	CreateConVarHook("l4d_nextbot_collision_resolve_scale",
					"0.33333333",
					"How much to scale the move vector as a result of resolving zombie collision.",
					FCVAR_CHEAT,
					true, 0.0, false, 0.0,
					CvarChg_ResolveScale);
}

void CvarChg_ResolveScale(ConVar convar, const char[] oldValue, const char[] newValue)
{
	float value = 3.0 * convar.FloatValue;
	StoreToAddress(g_pResolveScale, view_as<int>(value), NumberType_Int32);
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