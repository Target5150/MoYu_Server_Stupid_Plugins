#include <sourcemod>
#include <sdktools>
#include <sceneprocessor>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>
#undef L4D2UTIL_STOCKS_ONLY

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2.5"

public Plugin myinfo = 
{
	name = "Restore Blocked Vocalize",
	author = "Forgetest",
	description = "Annoyments outside TLS are back.",
	version = PLUGIN_VERSION,
	url = "you"
};

#define NULL_VOCALIZE (view_as<Vocalize>(-1))
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

/**
 *  Voices
 */
#define MAX_NICK_LAUGH 17
#define MAX_NICK_TAUNT 9
#define MAX_NICK_SCREAM 7

#define MAX_ROCHELLE_LAUGH 17
#define MAX_ROCHELLE_TAUNT 8
#define MAX_ROCHELLE_SCREAM 2

#define MAX_COACH_LAUGH 23
#define MAX_COACH_TAUNT 8
#define MAX_COACH_SCREAM 2

#define MAX_ELLIS_LAUGH 19
#define MAX_ELLIS_TAUNT 8
#define MAX_ELLIS_SCREAM 6

#define MAX_BILL_LAUGH 14
#define MAX_BILL_TAUNT 5
#define MAX_BILL_SCREAM 8

#define MAX_ZOEY_LAUGH 21
#define MAX_ZOEY_TAUNT 16
#define MAX_ZOEY_SCREAM 11

#define MAX_LOUIS_LAUGH 19
#define MAX_LOUIS_TAUNT 8
#define MAX_LOUIS_SCREAM 6

#define MAX_FRANCIS_LAUGH 15
#define MAX_FRANCIS_TAUNT 10
#define MAX_FRANCIS_SCREAM 10

static const int g_iMaxVoices[Vocalize][SurvivorCharacter] = 
{
	{
		MAX_NICK_LAUGH, MAX_ROCHELLE_LAUGH, MAX_COACH_LAUGH, MAX_ELLIS_LAUGH,
		MAX_BILL_LAUGH, MAX_ZOEY_LAUGH, MAX_LOUIS_LAUGH, MAX_FRANCIS_LAUGH
	},
	
	{
		MAX_NICK_TAUNT, MAX_ROCHELLE_TAUNT, MAX_COACH_TAUNT, MAX_ELLIS_TAUNT,
		MAX_BILL_TAUNT, MAX_ZOEY_TAUNT, MAX_LOUIS_TAUNT, MAX_FRANCIS_TAUNT
	},
	
	{
		MAX_NICK_SCREAM, MAX_ROCHELLE_SCREAM, MAX_COACH_SCREAM, MAX_ELLIS_SCREAM,
		MAX_BILL_SCREAM, MAX_ZOEY_SCREAM, MAX_LOUIS_SCREAM, MAX_FRANCIS_SCREAM
	}
};

static const char g_szNickLaughs[][] =
{
	"scenes/gambler/laughter01.vcd",
	"scenes/gambler/laughter02.vcd",
	"scenes/gambler/laughter03.vcd",
	"scenes/gambler/laughter04.vcd",
	"scenes/gambler/laughter05.vcd",
	"scenes/gambler/laughter06.vcd",
	"scenes/gambler/laughter07.vcd",
	"scenes/gambler/laughter08.vcd",
	"scenes/gambler/laughter09.vcd",
	"scenes/gambler/laughter10.vcd",
	"scenes/gambler/laughter11.vcd",
	"scenes/gambler/laughter12.vcd",
	"scenes/gambler/laughter13.vcd",
	"scenes/gambler/laughter14.vcd",
	"scenes/gambler/laughter15.vcd",
	"scenes/gambler/laughter16.vcd",
	"scenes/gambler/laughter17.vcd"
};

static const char g_szNickTaunts[][] =
{
	"scenes/gambler/taunt01.vcd",
	"scenes/gambler/taunt02.vcd",
	"scenes/gambler/taunt03.vcd",
	"scenes/gambler/taunt04.vcd",
	"scenes/gambler/taunt05.vcd",
	"scenes/gambler/taunt06.vcd",
	"scenes/gambler/taunt07.vcd",
	"scenes/gambler/taunt08.vcd",
	"scenes/gambler/taunt09.vcd"
};

