#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Despawn Out Of Sight",
	author = "Forgetest",
	description = "Allow SI to despawn when losing sight of survivors.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

int g_iTankClass;
float g_flDespawnTimer[MAXPLAYERS+1];
float g_flLOSTime;
float g_flMinRange;

public void OnPluginStart()
{
	g_iTankClass = L4D_IsEngineLeft4Dead2() ? 8 : 5;

	CreateConVarHook("l4d_despawn_los_time",
				"15.0",
				"SI could despawn after this amount of time since last LOS of survivors.\n"
			...	"NOTE: Obeys minimum range set by \"z_discard_min_range\".",
				FCVAR_CHEAT,
				true, 0.0, false, 0.0,
				CvarChg_LOSTime);

	FindConVarHook("z_discard_min_range", CvarChg_DiscardMinRange);
	
	LateLoad();
}

void LateLoad()
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && IsAliveRespawnableInfected(i))
			L4D_OnMaterializeFromGhost(i);
	}
}

void CvarChg_LOSTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flLOSTime = convar.FloatValue;
}

void CvarChg_DiscardMinRange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flMinRange = convar.FloatValue;
}

public void L4D_OnMaterializeFromGhost(int client)
{
	g_flDespawnTimer[client] = 0.0;
	SDKHook(client, SDKHook_PostThinkPost, SDK_OnPostThink_Post);
}

void SDK_OnPostThink_Post(int client)
{
	if (!IsClientInGame(client))
		return;

	if (!CheckDespawnTimer(client))
		SDKUnhook(client, SDKHook_PostThinkPost, SDK_OnPostThink_Post);
}

bool CheckDespawnTimer(int client)
{
	if (!IsAliveRespawnableInfected(client))
		return false;
	
	if (!GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
	{
		if (g_flDespawnTimer[client] == 0.0)
			g_flDespawnTimer[client] = GetGameTime() + g_flLOSTime;
	}
	else
	{
		g_flDespawnTimer[client] = 0.0;
	}

	if (g_flDespawnTimer[client] != 0.0 && GetGameTime() > g_flDespawnTimer[client])
	{
		if (CanDiscardZombie(client))
			SetEntProp(client, Prop_Send, "m_isCulling", 1);
	}

	return true;
}

bool IsAliveRespawnableInfected(int client)
{
	return GetClientTeam(client) == 3
		&& IsPlayerAlive(client)
		&& !GetEntProp(client, Prop_Send, "m_isGhost")
		&& GetEntProp(client, Prop_Send, "m_zombieClass") != g_iTankClass;
}

bool CanDiscardZombie(int client)
{
	float flMinRange;
	return GetClosestSurvivor(client, flMinRange) > 0 && flMinRange > g_flMinRange;
}

int GetClosestSurvivor(int client, float &flDistance = 0.0)
{
	float clientPos[3], otherPos[3];
	GetClientAbsOrigin(client, clientPos);

	int closestClient = -1;
	float minDist = 1000000000.0;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, otherPos);

			float dist = GetVectorDistance(clientPos, otherPos);
			if (dist < minDist)
			{
				closestClient = i;
				minDist = dist;
			}
		}
	}
	
	if (closestClient > 0)
	{
		flDistance = minDist;
	}
	
	return closestClient;
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

stock ConVar FindConVarHook(const char[] name, ConVarChanged callback)
{
	ConVar cv = FindConVar(name);
	
	if (cv)
	{
		Call_StartFunction(INVALID_HANDLE, callback);
		Call_PushCell(cv);
		Call_PushNullString();
		Call_PushNullString();
		Call_Finish();
	
		cv.AddChangeHook(callback);
	}
	
	return cv;
}
