/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <readyup>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.0"

public Plugin myinfo =
{
	name		= "L4D2 Equalise Alarm Cars",
	author		= "Jahze, Forgetest",
	version		= PLUGIN_VERSION,
	description	= "Make the alarmed car and its color spawns the same for each team in versus"
};

bool bHooked = false;
bool bActivated = false;
bool bSecondRound = false;
bool bPatched = false;
bool bManually = false;
bool bRoundIsLive = false;

ArrayList hFirstRoundCars;
ArrayList hSecondRoundCars;
ArrayList hAlarmedCars;
StringMap hCarColorsTrie;

ConVar hCvarEqAlarmCars;
ConVar hCvarStartDisabled;

#define RGBA_BLOCK 4
#define MAX_OFF_COLOR 6
int iOffColors[6][RGBA_BLOCK] =
{
//	R		G		B		A
	{99,	135,	157,	255},
	{52,	46,		46,		255},
	{173,	186,	172,	255},
	{52,	70,		114,	255},
	{9,		41, 	138,	255},
	{68,	91, 	183,	255}
};

public void OnPluginStart()
{
	hCvarEqAlarmCars = CreateConVar("l4d_equalise_alarm_cars", "1", "Makes alarmed cars spawn in the same way for both teams", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvarStartDisabled = CreateConVar("l4d_equalise_alarm_start_disabled", "1", "Makes alarmed cars spawn disabled before game goes live.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	hCvarEqAlarmCars.AddChangeHook(EqAlarmCarsChange);
	
	hFirstRoundCars = new ArrayList(ByteCountToCells(128));
	hSecondRoundCars = new ArrayList(ByteCountToCells(128));
	hAlarmedCars = new ArrayList(ByteCountToCells(128));
	hCarColorsTrie = new StringMap();
	
	HookEvents();
}

public void OnMapStart()
{
	bActivated = false;
	bSecondRound = false;
	bManually = false;
	
	hFirstRoundCars.Clear();
	hSecondRoundCars.Clear();
	hAlarmedCars.Clear();
	hCarColorsTrie.Clear();
}

void HookEvents()
{
	if ( !bHooked )
	{
		HookEvent("round_start", RoundStart);
		HookEvent("round_end", RoundEnd, EventHookMode_Pre);
		HookEvent("player_left_start_area", PlayerLeftStartArea);
		bHooked = true;
	}
}

void UnhookEvents()
{
	if ( bHooked )
	{
		UnhookEvent("round_start", RoundStart);
		UnhookEvent("round_end", RoundEnd, EventHookMode_Pre);
		UnhookEvent("player_left_start_area", PlayerLeftStartArea);
		bHooked = false;
	}
}

public void EqAlarmCarsChange( ConVar convar, const char[] oldValue, const char[] newValue )
{
	if ( StringToInt(newValue) == 1 )
	{
		HookEvents();
	}
	else
	{
		UnhookEvents();
	}
}

public void RoundStart( Event event, const char[] name, bool dontBroadcast )
{
	bPatched = false;
	bRoundIsLive = false;
	if (bSecondRound) OnMapStart();
	
	CreateTimer(0.1, RoundStartDelay);
}

public void RoundEnd( Event event, const char[] name, bool dontBroadcast )
{
	if (!bSecondRound)
	{
		int iEntity = MaxClients+1;
		char szEntName[128];
		
		while ((iEntity = FindEntityByClassname(iEntity, "prop_car_alarm")) != -1)
		{
			int iColor[RGBA_BLOCK];
			GetEntityName(iEntity, szEntName, sizeof(szEntName));
			GetEntityRenderColorEx(iEntity, iColor);
			hCarColorsTrie.SetArray(szEntName, iColor, RGBA_BLOCK);
		}
		bSecondRound = true;
	}
}

public void OnRoundIsLive()
{
	bRoundIsLive = true;
	RestoreCars();
}

public void PlayerLeftStartArea( Event event, const char[] name, bool dontBroadcast )
{
	if (!bRoundIsLive)
	{
		bRoundIsLive = true;
		RestoreCars();
	}
}

public Action RoundStartDelay( Handle timer )
{
	int iEntity = MaxClients+1;
	char sTargetName[128];
	
	if ( bSecondRound && !bActivated )
	{
		CreateTimer(1.2, PatchAlarmCarColors);
		CreateTimer(10.0, DisableCars);
		return;
	}
    
	while ( (iEntity = FindEntityByClassname(iEntity, "logic_relay")) != -1 )
	{
		GetEntityName(iEntity, sTargetName, sizeof(sTargetName));
		
		int index = StrContains(sTargetName, "relay_caralarm_o");
		if ( index == -1 )
		{
			continue;
		}
		
		//LogMessage("<RoundStartDelay> %s", sTargetName);
		
		switch (sTargetName[index+16])
		{
			case 'n':
			{
				HookSingleEntityOutput(iEntity, "OnTrigger", CarAlarmLogicRelayOnTriggered);
			}
			case 'f':
			{
				if ( !bSecondRound ) hAlarmedCars.PushString(sTargetName);
				HookSingleEntityOutput(iEntity, "OnTrigger", CarAlarmLogicRelayOffTriggered);
			}
		}
	}
	
	HookEntityOutput("prop_car_alarm", "OnCarAlarmStart", CarAlarmStarted);
	
	CreateTimer(2.5, DisableCars);
}

public void CarAlarmLogicRelayOnTriggered( const char[] output, int caller, int activator, float delay )
{
	if (bManually)
		return;
	
	char sTargetName[128];
	GetEntityName(caller, sTargetName, sizeof(sTargetName));
	
	//LogMessage("<LogicRelayOn> %s", sTargetName);
	
	ReplaceString(sTargetName, sizeof sTargetName, "relay_caralarm_on", "relay_caralarm_off");
	
	if ( !bSecondRound )
	{
		int idx = hAlarmedCars.FindString(sTargetName);
		if ( idx == -1 ) hAlarmedCars.PushString(sTargetName);
		
		idx = hFirstRoundCars.FindString(sTargetName);
		if ( idx != -1 ) hFirstRoundCars.Erase(idx);
	}
	else
	{
		int idx = hSecondRoundCars.FindString(sTargetName);
		if ( idx != -1 ) hSecondRoundCars.Erase(idx);
	}
}

public void CarAlarmLogicRelayOffTriggered( const char[] output, int caller, int activator, float delay )
{
	if (bManually)
		return;
	
	char sTargetName[128];
	GetEntityName(caller, sTargetName, sizeof(sTargetName));
	
	//LogMessage("<LogicRelayOff> %s", sTargetName);
	
	if (activator && IsValidEntity(activator))
	{
		char sBuffer[128];
		GetEntityClassname(activator, sBuffer, sizeof(sBuffer));
		
		// If a car is turned off because of a tank punch or because it was
		// triggered the activator is the car itself. When the cars get
		// randomised the activator is the player who entered the trigger area.
		if ( strcmp(sBuffer, "prop_car_alarm") == 0 )
		{
			//PrintToChatAll("<LogicRelay> %s", sBuffer);
			if (!bSecondRound)
			{
				int iColor[RGBA_BLOCK];
				GetEntityName(activator, sBuffer, sizeof(sBuffer));
				GetEntityRenderColorEx(activator, iColor);
				hCarColorsTrie.SetArray(sBuffer, iColor, RGBA_BLOCK);
			}
			return;
		}
	}
	
	if ( !bSecondRound )
	{
		bActivated = true;
		hFirstRoundCars.PushString(sTargetName);
		
		int index = hAlarmedCars.FindString(sTargetName);
		if ( index != -1 ) hAlarmedCars.Erase(index);
		
		int rndPick = Math_GetRandomInt(0, MAX_OFF_COLOR-1);
		ApplyCarColor(sTargetName, iOffColors[rndPick]);
	}
	else
	{
		hSecondRoundCars.PushString(sTargetName);
		
		if ( !bPatched )
		{
			CreateTimer(1.0, PatchAlarmedCars);
			CreateTimer(1.2, PatchAlarmCarColors);
			bPatched = true;
		}
	}
}

public void CarAlarmStarted(const char[] output, int caller, int activator, float delay)
{
	char sTargetName[128];
	GetEntityName(caller, sTargetName, sizeof(sTargetName));
		
	//LogMessage("<CarAlarmStarted> %s", sTargetName);
	//PrintToChatAll("<CarAlarmStarted> %s", sTargetName);
	
	if (!bSecondRound)
	{
		int iColor[RGBA_BLOCK];
		GetEntityRenderColorEx(caller, iColor);
		hCarColorsTrie.SetArray(sTargetName, iColor, RGBA_BLOCK);
	}
}

void RestoreCars()
{
	if (!hCvarStartDisabled.BoolValue)
		return;
	
	//LogMessage("<RestoreCars> start");
	//PrintToChatAll("<RestoreCars> start");
	
	bManually = true;
	
	char sEntName[128];
	
	int iArraySize = hAlarmedCars.Length;
	for ( int i = 0; i < iArraySize; i++ )
	{
		hAlarmedCars.GetString(i, sEntName, sizeof(sEntName));
		EnableCar(sEntName);
		//LogMessage("<RestoreCars> %s", sEntName);
		//PrintToChatAll("<RestoreCars> %s", sEntName);
	}
	
	bManually = false;
	
	//LogMessage("<RestoreCars> end");
	//PrintToChatAll("<RestoreCars> end");
}

public Action DisableCars( Handle timer )
{
	if (!hCvarStartDisabled.BoolValue)
		return;
	
	//LogMessage("<DisableCars> start");
	//PrintToChatAll("<DisableCars> start");
	
	bManually = true;
	
	char sEntName[128];
	
	int iArraySize = hAlarmedCars.Length;
	for ( int i = 0; i < iArraySize; i++ )
	{
		hAlarmedCars.GetString(i, sEntName, sizeof(sEntName));
		DisableCar(sEntName);
		//LogMessage("<DisableCars> %s", sEntName);
		//PrintToChatAll("<DisableCars> %s", sEntName);
	}
	
	bManually = false;
	
	//LogMessage("<DisableCars> end");
	//PrintToChatAll("<DisableCars> end");
}

public Action PatchAlarmedCars( Handle timer )
{
	char sEntName[128];
	
	int iArraySize = hFirstRoundCars.Length;
	for ( int i = 0; i < iArraySize; i++ )
	{
		hFirstRoundCars.GetString(i, sEntName, sizeof(sEntName));
		
		if ( hSecondRoundCars.FindString(sEntName) == -1 )
		{
			DisableCar(sEntName);
		}
	}
	
	iArraySize = hSecondRoundCars.Length;
	for ( int i = 0; i < iArraySize; i++ )
	{
		hSecondRoundCars.GetString(i, sEntName, sizeof(sEntName));
		
		if ( hFirstRoundCars.FindString(sEntName) == -1 )
		{
			EnableCar(sEntName);
		}
	}
}

public Action PatchAlarmCarColors(Handle timer)
{
	if (!hCarColorsTrie.Size) return;
	
	int iEntity = MaxClients+1;
	char szEntName[128];
	
	while ((iEntity = FindEntityByClassname(iEntity, "prop_car_alarm")) != -1) {
		GetEntityName(iEntity, szEntName, sizeof(szEntName));
		
		int iColor[RGBA_BLOCK];
		if (hCarColorsTrie.GetArray(szEntName, iColor, RGBA_BLOCK)) {
			SetEntityRenderColorEx(iEntity, iColor);
		}
	}
}

int ExtractCarName( const char[] sName, const char[] sCompare, char[] sBuffer, int iSize ) {
	int index = SplitString(sName, "-", sBuffer, iSize);
	if (index == -1) {
		// Spilt delimiter doesn't exist.
		return 0;
	}
	
	if (strcmp(sName[index], sCompare)) {
		// Compare string is before spilt delimiter.
		strcopy(sBuffer, iSize, sName[index]);
		return -1;
	}
	
	// Compare string is after spilt delimiter.
	return 1;
}

void DisableCar( const char[] sName ) {
	TriggerCarRelay(sName, false);
}

void EnableCar( const char[] sName ) {
	TriggerCarRelay(sName, true);
}

void TriggerCarRelay( const char[] sName, bool bOn ) {
	char sCarName[128];
	int iEntity, iPosition;
	
	if ( !(iPosition = ExtractCarName(sName, "relay_caralarm_off", sCarName, sizeof(sCarName))) ) {
		return;
	}
	
	if (iPosition == 1) {
		StrCat(sCarName, sizeof(sCarName), "-{RelayToggle}");
	}
	else {
		Format(sCarName, sizeof(sCarName), "{RelayToggle}-%s", sCarName);
	}
	
	ReplaceString(sCarName, sizeof(sCarName), "{RelayToggle}", bOn ? "relay_caralarm_on" : "relay_caralarm_off");
	
	iEntity = FindEntityByName(sCarName, "logic_relay");
	
	if ( iEntity != -1 ) {
		AcceptEntityInput(iEntity, "Trigger");
	}
}

void ApplyCarColor(const char[] sName, int iColor[RGBA_BLOCK])
{
	char szCarName[128];
	int iEntity, iPosition;
	
	if ( !(iPosition = ExtractCarName(sName, "relay_caralarm_off", szCarName, sizeof(szCarName))) ) {
		return;
	}
	
	if (iPosition == 1) {
		StrCat(szCarName, sizeof(szCarName), "-caralarm_car1");
	}
	else {
		Format(szCarName, sizeof(szCarName), "caralarm_car1-%s", szCarName);
	}
	
	iEntity = FindEntityByName(szCarName, "prop_car_alarm");
	
	if (iEntity != -1) {
		SetEntityRenderColorEx(iEntity, iColor);
	}
}

int FindEntityByName( const char[] sName, const char[] sClassName ) {
	int iEntity = -1;
	char sEntName[128];
	
	while ( (iEntity = FindEntityByClassname(iEntity, sClassName)) != -1 ) {
		if ( !IsValidEntity(iEntity) ) {
			continue;
		}
		
		GetEntityName(iEntity, sEntName, sizeof(sEntName));
		
		if ( StrEqual(sEntName, sName) ) {
			return iEntity;
		}
	}
	
	return -1;
}

void GetEntityName( int iEntity, char[] sTargetName, int iSize ) {
	GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, iSize);
}

void GetEntityRenderColorEx(int entity, int color[RGBA_BLOCK])
{
	GetEntityRenderColor(entity, color[0], color[1], color[2], color[3]);
}

void SetEntityRenderColorEx(int entity, int color[RGBA_BLOCK])
{
	SetEntityRenderColor(entity, color[0], color[1], color[2], color[3]);
}

/**
 * Returns a random, uniform Integer number in the specified (inclusive) range.
 * This is safe to use multiple times in a function.
 * The seed is set automatically for each plugin.
 * Rewritten by MatthiasVance, thanks.
 *
 * @param min			Min value used as lower border
 * @param max			Max value used as upper border
 * @return				Random Integer number between min and max
 */
#define SIZE_OF_INT         2147483647 // without 0
stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0) {
		random++;
	}

	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}

