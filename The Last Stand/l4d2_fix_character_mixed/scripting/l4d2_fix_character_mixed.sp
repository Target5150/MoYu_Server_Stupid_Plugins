#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <left4dhooks>
#include <@Forgetest/gamedatawrapper>

#define DEBUG 0
#define PLUGIN_VERSION "1.6"

public Plugin myinfo = 
{
	name = "[L4D2] Fix Mixed Characters",
	author = "Forgetest",
	description = "Prioritize character searching (Team 4 bots) to hopefully fix issues with 8+ survivors.",
	version = PLUGIN_VERSION,
	url = "",
}

static const char g_sSurvivorModels[][] = {
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_manager.mdl"
};

#define MAX_CHARACTERS 8
static const char g_sCharacterNames[MAX_CHARACTERS][] = {
	"Nick",
	"Rochelle",
	"Coach",
	"Ellis",
	"Bill",
	"Zoey",
	"Francis",
	"Louis",
};

int g_iOrigSurvivorSet = 0;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin supports only L4D2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d2_fix_character_mixed");
	delete gd.CreateDetourOrFail("l4d2_fix_character_mixed::CL4D1SurvivorSpawn::InputSpawnSurvivor", DTR_InputSpawnSurvivor, DTR_InputSpawnSurvivor_Post);
	delete gd.CreateDetourOrFail("l4d2_fix_character_mixed::CTerrorPlayer::GetPlayerByCharacter", DTR_GetPlayerByCharacter);
	delete gd.CreateDetourOrFail("l4d2_fix_character_mixed::CTerrorPlayer::GetCharacterDisplayName", DTR_GetCharacterDisplayName);
	// delete gd.CreateDetourOrFail("l4d2_fix_character_mixed::CTerrorPlayer::InputTeleportToSurvivorPosition", DTR_InputTeleportToSurvivorPosition);
	// delete gd.CreateDetourOrFail("l4d2_fix_character_mixed::CTerrorPlayer::InputReleaseFromSurvivorPosition", DTR_InputReleaseFromSurvivorPosition);
	delete gd.CreateDetourOrFail("l4d2_fix_character_mixed::CGlobalEntityList::FindEntityByName", DTR_FindEntityByName);
	delete gd;
}

public void OnMapStart()
{
	g_iOrigSurvivorSet = 0;
}

int GetMissionSurvivorSet()
{
	if (g_iOrigSurvivorSet == 0)
	{
		g_iOrigSurvivorSet = L4D2_GetSurvivorSetMap();
	}
	return g_iOrigSurvivorSet;
}

int GetPlayerSurvivorCharacter(int client)
{
	return GetEntProp(client, Prop_Send, "m_survivorCharacter");
}

MRESReturn DTR_FindEntityByName(DHookReturn hReturn, DHookParam hParams)
{
	if (hParams.IsNull(2))
		return MRES_Ignored;
	
	char name[16];
	hParams.GetString(2, name, sizeof(name));

	if (name[0] != '!')
		return MRES_Ignored;
	
	int testCharacter = GetCharacterFromName(name[1]);
	if (testCharacter == -1)
		return MRES_Ignored;
	
	int i = 1;
	if (!hParams.IsNull(1))
		i = hParams.Get(1) + 1;
	
	DebugMsg("\x04FindEntityByName [L4D%d] (%s) (starting from #%d)", GetMissionSurvivorSet(), g_sCharacterNames[testCharacter], i);
	
	if (testCharacter >= 4 && GetMissionSurvivorSet() == 2)
	{
		// Special care when looking for a L4D1 character on L4D2 maps
		for ( ; i <= MaxClients; ++i )
		{
			// Hand in only Team 4 bots
			if (IsClientInGame(i)
			 && GetClientTeam(i) == 4
			 && IsFakeClient(i)
			 && GetPlayerSurvivorCharacter(i) == testCharacter)
			{
				DebugMsg("\x05> Returning team 4 BOT [%N]", i);
				hReturn.Value = i;
				return MRES_Supercede;
			}
		}
	}
	else
	{
		// General lookup for any character
		for ( ; i <= MaxClients; ++i )
		{
			if (IsClientInGame(i)
			 && GetClientTeam(i) == 2
			 && (GetPlayerSurvivorCharacter(i) == testCharacter || GetPlayerSurvivorCharacter(i) == ConvertCharacter(testCharacter)))
			{
				DebugMsg("\x05> Returning serial-matched character [%N]", i);
				hReturn.Value = i;
				return MRES_Supercede;
			}
		}
	}

	hReturn.Value = -1;
	return MRES_Supercede;
}