static const char g_szNickScreams[][] =
{
	"scenes/gambler/deathscream01.vcd",
	"scenes/gambler/deathscream02.vcd",
	"scenes/gambler/deathscream03.vcd",
	"scenes/gambler/deathscream04.vcd",
	"scenes/gambler/deathscream05.vcd",
	"scenes/gambler/deathscream06.vcd",
	"scenes/gambler/deathscream07.vcd"
};


static const char g_szRochelleLaughs[][] =
{
	"scenes/producer/laughter01.vcd",
	"scenes/producer/laughter02.vcd",
	"scenes/producer/laughter03.vcd",
	"scenes/producer/laughter04.vcd",
	"scenes/producer/laughter05.vcd",
	"scenes/producer/laughter06.vcd",
	"scenes/producer/laughter07.vcd",
	"scenes/producer/laughter08.vcd",
	"scenes/producer/laughter09.vcd",
	"scenes/producer/laughter10.vcd",
	"scenes/producer/laughter11.vcd",
	"scenes/producer/laughter12.vcd",
	"scenes/producer/laughter13.vcd",
	"scenes/producer/laughter14.vcd",
	"scenes/producer/laughter15.vcd",
	"scenes/producer/laughter16.vcd",
	"scenes/producer/laughter17.vcd"
};

static const char g_szRochelleTaunts[][] =
{
	"scenes/producer/taunt01.vcd",
	"scenes/producer/taunt02.vcd",
	"scenes/producer/taunt03.vcd",
	"scenes/producer/taunt04.vcd",
	"scenes/producer/taunt05.vcd",
	"scenes/producer/taunt06.vcd",
	"scenes/producer/taunt07.vcd",
	"scenes/producer/taunt08.vcd"
};

static const char g_szRochelleScreams[][] =
{
	"scenes/producer/deathscream01.vcd",
	"scenes/producer/deathscream02.vcd"
};


static const char g_szCoachLaughs[][] =
{
	"scenes/coach/laughter01.vcd",
	"scenes/coach/laughter02.vcd",
	"scenes/coach/laughter03.vcd",
	"scenes/coach/laughter04.vcd",
	"scenes/coach/laughter05.vcd",
	"scenes/coach/laughter06.vcd",
	"scenes/coach/laughter07.vcd",
	"scenes/coach/laughter08.vcd",
	"scenes/coach/laughter09.vcd",
	"scenes/coach/laughter10.vcd",
	"scenes/coach/laughter11.vcd",
	"scenes/coach/laughter12.vcd",
	"scenes/coach/laughter13.vcd",
	"scenes/coach/laughter14.vcd",
	"scenes/coach/laughter15.vcd",
	"scenes/coach/laughter16.vcd",
	"scenes/coach/laughter17.vcd",
	"scenes/coach/laughter18.vcd",
	"scenes/coach/laughter19.vcd",
	"scenes/coach/laughter20.vcd",
	"scenes/coach/laughter21.vcd",
	"scenes/coach/laughter22.vcd",
	"scenes/coach/laughter23.vcd"
};

static const char g_szCoachTaunts[][] =
{
	"scenes/coach/taunt01.vcd",
	"scenes/coach/taunt02.vcd",
	"scenes/coach/taunt03.vcd",
	"scenes/coach/taunt04.vcd",
	"scenes/coach/taunt05.vcd",
	"scenes/coach/taunt06.vcd",
	"scenes/coach/taunt07.vcd",
	"scenes/coach/taunt08.vcd"
};

static const char g_szCoachScreams[][] =
{
	"scenes/coach/deathscream01.vcd",
	"scenes/coach/deathscream02.vcd",
	"scenes/coach/deathscream03.vcd",
	"scenes/coach/deathscream04.vcd",
	"scenes/coach/deathscream05.vcd",
	"scenes/coach/deathscream06.vcd",
	"scenes/coach/deathscream07.vcd",
	"scenes/coach/deathscream08.vcd",
	"scenes/coach/deathscream09.vcd"
};


static const char g_szEllisLaughs[][] =
{
	"scenes/mechanic/laughter01.vcd",
	"scenes/mechanic/laughter02.vcd",
	"scenes/mechanic/laughter03.vcd",
	"scenes/mechanic/laughter04.vcd",
	"scenes/mechanic/laughter05.vcd",
	"scenes/mechanic/laughter06.vcd",
	"scenes/mechanic/laughter07.vcd",
	"scenes/mechanic/laughter08.vcd",
	"scenes/mechanic/laughter09.vcd",
	"scenes/mechanic/laughter10.vcd",
	"scenes/mechanic/laughter11.vcd",
	"scenes/mechanic/laughter12.vcd",
	"scenes/mechanic/laughter13.vcd",
	"scenes/mechanic/laughter13a.vcd",
	"scenes/mechanic/laughter13b.vcd",
	"scenes/mechanic/laughter13c.vcd",
	"scenes/mechanic/laughter13d.vcd",
	"scenes/mechanic/laughter13e.vcd",
	"scenes/mechanic/laughter14.vcd",
};

