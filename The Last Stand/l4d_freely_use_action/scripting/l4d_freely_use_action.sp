#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <sourcescramble>
#include <left4dhooks>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = 
{
	name = "[L4D & 2] Freely Use Action",
	author = "Forgetest",
	description = "Free movement when using items.",
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
	public DynamicHook CreateDHookOrFail(const char[] name) {
		DynamicHook hSetup = DynamicHook.FromConf(this, name);
		if (!hSetup)
			SetFailState("Missing dhook setup \"%s\"", name);
		return hSetup;
	}
}

enum UseAction
{
	UseAction_None				= 0,	// No use action active
	UseAction_Healing			= 1,	// Includes healing yourself or a teammate.
	UseAction_AmmoPack			= 2,	// When deploying the ammo pack that was never added into the game
	UseAction_Defibing			= 4,	// When defib'ing a dead body.
	UseAction_GettingDefibed	= 5,	// When comming back to life from a dead body.
	UseAction_DeployIncendiary	= 6,	// When deploying Incendiary ammo
	UseAction_DeployExplosive	= 7,	// When deploying Explosive ammo
	UseAction_PouringGas		= 8,	// Pouring gas into a generator
	UseAction_Cola				= 9,	// For Dead Center map 2 cola event, when handing over the cola to whitalker.
	UseAction_Button			= 10,	// Such as buttons, timed buttons, generators, etc.
	UseAction_UsePointScript	= 11,	// When using a "point_script_use_target" entity
	/* List is not fully done, these are just the ones I have found so far */

	MAX_USE_ACTION
};

static const int UseActionToFlag[MAX_USE_ACTION] = {
	0,
	1 << 0,
	0,
	0,
	1 << 1,
	0,
	1 << 2,
	1 << 3,
	1 << 4,
	1 << 5,
	1 << 6,
	1 << 7
};

int g_fType;
float g_flSpeedFactor;

int g_iOffs_m_iCurrentUseAction = -1;
bool g_bLeft4Dead2;

DynamicHook g_Hook_IsMoving;

public void OnPluginStart()
{
	g_iOffs_m_iCurrentUseAction = FindSendPropInfo("CTerrorPlayer", "m_iCurrentUseAction");

	GameDataWrapper gd = new GameDataWrapper("l4d_freely_use_action");

	g_bLeft4Dead2 = GetEngineVersion() == Engine_Left4Dead2;
	if (!g_bLeft4Dead2)
	{
		gd.CreatePatchOrFail("skip_IsMoving", true);
		gd.CreatePatchOrFail("set_mobilized", true);
	}
	else
	{
		g_Hook_IsMoving = gd.CreateDHookOrFail("CBaseEntity::IsMoving");
		delete gd.CreateDetourOrFail("CTerrorPlayer::IsImmobilized", DTR__IsImmobilized, DTR__IsImmobilized_Post);

		CreateConVarHook("l4d_freely_use_action_type",
						"255",
						"Allowed type of use action with freely movement."
					...	"0 = None, 1 = Heal, 2 = Defib, 4 = Deploy incendiary, 8 = Deploy explosive, 16 = Pour gas, 32 = Hand cola, 64 = Press button, 128 = point_script_use_target, 255 = All",
						FCVAR_NONE,
						true, 0.0, false, 0.0,
						CvarChg_Type);
	}

	CreateConVarHook("l4d_freely_use_action_speed_factor",
					"0.5",
					"Speed factor during use action with freely movement."
				...	"1.0 = Default",
					FCVAR_NONE,
					true, 0.0, false, 0.0,
					CvarChg_Speed);

	delete gd;
}

void CvarChg_Type(ConVar convar, const char[] oldValue, const char[] newVAlue)
{
	g_fType = convar.IntValue;
}

void CvarChg_Speed(ConVar convar, const char[] oldValue, const char[] newVAlue)
{
	g_flSpeedFactor = convar.FloatValue;
}

public void OnMapStart()
{
	for	(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)) OnClientPutInServer(i);
	}
}

public void OnClientPutInServer(int client)
{
	if (g_Hook_IsMoving)
		g_Hook_IsMoving.HookEntity(Hook_Pre, client, DTR__IsMoving);
}

public Action L4D_OnGetRunTopSpeed(int target, float &retVal)
{
	if (GetEntProp(target, Prop_Data, "m_nWaterLevel"))
	{
		return Plugin_Continue;
	}

	UseAction action = view_as<UseAction>(GetEntData(target, g_iOffs_m_iCurrentUseAction));

	if (IsAllowedUseType(action))
	{
		retVal *= g_flSpeedFactor;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

MRESReturn DTR__IsMoving(int client, DHookReturn hReturn)
{
	UseAction action = view_as<UseAction>(GetEntData(client, g_iOffs_m_iCurrentUseAction));

	if (IsAllowedUseType(action))
	{
		hReturn.Value = 0;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

UseAction g_iSave = UseAction_None;
MRESReturn DTR__IsImmobilized(int client, DHookReturn hReturn)
{
	UseAction action = view_as<UseAction>(GetEntData(client, g_iOffs_m_iCurrentUseAction));

	if (IsAllowedUseType(action))
	{
		g_iSave = action;
		SetEntData(client, g_iOffs_m_iCurrentUseAction, 0);
	}

	return MRES_Ignored;
}

MRESReturn DTR__IsImmobilized_Post(int client, DHookReturn hReturn)
{
	if (g_iSave != UseAction_None)
	{
		SetEntData(client, g_iOffs_m_iCurrentUseAction, g_iSave);
		g_iSave = UseAction_None;
	}
	return MRES_Ignored;
}

bool IsAllowedUseType(UseAction action)
{
	if (action >= UseAction_None && action < MAX_USE_ACTION)
	{
		return (g_fType & UseActionToFlag[action]) != 0;
	}
	return false;
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
