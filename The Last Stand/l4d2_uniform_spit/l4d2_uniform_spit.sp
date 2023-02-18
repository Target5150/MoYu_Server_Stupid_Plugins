#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <left4dhooks> //#include <l4d2d_timers>

public Plugin myinfo =
{
	name = "L4D2 Uniform Spit",
	author = "Visor, Sir, A1m`, Forgetest",
	description = "Make the spit deal a set amount of DPS under all circumstances",
	version = "2.1",
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define MAX_ENTITY_NAME_SIZE 64
#define MAX_INT_STRING_SIZE 8

#define TEAM_SURVIVOR 2

#define DMG_TYPE_SPIT (DMG_RADIATION|DMG_ENERGYBEAM)

#define GAMEDATA_FILE "l4d2_uniform_spit"
#define FUNCTION_NAME "CInsectSwarm::GetFlameLifetime"

enum struct PuddleInfo
{
	float flDamageTime;
	float flResetTime;
	Address pLastArea;
}

int 
	g_iDamageCurveNodes;
float
	g_flDamageCurve[20];

StringMap
	g_hPuddles;

bool
	g_bLateLoad;

bool
	g_bRepeat,
	g_bIndividual;

float
	g_flLifeTime,
	g_flGrace,
	g_flResumeWindow;

DynamicHook
	g_lifetimeHook;

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
	g_bLateLoad = bLate;
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData gd = new GameData(GAMEDATA_FILE);
	if (!gd)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	g_lifetimeHook = DynamicHook.FromConf(gd, FUNCTION_NAME);
	if (!g_lifetimeHook)
		SetFailState("Missing detour setup \""...FUNCTION_NAME..."\"");
	
	delete gd;
	
	CreateConVarHook("l4d2_spit_dmg",
			"0.0/5.0/10.0/20.0/30.0/30.0/20.0/7.0",
			"Linear curve of damage per second that the spit inflicts (separated by \"/\"). -1 to skip damage adjustments",
			FCVAR_SPONLY,
			false, 0.0, false, 0.0,
			CvarChg_Damage);
	
	CreateConVarHook("l4d2_spit_dmg_repeat",
			"0",
			"Repeat damage curve. 0 to disable.",
			FCVAR_SPONLY,
			true, 0.0, true, 1.0,
			CvarChg_DamageRepeat);
	
	CreateConVarHook("l4d2_spit_lifetime",
			"7.0",
			"Maximum lifetime of acids.",
			FCVAR_SPONLY,
			true, 0.0, false, 0.0,
			CvarChg_Lifetime);
	
	CreateConVarHook("l4d2_spit_grace",
			"1.0",
			"How long after Spitter acid detonates until it can cause damage.",
			FCVAR_SPONLY,
			true, 0.0, false, 0.0,
			CvarChg_Grace);
	
	CreateConVarHook("l4d2_spit_individual",
			"0",
			"Individual damage calculation for every player. 0 to disable.",
			FCVAR_SPONLY,
			true, 0.0, true, 1.0,
			CvarChg_Individual);
	
	CreateConVarHook("l4d2_spit_resume",
			"1.0",
			"Tolerance window of time that individual damage calculation can resume from last state.",
			FCVAR_SPONLY,
			true, 0.0, false, 0.0,
			CvarChg_Resume);
	
	g_hPuddles = new StringMap();
	
	HookEvent("round_start", Event_RoundReset, EventHookMode_PostNoCopy);
	
	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i)) OnClientPutInServer(i);
		}
	}
}

void Event_RoundReset(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	g_hPuddles.Clear();
}

