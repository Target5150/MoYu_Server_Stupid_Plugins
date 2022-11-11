#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks> //#include <l4d2d_timers>

#define MAX_ENTITY_NAME_SIZE 64
#define MAX_INT_STRING_SIZE 8

#define TICK_TIME 0.2 // was 0.200072, but game decides exactly with 0.2
#define TEAM_SURVIVOR 2

#define DMG_TYPE_SPIT (DMG_RADIATION|DMG_ENERGYBEAM)

enum
{
	eCount = 0,
	eAltTick,
	eLastTime,
	
	eArray_Size
};

ConVar
	g_hCvarDamagePerTick,
	g_hCvarAlternateDamagePerTwoTicks,
	g_hCvarMaxTicks,
	g_hCvarGodframeTicks,
	g_hCvarIndividualCalc;

StringMap
	g_hPuddles;

int
	g_iMaxTicks,
	g_iGodframeTicks;

bool
	g_bLateLoad,
	g_bIndividualCalc;

float
	g_fDamageCurve[20],
	g_fAlternatePerTick;

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
	g_bLateLoad = bLate;
	
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "L4D2 Uniform Spit",
	author = "Visor, Sir, A1m`, Forgetest",
	description = "Make the spit deal a set amount of DPS under all circumstances",
	version = "2.0.1",
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart()
{
	g_hCvarDamagePerTick = CreateConVar("l4d2_spit_dmg", "0.0/1.0/2.0/4.0/6.0/6.0/4.0/1.4", "Linear curve of damage per second that the spit inflicts. -1 to skip damage adjustments");
	g_hCvarAlternateDamagePerTwoTicks = CreateConVar("l4d2_spit_alternate_dmg", "-1.0", "Damage per alternate tick. -1 to disable");
	g_hCvarMaxTicks = CreateConVar("l4d2_spit_max_ticks", "28", "Maximum number of acid damage ticks");
	g_hCvarGodframeTicks = CreateConVar("l4d2_spit_godframe_ticks", "4", "Number of initial godframed acid ticks");
	g_hCvarIndividualCalc = CreateConVar("l4d2_spit_individual_calc", "0", "Individual damage calculation for every player.");
	
	g_hCvarDamagePerTick.AddChangeHook(CvarsChanged);
	g_hCvarAlternateDamagePerTwoTicks.AddChangeHook(CvarsChanged);
	g_hCvarMaxTicks.AddChangeHook(CvarsChanged);
	g_hCvarGodframeTicks.AddChangeHook(CvarsChanged);
	g_hCvarIndividualCalc.AddChangeHook(CvarsChanged);
	
	g_hPuddles = new StringMap();
	
	HookEvent("round_start", Event_RoundReset, EventHookMode_PostNoCopy);
	//HookEvent("round_end", Event_RoundReset, EventHookMode_PostNoCopy);
	
	if (g_bLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				OnClientPutInServer(i);
			}
		}
	}
}

void CvarsChanged(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	CvarsToType();
}

public void OnConfigsExecuted()
{
	CvarsToType();
}

void CvarsToType()
{
	char buffer[128];
	g_hCvarDamagePerTick.GetString(buffer, sizeof(buffer));
	StringToFloatArray(buffer, "/", g_fDamageCurve, sizeof(g_fDamageCurve), true);
	
	g_fAlternatePerTick = g_hCvarAlternateDamagePerTwoTicks.FloatValue;
	g_iMaxTicks = g_hCvarMaxTicks.IntValue;
	g_iGodframeTicks = g_hCvarGodframeTicks.IntValue;
	g_bIndividualCalc = g_hCvarIndividualCalc.BoolValue;
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
	}
	
	return numStrings;
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
	
	if (strcmp(sClassName, "insect_swarm") == 0) {
		char sTrieKey[MAX_INT_STRING_SIZE];
		IntToString(iEntity, sTrieKey, sizeof(sTrieKey));

		int iVictimArray[MAXPLAYERS + 1][eArray_Size];
		g_hPuddles.SetArray(sTrieKey, iVictimArray[0][0], (sizeof(iVictimArray) * sizeof(iVictimArray[])));
	}
}