bool g_bSpawnSurvivor = false;
MRESReturn DTR_InputSpawnSurvivor(int entity, DHookParam hParams)
{
	DebugMsg("\x04>> InputSpawnSurvivor");
	g_bSpawnSurvivor = true;
	return MRES_Ignored;
}

MRESReturn DTR_InputSpawnSurvivor_Post(int entity, DHookParam hParams)
{
	DebugMsg("\x05<< InputSpawnSurvivor");
	g_bSpawnSurvivor = false;
	return MRES_Ignored;
}

MRESReturn DTR_GetPlayerByCharacter(DHookReturn hReturn, DHookParam hParams)
{
	// Fix "info_l4d1_survivor_spawn" unable to spawn Team 4 bots
	if (g_bSpawnSurvivor && GetMissionSurvivorSet() == 2)
	{
		int character = hParams.Get(1);
		DebugMsg("\x04GetPlayerByCharacter (%d)", character);
		
		if (character < 0 && character >= 8)
			return MRES_Ignored;

		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i)
			&& GetClientTeam(i) == 4
			&& IsFakeClient(i)
			&& GetEntProp(i, Prop_Send, "m_survivorCharacter") == character)
			{
				DebugMsg("\x05> Returning team 4 BOT [%N]", i);
				hReturn.Value = i;
				return MRES_Supercede;
			}
		}

		hReturn.Value = -1;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

bool g_bForceSurvivorPositions = false;
public void L4D_OnForceSurvivorPositions_Pre()
{
	DebugMsg("\x04>> ForceSurvivorPositions");
	g_bForceSurvivorPositions = true;
}

public void L4D_OnForceSurvivorPositions()
{
	DebugMsg("\x05<< ForceSurvivorPositions");
	g_bForceSurvivorPositions = false;
}

MRESReturn DTR_GetCharacterDisplayName(int client, DHookReturn hReturn)
{
	// Workaround character's display name so intro cutscenes can work on non-main characters
	if (g_bForceSurvivorPositions && GetClientTeam(client) == 2)
	{
		int character = GetEntProp(client, Prop_Send, "m_survivorCharacter");
		if (character >= MAX_CHARACTERS)
			character = GetCharacterFromModel(client);
		
		if (character == -1)
			character = 4; // Assume he's bill

		if ((GetMissionSurvivorSet() == 1 && character < 4) || (GetMissionSurvivorSet() == 2 && character >= 4))
			character = ConvertCharacter(character);

		DebugMsg("\x04GetCharacterDisplayName (%N) (%d / %d) [%s]", client, character, GetEntProp(client, Prop_Send, "m_survivorCharacter"), g_sCharacterNames[character]);
		hReturn.SetString(g_sCharacterNames[character]);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

stock int GetCharacterFromModel(int client)
{
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
	
	for (int i = 0; i < sizeof(g_sSurvivorModels); i++)
	{
		if (!strcmp(model, g_sSurvivorModels[i]))
			return i;
	}

	return -1;
}

stock int GetCharacterFromName(const char[] name)
{
	for (int i = 0; i < sizeof(g_sCharacterNames); i++)
	{
		if (!strcmp(name, g_sCharacterNames[i], false))
			return i;
	}

	return -1;
}

int ConvertCharacter(int character)
{
	switch (character)
	{
		case 0: return 4;
		case 1: return 5;
		case 2: return 7;
		case 3: return 6;
		case 4: return 0;
		case 5: return 1;
		case 6: return 3;
		case 7: return 2;
	}
	return character;
}

void DebugMsg(const char[] format, any ...)
{
#if DEBUG
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	PrintToConsoleAll("%s", buffer);
	PrintToServer("%s", buffer);
	LogMessage("%s", buffer);
#else
	#pragma unused format
#endif
}
