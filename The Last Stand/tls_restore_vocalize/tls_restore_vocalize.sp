#include <sourcemod>
#include <sdktools>
#include <sceneprocessor>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2.11"

public Plugin myinfo = 
{
	name = "[L4D2] Restore Blocked Vocalize",
	author = "Forgetest",
	description = "Annoyments outside TLS are back.",
	version = PLUGIN_VERSION,
	url = "you"
};


// ============================
//  Vocalize Enumeration
// ============================

#define NULL_VOCALIZE view_as<Vocalize>(-1)
enum Vocalize
{
	Vocal_PlayerLaugh,
	Vocal_PlayerTaunt,
	Vocal_Playerdeath
};

static const char g_szVocalizeNames[Vocalize][] = 
{
	"PlayerLaugh", "PlayerTaunt", "Playerdeath"
};

#define SC_NONE view_as<SurvivorCharacter>(-1)
enum SurvivorCharacter {
    SC_COACH=0,
    SC_NICK,
    SC_ROCHELLE,
    SC_ELLIS,
    SC_LOUIS,
    SC_ZOEY,
    SC_BILL,
    SC_FRANCIS
};


// ============================
//  Voices
// ============================
#define MAX_NICK_LAUGH 17
#define MAX_NICK_TAUNT 9
#define MAX_NICK_SCREAM 7

#define MAX_ROCHELLE_LAUGH 17
#define MAX_ROCHELLE_TAUNT 8
#define MAX_ROCHELLE_SCREAM 2

#define MAX_COACH_LAUGH 23
#define MAX_COACH_TAUNT 8
#define MAX_COACH_SCREAM 9

#define MAX_ELLIS_LAUGH 19
#define MAX_ELLIS_TAUNT 8
#define MAX_ELLIS_SCREAM 6

#define MAX_BILL_LAUGH 14
#define MAX_BILL_TAUNT 5
#define MAX_BILL_SCREAM 8

#define MAX_ZOEY_LAUGH 21
#define MAX_ZOEY_TAUNT 16
#define MAX_ZOEY_SCREAM 11

#define MAX_LOUIS_LAUGH 21
#define MAX_LOUIS_TAUNT 10
#define MAX_LOUIS_SCREAM 10

#define MAX_FRANCIS_LAUGH 15
#define MAX_FRANCIS_TAUNT 10
#define MAX_FRANCIS_SCREAM 10

static const int g_iMaxVoices[Vocalize][SurvivorCharacter] = 
{
	{
		MAX_COACH_LAUGH,	MAX_NICK_LAUGH,		MAX_ROCHELLE_LAUGH,		MAX_ELLIS_LAUGH,
		MAX_LOUIS_LAUGH,	MAX_ZOEY_LAUGH,		MAX_BILL_LAUGH,			MAX_FRANCIS_LAUGH
	},
	
	{
		MAX_COACH_TAUNT,	MAX_NICK_TAUNT,		MAX_ROCHELLE_TAUNT,		MAX_ELLIS_TAUNT,
		MAX_LOUIS_TAUNT,	MAX_ZOEY_TAUNT,		MAX_BILL_TAUNT,			MAX_FRANCIS_TAUNT
	},
	
	{
		MAX_COACH_SCREAM,	MAX_NICK_SCREAM,	MAX_ROCHELLE_SCREAM,	MAX_ELLIS_SCREAM,
		MAX_LOUIS_SCREAM,	MAX_ZOEY_SCREAM,	MAX_BILL_SCREAM,		MAX_FRANCIS_SCREAM
	}
};

static const char g_szNickLaughs[][] =
{
	"gambler/laughter01",
	"gambler/laughter02",
	"gambler/laughter03",
	"gambler/laughter04",
	"gambler/laughter05",
	"gambler/laughter06",
	"gambler/laughter07",
	"gambler/laughter08",
	"gambler/laughter09",
	"gambler/laughter10",
	"gambler/laughter11",
	"gambler/laughter12",
	"gambler/laughter13",
	"gambler/laughter14",
	"gambler/laughter15",
	"gambler/laughter16",
	"gambler/laughter17"		// 17
};