static const char g_szEllisTaunts[][] =
{
	"scenes/mechanic/taunt01.vcd",
	"scenes/mechanic/taunt02.vcd",
	"scenes/mechanic/taunt03.vcd",
	"scenes/mechanic/taunt04.vcd",
	"scenes/mechanic/taunt05.vcd",
	"scenes/mechanic/taunt06.vcd",
	"scenes/mechanic/taunt07.vcd",
	"scenes/mechanic/taunt08.vcd"
};

static const char g_szEllisScreams[][] =
{
	"scenes/mechanic/deathscream01.vcd",
	"scenes/mechanic/deathscream02.vcd",
	"scenes/mechanic/deathscream03.vcd",
	"scenes/mechanic/deathscream04.vcd",
	"scenes/mechanic/deathscream05.vcd",
	"scenes/mechanic/deathscream06.vcd"
};


static const char g_szBillLaughs[][] =
{
	"scenes/namvet/laughter01.vcd",
	"scenes/namvet/laughter02.vcd",
	"scenes/namvet/laughter03.vcd",
	"scenes/namvet/laughter04.vcd",
	"scenes/namvet/laughter05.vcd",
	"scenes/namvet/laughter06.vcd",
	"scenes/namvet/laughter07.vcd",
	"scenes/namvet/laughter08.vcd",
	"scenes/namvet/laughter09.vcd",
	"scenes/namvet/laughter10.vcd",
	"scenes/namvet/laughter11.vcd",
	"scenes/namvet/laughter12.vcd",
	"scenes/namvet/laughter13.vcd",
	"scenes/namvet/laughter14.vcd"
};

static const char g_szBillTaunts[][] =
{
	"scenes/namvet/taunt01.vcd",
	"scenes/namvet/taunt02.vcd",
	"scenes/namvet/taunt07.vcd",
	"scenes/namvet/taunt08.vcd",
	"scenes/namvet/taunt09.vcd"
};

static const char g_szBillScreams[][] =
{
	"scenes/namvet/deathscream01.vcd",
	"scenes/namvet/deathscream02.vcd",
	"scenes/namvet/deathscream03.vcd",
	"scenes/namvet/deathscream04.vcd",
	"scenes/namvet/deathscream05.vcd",
	"scenes/namvet/deathscream06.vcd",
	"scenes/namvet/deathscream07.vcd",
	"scenes/namvet/deathscream08.vcd"
};


static const char g_szZoeyLaughs[][] =
{
	"scenes/teengirl/laughter01.vcd",
	"scenes/teengirl/laughter02.vcd",
	"scenes/teengirl/laughter03.vcd",
	"scenes/teengirl/laughter04.vcd",
	"scenes/teengirl/laughter05.vcd",
	"scenes/teengirl/laughter06.vcd",
	"scenes/teengirl/laughter07.vcd",
	"scenes/teengirl/laughter08.vcd",
	"scenes/teengirl/laughter09.vcd",
	"scenes/teengirl/laughter10.vcd",
	"scenes/teengirl/laughter11.vcd",
	"scenes/teengirl/laughter12.vcd",
	"scenes/teengirl/laughter13.vcd",
	"scenes/teengirl/laughter14.vcd",
	"scenes/teengirl/laughter15.vcd",
	"scenes/teengirl/laughter16.vcd",
	"scenes/teengirl/laughter17.vcd",
	"scenes/teengirl/laughter18.vcd",
	"scenes/teengirl/laughter19.vcd",
	"scenes/teengirl/laughter20.vcd",
	"scenes/teengirl/laughter21.vcd"
};

