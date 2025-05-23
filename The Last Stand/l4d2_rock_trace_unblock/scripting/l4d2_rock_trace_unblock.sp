#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>
#include <dhooks>
#include <sourcescramble>

#define PLUGIN_VERSION "1.11"

public Plugin myinfo = 
{
	name = "[L4D2] Rock Trace Unblock",
	author = "Forgetest",
	description = "Prevent hunter/jockey/coinciding survivor from blocking the rock radius check.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

enum struct SDKCallParamsWrapper {
	SDKType type;
	SDKPassMethod pass;
	int decflags;
	int encflags;
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
	public Handle CreateSDKCallOrFail(
			SDKCallType type,
			SDKFuncConfSource src,
			const char[] name,
			const SDKCallParamsWrapper[] params = {},
			int numParams = 0,
			bool hasReturnValue = false,
			const SDKCallParamsWrapper ret = {}) {
		static const char k_sSDKFuncConfSource[SDKFuncConfSource][] = { "offset", "signature", "address" };
		Handle result;
		StartPrepSDKCall(type);
		if (!PrepSDKCall_SetFromConf(this, src, name))
			SetFailState("Missing %s \"%s\"", k_sSDKFuncConfSource[src], name);
		for (int i = 0; i < numParams; ++i)
			PrepSDKCall_AddParameter(params[i].type, params[i].pass, params[i].decflags, params[i].encflags);
		if (hasReturnValue)
			PrepSDKCall_SetReturnInfo(ret.type, ret.pass, ret.decflags, ret.encflags);
		if (!(result = EndPrepSDKCall()))
			SetFailState("Failed to prep sdkcall \"%s\"", name);
		return result;
	}
}

Handle g_hSDKCall_BounceTouch;
DynamicHook g_hDHook_BounceTouch;
MemoryPatch g_hPatch_ForEachPlayer;

ConVar z_tank_rock_radius;

ConVar
	g_cvFlags,
	g_cvJockeyFix,
	g_cvHurtCapper;

int g_iFlags;

void LoadSDK()
{
	GameDataWrapper gd = new GameDataWrapper("l4d2_rock_trace_unblock");

	g_hPatch_ForEachPlayer = gd.CreatePatchOrFail("CTankRock::ProximityThink__No_ForEachPlayer", false);
	g_hDHook_BounceTouch = gd.CreateDHookOrFail("CTankRock::BounceTouch");

	SDKCallParamsWrapper params[] = {
		{SDKType_CBaseEntity, SDKPass_Pointer},
	};
	g_hSDKCall_BounceTouch = gd.CreateSDKCallOrFail(SDKCall_Entity, SDKConf_Virtual, "CTankRock::BounceTouch", params, 1);
	
	delete gd;
}

public void OnPluginStart()
{
	LoadSDK();
	
	g_cvFlags = CreateConVar(
					"l4d2_rock_trace_unblock_flag",
					"5",
					"Prevent SI from blocking the rock radius check.\n"\
				...	"1 = Unblock from all standing SI, 2 = Unblock from pounced, 4 = Unblock from jockeyed, 8 = Unblock from pummelled, 16 = Unblock from thrower (Tank), 31 = All, 0 = Disable.",
					FCVAR_CHEAT,
					true, 0.0, true, 31.0);
	
	g_cvJockeyFix = CreateConVar(
					"l4d2_rock_jockey_dismount",
					"1",
					"Force jockey to dismount the survivor who eats rock.\n"\
				...	"1 = Enable, 0 = Disable.",
					FCVAR_CHEAT,
					true, 0.0, true, 1.0);
	
	g_cvHurtCapper = CreateConVar(
					"l4d2_rock_hurt_capper",
					"5",
					"Hurt cappers before landing their victims.\n"\
				...	"1 = Hurt hunter, 2 = Hurt jockey, 4 = Hurt charger, 7 = All, 0 = Disable.",
					FCVAR_CHEAT,
					true, 0.0, true, 7.0);
	
	z_tank_rock_radius = FindConVar("z_tank_rock_radius");
	g_cvFlags.AddChangeHook(OnConVarChanged);
}

public void OnConfigsExecuted()
{
	GetCvars();
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iFlags = g_cvFlags.IntValue;
	ApplyPatch(g_iFlags > 0);
}

float GetTankRockProximityRadius()
{
	float result = z_tank_rock_radius.FloatValue;
	if (L4D2_HasConfigurableDifficultySetting())
	{
		static ConVar z_difficulty = null;
		if (z_difficulty == null)
			z_difficulty = FindConVar("z_difficulty");
		
		char buffer[16];
		z_difficulty.GetString(buffer, sizeof(buffer));
		if (strcmp(buffer, "Easy", false) == 0)
			result *= 0.75;
	}
	return result;
}

void ApplyPatch(bool patch)
{
	if (patch)
		g_hPatch_ForEachPlayer.Enable();
	else
		g_hPatch_ForEachPlayer.Disable();
}

public void L4D_TankRock_OnRelease_Post(int tank, int rock, const float vecPos[3], const float vecAng[3], const float vecVel[3], const float vecRot[3])
{
	if (g_iFlags)
		SDKHook(rock, SDKHook_Think, SDK_OnThink);
	
	if (g_cvJockeyFix.BoolValue)
		g_hDHook_BounceTouch.HookEntity(Hook_Post, rock, DHook_OnBounceTouch_Post);
}

int g_iFilterRock = -1;
int g_iFilterTank = -1;
Action SDK_OnThink(int entity)
{
	static float vOrigin[3], vLastOrigin[3], vPos[3], vClosestPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vOrigin);
	
	static int m_vLastPosition = -1;
	if (m_vLastPosition == -1)
		m_vLastPosition = FindSendPropInfo("CBaseCSGrenadeProjectile", "m_vInitialVelocity") + 24;
	
	GetEntDataVector(entity, m_vLastPosition, vLastOrigin);
	
	float flMinDistSqr = GetTankRockProximityRadius() * GetTankRockProximityRadius();
	int iClosestSurvivor = -1;
	
	g_iFilterRock = entity; // always self-ignored
	g_iFilterTank = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
			continue;
		
		if (L4D_IsPlayerIncapacitated(i) || L4D_IsPlayerHangingFromLedge(i))
			continue;
		
		L4D_GetEntityWorldSpaceCenter(i, vPos);
		ComputeClosestPoint(vLastOrigin, vOrigin, vPos, vOrigin);
		
		float flDistSqr = GetVectorDistance(vOrigin, vPos, true);
		if (flDistSqr < flMinDistSqr)
		{
			// See if there's any obstracle in the way
			TR_TraceRayFilter(vOrigin, vPos, MASK_SOLID, RayType_EndPoint, ProximityThink_TraceFilter, i);
			
			if (!TR_DidHit() && TR_GetFraction() >= 1.0)
			{
				flMinDistSqr = flDistSqr;
				iClosestSurvivor = i;
				vClosestPos = vOrigin;
			}
			
			// Keep in mind that rock finds multiple targets basically only around the moment the Tank releases it.
			// Exit the loop if we are really gonna search for nothing.
			if (iClosestSurvivor != -1)
			{
				IntervalTimer it = CTankRock__GetReleaseTimer(entity);
				if (ITimer_GetElapsedTime(it) >= 0.1)
				{
					break;
				}
			}
		}
	}
	
	if (iClosestSurvivor != -1)
	{
		// Maybe "TeleportEntity" does the same, let it be.
		SetAbsOrigin(entity, vClosestPos);
		
		// Hurt attackers first, based on flag setting
		HurtCappers(entity, iClosestSurvivor);
		
		// Confirm landing
		BounceTouch(entity, iClosestSurvivor);
	}
	
	return Plugin_Continue;
}