static const char g_szNickTaunts[][] =
{
	"gambler/taunt01",
	"gambler/taunt02",
	"gambler/taunt03",
	"gambler/taunt04",
	"gambler/taunt05",
	"gambler/taunt06",
	"gambler/taunt07",
	"gambler/taunt08",
	"gambler/taunt09"		// 9
};

static const char g_szNickScreams[][] =
{
	"gambler/deathscream01",
	"gambler/deathscream02",
	"gambler/deathscream03",
	"gambler/deathscream04",
	"gambler/deathscream05",
	"gambler/deathscream06",
	"gambler/deathscream07"	// 7
};

static const char g_szRochelleLaughs[][] =
{
	"producer/laughter01",
	"producer/laughter02",
	"producer/laughter03",
	"producer/laughter04",
	"producer/laughter05",
	"producer/laughter06",
	"producer/laughter07",
	"producer/laughter08",
	"producer/laughter09",
	"producer/laughter10",
	"producer/laughter11",
	"producer/laughter12",
	"producer/laughter13",
	"producer/laughter14",
	"producer/laughter15",
	"producer/laughter16",
	"producer/laughter17"	// 17
};

static const char g_szRochelleTaunts[][] =
{
	"producer/taunt01",
	"producer/taunt02",
	"producer/taunt03",
	"producer/taunt04",
	"producer/taunt05",
	"producer/taunt06",
	"producer/taunt07",
	"producer/taunt08"		// 8
};

static const char g_szRochelleScreams[][] =
{
	"producer/deathscream01",
	"producer/deathscream02"	// 2
};

static const char g_szCoachLaughs[][] =
{
	"coach/laughter01",
	"coach/laughter02",
	"coach/laughter03",
	"coach/laughter04",
	"coach/laughter05",
	"coach/laughter06",
	"coach/laughter07",
	"coach/laughter08",
	"coach/laughter09",
	"coach/laughter10",
	"coach/laughter11",
	"coach/laughter12",
	"coach/laughter13",
	"coach/laughter14",
	"coach/laughter15",
	"coach/laughter16",
	"coach/laughter17",
	"coach/laughter18",
	"coach/laughter19",
	"coach/laughter20",
	"coach/laughter21",
	"coach/laughter22",
	"coach/laughter23"		// 23
};

static const char g_szCoachTaunts[][] =
{
	"coach/taunt01",
	"coach/taunt02",
	"coach/taunt03",
	"coach/taunt04",
	"coach/taunt05",
	"coach/taunt06",
	"coach/taunt07",
	"coach/taunt08"			// 8
};

static const char g_szCoachScreams[][] =
{
	"coach/deathscream01",
	"coach/deathscream02",
	"coach/deathscream03",
	"coach/deathscream04",
	"coach/deathscream05",
	"coach/deathscream06",
	"coach/deathscream07",
	"coach/deathscream08",
	"coach/deathscream09"	// 9
};


static const char g_szEllisLaughs[][] =
{
	"mechanic/laughter01",
	"mechanic/laughter02",
	"mechanic/laughter03",
	"mechanic/laughter04",
	"mechanic/laughter05",
	"mechanic/laughter06",
	"mechanic/laughter07",
	"mechanic/laughter08",
	"mechanic/laughter09",
	"mechanic/laughter10",
	"mechanic/laughter11",
	"mechanic/laughter12",
	"mechanic/laughter13",
	"mechanic/laughter13a",
	"mechanic/laughter13b",
	"mechanic/laughter13c",
	"mechanic/laughter13d",
	"mechanic/laughter13e",
	"mechanic/laughter14",	// 19
};

