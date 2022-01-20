/* -------------------CHANGELOG--------------------
3.4
 - Fixed previous support to allow setting separated text file.

3.3
 - Added support for UTF-8 characters via storing hostname from text file

3.2
 - Fixed a bug when the plugin didn`t correctly recognize Confogl availability
 
3.1
 - Removed "empty" field from keyvalues file
 - Added new ConVar: sn_hostname_format3
 
3.0
 - Removed sn_name_format ConVar
 - Removed sn_name_format ConVar
 - Code optimization
 - Added two new ConVars: sn_hostname_format1 and sn_hostname_format2
 
2.5
 - Fixed incorrect convar hook which caused the plugin stuck on vanilla on new Confogl installs
 
2.4
 - Added new requested formatting type
 - Added public version convar

2.3.1
 - Changed one of formatting types (5) as it didn`t look neat before
 - Some code optimizations

2.3
 - Added 3 more formatting types
 - server_namer.txt now only updates on plugin start
 - Fixed game mode not disappearing on empty servers while Confogl match is loaded
 - Some code optimizations

 2.2
 - Added 3 choosable formatting types

 2.1
 - General code clean up

 2.0
 - Initial release
 
 1.0
 - Some laggy buggy log-spammy codes
^^^^^^^^^^^^^^^^^^^^CHANGELOG^^^^^^^^^^^^^^^^^^^^ */

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN
#define PL_VERSION "3.4"

#pragma semicolon 1
#pragma newdecls required

bool CustomName;
bool IsConfoglAvailable;

ConVar cvarHostNum;
ConVar cvarMainName;
ConVar cvarMainNameFile;
ConVar cvarServerNameFormatCase1;
ConVar cvarServerNameFormatCase2;
ConVar cvarServerNameFormatCase3;
ConVar cvarMpGameMode;
ConVar cvarZDifficulty;
ConVar cvarHostname;

ConVar cvarReadyUpCfgName;

KeyValues kv;

bool isempty;

public Plugin myinfo =
{
	name = "Server namer",
	version = PL_VERSION,
	description = "Changes server hostname according to the current game mode",
	author = "sheo, Forgetest"
}

public void OnPluginStart()
{
	//Check if l4d2
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		SetFailState("Plugin supports Left 4 dead 2 only!");
	}
	
	//Check if s_n.txt exists
	kv = CreateKeyValues("GameMods");
	char filepath[64];
	BuildPath(Path_SM, filepath, sizeof(filepath), "configs/server_namer.txt");
	if (!FileToKeyValues(kv, filepath))
	{
		SetFailState("configs/server_namer.txt not found!");
	}
	
	//Reg cmds/cvars
	RegAdminCmd("sn_hostname", Cmd_Hostname, ADMFLAG_KICK);
	cvarHostNum = CreateConVar("sn_host_num", "0", "Server number, usually set at lauch command line.");
	cvarMainName = CreateConVar("sn_main_name", "Hostname", "Main server name.");
	cvarMainNameFile = CreateConVar("sn_main_name_path", "", "Path to text file where main server name is (for using UTF-8 characters) (bases \"sourcemod/configs/\").");
	cvarServerNameFormatCase1 = CreateConVar("sn_hostname_format1", "[{hostname} #{servernum}] {gamemode}", "Hostname format. Case: Confogl or Vanilla without difficulty levels, such as Versus.");
	cvarServerNameFormatCase2 = CreateConVar("sn_hostname_format2", "[{hostname} #{servernum}] {gamemode} - {difficulty}", "Hostname format. Case: Vanilla with difficulty levels, such as Campaign.");
	cvarServerNameFormatCase3 = CreateConVar("sn_hostname_format3", "[{hostname} #{servernum}]", "Hostname format. Case: empty server.");
	CreateConVar("l4d2_server_namer_version", PL_VERSION, "Server namer version", FCVAR_NOTIFY);
	cvarMpGameMode = FindConVar("mp_gamemode");
	cvarHostname = FindConVar("hostname");
	cvarZDifficulty = FindConVar("z_difficulty");
		
	//Hooks
	HookConVarChange(cvarMpGameMode, OnCvarChanged);
	HookConVarChange(cvarZDifficulty, OnCvarChanged);
	//HookConVarChange(cvarMainName, OnCvarChanged);
	HookConVarChange(cvarHostNum, OnCvarChanged);
	HookConVarChange(cvarServerNameFormatCase1, OnCvarChanged);
	HookConVarChange(cvarServerNameFormatCase2, OnCvarChanged);
	HookConVarChange(cvarServerNameFormatCase3, OnCvarChanged);
	IsConfoglAvailable = LibraryExists("confogl");
	SetName();
}

public void OnClientConnected(int client)
{
	SetName();
}

public void OnConfigsExecuted()
{
	IsConfoglAvailable = LibraryExists("confogl");
	SetName();
}

public void OnClientDisconnect_Post(int client)
{
	SetName();
}

public void OnCvarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	SetName();
}

