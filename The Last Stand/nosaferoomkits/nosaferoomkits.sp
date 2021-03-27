#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.1.3"

enum L4D2Gamemode
{
	Coop		= (1 << 0),
	Versus		= (1 << 1),
	Survival	= (1 << 2),
	Scavenge	= (1 << 3)
}

float g_fSurvivorStart[3];
L4D2Gamemode g_eGamemode;

public Plugin myinfo = 
{
	name = "No Safe Room Medkits",
	author = "Blade",
	description = "Removes Safe Room Medkits",
	version = PLUGIN_VERSION,
	url = "nope"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//Look up what game we're running,
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		//and don't load if it's not L4D2.
		strcopy(error, err_max, "Plugin supports Left 4 Dead 2 only.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("nokits_version", PLUGIN_VERSION, "No Safe Room Medkits Version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
}

// credit to SilverShot
void IsAllowedGamemode()
{
	int entity = CreateEntityByName("info_gamemode");
	if( IsValidEntity(entity) )
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
			RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
	}
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_eGamemode = Coop;
	else if( strcmp(output, "OnVersus") == 0 )
		g_eGamemode = Versus;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_eGamemode = Survival;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_eGamemode = Scavenge;
}

//On every round,
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//find where the survivors start so we know which medkits to replace,
	FindSurvivorStart();
	//and replace the medkits with pills.
	ReplaceMedkits();
}

void FindSurvivorStart()
{
	int iEntityCount = GetEntityCount();
	char szEdictClassName[64];
	float fLocation[3];

	IsAllowedGamemode();
	
	if (g_eGamemode & (Coop | Versus))
	{
		//Search entities for either a locked saferoom door,
		for (int i = MaxClients+1; i <= iEntityCount; i++)
		{
			if (IsValidEntity(i))
			{
				GetEdictClassname(i, szEdictClassName, sizeof(szEdictClassName));
				if ((StrContains(szEdictClassName, "prop_door_rotating_checkpoint", false) != -1) && (GetEntProp(i, Prop_Send, "m_bLocked")==1))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", fLocation);
					g_fSurvivorStart = fLocation;
					return;
				}
			}
		}
	}
	//or a survivor start point.
	for (int i = MaxClients+1; i <= iEntityCount; i++)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, szEdictClassName, sizeof(szEdictClassName));
			if (StrContains(szEdictClassName, "info_survivor_position", false) != -1)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", fLocation);
				g_fSurvivorStart = fLocation;
				return;
			}
		}
	}
}

void ReplaceMedkits()
{
	int iCount = GetEntityCount();
	char szEdictClassName[64];
	float fNearestMedkit[3], fLocation[3];
	
	ArrayList hArrayList = new ArrayList();
	
	//Look for the nearest medkit from where the survivors start,
	for (int i = MaxClients+1; i <= iCount; i++)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, szEdictClassName, sizeof(szEdictClassName));
			if (StrContains(szEdictClassName, "weapon_first_aid_kit", false) != -1)
			{
				//Store medkit index
				hArrayList.Push(i);
				
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", fLocation);
				//If NearestMedkit is zero, then this must be the first medkit we found.
				if (GetVectorLength(fNearestMedkit) == 0.0)
				{
					fNearestMedkit = fLocation;
					continue;
				}
				//If this medkit is closer than the last medkit, record its location.
				if (GetVectorDistance(g_fSurvivorStart, fLocation, true) < GetVectorDistance(g_fSurvivorStart, fNearestMedkit, true))
					fNearestMedkit = fLocation;
			}
		}
	}
	
	iCount = hArrayList.Length;
	//then remove the kits
	for (int i = 0; i < iCount; i++)
	{
		int medkit = hArrayList.Get(i);
		GetEntPropVector(medkit, Prop_Send, "m_vecOrigin", fLocation);
		if (GetVectorDistance(fNearestMedkit, fLocation, true) < 16000)
		{
			RemoveEntity(medkit);
		}
	}
	
	delete hArrayList;
}