static const char g_szEllisTaunts[][] =
{
	"mechanic/taunt01",
	"mechanic/taunt02",
	"mechanic/taunt03",
	"mechanic/taunt04",
	"mechanic/taunt05",
	"mechanic/taunt06",
	"mechanic/taunt07",
	"mechanic/taunt08"		// 8
};

static const char g_szEllisScreams[][] =
{
	"mechanic/deathscream01",
	"mechanic/deathscream02",
	"mechanic/deathscream03",
	"mechanic/deathscream04",
	"mechanic/deathscream05",
	"mechanic/deathscream06"	// 6
};


static const char g_szBillLaughs[][] =
{
	"namvet/laughter01",
	"namvet/laughter02",
	"namvet/laughter03",
	"namvet/laughter04",
	"namvet/laughter05",
	"namvet/laughter06",
	"namvet/laughter07",
	"namvet/laughter08",
	"namvet/laughter09",
	"namvet/laughter10",
	"namvet/laughter11",
	"namvet/laughter12",
	"namvet/laughter13",
	"namvet/laughter14"		// 14
};

static const char g_szBillTaunts[][] =
{
	"namvet/taunt01",
	"namvet/taunt02",
	"namvet/taunt07",
	"namvet/taunt08",
	"namvet/taunt09"			// 5
};

static const char g_szBillScreams[][] =
{
	"namvet/deathscream01",
	"namvet/deathscream02",
	"namvet/deathscream03",
	"namvet/deathscream04",
	"namvet/deathscream05",
	"namvet/deathscream06",
	"namvet/deathscream07",
	"namvet/deathscream08"	// 8
};


static const char g_szZoeyLaughs[][] =
{
	"teengirl/laughter01",
	"teengirl/laughter02",
	"teengirl/laughter03",
	"teengirl/laughter04",
	"teengirl/laughter05",
	"teengirl/laughter06",
	"teengirl/laughter07",
	"teengirl/laughter08",
	"teengirl/laughter09",
	"teengirl/laughter10",
	"teengirl/laughter11",
	"teengirl/laughter12",
	"teengirl/laughter13",
	"teengirl/laughter14",
	"teengirl/laughter15",
	"teengirl/laughter16",
	"teengirl/laughter17",
	"teengirl/laughter18",
	"teengirl/laughter19",
	"teengirl/laughter20",
	"teengirl/laughter21"	// 21
};

static const char g_szZoeyTaunts[][] =
{
	"teengirl/taunt02",
	"teengirl/taunt13",
	"teengirl/taunt18",
	"teengirl/taunt19",
	"teengirl/taunt20",
	"teengirl/taunt21",
	"teengirl/taunt24",
	"teengirl/taunt25",
	"teengirl/taunt26",
	"teengirl/taunt28",
	"teengirl/taunt29",
	"teengirl/taunt30",
	"teengirl/taunt31",
	"teengirl/taunt34",
	"teengirl/taunt35",
	"teengirl/taunt39"		// 16
};

static const char g_szZoeyScreams[][] =
{
	"teengirl/deathscream01",
	"teengirl/deathscream02",
	"teengirl/deathscream03",
	"teengirl/deathscream04",
	"teengirl/deathscream05",
	"teengirl/deathscream06",
	"teengirl/deathscream07",
	"teengirl/deathscream08",
	"teengirl/deathscream09",
	"teengirl/deathscream10",
	"teengirl/deathscream11"	// 11
};


static const char g_szLouisLaughs[][] =
{
	"manager/laughter01",
	"manager/laughter02",
	"manager/laughter03",
	"manager/laughter04",
	"manager/laughter05",
	"manager/laughter06",
	"manager/laughter07",
	"manager/laughter08",
	"manager/laughter09",
	"manager/laughter10",
	"manager/laughter11",
	"manager/laughter12",
	"manager/laughter13",
	"manager/laughter14",
	"manager/laughter15",
	"manager/laughter16",
	"manager/laughter17",
	"manager/laughter18",
	"manager/laughter19",
	"manager/laughter20",
	"manager/laughter21"		// 21
};

