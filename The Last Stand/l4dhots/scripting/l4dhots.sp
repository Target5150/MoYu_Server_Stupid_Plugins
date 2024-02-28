#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "2.5.1"

public Plugin myinfo = 
{
    name = "L4D HOTs",
    author = "ProdigySim, CircleSquared, Forgetest",
    description = "Pills and Adrenaline heal over time",
    version = PLUGIN_VERSION,
    url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

ArrayList
	g_aHOTPair;

bool
	g_bLeft4Dead2;

ConVar
	hCvarPillHot,
	hCvarPillInterval,
	hCvarPillIncrement,
	hCvarPillTotal,
	pain_pills_health_value;

ConVar
	hCvarAdrenHot,
	hCvarAdrenInterval,
	hCvarAdrenIncrement,
	hCvarAdrenTotal,
	adrenaline_health_buffer;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_aHOTPair = new ArrayList(2);
	
	char buffer[16];
	pain_pills_health_value = FindConVar("pain_pills_health_value");
	pain_pills_health_value.GetString(buffer, sizeof(buffer));
	
	hCvarPillHot =			CreateConVar("l4d_pills_hot",				"0",	"Pills heal over time",				FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	hCvarPillInterval =		CreateConVar("l4d_pills_hot_interval",		"1.0",	"Interval for pills hot",			FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.00001);
	hCvarPillIncrement =	CreateConVar("l4d_pills_hot_increment",		"10",	"Increment amount for pills hot",	FCVAR_NOTIFY|FCVAR_SPONLY, true, 1.0);
	hCvarPillTotal =		CreateConVar("l4d_pills_hot_total",			buffer,	"Total amount for pills hot",		FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0);
	
	if (g_bLeft4Dead2)
	{
		adrenaline_health_buffer = FindConVar("adrenaline_health_buffer");
		adrenaline_health_buffer.GetString(buffer, sizeof(buffer));
		
		hCvarAdrenHot = 		CreateConVar("l4d_adrenaline_hot",				"0",	"Adrenaline heals over time",			FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
		hCvarAdrenInterval =	CreateConVar("l4d_adrenaline_hot_interval",		"1.0",	"Interval for adrenaline hot",			FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.00001);
		hCvarAdrenIncrement =	CreateConVar("l4d_adrenaline_hot_increment",	"15",	"Increment amount for adrenaline hot",	FCVAR_NOTIFY|FCVAR_SPONLY, true, 1.0);
		hCvarAdrenTotal =		CreateConVar("l4d_adrenaline_hot_total",		buffer,	"Total amount for adrenaline hot",		FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0);
		
		CvarChg_AdrenHot(hCvarAdrenHot, "", "");
		hCvarAdrenHot.AddChangeHook(CvarChg_AdrenHot);
	}
	
	CvarChg_PillHot(hCvarPillHot, "", "");
	hCvarPillHot.AddChangeHook(CvarChg_PillHot);
}

public void OnPluginEnd()
{
	TogglePillHot(false);
	ToggleAdrenHot(false);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_aHOTPair.Clear();
}

void Event_Player_BotReplace(Event event, const char[] name, bool dontBroadcast)
{
	HandleSurvivorTakeover(event.GetInt("player"), event.GetInt("bot"));
}

void Event_Bot_PlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	HandleSurvivorTakeover(event.GetInt("bot"), event.GetInt("player"));
}

void HandleSurvivorTakeover(int replacee, int replacer)
{
	// There can be multiple HOTs happening at the same time
	int index = -1;
	while ((index = g_aHOTPair.FindValue(replacee, 0)) != -1)
	{
		g_aHOTPair.Set(index, replacer, 0);
		
		DataPack dp = g_aHOTPair.Get(index, 1);
		dp.Reset();
		dp.WriteCell(replacer);
	}
}

void PillsUsed_Event(Event event, const char[] name, bool dontBroadcast)
{
	HealEntityOverTime(
		event.GetInt("userid"),
		hCvarPillInterval.FloatValue,
		hCvarPillIncrement.IntValue,
		hCvarPillTotal.IntValue
	);
}

void AdrenalineUsed_Event(Event event, const char[] name, bool dontBroadcast)
{
	HealEntityOverTime(
		event.GetInt("userid"),
		hCvarAdrenInterval.FloatValue,
		hCvarAdrenIncrement.IntValue,
		hCvarAdrenTotal.IntValue
	);
}

void HealEntityOverTime(int userid, float interval, int increment, int total)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	
	int max = GetEntProp(client, Prop_Send, "m_iMaxHealth", 2);
	
	if (increment >= total)
	{
		__HealTowardsMax(client, total, max);
	}
	else
	{
		__HealTowardsMax(client, increment, max);
		DataPack dp;
		CreateDataTimer(interval, __HOT_ACTION, dp,
			TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		dp.WriteCell(userid);
		dp.WriteCell(increment);
		dp.WriteCell(total-increment);
		dp.WriteCell(max);
		
		g_aHOTPair.Set(g_aHOTPair.Push(userid), dp, 1);
	}
}

Action __HOT_ACTION(Handle timer, DataPack dp)
{
	dp.Reset();
	
	int userid = dp.ReadCell();
	int client = GetClientOfUserId(userid);
	
	if (client && IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client) && !L4D_IsPlayerHangingFromLedge(client))
	{
		int increment = dp.ReadCell();
		DataPackPos pos = dp.Position;
		int remaining = dp.ReadCell();
		int maxhp = dp.ReadCell();
		
		//PrintToChatAll("HOT: %N %d %d %d", client, increment, remaining, maxhp);
		
		if (increment < remaining)
		{
			__HealTowardsMax(client, increment, maxhp);
			dp.Position = pos;
			dp.WriteCell(remaining-increment);
			
			return Plugin_Continue;
		}
		else
		{
			__HealTowardsMax(client, remaining, maxhp);
		}
	}
	
	g_aHOTPair.Erase(g_aHOTPair.FindValue(dp, 1));
	return Plugin_Stop;
}

