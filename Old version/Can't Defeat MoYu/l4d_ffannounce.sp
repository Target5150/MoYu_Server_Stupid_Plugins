#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

#define		FF_LOG		10
//#define 	ANC_MINFF	1

new Handle: AnnounceEnable;
new Handle: AbnormalLog;
new Handle:	FFTimer[MAXPLAYERS+1]; 
new bool:	FFActive[MAXPLAYERS+1]; 

new DamageCache[MAXPLAYERS+1][MAXPLAYERS+1]; 

public Plugin:myinfo = 
{
	name = "L4D2 FF Announce",
	author = "AiMee",
	description = "Friendly Fire Announcements",
	version = "3.2",
	url = "",
}

public OnPluginStart()
{
	AnnounceEnable 	= CreateConVar("l4d_ff_announce_enable", 		"1", "Enable Announcing Friendly Fire (0 - Disabled, 1 - Announce in private, 2 - Announce to Activators and Spectators, 3 - Announce to All).", FCVAR_SPONLY);
	AbnormalLog 	= CreateConVar("l4d_ff_announce_log_abnormal",	"0", "Friendly fire amount over this value will be logged to file (Found in sourcemod/logs/abnormalff.log), 0 to disable.", FCVAR_SPONLY);
	
	HookEvent("player_hurt_concise", Event_HurtConcise, EventHookMode_Post);
}

public Event_HurtConcise(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarInt(AnnounceEnable)) return;
	
	new attacker 	= GetEventInt(event, "attackerentid");
	new victim 		= GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (attacker > MaxClients || !attacker) return;
	if (!IsClientInGame(attacker) || IsFakeClient(attacker) || GetClientTeam(attacker) != 2) return;
	if (!IsClientInGame(victim)   || GetClientTeam(victim) != 2) return;
	
	if (attacker == victim) return;
	
	new damage = GetEventInt(event, "dmg_health");
	if (FFActive[attacker])
	{
		DamageCache[attacker][victim] += damage;
		KillTimer(FFTimer[attacker]);
		FFTimer[attacker] = CreateTimer(1.5, AnnounceFF, attacker);
	}
	else 
	{
		for (new i = 1; i <= MaxClients; i++) DamageCache[attacker][i] = 0;
		
		DamageCache[attacker][victim] = damage;
		FFActive[attacker] = true;
		FFTimer[attacker] = CreateTimer(1.5, AnnounceFF, attacker);
	}
}

public Action:AnnounceFF(Handle:timer, any:attacker) 
{
	FFActive[attacker] = false;
	
	if (!IsClientInGame(attacker)) return Plugin_Handled;
		
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (DamageCache[attacker][i] > 0)
		{
			CPrintToChat(attacker, "* {blue}You {default}did {olive}%d {green}FF damage {default}to {olive}%N", DamageCache[attacker][i], i);
			if (!IsFakeClient(i))
				CPrintToChat(i, "* {blue}%N {default}did {olive}%d {green}FF damage {default}to {olive}you", attacker, DamageCache[attacker][i]);
			
			if (GetConVarInt(AnnounceEnable) > 2)
			{
				if (IsClientObserver(i) || (GetClientTeam(i) == 3 && GetConVarInt(AnnounceEnable) == 3))
					CPrintToChat(i, "* {blue}%N {default}did {olive}%d {green}FF damage {default}to {olive}%N", attacker, DamageCache[attacker][i], i);
			}
			
			
			if (GetConVarInt(AbnormalLog) > 0 && DamageCache[attacker][i] > GetConVarInt(AbnormalLog))
			{
				char path[PLATFORM_MAX_PATH];
				BuildPath(Path_SM, path, sizeof(path), "logs/abnormalff.log");
				
				File file = OpenFile(path, "r+");
				if (file != null)
				{
					char auth[64], sTime[64];
					GetClientAuthId(attacker, AuthId_Steam2, auth, sizeof(auth));
					FormatTime(sTime, sizeof(sTime), "%Y-%m-%d %X");
					file.WriteLine("[FF] [%s]  %N (%s) did %d friendly fire damage to %N", sTime, attacker, auth, DamageCache[attacker][i], i);
				}
			}
			
			DamageCache[attacker][i] = 0;
		}
	}
	return Plugin_Handled;
}