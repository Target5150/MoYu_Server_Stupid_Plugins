#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION "2.0"

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
int CTerrorGameMovement_CMoveData;
int CMoveData_m_nButtons;
int CMoveData_m_flSideMove;

methodmap CMoveData
{
	public CMoveData(Address pTerrorGameMovement) {
		return view_as<CMoveData>(LoadFromAddress(view_as<Address>(pTerrorGameMovement) + view_as<Address>(CTerrorGameMovement_CMoveData), NumberType_Int32));
	}
	
	property int m_nButtons {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(CMoveData_m_nButtons), NumberType_Int32); }
		public set(int nButtons) { StoreToAddress(view_as<Address>(this) + view_as<Address>(CMoveData_m_nButtons), nButtons, NumberType_Int32); }
	}
	
	property float m_flSideMove {
		public get() { return view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(CMoveData_m_flSideMove), NumberType_Int32)); }
		public set(float flSideMove) { StoreToAddress(view_as<Address>(this) + view_as<Address>(CMoveData_m_flSideMove), view_as<int>(flSideMove), NumberType_Int32); }
	}
}

ArrayList g_aResetAttackTimerList;

enum
{
	PATCH_CROUCH = (1 << 0),
	PATCH_SIDEMOVE = (1 << 1)
}
ConVar g_cvPatchFlag;
int g_iPatchFlag;

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (!conf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	CTerrorGameMovement_m_pPlayer = GameConfGetOffset(conf, "CTerrorGameMovement::m_pPlayer");
	if (CTerrorGameMovement_m_pPlayer == -1) SetFailState("Missing offset \"CTerrorGameMovement::m_pPlayer\"");
	
	CTerrorGameMovement_CMoveData = GameConfGetOffset(conf, "CTerrorGameMovement::CMoveData");
	if (CTerrorGameMovement_CMoveData == -1) SetFailState("Missing offset \"CTerrorGameMovement::CMoveData\"");
	
	CMoveData_m_nButtons = GameConfGetOffset(conf, "CMoveData::m_nButtons");
	if (CMoveData_m_nButtons == -1) SetFailState("Missing offset \"CMoveData::m_nButtons\"");
	
	CMoveData_m_flSideMove = GameConfGetOffset(conf, "CMoveData::m_flSideMove");
	if (CMoveData_m_flSideMove == -1) SetFailState("Missing offset \"CMoveData::m_flSideMove\"");
	
	Handle hDetour = DHookCreateFromConf(conf, "CTerrorGameMovement::PlayerMove");
	if (!hDetour) SetFailState("Missing detour setting \"CTerrorGameMovement::PlayerMove\"");
	
	if (!DHookEnableDetour(hDetour, false, OnPlayerMove_Pre))
		SetFailState("Failed to pre-detour \"CTerrorGameMovement::PlayerMove\"");
	
	delete conf;
	
	g_aResetAttackTimerList = new ArrayList(2);
	
	CreateConVar("l4d_no_m2_movement_block_version", PLUGIN_VERSION, "No M2 Movement Block Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY);
	g_cvPatchFlag = CreateConVar("l4d_no_m2_movement_block_enable", "3", "Plugin enable flags.\n1 = Crouch Patch, 2 = Side-move Patch, 3 = Both.", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 3.0);
	g_cvPatchFlag.AddChangeHook(OnConVarChanged);
	g_iPatchFlag = g_cvPatchFlag.IntValue;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iPatchFlag = g_cvPatchFlag.IntValue;
}

MRESReturn OnPlayerMove_Pre(Address pThis)
{
	if (!g_iPatchFlag) return MRES_Ignored;
	
	int client = L4D_GetSIFromAddress(CTerrorGameMovement_GetPlayer(pThis));
	if (client == -1 || !IsPlayerAlive(client))
		return MRES_Ignored;
	
	if (GetEntProp(client, Prop_Send, "m_zombieClass") == 5)
		return MRES_Ignored;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon == -1)
		return MRES_Ignored;
	
	float flM2Time = GetEntPropFloat(weapon, Prop_Send, "m_attackTimer", 1);
	if (flM2Time > GetGameTime()) // M2-ing
	{
		int userid = GetClientUserId(client);
		int index = g_aResetAttackTimerList.FindValue(userid);
		if (index == -1)
			index = g_aResetAttackTimerList.Push(userid);
		g_aResetAttackTimerList.Set(index, flM2Time, 1);
		
		// Trick the client into thinking not performing M2
		SetEntPropFloat(weapon, Prop_Send, "m_attackTimer", 0.0, 1);
		
		// Reproduce original behaviors accordingly
		CMoveData mv = CMoveData(pThis);
		if (~g_iPatchFlag & PATCH_CROUCH)
		{
			mv.m_nButtons &= 0xFFFFFFFB;
		}
		if (~g_iPatchFlag & PATCH_SIDEMOVE)
		{
			mv.m_flSideMove = 0.0;
		}
	}
	
	return MRES_Ignored;
}

// Reset players' AttackTimer on time
public void OnGameFrame()
{
	float fNow = GetGameTime();
	for (int i = 0; i < g_aResetAttackTimerList.Length; ++i)
	{
		float fSetTime = g_aResetAttackTimerList.Get(i, 1);
		if (fNow < fSetTime) continue;
		
		int client = GetClientOfUserId(g_aResetAttackTimerList.Get(i, 0));
		if (client)
		{
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (weapon != -1)
			{
				SetEntPropFloat(weapon, Prop_Send, "m_attackTimer", fSetTime, 1);
			}
		}
		
		g_aResetAttackTimerList.Erase(i--);
	}
}

public void OnClientDisconnect(int client)
{
	int userid = GetClientUserId(client);
	
	int index = g_aResetAttackTimerList.FindValue(userid, 0);
	if (index != -1)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (weapon != -1)
		{
			SetEntPropFloat(weapon, Prop_Send, "m_attackTimer", g_aResetAttackTimerList.Get(index, 1), 1);
		}
		
		g_aResetAttackTimerList.Erase(index);
	}
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
