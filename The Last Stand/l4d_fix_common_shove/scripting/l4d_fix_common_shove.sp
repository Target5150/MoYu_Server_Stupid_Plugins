#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks_anim>
#include <actions>

#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "1.4.2"

public Plugin myinfo = 
{
	name = "[L4D & 2] Fix Common Shove",
	author = "Forgetest",
	description = "Fix commons being immune to shoves when crouching, falling and landing.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

bool g_bLeft4Dead2;

enum ActivityType 
{ 
	MOTION_CONTROLLED_XY	= 0x0001,	// XY position and orientation of the bot is driven by the animation.
	MOTION_CONTROLLED_Z		= 0x0002,	// Z position of the bot is driven by the animation.
	ACTIVITY_UNINTERRUPTIBLE= 0x0004,	// activity can't be changed until animation finishes
	ACTIVITY_TRANSITORY		= 0x0008,	// a short animation that takes over from the underlying animation momentarily, resuming it upon completion
	ENTINDEX_PLAYBACK_RATE	= 0x0010,	// played back at different rates based on entindex
};

enum PostureType
{
	STAND,
	CROUCH,
	SIT,
	CRAWL,
	LIE
};

Handle g_hCall_MyNextBotPointer;
INextBot MyNextBotPointer(int entity)
{
	return SDKCall(g_hCall_MyNextBotPointer, entity);
}

Handle g_hCall_GetBodyInterface;
Handle g_hCall_GetLocomotionInterface;
methodmap INextBot
{
	public IBody GetBodyInterface() {
		return SDKCall(g_hCall_GetBodyInterface, this);
	}

	public ILocomotion GetLocomotionInterface() {
		return SDKCall(g_hCall_GetLocomotionInterface, this);
	}
}

int g_offs_ZombieBotBody__m_activity;
int g_offs_ZombieBotBody__m_activityType;
int g_offs_ZombieBotBody__m_desiredPosture;
int g_offs_ZombieBotBody__m_actualPosture;
int g_offs_ZombieBotBody__m_isPostureChanging;
methodmap IBody {}
methodmap ZombieBotBody < IBody
{
	property int m_activity {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotBody__m_activity), NumberType_Int32); }
		public set(int act) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotBody__m_activity), act, NumberType_Int32); }
	}
	
	property ActivityType m_activityType {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotBody__m_activityType), NumberType_Int32); }
		public set(ActivityType flags) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotBody__m_activityType), flags, NumberType_Int32); }
	}

	property PostureType m_desiredPosture {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotBody__m_desiredPosture), NumberType_Int32); }
		public set(PostureType val) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotBody__m_desiredPosture), val, NumberType_Int32); }
	}

	property PostureType m_actualPosture {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotBody__m_actualPosture), NumberType_Int32); }
		public set(PostureType val) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotBody__m_actualPosture), val, NumberType_Int32); }
	}

	property bool m_isPostureChanging {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotBody__m_isPostureChanging), NumberType_Int8); }
		public set(bool val) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotBody__m_isPostureChanging), val, NumberType_Int8); }
	}
}

int g_offs_ZombieBotLocomotion__m_ladder;
methodmap ILocomotion {}
methodmap ZombieBotLocomotion
{
	property Address m_ladder {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotLocomotion__m_ladder), NumberType_Int32); }
		public set(Address p) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_offs_ZombieBotLocomotion__m_ladder), p, NumberType_Int32); }
	}
}

enum
{
	SHOVE_CROUCHING	= 1,
	SHOVE_FALLING	= (1 << 1),
	SHOVE_LANDING	= (1 << 2),
	SHOVE_CLIMBING	= (1 << 3),
	SHOVE_COURCHSIT	= (1 << 4),
};

int g_iShoveFlag;

