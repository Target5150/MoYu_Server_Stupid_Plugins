#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <actions>
#include <sdktools>

#define PLUGIN_VERSION "1.2"

public Plugin myinfo = 
{
	name = "[L4D & 2] Change Witch Victim",
	author = "Forgetest",
	description = "Provide functionality for changing witch's victim.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

enum struct SDKCallParamsWrapper {
	SDKType type;
	SDKPassMethod pass;
	int decflags;
	int encflags;
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	public Handle CreateSDKCallOrFail(
			SDKCallType type,
			SDKFuncConfSource src,
			const char[] name,
			const SDKCallParamsWrapper[] params = {},
			int numParams = 0,
			bool hasReturnValue = false,
			const SDKCallParamsWrapper ret = {}) {
		static const char k_sSDKFuncConfSource[SDKFuncConfSource][] = { "offset", "signature", "address" };
		Handle result;
		StartPrepSDKCall(type);
		if (!PrepSDKCall_SetFromConf(this, src, name))
			SetFailState("Missing %s \"%s\"", k_sSDKFuncConfSource[src], name);
		for (int i = 0; i < numParams; ++i)
			PrepSDKCall_AddParameter(params[i].type, params[i].pass, params[i].decflags, params[i].encflags);
		if (hasReturnValue)
			PrepSDKCall_SetReturnInfo(ret.type, ret.pass, ret.decflags, ret.encflags);
		if (!(result = EndPrepSDKCall()))
			SetFailState("Failed to prep sdkcall \"%s\"", name);
		return result;
	}
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

methodmap WitchBurn < BehaviorAction {
	property int m_hTarget {
		public get() { return view_as<EHANDLE>(this.Get(60, NumberType_Int32)).Get(); }
		public set(int target) { this.Set(60, EHandleFromEdict(target), NumberType_Int32); }
	}
}

methodmap InfectedStandingActivity < BehaviorAction {
	property bool m_bAnimationFinished {
		public set(bool bAnimationFinished) { this.Set(72, bAnimationFinished, NumberType_Int8); }
	}
	property BehaviorAction m_nextAction {
		public get() { return this.Get(68, NumberType_Int32); }
	}
}

Handle g_Call_OnShoved, g_Call_OnCommandAttack;
Handle g_Call_MyNextBotPointer;
ConVar g_cvDebug;

bool g_bLeft4Dead2;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: { g_bLeft4Dead2 = false; }
		case Engine_Left4Dead2: { g_bLeft4Dead2 = true; }
		default: { strcopy(error, err_max, "Plugin supports L4D & 2 only"); return APLRes_SilentFailure; }
	}

	CreateNative("ChangeWitchTarget", Ntv_ChangeWitchTarget);
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_change_witch_victim");

	SDKCallParamsWrapper params[] = {
		{ SDKType_CBaseEntity, SDKPass_Pointer },
		{ SDKType_PlainOldData, SDKPass_Plain }
	};
	if (g_bLeft4Dead2)
		g_Call_OnCommandAttack = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Virtual, "INextBotEventResponder::OnCommandAttack", params, 1);
	else 
		g_Call_OnShoved = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Virtual, "INextBotEventResponder::OnShoved", params, 1);
	g_Call_MyNextBotPointer = gd.CreateSDKCallOrFail(SDKCall_Entity, SDKConf_Virtual, "MyNextBotPointer", _, _, true, params[1]);

	delete gd;

	g_cvDebug = CreateConVar("change_witch_target_debug", "0", "", FCVAR_NONE, true, 0.0, true, 1.0);
}

any Ntv_ChangeWitchTarget(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);

	if (!entity || !IsValidEdict(entity))
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is invalid", entity);
	
	if (!IsAliveWitch(entity))
		return false;
	
	int target = GetNativeCell(2);
	if (!IsValidEdict(target))
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is invalid", target);
	
	return ChangeWitchTarget(entity, target);
}

void ForceWitchAttack(int entity, int target)
{
	if (g_bLeft4Dead2)
	{
		SetEntPropFloat(entity, Prop_Send, "m_rage", 1.0);
		SDKCall( g_Call_OnCommandAttack, SDKCall(g_Call_MyNextBotPointer, entity), target );
	}
	else
	{
		SDKCall( g_Call_OnShoved, SDKCall(g_Call_MyNextBotPointer, entity), target );
	}
}

bool ChangeWitchTarget(int entity, int target)
{
	if (!target)
		return false;

	BehaviorAction action = ActionsManager.GetAction(entity, "WitchKillIncapVictim");
	if (action == INVALID_ACTION)
	{
		action = ActionsManager.GetAction(entity, "WitchBehavior");
		if (action == INVALID_ACTION)
			return false;
		
		if (action.Above != INVALID_ACTION)
		{
			DebugPrintToChatAll("\x04 ChangeWitchTarget : Above");
			action = GetTopAction(action);
		}
		else if (action.Child != INVALID_ACTION)
		{
			DebugPrintToChatAll("\x04 ChangeWitchTarget : Child");
			action = GetTopAction(action.Child);
		}
		else
		{
			return false;
		}
	}
	else
	{
		DebugPrintToChatAll("\x04 ChangeWitchTarget : WitchKillIncapVictim");
	}

	action.Update = OnUpdate;
	action.SetUserData("forced_target", EntIndexToEntRef(target));

	return true;
}

