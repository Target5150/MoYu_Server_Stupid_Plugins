#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <collisionhook>
#include <sourcescramble>
#include <dhooks>

#define PLUGIN_VERSION "1.3"

public Plugin myinfo = 
{
	name = "[L4D & 2] Tongue Block Fix",
	author = "Forgetest",
	description = "Fix infected teammate blocking tongue chasing.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

#define GAMEDATA_FILE "l4d_tongue_block_fix"

#define KEY_ONUPDATEEXTENDINGSTATE "CTongue::OnUpdateExtendingState"
#define KEY_UPDATETONGUETARGET "CTongue::UpdateTongueTarget"
#define KEY_ISTARGETVISIBLE "TongueTargetScan<CTerrorPlayer>::IsTargetVisible"
#define KEY_SETPASSENTITY "CTraceFilterSimple::SetPassEntity"

#define PATCH_ARG "__AddEntityToIgnore_argpatch"
#define PATCH_PASSENT "__TraceFilterTongue_passentpatch"
#define PATCH_DUMMY "__AddEntityToIgnore_dummypatch"

DynamicDetour g_hDetour;

int
	g_iTankClass,
	g_iTipFlag,
	g_iFlyFlag;

enum
{
	TIP_GENERIC	= (1 << 0),
	TIP_TANK	= (1 << 1),
};

enum
{
	FLY_GENERIC		= (1 << 0),
	FLY_TANK		= (1 << 1),
	FLY_SURVIVOR	= (1 << 2),
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: { g_iTankClass = 5; }
		case Engine_Left4Dead2: { g_iTankClass = 8; }
		default:
		{
			strcopy(error, err_max, "Plugin supports Left 4 Dead & 2 only.");
			return APLRes_SilentFailure;
		}
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData conf = new GameData(GAMEDATA_FILE);
	if (!conf)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	Address pfnSetPassEntity = conf.GetAddress(KEY_SETPASSENTITY);
	if (pfnSetPassEntity == Address_Null)
		SetFailState("Failed to get address of \""...KEY_SETPASSENTITY..."\"");
	
	CreateEnabledPatch(conf, KEY_ONUPDATEEXTENDINGSTATE...PATCH_ARG);
	CreateEnabledPatch(conf, KEY_ONUPDATEEXTENDINGSTATE...PATCH_PASSENT);
	
	MemoryPatch hPatch = CreateEnabledPatch(conf, KEY_ONUPDATEEXTENDINGSTATE...PATCH_DUMMY);
	PatchNearJump(0xE8, hPatch.Address, pfnSetPassEntity);
	
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		hPatch = CreateEnabledPatch(conf, KEY_ISTARGETVISIBLE...PATCH_DUMMY);
		PatchNearJump(0xE8, hPatch.Address, pfnSetPassEntity);
	}
	
	g_hDetour = DynamicDetour.FromConf(conf, KEY_UPDATETONGUETARGET);
	if (!g_hDetour)
		SetFailState("Missing detour setup \""...KEY_UPDATETONGUETARGET..."\"");
	
	delete conf;
	
	CreateConVarHook("tongue_tip_through_teammate",
					"0",
					"Whether smoker can shoot his tongue through his teammates.\n"
				...	"1 = Through generic SIs, 2 = Through Tank, 3 = All, 0 = Disabled",
					FCVAR_SPONLY,
					true, 0.0, true, 3.0,
					CvarChg_TipThroughTeammate);
	
	CreateConVarHook("tongue_fly_through_teammate",
					"5",
					"Whether tongue can go through his teammates once shot.\n"
				...	"1 = Through generic SIs, 2 = Through Tank, 4 = Through Survivors, 7 = All, 0 = Disabled",
					FCVAR_SPONLY,
					true, 0.0, true, 7.0,
					CvarChg_FlyThroughTeammate);
}

void CvarChg_TipThroughTeammate(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iTipFlag = convar.IntValue;
	ToggleDetour(g_iTipFlag > 0);
}

void CvarChg_FlyThroughTeammate(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iFlyFlag = convar.IntValue;
}

void ToggleDetour(bool enable)
{
	static bool enabled = false;
	if (enable && !enabled)
	{
		if (!g_hDetour.Enable(Hook_Pre, DTR_OnUpdateTongueTarget))
			SetFailState("Failed to pre-detour \""...KEY_UPDATETONGUETARGET..."\"");
		if (!g_hDetour.Enable(Hook_Post, DTR_OnUpdateTongueTarget_Post))
			SetFailState("Failed to post-detour \""...KEY_UPDATETONGUETARGET..."\"");
		enabled = true;
	}
	else if (!enable && enabled)
	{
		if (!g_hDetour.Disable(Hook_Pre, DTR_OnUpdateTongueTarget))
			SetFailState("Failed to remove pre-detour \""...KEY_UPDATETONGUETARGET..."\"");
		if (!g_hDetour.Disable(Hook_Post, DTR_OnUpdateTongueTarget_Post))
			SetFailState("Failed to remove post-detour \""...KEY_UPDATETONGUETARGET..."\"");
		enabled = false;
	}
}

bool g_bUpdateTongueTarget = false;
MRESReturn DTR_OnUpdateTongueTarget(int pThis)
{
	g_bUpdateTongueTarget = true;
	return MRES_Ignored;
}

MRESReturn DTR_OnUpdateTongueTarget_Post(int pThis)
{
	g_bUpdateTongueTarget = false;
	return MRES_Ignored;
}

public Action CH_PassFilter(int touch, int pass, bool &result)
{
	if (!touch || touch > MaxClients || !IsClientInGame(touch))
		return Plugin_Continue;
	
	if (!g_bUpdateTongueTarget)
	{
		if (pass <= MaxClients)
			return Plugin_Continue;
		
		static char cls[64];
		if (!GetEdictClassname(pass, cls, sizeof(cls)))
			return Plugin_Continue;
		
		if (strcmp(cls, "ability_tongue") != 0)
			return Plugin_Continue;
		
		if (touch == GetEntPropEnt(pass, Prop_Send, "m_owner")) // probably won't happen
			return Plugin_Continue;
			
		if (GetClientTeam(touch) == 3)
		{
			if (GetEntProp(touch, Prop_Send, "m_zombieClass") == g_iTankClass)
			{
				if (~g_iFlyFlag & FLY_TANK)
					return Plugin_Continue;
			}
			else if (~g_iFlyFlag & FLY_GENERIC)
				return Plugin_Continue;
		}
		else
		{
			if (~g_iFlyFlag & FLY_SURVIVOR)
				return Plugin_Continue;
		}
	}
	else
	{
		if (!pass || pass > MaxClients)
			return Plugin_Continue;
		
		if (!IsClientInGame(pass))
			return Plugin_Continue;
		
		if (GetClientTeam(touch) != 3)
			return Plugin_Continue;
		
		if (GetClientTeam(pass) != 3 || GetEntProp(pass, Prop_Send, "m_zombieClass") != 1)
			return Plugin_Continue;
			
		if (GetEntProp(touch, Prop_Send, "m_zombieClass") == g_iTankClass)
		{
			if (~g_iTipFlag & TIP_TANK)
				return Plugin_Continue;
		}
		else if (~g_iTipFlag & TIP_GENERIC)
			return Plugin_Continue;
	}
	
	result = false;
	return Plugin_Handled;
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

void PatchNearJump(int instruction, Address src, Address dest)
{
	StoreToAddress(src, instruction, NumberType_Int8);
	StoreToAddress(src + view_as<Address>(1), view_as<int>(dest - src) - 5, NumberType_Int32);
}