static const char g_szLouisTaunts[][] =
{
	"manager/taunt01",
	"manager/taunt02",
	"manager/taunt03",
	"manager/taunt04",
	"manager/taunt05",
	"manager/taunt06",
	"manager/taunt07",
	"manager/taunt08",
	"manager/taunt09",
	"manager/taunt10"		// 10
};

static const char g_szLouisScreams[][] =
{
	"manager/deathscream01",
	"manager/deathscream02",
	"manager/deathscream03",
	"manager/deathscream04",
	"manager/deathscream05",
	"manager/deathscream06",
	"manager/deathscream07",
	"manager/deathscream08",
	"manager/deathscream09",
	"manager/deathscream10"	// 10
};


static const char g_szFrancisLaughs[][] =
{
	"biker/laughter01",
	"biker/laughter02",
	"biker/laughter03",
	"biker/laughter04",
	"biker/laughter05",
	"biker/laughter06",
	"biker/laughter07",
	"biker/laughter08",
	"biker/laughter09",
	"biker/laughter10",
	"biker/laughter11",
	"biker/laughter12",
	"biker/laughter13",
	"biker/laughter14",
	"biker/laughter15"		// 15
};

static const char g_szFrancisTaunts[][] =
{
	"biker/taunt01",
	"biker/taunt02",
	"biker/taunt03",
	"biker/taunt04",
	"biker/taunt05",
	"biker/taunt06",
	"biker/taunt07",
	"biker/taunt08",
	"biker/taunt09",
	"biker/taunt10"			// 10
};

static const char g_szFrancisScreams[][] =
{
	"biker/deathscream01",
	"biker/deathscream02",
	"biker/deathscream03",
	"biker/deathscream04",
	"biker/deathscream05",
	"biker/deathscream06",
	"biker/deathscream07",
	"biker/deathscream08",
	"biker/deathscream09",
	"biker/deathscream10"	// 10
};


// ============================
//  Variables
// ============================

bool g_bVersus, g_bMapStarted;


// ============================
//  Forwards
// ============================

public void OnPluginStart()
{
	FindConVar("mp_gamemode").AddChangeHook(OnGamemodeChanged);
}

public void OnMapStart()
{
	g_bMapStarted = true;
	DoPrecache();
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnConfigsExecuted()
{
	CheckVersus();
}


// ============================
//  ConVar Change
// ============================

public void OnGamemodeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CheckVersus();
}


// ============================
//  *IsAllowedGamemode()*
// credit to SilverShot
// ============================

void CheckVersus()
{
	g_bVersus = false;
	
	if (g_bMapStarted)
	{
		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnVersus", OnVersus, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}
	}
}

public void OnVersus(const char[] output, int caller, int activator, float delay)
{
	g_bVersus = true;
}


// ============================
//  Vocalize Handles
// ============================

public Action OnVocalizeCommand(int client, const char[] vocalize, int initiator)
{
	if (!g_bVersus)
		return;
	
	if (!IsSurvivor(client) || !IsPlayerAlive(client))
		return;
	
	int scene = GetSceneFromActor(client);
	
	Vocalize emVocalize = IdentifyVocalize(vocalize);
	if (emVocalize == NULL_VOCALIZE
			|| (emVocalize == Vocal_PlayerTaunt && IsValidScene(scene))) // :D
		return;
		
	if (IsValidScene(scene) && GetSceneInitiator(scene) == SCENE_INITIATOR_WORLD)
		return;
	
	SurvivorCharacter emCharacter = IdentifySurvivor(client);
	if (emCharacter == SC_NONE)
		return;

	char szVoiceFile[PLATFORM_MAX_PATH];
	PickVoice(szVoiceFile, sizeof(szVoiceFile), emVocalize, emCharacter);
	PerformScene(client, g_szVocalizeNames[emVocalize], szVoiceFile);
}


// ============================
//  Vocalize Pick & Formation
// ============================

