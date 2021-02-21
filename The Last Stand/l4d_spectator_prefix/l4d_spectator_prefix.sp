#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <readyup>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2.4"

public Plugin myinfo = 
{
	name = "Spectator Prefix",
	author = "Forgetest & Harry Potter",
	description = "Brand-fresh views in Server Browser where spectators are clear to identify.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/fbef0102/"
};

enum L4D2_Team
{
    L4D2Team_Spectator = 1,
    L4D2Team_Survivor,
    L4D2Team_Infected
};

ConVar g_cvPrefixType;
ConVar g_cvPrefixTypeCaster;
ConVar g_cvSupressMsg;

char g_sPrefixType[32];
char g_sPrefixTypeCaster[32];
bool g_bSupress;

StringMap g_triePrefixed;

bool readyupAvailable;

public void OnPluginStart()
{
	g_cvPrefixType =		CreateConVar("sp_prefix_type",			"(S)", "Determine your preferred type of Spectator Prefix");
	g_cvPrefixTypeCaster =	CreateConVar("sp_prefix_type_caster",	"(C)", "Determine your preferred type of Spectator Prefix");
	g_cvSupressMsg =		CreateConVar("sp_supress_msg", "1", "Determine whether to supress message of prefixing name", _, true, 0.0, true, 1.0);
	
	g_cvPrefixType.GetString(g_sPrefixType, sizeof(g_sPrefixType));
	g_cvPrefixTypeCaster.GetString(g_sPrefixTypeCaster, sizeof(g_sPrefixTypeCaster));
	g_bSupress = g_cvSupressMsg.BoolValue;
	
	g_cvPrefixType.AddChangeHook(OnConVarChanged);
	g_cvPrefixTypeCaster.AddChangeHook(OnConVarChanged);
	g_cvSupressMsg.AddChangeHook(OnConVarChanged);
	
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
		char buffer[64], authId[64];
		for (int i = 0; i < length; i++)
		{
			snap.GetKey(i, buffer, sizeof(buffer));
			for (int j = 1; j <= MaxClients; j++)
			{
				if (IsClientAndInGame(j))
				{
					GetClientAuthId(j, AuthId_Steam2, buffer, sizeof(buffer));
					if (StrEqual(authId, buffer)) RemovePrefix(j);
				}
			}
		}
		delete snap;
	}
}

public void OnAllPluginsLoaded() { readyupAvailable = LibraryExists("readyup"); }
public void OnLibraryAdded(const char[] name) { if (StrEqual(name, "readyup")) readyupAvailable = true; }
public void OnLibraryRemoved(const char[] name) { if (StrEqual(name, "readyup")) readyupAvailable = false; }

public void OnMapStart() { g_triePrefixed.Clear(); }

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvPrefixType.GetString(g_sPrefixType, sizeof(g_sPrefixType));
	g_cvPrefixTypeCaster.GetString(g_sPrefixTypeCaster, sizeof(g_sPrefixTypeCaster));
	g_bSupress = g_cvSupressMsg.BoolValue;
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
	
	delete pack;
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
	char buffer[64], name[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
	
	if (newname[0] != '\0') strcopy(name, sizeof(name), newname);
	else GetClientName(client, name, sizeof(name));
	
	g_triePrefixed.SetString(buffer, name, true);
	
	if (readyupAvailable && IsClientCaster(client))
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
	char buffer[64], name[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
	if (g_triePrefixed.GetString(buffer, name, sizeof(name))) // in case
	{
		g_triePrefixed.Remove(buffer);
		CS_SetClientName(client, name);
	}
}

void CS_SetClientName(int client, const char[] name)
{
	char oldname[MAX_NAME_LENGTH];
	GetClientName(client, oldname, sizeof(oldname));
	
	SetClientInfo(client, "name", name);
	SetEntPropString(client, Prop_Data, "m_szNetname", name);
	
	if (g_bSupress)
		return;

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
