#include <sourcemod>
#include <colors>
#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.1"

public Plugin myinfo =
{
    name = "Special Infected Class Announce",
    author = "Tabun, Forgetest",
    description = "Report what SI classes are up when the round starts.",
    version = PLUGIN_VERSION,
    url = "none"
}

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8

#define TEAM_SPECTATOR			1
#define TEAM_SURVIVOR			2
#define TEAM_INFECTED			3

#define MAXSPAWNS               8

static const char g_csSIClassName[][] =
{
    "",
    "Smoker",
    "(Boomer)",
    "Hunter",
    "(Spitter)",
    "Jockey",
    "Charger",
    "",
    ""
};

Handle g_hAddFooterTimer;
bool g_bFooterAdded, g_bMessagePrinted;

public void OnPluginStart()
{
	HookEvent("round_start", view_as<EventHook>(Event_RoundStart), EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_Post);
}

public void Event_RoundStart()
{
	g_bFooterAdded = false;
	g_bMessagePrinted = false;
	
	if( GetFeatureStatus(FeatureType_Native, "AddStringToReadyFooter") == FeatureStatus_Available )
	{
		ToggleEvent(true);
		g_hAddFooterTimer = CreateTimer(7.0, UpdateReadyUpFooter, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		ToggleEvent(false);
	}
}

void ToggleEvent(bool hook)
{
	static bool hooked = false;
	if (!hooked && hook)
	{
		HookEvent("player_team", Event_PlayerTeam);
	}
	else if (hooked && !hook)
	{
		UnhookEvent("player_team", Event_PlayerTeam);
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bFooterAdded) return;
	
	if (g_hAddFooterTimer != null) return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client) return;
	
	if (event.GetInt("team") == TEAM_INFECTED)
	{
		g_hAddFooterTimer = CreateTimer(1.0, UpdateReadyUpFooter, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action UpdateReadyUpFooter(Handle timer)
{
	g_hAddFooterTimer = null;
	
	if (!IsInfectedTeamFullAlive() || g_bFooterAdded)
		return;
	
	char msg[64];
	if (ProcessSIString(msg, sizeof(msg), true))
		g_bFooterAdded = (AddStringToReadyFooter(msg) != -1);
}

public void OnRoundIsLive()
{
	// announce SI classes up now
	char msg[128];
	if (ProcessSIString(msg, sizeof(msg)))
	{
		AnnounceSIClasses(msg);
		g_bMessagePrinted = true;
	}
	ToggleEvent(false);
}

public Action Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{
	// if no readyup, use this as the starting event
	if (!g_bMessagePrinted) {
		char msg[128];
		if (ProcessSIString(msg, sizeof(msg)))
			AnnounceSIClasses(msg);
			
		// no matter printed or not, we won't bother the game since survivor leaves saferoom.
		g_bMessagePrinted = true;
	}
}

#define COLOR_PARAM "%s{red}%s{default}"
#define NORMA_PARAM "%s%s"

bool ProcessSIString(char[] msg, int maxlength, bool footer = false)
{
	// get currently active SI classes
	int iSpawns;
	int iSpawnClass[MAXSPAWNS];
	
	for (int i = 1; i <= MaxClients && iSpawns < MAXSPAWNS; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i)) { continue; }
		
		iSpawnClass[iSpawns] = GetEntProp(i, Prop_Send, "m_zombieClass");
		
		if (iSpawnClass[iSpawns] != ZC_WITCH && iSpawnClass[iSpawns] != ZC_TANK)
			iSpawns++;
	}
	
	// found nothing :/
	if (!iSpawns) {
		return false;
	}
    
	strcopy(msg, maxlength, footer ? "SI: " : "Special Infected: ");
	
	// format classes, according to amount of spawns found
	for (int count = 0; count < iSpawns; count++) {
		if (count) StrCat(msg, maxlength, ", ");
		
		Format(	msg,
				maxlength,
				(footer ? NORMA_PARAM : COLOR_PARAM),
				msg,
				g_csSIClassName[iSpawnClass[count]]
		);
	}
	
	return true;
}

void AnnounceSIClasses(const char[] Message)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) == TEAM_INFECTED || (IsFakeClient(i) && !IsClientSourceTV(i))) { continue; }

		CPrintToChat(i, Message);
		//PrintHintText(i, Message2);
    }
}

stock bool IsInfectedTeamFullAlive()
{
	static ConVar cMaxZombies;
	if (!cMaxZombies) cMaxZombies = FindConVar("z_max_player_zombies");
	
	int players = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i)) players++;
	}
	return players >= cMaxZombies.IntValue;
}