public void OnEntityDestroyed(int iEntity)
{
	if (IsInsectSwarm(iEntity)) {
		char sTrieKey[MAX_INT_STRING_SIZE];
		IntToString(iEntity, sTrieKey, sizeof(sTrieKey));

		g_hPuddles.Remove(sTrieKey);
	}
}

/*
 * signed int CInsectSwarm::GetDamageType()
 * {
 *   return 263168; //DMG_RADIATION|DMG_ENERGYBEAM
 * }
*/
Action Hook_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &fDamageType)
{
	if (!(fDamageType & DMG_TYPE_SPIT)) { //for performance
		return Plugin_Continue;
	}

	if (!IsInsectSwarm(iInflictor) || !IsSurvivor(iVictim)) {
		return Plugin_Continue;
	}
	
	char sTrieKey[MAX_INT_STRING_SIZE];
	IntToString(iInflictor, sTrieKey, sizeof(sTrieKey));

	int iVictimArray[MAXPLAYERS + 1][eArray_Size];
	if (g_hPuddles.GetArray(sTrieKey, iVictimArray[0][0], (sizeof(iVictimArray) * sizeof(iVictimArray[])))) {
		iVictimArray[iVictim][eCount]++;
		
		// Check to see if it's a godframed tick
		if ((GetPuddleLifetime(iInflictor) >= g_iGodframeTicks * TICK_TIME) && iVictimArray[iVictim][eCount] < g_iGodframeTicks) {
			iVictimArray[iVictim][eCount] = g_iGodframeTicks + 1;
		}
		
		float flTempTimestamp = ITimer_GetTimestamp(GetInfernoActiveTimer(iInflictor));
		
		if (g_bIndividualCalc) {
			float flNow = GetGameTime();
			if (flNow - view_as<float>(iVictimArray[iVictim][eLastTime]) <= 1.0) {
				flTempTimestamp = view_as<float>(iVictimArray[iVictim][eLastTime]);
			} else {
				iVictimArray[iVictim][eLastTime] = view_as<int>(flNow);
			}
		}

		// Let's see what do we have here
		float flDamageThisTick = GetDamagePerTick(flTempTimestamp);
		if (flDamageThisTick > -1.0) {
			if (g_fAlternatePerTick > -1.0 && iVictimArray[iVictim][eAltTick]) {
				iVictimArray[iVictim][eAltTick] = false;
				fDamage = g_fAlternatePerTick;
			} else {
				fDamage = flDamageThisTick;
				iVictimArray[iVictim][eAltTick] = true;
			}
		}
		
		// Update the array with stored tickcounts
		g_hPuddles.SetArray(sTrieKey, iVictimArray[0][0], (sizeof(iVictimArray) * sizeof(iVictimArray[])));
		
		if (g_iGodframeTicks >= iVictimArray[iVictim][eCount] || iVictimArray[iVictim][eCount] > g_iMaxTicks) {
			fDamage = 0.0;
		}
		
		if (iVictimArray[iVictim][eCount] > g_iMaxTicks) {
			KillEntity(iInflictor);
		}
		
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

float GetDamagePerTick(float flStartTimestamp)
{
	if (g_fDamageCurve[0] == -1.0)
		return -1.0;
	
	float flElaspedTime = GetGameTime() - flStartTimestamp;
	int iElaspedTime = RoundToFloor(flElaspedTime);
	
	if (iElaspedTime >= sizeof(g_fDamageCurve))
		return g_fDamageCurve[sizeof(g_fDamageCurve) - 1];
	
	float flFraction = flElaspedTime - iElaspedTime;
	
	float flDmgBase = g_fDamageCurve[iElaspedTime];
	float flDmgFrac = g_fDamageCurve[iElaspedTime + 1] - flDmgBase;
	
	return flDmgFrac * flFraction + flDmgBase;
}

float GetPuddleLifetime(int iPuddle)
{
	return ITimer_GetElapsedTime(GetInfernoActiveTimer(iPuddle));
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

void KillEntity(int iEntity)
{
#if SOURCEMOD_V_MINOR > 8
	RemoveEntity(iEntity);
#else
	AcceptEntityInput(iEntity, "Kill");
#endif
}
