#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Temp HP Prior",
	author = "Forgetest",
	description = "Damage dealt to temporary health prior to permanent health.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

methodmap Math 
{
	public static float fMax(float a, float b) { return a > b ? a : b; }
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_temphp_prior");
	delete gd.CreateDetourOrFail("l4d_temphp_prior::CBaseCombatCharacter::OnTakeDamage_Alive", DTR_CBaseCombatCharacter_OnTakeDamage_Alive, DTR_CBaseCombatCharacter_OnTakeDamage_Alive_Post);
	delete gd;
}

static int g_iLastHealth;
MRESReturn DTR_CBaseCombatCharacter_OnTakeDamage_Alive(int entity, DHookReturn hReturn, DHookParam hParams)
{
	g_iLastHealth = -1;

	if (entity <= 0 || entity > MaxClients || !IsClientInGame(entity))
		return MRES_Ignored;

	g_iLastHealth = GetClientHealth(entity);
	return MRES_Ignored;
}

MRESReturn DTR_CBaseCombatCharacter_OnTakeDamage_Alive_Post(int entity, DHookReturn hReturn, DHookParam hParams)
{
	if (hReturn.Value != true)	// damage prevented
		return MRES_Ignored;
	
	if (g_iLastHealth <= 1)		// not a player, or just let the game decide
		return MRES_Ignored;
	
	if (GetEntProp(entity, Prop_Send, "m_isIncapacitated"))	// include hanging
		return MRES_Ignored;
	
	int perm = GetEntProp(entity, Prop_Data, "m_iHealth");
	float temp = L4D_GetPlayerTempHealthFloat(entity);
	int lost = g_iLastHealth - perm;

	// subtract the damage from temp health first, then recover perm health by the decreased amount
	float newtemp = Math.fMax(0.0, temp - lost);
	int newperm = perm + RoundToFloor(temp - newtemp);

	SetEntProp(entity, Prop_Data, "m_iHealth", newperm);
	SetEntPropFloat(entity, Prop_Send, "m_healthBuffer", newtemp);
	SetEntPropFloat(entity, Prop_Send, "m_healthBufferTime", GetGameTime());

	return MRES_Ignored;
}

stock float L4D_GetPlayerTempHealthFloat(int client)
{
	static ConVar painPillsDecayCvar;
	if (painPillsDecayCvar == null)
	{
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
		if (painPillsDecayCvar == null)
		{
			return -1.0;
		}
	}

	float fGameTime = GetGameTime();
	float fHealthTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (fGameTime - fHealthTime) * painPillsDecayCvar.FloatValue;
	return fHealth < 0.0 ? 0.0 : fHealth;
}
