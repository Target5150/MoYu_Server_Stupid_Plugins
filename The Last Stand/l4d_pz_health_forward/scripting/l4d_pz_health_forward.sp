#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define DEBUG 0
#define PLUGIN_VERSION "1.0.1"

public Plugin myinfo = 
{
	name = "[L4D & 2] Player Zombie Health Forward",
	author = "Forgetest",
	description = "Provide forwards for modifying player zombie health.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

GlobalForward g_fwd_OnInfectedSpawnHealth;
GlobalForward g_fwd_OnInfectedRespawnHealth;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// forward void L4D_OnPZSpawnHealth(int client, int zombieclass, bool zspawncmd, int &health, int &maxHealth, float &healthMult, float &maxHealthMult);
	// forward void L4D_OnPZRespawnHealth(int client, int zombieclass, int &health, int &maxHealth, float &healthMult, float &maxHealthMult);
	g_fwd_OnInfectedSpawnHealth = new GlobalForward("L4D_OnPZSpawnHealth", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_FloatByRef);
	g_fwd_OnInfectedRespawnHealth = new GlobalForward("L4D_OnPZRespawnHealth", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_FloatByRef);

	RegPluginLibrary("l4d_pz_health_forward");
	return APLRes_Success;
}

bool ApplySpawnHealthMod(int client, int class, bool zspawncmd, int &health, int &maxhealth)
{
	if (g_fwd_OnInfectedSpawnHealth.FunctionCount == 0)
		return false;

	int healthMut = health;
	int maxhealthMut = maxhealth;
	float healthMult = 1.0;
	float maxhealthMult = 1.0;

	Call_StartForward(g_fwd_OnInfectedSpawnHealth);
	Call_PushCell(client);
	Call_PushCell(class);
	Call_PushCell(zspawncmd);
	Call_PushCellRef(healthMut);
	Call_PushCellRef(maxhealthMut);
	Call_PushFloatRef(healthMult);
	Call_PushFloatRef(maxhealthMult);
	Call_Finish();

#if DEBUG
	PrintToChat(client, 
		"ApplySpawnHealthMod (%N %s) (before %d / %d) (after %d / %d) (mult %.1f / %.1f) (result %d / %d)",
		client, zspawncmd ? "command spawn" : "spawn",
		health, maxhealth,
		healthMut, maxhealthMut,
		healthMult, maxhealthMult,
		RoundToFloor(healthMut * healthMult), RoundToFloor(maxhealthMut * maxhealthMult));
#endif

	health = RoundToFloor(healthMut * healthMult);
	maxhealth = RoundToFloor(maxhealthMut * maxhealthMult);

	return true;
}

bool ApplyRespawnHealthMod(int client, int class, int &health, int &maxhealth)
{
	if (g_fwd_OnInfectedRespawnHealth.FunctionCount == 0)
		return false;

	int healthMut = health;
	int maxhealthMut = maxhealth;
	float healthMult = 1.0;
	float maxhealthMult = 1.0;

	Call_StartForward(g_fwd_OnInfectedRespawnHealth);
	Call_PushCell(client);
	Call_PushCell(class);
	Call_PushCellRef(healthMut);
	Call_PushCellRef(maxhealthMut);
	Call_PushFloatRef(healthMult);
	Call_PushFloatRef(maxhealthMult);
	Call_Finish();

#if DEBUG
	PrintToChat(client, 
		"ApplyRespawnHealthMod (%N @ %dHP) (before %d / %d) (after %d / %d) (mult %.1f / %.1f) (result %d / %d)",
		client, prevhealth,
		health, maxhealth,
		healthMut, maxhealthMut,
		healthMult, maxhealthMult,
		RoundToFloor(healthMut * healthMult), RoundToFloor(maxhealthMut * maxhealthMult));
#endif

	health = RoundToFloor(healthMut * healthMult);
	maxhealth = RoundToFloor(maxhealthMut * maxhealthMult);

	return true;
}

public void L4D_OnSetClass_Post(int client, int class)
{
	if (class <= 0 || class > 8)
		return;
	
	int health = GetEntProp(client, Prop_Send, "m_iHealth");
	int maxhealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");

	// NOTE: "z_spawn" sets abortcontrol as well, but the pre-health is -1
	int prevhealth = GetPlayerZombiePreAbortedControlHealth(client);
	bool aborted = IsPlayerZombieAbortedControl(client);
	bool isRespawn = aborted && prevhealth != -1;

	if (isRespawn ?
		ApplyRespawnHealthMod(client, class, health, maxhealth) :
		ApplySpawnHealthMod(client, class, aborted && prevhealth == -1, health, maxhealth))
	{
		SetEntProp(client, Prop_Send, "m_iHealth", health);
		SetEntProp(client, Prop_Send, "m_iMaxHealth", maxhealth);
	}
}

bool IsPlayerZombieAbortedControl(int client)
{
	static int s_iOffs_m_bPZAbortedControl = -1;
	if (s_iOffs_m_bPZAbortedControl == -1)
	{
		s_iOffs_m_bPZAbortedControl = GetEngineVersion() == Engine_Left4Dead2 ?
			FindSendPropInfo("CTerrorPlayer", "m_bSurvivorGlowEnabled") + 1 :
			FindSendPropInfo("CTerrorPlayer", "m_lookatPlayer") + 4;
	}
	
	return GetEntData(client, s_iOffs_m_bPZAbortedControl, 1) != 0;
}

int GetPlayerZombiePreAbortedControlHealth(int client)
{
	static int s_iOffs_m_iPZAbortedControlHealth = -1;
	if (s_iOffs_m_iPZAbortedControlHealth == -1)
	{
		s_iOffs_m_iPZAbortedControlHealth = GetEngineVersion() == Engine_Left4Dead2 ?
			FindSendPropInfo("CTerrorPlayer", "m_bSurvivorGlowEnabled") + 4 :
			FindSendPropInfo("CTerrorPlayer", "m_lookatPlayer") + 8;
	}
	
	return GetEntData(client, s_iOffs_m_iPZAbortedControlHealth, 4);
}