#define SCENE_FILE_PREFIX "scenes/"
#define SCENE_FILE_SURFIX ".vcd"
#define SOUND_FILE_PREFIX "player/survivor/voice/"
#define SOUND_FILE_SURFIX ".wav"

// FormatScene(char[] buffer, int maxlength, const char[] scene)
#define FormatScene(%0,%1,%2) FormatEx((%0), (%1), "%s%s%s", SCENE_FILE_PREFIX, (%2), SCENE_FILE_SURFIX)
// FormatSound(char[] buffer, int maxlength, const char[] sound)
#define FormatSound(%0,%1,%2) FormatEx((%0), (%1), "%s%s%s", SOUND_FILE_PREFIX, (%2), SOUND_FILE_SURFIX)

void PickVoice(char[] szFile, int maxlength, Vocalize emVocalize, SurvivorCharacter emCharacter)
{
	int max = g_iMaxVoices[emVocalize][emCharacter];
	int rndPick = Math_GetRandomInt(0, max-1);
	
	switch (emVocalize)
	{
		case Vocal_PlayerLaugh:
		{
			switch (emCharacter)
			{
				case SC_NICK:		{FormatScene(szFile, maxlength, g_szNickLaughs[rndPick]);}
				case SC_ROCHELLE:	{FormatScene(szFile, maxlength, g_szRochelleLaughs[rndPick]);}
				case SC_COACH:		{FormatScene(szFile, maxlength, g_szCoachLaughs[rndPick]);}
				case SC_ELLIS:		{FormatScene(szFile, maxlength, g_szEllisLaughs[rndPick]);}
				case SC_BILL:		{FormatScene(szFile, maxlength, g_szBillLaughs[rndPick]);}
				case SC_ZOEY:		{FormatScene(szFile, maxlength, g_szZoeyLaughs[rndPick]);}
				case SC_LOUIS:		{FormatScene(szFile, maxlength, g_szLouisLaughs[rndPick]);}
				case SC_FRANCIS:	{FormatScene(szFile, maxlength, g_szFrancisLaughs[rndPick]);}
			}
		}
		case Vocal_PlayerTaunt:
		{
			switch (emCharacter)
			{
				case SC_NICK:		{FormatScene(szFile, maxlength, g_szNickTaunts[rndPick]);}
				case SC_ROCHELLE:	{FormatScene(szFile, maxlength, g_szRochelleTaunts[rndPick]);}
				case SC_COACH:		{FormatScene(szFile, maxlength, g_szCoachTaunts[rndPick]);}
				case SC_ELLIS:		{FormatScene(szFile, maxlength, g_szEllisTaunts[rndPick]);}
				case SC_BILL:		{FormatScene(szFile, maxlength, g_szBillTaunts[rndPick]);}
				case SC_ZOEY:		{FormatScene(szFile, maxlength, g_szZoeyTaunts[rndPick]);}
				case SC_LOUIS:		{FormatScene(szFile, maxlength, g_szLouisTaunts[rndPick]);}
				case SC_FRANCIS:	{FormatScene(szFile, maxlength, g_szFrancisTaunts[rndPick]);}
			}
		}
		case Vocal_Playerdeath:
		{
			switch (emCharacter)
			{
				case SC_NICK:		{FormatScene(szFile, maxlength, g_szNickScreams[rndPick]);}
				case SC_ROCHELLE:	{FormatScene(szFile, maxlength, g_szRochelleScreams[rndPick]);}
				case SC_COACH:		{FormatScene(szFile, maxlength, g_szCoachScreams[rndPick]);}
				case SC_ELLIS:		{FormatScene(szFile, maxlength, g_szEllisScreams[rndPick]);}
				case SC_BILL:		{FormatScene(szFile, maxlength, g_szBillScreams[rndPick]);}
				case SC_ZOEY:		{FormatScene(szFile, maxlength, g_szZoeyScreams[rndPick]);}
				case SC_LOUIS:		{FormatScene(szFile, maxlength, g_szLouisScreams[rndPick]);}
				case SC_FRANCIS:	{FormatScene(szFile, maxlength, g_szFrancisScreams[rndPick]);}
			}
		}
	}
}

