#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <readyup>

StringMap g_smToggleCvars;

enum struct ToggleVal_t
{
	char sOn[64];
	char sOff[64];
}

public void OnPluginStart()
{
	g_smToggleCvars = new StringMap();
	
	RegServerCmd("sm_readyup_add_togglecvars", Cmd_AddToggleCvars);
	RegServerCmd("sm_readyup_remove_togglecvars", Cmd_RemoveToggleCvars);
	RegServerCmd("sm_readyup_clear_togglecvars", Cmd_ClearToggleCvars);
}

Action Cmd_AddToggleCvars(int args)
{
	if (args != 3)
	{
		PrintToServer("Usage: sm_readyup_add_togglecvars <cvar> <value_on> <value_off>");
		return Plugin_Handled;
	}
	
	char sCvar[128];
	GetCmdArg(1, sCvar, sizeof(sCvar));
	
	ToggleVal_t ToggleVal;
	GetCmdArg(2, ToggleVal.sOn, sizeof(ToggleVal.sOn));
	GetCmdArg(3, ToggleVal.sOff, sizeof(ToggleVal.sOff));
	
	g_smToggleCvars.SetArray(sCvar, ToggleVal, sizeof(ToggleVal));
	PrintToServer("[ReadyUp ToggleCvars] Added: %s <%s|%s>", sCvar, ToggleVal.sOn, ToggleVal.sOff);
	
	return Plugin_Handled;
}

Action Cmd_RemoveToggleCvars(int args)
{
	if (args != 1)
	{
		PrintToServer("Usage: sm_readyup_remove_togglecvars <cvar>");
		return Plugin_Handled;
	}
	
	char sCvar[128];
	GetCmdArg(1, sCvar, sizeof(sCvar));
	
	g_smToggleCvars.Remove(sCvar);
	PrintToServer("[ReadyUp ToggleCvars] Removed: %s", sCvar);
	
	return Plugin_Handled;
}

Action Cmd_ClearToggleCvars(int args)
{
	g_smToggleCvars.Clear();
	PrintToServer("[ReadyUp ToggleCvars] Cleared all entries.");
	
	return Plugin_Handled;
}

public void OnReadyUpInitiate()
{
	StringMapSnapshot snapshot = g_smToggleCvars.Snapshot();
	
	char sCvar[128];
	ConVar cvar;
	ToggleVal_t ToggleVal;
	for (int i = 0; i < snapshot.Length; ++i)
	{
		snapshot.GetKey(i, sCvar, sizeof(sCvar));
		if ((cvar = FindConVar(sCvar)) != null)
		{
			g_smToggleCvars.GetArray(sCvar, ToggleVal, sizeof(ToggleVal));
			cvar.SetString(ToggleVal.sOn);
		}
	}
	
	delete snapshot;
}

public void OnRoundIsLive()
{
	StringMapSnapshot snapshot = g_smToggleCvars.Snapshot();
	
	char sCvar[128];
	ConVar cvar;
	ToggleVal_t ToggleVal;
	for (int i = 0; i < snapshot.Length; ++i)
	{
		snapshot.GetKey(i, sCvar, sizeof(sCvar));
		if ((cvar = FindConVar(sCvar)) != null)
		{
			g_smToggleCvars.GetArray(sCvar, ToggleVal, sizeof(ToggleVal));
			cvar.SetString(ToggleVal.sOff);
		}
	}
	
	delete snapshot;
}