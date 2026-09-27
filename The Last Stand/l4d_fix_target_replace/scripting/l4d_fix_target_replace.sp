#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_functions>
#include <actions>

#define PLUGIN_VERSION "1.3"

public Plugin myinfo = 
{
	name = "[L4D & 2] Fix Target Replace",
	author = "Forgetest",
	description = "Fix issues with infected targeting when replacing survivors.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

enum EHANDLE
{
	INVALID_EHANDLE = -1
};

EHANDLE EHandleFromEdict(int entity) {
	static int s_iOffs_m_RefEHandle = -1;
	if (s_iOffs_m_RefEHandle == -1)
		s_iOffs_m_RefEHandle = FindSendPropInfo("CBaseEntity", "m_angRotation") + 12;
	
	return view_as<EHANDLE>(GetEntData(entity, s_iOffs_m_RefEHandle, 4));
}

methodmap EHANDLE {
	public int Get() {
		static int s_iRandomOffsetToAnEHandle = -1;
		if (s_iRandomOffsetToAnEHandle == -1)
			s_iRandomOffsetToAnEHandle = FindSendPropInfo("CWorld", "m_hOwnerEntity");
		
		int temp = GetEntData(0, s_iRandomOffsetToAnEHandle, 4);
		SetEntData(0, s_iRandomOffsetToAnEHandle, this, 4);
		int result = GetEntDataEnt2(0, s_iRandomOffsetToAnEHandle);
		SetEntData(0, s_iRandomOffsetToAnEHandle, temp, 4);
		
		return result;
	}
}

enum TongueState
{
	STATE_TONGUE_IN_MOUTH,
	STATE_TONGUE_MISFIRE,
	STATE_TONGUE_EXTENDING,
	STATE_TONGUE_ATTACHED_TO_TARGET,
	STATE_TONGUE_DROPPING_TO_GROUND,

	NUM_TONGUE_STATES
};

methodmap CTongue
{
	public static CTongue FromPlayer(int client) {
		int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
		if (ability == -1 || !CTongue.IsAbilityTongue(ability)) return view_as<CTongue>(0);
		return view_as<CTongue>(ability);
	}

	public static bool IsAbilityTongue(int ability) {
		char cls[64];
		return GetEdictClassname(ability, cls, sizeof(cls)) && !strcmp(cls, "ability_tongue");
	}

	property TongueState m_tongueState {
		public get() { return view_as<TongueState>(GetEntProp(view_as<int>(this), Prop_Send, "m_tongueState")); }
	}

	property int m_currentTipTarget {
		public get() { return GetEntPropEnt(view_as<int>(this), Prop_Send, "m_currentTipTarget"); }
		public set(int target) { SetEntPropEnt(view_as<int>(this), Prop_Send, "m_currentTipTarget", target); }
	}
}

bool g_bFixSmoker, g_bFixBoomer, g_bFixInfected, g_bFixWitch;

public void OnPluginStart()
{
	CreateConVarHook("l4d_fix_target_replace_smoker",
				"1",
				"Enable target fix for Smoker?",
				FCVAR_NONE,
				true, 0.0, true, 1.0,
				CvarChg_FixSmoker);

	CreateConVarHook("l4d_fix_target_replace_boomer",
				"1",
				"Enable target fix for Boomer?",
				FCVAR_NONE,
				true, 0.0, true, 1.0,
				CvarChg_FixBoomer);

	CreateConVarHook("l4d_fix_target_replace_infected",
				"1",
				"Enable target fix for the common infected?",
				FCVAR_NONE,
				true, 0.0, true, 1.0,
				CvarChg_FixInfected);

	CreateConVarHook("l4d_fix_target_replace_witch",
				"1",
				"Enable target fix for Witch?",
				FCVAR_NONE,
				true, 0.0, true, 1.0,
				CvarChg_FixWitch);

	HookEvent("player_bot_replace", Event_player_bot_replace);
	HookEvent("bot_player_replace", Event_bot_player_replace);
}

void CvarChg_FixSmoker(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bFixSmoker = convar.BoolValue;
}

void CvarChg_FixBoomer(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bFixBoomer = convar.BoolValue;
}

void CvarChg_FixInfected(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bFixInfected = convar.BoolValue;
}

void CvarChg_FixWitch(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bFixWitch = convar.BoolValue;
}

void Event_player_bot_replace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(event.GetInt("bot"), event.GetInt("player"));
}

