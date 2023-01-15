#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2util>
#include <left4dhooks>
#include <colors>

public Plugin myinfo =
{
	name = "Player Management Plugin",
	author = "CanadaRox, Forgetest",
	description = "Player management!  Swap players/teams and spectate!",
	version = "8.0",
	url = ""
};

#include "playermanagement/jointeam.inc"
#include "playermanagement/spectate.inc"
#include "playermanagement/swapteam.inc"

#define TRANSLATION_FILE "playermanagement.phrases"

ConVar 
	survivor_limit,
	z_max_player_zombies;

public void OnPluginStart()
{
	LoadPluginTranslations();
	LoadTranslations("common.phrases");

	survivor_limit = FindConVar("survivor_limit");
	survivor_limit.AddChangeHook(survivor_limitChanged);

	z_max_player_zombies = FindConVar("z_max_player_zombies");
	
	InitJoinTeam();
	InitSpectate();
	InitSwapTeam();
	
	RegAdminCmd("sm_fixbots", FixBots_Cmd, ADMFLAG_BAN, "sm_fixbots - Spawns survivor bots to match survivor_limit");
	
	HookEvent("round_start", Event_RoundStart);
}

Action FixBots_Cmd(int client, int args)
{
	FixBotCount();
	CPrintToChatAll("[SM] %N is attempting to fix bot counts", client);
	
	return Plugin_Handled;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (GetHumanCount()) FixBotCount();
}

void survivor_limitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (GetHumanCount()) FixBotCount();
}

bool ChangeClientTeamEx(int client, int team, bool force)
{
	int currentTeam = GetClientTeam(client);
	if (currentTeam == team)
		return true;

	else if (!force && GetTeamHumanCount(team) == GetTeamMaxHumans(team))
		return false;

	if (currentTeam == L4D2Team_Infected && GetInfectedClass(client) != L4D2Infected_Tank)
	{
		if (IsPlayerAlive(client) && !IsInfectedGhost(client))
			ForcePlayerSuicide(client);
	}
	
	if (team != L4D2Team_Survivor)
	{
		ChangeClientTeam(client, team);
		return true;
	}

	else
	{
		int bot = FindSurvivorBot();
		if (bot > 0)
		{
			int flags = GetCommandFlags("sb_takecontrol");
			SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
			FakeClientCommand(client, "sb_takecontrol");
			SetCommandFlags("sb_takecontrol", flags);
			return true;
		}
	}
	return false;
}

int GetTeamHumanCount(int team)
{
	int humans = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == team)
		{
			humans++;
		}
	}
	
	return humans;
}

int GetHumanCount()
{
	int humans = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			humans++;
		}
	}
	
	return humans;
}

int GetTeamMaxHumans(int team)
{
	if (team == L4D2Team_Survivor)
	{
		return survivor_limit.IntValue;
	}
	else if (team == L4D2Team_Infected)
	{
		return z_max_player_zombies.IntValue;
	}
	return MaxClients;
}

/* return -1 if no bot found, clientid otherwise */
int FindSurvivorBot(int startIndex = -1)
{
	int client = startIndex > 0 ? (startIndex+1) : 1;
	
	for (; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == L4D2Team_Survivor)
		{
			return client;
		}
	}
	return -1;
}

int FindAliveSurvivorBot()
{
	int bot = -1;
	while ((bot = FindSurvivorBot(bot)) != -1)
	{
		if (IsPlayerAlive(bot))
			break;
	}
	
	return bot;
}

void AddSurvivorBot()
{
	ServerCommand("sb_add");
}

void FixBotCount()
{
	int survivor_count = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == L4D2Team_Survivor)
		{
			survivor_count++;
		}
	}
	int limit = survivor_limit.IntValue;
	if (survivor_count < limit)
	{
		for (; survivor_count < limit; survivor_count++)
		{
			AddSurvivorBot();
		}
	}
	else if (survivor_count > limit)
	{
		for (int client = 1; client <= MaxClients && survivor_count > limit; client++)
		{
			if(IsClientInGame(client) && GetClientTeam(client) == L4D2Team_Survivor)
			{
				if (IsFakeClient(client))
				{
					survivor_count--;
					KickClient(client);
				}
			}
		}
	}
}

void LoadPluginTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/" ... TRANSLATION_FILE ... ".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translations \"" ... TRANSLATION_FILE ... "\"");
	}
	LoadTranslations(TRANSLATION_FILE);
}