void __HealTowardsMax(int client, int amount, int max)
{
	float hb = L4D_GetTempHealth(client) + amount;
	float overflow = hb + GetClientHealth(client) - max;
	if (overflow > 0)
	{
		hb -= overflow;
	}
	L4D_SetTempHealth(client, hb);
}


/**
 * ConVar Change
 */

void CvarChg_PillHot(ConVar convar, const char[] oldValue, const char[] newValue)
{
	TogglePillHot(hCvarPillHot.BoolValue);
	SwitchGeneralEventHooks(hCvarPillHot.BoolValue || (hCvarAdrenHot && hCvarAdrenHot.BoolValue));
}

void CvarChg_AdrenHot(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ToggleAdrenHot(hCvarAdrenHot.BoolValue);
	SwitchGeneralEventHooks(hCvarPillHot.BoolValue || (hCvarAdrenHot && hCvarAdrenHot.BoolValue));
}

void TogglePillHot(bool enable)
{
	static bool enabled = false;
	static int origValue;
	
	if (enable && !enabled)
	{
		pain_pills_health_value.Flags &= ~FCVAR_REPLICATED;
		origValue = pain_pills_health_value.IntValue;
		pain_pills_health_value.IntValue = 0;
		
		HookEvent("pills_used", PillsUsed_Event);
		
		enabled = true;
	}
	else if (!enable && enabled)
	{
		pain_pills_health_value.Flags &= FCVAR_REPLICATED;
		pain_pills_health_value.IntValue = origValue;
		
		UnhookEvent("pills_used", PillsUsed_Event);
		
		enabled = false;
	}
}

void ToggleAdrenHot(bool enable)
{
	static bool enabled = false;
	static int origValue;
	
	if (enable && !enabled)
	{
		adrenaline_health_buffer.Flags &= ~FCVAR_REPLICATED;
		origValue = adrenaline_health_buffer.IntValue;
		adrenaline_health_buffer.IntValue = 0;
		
		HookEvent("adrenaline_used", AdrenalineUsed_Event);
		
		enabled = true;
	}
	else if (!enable && enabled)
	{
		adrenaline_health_buffer.Flags &= FCVAR_REPLICATED;
		adrenaline_health_buffer.IntValue = origValue;
		
		UnhookEvent("adrenaline_used", AdrenalineUsed_Event);
		
		enabled = false;
	}
}

void SwitchGeneralEventHooks(bool hook)
{
	static bool hooked = false;
	
	if (hook && !hooked)
	{
		HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("player_bot_replace", Event_Player_BotReplace);
		HookEvent("bot_player_replace", Event_Bot_PlayerReplace);
		
		hooked = true;
	}
	else if (!hook && hooked)
	{
		UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("player_bot_replace", Event_Player_BotReplace);
		UnhookEvent("bot_player_replace", Event_Bot_PlayerReplace);
		
		hooked = false;
	}
}