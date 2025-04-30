#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Rock Invulnerable Duration",
	author = "Forgetest",
	description = "Changer for the default 0.5s invulnerability on rock.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

float g_flInvulDuration;

public void OnPluginStart()
{
	ConVar cv = CreateConVar("tank_rock_invuln_duration",
							"0.5",
							"Amount of time Tank rock keeps invulnerable after released.\n"
						...	"Negative value indicates invulnerable forever.",
							FCVAR_SPONLY,
							true, -1.0);
	OnConVarChanged(cv, "", "");
	cv.AddChangeHook(OnConVarChanged);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flInvulDuration = convar.FloatValue;
}

public void L4D_TankRock_OnRelease_Post(int tank, int rock, const float vecPos[3], const float vecAng[3], const float vecVel[3], const float vecRot[3])
{
	static int s_iOffs_m_releaseTimer = -1;
	if (s_iOffs_m_releaseTimer == -1)
		s_iOffs_m_releaseTimer = FindSendPropInfo("CBaseCSGrenadeProjectile", "m_vInitialVelocity") + 36;
	
	if (0.0 <= g_flInvulDuration && g_flInvulDuration <= 0.5)
		SetEntDataFloat(rock, s_iOffs_m_releaseTimer + 4, GetGameTime() + g_flInvulDuration - 0.5);
	else
		SDKHook(rock, SDKHook_ThinkPost, SDK_OnThink_Post);
}

void SDK_OnThink_Post(int rock)
{
	if (!IsValidEdict(rock))
		return;
	
	if (GetEntProp(rock, Prop_Data, "m_takedamage") == 2) // DAMAGE_YES
	{
		SetEntProp(rock, Prop_Data, "m_takedamage", 0);
		
		if (g_flInvulDuration > 0.5)
			CreateTimer(g_flInvulDuration - 0.5, Timer_AllowDamage, EntIndexToEntRef(rock), TIMER_FLAG_NO_MAPCHANGE);
		
		SDKUnhook(rock, SDKHook_ThinkPost, SDK_OnThink_Post);
	}
}

Action Timer_AllowDamage(Handle timer, int ref)
{
	int rock = EntRefToEntIndex(ref);
	
	if (IsValidEdict(rock))
	{
		SetEntProp(rock, Prop_Data, "m_takedamage", 2); // DAMAGE_YES
	}
	
	return Plugin_Stop;
}