BehaviorAction GetTopAction(BehaviorAction action)
{
	char name[ACTION_NAME_LENGTH];
	action.GetName(name);
	DebugPrintToChatAll("\x04 GetTopAction : %s", name);
	while (action.Above)
	{
		action = action.Above;
		action.GetName(name);
		DebugPrintToChatAll("\x04 GetTopAction : %s", name);
	}
	return action;
}

int EntityToPlayer(int entity)
{
	entity = EntRefToEntIndex(entity);
	if (entity <= MaxClients && IsClientInGame(entity))
		return entity;
	
	return 0;
}

Action OnUpdate(BehaviorAction action, int actor, float interval, ActionResult result)
{
	int entity = action.GetUserData("forced_target");
	if (!IsValidEdict(entity))
		return Plugin_Continue;
	
	DebugPrintToChatAll("OnUpdate target %N", EntityToPlayer(entity));
	action.SetUserData("forced_target", -1);
	
	char name[ACTION_NAME_LENGTH];
	action.GetName(name);

	if (!strcmp(name, "WitchDying"))
	{
		return Plugin_Continue;
	}
	else if (!strcmp(name, "InfectedStandingActivity"))
	{
		action.UpdatePost = InfectedStandingActivity_UpdatePost;
		action.SetUserData("forced_target", entity);
		view_as<InfectedStandingActivity>(action).m_bAnimationFinished = true;
		DebugPrintToChatAll("\x03OnUpdate : %s", name);
		return Plugin_Continue;
	}
	else if (!strcmp(name, "WitchRetreat") || !strcmp(name, "WitchKillIncapVictim") || !strcmp(name, "WitchAttack"))
	{
		if (action.Under != INVALID_ACTION)
		{
			action.Under.OnResumePost = OnResumePost;
			action.Under.Update = OnUpdate;
			action.Under.SetUserData("forced_target", entity);
			DebugPrintToChatAll("\x03OnUpdate : %s Done", name);
			return action.Done("Forced by plugin \""..."l4d_change_witch_victim"..."\"");
		}
	}
	else if (!strcmp(name, "WitchBurn"))
	{
		action.IsStarted = false;
		view_as<WitchBurn>(action).m_hTarget = entity;
		DebugPrintToChatAll("\x03OnUpdate : %s IsStarted", name);
		return Plugin_Continue;
	}
	
	DataPack dp = new DataPack();
	RequestFrame(NextFrame_WitchAttack, dp);
	dp.WriteCell(EntIndexToEntRef(actor));
	dp.WriteCell(entity);

	// ForceWitchAttack(actor, EntRefToEntIndex(entity));
	DebugPrintToChatAll("\x03OnUpdate : %s NextFrame_WitchAttack", name);

	if (!strcmp(name, "WitchAngry"))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

Action InfectedStandingActivity_UpdatePost(BehaviorAction action, int actor, float interval, ActionResult result)
{
	if (result.type == CHANGE_TO)
	{
		result.action.Update = OnUpdate;
		result.action.SetUserData("forced_target", action.GetUserData("forced_target"));
	}
	return Plugin_Continue;
}

Action OnResumePost(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	if (result.type == CHANGE_TO)
	{
		result.action.Update = OnUpdate;
		result.action.SetUserData("forced_target", action.GetUserData("forced_target"));
	}
	return Plugin_Continue;
}

void NextFrame_WitchAttack(DataPack dp)
{
	dp.Reset();

	int entity = dp.ReadCell();
	int target = dp.ReadCell();

	delete dp;

	if (!IsValidEdict(entity) || !IsValidEdict(target))
		return;
	
	DebugPrintToChatAll("\x03NextFrame_WitchAttack %N", EntRefToEntIndex(target));
	ForceWitchAttack(EntRefToEntIndex(entity), EntRefToEntIndex(target));
}

bool IsAliveWitch(int entity)
{
	char cls[6];
	return GetEntityNetClass(entity, cls, sizeof(cls)) && !strcmp(cls, "Witch") && GetEntProp(entity, Prop_Data, "m_lifeState") == 0 && GetEntProp(entity, Prop_Data, "m_iHealth") > 0;
}

void DebugPrintToChatAll(const char[] format, any ...)
{
	if (g_cvDebug.BoolValue)
	{
		char buffer[512];
		VFormat(buffer, sizeof(buffer), format, 2);
		LogMessage("%s", buffer);
		PrintToChatAll("%s", buffer);
	}
}