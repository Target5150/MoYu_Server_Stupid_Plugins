#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <actions>

#define PLUGIN_VERSION "2.0.1"

public Plugin myinfo = 
{
	name = "[L4D & 2] Change Witch Victim",
	author = "Forgetest",
	description = "Provide functionality for changing witch's victim.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

#define REASON_CHANGE "Forced by plugin \""..."l4d_change_witch_victim"..."\""

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
}

methodmap InfectedStandingActivity < BehaviorAction {
	property bool m_bAnimationFinished {
		public set(bool bAnimationFinished) { this.Set(72, bAnimationFinished, NumberType_Int8); }
	}
}

ActionConstructor g_ActionConstructor_WitchAttack;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead, Engine_Left4Dead2: {}
		default: { strcopy(error, err_max, "Plugin supports L4D & 2 only"); return APLRes_SilentFailure; }
	}

	CreateNative("ChangeWitchTarget", Ntv_ChangeWitchTarget);
	RegPluginLibrary("l4d_change_witch_victim");

	return APLRes_Success;
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_change_witch_victim");
	g_ActionConstructor_WitchAttack = ActionConstructor.SetupFromConf(gd, "Forgetest::WitchAttack");
	delete gd;
}

any Ntv_ChangeWitchTarget(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);

	if (!entity || !IsValidEdict(entity))
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is invalid (arg %d)", entity, 1);
	
	if (!IsAliveWitch(entity))
		return false;
	
	int target = GetNativeCell(2);
	if (!IsValidEdict(target))
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is invalid (arg %d)", target, 2);
	
	return ChangeWitchTarget(entity, target);
}

bool ChangeWitchTarget(int entity, int target)
{
	BehaviorAction action = ActionsManager.GetAction(entity, "WitchExecAction");
	
	if (action == INVALID_ACTION) // she's gone
		return false;
	
	if (action.Child == INVALID_ACTION) // must have at least one child
		return false;
	
	do {
		action = action.Child;
	} while (action.Child != INVALID_ACTION);
	
	action.Update = Witch_OnUpdate;
	action.SetUserData("forced_target", EntIndexToEntRef(target));

	return true;
}

Action Witch_OnUpdate(BehaviorAction action, int actor, float interval, ActionResult result)
{
	action.Update = INVALID_FUNCTION;

	int ref = action.GetUserData("forced_target");
	if (ref == INVALID_ENT_REFERENCE || !IsValidEdict(ref))
		return Plugin_Continue;
	
	int entity = EntRefToEntIndex(ref);
	
	// Possible actions:
	//
	// - WitchDying
	//
	// - InfectedStandingActivity
	// 
	// - WitchKillIncapVictim, WitchRetreat
	//
	// - WitchAttack
	//
	// - WitchIdle, WitchWander, WitchAngry, WitchBurn

	if (action.Matches("WitchDying"))
	{
		return Plugin_Continue;
	}
	else if (action.Matches("InfectedStandingActivity"))
	{
		// force the animation finishes
		view_as<InfectedStandingActivity>(action).m_bAnimationFinished = true;

		// IMPORTANT:
		// this action acts as a transition and might carry another action that won't be freed on destruct
		action.UpdatePost = InfectedStandingActivity_UpdatePost;
		action.SetUserData("forced_target", ref);

		return Plugin_Continue;
	}
	else if (action.Matches("WitchRetreat") || action.Matches("WitchKillIncapVictim"))
	{
		if (action.Under != INVALID_ACTION)
		{
			action.Under.Update = Witch_OnUpdate;
			action.Under.SetUserData("forced_target", ref);
			return action.Done(REASON_CHANGE);
		}
	}
	else if (action.Matches("WitchAttack"))
	{
		return action.ChangeTo(g_ActionConstructor_WitchAttack.Execute(entity), REASON_CHANGE);
	}

	return action.SuspendFor(g_ActionConstructor_WitchAttack.Execute(entity), REASON_CHANGE);
}

Action InfectedStandingActivity_UpdatePost(BehaviorAction action, int actor, float interval, ActionResult result)
{
	action.UpdatePost = INVALID_FUNCTION;

	if (result.type == CHANGE_TO)
	{
		result.action.Update = Witch_OnUpdate;
		result.action.SetUserData("forced_target", action.GetUserData("forced_target"));
	}
	else if (result.type == DONE)
	{
		if (action.Under != INVALID_ACTION)
		{
			action.Under.Update = Witch_OnUpdate;
			action.Under.SetUserData("forced_target", action.GetUserData("forced_target"));
		}
	}
	return Plugin_Continue;
}

bool IsAliveWitch(int entity)
{
	char cls[6];
	return GetEntityNetClass(entity, cls, sizeof(cls)) && !strcmp(cls, "Witch") && GetEntProp(entity, Prop_Data, "m_lifeState") == 0 && GetEntProp(entity, Prop_Data, "m_iHealth") > 0;
}
