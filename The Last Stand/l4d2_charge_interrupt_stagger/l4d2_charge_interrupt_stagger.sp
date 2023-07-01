#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D2] Charge Interrupt Stagger",
	author = "Forgetest",
	description = "Stagger the victim after being free from charge carrying.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

int g_iCarryee[MAXPLAYERS+1] = {-1, ...};
float g_flStaggerTime;
bool g_bLevelInvuln;

public void OnPluginStart()
{
	CreateConVarHook("charge_interrupt_stagger_time",
				"0.5",
				"Amount of time to stagger carry victims for.",
				FCVAR_NONE,
				true, 0.0, false, 0.0,
				CvarChg_StaggerTime);
	
	CreateConVarHook("charge_interrupt_stagger_except_level",
				"1",
				"Whether to stop applying stagger on players having levelled a charger.",
				FCVAR_NONE,
				true, 0.0, true, 1.0,
				CvarChg_LevelInvuln);
	
	HookEvent("charger_carry_end", Event_ChargerCarryEnd);
	HookEvent("charger_killed", Event_ChargerKilled);
}

void CvarChg_StaggerTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flStaggerTime = convar.FloatValue;
}

void CvarChg_LevelInvuln(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bLevelInvuln = convar.BoolValue;
}

void Event_ChargerCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_flStaggerTime == 0.0)
		return;
	
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	if (!attacker || !IsClientInGame(attacker))
		return;
	
	if (GetClientHealth(attacker) > 0)
		return;
	
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (!victim || !IsClientInGame(victim))
		return;
	
	float pos[3], ang[3];
	GetClientAbsOrigin(victim, pos);
	GetClientAbsAngles(victim, ang);
	
	// Stagger from in front victims. Makes sense since they're always going backward during charges.
	GetAngleVectors(ang, ang, NULL_VECTOR, NULL_VECTOR);
	AddVectors(pos, ang, pos);
	
	L4D_StaggerPlayer(victim, attacker, pos);
	
	// Override the stagger time
	SetEntPropFloat(victim, Prop_Send, "m_staggerTimer", g_flStaggerTime, 0);
	SetEntPropFloat(victim, Prop_Send, "m_staggerTimer", GetGameTime() + g_flStaggerTime, 1);
	
	// Remember for the level check afterwards
	g_iCarryee[victim] = attacker;
}

void Event_ChargerKilled(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker))
		return;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim))
		return;
	
	if (g_iCarryee[attacker] == -1)
		return;
	
	int carryee = g_iCarryee[attacker];
	g_iCarryee[attacker] = -1;
	
	if (carryee != victim)
		return;
	
	if (GetStaggerSourceEnt(attacker) != victim)
		return;
	
	if (GetClientTeam(attacker) != 2)
		return;
	
	// melee levels only
	if (!event.GetBool("melee") || !event.GetBool("charging"))
		return;
	
	if (!g_bLevelInvuln)
		return;
	
	L4D_CancelStagger(attacker);
}

int GetStaggerSourceEnt(int client)
{
	static int s_iOffs_m_hStaggerSource = -1;
	if (s_iOffs_m_hStaggerSource == -1)
		s_iOffs_m_hStaggerSource = FindSendPropInfo("CTerrorPlayer", "m_staggerTimer") - 16;
	
	return GetEntDataEnt2(client, s_iOffs_m_hStaggerSource);
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
