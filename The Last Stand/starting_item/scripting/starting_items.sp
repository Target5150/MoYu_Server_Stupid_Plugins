#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_functions>
#undef REQUIRE_PLUGIN
#include <readyup>

#define MAX_ITEM_STRING_LEN 64

ConVar
	g_hCvarItemType = null;

bool
	g_bItemDistributed = false;

public Plugin myinfo =
{
	name = "Starting Items",
	author = "CircleSquared, Jacob, A1m`, Forgetest",
	description = "Gives health items and throwables to survivors at the start of each round",
	version = "3.1.1",
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart()
{
	g_hCvarItemType = CreateConVar("starting_item_list", \
		"health,pain_pills,first_aid_kit,smg_silenced,katana", \
		"Item names to give on leaving the saferoom (via \"give\" command, separated by \",\")\n" \
	...	"NOTE: Generally supported melees are limited, unsupported ones won't spawned. A list of them can be found in \"missions.txt\"." \
	);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
}

public void OnRoundIsLive()
{
	if (!g_bItemDistributed)
	{
		g_bItemDistributed = true;
		DetermineItems();
	}
}

void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	g_bItemDistributed = false;
}

void Event_PlayerLeftStartArea(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	OnRoundIsLive();
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
	
	char sBuffer[MAX_ITEM_STRING_LEN];
	ArrayList arrayItemString = new ArrayList(ByteCountToCells(MAX_ITEM_STRING_LEN));
	
	for ( int i = 0, j = 0;
			(j = FindCharInString(sItemString[i], ',') + 1) != 0;
			i += j
	) {
		if (j > sizeof(sBuffer)) { // overflow
			ThrowError("Could not hold value of \"%s\" containing invalid string.", sItemString);
		}
		
		strcopy(sBuffer, j/* C strncpy */, sItemString[i]);
		sBuffer[j] = '\0';
		
		arrayItemString.PushString(sBuffer);
	}
	
	GiveStartingItems(arrayItemString);

	delete arrayItemString;
}

void GiveStartingItems(ArrayList arrayItemString)
{
	int maxlength = arrayItemString.BlockSize;
	char[] sBuffer = new char[maxlength];
	int iSize = arrayItemString.Length;

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			for (int j = 0; j < iSize; j++) {
				arrayItemString.GetString(j, sBuffer, maxlength);
				GivePlayerWeaponByName(i, sBuffer);
			}
		}
	}
}

void GivePlayerWeaponByName(int iClient, const char[] sWeaponName)
{
	// NOTE:
	// Campaigns have customized supported melees configured by "meleeweapons",
	// if trying to give unsupported melees, they won't spawn.
	if (GivePlayerItem(iClient, sWeaponName) == -1) // Fixed only in the latest version of sourcemod 1.11
	{
		LogMessage("Attempt to give invalid item (%s)", sWeaponName);
	}
}
