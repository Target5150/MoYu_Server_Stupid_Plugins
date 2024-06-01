#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#define PLUGIN_VERSION "1.3"

public Plugin myinfo =
{
	name = "[L4D & 2] Lag-compensated Skeet",
	author = "Forgetest",
	description = "Make hunter skeets more consistent across different pings.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

methodmap CountdownTimer
{
	public bool HasStarted() {
		return (this.m_timestamp > 0.0);
	}

	property float m_duration {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(4), NumberType_Int32); }
	}

	property float m_timestamp {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(8), NumberType_Int32); }
	}
}

methodmap CUserCmd
{
	property int tick_count {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(8), NumberType_Int32); }
	}
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	public DynamicDetour CreateDetourOrFail(
			const char[] name,
			DHookCallback preHook = INVALID_FUNCTION,
			DHookCallback postHook = INVALID_FUNCTION) {
		DynamicDetour hSetup = DynamicDetour.FromConf(this, name);
		if (!hSetup)
			SetFailState("Missing detour setup \"%s\"", name);
		if (preHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Pre, preHook))
			SetFailState("Failed to pre-detour \"%s\"", name);
		if (postHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Post, postHook))
			SetFailState("Failed to post-detour \"%s\"", name);
		return hSetup;
	}
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_lagcomp_skeet");
	delete gd.CreateDetourOrFail("CTerrorPlayer::OnTakeDamageInternal", DTR_OnTakeDamageInternal, DTR_OnTakeDamageInternal_Post);
	delete gd;
}

int g_iSaveClient;
int g_iSave_m_isAttemptingToPounce;
MRESReturn DTR_OnTakeDamageInternal(int victim, DHookParam hParams)
{
	g_iSaveClient = -1;
	g_iSave_m_isAttemptingToPounce = -1;

	int ability = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
	if (ability == -1 || !IsAbilityLunge(ability))
		return MRES_Ignored;

	static const int k_iOffs_CTakeDamageInfo_m_hAttacker = 52;

	int attacker = hParams.GetObjectVar(1, k_iOffs_CTakeDamageInfo_m_hAttacker, ObjectValueType_Ehandle);
	if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2 || IsFakeClient(attacker))
		return MRES_Ignored;

	g_iSaveClient = victim;
	float flTargetTime = GetLagCompTargetTime(attacker);

	if (GetEntProp(ability, Prop_Send, "m_isLunging"))
	{
		float flLungeStartTime = GetEntPropFloat(ability, Prop_Send, "m_lungeStartTime");

		g_iSave_m_isAttemptingToPounce = GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce");
		SetEntProp(victim, Prop_Send, "m_isAttemptingToPounce", flTargetTime >= flLungeStartTime);
	}
	else
	{
		CountdownTimer lungeCooldownTiemr = GetLungeCooldownTimer(ability);
		if (lungeCooldownTiemr.HasStarted())
		{
			float flLungeEndTime = lungeCooldownTiemr.m_timestamp - lungeCooldownTiemr.m_duration;

			g_iSave_m_isAttemptingToPounce = GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce");
			SetEntProp(victim, Prop_Send, "m_isAttemptingToPounce", flTargetTime < flLungeEndTime);
		}
	}

	return MRES_Ignored;
}

MRESReturn DTR_OnTakeDamageInternal_Post(int victim, DHookParam hParams)
{
	if (g_iSaveClient != victim)
		return MRES_Ignored;

	g_iSaveClient = -1;
	if (g_iSave_m_isAttemptingToPounce != -1)
	{
		SetEntProp(victim, Prop_Send, "m_isAttemptingToPounce", g_iSave_m_isAttemptingToPounce);
		g_iSave_m_isAttemptingToPounce = -1;
	}

	return MRES_Ignored;
}

