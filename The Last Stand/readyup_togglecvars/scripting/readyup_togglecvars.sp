#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <readyup>

#define PLUGIN_VERSION "1.6"

public Plugin myinfo = 
{
	name = "[L4D2] Ready-Up Toggle Cvars",
	author = "Forgetest",
	description = "Customize your own Ready-Up state.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

enum struct CvarValue
{
	char on[128];
	char off[128];
}
StringMap g_smToggleCvars;
StringMap g_smConfigToggleCvars;

bool g_bConfigExecuted;
ConVar g_cvVarsConfig;

public void OnPluginStart()
{
	g_smToggleCvars = new StringMap();
	g_smConfigToggleCvars = new StringMap();

	g_cvVarsConfig = CreateConVar(
		"readyup_togglecvars_config_path",
		"../../cfg/readyup_togglecvars.cfg",
		"Path to config for toggle cvars.\nFormat: \"<cvar> <value_on> <value_off>\"");
	g_cvVarsConfig.AddChangeHook(CvarChg_Config);
	
	RegServerCmd("sm_readyup_add_togglecvars", Cmd_AddToggleCvars);
	RegServerCmd("sm_readyup_remove_togglecvars", Cmd_RemoveToggleCvars);
	RegServerCmd("sm_readyup_clear_togglecvars", Cmd_ClearToggleCvars);
}

void CvarChg_Config(ConVar convar, const char[] oldValue, const char[] newValue)
{
	LoadConfig();
}

public void OnPluginEnd()
{
	OnRoundIsLive();
}

public void OnMapStart()
{
	g_bConfigExecuted = false;
}

public void OnMapEnd()
{
	g_bConfigExecuted = false;
}

public void OnConfigsExecuted()
{
	g_bConfigExecuted = true;

	LoadConfig();
	OnReadyUpInitiate();
}

bool ReadToggleCvarToken(const char[] str, char[] cvar, int cvar_length, CvarValue values)
{
	char buffers[3][128];

	if (3 != ExplodeString(str, " ", buffers, sizeof(buffers), sizeof(buffers[])))
		return false;
	
	for (int i = 0; i < sizeof(buffers); ++i)
		StripQuotes(buffers[i]);

	strcopy(cvar, cvar_length, buffers[0]);
	strcopy(values.on, sizeof(values.on), buffers[1]);
	strcopy(values.off, sizeof(values.off), buffers[2]);

	return true;
}

void LoadConfig()
{
	if (g_bConfigExecuted && IsInReady())
		DoToggleCvars(g_smConfigToggleCvars, false);

	g_smConfigToggleCvars.Clear();

	char buffer[512], path[PLATFORM_MAX_PATH];
	g_cvVarsConfig.GetString(buffer, sizeof(buffer));
	BuildPath(Path_SM, path, sizeof(path), buffer);

	File f = OpenFile(path, "r");
	if (!f)
		return;

	char cvar[128];
	CvarValue values;

	while (!f.EndOfFile())
	{
		f.ReadLine(buffer, sizeof(buffer));

		if (ReadToggleCvarToken(buffer, cvar, sizeof(cvar), values))
		{
			g_smConfigToggleCvars.SetArray(cvar, values, sizeof(values));
			PrintToServer("[ReadyUp ToggleCvars] Added from config: %s <%s|%s>", cvar, values.on, values.off);
		}
	}

	delete f;

	if (g_bConfigExecuted && IsInReady())
		DoToggleCvars(g_smConfigToggleCvars, true);
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
	
	CvarValue v;
	GetCmdArg(2, v.on, sizeof(v.on));
	GetCmdArg(3, v.off, sizeof(v.off));
	StripQuotes(v.on);
	StripQuotes(v.off);
	
	g_smToggleCvars.SetArray(sCvar, v, sizeof(v));
	PrintToServer("[ReadyUp ToggleCvars] Added: %s <%s|%s>", sCvar, v.on, v.off);
	
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
	if (g_smToggleCvars.Remove(sCvar))
	{
		PrintToServer("[ReadyUp ToggleCvars] Removed: %s", sCvar);
	}
}

public void OnReadyUpInitiate()
{
	if (!g_bConfigExecuted)
		return;

	RequestFrame(NextFrame_OnReadyUpInitiate);
}

void NextFrame_OnReadyUpInitiate()
{
	if (!IsInReady())
		return;

	DoToggleCvars(g_smToggleCvars, true);
	DoToggleCvars(g_smConfigToggleCvars, true);
}

public void OnRoundIsLive()
{
	DoToggleCvars(g_smToggleCvars, false);
	DoToggleCvars(g_smConfigToggleCvars, false);
}

void DoToggleCvars(StringMap lookup, bool enable)
{
	char sCvar[128];
	CvarValue v;
	ConVar cvar;

	StringMapSnapshot ss = lookup.Snapshot();
	for (int i = 0; i < ss.Length; ++i)
	{
		ss.GetKey(i, sCvar, sizeof(sCvar));
		if ((cvar = FindConVar(sCvar)) != null)
		{
			if (lookup.GetArray(sCvar, v, sizeof(v)))
			{
				cvar.SetString(enable ? v.on : v.off);
			}
		}
	}
	
	delete ss;
}