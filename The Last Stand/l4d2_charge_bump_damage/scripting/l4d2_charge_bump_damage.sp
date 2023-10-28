#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D2] Charge Bump Damage",
	author = "Forgetest",
	description = "Damage to the carried victim when the charge impacts someone due to reaction force.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

float g_flBumpDamage;

public void OnPluginStart()
{
	CreateConVarHook("z_charge_damage_carry_victim",
			"10",
			"Damage to the carry victim when the charger bowls someone.",
			FCVAR_CHEAT,
			true, 0.0, false, 0.0,
			CvarChg_BumpDamage);

	HookEvent("charger_impact", Event_ChargerImpact);
}

void CvarChg_BumpDamage(ConVar convar, const char[] oldvalue, const char[] newValue)
{
	g_flBumpDamage = convar.FloatValue;
}

void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
	if (g_flBumpDamage == 0.0)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (!client || !IsClientInGame(client) || !victim || !IsClientInGame(victim))
		return;
	
	int carryee = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
	if (carryee == -1 || !IsClientInGame(carryee))
		return;
	
	float pos[3], vel[3];
	GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", pos); // consider it's a reaction force
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vel); 

	/**
	 *	if ( (*((_BYTE *)a1 + 333) & 0x10) != 0 )
	 * 		CBaseEntity::CalcAbsoluteVelocity(a1);
	 * 	v4 = *((float *)a1 + 157);
	 * 	v15.z = 0.0;
	 * 	v15.x = v4;
	 * 	v15.y = *((vec_t *)a1 + 158);
	 * 	VectorNormalize(&v15);
	 * 	v15.z = 0.89999998;
	 * 	VectorNormalize(&v15);
	 */
	vel[2] = 0.0;
	NormalizeVector(vel, vel);
	vel[2] = 0.9;
	NormalizeVector(vel, vel);

	// consider it's a reaction force
	NegateVector(vel);

	float force[3];
	CalculateChargerImpactForce(force, vel, g_flBumpDamage, 0.01);

	// inflictor: the survivor got bowled
	// kinda to differ from general impacts
	SDKHooks_TakeDamage(carryee, victim, client, g_flBumpDamage, DMG_CLUB, -1, force, pos, false);
}

void CalculateChargerImpactForce(float force[3], const float dir[3], float damage, float scale = 1.0)
{
	static ConVar phys_pushscale;
	if (!phys_pushscale)
		phys_pushscale = FindConVar("phys_pushscale");
	
	NormalizeVector(dir, force);
	ScaleVector(force, phys_pushscale.FloatValue * scale * damage * 300.0);
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