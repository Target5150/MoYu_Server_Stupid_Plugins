#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = 
{
	name = "[L4D & 2] FF Immune Crouch",
	author = "Forgetest",
	description = "Feature from B4B. Deal/Receive no friendly fire when crouching.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

bool g_bImmuneFire;
bool g_bImmuneSelf;

public void OnPluginStart()
{
	CreateConVarHook(
		"friendly_fire_immune_crouch_fire",
		"0",
		"Immune friendly-fire of burn damage when crouching.",
		FCVAR_NONE, true, 0.0, true, 1.0, CvarChg_ImmuneFire);
	CreateConVarHook(
		"friendly_fire_immune_crouch_self",
		"0",
		"Immune self friendly-fire when crouching.",
		FCVAR_NONE, true, 0.0, true, 1.0, CvarChg_ImmuneSelf);
}

void CvarChg_ImmuneFire(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bImmuneFire = convar.BoolValue;
}

void CvarChg_ImmuneSelf(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bImmuneSelf = convar.BoolValue;
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)) OnClientPutInServer(i);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
}

Action SDK_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (victim == attacker && !g_bImmuneSelf)
		return Plugin_Continue;

	if ((damagetype & DMG_BURN) && !g_bImmuneFire)
		return Plugin_Continue;

	if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker))
		return Plugin_Continue;

	if (GetClientTeam(victim) != 2 || GetClientTeam(attacker) != 2)
		return Plugin_Continue;

	if (!EntityHasFlags(victim, FL_DUCKING|FL_ONGROUND) && !EntityHasFlags(attacker, FL_DUCKING|FL_ONGROUND))
		return Plugin_Continue;

	damage = 0.0;
	return Plugin_Changed;
}

bool EntityHasFlags(int entity, int flags)
{
	return (GetEntityFlags(entity) & flags) == flags;
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
