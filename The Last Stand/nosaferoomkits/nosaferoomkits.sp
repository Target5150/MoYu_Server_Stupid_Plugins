#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.1.4"

static const char g_sGamemodes[4][] = 
{
	"coop", "versus", "survival", "scavenge"
};

float g_fSurvivorStart[3];
bool g_bMapStarted;
int g_iGamemode;

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

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

// credit to SilverShot
bool IsSingleChapterGamemode()
{
	g_iGamemode = 0;
	
	if (!g_bMapStarted)
	{
		return false;
	}
	
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
	
	return (g_iGamemode == 3) || (g_iGamemode == 4);
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iGamemode = 1;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iGamemode = 2;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iGamemode = 3;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iGamemode = 4;
}

//On every round,
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.1, Timer_RoundStart);
}

public Action Timer_RoundStart(Handle timer)
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

	if (!IsSingleChapterGamemode())
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
	char sGamemode[16];
	strcopy(sGamemode, sizeof sGamemode, g_sGamemodes[g_iGamemode-1]);
	
	for (int i = MaxClients+1; i <= iEntityCount; i++)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, szEdictClassName, sizeof(szEdictClassName));
			if (StrContains(szEdictClassName, "info_survivor_position", false) != -1)
			{
				static char buffer[16];
				if (
					GetEntPropString(i, Prop_Data, "m_iszGameMode", buffer, sizeof buffer)
					&& strcmp(buffer, sGamemode, false) != 0
				) {
					continue;
				}
				
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