Vocalize IdentifyVocalize(const char[] szVocalize)
{
	for (Vocalize i; i < Vocalize; i++)
		if (strcmp(szVocalize, g_szVocalizeNames[i]) == 0)
			return i;
			
	return NULL_VOCALIZE;
}


// ============================
//  Precaches
// ============================

void DoPrecache()
{
	bool save = LockStringTables(false);
	
	int i;
	for (i = 0; i < MAX_NICK_LAUGH; ++i)		PrecacheVocalize(g_szNickLaughs[i]);
	for (i = 0; i < MAX_NICK_TAUNT; ++i)		PrecacheVocalize(g_szNickTaunts[i]);
	for (i = 0; i < MAX_NICK_SCREAM; ++i)		PrecacheVocalize(g_szNickScreams[i]);
	for (i = 0; i < MAX_ROCHELLE_LAUGH; ++i)	PrecacheVocalize(g_szRochelleLaughs[i]);
	for (i = 0; i < MAX_ROCHELLE_TAUNT; ++i)	PrecacheVocalize(g_szRochelleTaunts[i]);
	for (i = 0; i < MAX_ROCHELLE_SCREAM; ++i)	PrecacheVocalize(g_szRochelleScreams[i]);
	for (i = 0; i < MAX_COACH_LAUGH; ++i)		PrecacheVocalize(g_szCoachLaughs[i]);
	for (i = 0; i < MAX_COACH_TAUNT; ++i)		PrecacheVocalize(g_szCoachTaunts[i]);
	for (i = 0; i < MAX_COACH_SCREAM; ++i)		PrecacheVocalize(g_szCoachScreams[i]);
	for (i = 0; i < MAX_ELLIS_LAUGH; ++i)		PrecacheVocalize(g_szEllisLaughs[i]);
	for (i = 0; i < MAX_ELLIS_TAUNT; ++i)		PrecacheVocalize(g_szEllisTaunts[i]);
	for (i = 0; i < MAX_ELLIS_SCREAM; ++i)		PrecacheVocalize(g_szEllisScreams[i]);
	for (i = 0; i < MAX_BILL_LAUGH; ++i)		PrecacheVocalize(g_szBillLaughs[i]);
	for (i = 0; i < MAX_BILL_TAUNT; ++i)		PrecacheVocalize(g_szBillTaunts[i]);
	for (i = 0; i < MAX_BILL_SCREAM; ++i)		PrecacheVocalize(g_szBillScreams[i]);
	for (i = 0; i < MAX_ZOEY_LAUGH; ++i)		PrecacheVocalize(g_szZoeyLaughs[i]);
	for (i = 0; i < MAX_ZOEY_TAUNT; ++i)		PrecacheVocalize(g_szZoeyTaunts[i]);
	for (i = 0; i < MAX_ZOEY_SCREAM; ++i)		PrecacheVocalize(g_szZoeyScreams[i]);
	for (i = 0; i < MAX_LOUIS_LAUGH; ++i)		PrecacheVocalize(g_szLouisLaughs[i]);
	for (i = 0; i < MAX_LOUIS_TAUNT; ++i)		PrecacheVocalize(g_szLouisTaunts[i]);
	for (i = 0; i < MAX_LOUIS_SCREAM; ++i)		PrecacheVocalize(g_szLouisScreams[i]);
	for (i = 0; i < MAX_FRANCIS_LAUGH; ++i)		PrecacheVocalize(g_szFrancisLaughs[i]);
	for (i = 0; i < MAX_FRANCIS_TAUNT; ++i)		PrecacheVocalize(g_szFrancisTaunts[i]);
	for (i = 0; i < MAX_FRANCIS_SCREAM; ++i)	PrecacheVocalize(g_szFrancisScreams[i]);
	
	LockStringTables(save);
}