enum PendingShoveState
{
	PendingShove_Invalid = 0,
	PendingShove_Yes,
	PendingShove_Callback,
};

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_fix_common_shove");

	SDKCallParamsWrapper params[] = {
		{SDKType_PlainOldData, SDKPass_Plain},
	};
	g_hCall_MyNextBotPointer = gd.CreateSDKCallOrFail(SDKCall_Entity, SDKConf_Virtual, "CBaseEntity::MyNextBotPointer", _, 0, true, params[0]);
	g_hCall_GetBodyInterface = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Virtual, "INextBot::GetBodyInterface", _, 0, true, params[0]);
	g_hCall_GetLocomotionInterface = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Virtual, "INextBot::GetLocomotionInterface", _, 0, true, params[0]);
	
	g_offs_ZombieBotLocomotion__m_ladder = gd.GetOffset("ZombieBotLocomotion::m_ladder");
	g_offs_ZombieBotBody__m_activity = gd.GetOffset("ZombieBotBody::m_activity");
	g_offs_ZombieBotBody__m_activityType = gd.GetOffset("ZombieBotBody::m_activityType");
	g_offs_ZombieBotBody__m_desiredPosture = gd.GetOffset("ZombieBotBody::m_desiredPosture");
	g_offs_ZombieBotBody__m_actualPosture = gd.GetOffset("ZombieBotBody::m_actualPosture");
	g_offs_ZombieBotBody__m_isPostureChanging = gd.GetOffset("ZombieBotBody::m_isPostureChanging");
	
	delete gd;

	g_bLeft4Dead2 = GetEngineVersion() == Engine_Left4Dead2;
	
	CreateConVarHook("l4d_common_shove_flag",
					"15",
					"Flag for fixing common shove.\n"
				...	"1 = Crouch, 2 = Falling, 4 = Landing, 8 = Climbing, 16 = Crouch to sit (requires 1=Crouch)",
					FCVAR_CHEAT,
					true, 0.0, false, 31.0,
					CvarChg_ShoveFlag);
}

void CvarChg_ShoveFlag(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iShoveFlag = convar.IntValue;
}

public void OnActionCreated(BehaviorAction action, int actor, const char[] name)
{
	if (name[0] == 'I' && strcmp(name, "InfectedShoved") == 0)
	{
		action.OnStart = InfectedShoved_OnStart;
		action.OnShoved = InfectedShoved_OnShoved;
		action.OnLandOnGroundPost = InfectedShoved_OnLandOnGroundPost;
	}
}

Action InfectedShoved_OnStart(BehaviorAction action, int actor, any priorAction, ActionResult result)
{
	// riverside1: L4D2_ACT_TERROR_FALL is an unrelated activity on L4D1, so the falling fix never ran here
	// riverside2: the game refuses the shove only when the common is on FALL AND off the ground
	// (InfectedShoved::OnStart, server.so 0x7c2360). One grounded with FALL left over waited
	// for a landing that never came, and InfectedShoved has no Update, so it stood frozen.
	if (view_as<ZombieBotBody>(MyNextBotPointer(actor).GetBodyInterface()).m_activity == (g_bLeft4Dead2 ? L4D2_ACT_TERROR_FALL : L4D1_ACT_TERROR_FALL) // falling check
		&& GetEntPropEnt(actor, Prop_Data, "m_hGroundEntity") == -1)
	{
		if (g_iShoveFlag & SHOVE_FALLING)
		{
			result.type = CONTINUE; // do not exit
			
			action.SetUserData("state", PendingShove_Yes); // for later use in "InfectedShoved_OnLandOnGroundPost"
			
			float direction[3], pos[3];
			direction[0] = action.Get(56, NumberType_Int32);
			direction[1] = action.Get(60, NumberType_Int32);
			direction[2] = action.Get(64, NumberType_Int32);
			GetEntPropVector(actor, Prop_Data, "m_vecAbsOrigin", pos);
			SubtractVectors(direction, pos, direction);
			
			action.SetUserDataVector("direction", direction);
			
			// almost certain that shove does nothing at the moment, just skip it
			return Plugin_Handled; 
		}
		
		return Plugin_Continue;
	}
	
	INextBot nb = MyNextBotPointer(actor);
	ZombieBotBody body = view_as<ZombieBotBody>(nb.GetBodyInterface());
	if ((g_iShoveFlag & SHOVE_CROUCHING) && body.m_actualPosture == CROUCH)
	{
		if (!body.m_isPostureChanging)
		{
			body.m_desiredPosture = body.m_actualPosture;
			body.m_isPostureChanging = true;
		}
		body.m_actualPosture = (g_iShoveFlag & SHOVE_COURCHSIT) ? SIT : STAND;
	}

	if (g_iShoveFlag & SHOVE_CLIMBING)
	{
		view_as<ZombieBotLocomotion>(nb.GetLocomotionInterface()).m_ladder = Address_Null;
	}
	
	if (g_iShoveFlag & SHOVE_LANDING
	  || (g_iShoveFlag & SHOVE_FALLING && action.GetUserData("state") == PendingShove_Callback))
	{
		ForceActivityInterruptible(actor); // if they happen to land on ground at the time, override
	}
	
	if (action.GetUserData("state") == PendingShove_Callback)
	{
		float direction[3], pos[3];
		action.GetUserDataVector("direction", direction);
		GetEntPropVector(actor, Prop_Data, "m_vecAbsOrigin", pos);
		AddVectors(pos, direction, pos);
		
		action.Set(56, pos[0], NumberType_Int32);
		action.Set(60, pos[1], NumberType_Int32);
		action.Set(64, pos[2], NumberType_Int32);
	}
	
	return Plugin_Continue;
}