/**
 * @brief Valve's built-in function to compute close point to potential rock victims.
 *
 * @param vLeft			Last recorded position of moving object.
 * @param vRight		Current position of moving object.
 * @param vPos			Target position to test.
 * @param result		Vector to store the result.
 * 
 * @return				True if the closest point, false otherwise.
 */
bool ComputeClosestPoint(const float vLeft[3], const float vRight[3], const float vPos[3], float result[3])
{
	static float vLTarget[3], vLine[3];
	SubtractVectors(vPos, vLeft, vLTarget);
	SubtractVectors(vRight, vLeft, vLine);
	
	static float fLength, fDot;
	fLength = NormalizeVector(vLine, vLine);
	fDot = GetVectorDotProduct(vLTarget, vLine);
	
	/**
	 *       * (T)
	 *      /|
	 *     / |
	 *    L==P====R
	 *
	 *  L, R -> Line
	 *  T -> Target
	 *  P -> result point
	 */
	
	if (fDot >= 0.0) // (-pi/2 < θ < pi/2)
	{
		if (fDot <= fLength) // We can find a P on the line
		{
			ScaleVector(vLine, fDot);
			AddVectors(vLeft, vLine, result);
			return true;
		}
		else // Too far from T
		{
			result = vRight;
			return false;
		}
	}
	else // seems to potentially risk a hit, for tiny performance?
	{
		result = vLeft;
		return false;
	}
}

