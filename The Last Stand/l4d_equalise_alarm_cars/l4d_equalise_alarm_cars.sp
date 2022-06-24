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
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <readyup>

#define PLUGIN_VERSION "3.0"

public Plugin myinfo =
{
	name		= "L4D2 Equalise Alarm Cars",
	author		= "Jahze, Forgetest",
	version		= PLUGIN_VERSION,
	description	= "Make the alarmed car and its color spawns the same for each team in versus"
};

StringMap g_smCarNameMap;

enum alarmArray
{
	ENTRY_RELAY_ON,
	ENTRY_RELAY_OFF,
	ENTRY_START_STATE,
	ENTRY_ALARM_CAR,
	ENTRY_COLOR,
	
	alarmArray_SIZE
}
ArrayList g_aAlarmArray;

ConVar g_cvStartDisabled;

bool g_bRoundIsLive;

static const int g_iOffColors[] =
{
//	R				G				B				A
	(99 << 24)		+ (135 << 16)	+ (157 << 8)	+ 255,
	(52 << 24)		+ (46 << 16)	+ (46 << 8)		+ 255,
	(173 << 24)		+ (186 << 16)	+ (172 << 8)	+ 255,
	(52 << 24)		+ (70 << 16)	+ (114 << 8)	+ 255,
	(9 << 24)		+ (41 << 16)	+ (138 << 8)	+ 255,
	(68 << 24)		+ (91 << 16)	+ (183 << 8)	+ 255
};

int GetRandomOffColor()
{
	return g_iOffColors[GetRandomInt(0, sizeof(g_iOffColors)-1)];
}