public void OnMapEnd()
{
	g_hPuddles.Clear();
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void OnClientDisconnect(int iClient)
{
	SDKUnhook(iClient, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void OnEntityCreated(int iEntity, const char[] sClassName)
{
	if (sClassName[0] != 'i') {
		return;
	}
	
	if (strcmp(sClassName, "insect_swarm") == 0)
	{
		char sTrieKey[MAX_INT_STRING_SIZE];
		IntToString(iEntity, sTrieKey, sizeof(sTrieKey));

		PuddleInfo[] iVictimArray = new PuddleInfo[MaxClients+1];
		g_hPuddles.SetArray(sTrieKey, iVictimArray[0], ((MaxClients+1) * sizeof(PuddleInfo)));
		
		g_lifetimeHook.HookEntity(Hook_Pre, iEntity, DTR_CInsectSwarm__GetFlameLifetime);
	}
}

public void OnEntityDestroyed(int iEntity)
{
	if (IsInsectSwarm(iEntity))
	{
		char sTrieKey[MAX_INT_STRING_SIZE];
		IntToString(iEntity, sTrieKey, sizeof(sTrieKey));

		g_hPuddles.Remove(sTrieKey);
	}
}

MRESReturn DTR_CInsectSwarm__GetFlameLifetime(DHookReturn hReturn)
{
	hReturn.Value = g_flLifeTime;
	return MRES_Supercede;
} 

/*
 * signed int CInsectSwarm::GetDamageType()
 * {
 *   return 263168; //DMG_RADIATION|DMG_ENERGYBEAM
 * }
*/
Action Hook_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &fDamageType)
{
	if (!(fDamageType & DMG_TYPE_SPIT)) //for performance
		return Plugin_Continue;

	if (!IsInsectSwarm(iInflictor) || !IsSurvivor(iVictim))
		return Plugin_Continue;
	
	char sTrieKey[MAX_INT_STRING_SIZE];
	IntToString(iInflictor, sTrieKey, sizeof(sTrieKey));

	PuddleInfo[] iVictimArray = new PuddleInfo[MaxClients+1];
	if (!g_hPuddles.GetArray(sTrieKey, iVictimArray[0], ((MaxClients+1) * sizeof(PuddleInfo))))
		return Plugin_Continue;
	
	// Check to see if it's a godframed tick
	if (GetPuddleLifetime(iInflictor) <= g_flGrace)
		return Plugin_Handled;
	
	float flActiveSince = GetPuddleSpawnTime(iInflictor);
	
	if (g_bIndividual)
	{
		// Area check to help determine if the victim was godframed
		Address area = L4D_GetLastKnownArea(iVictim);
		Address lastArea = iVictimArray[iVictim].pLastArea;
		
		if (lastArea == Address_Null || area != lastArea)
			iVictimArray[iVictim].pLastArea = area;
		
		float flNow = GetGameTime();
		if (iVictimArray[iVictim].flDamageTime == 0.0
			|| (area != lastArea && flNow > iVictimArray[iVictim].flResetTime)
		) {
			iVictimArray[iVictim].flDamageTime = flNow;
		}
		
		iVictimArray[iVictim].flResetTime = flNow + g_flResumeWindow;
		flActiveSince = iVictimArray[iVictim].flDamageTime;
	}

	// Update the array with stored tickcounts
	g_hPuddles.SetArray(sTrieKey, iVictimArray[0], ((MaxClients+1) * sizeof(PuddleInfo)));
	
	// Let's see what do we have here
	float flDamageThisTick = GetDamagePerTick(flActiveSince);
	if (flDamageThisTick > 0.0)
	{
		fDamage = flDamageThisTick;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

float GetDamagePerTick(float flStartTime)
{
	if (g_iDamageCurveNodes == 0)
		return -1.0;
	
	float flElaspedTime = GetGameTime() - flStartTime;
	int iElaspedTime = RoundToFloor(flElaspedTime);
	
	if (iElaspedTime + 1 >= g_iDamageCurveNodes)
	{
		if (!g_bRepeat || iElaspedTime < g_iDamageCurveNodes)
			return g_flDamageCurve[g_iDamageCurveNodes - 1];
		
		iElaspedTime %= g_iDamageCurveNodes;
	}
	
	float flFraction = flElaspedTime - iElaspedTime;
	
	float flDmgBase = g_flDamageCurve[iElaspedTime];
	float flDmgFrac = g_flDamageCurve[iElaspedTime + 1] - flDmgBase;
	
	return flDmgFrac * flFraction + flDmgBase;
}

float GetPuddleLifetime(int iPuddle)
{
	return ITimer_GetElapsedTime(GetInfernoActiveTimer(iPuddle));
}

float GetPuddleSpawnTime(int iPuddle)
{
	return ITimer_GetTimestamp(GetInfernoActiveTimer(iPuddle));
}

IntervalTimer GetInfernoActiveTimer(int inferno)
{
	static int s_iActiveTimerOffset = -1;
	if (s_iActiveTimerOffset == -1)
		s_iActiveTimerOffset = FindSendPropInfo("CInferno", "m_fireCount") + 344;
	
	return view_as<IntervalTimer>(GetEntityAddress(inferno) + view_as<Address>(s_iActiveTimerOffset));
}

bool IsInsectSwarm(int iEntity)
{
	if (iEntity <= MaxClients || !IsValidEdict(iEntity)) {
		return false;
	}

	char sClassName[MAX_ENTITY_NAME_SIZE];
	GetEdictClassname(iEntity, sClassName, sizeof(sClassName));
	return (strcmp(sClassName, "insect_swarm") == 0);
}

bool IsSurvivor(int iClient)
{
	return (iClient > 0
		&& iClient <= MaxClients
		&& IsClientInGame(iClient)
		&& GetClientTeam(iClient) == TEAM_SURVIVOR);
}

void CvarChg_Damage(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	char buffer[128];
	hConVar.GetString(buffer, sizeof(buffer));
	g_iDamageCurveNodes = StringToFloatArray(buffer, "/", g_flDamageCurve, sizeof(g_flDamageCurve), false);
}

void CvarChg_DamageRepeat(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	g_bRepeat = hConVar.BoolValue;
}

void CvarChg_Lifetime(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	g_flLifeTime = hConVar.FloatValue;
}

void CvarChg_Grace(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	g_flGrace = hConVar.FloatValue;
}

void CvarChg_Individual(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	g_bIndividual = hConVar.BoolValue;
}

void CvarChg_Resume(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	g_flResumeWindow = hConVar.FloatValue;
}

int StringToFloatArray(const char[] buffer, const char[] split, float[] array, int size, bool fill = false)
{
	static const int MAX_FLOAT_STRING_SIZE = 16;
	
	char[][] buffers = new char[size][MAX_FLOAT_STRING_SIZE];
	int numStrings = ExplodeString(buffer, split, buffers, size, MAX_FLOAT_STRING_SIZE, true);
	
	if (numStrings == 0)
		return 0;
	
	if (numStrings > size)
		numStrings = size;
	
	for (int i = 0; i < numStrings; ++i)
	{
		array[i] = StringToFloat(buffers[i]);
	}
	
	if (fill)
	{
		float flLastElement = array[numStrings - 1];
		for (int i = numStrings; i < size; ++i)
		{
			array[i] = flLastElement;
		}
		
		return size;
	}
	
	return numStrings;
}

ConVar CreateConVarHook(const char[] name,
	const char[] defaultValue,
	const char[] description="",
	int flags=0,
	bool hasMin=false, float min=0.0,
	bool hasMax=false, float max=0.0,
	ConVarChanged callback)
{
	ConVar cv = CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
	
	Call_StartFunction(INVALID_HANDLE, callback);
	Call_PushCell(cv);
	Call_PushNullString();
	Call_PushNullString();
	Call_Finish();
	
	cv.AddChangeHook(callback);
	
	return cv;
}