static const char g_szZoeyTaunts[][] =
{
	"scenes/teengirl/taunt02.vcd",
	"scenes/teengirl/taunt13.vcd",
	"scenes/teengirl/taunt18.vcd",
	"scenes/teengirl/taunt19.vcd",
	"scenes/teengirl/taunt20.vcd",
	"scenes/teengirl/taunt21.vcd",
	"scenes/teengirl/taunt24.vcd",
	"scenes/teengirl/taunt25.vcd",
	"scenes/teengirl/taunt26.vcd",
	"scenes/teengirl/taunt28.vcd",
	"scenes/teengirl/taunt29.vcd",
	"scenes/teengirl/taunt30.vcd",
	"scenes/teengirl/taunt31.vcd",
	"scenes/teengirl/taunt34.vcd",
	"scenes/teengirl/taunt35.vcd",
	"scenes/teengirl/taunt39.vcd"
};

static const char g_szZoeyScreams[][] =
{
	"scenes/teengirl/deathscream01.vcd",
	"scenes/teengirl/deathscream02.vcd",
	"scenes/teengirl/deathscream03.vcd",
	"scenes/teengirl/deathscream04.vcd",
	"scenes/teengirl/deathscream05.vcd",
	"scenes/teengirl/deathscream06.vcd",
	"scenes/teengirl/deathscream07.vcd",
	"scenes/teengirl/deathscream08.vcd",
	"scenes/teengirl/deathscream09.vcd",
	"scenes/teengirl/deathscream10.vcd",
	"scenes/teengirl/deathscream11.vcd"
};


static const char g_szLouisLaughs[][] =
{
	"scenes/manager/laughter01.vcd",
	"scenes/manager/laughter02.vcd",
	"scenes/manager/laughter03.vcd",
	"scenes/manager/laughter04.vcd",
	"scenes/manager/laughter05.vcd",
	"scenes/manager/laughter06.vcd",
	"scenes/manager/laughter07.vcd",
	"scenes/manager/laughter08.vcd",
	"scenes/manager/laughter09.vcd",
	"scenes/manager/laughter10.vcd",
	"scenes/manager/laughter11.vcd",
	"scenes/manager/laughter12.vcd",
	"scenes/manager/laughter13.vcd",
	"scenes/manager/laughter14.vcd",
	"scenes/manager/laughter15.vcd",
	"scenes/manager/laughter16.vcd",
	"scenes/manager/laughter17.vcd",
	"scenes/manager/laughter18.vcd",
	"scenes/manager/laughter19.vcd",
	"scenes/manager/laughter20.vcd",
	"scenes/manager/laughter21.vcd"
};

static const char g_szLouisTaunts[][] =
{
	"scenes/manager/taunt01.vcd",
	"scenes/manager/taunt02.vcd",
	"scenes/manager/taunt03.vcd",
	"scenes/manager/taunt04.vcd",
	"scenes/manager/taunt05.vcd",
	"scenes/manager/taunt06.vcd",
	"scenes/manager/taunt07.vcd",
	"scenes/manager/taunt08.vcd",
	"scenes/manager/taunt09.vcd",
	"scenes/manager/taunt10.vcd"
};

static const char g_szLouisScreams[][] =
{
	"scenes/manager/deathscream01.vcd",
	"scenes/manager/deathscream02.vcd",
	"scenes/manager/deathscream03.vcd",
	"scenes/manager/deathscream04.vcd",
	"scenes/manager/deathscream05.vcd",
	"scenes/manager/deathscream06.vcd",
	"scenes/manager/deathscream07.vcd",
	"scenes/manager/deathscream08.vcd",
	"scenes/manager/deathscream09.vcd",
	"scenes/manager/deathscream10.vcd"
};


static const char g_szFrancisLaughs[][] =
{
	"scenes/biker/laughter01.vcd",
	"scenes/biker/laughter02.vcd",
	"scenes/biker/laughter03.vcd",
	"scenes/biker/laughter04.vcd",
	"scenes/biker/laughter05.vcd",
	"scenes/biker/laughter06.vcd",
	"scenes/biker/laughter07.vcd",
	"scenes/biker/laughter08.vcd",
	"scenes/biker/laughter09.vcd",
	"scenes/biker/laughter10.vcd",
	"scenes/biker/laughter11.vcd",
	"scenes/biker/laughter12.vcd",
	"scenes/biker/laughter13.vcd",
	"scenes/biker/laughter14.vcd",
	"scenes/biker/laughter15.vcd"
};

static const char g_szFrancisTaunts[][] =
{
	"scenes/biker/taunt01.vcd",
	"scenes/biker/taunt02.vcd",
	"scenes/biker/taunt03.vcd",
	"scenes/biker/taunt04.vcd",
	"scenes/biker/taunt05.vcd",
	"scenes/biker/taunt06.vcd",
	"scenes/biker/taunt07.vcd",
	"scenes/biker/taunt08.vcd",
	"scenes/biker/taunt09.vcd",
	"scenes/biker/taunt10.vcd"
};

