#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <actions>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D2] Common Hate To See You",
	author = "Forgetest",
	description = "Now you are the true zombies.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

methodmap EHANDLE {
    public int Get() {
    #if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 12 && SOURCEMOD_V_REV >= 6964
        return LoadEntityFromHandleAddress(view_as<Address>(this));
    #else
        static int s_iRandomOffsetToAnEHandle = -1;
        if (s_iRandomOffsetToAnEHandle == -1)
            s_iRandomOffsetToAnEHandle = FindSendPropInfo("CWorld", "m_hOwnerEntity");
        
        int temp = GetEntData(0, s_iRandomOffsetToAnEHandle, 4);
        SetEntData(0, s_iRandomOffsetToAnEHandle, this, 4);
        int result = GetEntDataEnt2(0, s_iRandomOffsetToAnEHandle);
        SetEntData(0, s_iRandomOffsetToAnEHandle, temp, 4);
        
        return result;
    #endif
    }
}

enum InfectedFlag
{
	// random naming by me
	INFECTED_FLAG_FALLEN_FLEE			= 0x400,
};
int g_iOffs_m_nInfectedFlags;

bool g_bFleeOnContact;

public void OnPluginStart()
{
	g_iOffs_m_nInfectedFlags = FindSendPropInfo("Infected", "m_nFallenFlags") - 4;
	
	CreateConVarHook("z_never_fight_on_contact",
				"1",
				"Common keeps fleeing after contacting survivors instead of attacking them.",
				FCVAR_CHEAT,
				true, 0.0, true, 1.0,
				CvarChg_FleeOnContact);
}

void CvarChg_FleeOnContact(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bFleeOnContact = convar.BoolValue;
}

public void OnActionCreated(BehaviorAction action, int actor, const char[] name)
{
	if (name[0] == 'I')
	{
		if (strncmp(name, "Infected", 8) == 0)
		{
			AddInfectedFlag(actor, INFECTED_FLAG_FALLEN_FLEE);
		}
		
		if (strcmp(name, "InfectedAttack") == 0)
		{
			action.OnStartPost = InfectedAttack__OnStartPost;
		}
		else if (strcmp(name, "InfectedFlee") == 0)
		{
			action.OnContact = InfectedFlee__OnContact;
			action.OnContactPost = InfectedFlee__OnContactPost;
		}
	}
}

Action InfectedAttack__OnStartPost(BehaviorAction action, int actor, BehaviorAction priorAction, ActionResult result)
{
	if (!action.GetUserData("InfectedFlee__OnContactPost"))
	{
		RequestFrame(NextFrame_FakeInjure, EntIndexToEntRef(actor));
	}
	
	return Plugin_Continue;
}

void NextFrame_FakeInjure(int entRef)
{
	int entity = EntRefToEntIndex(entRef);
	if (!IsValidEdict(entity))
		return;
	
	BehaviorAction action = ActionsManager.GetAction(entity, "InfectedAttack");
	if (action == INVALID_ACTION)
		return;
	
	EHANDLE hTarget = action.Get(52, NumberType_Int32);
	int client = hTarget.Get();
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return;
	
	if (GetClientTeam(client) != 2)
		return;
	
	// fakes OnInjured event
	SDKHooks_TakeDamage(entity, client, client, 0.0, .bypassHooks = true);
}

Action InfectedFlee__OnContact(BehaviorAction action, int actor, int entity, Address trace, ActionDesiredResult result)
{
	if (g_bFleeOnContact)
	{
		action.TryToSustain();
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action InfectedFlee__OnContactPost(BehaviorAction action, int actor, int entity, Address trace, ActionDesiredResult result)
{
	if (!g_bFleeOnContact && result.action != INVALID_ACTION)
	{
		result.action.SetUserData("InfectedFlee__OnContactPost", 1);
	}
	return Plugin_Continue;
}

void AddInfectedFlag(int entity, InfectedFlag flags)
{
	SetEntData(entity, g_iOffs_m_nInfectedFlags, GetEntData(entity, g_iOffs_m_nInfectedFlags) | view_as<int>(flags));
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