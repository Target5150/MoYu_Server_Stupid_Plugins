#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <caster_system>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.6"

public Plugin myinfo = 
{
	name = "Spectator Prefix",
	author = "Forgetest & Harry Potter",
	description = "Brand-fresh views in Server Browser where spectators are clear to identify.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/fbef0102/"
};

// ===================================================================
// Variables
// ===================================================================

#define L4D2Team_None 0
#define L4D2Team_Spectator 1
#define L4D2Team_Survivor 2
#define L4D2Team_Infected 3

ConVar g_cvPrefixType;
ConVar g_cvPrefixTypeCaster;
ConVar g_cvSupressMsg;

char g_sPrefixType[32];
char g_sPrefixTypeCaster[32];
bool g_bSupress;

StringMap g_triePrefixed;

bool casterAvailable;
bool g_bLateLoad;

// ===================================================================
// Plugin Setup / Backup
// ===================================================================

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvPrefixType			= CreateConVar("sp_prefix_type",		"(S)",	"Determine your preferred type of Spectator Prefix", FCVAR_PRINTABLEONLY);
	g_cvPrefixTypeCaster 	= CreateConVar("sp_prefix_type_caster",	"(C)",	"Determine your preferred type of Spectator Prefix", FCVAR_PRINTABLEONLY);
	g_cvSupressMsg			= CreateConVar("sp_supress_msg",		"1",	"Determine whether to supress message of prefixing name", _, true, 0.0, true, 1.0);
	
	g_cvPrefixType.AddChangeHook(OnConVarChanged);
	g_cvPrefixTypeCaster.AddChangeHook(OnConVarChanged);
	g_cvSupressMsg.AddChangeHook(OnConVarChanged);
	
	GetCvars();
	
	g_triePrefixed = new StringMap();
	
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_changename", Event_NameChanged);
	
	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == L4D2Team_Spectator && !IsFakeClient(i))
			{
				AddPrefix(i);
			}
		}
	}
}

public void OnPluginEnd()
{
	if (g_triePrefixed.Size)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == L4D2Team_Spectator) RemovePrefix(i);
		}
	}
}

// ===================================================================
// Ready Up Available
// ===================================================================

public void OnAllPluginsLoaded() { casterAvailable = LibraryExists("caster_system"); }
public void OnLibraryAdded(const char[] name) { if (StrEqual(name, "caster_system")) casterAvailable = true; }
public void OnLibraryRemoved(const char[] name) { if (StrEqual(name, "caster_system")) casterAvailable = false; }

// ===================================================================
// Clear Up
// ===================================================================

public void OnMapStart() { g_triePrefixed.Clear(); }

// ===================================================================
// Get ConVars
// ===================================================================

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) { GetCvars(); }

void GetCvars()
{
	g_cvPrefixType.GetString(g_sPrefixType, sizeof(g_sPrefixType));
	g_cvPrefixTypeCaster.GetString(g_sPrefixTypeCaster, sizeof(g_sPrefixTypeCaster));
	g_bSupress = g_cvSupressMsg.BoolValue;
}

// ===================================================================
// Events
// ===================================================================

void Event_NameChanged(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	
	if (!client 
		|| !IsClientInGame(client)
		|| IsFakeClient(client)
		|| GetClientTeam(client) != L4D2Team_Spectator)
		return;
	
	char newname[MAX_NAME_LENGTH];
	event.GetString("newname", newname, sizeof(newname));
	
	// Use a delay function to prevent issue
	DataPack dp = new DataPack();
	dp.WriteCell(userid);
	dp.WriteString(newname);
	
	RequestFrame(OnNextFrame, dp);
}

void OnNextFrame(DataPack dp)
{
	dp.Reset();
	
	int client = GetClientOfUserId(dp.ReadCell());
	
	if (client)
	{
		char name[MAX_NAME_LENGTH];
		dp.ReadString(name, sizeof(name));
		AddPrefix(client, name);
	}
	
	delete dp;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!client || !IsClientInGame(client))
		return;
	
	if (IsFakeClient(client))
		return;
	
	int newteam = event.GetInt("team");
	int oldteam = event.GetInt("oldteam");
	if (newteam == oldteam)
		return;
	
	if (newteam == L4D2Team_Spectator) AddPrefix(client);
	else if (oldteam == L4D2Team_Spectator) RemovePrefix(client);
}

// ===================================================================
// Prefix Methods
// ===================================================================

void AddPrefix(int client, const char[] newname = "")
{
	char authId[64];
	if (!GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId)))
		return;
	
	if (HasPrefix(authId))
		return;
	
	char name[MAX_NAME_LENGTH];
	if (strlen(newname) > 0)
		strcopy(name, sizeof(name), newname);
	else
		GetEntPropString(client, Prop_Data, "m_szNetname", name, sizeof(name));
	
	g_triePrefixed.SetString(authId, name, true);
	
	if (casterAvailable && IsClientCaster(client))
	{
		Format(name, sizeof(name), "%s %s", g_sPrefixTypeCaster, name);
		CS_SetClientName(client, name);
	}
	else
	{
		Format(name, sizeof(name), "%s %s", g_sPrefixType, name);
		CS_SetClientName(client, name);
	}
}

void RemovePrefix(int client)
{
	char authId[64];
	if (!GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId)))
		return;
	
	char name[MAX_NAME_LENGTH];
	if (g_triePrefixed.GetString(authId, name, sizeof(name)))
	{
		g_triePrefixed.Remove(authId);
		CS_SetClientName(client, name);
	}
}

void CS_SetClientName(int client, const char[] name)
{
	SetClientInfo(client, "name", name);
	SetEntPropString(client, Prop_Data, "m_szNetname", name);
	
	if (g_bSupress)
		return;

	char oldname[MAX_NAME_LENGTH];
	GetClientName(client, oldname, sizeof(oldname));
	
	Event event = CreateEvent("player_changename");
	
	if (event != null)
	{
		event.SetInt("userid", GetClientUserId(client));
		event.SetString("oldname", oldname);
		event.SetString("newname", name);
		event.BroadcastDisabled = g_bSupress;
		event.Fire();
	}
	
	BfWrite msg = UserMessageToBfWrite(StartMessageAll("SayText2"));
	
	if (msg != null)
	{
		BfWriteByte(msg, client);
		BfWriteByte(msg, true);
		BfWriteString(msg, "#Cstrike_Name_Change");
		BfWriteString(msg, oldname);
		BfWriteString(msg, name);
		EndMessage();
	}
}

// ===================================================================
// Helpers
// ===================================================================

bool HasPrefix(const char[] auth)
{
	return g_triePrefixed.ContainsKey(auth);
}
