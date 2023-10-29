#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Tongue Fatigue Control",
	author = "Forgetest",
	description = "Customize the fatigue from tongue release.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

float g_flMinTime, g_flMaxTime;
float g_flDefaultFatigue;

public void OnPluginStart()
{
	CreateConVarHook("tongue_release_fatigue_scale_min_time",
				"0.2",
				"Before this time of being pulled the victim gets no fatigue penalty.",
				FCVAR_CHEAT,
				true, 0.0, false, 0.0,
				CvarChg_MinTime);
	
	CreateConVarHook("tongue_release_fatigue_scale_max_time",
				"1.0",
				"After this time of being pulled the victim gets full fatigue penalty.",
				FCVAR_CHEAT,
				true, 0.0, false, 0.0,
				CvarChg_MaxTime);
	
	FindConVarHook("tongue_release_fatigue_penalty", CvarChg_DefaultFatigue);

	HookEvent("tongue_pull_stopped", Event_TonguePullStopped);
}

void CvarChg_MinTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flMinTime = convar.FloatValue;
}

void CvarChg_MaxTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flMaxTime = convar.FloatValue;
}

void CvarChg_DefaultFatigue(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flDefaultFatigue = convar.FloatValue;
}

void Event_TonguePullStopped(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	int smoker = GetClientOfUserId(event.GetInt("smoker"));
	if (!victim || !IsClientInGame(victim) || !smoker || !IsClientInGame(smoker))
		return;

	int ability = GetEntPropEnt(smoker, Prop_Send, "m_customAbility");

	float flPullTime = GetGameTime() - GetEntPropFloat(ability, Prop_Send, "m_tongueHitTimestamp");
	if (flPullTime < 0.0)
		return;
	
	float flScale;
	if (flPullTime <= g_flMinTime)
	{
		flScale = 0.0;
	}
	else
	{
		float flRange = Math_Max(0.00001, g_flMaxTime - g_flMinTime);
		flScale = Math_Min(1.0, flPullTime / flRange);
	}

	float flStamina = GetEntPropFloat(victim, Prop_Send, "m_flStamina");
	flStamina -= g_flDefaultFatigue * (1.0 - flScale);
	SetEntPropFloat(victim, Prop_Send, "m_flStamina", flStamina);
}

stock any Math_Min(any a, any b)
{
	return a < b ? a : b;
}

stock any Math_Max(any a, any b)
{
	return a > b ? a : b;
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