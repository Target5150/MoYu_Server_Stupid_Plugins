#include <sourcemod>
#include <ripext>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0
#define PLUGIN_VERSION "1.1"

public Plugin myinfo = 
{
	name = "Simple Playtime Interface",
	author = "Forgetest",
	description = "Retrieve certain game playtime of clients.",
	version = PLUGIN_VERSION,
	url = "na"
};

#define HOST_PATH "api.steampowered.com"

ConVar g_cvAppID;
ConVar g_cvAPIkey;

int g_iAppID;
char g_sAPIkey[64];

StringMap g_hTrie_Playtime;

HTTPClient g_httpClient;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Steam_GetClientPlaytime", _Native_GetClientPlaytime);
}

public int _Native_GetClientPlaytime(Handle plugin, int numParams)
{
	char authId[65];
	GetNativeString(1, authId, sizeof authId);
	
	int val = 0;
	g_hTrie_Playtime.GetValue(authId, val);
	return val;
}

public void OnPluginStart()
{
	g_httpClient = new HTTPClient(HOST_PATH);
	if (g_httpClient == null) 
	{
		SetFailState("Failed to create http client.");
	}
	
	g_hTrie_Playtime = new StringMap();
	
	g_cvAppID = CreateConVar("game_playtime_appid", "550", "Application ID of current game. CS:S (240), CS:GO (730), TF2 (440), L4D (500), L4D2 (550)", FCVAR_NOTIFY);
	g_cvAPIkey = CreateConVar("game_playtime_apikey", "XXXXXXXXXXXXXXXXXXXX", "Steam developer web API key", FCVAR_PROTECTED);
	
	HookConVarChange(g_cvAppID, OnCvarChanged);
	HookConVarChange(g_cvAPIkey, OnCvarChanged);
	
	GetCvars();
	
	CreateConVar("sm_simple_playtime_interface_version", PLUGIN_VERSION, "Standard plugin version ConVar. Please don't change me!", FCVAR_REPLICATED|FCVAR_DONTRECORD);

	AutoExecConfig(true, "simple_playtime_interface");
	
	#if DEBUG
	RegAdminCmd("sm_uei", uei, ADMFLAG_ROOT);
	#endif
}

#if DEBUG
public Action uei(int a, int b)
{
	int target = a;
	
	if (b > 0)
	{
		char buf[16];
		GetCmdArg(1, buf, sizeof buf);
		target = GetClientOfUserId(StringToInt(buf));
	}
	
	char authId[65];
	GetClientAuthId(target, AuthId_Steam2, authId, sizeof authId);
	if (b > 0)
	{
		OnClientAuthorized(target, authId);
	}
	else
	{
		int playtime = -1;
		g_hTrie_Playtime.GetValue(authId, playtime);
		PrintToChat(a, "\x05Userid\x01: \x04%i\x01, \x05Playtime\x01: \x04%i", GetClientUserId(target), playtime);
	}
}
#endif // DEBUG

public void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iAppID = GetConVarInt(g_cvAppID);
	GetConVarString(g_cvAPIkey, g_sAPIkey, sizeof g_sAPIkey);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (IsFakeClient(client) || strcmp(auth, "BOT") == 0)
	{
		return;
	}
	
	char authId64[65];
	GetClientAuthId(client, AuthId_SteamID64, authId64, sizeof authId64);
	
	char sGet[256];
	Format(sGet, sizeof sGet,
			"IPlayerService/GetOwnedGames/v0001/?key=%s&include_played_free_games=1&appids_filter[0]=%i&steamid=%s",
			g_sAPIkey, g_iAppID, authId64);
	
	#if DEBUG
	LogMessage("Sending HTTP Request - GET %s", sGet);
	#endif
	
	g_httpClient.Get(sGet, HTTPResponse_GetRecentlyPlayedGames, GetClientUserId(client));
}

public void HTTPResponse_GetRecentlyPlayedGames(HTTPResponse response, int userid)
{
	if (response.Status != HTTPStatus_OK)
	{
		#if DEBUG
		LogMessage("Failed to retrieve response - HTTPStatus: %i", view_as<int>(response.Status));
		#endif
		return;
	}
	
	int client = GetClientOfUserId(userid);
	if (!client)
	{
		#if DEBUG
		LogMessage("Failed in targeting client index");
		#endif
		return;
	}
	
	char authId[65];
	GetClientAuthId(client, AuthId_Steam2, authId, sizeof authId);
	
	// go to response body
	JSONObject dataObj = view_as<JSONObject>(view_as<JSONObject>(response.Data).Get("response"));
	
	#if DEBUG
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "logs/playtime_%s.txt", authId);
	dataObj.ToFile(sPath);
	LogMessage("dataObj.Size = %i", dataObj.Size);
	#endif
	
	// reach privacy?
	if (dataObj.Size == 0)
	{
		return;
	}
	
	// jump to "games" array section
	JSONArray jsonArray = view_as<JSONArray>(dataObj.Get("games"));
	
	// right here is the data requested
	dataObj = view_as<JSONObject>(jsonArray.Get(0));
	
	// playtime is formatted in minutes
	int minutes = dataObj.GetInt("playtime_forever");
	g_hTrie_Playtime.SetValue(authId, minutes, true);
	
	delete jsonArray;
	delete dataObj;
}
