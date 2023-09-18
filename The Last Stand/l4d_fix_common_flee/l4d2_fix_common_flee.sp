#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <actions>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D2] Fix Common Flee",
	author = "Forgetest",
	description = "Fix sitting/lying commons becoming stuck when attempting to flee.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d2_fix_common_flee"

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	public int GetOffsetOrFail(const char[] key) {
		int offset = this.GetOffset(key);
		if (offset == -1) SetFailState("Missing offset \"%s\"", key);
		return offset;
	}
}

int g_iOffs_Infected__m_body;
int g_iOffs_ZombieBotBody__m_desiredPosture;
int g_iOffs_ZombieBotBody__m_posture;
int g_iOffs_ZombieBotBody__m_bPostureChanging;
int g_iOffs_ZombieBotBody__m_arousal;
Handle g_hCall_SetDesiredPosture;

enum PostureType
{
	STAND,
	CROUCH,
	SIT,
	CRAWL,
	LIE
};

enum ArousalType
{
	NEUTRAL,
	ALERT,
	INTENSE
};

methodmap ZombieBotBody
{
	public void SetDesiredPosture(PostureType posture) {
		SDKCall(g_hCall_SetDesiredPosture, this, posture);
	}
	property PostureType m_desiredPosture {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_ZombieBotBody__m_desiredPosture), NumberType_Int32); }
	}
	property PostureType m_posture {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_ZombieBotBody__m_posture), NumberType_Int32); }
	}
	property bool m_bPostureChanging {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_ZombieBotBody__m_bPostureChanging), NumberType_Int8); }
	}
	property ArousalType m_arousal {
		public set(ArousalType arousal) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_ZombieBotBody__m_arousal), arousal, NumberType_Int32); }
	}
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper(GAMEDATA_FILE);
	
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "ZombieBotBody::SetDesiredPosture"))
		SetFailState("Missing signature \"ZombieBotBody::SetDesiredPosture\"");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hCall_SetDesiredPosture = EndPrepSDKCall();
	
	g_iOffs_Infected__m_body = gd.GetOffsetOrFail("Infected::m_body");
	g_iOffs_ZombieBotBody__m_desiredPosture = gd.GetOffsetOrFail("ZombieBotBody::m_desiredPosture");
	g_iOffs_ZombieBotBody__m_posture = gd.GetOffsetOrFail("ZombieBotBody::m_posture");
	g_iOffs_ZombieBotBody__m_bPostureChanging = gd.GetOffsetOrFail("ZombieBotBody::m_bPostureChanging");
	g_iOffs_ZombieBotBody__m_arousal = gd.GetOffsetOrFail("ZombieBotBody::m_arousal");
	
	delete gd;
}

public void OnActionCreated(BehaviorAction action, int actor, const char[] name)
{
	if (name[0] == 'I' && strcmp(name, "InfectedFlee") == 0)
	{
		action.OnStart = InfectedFlee__OnStart;
	}
}

Action InfectedFlee__OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	// excites the common since he's escaping from something dangerous
	Infected__GetBodyInterface(actor).m_arousal = INTENSE;
	
	return action.SuspendFor(MakeInfectedChangeStandPosture());
}

BehaviorAction MakeInfectedChangeStandPosture()
{
	BehaviorAction action = ActionsManager.Create("InfectedChangePosture");
	
	action.OnStart = InfectedChangeStandPosture__OnStart;
	action.OnUpdate = InfectedChangeStandPosture__OnUpdate;
	
	return action;
}

Action InfectedChangeStandPosture__OnStart(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	Infected__GetBodyInterface(actor).SetDesiredPosture(STAND);
	return action.Continue();
}

Action InfectedChangeStandPosture__OnUpdate(BehaviorAction action, int actor, float interval, ActionResult result)
{
	ZombieBotBody body = Infected__GetBodyInterface(actor);
	if (body.m_posture == body.m_desiredPosture)
	{
		return action.Done();
	}
	else if (!body.m_bPostureChanging)
	{
		body.SetDesiredPosture(STAND);
	}
	return action.Continue();
}

ZombieBotBody Infected__GetBodyInterface(int infected)
{
	return view_as<ZombieBotBody>(GetEntData(infected, g_iOffs_Infected__m_body, 4));
}
