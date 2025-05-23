#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "2.1"

public Plugin myinfo = 
{
	name = "[L4D & 2] BeQuiet",
	author = "Sir, Forgetest",
	description = "Please be Quiet! (Spec hearing chat, name/cvar change supress)",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

// 1.12.0.6944
// https://github.com/alliedmodders/sourcemod/commit/3b4a343274286b31a9b3cf33c64f7ef
#if ( SOURCEMOD_V_MAJOR == 1 && (SOURCEMOD_V_MINOR < 12 || SOURCEMOD_V_REV < 6944) )
native int GetPublicChatTriggers(char[] buffer, int maxlength);
native int GetSilentChatTriggers(char[] buffer, int maxlength);
#endif

ConVar hCvarCvarChange, hCvarNameChange, hCvarSpecNameChange, hCvarSpecSeeChat;

public void OnPluginStart()
{
	//Player name change & chat trigger
	HookUserMessage(GetUserMessageId("SayText2"), UserMsg_OnSayText2, true);
	
	//Server CVar
	HookEvent("server_cvar", Event_ServerConVar, EventHookMode_Pre);
	
	//Cvars
	hCvarCvarChange = CreateConVar("bq_cvar_change_suppress", "1", "Silence Server Cvars being changed, this makes for a clean chat with no disturbances.", FCVAR_SPONLY, true, 0.0, true, 1.0);
	hCvarNameChange = CreateConVar("bq_name_change_suppress", "0", "Silence Player name Changes.", FCVAR_SPONLY, true, 0.0, true, 1.0);
	hCvarSpecNameChange = CreateConVar("bq_name_change_spec_suppress", "0", "Silence Spectating Player name Changes.", FCVAR_SPONLY, true, 0.0, true, 1.0);
	hCvarSpecSeeChat = CreateConVar("bq_show_player_team_chat_spec", "1", "Show Spectators Survivors and Infected Team chat?", FCVAR_SPONLY, true, 0.0, true, 1.0);

	AutoExecConfig(true);
}

bool TryRequireFeature(FeatureType type, const char[] name)
{
	FeatureStatus status = GetFeatureStatus(type, name);
	if (status == FeatureStatus_Unknown)
		return false;
	
	if (status == FeatureStatus_Unavailable)
		RequireFeature(type, name);

	return true;
}

bool IsChatTriggerMsg(const char[] text)
{
	static char s_sPubChatTrigger[8] = "!", s_sPrivChatTrigger[8] = "/";
	static int s_iPubTriggerLen = 1, s_iPrivTriggerLen = 1;

	static bool s_bInit = false;
	if (!s_bInit)
	{
		if (CanTestFeatures() && TryRequireFeature(FeatureType_Native, "GetPublicChatTriggers"))
		{
			s_iPubTriggerLen = GetPublicChatTriggers(s_sPubChatTrigger, sizeof(s_sPubChatTrigger));
			s_iPrivTriggerLen = GetSilentChatTriggers(s_sPrivChatTrigger, sizeof(s_sPrivChatTrigger));
			
			if (!s_iPubTriggerLen)
				s_iPubTriggerLen = strcopy(s_sPubChatTrigger, sizeof(s_sPubChatTrigger), "!");
			if (!s_iPrivTriggerLen)
				s_iPrivTriggerLen = strcopy(s_sPrivChatTrigger, sizeof(s_sPrivChatTrigger), "/");
		}

		s_bInit = true;
	}

	if (strncmp(text, s_sPubChatTrigger, s_iPubTriggerLen) != 0
	  && strncmp(text, s_sPrivChatTrigger, s_iPrivTriggerLen) != 0)
		return false;
	
	return true;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (!IsValidClient(client))
		return;
	
	if (!hCvarSpecSeeChat.BoolValue || strcmp(command, "say_team") != 0)
		return;
	
	// TODO: Formats for dead players? Not really seen much.
	static const char s_ChatFormats[][] = {
		"L4D_Chat_Survivor",
		"L4D_Chat_Infected",
		// "L4D_Chat_Survivor_Dead",
		// "L4D_Chat_Infected_Dead",
	};
	
	int idxTeam = GetClientTeam(client) - 2;
	if (idxTeam != 0 && idxTeam != 1)
		return;
	
	// if (!IsPlayerAlive(client))
	// 	idxTeam += 2;
	
	// collect all spectators + SourceTV
	int[] clients = new int[MaxClients];
	int numClients = 0;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 1 && (!IsFakeClient(i) || IsClientSourceTV(i)))
			clients[numClients++] = i;
	}
	
	if (numClients <= 0)
		return;
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	UTIL_SayText2Filter(client, clients, numClients, true, s_ChatFormats[idxTeam], name, sArgs);
}

Action Event_ServerConVar(Event event, const char[] name, bool dontBroadcast)
{
	return hCvarCvarChange.BoolValue ? Plugin_Handled : Plugin_Continue;
}

// Thanks for help from HarryPotter (@fbef0102) IIRC
Action UserMsg_OnSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int client = msg.ReadByte();
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	msg.ReadByte(); // Skip the second byte (bChat)
	
	// Read the format (translation)
	static char sFormat[128];
	msg.ReadString(sFormat, sizeof(sFormat), true);
	
	if( (GetClientTeam(client) == 1 && hCvarSpecNameChange.BoolValue)
	 || hCvarNameChange.BoolValue )
	{
		if (strcmp(sFormat, "#Cstrike_Name_Change") == 0) // don't broadcast player name changes
			return Plugin_Handled;
	}
	
	static char text[256];
	msg.ReadString(text, sizeof(text), true); // name
	msg.ReadString(text, sizeof(text), true); // text @ param1

	if (IsChatTriggerMsg(text)) // don't broadcast chat trigger messages
		return Plugin_Handled;

	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock void UTIL_SayText2Filter( int entity, const int[] recipients, int numRecipient, bool bChat, const char[] msg_name, const char[] param1 = NULL_STRING, const char[] param2 = NULL_STRING, const char[] param3 = NULL_STRING, const char[] param4 = NULL_STRING )
{
	BfWrite bf = UserMessageToBfWrite(StartMessage( "SayText2", recipients, numRecipient, USERMSG_RELIABLE ));
	
	if ( entity < 0 )
		entity = 0; // world, dedicated server says
	
	bf.WriteByte( entity );
	bf.WriteByte( bChat );
	bf.WriteString( msg_name );
	
	if ( !IsNullString(param1) )
		bf.WriteString( param1 );
	else
		bf.WriteString( "" );
	
	if ( !IsNullString(param2) )
		bf.WriteString( param2 );
	else
		bf.WriteString( "" );
	
	if ( !IsNullString(param3) )
		bf.WriteString( param3 );
	else
		bf.WriteString( "" );
	
	if ( !IsNullString(param4) )
		bf.WriteString( param4 );
	else
		bf.WriteString( "" );
	
	EndMessage();
}