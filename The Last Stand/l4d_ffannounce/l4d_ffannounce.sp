#pragma semicolon 1

#include <sourcemod>
#include <colors>

ConVar	AnnounceEnable;
ConVar	AbnormalLog;
ConVar	AbnormalLogPath;
Handle	FFTimer[MAXPLAYERS+1]; 

int	DamageCache[MAXPLAYERS+1][MAXPLAYERS+1];

enum L4D2_Team
{
    L4D2Team_Spectator = 1,
    L4D2Team_Survivor,
    L4D2Team_Infected
};

public Plugin myinfo = 
{
	name = "Survivor FF Announce",
	author = "AiMee, Forgetest",
	description = "Friendly Fire Announcements",
	version = "3.2",
	url = "",
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead && GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin supports only L4D & L4D2!");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	AnnounceEnable 	= CreateConVar("l4d_ff_announce_enable", 	"1", "Enable Announcing Friendly Fire (0 - Disabled, 1 - Announce in private, 2 - Announce to Activators and Spectators).", FCVAR_SPONLY);
	AbnormalLog 	= CreateConVar("l4d_ff_announce_log",		"0", "Friendly fire amount over this value will be logged to file (Found in sourcemod/logs/abnormalff.log), 0 to disable.", FCVAR_SPONLY);
	AbnormalLogPath = CreateConVar("l4d_ff_announce_log_path",	"logs/abnormalff.log", "File path to log friendly fire", FCVAR_SPONLY);
	
	HookEvent("player_hurt_concise", Event_HurtConcise);
}

public void Event_HurtConcise(Event event, const char[] name, bool dontBroadcast)
{
	if (!AnnounceEnable.IntValue) return;
	
	int attacker 	= GetEventInt(event, "attackerentid");
	int victim 		= GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!IsValidClient(attacker) || !IsValidClient(victim)) return;
	if (GetClientTeam(attacker) != _:L4D2Team_Survivor || IsFakeClient(attacker)) return;
	if (GetClientTeam(victim)	!= _:L4D2Team_Survivor) return;
	
	if (attacker == victim) return;
	
	int damage = GetEventInt(event, "dmg_health");
	if (FFTimer[attacker] != null)
	{
		DamageCache[attacker][victim] += damage;
		KillTimer(FFTimer[attacker]);
		FFTimer[attacker] = CreateTimer(1.5, AnnounceFF, attacker);
	}
	else 
	{
		for (int i = 1; i <= MaxClients; i++) DamageCache[attacker][i] = 0;
		
		DamageCache[attacker][victim] = damage;
		FFTimer[attacker] = CreateTimer(1.5, AnnounceFF, attacker);
	}
}

public Action AnnounceFF(Handle timer, int attacker) 
{
	FFTimer[attacker] = null;
	
	if (!IsClientInGame(attacker)) return Plugin_Handled;
	
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
			
			if (AbnormalLog.IntValue && DamageCache[attacker][i] > AbnormalLog.IntValue)
			{
				char path[PLATFORM_MAX_PATH];
				AbnormalLogPath.GetString(path, sizeof(path));
				BuildPath(Path_SM, path, sizeof(path), path);
				
				File file = OpenFile(path, "r+");
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
	if (text[0] != '\0')
	{
		CPrintToChat(attacker, text);
		
		if (AnnounceEnable.IntValue > 1)
		{
			char buffer[64];
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
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == _:L4D2Team_Spectator)
		{
			CPrintToChat(i, msg);
		}
	}
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}