void Event_bot_player_replace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(event.GetInt("player"), event.GetInt("bot"));
}

void HandlePlayerReplace(int replacer, int me)
{
	replacer = GetClientOfUserId(replacer);
	me = GetClientOfUserId(me);
	if (!replacer || !IsClientInGame(replacer) || !me || !IsClientInGame(me))
		return;
	
	if (GetClientTeam(replacer) != 2)
		return;
	
	NotifyNextbot(replacer, me);
}

void NotifyNextbot(int newTarget, int oldTarget)
{
	if (g_bFixInfected)
	{
		int entity = MaxClients+1;
		while ((entity = FindEntityByClassname(entity, "infected")) != INVALID_ENT_REFERENCE)
		{
			UTIL_ReplaceActionVictim(entity, "InfectedAttack", newTarget, oldTarget);
			UTIL_ReplaceActionVictim(entity, "PunchVictim", newTarget, oldTarget);
		}
	}

	if (g_bFixWitch)
	{
		int entity = MaxClients+1;
		while ((entity = FindEntityByClassname(entity, "witch")) != INVALID_ENT_REFERENCE)
		{ 
			UTIL_ReplaceActionVictim(entity, "WitchAttack", newTarget, oldTarget);
			UTIL_ReplaceActionVictim(entity, "WitchKillIncapVictim", newTarget, oldTarget);
			UTIL_ReplaceActionVictim(entity, "InfectedStandingActivity", newTarget, oldTarget);
		}
	}

	if (g_bFixSmoker || g_bFixBoomer)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
			{
				switch (GetEntProp(i, Prop_Send, "m_zombieClass"))
				{
				case 1:
					{
						if (g_bFixSmoker)
						{
							UTIL_ReplaceActionVictim(i, "SmokerTongueVictim", newTarget, oldTarget);

							CTongue ability = CTongue.FromPlayer(i);
							if (ability && ability.m_tongueState == STATE_TONGUE_EXTENDING)
							{
								if (ability.m_currentTipTarget == oldTarget)
								{
									ability.m_currentTipTarget = newTarget;
								}
							}
						}
					}

				case 2:
					{
						if (g_bFixBoomer)
						{
							UTIL_ReplaceActionVictim(i, "BoomerVomitOnVictim", newTarget, oldTarget);
						}
					}
				}
			}
		}
	}
}

void UTIL_ReplaceActionVictim(int entity, const char[] name, int newTarget, int oldTarget)
{
	BehaviorAction action = ActionsManager.GetAction(entity, name);
	if (action == INVALID_ACTION)
		return;
	
	if (!strcmp(name, "InfectedStandingActivity"))
	{
		BehaviorAction nextAction = action.Get(68, NumberType_Int32);
		if (action != INVALID_ACTION)
		{
			// It's still an inactive action so we cannot just call "BehaviorAction.GetName" on it
			// ugly but accept
			_ReplaceActionVictim(nextAction, "WitchKillIncapVictim", newTarget, oldTarget);
		}
		return;
	}

	_ReplaceActionVictim(action, name, newTarget, oldTarget);
}

void _ReplaceActionVictim(BehaviorAction action, const char[] name, int newTarget, int oldTarget)
{
	int offs = !strcmp(name, "PunchVictim") ? 88 : 52;

	EHANDLE ehndl = action.Get(offs);
	if (ehndl.Get() != oldTarget)
		return;
	
	action.Set(offs, EHandleFromEdict(newTarget));

	if (!strcmp(name, "WitchAttack"))
		action.Set(56, GetEntProp(newTarget, Prop_Send, "m_survivorCharacter"));
}

stock ConVar CreateConVarHook(const char[] name,
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