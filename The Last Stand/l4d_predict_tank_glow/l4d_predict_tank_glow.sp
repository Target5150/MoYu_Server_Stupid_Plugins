#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <l4d_boss_vote>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Predict Tank Glow",
	author = "Forgetest",
	description = "Predicts flow tank positions and fakes models with glow (mimic \"Dark Carnival: Remix\").",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

//=========================================================================================================

#define GAMEDATA_FILE "l4d_predict_tank_glow"
#include "tankglow/tankglow_defines.inc"

bool g_bLeft4Dead2;

CZombieManager ZombieManager;

static const char g_sTankModels[][] = {
	"models/infected/hulk.mdl",
	"models/infected/hulk_dlc3.mdl",
	"models/infected/hulk_l4d1.mdl"
};

int g_iPredictModel = INVALID_ENT_REFERENCE;
float g_vModelPos[3], g_vModelAng[3];

ConVar g_cvTeleport;

//=========================================================================================================

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_bLeft4Dead2 = false;
		case Engine_Left4Dead2: g_bLeft4Dead2 = true;
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
	LoadSDK();
	
	g_cvTeleport = CreateConVar("l4d_predict_glow_tp",
								"0",
								"Teleports tank to glow position for consistency.\n"
							...	"0 = Disable, 1 = Enable",
								FCVAR_SPONLY,
								true, 0.0, true, 1.0);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("tank_spawn", Event_TankSpawn);
}

//=========================================================================================================

/**
 * @brief Called when the boss percents are updated.
 * @remarks Triggered via boss votes, force tanks, force witches.
 * @remarks Special value: -1 indicates ignored in change, 0 disabled (no spawn).
 */
public void OnUpdateBosses(int iTankFlow, int iWitchFlow)
{
	if (IsValidEdict(g_iPredictModel))
	{
		RemoveEntity(g_iPredictModel);
		g_iPredictModel = INVALID_ENT_REFERENCE;
	}
	
	if (iTankFlow > 0)
	{
		Event_RoundStart(null, "", false);
		Timer_DelayProcess(null);
	}
}

//=========================================================================================================

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!L4D_IsVersusMode()) return;
	
	g_iPredictModel = INVALID_ENT_REFERENCE;
	if (!GameRules_GetProp("m_bInSecondHalfOfRound", 1))
	{
		g_vModelPos = NULL_VECTOR;
		g_vModelAng = NULL_VECTOR;
	}
}

public void OnMapStart()
{
	for (int i; i < sizeof(g_sTankModels); ++i)
		PrecacheModel(g_sTankModels[i]);
	
	HookEntityOutput("info_director", "OnGameplayStart", EntO_OnGameplayStart);
}

void EntO_OnGameplayStart(const char[] output, int caller, int activator, float delay)
{
	// Need to delay a bit, seems crashing otherwise.
	CreateTimer(1.0, Timer_DelayProcess, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_DelayProcess(Handle timer)
{
	if (!L4D_IsVersusMode()) return Plugin_Stop;
	
	g_iPredictModel = ProcessPredictModel(g_vModelPos, g_vModelAng);
	if (g_iPredictModel != -1)
		g_iPredictModel = EntIndexToEntRef(g_iPredictModel);
	
	return Plugin_Stop;
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!L4D_IsVersusMode()) return;
	
	if (!IsValidEdict(g_iPredictModel))
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;
	
	if (IsFakeClient(client) && IsTankOffering())
	{
		if (g_cvTeleport.BoolValue)
			TeleportEntity(client, g_vModelPos, g_vModelAng, NULL_VECTOR);
	}
	else
	{
		RemoveEntity(g_iPredictModel);
		g_iPredictModel = INVALID_ENT_REFERENCE;
	}
}

//=========================================================================================================

int ProcessPredictModel(float vPos[3], float vAng[3])
{
	if (GetVectorLength(vPos) == 0.0)
	{
		if (L4D2Direct_GetVSTankToSpawnThisRound(0))
		{
			float percent = L4D2Direct_GetVSTankFlowPercent(0);
			
			TerrorNavArea nav = GetBossSpawnAreaForFlow(percent);
			if (nav != NULL_NAV_AREA)
			{
				L4D_FindRandomSpot(view_as<int>(nav), vPos);
				
				vAng[0] = 0.0;
				vAng[1] = GetRandomFloat(0.0, 360.0);
				vAng[2] = 0.0;
			}
		}
	}
	
	if (GetVectorLength(vPos) == 0.0)
		return -1;
	
	return CreateTankGlowModel(vPos, vAng);
}

TerrorNavArea GetBossSpawnAreaForFlow(float flow)
{
	float vPos[3];
	TheEscapeRoute().GetPositionOnPath(flow, vPos);
	
	TerrorNavArea nav = TerrorNavArea(vPos);
	
	ArrayList aList = new ArrayList();
	while( !nav.IsValidForWanderingPopulation()
		|| (nav.GetCenter(vPos), vPos[2] += 10.0, !ZombieManager.IsSpaceForZombieHere(vPos))
		|| nav.m_isUnderwater
		|| nav.m_activeSurvivors )
	{
		if (aList.FindValue(nav) != -1)
		{
			delete aList;
			return NULL_NAV_AREA;
		}
		
		aList.Push(nav);
		nav = nav.GetNextEscapeStep();
	}
	
	delete aList;
	return nav;
}

//=========================================================================================================

int CreateTankGlowModel(const float vPos[3], const float vAng[3])
{
	int entity = CreateEntityByName("prop_dynamic");
	if (entity == -1)
		return -1;
	
	SetEntityModel(entity, g_sTankModels[PickTankVariant()]);
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "DefaultAnim", "idle");
	DispatchSpawn(entity);
	
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	L4D2_SetEntityGlow(entity, L4D2Glow_Constant, 0, 0, {77, 102, 255}, false);
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
	
	return entity;
}

//=========================================================================================================

bool IsTankOffering()
{
	return GetEntProp(L4D_GetResourceEntity(), Prop_Send, "m_pendingTankPlayerIndex") > 0;
}

int PickTankVariant()
{
	if (!g_bLeft4Dead2 || L4D2_GetSurvivorSetMod() == 2)
		return 0;
	
	/*char sCurrentMap[64];
	GetCurrentMap(sCurrentMap, 6);
	if (strncmp(sCurrentMap, "c7m1_", 5) == 2)
		return 1;*/
	
	return 2;
}