#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <l4d2util>

#include "l4d2_uncommon_adjustment/util.inc"
#include "l4d2_uncommon_adjustment/uncommon_attract.inc"

#define PLUGIN_VERSION "1.1"

public Plugin myinfo =
{
	name = "[L4D2] Uncommon Adjustment",
	author = "Forgetest",
	description = "Custom adjustments to uncommon infected.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d2_uncommon_adjustment"

ConVar z_health;

float g_flHealthScale;
float g_flJimmyHealthScale;

UncommonAttract_t UncommonAttract;

public void OnPluginStart()
{
	LoadSDK();
	
	ConVar cv;
	cv = CreateConVar("l4d2_uncommon_attract",
						"1",
						"Set whether clowns and Jimmy gibs Jr. can attract zombies.\n"
					...	"0 = Disable, 1 = Enable",
						FCVAR_SPONLY,
						true, 0.0, true, 1.0);
	cv.AddChangeHook(UncommonAttract_ConVarChanged);
	UncommonAttract_ConVarChanged(cv, "", "");
	
	cv = CreateConVar("l4d2_uncommon_health_multiplier",
						"3.0",
						"How many the uncommon health is scaled by.\n"
					...	"Doesn't apply to Jimmy gibs Jr., fallen survivors and Riot Cops.",
						FCVAR_SPONLY,
						true, 1.0);
	cv.AddChangeHook(UncommonHealthScale_ConVarChanged);
	UncommonHealthScale_ConVarChanged(cv, "", "");
	
	cv = CreateConVar("l4d2_jimmy_health_multiplier",
						"20.0",
						"How many the health of Jimmy gibs Jr. is scaled by.",
						FCVAR_SPONLY,
						true, 1.0);
	cv.AddChangeHook(JimmyHealthScale_ConVarChanged);
	JimmyHealthScale_ConVarChanged(cv, "", "");
	
	z_health = FindConVar("z_health");
}

void LoadSDK()
{
	GameData conf = new GameData(GAMEDATA_FILE);
	__Assert(conf != null, "Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	UncommonAttract.Init(conf);
	
	delete conf;
}

void UncommonAttract_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.BoolValue ? UncommonAttract.Enable() : UncommonAttract.Disable();
}

void UncommonHealthScale_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flHealthScale = convar.FloatValue;
}

void JimmyHealthScale_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flJimmyHealthScale = convar.FloatValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (classname[0] == 'i' && strcmp(classname, "infected") == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, SDK_OnSpawn_Post);
	}
}

void SDK_OnSpawn_Post(int entity)
{
	if (!IsValidEdict(entity))
		return;
	
	int gender = GetGender(entity);
	if (gender < L4D2Gender_Ceda || gender > L4D2Gender_Jimmy)
		return;
	
	switch (gender)
	{
	case L4D2Gender_Fallen, L4D2Gender_Riot_Control: { }
	case L4D2Gender_Jimmy:
	{
		int iHealth = RoundToFloor(z_health.FloatValue * g_flJimmyHealthScale); // classic cast to int
		ResetEntityHealth(entity, iHealth);
	}
	default:
	{
		int iHealth = RoundToFloor(z_health.FloatValue * g_flHealthScale); // classic cast to int
		ResetEntityHealth(entity, iHealth);
	}
	}
}