Action InfectedShoved_OnShoved(BehaviorAction action, int actor, int entity, ActionDesiredResult result)
{
	if (GetEntPropEnt(actor, Prop_Data, "m_hGroundEntity") != -1) // falling check
	{
		ZombieBotBody body = view_as<ZombieBotBody>(MyNextBotPointer(actor).GetBodyInterface());

		if ((g_iShoveFlag & SHOVE_CROUCHING) && body.m_actualPosture == CROUCH)
		{
			if (!body.m_isPostureChanging)
			{
				body.m_desiredPosture = body.m_actualPosture;
				body.m_isPostureChanging = true;
			}
			body.m_actualPosture = (g_iShoveFlag & SHOVE_COURCHSIT) ? SIT : STAND;
		}
	}
	
	return Plugin_Continue;
}

Action InfectedShoved_OnLandOnGroundPost(BehaviorAction action, int actor, int entity, ActionDesiredResult result)
{
	if (~g_iShoveFlag & SHOVE_FALLING || action.GetUserData("state") != PendingShove_Yes)
		return Plugin_Continue;
	
	action.IsStarted = false; // trick the action into calling OnStart as if actor get shoved this frame
	action.SetUserData("state", PendingShove_Callback);
	
	ForceActivityInterruptible(actor); // if they happen to land on ground at the time, override
	
	return Plugin_Handled;
}

bool ForceActivityInterruptible(int infected)
{
	ZombieBotBody body = view_as<ZombieBotBody>(MyNextBotPointer(infected).GetBodyInterface());
	
	if (L4D_IsEngineLeft4Dead1()) // perhaps unnecessary
	{
		switch (body.m_activity)
		{
			case L4D1_ACT_TERROR_JUMP_LANDING,
				L4D1_ACT_TERROR_JUMP_LANDING_HARD,
				L4D1_ACT_TERROR_JUMP_LANDING_NEUTRAL,
				L4D1_ACT_TERROR_JUMP_LANDING_HARD_NEUTRAL: { }
			default: { return false; }
		}
	}
	else
	{
		switch (body.m_activity)
		{
			case L4D2_ACT_TERROR_JUMP_LANDING,
				L4D2_ACT_TERROR_JUMP_LANDING_HARD,
				L4D2_ACT_TERROR_JUMP_LANDING_NEUTRAL,
				L4D2_ACT_TERROR_JUMP_LANDING_HARD_NEUTRAL: { }
			default: { return false; }
		}
	}
	
	body.m_activityType &= ~ACTIVITY_UNINTERRUPTIBLE;
	return true;
}

stock bool IsInfected(int entity)
{
	if (entity > MaxClients && IsValidEdict(entity))
	{
		char cls[64];
		GetEdictClassname(entity, cls, sizeof(cls));
		return strcmp(cls, "infected") == 0;
	}
	return false;
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
