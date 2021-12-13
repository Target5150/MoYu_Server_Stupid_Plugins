#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>

#define PLUGIN_VERSION "1.5"

public Plugin myinfo = 
{
	name = "[L4D2] Simple Playtime Interface",
	author = "Forgetest",
	description = "Retrieve certain game playtime of clients.",
	version = PLUGIN_VERSION,
	url = "na"
};

#define APPID_LEFT4DEAD2 550
#define HOST_PATH "https://api.steampowered.com"
#define TOTAL_PLAYTIME_URL "/IPlayerService/GetOwnedGames/v1"
#define REAL_PLAYTIME_URL "/ISteamUserStats/GetUserStatsForGame/v2"

ConVar g_cvAPIkey;
StringMap g_hTrie_Playtime;
Handle g_hForward_OnGetPlaytime;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hForward_OnGetPlaytime = CreateGlobalForward("L4D2_OnGetPlaytime", ET_Ignore, Param_String, Param_Cell, Param_Cell);
	CreateNative("L4D2_GetTotalPlaytime", _Native_GetTotalPlaytime);
	return APLRes_Success;
}

public int _Native_GetTotalPlaytime(Handle plugin, int numParams)
{
	char authId[65];
	GetNativeString(1, authId, sizeof authId);
	
	int val[2] = {-1};
	g_hTrie_Playtime.GetArray(authId, val, 2);
	
	bool real = GetNativeCell(2);
	return val[view_as<int>(real)];
}

public void OnPluginStart()
{
	CreateConVar("sm_l4d2_simple_playtime_interface_version", PLUGIN_VERSION, "Standard plugin version ConVar. Please don't change me!", FCVAR_REPLICATED|FCVAR_DONTRECORD);
	g_cvAPIkey = CreateConVar("l4d2_playtime_apikey", "XXXXXXXXXXXXXXXXXXXX", "Steam developer web API key", FCVAR_PROTECTED);
	
	AutoExecConfig(true, "l4d2_playtime_interface");
	
	g_hTrie_Playtime = new StringMap();
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	char authId64[65];
	if (!GetClientAuthId(client, AuthId_SteamID64, authId64, sizeof(authId64)))
	{
		return;
	}
	
	char apikey[65];
	g_cvAPIkey.GetString(apikey, sizeof(apikey));
	
	DataPack dp = new DataPack();
	dp.WriteString(auth);
	DataPack dp2 = view_as<DataPack>(CloneHandle(dp));
	
	HTTPRequest request = new HTTPRequest(HOST_PATH...TOTAL_PLAYTIME_URL);
	request.AppendQueryParam("key", "%s", apikey);
	request.AppendQueryParam("steamid", "%s", authId64);
	request.AppendQueryParam("appids_filter[0]", "%i", APPID_LEFT4DEAD2);
	request.AppendQueryParam("include_appinfo", "%i", 0);
	request.AppendQueryParam("include_played_free_games", "%i", 0);
	request.Get(HTTPResponse_GetOwnedGames, dp);
	
	request = new HTTPRequest(HOST_PATH...REAL_PLAYTIME_URL);
	request.AppendQueryParam("key", "%s", apikey);
	request.AppendQueryParam("steamid", "%s", authId64);
	request.AppendQueryParam("appid", "%i", APPID_LEFT4DEAD2);
	request.Get(HTTPResponse_GetUserStatsForGame, dp2);
}