bool ProximityThink_TraceFilter(int entity, int contentsMask, int target)
{
	if (entity == g_iFilterRock
	 || entity == g_iFilterTank
	 || entity == target)
		return false;
	
	if (entity > 0 && entity <= MaxClients && IsClientInGame(entity))
	{
		if (GetClientTeam(entity) == 2)
		{
			/**
			 * NOTE:
			 *
			 * This should not be possible as radius check runs every think
			 * and survivors in between must be prior to be targeted.
			 *
			 * As far as I know, the only exception is that multiple survivors
			 * are coinciding (like at a corner), and obstracle tracing ends up
			 * with "true", kinda false positive.
			 *
			 * Treated as a bug here, no options.
			 */
			return false;
		}
		
		switch (GetEntProp(entity, Prop_Send, "m_zombieClass"))
		{
			case 3:
			{
				if (GetEntPropEnt(entity, Prop_Send, "m_pounceVictim") != -1)
				{
					return !(g_iFlags & 2);
				}
			}
			case 5:
			{
				if (GetEntPropEnt(entity, Prop_Send, "m_jockeyVictim") != -1)
				{
					return !(g_iFlags & 4);
				}
			}
			case 6:
			{
				if (GetEntPropEnt(entity, Prop_Send, "m_pummelVictim") != -1)
				{
					return !(g_iFlags & 8);
				}
			}
		}
		
		if (g_iFlags & 1)
		{
			return false;
		}
	}
	
	return true;
}

MRESReturn DHook_OnBounceTouch_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	int client = -1;
	if (!hParams.IsNull(1))
		client = hParams.Get(1);
	
	if (client > 0 && client <= MaxClients
	 && GetClientTeam(client) == 2
	 && !L4D_IsPlayerIncapacitated(client))
	{
		int jockey = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
		if (jockey != -1)
		{
			Dismount(jockey);
		}
	}
	
	return MRES_Ignored;
}

void HurtCappers(int rock, int client)
{
	int flag = g_cvHurtCapper.IntValue;
	
	if (flag & 1) // hunter
	{
		int hunter = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
		if (hunter != -1)
		{
			BounceTouch(rock, hunter);
			return;
		}
	}
	
	if (flag & 2) // jockey
	{
		int jockey = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
		if (jockey != -1)
		{
			BounceTouch(rock, jockey);
			return;
		}
	}
	
	if (flag & 4) // charger
	{
		int charger = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
		if (charger != -1)
		{
			BounceTouch(rock, charger);
			return;
		}
	}
}

void BounceTouch(int rock, int client)
{
	SDKCall(g_hSDKCall_BounceTouch, rock, client);
}

void Dismount(int client)
{
	int flags = GetCommandFlags("dismount");
	SetCommandFlags("dismount", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "dismount");
	SetCommandFlags("dismount", flags);
}

IntervalTimer CTankRock__GetReleaseTimer(int rock)
{
	static int s_iOffs_m_releaseTimer = -1;
	if (s_iOffs_m_releaseTimer == -1)
		s_iOffs_m_releaseTimer = FindSendPropInfo("CBaseCSGrenadeProjectile", "m_vInitialVelocity") + 36;
	
	return view_as<IntervalTimer>(GetEntityAddress(rock) + view_as<Address>(s_iOffs_m_releaseTimer));
}