static const char g_szFrancisScreams[][] =
{
	"scenes/biker/deathscream01.vcd",
	"scenes/biker/deathscream02.vcd",
	"scenes/biker/deathscream03.vcd",
	"scenes/biker/deathscream04.vcd",
	"scenes/biker/deathscream05.vcd",
	"scenes/biker/deathscream06.vcd",
	"scenes/biker/deathscream07.vcd",
	"scenes/biker/deathscream08.vcd",
	"scenes/biker/deathscream09.vcd",
	"scenes/biker/deathscream10.vcd"
};

ConVar g_cvGamemode;
bool g_bVersus;

public void OnPluginStart()
{
	g_cvGamemode = FindConVar("mp_gamemode");
	g_cvGamemode.AddChangeHook(OnGamemodeChanged);
}

public void OnMapStart()
{
	PrecacheScenes();
}

public void OnConfigsExecuted()
{
	CheckVersus();
}

public void OnGamemodeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CheckVersus();
}

// credit to SilverShot
void CheckVersus()
{
	int entity = CreateEntityByName("info_gamemode");
	if( IsValidEntity(entity) )
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
			RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
	}
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 || strcmp(output, "OnSurvival") == 0 || strcmp(output, "OnScavenge") == 0 )
		g_bVersus = false;
	else if( strcmp(output, "OnVersus") == 0 )
		g_bVersus = true;
}

