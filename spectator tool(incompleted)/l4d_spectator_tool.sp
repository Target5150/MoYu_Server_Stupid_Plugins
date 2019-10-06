#pragma semicolon 1

#define DEBUG 0

#define MAX_DIST_SQUARED 250000 /* 500 distance */
#define TRACE_TOLERANCE 30.0

#include <sourcemod>
#include <sdktools>
#include <colors>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "L4D2 Spectator Tool",
	author = "Nana (with CanadaRox's pill_passer)",
	description = "Get players First-Pov by press key USE.",
	version = "",
	url = ""
};

/**
 *  Global
**/
static bool bSpecToolHintShown[MAXPLAYERS+1];
static float fButtonTime[MAXPLAYERS+1] = -1.0;

/**
 *  Forward
**/
public void OnPluginStart()
{
	HookEvent("player_team", Event_PlayerTeam);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	bSpecToolHintShown[client] = false;
}

public void Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	CreateTimer(0.5, Timer_CheckRealSpec, client);
}

public Action Timer_CheckRealSpec(Handle timer, any client)
{
	if (IsClientObserver(client) && !bSpecToolHintShown[client])
	{
		bSpecToolHintShown[client] = true;
		//CPrintToChat(client, "<{olive}SpecTool{default}> Press {blue}USE {default}towards a player or {blue}number 1-8 {default}to view their {green}First-Pov{default}.");
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3])
{
	if (client < 0 || client > MaxClients || IsFakeClient(client) || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	if (!IsClientObserver(client))
	{
		return Plugin_Continue;
	}
	
	if (buttons & IN_USE)
	{
		if (fButtonTime[client] > -1.0 && GetEngineTime() - fButtonTime[client] < 0.5) { return Plugin_Continue; }
		
		fButtonTime[client] = GetEngineTime();
		
		int target = GetClientAimTarget(client);
		if (target != -1 && (GetClientTeam(target) == 2 || GetClientTeam(target) == 3) && IsPlayerAlive(target))
		{
			
#if DEBUG
PrintToChat(client, "[SpecTool] You tried viewing player %N (userid:%d) in-eye.", target, GetClientUserId(target));
#endif
			
			float clientOrigin[3], targetOrigin[3];
			GetClientAbsOrigin(client, clientOrigin);
			GetClientAbsOrigin(target, targetOrigin);
			if (GetVectorDistance(clientOrigin, targetOrigin, true) < MAX_DIST_SQUARED)
			{
				if (IsVisibleTo(client, target) || IsVisibleTo(client, target, true))
				{
					TeleportToFirstPovOfTarget(client, target);
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public void TeleportToFirstPovOfTarget(int client, int target)
{
	if (!IsClientObserver(client)) { return; }
	
	char namebuf[MAX_NAME_LENGTH];
	GetClientName(target, namebuf, sizeof(namebuf));
#if DEBUG
PrintToChat(client, "[SpecTool] Teleporting to eye-view of %s...", namebuf);
#endif
	FakeClientCommand(client, "spec_mode 4"); /* 4 = in-eye, 5 = chase, 6 = roaming */
	FakeClientCommand(client, "spec_player \"%s\"", namebuf);
}


/**
 * From Pill_passer by CanadaRox
**/
stock bool IsVisibleTo(int client, int client2, bool ghetto_lagcomp = false) // check an entity for being visible to a client
{
	float vAngles[3], vOrigin[3], vEnt[3], vLookAt[3];
	float vClientVelocity[3], vClient2Velocity[3];

	GetClientEyePosition(client, vOrigin); // get both player and zombie position
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vClientVelocity);

	GetClientAbsOrigin(client2, vEnt);
	GetEntPropVector(client2, Prop_Data, "m_vecAbsVelocity", vClient2Velocity);

	float ping = GetClientAvgLatency(client, NetFlow_Outgoing);
	float lerp = GetEntPropFloat(client, Prop_Data, "m_fLerpTime");
	lerp *= 4;
	/* This number is pretty much pulled out of my ass with a little bit of testing on a local server with NF */
	/* If you have a problem with this number, blame NF!!! */

	if (ghetto_lagcomp)
	{
		vOrigin[0] += vClientVelocity[0] * (ping + lerp) * -1;
		vOrigin[1] += vClientVelocity[1] * (ping + lerp) * -1;
		vOrigin[2] += vClientVelocity[2] * (ping + lerp) * -1;

		vEnt[0] += vClient2Velocity[0] * (ping) * -1;
		vEnt[1] += vClient2Velocity[1] * (ping) * -1;
		vEnt[2] += vClient2Velocity[2] * (ping) * -1;
	}

	MakeVectorFromPoints(vOrigin, vEnt, vLookAt); // compute vector from player to zombie

	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_OPAQUE_AND_NPCS, RayType_Infinite, TraceFilter);

	bool isVisible = false;
	if (TR_DidHit(trace))
	{
		float vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint

		if ((GetVectorDistance(vOrigin, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(vOrigin, vEnt))
		{
			isVisible = true;
		}
	}
	else
	{
		isVisible = true;
	}
	CloseHandle(trace);
	return isVisible;
}

public bool TraceFilter(int entity, int contentsMask)
{
	if (entity <= MaxClients)
		return false;
	return true;
}
