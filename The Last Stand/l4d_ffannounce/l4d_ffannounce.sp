#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

#define PLUGIN_VERSION "3.3"

public Plugin myinfo = 
{
	name = "Survivor FF Announce",
	author = "AiMee, Forgetest",
	description = "Friendly Fire Announcements",
	version = PLUGIN_VERSION,
	url = "",
}

#define L4D2Team_None 0
#define L4D2Team_Spectator 1
#define L4D2Team_Survivor 2
#define L4D2Team_Infected 3

ConVar	AnnounceEnable;
ConVar	AbnormalLog;
ConVar	AbnormalLogPath;

int		iAnnounceEnable;
int		iAbnormalLog;
char	sAbnormalLogPath[PLATFORM_MAX_PATH];

Handle	FFTimer[MAXPLAYERS+1]; 
int		DamageCache[MAXPLAYERS+1][MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			return APLRes_Success;
		}
		default:
		{
			strcopy(error, err_max, "Plugin supports only L4D & L4D2!");
			return APLRes_SilentFailure;
		}
	}
}

public void OnPluginStart()
{
	(	AnnounceEnable 	= CreateConVar("l4d_ff_announce_enable", 	"1", "Enable Announcing Friendly Fire (0 - Disabled, 1 - Announce in private, 2 - Announce to Activators and Spectators).", FCVAR_SPONLY, true, 0.0, true, 2.0)).AddChangeHook(OnConVarChanged);
	(	AbnormalLog 	= CreateConVar("l4d_ff_announce_log",		"0", "Friendly fire amount over this value will be logged to file (Found in sourcemod/logs/abnormalff.log), 0 to disable.", FCVAR_SPONLY, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChanged);
	(	AbnormalLogPath = CreateConVar("l4d_ff_announce_log_path",	"logs/abnormalff.log", "File path to log friendly fire", FCVAR_SPONLY)).AddChangeHook(OnConVarChanged);
	
	GetCvars();
	
	HookEvent("player_hurt_concise", Event_HurtConcise);
}

void GetCvars()
{
	iAnnounceEnable = AnnounceEnable.IntValue;
	iAbnormalLog = AbnormalLog.IntValue;
	AbnormalLogPath.GetString(sAbnormalLogPath, sizeof sAbnormalLogPath);
	BuildPath(Path_SM, sAbnormalLogPath, sizeof sAbnormalLogPath, sAbnormalLogPath);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void Event_HurtConcise(Event event, const char[] name, bool dontBroadcast)
{
	if (!iAnnounceEnable) return;
	
	int attacker 	= event.GetInt("attackerentid");
	int victim 		= GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidClient(attacker) || !IsValidClient(victim)) return;
	if (GetClientTeam(attacker) != L4D2Team_Survivor || IsFakeClient(attacker)) return;
	if (GetClientTeam(victim)	!= L4D2Team_Survivor) return;
	
	if (attacker == victim) return;
	
	int damage = event.GetInt("dmg_health");
	if (FFTimer[attacker] != null)
	{
		DamageCache[attacker][victim] += damage;
		delete FFTimer[attacker];
		
		DataPack dp;
		FFTimer[attacker] = CreateDataTimer(1.5, AnnounceFF, dp);
		dp.WriteCell(attacker);
		dp.WriteCell(GetClientUserId(attacker));
	}
	else 
	{
		for (int i = 1; i <= MaxClients; i++) DamageCache[attacker][i] = 0;
		
		DamageCache[attacker][victim] = damage;
		
		DataPack dp;
		FFTimer[attacker] = CreateDataTimer(1.5, AnnounceFF, dp);
		dp.WriteCell(attacker);
		dp.WriteCell(GetClientUserId(attacker));
	}
}

public Action AnnounceFF(Handle timer, DataPack dp) 
{
	dp.Reset();
	
	int attacker = dp.ReadCell();
	int attackerid = dp.ReadCell();
	
	FFTimer[attacker] = null;
	
	if (attacker != GetClientOfUserId(attackerid)) return Plugin_Handled;
	
	char text[512];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (DamageCache[attacker][i] > 0)
		{
			if (strlen(text) == 0) {
				FormatEx(text, sizeof(text), "* {green}You {default}did {blue}FF {default}to {olive}%N {default}@ {olive}%d {default}HP", i, DamageCache[attacker][i]);
			} else {
				Format(text, sizeof(text), "%s, {olive}%N {default}@ {olive}%d {default}HP", text, i, DamageCache[attacker][i]);
			}
			if (!IsFakeClient(i)) CPrintToChat(i, "* {olive}%N {default}did {blue}FF {default}to {green}you {default}@ {olive}%d {default}HP", attacker, DamageCache[attacker][i]);
			
			if (iAbnormalLog && DamageCache[attacker][i] > iAbnormalLog)
			{
				File file = OpenFile(sAbnormalLogPath, "r+");
				if (file != null)
				{
					char auth[64], sTime[64];
					GetClientAuthId(attacker, AuthId_Steam2, auth, sizeof(auth));
					FormatTime(sTime, sizeof(sTime), "%Y-%m-%d %X");
					file.WriteLine("[FF] [%s]  %N (%s) did %d friendly fire damage to %N", sTime, attacker, auth, DamageCache[attacker][i], i);
				}
			}
		}
	}
	if (strlen(text) > 0)
	{
		CPrintToChat(attacker, text);
		
		if (iAnnounceEnable > 1)
		{
			char buffer[MAX_NAME_LENGTH+9];
			FormatEx(buffer, sizeof(buffer), "* {olive}%N", attacker);
			ReplaceString(text, sizeof(text), "* {green}You", buffer, true);
			CPrintToSpectators(text);
		}
	}
	
	return Plugin_Handled;
}

void CPrintToSpectators(const char[] msg)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == L4D2Team_Spectator)
		{
			CPrintToChat(i, msg);
		}
	}
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}