void PrecacheVocalize(const char[] vocalize)
{
	char buffer[PLATFORM_MAX_PATH];
	
	FormatScene(buffer, sizeof(buffer), vocalize);
	AddSceneToTable(buffer);
	
	FormatSound(buffer, sizeof(buffer), vocalize);
	PrecacheSound(buffer, true);
}

void AddSceneToTable(const char[] scene)
{
	static int sceneTable = INVALID_STRING_TABLE;

	if (sceneTable == INVALID_STRING_TABLE)
	{
		sceneTable = FindStringTable("Scenes");
		if (sceneTable == INVALID_STRING_TABLE)
		{
			SetFailState("[VocalRestore] Unable to find string table \"Scenes\" when precaching.");
		}
	}
	
	if (FindStringIndex(sceneTable, scene) == INVALID_STRING_INDEX)
	{
		if (GetStringTableNumStrings(sceneTable) < GetStringTableMaxStrings(sceneTable))
		{
			AddToStringTable(sceneTable, scene);
		}
		else
		{
			LogError("[VocalRestore] Unable to precache scene (%s) due to exceeding string table limits.", scene);
		}
	}
}


// ============================
//  Stocks
// ============================

/**
 * Initializes internal structure necessary for IdentifySurvivor() function
 * @remark It is recommended that you run this function on plugin start, but not necessary
 *
 * @noreturn
 */
stock void InitSurvivorModelTrie(StringMap& hTrie)
{
	hTrie = new StringMap();
	hTrie.SetValue("models/survivors/survivor_coach.mdl", SC_COACH);
	hTrie.SetValue("models/survivors/survivor_gambler.mdl", SC_NICK);
	hTrie.SetValue("models/survivors/survivor_producer.mdl", SC_ROCHELLE);
	hTrie.SetValue("models/survivors/survivor_mechanic.mdl", SC_ELLIS);
	hTrie.SetValue("models/survivors/survivor_manager.mdl", SC_LOUIS);
	hTrie.SetValue("models/survivors/survivor_teenangst.mdl", SC_ZOEY);
	hTrie.SetValue("models/survivors/survivor_namvet.mdl", SC_BILL);
	hTrie.SetValue("models/survivors/survivor_biker.mdl", SC_FRANCIS);
}

/**
 * Identifies a client's survivor character based on their current model.
 * @remark SC_NONE on errors
 *
 * @param client                Survivor client to identify
 * @return SurvivorCharacter    index identifying the survivor, or SC_NONE if not identified.
 */
stock SurvivorCharacter IdentifySurvivor(int client)
{
	static char clientModel[42];
	GetClientModel(client, clientModel, sizeof(clientModel));
	return ClientModelToSC(clientModel);
}

/**
 * Identifies the survivor character corresponding to a player model.
 * @remark SC_NONE on errors, uses SurvivorModelTrie
 *
 * @param model                 Player model to identify
 * @return SurvivorCharacter    index identifying the model, or SC_NONE if not identified.
 */
stock SurvivorCharacter ClientModelToSC(const char[] model)
{
	static StringMap hSurvivorModelsTrie;
	if (hSurvivorModelsTrie == null)
	{
		InitSurvivorModelTrie(hSurvivorModelsTrie);
	}
	SurvivorCharacter sc;
	if (hSurvivorModelsTrie.GetValue(model, sc))
	{
		return sc;
	}
	return SC_NONE;
}

/**
 * Returns true if the player is currently on the survivor team. 
 *
 * @param client client ID
 * @return bool
 */
stock bool IsSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2;
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
// Simple modification against sequently giving equal numbers.
stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();
	int range = max - min + 1;
	int pick = 0;
	
	if (random)
	{
		pick = random % range;
	}
	
	static int prev = -1;
	prev = (prev == pick ? ++pick : pick);
	
	return (pick > range ? (pick - range) : pick) + min; // => pick % range + min
}
