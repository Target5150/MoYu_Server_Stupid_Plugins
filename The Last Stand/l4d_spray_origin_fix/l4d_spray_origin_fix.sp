#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = 
{
	name = "Spray Origin Fix",
	author = "Forgetest",
	description = "Self-descriptive",
	version = PLUGIN_VERSION,
	url = "ez"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	AddTempEntHook("Player Decal", PlayerDecal);
}

public Action PlayerDecal(const char[] te_name, const int[] Players, int numClients, float delay)
{
	int client = TE_ReadNum("m_nPlayer");
	if( !client || !IsClientInGame(client) )
	{
		return Plugin_Handled;
	}

	if( GetClientTeam(client) != 2 || !IsPlayerAlive(client) )
	{
		return Plugin_Continue;
	}
	
	// Functions only on Survivors who are incapped or hanging
	if( !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge") )
	{
		return Plugin_Continue;
	}
	
	float viewPoint[3];
	if( GetPlayerEyeViewPoint(client, viewPoint) )
	{
		TE_WriteVector("m_vecOrigin", viewPoint);
	}
	
	return Plugin_Continue;
}

stock bool GetPlayerEyeViewPoint(int iClient, float fPosition[3])
{
	float fAngles[3], fOrigin[3];
	
	GetClientEyeAngles(iClient, fAngles);
	GetClientEyePosition(iClient, fOrigin);

	Handle hTrace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
	if( TR_DidHit(hTrace) )
	{
		TR_GetEndPosition(fPosition, hTrace);
		delete hTrace;
		return true;
	}
	delete hTrace;
	return false;
}

public bool TraceEntityFilterPlayer(int iEntity, int iContentsMask)
{
	return iEntity > MaxClients;
}