#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define TEAM_SPECTATOR 1


new String:g_sPrefixType[32];
new String:g_sPrefixTypeCaster[32];
new Handle:g_hPrefixType;
new Handle:g_hPrefixTypeCaster;
native bool:IsClientCaster(client);

public Plugin:myinfo = 
{
	name = "Spectator Prefix, caster prefix",
	author = "Nana & Harry Potter",
	description = "when player in spec team, add prefix",
	version = "1.2",
	url = "https://steamcommunity.com/id/fbef0102/"
};

public OnPluginStart()
{
	g_hPrefixType = CreateConVar("sp_prefix_type", "(S)", "Determine your preferred type of Spectator Prefix");
	g_hPrefixTypeCaster = CreateConVar("sp_prefix_type_caster", "(C)", "Determine your preferred type of Spectator Prefix");
	GetConVarString(g_hPrefixType, g_sPrefixType, sizeof(g_sPrefixType));
	GetConVarString(g_hPrefixTypeCaster, g_sPrefixTypeCaster, sizeof(g_sPrefixTypeCaster));
	HookConVarChange(g_hPrefixType, ConVarChange_PrefixType);
	HookConVarChange(g_hPrefixTypeCaster, ConVarChange_PrefixTypeCaster);
	
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_PostNoCopy);
	HookEvent("player_changename", Event_NameChanged);
}

public ConVarChange_PrefixType(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(g_hPrefixType, g_sPrefixType, sizeof(g_sPrefixType));
}

public ConVarChange_PrefixTypeCaster(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(g_hPrefixTypeCaster, g_sPrefixTypeCaster, sizeof(g_sPrefixTypeCaster));
}

public Action:Event_NameChanged(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.8,PlayerNameCheck,client,TIMER_FLAG_NO_MAPCHANGE);//延遲一秒檢查

	return Plugin_Continue;
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.8,PlayerNameCheck,client,TIMER_FLAG_NO_MAPCHANGE);//延遲一秒檢查

	return Plugin_Continue;
}

public Action:PlayerNameCheck(Handle:timer,any:client)
{
	if(!IsClientInGame(client) || IsFakeClient(client)) return Plugin_Continue;
	
	new team = GetClientTeam(client);
	
	//PrintToChatAll("client: %N - %d",client,team);
	if (IsClientAndInGame(client) && !IsFakeClient(client))
	{
		new String:sOldname[256],String:sNewname[256];
		GetClientName(client, sOldname, sizeof(sOldname));
		if (team == TEAM_SPECTATOR)
		{
			if(IsClientCaster(client))
			{
				if(CheckClientHasPreFix(sOldname))//先有旁觀prefix去掉
				{
					ReplaceString(sOldname, sizeof(sOldname), g_sPrefixType, "", true);
					strcopy(sNewname,sizeof(sOldname),sOldname);
					if(!CheckClientHasPreFixCaster(sNewname)) //後增加caster prefix
						Format(sNewname, sizeof(sNewname), "%s%s", g_sPrefixTypeCaster, sNewname);
						
					CS_SetClientName(client, sNewname);
				}
				else if(!CheckClientHasPreFixCaster(sOldname))//無旁觀prefix直接增加caster prefix
				{
					Format(sNewname, sizeof(sNewname), "%s%s", g_sPrefixTypeCaster, sOldname);
					CS_SetClientName(client, sNewname);
				}
			}
			else
			{
				if(CheckClientHasPreFixCaster(sOldname))//先有caster prefix去掉
				{
					ReplaceString(sOldname, sizeof(sOldname), g_sPrefixTypeCaster, "", true);
					strcopy(sNewname,sizeof(sOldname),sOldname);
					if(!CheckClientHasPreFix(sNewname)) //後增加spec prefix
						Format(sNewname, sizeof(sNewname), "%s%s", g_sPrefixType, sNewname);
						
					CS_SetClientName(client, sNewname);
				}
				else if(!CheckClientHasPreFix(sOldname))//無caster prefix直接增加旁觀prefix
				{
					Format(sNewname, sizeof(sNewname), "%s%s", g_sPrefixType, sOldname);
					CS_SetClientName(client, sNewname);
				}
			}
			//PrintToChatAll("sNewname: %s",sNewname);
		}
		else
		{
			if(CheckClientHasPreFix(sOldname)||CheckClientHasPreFixCaster(sOldname))
			{
				ReplaceString(sOldname, sizeof(sOldname), g_sPrefixType, "", true);
				ReplaceString(sOldname, sizeof(sOldname), g_sPrefixTypeCaster, "", true);
				strcopy(sNewname,sizeof(sOldname),sOldname);
				CS_SetClientName(client, sNewname);
				
				//PrintToChatAll("sNewname: %s",sNewname);
			}
		}
	}
	
	return Plugin_Continue;
}

stock bool:IsClientAndInGame(index)
{
	if (index > 0 && index < MaxClients)
	{
		return IsClientInGame(index);
	}
	return false;
}

bool:CheckClientHasPreFix(const String:sOldname[])
{
	for(new i =0 ; i< strlen(g_sPrefixType); ++i)
	{
		if(sOldname[i] == g_sPrefixType[i])
		{
			//PrintToChatAll("%d-%c",i,g_sPrefixType[i]);
			continue;
		}
		else
			return false;
	}
	
	return true;
}

bool:CheckClientHasPreFixCaster(const String:sOldname[])
{
	for(new i =0 ; i< strlen(g_sPrefixTypeCaster); ++i)
	{
		if(sOldname[i] == g_sPrefixTypeCaster[i])
		{
			continue;
		}
		else
			return false;
	}
	
	return true;
}

stock CS_SetClientName(client, const String:name[], bool:silent=false)
{
    decl String:oldname[MAX_NAME_LENGTH];
    GetClientName(client, oldname, sizeof(oldname));

    SetClientInfo(client, "name", name);
    SetEntPropString(client, Prop_Data, "m_szNetname", name);

    new Handle:event = CreateEvent("player_changename");

    if (event != INVALID_HANDLE)
    {
        SetEventInt(event, "userid", GetClientUserId(client));
        SetEventString(event, "oldname", oldname);
        SetEventString(event, "newname", name);
        FireEvent(event);
    }

    if (silent)
        return;
    
    new Handle:msg = StartMessageAll("SayText2");

    if (msg != INVALID_HANDLE)
    {
        BfWriteByte(msg, client);
        BfWriteByte(msg, true);
        BfWriteString(msg, "#Cstrike_Name_Change");
        BfWriteString(msg, oldname);
        BfWriteString(msg, name);
        EndMessage();
    }
}