public Action OnVocalizeCommand(int client, const char[] vocalize, int initiator)
{
	if (!g_bVersus) return;
	
	if (!IsSurvivor(client) || !IsPlayerAlive(client)) return;
	
	Vocalize emVocalize = IdentifyVocalize(vocalize);
	if (emVocalize == NULL_VOCALIZE
			|| (emVocalize == Vocal_PlayerTaunt && IsActorBusy(client))) // :D
		return;

	SurvivorCharacter emCharacter = IdentifySurvivor(client);
	if (emCharacter == SC_NONE) return;

	char szVoiceFile[PLATFORM_MAX_PATH];
	PickVoice(szVoiceFile, sizeof(szVoiceFile), emVocalize, emCharacter);
	PerformScene(client, g_szVocalizeNames[emVocalize], szVoiceFile);
}

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
				case SC_NICK:		strcopy(szFile, maxlength, g_szNickLaughs[rndPick]);
				case SC_ROCHELLE:	strcopy(szFile, maxlength, g_szRochelleLaughs[rndPick]);
				case SC_COACH:		strcopy(szFile, maxlength, g_szCoachLaughs[rndPick]);
				case SC_ELLIS:		strcopy(szFile, maxlength, g_szEllisLaughs[rndPick]);
				case SC_BILL:		strcopy(szFile, maxlength, g_szBillLaughs[rndPick]);
				case SC_ZOEY:		strcopy(szFile, maxlength, g_szZoeyLaughs[rndPick]);
				case SC_LOUIS:		strcopy(szFile, maxlength, g_szLouisLaughs[rndPick]);
				case SC_FRANCIS:	strcopy(szFile, maxlength, g_szFrancisLaughs[rndPick]);
			}
		}
		case Vocal_PlayerTaunt:
		{
			switch (emCharacter)
			{
				case SC_NICK:		strcopy(szFile, maxlength, g_szNickTaunts[rndPick]);
				case SC_ROCHELLE:	strcopy(szFile, maxlength, g_szRochelleTaunts[rndPick]);
				case SC_COACH:		strcopy(szFile, maxlength, g_szCoachTaunts[rndPick]);
				case SC_ELLIS:		strcopy(szFile, maxlength, g_szEllisTaunts[rndPick]);
				case SC_BILL:		strcopy(szFile, maxlength, g_szBillTaunts[rndPick]);
				case SC_ZOEY:		strcopy(szFile, maxlength, g_szZoeyTaunts[rndPick]);
				case SC_LOUIS:		strcopy(szFile, maxlength, g_szLouisTaunts[rndPick]);
				case SC_FRANCIS:	strcopy(szFile, maxlength, g_szFrancisTaunts[rndPick]);
			}
		}
		case Vocal_Playerdeath:
		{
			switch (emCharacter)
			{
				case SC_NICK:		strcopy(szFile, maxlength, g_szNickScreams[rndPick]);
				case SC_ROCHELLE:	strcopy(szFile, maxlength, g_szRochelleScreams[rndPick]);
				case SC_COACH:		strcopy(szFile, maxlength, g_szCoachScreams[rndPick]);
				case SC_ELLIS:		strcopy(szFile, maxlength, g_szEllisScreams[rndPick]);
				case SC_BILL:		strcopy(szFile, maxlength, g_szBillScreams[rndPick]);
				case SC_ZOEY:		strcopy(szFile, maxlength, g_szZoeyScreams[rndPick]);
				case SC_LOUIS:		strcopy(szFile, maxlength, g_szLouisScreams[rndPick]);
				case SC_FRANCIS:	strcopy(szFile, maxlength, g_szFrancisScreams[rndPick]);
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

void PrecacheScenes()
{
	bool save = LockStringTables(false);
	
	int i;
	for (i = 0; i < MAX_NICK_LAUGH; ++i) {
		AddSceneToTable(g_szNickLaughs[i]);
	}
	for (i = 0; i < MAX_NICK_TAUNT; ++i) {
		AddSceneToTable(g_szNickTaunts[i]);
	}
	for (i = 0; i < MAX_NICK_SCREAM; ++i) {
		AddSceneToTable(g_szNickScreams[i]);
	}
	for (i = 0; i < MAX_ROCHELLE_LAUGH; ++i) {
		AddSceneToTable(g_szRochelleLaughs[i]);
	}
	for (i = 0; i < MAX_ROCHELLE_TAUNT; ++i) {
		AddSceneToTable(g_szRochelleTaunts[i]);
	}
	for (i = 0; i < MAX_ROCHELLE_SCREAM; ++i) {
		AddSceneToTable(g_szRochelleScreams[i]);
	}
	for (i = 0; i < MAX_COACH_LAUGH; ++i) {
		AddSceneToTable(g_szCoachLaughs[i]);
	}
	for (i = 0; i < MAX_COACH_TAUNT; ++i) {
		AddSceneToTable(g_szCoachTaunts[i]);
	}
	for (i = 0; i < MAX_COACH_SCREAM; ++i) {
		AddSceneToTable(g_szCoachScreams[i]);
	}
	for (i = 0; i < MAX_ELLIS_LAUGH; ++i) {
		AddSceneToTable(g_szEllisLaughs[i]);
	}
	for (i = 0; i < MAX_ELLIS_TAUNT; ++i) {
		AddSceneToTable(g_szEllisTaunts[i]);
	}
	for (i = 0; i < MAX_ELLIS_SCREAM; ++i) {
		AddSceneToTable(g_szEllisScreams[i]);
	}
	for (i = 0; i < MAX_BILL_LAUGH; ++i) {
		AddSceneToTable(g_szBillLaughs[i]);
	}
	for (i = 0; i < MAX_BILL_TAUNT; ++i) {
		AddSceneToTable(g_szBillTaunts[i]);
	}
	for (i = 0; i < MAX_BILL_SCREAM; ++i) {
		AddSceneToTable(g_szBillScreams[i]);
	}
	for (i = 0; i < MAX_ZOEY_LAUGH; ++i) {
		AddSceneToTable(g_szZoeyLaughs[i]);
	}
	for (i = 0; i < MAX_ZOEY_TAUNT; ++i) {
		AddSceneToTable(g_szZoeyTaunts[i]);
	}
	for (i = 0; i < MAX_ZOEY_SCREAM; ++i) {
		AddSceneToTable(g_szZoeyScreams[i]);
	}
	for (i = 0; i < MAX_LOUIS_LAUGH; ++i) {
		AddSceneToTable(g_szLouisLaughs[i]);
	}
	for (i = 0; i < MAX_LOUIS_TAUNT; ++i) {
		AddSceneToTable(g_szLouisTaunts[i]);
	}
	for (i = 0; i < MAX_LOUIS_SCREAM; ++i) {
		AddSceneToTable(g_szLouisScreams[i]);
	}
	for (i = 0; i < MAX_FRANCIS_LAUGH; ++i) {
		AddSceneToTable(g_szFrancisLaughs[i]);
	}
	for (i = 0; i < MAX_FRANCIS_TAUNT; ++i) {
		AddSceneToTable(g_szFrancisTaunts[i]);
	}
	for (i = 0; i < MAX_FRANCIS_SCREAM; ++i) {
		AddSceneToTable(g_szFrancisScreams[i]);
	}
	
	LockStringTables(save);
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
