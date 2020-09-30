#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <readyup>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2.3"

enum L4D2_Team
{
    L4D2Team_Spectator = 1,
    L4D2Team_Survivor,
    L4D2Team_Infected
};

char g_sPrefixType[32];
char g_sPrefixTypeCaster[32];

ConVar g_cvPrefixType;
ConVar g_cvPrefixTypeCaster;
ConVar g_cvSupressMsg;

StringMap g_triePrefixed;

bool readyupAvailable;

public Plugin myinfo = 
{
	name = "Spectator Prefix",
	author = "Forgetest & Harry Potter",
	description = "Brand-fresh views in Server Browser where spectators are clear to identify.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/fbef0102/"
};

public void OnPluginStart()
{
	g_cvPrefixType =		CreateConVar("sp_prefix_type",			"(S)", "Determine your preferred type of Spectator Prefix");
	g_cvPrefixTypeCaster =	CreateConVar("sp_prefix_type_caster",	"(C)", "Determine your preferred type of Spectator Prefix");
	g_cvSupressMsg =		CreateConVar("sp_supress_msg", "1", "Determine whether to supress message of prefixing name", _, true, 0.0, true, 1.0);
	
	g_cvPrefixType.GetString(g_sPrefixType, sizeof(g_sPrefixType));
	g_cvPrefixTypeCaster.GetString(g_sPrefixTypeCaster, sizeof(g_sPrefixTypeCaster));
	
	g_cvPrefixType.AddChangeHook(OnConVarChanged);
	g_cvPrefixTypeCaster.AddChangeHook(OnConVarChanged);
	
	g_triePrefixed = new StringMap();
	
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_changename", Event_NameChanged);
}

public void OnPluginEnd()
{
	if (g_triePrefixed.Size)
	{
		StringMapSnapshot snap = g_triePrefixed.Snapshot();
		
		int length = snap.Length;
		char buffer[8];
		for (int i = 0; i < length; i++)
		{
			snap.GetKey(i, buffer, sizeof(buffer));
			RemovePrefix(StringToInt(buffer));
		}
		delete snap;
	}
	delete g_triePrefixed;
}

public void OnAllPluginsLoaded() { readyupAvailable = LibraryExists("readyup"); }
public void OnLibraryAdded(const char[] name) { if (StrEqual(name, "readyup")) readyupAvailable = true; }
public void OnLibraryRemoved(const char[] name) { if (StrEqual(name, "readyup")) readyupAvailable = false; }

public void OnMapStart() { g_triePrefixed.Clear(); }

//public void OnClientDisconnect(int client) { if (!IsFakeClient(client)) RemovePrefix(client); }

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvPrefixType.GetString(g_sPrefixType, sizeof(g_sPrefixType));
	g_cvPrefixTypeCaster.GetString(g_sPrefixTypeCaster, sizeof(g_sPrefixTypeCaster));
}

public void Event_NameChanged(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!IsClientAndInGame(client)
		|| IsFakeClient(client)
		|| view_as<L4D2_Team>(GetClientTeam(client)) != L4D2Team_Spectator)
		return;
			
	char newname[MAX_NAME_LENGTH];
	event.GetString("newname", newname, sizeof(newname));
	
	// Use a delay function to prevent issue
	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteString(newname);
	
	RequestFrame(DelayStuff, pack);
}

void DelayStuff(DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	
	if (IsClientInGame(client))
	{
		char name[MAX_NAME_LENGTH];
		pack.ReadString(name, sizeof(name));
		
		if (!HasPrefix(name)) AddPrefix(client, name);
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!IsClientAndInGame(client)
		|| IsFakeClient(client)
		|| event.GetBool("disconnect"))
		return;
		
	L4D2_Team newteam = view_as<L4D2_Team>(GetEventInt(event, "team"));
	L4D2_Team oldteam = view_as<L4D2_Team>(GetEventInt(event, "oldteam"));
	
	if (newteam == L4D2Team_Spectator) AddPrefix(client);
	else if (oldteam == L4D2Team_Spectator) RemovePrefix(client);
}

void AddPrefix(int client, const char[] newname = "")
{
	bool supress = g_cvSupressMsg.BoolValue;
	
	char buffer[8], name[MAX_NAME_LENGTH];
	IntToString(client, buffer, sizeof(buffer));
	
	if (newname[0] != '\0') strcopy(name, sizeof(name), newname);
	else GetClientName(client, name, sizeof(name));
	
	g_triePrefixed.SetString(buffer, name, true);
	
	if (readyupAvailable && IsClientCaster(client))
	{
		Format(name, sizeof(name), "%s %s", g_sPrefixTypeCaster, name);
		CS_SetClientName(client, name, supress);
	}
	else
	{
		Format(name, sizeof(name), "%s %s", g_sPrefixType, name);
		CS_SetClientName(client, name, supress);
	}
}

void RemovePrefix(int client)
{
	bool supress = g_cvSupressMsg.BoolValue;
	
	char buffer[8], name[MAX_NAME_LENGTH];
	IntToString(client, buffer, sizeof(buffer));
	g_triePrefixed.GetString(buffer, name, sizeof(name));
	g_triePrefixed.Remove(buffer);
	
	CS_SetClientName(client, name, supress);
}

void CS_SetClientName(int client, const char[] name, bool supress=false)
{
	char oldname[MAX_NAME_LENGTH];
	GetClientName(client, oldname, sizeof(oldname));
	
	SetClientInfo(client, "name", name);
	SetEntPropString(client, Prop_Data, "m_szNetname", name);
	
	if (supress)
		return;

	Event event = CreateEvent("player_changename");
	
	if (event != null)
	{
		event.SetInt("userid", GetClientUserId(client));
		event.SetString("oldname", oldname);
		event.SetString("newname", name);
		event.BroadcastDisabled = supress;
		event.Fire();
	}
	
	Handle msg = StartMessageAll("SayText2");
	
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

bool HasPrefix(const char[] name)
{
	return strncmp(name, g_sPrefixType, strlen(g_sPrefixType)) == 0 || strncmp(name, g_sPrefixTypeCaster, strlen(g_sPrefixTypeCaster)) == 0;
}

stock bool IsClientAndInGame(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		return IsClientInGame(client);
	}
	return false;
}
