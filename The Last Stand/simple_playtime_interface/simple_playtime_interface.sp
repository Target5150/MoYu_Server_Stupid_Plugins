#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>

#define PLUGIN_VERSION "1.3"

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
	CreateConVar("sm_simple_playtime_interface_version", PLUGIN_VERSION, "Standard plugin version ConVar. Please don't change me!", FCVAR_REPLICATED|FCVAR_DONTRECORD);
	g_cvAppID = CreateConVar("game_playtime_appid", "550", "Application ID of current game. CS:S (240), CS:GO (730), TF2 (440), L4D (500), L4D2 (550)", FCVAR_NOTIFY);
	g_cvAPIkey = CreateConVar("game_playtime_apikey", "XXXXXXXXXXXXXXXXXXXX", "Steam developer web API key", FCVAR_PROTECTED);
	
	g_cvAppID.AddChangeHook(OnCvarChanged);
	g_cvAPIkey.AddChangeHook(OnCvarChanged);
	
	AutoExecConfig(true, "simple_playtime_interface");
	
	GetCvars();
	
	g_hTrie_Playtime = new StringMap();
}

public void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iAppID = g_cvAppID.IntValue;
	g_cvAPIkey.GetString(g_sAPIkey, sizeof g_sAPIkey);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	char authId64[65];
	GetClientAuthId(client, AuthId_SteamID64, authId64, sizeof authId64);
	
	HTTPRequest request = new HTTPRequest(HOST_PATH);
	
	request.AppendQueryParam(
			"IPlayerService/GetOwnedGames/v0001/?key=%s&include_played_free_games=1&appids_filter[0]=%i&steamid=%s",
			g_sAPIkey, g_iAppID, authId64
	);
	
	request.Get(HTTPResponse_GetRecentlyPlayedGames, GetClientUserId(client));
}

public void HTTPResponse_GetRecentlyPlayedGames(HTTPResponse response, any userid)
{
	if (response.Status != HTTPStatus_OK)
	{
		LogMessage("Failed to retrieve response - HTTPStatus: %i", view_as<int>(response.Status));
		return;
	}
	
	int client = GetClientOfUserId(userid);
	if (!client)
	{
		return;
	}
	
	char authId[65];
	if (!GetClientAuthId(client, AuthId_Steam2, authId, sizeof authId))
	{
		return;
	}
	
	/*
	{
		"response":
		{
			"game_count":1,
			"games":
			[
				{
					"appid":550,
					"playtime_forever":0,
					"playtime_windows_forever":0,
					"playtime_mac_forever":0,
					"playtime_linux_forever":0
				}
			]
		}
	}
	*/
	
	// go to response body
	JSONObject dataObj = view_as<JSONObject>(view_as<JSONObject>(response.Data).Get("response"));
	
	// privacy?
	if (!dataObj.Size || !dataObj.HasKey("games") || dataObj.IsNull("games"))
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