public Action Cmd_Hostname(int client, int args)
{
	if (args == 0)
	{
		CustomName = false;
		SetName();
	}
	else
	{
		CustomName = true;
		char arg1[128];
		GetCmdArg(1, arg1, sizeof(arg1));
		SetConVarString(cvarHostname, arg1, false, false);
	}
	
	return Plugin_Handled;
}

void SetName()
{
	if (CustomName)
	{
		return;
	}
	StoreMainNameFromFile();
	isempty = ServerIsEmpty();
	if (IsConfoglAvailable)
	{
		if (cvarReadyUpCfgName == INVALID_HANDLE)
		{
			cvarReadyUpCfgName = FindConVar("l4d_ready_cfg_name");
		}
		if (cvarReadyUpCfgName != INVALID_HANDLE)
		{
			SetConfoglName();
		}
		else
		{
			SetVanillaName();
		}
	}
	else
	{
		SetVanillaName();
	}
}

void SetVanillaName()
{
	char GameMode[128];
	char FinalHostname[128];
	if (isempty || IsGameModeEmpty())
	{
		GetConVarString(cvarServerNameFormatCase3, FinalHostname, sizeof(FinalHostname));
		ParseNameAndSendToMainConVar(FinalHostname);
	}
	else
	{
		char CurGamemode[128];
		GetConVarString(cvarMpGameMode, CurGamemode, sizeof(CurGamemode));
		KvRewind(kv);
		if (KvJumpToKey(kv, CurGamemode))
		{
			KvGetString(kv, "name", GameMode, sizeof(GameMode));
			if (KvGetNum(kv, "difficulty") == 1)
			{
				char CurDiff[32];
				GetConVarString(cvarZDifficulty, CurDiff, sizeof(CurDiff));
				KvRewind(kv);
				KvJumpToKey(kv, "difficulties");
				char CurDiffBuffer[32];
				KvGetString(kv, CurDiff, CurDiffBuffer, sizeof(CurDiffBuffer));
				GetConVarString(cvarServerNameFormatCase2, FinalHostname, sizeof(FinalHostname));
				ReplaceString(FinalHostname, sizeof(FinalHostname), "{gamemode}", GameMode);
				ReplaceString(FinalHostname, sizeof(FinalHostname), "{difficulty}", CurDiffBuffer);
				ParseNameAndSendToMainConVar(FinalHostname);
			}
			else
			{
				GetConVarString(cvarServerNameFormatCase1, FinalHostname, sizeof(FinalHostname));
				ReplaceString(FinalHostname, sizeof(FinalHostname), "{gamemode}", GameMode);
				ParseNameAndSendToMainConVar(FinalHostname);
			}
		}
		else
		{
			GetConVarString(cvarServerNameFormatCase1, FinalHostname, sizeof(FinalHostname));
			ReplaceString(FinalHostname, sizeof(FinalHostname), "{gamemode}", CurGamemode);
			ParseNameAndSendToMainConVar(FinalHostname);
		}
	}
}

void SetConfoglName()
{
	char GameMode[128];
	char FinalHostname[128];
	if (isempty)
	{
		GetConVarString(cvarServerNameFormatCase3, FinalHostname, sizeof(FinalHostname));
		ParseNameAndSendToMainConVar(FinalHostname);
	}
	else
	{
		GetConVarString(cvarReadyUpCfgName, GameMode, sizeof(GameMode));
		GetConVarString(cvarServerNameFormatCase1, FinalHostname, sizeof(FinalHostname));
		ReplaceString(FinalHostname, sizeof(FinalHostname), "{gamemode}", GameMode);
		ParseNameAndSendToMainConVar(FinalHostname);
	}
}

void ParseNameAndSendToMainConVar(char[] sBuffer)
{
	char tBuffer[128];
	GetConVarString(cvarMainName, tBuffer, sizeof(tBuffer));
	ReplaceString(sBuffer, 128, "{hostname}", tBuffer);
	GetConVarString(cvarHostNum, tBuffer, sizeof(tBuffer));
	ReplaceString(sBuffer, 128, "{servernum}", tBuffer);
	SetConVarString(cvarHostname, sBuffer, false, false);
}

void StoreMainNameFromFile()
{
	char sPath[PLATFORM_MAX_PATH];
	GetConVarString(cvarMainNameFile, sPath, sizeof sPath);
	if (!strlen(sPath)) return;
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/%s", sPath);
	
	File file = OpenFile(sPath, "r");
	if (file != INVALID_HANDLE)
	{
		char readData[256];
		if(!IsEndOfFile(file) && ReadFileLine(file, readData, sizeof(readData)))
		{
			SetConVarString(cvarMainName, readData);
		}
		return;
	}
}

bool ServerIsEmpty()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			return false;
		}
	}

	return true;
}

bool IsGameModeEmpty()
{
	char GameMode[128];
	char CurGamemode[128];

	GetConVarString(cvarMpGameMode, CurGamemode, sizeof(CurGamemode));

	KvRewind(kv);
	if (KvJumpToKey(kv, CurGamemode))
	{
		KvGetString(kv, "name", GameMode, sizeof(GameMode));

		if (GameMode[0] == '\0') return true;
	}

	return false;
}