float GetLagCompTargetTime(int client)
{
	/*

	// correct is the amount of time we have to correct game time
	float correct = 0.0f;

	// Get true latency
	INetChannelInfo *nci = engine->GetPlayerNetInfo( player->entindex() );
	if ( nci )
	{
		// add network latency
		correct+= nci->GetLatency( FLOW_OUTGOING );
	}

	// NOTE:  do these computations in float time, not ticks, to avoid big roundoff error accumulations in the math
	// add view interpolation latency see C_BaseEntity::GetInterpolationAmount()
	correct += player->m_fLerpTime;

	// check bounds [0,sv_maxunlag]
	correct = clamp( correct, 0.0f, sv_maxunlag.GetFloat() );

	// correct tick send by player
	float flTargetTime = TICKS_TO_TIME( cmd->tick_count ) - player->m_fLerpTime;

	// calculate difference between tick sent by player and our latency based tick
	float deltaTime =  correct - ( gpGlobals->curtime - flTargetTime );

	if ( fabs( deltaTime ) > 0.2f )
	{
		// difference between cmd time and latency is too big > 200ms, use time correction based on latency
		// DevMsg("StartLagCompensation: delta too big (%.3f)\n", deltaTime );
		flTargetTime = gpGlobals->curtime - correct;
	}

	flTargetTime += TICKS_TO_TIME( sv_lagpushticks.GetInt() );

	*/

	static ConVar sv_maxunlag = null, sv_lagpushticks = null;
	if (!sv_maxunlag || !sv_lagpushticks)
	{
		sv_maxunlag = FindConVar("sv_maxunlag");
		sv_lagpushticks = FindConVar("sv_lagpushticks");
	}

	// correct is the amount of time we have to correct game time
	float correct = GetClientLatency(client, NetFlow_Outgoing); // Get true latency

	// NOTE:  do these computations in float time, not ticks, to avoid big roundoff error accumulations in the math
	// add view interpolation latency see C_BaseEntity::GetInterpolationAmount()
	correct += GetEntPropFloat(client, Prop_Data, "m_fLerpTime");

	// check bounds [0,sv_maxunlag]
	if (sv_maxunlag) correct = Math_Clamp( correct, 0.0, sv_maxunlag.FloatValue );

	// correct tick send by player
	float flTargetTime = GetTickInterval() * GetPlayerCurrentCommand(client).tick_count - GetEntPropFloat(client, Prop_Data, "m_fLerpTime");

	// calculate difference between tick sent by player and our latency based tick
	float deltaTime =  correct - ( GetGameTime() - flTargetTime );

	if ( FloatAbs(deltaTime) > 0.2 )
	{
		// difference between cmd time and latency is too big > 200ms, use time correction based on latency
		flTargetTime = GetGameTime() - correct;
	}

	if (sv_lagpushticks) flTargetTime += GetTickInterval() * sv_lagpushticks.IntValue;

	return flTargetTime;
}

CountdownTimer GetLungeCooldownTimer(int ability)
{
	static int s_iOffs_m_lungeCooldownTimer = -1;
	if (s_iOffs_m_lungeCooldownTimer == -1)
		s_iOffs_m_lungeCooldownTimer = FindSendPropInfo("CLunge", "m_isLunging") + 4;

	return view_as<CountdownTimer>(GetEntityAddress(ability) + view_as<Address>(s_iOffs_m_lungeCooldownTimer));
}

CUserCmd GetPlayerCurrentCommand(int player)
{
	static int s_iOffs_m_pCurrentCommand = -1;
	if (s_iOffs_m_pCurrentCommand == -1)
		s_iOffs_m_pCurrentCommand = FindDataMapInfo(player, "m_hViewModel")
									+ 4*2 /* CHandle<CBaseViewModel> * MAX_VIEWMODELS */
									+ 88 /* sizeof(m_LastCmd) */;

	return view_as<CUserCmd>(GetEntData(player, s_iOffs_m_pCurrentCommand, 4));
}

bool IsAbilityLunge(int ability)
{
	char cls[64];
	GetEdictClassname(ability, cls, sizeof(cls));
	return strcmp(cls, "ability_lunge") == 0;
}

stock any Math_Clamp(any inc, any low, any high)
{
	return (inc > high) ? high : ((inc < low) ? low : inc);
}
