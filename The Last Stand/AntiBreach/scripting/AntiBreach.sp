#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <colors>

#define PLUGIN_VERSION "2.0.1"

public Plugin myinfo = 
{
	name = "No spawn near safe room door.",
	author = "Eyal282 ( FuckTheSchool ), Forgetest",
	description = "To prevent a player breaching safe room door with a bug, prevents him from spawning near safe room door.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define TRANSLATION_FILE "AntiBreach.phrases"
float g_flLastExploitTime[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadPluginTranslations(TRANSLATION_FILE);
}

public Action L4D_OnMaterializeFromGhostPre(int client)
{
	float vecOrigin[3], vecVelocity[3];
	GetClientAbsOrigin(client, vecOrigin);
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vecVelocity);
	
	ScaleVector(vecVelocity, GetTickInterval());
	
	float vecPredictedOrigin[3];
	AddVectors(vecOrigin, vecVelocity, vecPredictedOrigin);
	
	Address nav = L4D_GetNearestNavArea(vecPredictedOrigin, 300.0, false, false, false);
	if (nav != Address_Null)
	{
		int spawnAttributes = L4D_GetNavArea_SpawnAttributes(nav);
		if (spawnAttributes & NAV_SPAWN_CHECKPOINT && L4D2Direct_GetTerrorNavAreaFlow(nav) > 2000.0)
		{
			AlertToExploits(client);
			return Plugin_Handled;
		}
	}
	
	float vecMins[3], vecMaxs[3];
	GetClientMins(client, vecMins);
	GetClientMaxs(client, vecMaxs);
	
	Handle tr = TR_TraceHullFilterEx(vecOrigin, vecPredictedOrigin, vecMins, vecMaxs, MASK_SOLID, TraceFilter_SaferoomDoors);
	
	bool bDidHit = TR_DidHit(tr);
	delete tr;
	
	if (bDidHit)
	{
		AlertToExploits(client);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

bool TraceFilter_SaferoomDoors(int entity, int contentsMask)
{
	if (entity > MaxClients)
	{
		static char cls[64];
		if (GetEdictClassname(entity, cls, sizeof(cls)))
		{
			return strcmp(cls, "prop_door_rotating_checkpoint") == 0 && GetEntProp(entity, Prop_Send, "m_eDoorState") == 0;
		}
	}
	
	return false;
}

void AlertToExploits(int client)
{
	if (g_flLastExploitTime[client] != -1.0)
	{
		if (GetGameTime() - g_flLastExploitTime[client] <= 2.5)
			return;
	}
	
	g_flLastExploitTime[client] = GetGameTime();
	
	CSkipNextClient(client);
	CPrintToChatAll("%t", "AlertAllToExploits", client);
	
	CPrintToChat(client, "%t", "AlertPlayerToExploits");
}

public void OnClientPutInServer(int client)
{
	g_flLastExploitTime[client] = -1.0;
}

void LoadPluginTranslations(const char[] file)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/%s.txt", file);
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation file \"%s.txt\"", file);
	}
	LoadTranslations(file);
}
