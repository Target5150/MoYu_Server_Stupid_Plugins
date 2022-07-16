#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <l4d2util_constants>
#include "l4d2util_weapons.inc"
#undef REQUIRE_PLUGIN
#include <readyup>

#define DEBUG					0
#define ENTITY_NAME_MAX_SIZE	64

ConVar
	g_hCvarItemType = null;

bool
	g_bItemDistributed = false;

public Plugin myinfo =
{
	name = "Starting Items",
	author = "CircleSquared, Jacob, A1m`, Forgetest",
	description = "Gives health items and throwables to survivors at the start of each round",
	version = "3.0",
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart()
{
	g_hCvarItemType = CreateConVar("starting_item_list", \
		"pain_pills,first_aid_kit,smg_silenced,katana", \
		"Item names to give on leaving the saferoom (without \"weapon_\" prefix, separated by \",\")\n" \
	...	"NOTE: Generally supported melees are limited, unsupported ones won't spawned. A list of them can be found in \"missions.txt\"." \
	);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);

	L4D2Weapons_Init();

#if DEBUG
	RegAdminCmd("sm_give_starting_items", Cmd_GiveStartingItems, ADMFLAG_KICK);
#endif
}

void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	g_bItemDistributed = false;
}

public void OnRoundIsLive()
{
	g_bItemDistributed = true;
	DetermineItems();
}

void Event_PlayerLeftStartArea(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bItemDistributed) {
		g_bItemDistributed = true;
		DetermineItems();
	}
}

void DetermineItems()
{
	char sItemString[256];
	g_hCvarItemType.GetString(sItemString, sizeof(sItemString));
	
	int len = strlen(sItemString);
	if (len + 1 > sizeof(sItemString)) { // overflow
		g_hCvarItemType.GetName(sItemString, sizeof(sItemString));
		ThrowError("Could not hold value of \"%s\" because it's too long.", sItemString);
	}
	
	sItemString[len] = ','; // take care of remainder
	sItemString[len+1] = '\0';
	
	StringMap hItemsStringMap = new StringMap();
	char sBuffer[64] = "weapon_"; // items are without prefix
	int wepid;
	
	for ( int i = 0, j = 0;
			(j = FindCharInString(sItemString[i], ',') + 1) != 0;
			i += j
	) {
		if (j > sizeof(sBuffer) - 7) { // overflow
			continue;
		}
		
		strcopy(sBuffer[7], j/* C strncpy */, sItemString[i]);
		sBuffer[7 + j] = '\0';
		
		if ((wepid = WeaponNameToId(sBuffer)) != WEPID_NONE) {
			hItemsStringMap.SetValue(sBuffer, GetSlotFromWeaponId(wepid));
		} else if (MeleeWeaponNameToId(sBuffer[7]) != WEPID_MELEE_NONE) {
			hItemsStringMap.SetValue(sBuffer[7], GetSlotFromWeaponId(WEPID_MELEE));
		}
	}
	
	GiveStartingItems(hItemsStringMap);

	delete hItemsStringMap;
}

void GiveStartingItems(StringMap hItemsStringMap)
{
	if (hItemsStringMap.Size < 1) {
		return;
	}

	char sEntName[ENTITY_NAME_MAX_SIZE];
	StringMapSnapshot hItemsSnapshot = hItemsStringMap.Snapshot();
	int iSlotIndex, iSize = hItemsSnapshot.Length;

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == L4D2Team_Survivor && IsPlayerAlive(i)) {
			for (int j = 0; j < iSize; j++) {
				hItemsSnapshot.GetKey(j, sEntName, sizeof(sEntName));
				hItemsStringMap.GetValue(sEntName, iSlotIndex);
				GivePlayerWeaponByName(i, sEntName);
			}
		}
	}

	delete hItemsSnapshot;
}

void GivePlayerWeaponByName(int iClient, const char[] sWeaponName)
{
	// NOTE:
	// Campaigns have customized supported melees configured by "meleeweapons",
	// if trying to give unsupported melees, they won't spawn.
	GivePlayerItem(iClient, sWeaponName); // Fixed only in the latest version of sourcemod 1.11
}

#if DEBUG
public Action Cmd_GiveStartingItems(int iClient, int iArgs)
{
	DetermineItems();
	PrintToChat(iClient, "DetermineItems()");

	return Plugin_Handled;
}
#endif
