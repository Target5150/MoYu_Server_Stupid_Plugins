#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_engine>
#include <left4dhooks>
#include <dhooks>

#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "1.7"

public Plugin myinfo = 
{
	name = "[L4D & 2] Fix DeathFall Camera",
	author = "Forgetest",
	description = "Prevent \"point_deathfall_camera\" and \"point_viewcontrol*\" permanently locking view.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

ArrayList g_aDeathFallClients;
bool g_bCustomDetour = false;

#include "l4d_fix_deathfall_cam/natives.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	Natives_Init();
	return APLRes_Success;
}

public void OnPluginStart()
{
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		GameDataWrapper gd = new GameDataWrapper("l4d_fix_deathfall_cam");
		if (gd.GetOffset("OS") == 1)
		{
			delete gd.CreateDetourOrFail("CDeathFallCamera::InputEnable", DTR_CDeathFallCamera_InputEnable);
			g_bCustomDetour = true;
		}
		delete gd;
	}

	g_aDeathFallClients = new ArrayList();

	CreateConVar("l4d2_fix_deathfall_cam_version", PLUGIN_VERSION, "Fix Deathfall Camera Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("gameinstructor_nodraw", Event_NoDraw);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (FindEntityByClassname(MaxClients+1, "point_viewcontrol*") != INVALID_ENT_REFERENCE
		|| FindEntityByClassname(MaxClients+1, "point_deathfall_camera") != INVALID_ENT_REFERENCE)
	{
		UTIL_ReleaseAllExceptSurv();
	}
	
	g_aDeathFallClients.Clear();
}

// Fix intro cameras locking view on L4D1
void Event_NoDraw(Event event, const char[] name, bool dontBroadcast)
{
	UTIL_ReleaseAllExceptSurv();
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	Timer_ReleaseView(null, event.GetInt("userid"));
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	// the player's view locks for approximately 6.0s after died
	CreateTimer(6.0, Timer_ReleaseView, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ReleaseView(Handle timer, any userid)
{
	int index = g_aDeathFallClients.FindValue(userid);
	if (index == -1)
		return Plugin_Stop;
	
	g_aDeathFallClients.Erase(index);

	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	ReleaseFromViewControl(client);
	
	return Plugin_Stop;
}

// TODO: Maybe replace with some inputhook API
MRESReturn DTR_CDeathFallCamera_InputEnable(int entity, DHookParam hParams)
{
	int activator = hParams.GetObjectVar(1, 0, ObjectValueType_CBaseEntityPtr);
	if (activator <= 0 || activator > MaxClients || !IsClientInGame(activator))
		return MRES_Ignored;

	return CheckBlockDeathfallCamera(activator) ? MRES_Supercede : MRES_Ignored;
}

public Action L4D_OnFatalFalling(int client, int camera)
{
	if (g_bCustomDetour || client <= 0)
		return Plugin_Continue;
	
	return CheckBlockDeathfallCamera(client) ? Plugin_Handled : Plugin_Continue;
}

bool CheckBlockDeathfallCamera(int client)
{
	if (AllowDamage())
	{
		if (GetClientTeam(client) == 2 && !IsFakeClient(client) && IsPlayerAlive(client))
		{
			// keep deathcam for a period until the player dies
			int userid = GetClientUserId(client);
			if (g_aDeathFallClients.FindValue(userid) == -1)
				g_aDeathFallClients.Push(userid);
			
			return false;
		}
	}
	
	return true;
}

void SetViewEntity(int client, int view)
{
	SetEntPropEnt(client, Prop_Send, "m_hViewEntity", view);
	SetClientViewEntity(client, IsValidEdict(view) ? view : client);
}

// Hud Element hiding flags
#define HIDEHUD_WEAPONSELECTION     (1 << 0)	// Hide ammo count & weapon selection
#define HIDEHUD_FLASHLIGHT          (1 << 1)
#define HIDEHUD_ALL                 (1 << 2)
#define HIDEHUD_HEALTH              (1 << 3)	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD          (1 << 4)	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT            (1 << 5)	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS          (1 << 6)	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT                (1 << 7)	// Hide all communication elements (saytext, voice icon, etc)
#define HIDEHUD_CROSSHAIR           (1 << 8)	// Hide crosshairs
#define HIDEHUD_VEHICLE_CROSSHAIR   (1 << 9)	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE           (1 << 10)
#define HIDEHUD_BONUS_PROGRESS      (1 << 11)	// Hide bonus progress display (for bonus map challenges)
stock void ReleaseFromViewControl(int client)
{
	SetEntityFlags(client, GetEntityFlags(client) & ~FL_FROZEN);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1, 1);
	SetViewEntity(client, -1);
	
	if (GetClientTeam(client) == 1)
		SetEntProp(client, Prop_Send, "m_iHideHUD", HIDEHUD_BONUS_PROGRESS | HIDEHUD_HEALTH);
	else
		SetEntProp(client, Prop_Send, "m_iHideHUD", HIDEHUD_BONUS_PROGRESS);
			
	SetEntPropEnt(client, Prop_Send, "m_hZoomOwner", -1);
	
	// Fix for custom FOV setting
	SetEntProp(client, Prop_Send, "m_iFOV", 0);
	SetEntProp(client, Prop_Send, "m_iFOVStart", 0);
	SetEntPropFloat(client, Prop_Send, "m_flFOVRate", 0.0);
}

void UTIL_ReleaseAllExceptSurv()
{
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 2)
			ReleaseFromViewControl(i);
}

bool AllowDamage()
{
	static ConVar god = null;
	if (god == null)
		god = FindConVar("god");
	
	if (god.BoolValue)
		return false;
	
	return true;
}