public void HTTPResponse_GetOwnedGames(HTTPResponse response, DataPack dp)
{
	dp.Reset();
	
	char authId[65];
	dp.ReadString(authId, sizeof(authId));
	
	delete dp;
	
	if (response.Status != HTTPStatus_OK || response.Data == null)
	{
		LogMessage("Failed to retrieve response (GetOwnedGames) - HTTPStatus: %i", view_as<int>(response.Status));
		return;
	}
	
	/*
	{
		"response":
		{
			"game_count":1,
			"games": [
			{
				"appid":550,
				"playtime_forever":0,
				"playtime_windows_forever":0,
				"playtime_mac_forever":0,
				"playtime_linux_forever":0
			}]
		}
	}
	*/
	
	// go to response body
	JSONObject dataObj = view_as<JSONObject>(view_as<JSONObject>(response.Data).Get("response"));
	
	// invalid json data due to privacy?
	if (!dataObj)
	{
		SetPlaytime(authId, -2, false);
		return;
	}
	if (!dataObj.Size || !dataObj.HasKey("games") || dataObj.IsNull("games"))
	{
		SetPlaytime(authId, -2, false);
		delete dataObj;
		return;
	}
	
	// jump to "games" array section
	JSONArray jsonArray = view_as<JSONArray>(dataObj.Get("games"));
	delete dataObj;
	
	// right here is the data requested
	dataObj = view_as<JSONObject>(jsonArray.Get(0));
	
	// playtime is formatted in minutes
	SetPlaytime(authId, dataObj.GetInt("playtime_forever") * 60, false);
	
	delete jsonArray;
	delete dataObj;
}

public void HTTPResponse_GetUserStatsForGame(HTTPResponse response, DataPack dp)
{
	dp.Reset();
	
	char authId[65];
	dp.ReadString(authId, sizeof(authId));
	
	delete dp;
	
	if (response.Status != HTTPStatus_OK || response.Data == null)
	{
		LogMessage("Failed to retrieve response (GetUserStatsForGame) - HTTPStatus: %i", view_as<int>(response.Status));
		
		// seems chances that this error represents privacy as well.
		if (response.Status == HTTPStatus_InternalServerError)
		{
			SetPlaytime(authId, -2, true);
		}
		
		return;
	}
	
	/*
	{
		"playerstats":
		{
			"steamID":"STEAM64",
			"gameName":"",
			"achievements":[
				{"name": "...", "achieved": 1},
				...
			],
			"stats":[
				...,
				{"name": "Stat.TotalPlayTime.Total", "value": ?},
				...
			]
		}
	}
	*/
	
	// go to response body
	JSONObject dataObj = view_as<JSONObject>(view_as<JSONObject>(response.Data).Get("playerstats"));
	
	// invalid json data due to privacy?
	if (dataObj)
	{
		if ( !dataObj.Size
			|| !dataObj.HasKey("stats")
			|| dataObj.IsNull("stats") )
		{
			SetPlaytime(authId, -2, true);
			delete dataObj;
			return;
		}
	}
	else
	{
		SetPlaytime(authId, -2, true);
		return;
	}
	
	// jump to "stats" array section
	JSONArray jsonArray = view_as<JSONArray>(dataObj.Get("stats"));
	
	char keyname[64];
	int size = jsonArray.Length;
	for (int i = 0; i < size; ++i)
	{
		delete dataObj;
		dataObj = view_as<JSONObject>(jsonArray.Get(i));
		
		if ( dataObj.GetString("name", keyname, sizeof(keyname))
			&& strcmp(keyname, "Stat.TotalPlayTime.Total") == 0 )
		{
			// playtime is formatted in seconds
			SetPlaytime(authId, dataObj.GetInt("value"), true);
			break;
		}
	}
	
	delete jsonArray;
	delete dataObj;
}

/*
 * Playtime array = int[2]
 * array[0] = Total time, array[1] = Real time.
 */

void SetPlaytime(const char[] auth, int seconds, bool real)
{
	int array[2];
	if (!g_hTrie_Playtime.GetArray(auth, array, 2))
	{
		array[view_as<int>(real) ^ 1] = -1;
	}
	
	array[view_as<int>(real)] = seconds;
	g_hTrie_Playtime.SetArray(auth, array, 2);
	
	Call_StartForward(g_hForward_OnGetPlaytime);
	Call_PushString(auth);
	Call_PushCell(real);
	Call_PushCell(seconds);
	Call_Finish();
}