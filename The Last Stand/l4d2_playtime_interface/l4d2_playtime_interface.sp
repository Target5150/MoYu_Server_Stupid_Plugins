#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>

#define PLUGIN_VERSION "1.4"

public Plugin myinfo = 
{
	name = "[L4D2] Simple Playtime Interface",
	author = "Forgetest",
	description = "Retrieve certain game playtime of clients.",
	version = PLUGIN_VERSION,
	url = "na"
};

#define HOST_PATH "api.steampowered.com"
#define TOTAL_PLAYTIME_URL "IPlayerService/GetOwnedGames/v1"
#define REAL_PLAYTIME_URL "ISteamUserStats/GetUserStatsForGame/v2"

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
	
	AutoExecConfig(true, "l4d2_simple_playtime_interface");
	
	g_hTrie_Playtime = new StringMap();
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (IsFakeClient(client))
	{
		return;
	}
	
	char authId64[65];
	if (GetClientAuthId(client, AuthId_SteamID64, authId64, sizeof(authId64)))
	{
		return;
	}
	
	char apikey[65];
	g_cvAPIkey.GetString(apikey, sizeof(apikey));
	
	DataPack dp = new DataPack();
	dp.WriteString(authId64);
	
	// since we're performing 2 requests, need 2 separate packs.
	DataPack dp2 = view_as<DataPack>(CloneHandle(dp));
	
	HTTPRequest request = new HTTPRequest(HOST_PATH);
	request.AppendQueryParam(
			"%s/?key=%s&include_appinfo=0&include_played_free_games=0&appids_filter[0]=550&steamid=%s",
			TOTAL_PLAYTIME_URL, apikey, authId64);
	request.Get(HTTPResponse_GetOwnedGames, dp);
	
	request = new HTTPRequest(HOST_PATH);
	request.AppendQueryParam(
			"%s/?key=%s&appid=550&steamid=%s",
			REAL_PLAYTIME_URL, apikey, authId64);
	request.Get(HTTPResponse_GetUserStatsForGame, dp2);
}

public void HTTPResponse_GetOwnedGames(HTTPResponse response, DataPack dp)
{
	if (response.Status != HTTPStatus_OK)
	{
		LogMessage("Failed to retrieve response - HTTPStatus: %i", view_as<int>(response.Status));
		return;
	}
	
	dp.Reset();
	
	char authId64[65];
	dp.ReadString(authId64, sizeof(authId64));
	
	delete dp;
	
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
		delete dataObj;
		return;
	}
	
	// jump to "games" array section
	JSONArray jsonArray = view_as<JSONArray>(dataObj.Get("games"));
	delete dataObj;
	
	// right here is the data requested
	dataObj = view_as<JSONObject>(jsonArray.Get(0));
	
	// playtime is formatted in minutes
	SetPlaytime(authId64, dataObj.GetInt("playtime_forever") * 60, false);
	
	delete jsonArray;
	delete dataObj;
}

public void HTTPResponse_GetUserStatsForGame(HTTPResponse response, DataPack dp)
{
	if (response.Status != HTTPStatus_OK)
	{
		LogMessage("Failed to retrieve response - HTTPStatus: %i", view_as<int>(response.Status));
		return;
	}
	
	dp.Reset();
	
	char authId64[65];
	dp.ReadString(authId64, sizeof(authId64));
	
	delete dp;
	
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
	JSONObject dataObj = view_as<JSONObject>(view_as<JSONObject>(response.Data).Get("playerstats"));
	
	// privacy?
	if (!dataObj.Size || !dataObj.HasKey("stats") || dataObj.IsNull("stats"))
	{
		delete dataObj;
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
		
		dataObj.GetString("name", keyname, sizeof(keyname));
		if (strcmp(keyname, "Stat.TotalPlayTime.Total") == 0)
		{
			// playtime is formatted in seconds
			SetPlaytime(authId64, dataObj.GetInt("value"), true);
			break;
		}
	}
	
	delete jsonArray;
	delete dataObj;
}

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