public void OnPluginStart()
{
	g_cvStartDisabled = CreateConVar("l4d_equalise_alarm_start_disabled", "1", "Makes alarmed cars spawn disabled before game goes live.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	g_smCarNameMap = new StringMap();
	g_aAlarmArray = new ArrayList(alarmArray_SIZE);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
}

public void OnMapStart()
{
	g_smCarNameMap.Clear();
	g_aAlarmArray.Clear();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundIsLive = false;
	CreateTimer(0.1, Timer_RoundStartDelay, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_RoundStartDelay(Handle timer)
{
	char sKey[64], sName[128];
	
	int ent = MaxClients+1;
	while ((ent = FindEntityByClassname(ent, "prop_car_alarm")) != INVALID_ENT_REFERENCE)
	{
		GetEntityName(ent, sName, sizeof(sName));
		if (ExtractCarName(sName, "caralarm_car1", sKey, sizeof(sKey)) != 0)
		{
			if (!GameRules_GetProp("m_bInSecondHalfOfRound"))
			{
				int entry = g_aAlarmArray.Length;
				g_smCarNameMap.SetValue(sKey, entry);
				g_aAlarmArray.Resize(entry+1);
				g_aAlarmArray.Set(entry, EntIndexToEntRef(ent), ENTRY_ALARM_CAR);
			}
			else
			{
				int entry = -1;
				if (g_smCarNameMap.GetValue(sKey, entry))
				{
					g_aAlarmArray.Set(entry, EntIndexToEntRef(ent), ENTRY_ALARM_CAR);
				}
			}
			
			//HookSingleEntityOutput(ent, "OnCarAlarmStart", EntO_OnCarAlarmStart);
		}
	}
	
	ent = MaxClients+1;
	while ((ent = FindEntityByClassname(ent, "logic_relay")) != INVALID_ENT_REFERENCE)
	{
		GetEntityName(ent, sName, sizeof(sName));
		
		int entry = -1;
		if ((entry = StrContains(sName, "relay_caralarm_o")) != -1)
		{
			bool type = (sName[entry+16] == 'n');
			
			ExtractCarName(sName,
							type ? "relay_caralarm_on" : "relay_caralarm_off",
							sKey, sizeof(sKey));
			
			if (g_smCarNameMap.GetValue(sKey, entry))
			{
				g_aAlarmArray.Set(entry,
									ent,
									type ? ENTRY_RELAY_ON : ENTRY_RELAY_OFF);
				
				if (!GameRules_GetProp("m_bInSecondHalfOfRound"))
				{
					HookSingleEntityOutput(ent,
											"OnTrigger",
											type ? EntO_AlarmRelayOnTriggered : EntO_AlarmRelayOffTriggered);
				}
			}
		}
	}
	
	return Plugin_Stop;
}

bool bIsStartDisabled = false;
void EntO_AlarmRelayOnTriggered(const char[] output, int caller, int activator, float delay)
{
	int entry = g_aAlarmArray.FindValue(caller, ENTRY_RELAY_ON);
	if (entry == -1)
	{
		// this should not happen...
		char sName[128];
		GetEntityName(caller, sName, sizeof(sName));
		LogError("Fatal: Could not get ENTRY_RELAY_ON for %s", sName);
		return;
	}
	
	g_aAlarmArray.Set(entry, true, ENTRY_START_STATE);
	
	int alarmCar = EntRefToEntIndex(g_aAlarmArray.Get(entry, ENTRY_ALARM_CAR));
	g_aAlarmArray.Set(entry, GetEntityRenderColorEx(alarmCar), ENTRY_COLOR);
	
	if (g_cvStartDisabled.BoolValue)
	{
		int relayOff = g_aAlarmArray.Get(entry, ENTRY_RELAY_OFF);
		bIsStartDisabled = true;
		AcceptEntityInput(relayOff, "Trigger");
		bIsStartDisabled = false;
	}
}

void EntO_AlarmRelayOffTriggered(const char[] output, int caller, int activator, float delay)
{
	if (bIsStartDisabled)
		return;
	
	int entry = g_aAlarmArray.FindValue(caller, ENTRY_RELAY_OFF);
	if (entry == -1)
	{
		// this should not happen...
		char sName[128];
		GetEntityName(caller, sName, sizeof(sName));
		LogError("Fatal: Could not get ENTRY_RELAY_OFF for %s", sName);
		return;
	}
	
	g_aAlarmArray.Set(entry, false, ENTRY_START_STATE);
	
	int alarmCar = EntRefToEntIndex(g_aAlarmArray.Get(entry, ENTRY_ALARM_CAR));
	int color = GetRandomOffColor();
	SetEntityRenderColorEx(alarmCar, color);
	g_aAlarmArray.Set(entry, color, ENTRY_COLOR);
}

/*void EntO_OnCarAlarmStart(const char[] output, int caller, int activator, float delay)
{
	int entry = g_aAlarmArray.FindValue(EntIndexToEntRef(caller), ENTRY_ALARM_CAR);
	if (entry == -1)
	{
		// this should not happen...
		char sName[128];
		GetEntityName(caller, sName, sizeof(sName));
		LogError("Fatal: Could not get ENTRY_ALARM_CAR for %s", sName);
		return;
	}
	
	int relayOff = g_aAlarmArray.Get(entry, ENTRY_RELAY_OFF);
	HookSingleEntityOutput(relayOff, "OnTrigger", EntO_AlarmRelayOffTriggered_PostLive, true);
}

void EntO_AlarmRelayOffTriggered_PostLive(const char[] output, int caller, int activator, float delay)
{
	int entry = g_aAlarmArray.FindValue(caller, ENTRY_RELAY_OFF);
	if (entry == -1)
	{
		// this should not happen...
		char sName[128];
		GetEntityName(caller, sName, sizeof(sName));
		LogError("Fatal: Could not get ENTRY_RELAY_OFF for %s", sName);
		return;
	}
	
	int alarmCar = EntRefToEntIndex(g_aAlarmArray.Get(entry, ENTRY_ALARM_CAR));
	SetEntityRenderColorEx(alarmCar, GetRandomOffColor());
}*/

public void OnRoundIsLive()
{
	g_bRoundIsLive = true;
	EnableCars();
}

void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundIsLive)
	{
		g_bRoundIsLive = true;
		EnableCars();
	}
}

void EnableCars()
{
	for (int i = 0; i < g_aAlarmArray.Length; ++i)
	{
		int alarmCar = EntRefToEntIndex(g_aAlarmArray.Get(i, ENTRY_ALARM_CAR));
		int relayOn = g_aAlarmArray.Get(i, ENTRY_RELAY_ON);
		
		if (g_aAlarmArray.Get(i, ENTRY_START_STATE))
		{
			AcceptEntityInput(relayOn, "Trigger");
			SetEntityRenderColorEx(alarmCar, g_aAlarmArray.Get(i, ENTRY_COLOR));
		}
	}
}

stock void DisableCars()
{
	for (int i = 0; i < g_aAlarmArray.Length; ++i)
	{
		int alarmCar = EntRefToEntIndex(g_aAlarmArray.Get(i, ENTRY_ALARM_CAR));
		int relayOff = g_aAlarmArray.Get(i, ENTRY_RELAY_OFF);
		
		if (g_aAlarmArray.Get(i, ENTRY_START_STATE))
		{
			AcceptEntityInput(relayOff, "Trigger");
			SetEntityRenderColorEx(alarmCar, g_aAlarmArray.Get(i, ENTRY_COLOR));
		}
	}
}

int ExtractCarName(const char[] sName, const char[] sCompare, char[] sBuffer, int iSize)
{
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

void GetEntityName(int entity, char[] buffer, int maxlen)
{
	GetEntPropString(entity, Prop_Data, "m_iName", buffer, maxlen);
}

int GetEntityRenderColorEx(int entity)
{
	int r, g, b, a;
	GetEntityRenderColor(entity, r, g, b, a);
	return (r << 24) + (g << 16) + (b << 8) + a;
}

void SetEntityRenderColorEx(int entity, int color)
{
	int r, g, b, a;
	r = (color & 0xFF000000) >> 24;
	g = (color & 0x00FF0000) >> 16;
	b = (color & 0x0000FF00) >> 8;
	a = (color & 0x000000FF);
	SetEntityRenderColor(entity, r, g, b, a);
}
