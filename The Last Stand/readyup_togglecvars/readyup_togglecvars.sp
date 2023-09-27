#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <readyup>

#define PLUGIN_VERSION "1.3"

public Plugin myinfo = 
{
	name = "[L4D2] Ready-Up Toggle Cvars",
	author = "Forgetest",
	description = "Customize your own Ready-Up state.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

StringMap g_smToggleCvars;

public void OnPluginStart()
{
	g_smToggleCvars = new StringMap();
	
	RegServerCmd("sm_readyup_add_togglecvars", Cmd_AddToggleCvars);
	RegServerCmd("sm_readyup_remove_togglecvars", Cmd_RemoveToggleCvars);
	RegServerCmd("sm_readyup_clear_togglecvars", Cmd_ClearToggleCvars);
}

public void OnPluginEnd()
{
	OnRoundIsLive();
	Cmd_ClearToggleCvars(0);
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
	StripQuotes(sCvar);
	
	DataPack dp = new DataPack();
	
	char sOn[64], sOff[64];
	GetCmdArg(2, sOn, sizeof(sOn));
	StripQuotes(sOn);
	dp.WriteString(sOn);
	GetCmdArg(3, sOff, sizeof(sOff));
	StripQuotes(sOff);
	dp.WriteString(sOff);
	
	g_smToggleCvars.SetValue(sCvar, dp);
	PrintToServer("[ReadyUp ToggleCvars] Added: %s <%s|%s>", sCvar, sOn, sOff);
	
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
	StripQuotes(sCvar);
	RemoveToggleCvar(sCvar);
	
	return Plugin_Handled;
}

Action Cmd_ClearToggleCvars(int args)
{
	StringMapSnapshot ss = g_smToggleCvars.Snapshot();
	
	char sCvar[128];
	for (int i = 0; i < ss.Length; ++i)
	{
		ss.GetKey(i, sCvar, sizeof(sCvar));
		RemoveToggleCvar(sCvar);
	}
	PrintToServer("[ReadyUp ToggleCvars] Cleared all entries.");
	
	delete ss;
	
	return Plugin_Handled;
}

void RemoveToggleCvar(const char[] sCvar)
{
	DataPack dp;
	if (g_smToggleCvars.GetValue(sCvar, dp))
	{
		delete dp;
		g_smToggleCvars.Remove(sCvar);
		PrintToServer("[ReadyUp ToggleCvars] Removed: %s", sCvar);
	}
}

public void OnReadyUpInitiate()
{
	StringMapSnapshot ss = g_smToggleCvars.Snapshot();
	
	char buffer[128];
	for (int i = 0; i < ss.Length; ++i)
	{
		ss.GetKey(i, buffer, sizeof(buffer));
		for (ConVar cvar = FindConVar(buffer); cvar != null;)
		{
			DataPack dp;
			if (g_smToggleCvars.GetValue(buffer, dp))
			{
				dp.ReadString(buffer, sizeof(buffer));
				cvar.SetString(buffer);
			}
			break;
		}
	}
	
	delete ss;
}

public void OnRoundIsLive()
{
	StringMapSnapshot ss = g_smToggleCvars.Snapshot();
	
	char buffer[128];
	for (int i = 0; i < ss.Length; ++i)
	{
		ss.GetKey(i, buffer, sizeof(buffer));
		for (ConVar cvar = FindConVar(buffer); cvar != null;)
		{
			DataPack dp;
			if (g_smToggleCvars.GetValue(buffer, dp))
			{
				dp.ReadString(buffer, sizeof(buffer));
				dp.ReadString(buffer, sizeof(buffer));
				cvar.SetString(buffer);
			}
			break;
		}
	}
	
	delete ss;
}