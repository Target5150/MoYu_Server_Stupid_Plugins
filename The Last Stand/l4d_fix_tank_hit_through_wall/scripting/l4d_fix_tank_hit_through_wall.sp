#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <left4dhooks>
#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Fix Tank Hit Through Wall",
	author = "Forgetest",
	description = "Extra collision tests to prevent tank fist's hit from registering through thin walls.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

static const int g_size_m_hHitEntities = 128;
static int g_offs_m_hHitEntities = -1;
static int g_offs_m_iHitEntities = -1;

ArrayList g_UndoList;

public void OnPluginStart()
{
	g_offs_m_hHitEntities = FindSendPropInfo("CTerrorWeapon", "m_swingTimer");
	if (g_offs_m_hHitEntities != -1)
	{
		g_offs_m_hHitEntities += 32;
		g_offs_m_iHitEntities = g_offs_m_hHitEntities + 4 * g_size_m_hHitEntities;
	}

	GameDataWrapper gd = new GameDataWrapper("l4d_fix_tank_hit_through_wall");
	delete gd.CreateDetourOrFail("CTankClaw::OnHit", DTR_CTankClaw_OnHit);
	delete gd.CreateDetourOrFail("CTankClaw::SweepFist", _, DTR_CTankClaw_SweepFist_Post);
	delete gd;

	g_UndoList = new ArrayList();
}

bool UTIL_IsTankHittable(int entity)
{
	return IsEntityClassname(entity, "prop_physics*") || IsEntityClassname(entity, "prop_car_alarm");
}

// CTankClaw::OnHit(CGameTrace &,Vector const&,bool)
MRESReturn DTR_CTankClaw_OnHit(int weapon, DHookReturn hReturn, DHookParam hParams)
{
	int hitent = hParams.GetObjectVar(1, 76, ObjectValueType_CBaseEntityPtr);
	if (hitent <= 0)
		return MRES_Ignored;
	
	if (hitent > MaxClients && !UTIL_IsTankHittable(hitent))
	{
		int parent = GetEntPropEnt(hitent, Prop_Data, "m_pParent");
		if (parent == -1 || !UTIL_IsTankHittable(hitent))
		{
			return MRES_Ignored;
		}

		if (parent != -1)
		{
			hitent = parent;
		}
	}
	
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
	if (client == -1 || !IsClientInGame(client))
		return MRES_Ignored;

	float eyepos[3], centerpos[3], endpos[3];
	GetClientEyePosition(client, eyepos);
	L4D_GetEntityWorldSpaceCenter(client, centerpos);
	hParams.GetObjectVarVector(1, 12, ObjectValueType_Vector, endpos);

	float mins[3], maxs[3];
	mins[0] = mins[1] = mins[2] = -8.0;
	maxs[0] = maxs[1] = maxs[2] = 8.0;

	if (!IsLineToPunchTargetClear(eyepos, endpos, mins, maxs, MASK_SHOT_HULL, hitent, weapon) && !IsLineToPunchTargetClear(centerpos, endpos, mins, maxs, MASK_SHOT_HULL, hitent, weapon))
	{
		if (hParams.Get(3))
		{
			// The hit entity will later be pushed to the array at "size" position
			int size = GetEntData(weapon, g_offs_m_iHitEntities, 4);
			g_UndoList.Push(size);
		}

		hReturn.Value = false;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

enum struct TraceFilterPunchTargetData
{
	int target;
	int ignore;
}
TraceFilterPunchTargetData g_iTraceFilterData;

bool IsLineToPunchTargetClear(const float start[3], const float end[3], const float mins[3], const float maxs[3], int mask, int target, int ignore = -1)
{
	g_iTraceFilterData.target = target;
	g_iTraceFilterData.ignore = ignore;
	Handle tr = TR_TraceHullFilterEx(start, end, mins, maxs, mask, TraceFilter_PunchTarget);
	bool result = !TR_DidHit(tr);
	delete tr;
	return result;
}

bool TraceFilter_PunchTarget(int entity, int contentsMask)
{
	if (g_iTraceFilterData.target != -1)
	{
		if (entity == g_iTraceFilterData.target || GetEntPropEnt(entity, Prop_Data, "m_pParent") == g_iTraceFilterData.target)
			return false;
	}

	if (g_iTraceFilterData.ignore != -1)
	{
		if (entity == g_iTraceFilterData.ignore || entity == GetEntPropEnt(g_iTraceFilterData.ignore, Prop_Data, "m_hOwnerEntity"))
			return false;
	}

	return entity == 0 || entity > MaxClients;
}

MRESReturn DTR_CTankClaw_SweepFist_Post(int weapon, DHookParam hParams)
{
	UndoWeaponHitList(weapon, g_UndoList);

	if (g_UndoList.Length)
	{
		LogError("Failed to undo hit entities (num %d)", g_UndoList.Length);		
		g_UndoList.Clear();
	}

	return MRES_Ignored;
}

void UndoWeaponHitList(int weapon, ArrayList list)
{
	for (int i = list.Length-1; i >= 0; --i)
	{
		if (UnmarkWeaponHitEntity(weapon, list.Get(i)))
			list.Erase(i);
	}
}

bool UnmarkWeaponHitEntity(int weapon, int index)
{
	int size = GetEntData(weapon, g_offs_m_iHitEntities, 4);
	if (index == size-1)
	{
		SetEntData(weapon, g_offs_m_iHitEntities, size-1, 4);
		return true;
	}
	else if (index > 0 && index < g_size_m_hHitEntities)
	{
		int p = GetEntData(weapon, g_offs_m_hHitEntities + 4 * size-1, 4);
		SetEntData(weapon, g_offs_m_hHitEntities + 4 * index, p, 4);
		SetEntData(weapon, g_offs_m_iHitEntities, size-1, 4);
		return true;
	}
	return false;
}

bool IsEntityClassname(int entity, const char[] classname)
{
	int len = strlen(classname);
	if (len == 0)
		return false;

	char buffer[64];
	GetEntityClassname(entity, buffer, sizeof(buffer));
	return classname[len-1] == '*' ? !strncmp(buffer, classname, len-1) : !strcmp(buffer, classname);
}
