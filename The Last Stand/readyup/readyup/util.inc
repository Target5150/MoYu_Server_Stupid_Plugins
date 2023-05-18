#if defined _readyup_util_included
 #endinput
#endif
#define _readyup_util_included

#pragma semicolon 1
#pragma newdecls required

#include "readyup/player.inc"

void LoadPluginTranslations(const char[] file)
{
	char sPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/%s.txt", file);
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation file \"%s.txt\"", file);
	}
	LoadTranslations(file);
}

stock void String_ToLower(char[] str, const int MaxSize)
{
	int iSize = strlen(str); //Сounts string length to zero terminator

	for (int i = 0; i < iSize && i < MaxSize; i++) { //more security, so that the cycle is not endless
		if (IsCharUpper(str[i])) {
			str[i] = CharToLower(str[i]);
		}
	}

	str[iSize] = '\0';
}

int GetDifficulty()
{
	char sDifficulty[11];
	GetDifficultyString(sDifficulty, sizeof(sDifficulty));
	
	for (int i = 0; i < Difficulty_SIZE; ++i)
	{
		if (strcmp(sDifficulty, sDifficultyStrings[i]) == 0)
		{
			return i;
		}
	}
	
	return Difficulty_Normal;
}

void GetDifficultyString(char[] sDifficulty, int maxlength)
{
	static ConVar z_difficulty;
	
	if (!L4D2_HasConfigurableDifficultySetting())
	{
		if (z_difficulty == null)
			z_difficulty = FindConVar("z_difficulty");
		
		z_difficulty.GetString(sDifficulty, maxlength);
		String_ToLower(sDifficulty, maxlength);
		
		if (strcmp("impossible", sDifficulty) == 0)
			strcopy(sDifficulty, maxlength, "expert");
	}
	else
	{
		strcopy(sDifficulty, maxlength, "normal");
	}
}

int GetMaxAllowedPlayers()
{
	int survLimit = survivor_limit.IntValue;
	
	if (L4D_GetGameModeType() & (GAMEMODE_VERSUS|GAMEMODE_SCAVENGE))
	{
		return survLimit + z_max_player_zombies.IntValue;
	}
	
	return survLimit;
}

int GetMaxPlayers()
{
	static ConVar sv_maxplayers = null;
	if (sv_maxplayers == null)
	{
		sv_maxplayers = FindConVar("sv_maxplayers");
	}
	
	if (sv_maxplayers != null)
	{
		return sv_maxplayers.IntValue;
	}
	
	return GetMaxAllowedPlayers();
}

bool IsEmptyString(const char[] str, int maxlength)
{
	int len = strlen(str);
	if (len == 0)
		return true;
	
	if (len > maxlength)
		len = maxlength;
	
	for (int i = 0; i < len; ++i)
	{
		if (IsCharSpace(str[i]))
			continue;
		
		if (str[i] == '\r' || str[i] == '\n')
			continue;
		
		return false;
	}
	
	return true;
}

stock bool IsAnyPlayerLoading()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && (!IsClientInGame(i) || GetClientTeam(i) == L4D2Team_None))
		{
			return true;
		}
	}
	return false;
}

int GetSeriousClientCount(bool inGame = false)
{
	int clients = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (inGame)
		{
			if (IsClientInGame(i) && !IsFakeClient(i)) clients++;
		}
		else
		{
			if (IsClientConnected(i) && !IsFakeClient(i)) clients++;
		}
	}
	
	return clients;
}

void ReturnTeamToSaferoom(int team)
{
	int warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team)
		{
			ReturnPlayerToSaferoom(client, true);
		}
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
}

void SetTeamFrozen(int team, bool freezeStatus)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team)
		{
			SetClientFrozen(client, freezeStatus);
		}
	}
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