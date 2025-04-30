#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION "2.1"

public Plugin myinfo =
{
	name = "[L4D] No M2 Movement Block",
	author = "Forgetest",
	description = "Enable free movement on SI when M2-ing.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d_no_m2_movement_block"

int CTerrorGameMovement_m_pPlayer;

float g_flNextM2Time[MAXPLAYERS+1];

ConVar g_cvAllow;

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (!conf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	CTerrorGameMovement_m_pPlayer = GameConfGetOffset(conf, "CTerrorGameMovement::m_pPlayer");
	if (CTerrorGameMovement_m_pPlayer == -1) SetFailState("Missing offset \"CTerrorGameMovement::m_pPlayer\"");
	
	Handle hDetour = DHookCreateFromConf(conf, "CTerrorGameMovement::PlayerMove");
	if (!hDetour) SetFailState("Missing detour setting \"CTerrorGameMovement::PlayerMove\"");
	
	if (!DHookEnableDetour(hDetour, false, OnPlayerMove_Pre))
		SetFailState("Failed to pre-detour \"CTerrorGameMovement::PlayerMove\"");
	
	if (!DHookEnableDetour(hDetour, true, OnPlayerMove_Post))
		SetFailState("Failed to post-detour \"CTerrorGameMovement::PlayerMove\"");
		
	hDetour = DHookCreateFromConf(conf, "CTerrorWeapon::IsAttacking");
	if (!hDetour) SetFailState("Missing detour setting \"CTerrorWeapon::IsAttacking\"");
	
	if (!DHookEnableDetour(hDetour, false, OnIsAttacking_Pre))
		SetFailState("Failed to pre-detour \"CTerrorWeapon::IsAttacking\"");
	
	delete conf;
	
	CreateConVar("l4d_no_m2_movement_block_version", PLUGIN_VERSION, "No M2 Movement Block Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY);
	g_cvAllow = CreateConVar("l4d_no_m2_movement_block_enable", "1", "Plugin enable or not.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

bool bInsideCall[MAXPLAYERS+1] = {false, ...};
MRESReturn OnPlayerMove_Pre(Address pThis)
{
	if (!g_cvAllow.BoolValue) return MRES_Ignored;
	
	int client = L4D_GetSIFromAddress(CTerrorGameMovement_GetPlayer(pThis));
	if (client == -1)
		return MRES_Ignored;
	
	if (!IsPlayerAlive(client)
		|| GetEntProp(client, Prop_Send, "m_zombieClass") == 5
		|| GetEntProp(client, Prop_Send, "m_isGhost", 1))
	{
		if (g_flNextM2Time[client] != 0.0)
			g_flNextM2Time[client] = 0.0;
		
		return MRES_Ignored;
	}
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon == -1)
		return MRES_Ignored;
	
	float flM2Time = GetEntPropFloat(weapon, Prop_Send, "m_attackTimer", 1);
	if (flM2Time == -0.5) // Aimless M2 has 0.5s cooldown in return
	{
		g_flNextM2Time[client] += flM2Time;
	}
	else if (flM2Time > GetGameTime()) // M2-ing
	{
		g_flNextM2Time[client] = flM2Time;
	}
	else if (flM2Time != 0.0) // M2-ed state
	{
		return MRES_Ignored;
	}
	
	if (g_flNextM2Time[client] != 0.0)
	{
		if (GetGameTime() > g_flNextM2Time[client]) // m2 idle
		{
			// Restore value to prevent infinite loop
			SetEntPropFloat(weapon, Prop_Send, "m_attackTimer", g_flNextM2Time[client], 1);
			g_flNextM2Time[client] = 0.0;
			return MRES_Ignored;
		}
	}
	
	// Trick the client into thinking not performing M2
	SetEntPropFloat(weapon, Prop_Send, "m_attackTimer", 0.0, 1);
	
	// while we have to tell other function client is attacking
	bInsideCall[client] = true;
	
	return MRES_Ignored;
}

MRESReturn OnPlayerMove_Post(Address pThis)
{
	int client = L4D_GetSIFromAddress(CTerrorGameMovement_GetPlayer(pThis));
	if (client != -1 && bInsideCall[client])
		bInsideCall[client] = false;
	
	return MRES_Ignored;
}

MRESReturn OnIsAttacking_Pre(int weapon, Handle hReturn)
{
	if (GetEntPropFloat(weapon, Prop_Send, "m_attackTimer", 1) != 0.0)
		return MRES_Ignored;
	
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
	if (owner == -1)
		return MRES_Ignored;
	
	DHookSetReturn(hReturn, view_as<int>(!bInsideCall[owner]));
	return MRES_Supercede;
}

Address CTerrorGameMovement_GetPlayer(Address pTerrorGameMovement)
{
	return view_as<Address>(LoadFromAddress(pTerrorGameMovement + view_as<Address>(CTerrorGameMovement_m_pPlayer), NumberType_Int32));
}

// Thanks "L4D_GetClientFromAddress" from left4dhooks
int L4D_GetSIFromAddress(Address addy)
{
	if (addy != Address_Null)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
			{
				if (GetEntityAddress(i) == addy) return i;
			}
		}
	}
	return -1;
}
