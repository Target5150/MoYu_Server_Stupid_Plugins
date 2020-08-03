#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

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

native bool IsClientCaster(client);

public Plugin myinfo = 
{
	name = "Spectator Prefix, caster prefix",
	author = "Nana & Harry Potter",
	description = "when player in spec team, add prefix",
	version = "1.2.1",
	url = "https://steamcommunity.com/id/fbef0102/"
};

public void OnPluginStart()
{
	g_cvPrefixType = CreateConVar("sp_prefix_type", "(S)", "Determine your preferred type of Spectator Prefix");
	g_cvPrefixTypeCaster = CreateConVar("sp_prefix_type_caster", "(C)", "Determine your preferred type of Spectator Prefix");
	g_cvSupressMsg = CreateConVar("sp_supress_msg", "1", "Determine whether to supress message of name changing", _, true, 0.0, true, 1.0);
	
	g_cvPrefixType.GetString(g_sPrefixType, sizeof(g_sPrefixType));
	g_cvPrefixTypeCaster.GetString(g_sPrefixTypeCaster, sizeof(g_sPrefixTypeCaster));
	
	g_cvPrefixType.AddChangeHook(OnConVarChanged);
	g_cvPrefixTypeCaster.AddChangeHook(OnConVarChanged);
	
	g_triePrefixed = new StringMap();
	
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_changename", Event_NameChanged);
}

public void OnMapStart() { g_triePrefixed.Clear(); }

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvPrefixType.GetString(g_sPrefixType, sizeof(g_sPrefixType));
	g_cvPrefixTypeCaster.GetString(g_sPrefixTypeCaster, sizeof(g_sPrefixTypeCaster));
}

public void Event_NameChanged(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!IsClientAndInGame(client)
		|| IsFakeClient(client)
		|| view_as<L4D2_Team>(GetClientTeam(client)) != L4D2Team_Spectator)
		return;
	
	// Use a delay function to prevent issue
	RequestFrame(DelayStuff, client);
}

void DelayStuff(int client)
{
	if (IsClientInGame(client))
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		
		if (!HasPreFix(name)) AddPrefix(client);
	}
}

public void Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!IsClientAndInGame(client)
		|| IsFakeClient(client))
		return;
		
	L4D2_Team newteam = view_as<L4D2_Team>(GetEventInt(event, "team"));
	L4D2_Team oldteam = view_as<L4D2_Team>(GetEventInt(event, "oldteam"));
	
	if (newteam == L4D2Team_Spectator) AddPrefix(client);
	else if (oldteam == L4D2Team_Spectator) RemovePrefix(client);
}

void AddPrefix(int client, const char[] newname = "")
{
	bool supress = g_cvSupressMsg.BoolValue;
	
	char authId[64], name[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));
	
	if (newname[0] != '\0') strcopy(name, sizeof(name), newname);
	else GetClientName(client, name, sizeof(name));
	
	g_triePrefixed.SetString(authId, name, true);
	
	if (IsClientCaster(client))
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
	
	char authId[64], name[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));
	g_triePrefixed.GetString(authId, name, sizeof(name));
	g_triePrefixed.Remove(authId);
	
	CS_SetClientName(client, name, supress);
}

stock bool IsClientAndInGame(client)
{
	if (client > 0 && client <= MaxClients)
	{
		return IsClientInGame(client);
	}
	return false;
}

bool HasPreFix(const char[] name)
{
	return strncmp(name, g_sPrefixType, strlen(g_sPrefixType)) == 0 || strncmp(name, g_sPrefixTypeCaster, strlen(g_sPrefixTypeCaster)) == 0;
}

CS_SetClientName(int client, const char[] name, bool supress=false)
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
