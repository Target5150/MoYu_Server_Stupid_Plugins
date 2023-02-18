#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D2] Pounce Damage Uncap",
	author = "Forgetest, ProdigySim",
	description = "A port of ProdigySim's work. Patch L4D2 to allow uncapping the pounce range limits.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d2_pounce_damage_uncap"
#define FUNCTION_NAME "CTerrorPlayer::OnPouncedOnSurvivor"
#define PATCH_OFFSET view_as<Address>(4)

#define FLT_MAX 3.402823466e38

float g_flMaxRange;
float g_flMinRange, g_flMinRangeNegate;
float g_flRangeDiffFactor;

public void OnPluginStart()
{
	CreateConVarHook("z_pounce_damage_range_max",
				"1000.0",
				"Range at which a pounce is worth the maximum bonus damage.",
				FCVAR_GAMEDLL|FCVAR_CHEAT,
				true, 0.0, false, 0.0,
				CvarChg_MaxRange);
	
	CreateConVarHook("z_pounce_damage_range_min",
				"300.0",
				"Minimum range for a pounce to be worth bonus damage.",
				FCVAR_GAMEDLL|FCVAR_CHEAT,
				true, 0.0, false, 0.0,
				CvarChg_MinRange);
	
	GameData gd = new GameData(GAMEDATA_FILE);
	if (!gd)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	int os = gd.GetOffset("OS");
	if (os == -1)
		SetFailState("Missing offset \"OS\"");
	
	MemoryPatch patch = MemoryPatch.CreateFromConf(gd, FUNCTION_NAME..."__MinRange_cond");
	if (!patch.Enable())
		SetFailState("Failed to patch \""...FUNCTION_NAME..."__MinRange_cond"..."\"");
	
	StoreToAddress(patch.Address + PATCH_OFFSET, GetAddressOfCell(g_flMinRange), NumberType_Int32);
	
	patch = MemoryPatch.CreateFromConf(gd, FUNCTION_NAME..."__MaxRange_cond");
	if (!patch.Enable())
		SetFailState("Failed to patch \""...FUNCTION_NAME..."__MaxRange_cond"..."\"");
	
	StoreToAddress(patch.Address + PATCH_OFFSET, GetAddressOfCell(g_flMaxRange), NumberType_Int32);
	
	if (os == 1)
	{
		patch = MemoryPatch.CreateFromConf(gd, FUNCTION_NAME..."__MinRangeNegate_add");
		if (!patch.Enable())
			SetFailState("Failed to patch \""...FUNCTION_NAME..."__MinRangeNegate_add"..."\"");
		
		StoreToAddress(patch.Address + PATCH_OFFSET, GetAddressOfCell(g_flMinRangeNegate), NumberType_Int32);
	}
	
	patch = MemoryPatch.CreateFromConf(gd, FUNCTION_NAME..."__RangeDiffFactor_mul");
	if (!patch.Enable())
		SetFailState("Failed to patch \""...FUNCTION_NAME..."__RangeDiffFactor_mul"..."\"");
	
	StoreToAddress(patch.Address + PATCH_OFFSET, GetAddressOfCell(g_flRangeDiffFactor), NumberType_Int32);
	
	delete gd;
}

void CvarChg_MaxRange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flMaxRange = convar.FloatValue;
	RecalculateDifference();
}

void CvarChg_MinRange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flMinRange = convar.FloatValue;
	g_flMinRangeNegate = -g_flMinRange;
	RecalculateDifference();
}

void RecalculateDifference()
{
	float flDiff = g_flMaxRange - g_flMinRange;
	
	g_flRangeDiffFactor = (flDiff == 0.0) ? FLT_MAX : 1.0 / flDiff;
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
