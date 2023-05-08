#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <actions>
#include <l4d2util>

#define PLUGIN_VERSION "2.0.1"

public Plugin myinfo =
{
	name = "[L4D2] Uncommon Adjustment",
	author = "Forgetest",
	description = "Custom adjustments to uncommon infected.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

ConVar z_health;

int g_iUncommonAttract;
float g_flHealthScale;
float g_flJimmyHealthScale;

int g_iOffs_m_nUncommonFlags;

public void OnPluginStart()
{
	z_health = FindConVar("z_health");
	
	CreateConVarHook("l4d2_uncommon_attract",
						"3",
						"Set whether clowns and Jimmy gibs Jr. can attract zombies.\n"
					...	"0 = Neither, 1 = Clowns, 2 = Jimmy gibs Jr., 3 = Both",
						FCVAR_SPONLY,
						true, 0.0, true, 3.0,
						UncommonAttract_ConVarChanged);
	
	CreateConVarHook("l4d2_uncommon_health_multiplier",
						"3.0",
						"How many the uncommon health is scaled by.\n"
					...	"Doesn't apply to Jimmy gibs Jr., fallen survivors and Riot Cops.",
						FCVAR_SPONLY,
						true, 0.0, false, 0.0,
						UncommonHealthScale_ConVarChanged);
	
	CreateConVarHook("l4d2_jimmy_health_multiplier",
						"20.0",
						"How many the health of Jimmy gibs Jr. is scaled by.",
						FCVAR_SPONLY,
						true, 0.0, false, 0.0,
						JimmyHealthScale_ConVarChanged);
	
	g_iOffs_m_nUncommonFlags = FindSendPropInfo("Infected", "m_nFallenFlags") - 4;
}

void UncommonAttract_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iUncommonAttract = convar.IntValue;
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
	if (classname[0] == 'i')
	{
		if (strcmp(classname, "infected") == 0)
		{
			SDKHook(entity, SDKHook_SpawnPost, SDK_OnSpawn_Post);
		}
		else if (strcmp(classname, "info_goal_infected_chase") == 0)
		{
			SDKHook(entity, SDKHook_Think, SDK_OnThink_Once);
		}
	}
}

Action SDK_OnThink_Once(int entity)
{
	SDKUnhook(entity, SDKHook_Think, SDK_OnThink_Once);
	return __OnThink(entity);
}

Action __OnThink(int entity)
{
	int parent = GetEntPropEnt(entity, Prop_Data, "m_pParent");
	if (!IsValidEntity(parent))
		return Plugin_Continue;
	
	bool bDisableAttraction = false;
	switch (GetGender(parent))
	{
	case L4D2Gender_Clown:
		{
			bDisableAttraction = (g_iUncommonAttract & 1) == 0;
		}
	case L4D2Gender_Jimmy:
		{
			bDisableAttraction = (g_iUncommonAttract & 2) == 0;
		}
	}
	
	if (bDisableAttraction)
	{
		AcceptEntityInput(entity, "Disable");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
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

public void OnActionCreated(BehaviorAction action, int owner, const char[] name)
{
	if (name[0] != 'I' && strncmp(name, "Infected", 8) != 0)
		return;
	
	if (strcmp(name[8], "Attack") != 0 && strcmp(name[8], "Alert") != 0 && strcmp(name[8], "Wander") != 0)
		return;
	
	if (~GetUncommonFlag(owner) & 8)
		return;
	
	action.OnSound = OnSound;
	action.OnSoundPost = OnSoundPost;
}

bool g_bShouldRestore = false;
Action OnSound(BehaviorAction action, int actor, int entity, const float pos[3], Address keyvalues, ActionDesiredResult result)
{
	char cls[64];
	GetEdictClassname(entity, cls, sizeof(cls));
	if (strcmp(cls, "info_goal_infected_chase") == 0)
	{
		if (GetEntPropEnt(entity, Prop_Data, "m_pParent") == -1)
		{
			SetUncommonFlag(actor, GetUncommonFlag(actor) & ~8);
			g_bShouldRestore = true;
		}
	}
	
	return Plugin_Continue;
}

Action OnSoundPost(BehaviorAction action, int actor, int entity, const float pos[3], Address keyvalues, ActionDesiredResult result)
{
	if (g_bShouldRestore)
	{
		SetUncommonFlag(actor, GetUncommonFlag(actor) | 8);
		g_bShouldRestore = false;
	}
	
	return Plugin_Continue;
}

int GetUncommonFlag(int entity)
{
	return GetEntData(entity, g_iOffs_m_nUncommonFlags);
}

void SetUncommonFlag(int entity, int flags)
{
	SetEntData(entity, g_iOffs_m_nUncommonFlags, flags);
}

void ResetEntityHealth(int entity, int health)
{
	if (health < 1)
		health = 1;
	
	SetEntProp(entity, Prop_Data, "m_iMaxHealth", health);
	SetEntProp(entity, Prop_Data, "m_iHealth", health);
}

ConVar CreateConVarHook(const char[] name,
	const char[] defaultValue,
	const char[] description="",
	int flags=0,
	bool hasMin=false, float min=0.0,
	bool hasMax=false, float max=0.0,
	ConVarChanged callback)
{
	ConVar cv = CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
	
	Call_StartFunction(INVALID_HANDLE, callback);
	Call_PushCell(cv);
	Call_PushNullString();
	Call_PushNullString();
	Call_Finish();
	
	cv.AddChangeHook(callback);
	
	return cv;
}
