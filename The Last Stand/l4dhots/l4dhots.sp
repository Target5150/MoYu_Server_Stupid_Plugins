#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.7"

public Plugin myinfo = 
{
    name = "L4D HOTs",
    author = "ProdigySim, CircleSquared, Forgetest",
    description = "Pills and Adrenaline heal over time",
    version = PLUGIN_VERSION,
    url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
}

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

#define TEAM_SURVIVOR 2

#define WEPID_PAIN_PILLS 15
#define WEPID_ADRENALINE 23

ConVar pain_pills_decay_rate;
float fDecayRate;

enum struct Temporary
{
	float buffer[MAXPLAYERS+1];
	float timestamp[MAXPLAYERS+1];
	
	void Clear() {
		for (int i = 1; i <= MaxClients; i++) {
			this.buffer[i] = 0.0;
			this.timestamp[i] = 0.0;
		}
	}
	
	void Reset(int client) {
		this.Set2(client, 0.0, 0.0);
	}
	
	void Set(int client) {
		this.buffer[client] = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
		this.timestamp[client] = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	}
	
	void Set2(int client, float buffer, float timestamp) {
		this.buffer[client] = buffer;
		this.timestamp[client] = timestamp;
	}
	
	void Apply(int client) {
		float buffer = MAX(0.0, this.buffer[client] - ((GetGameTime() - this.timestamp[client]) * fDecayRate));
		float timestamp = GetGameTime();
		
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", buffer);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", timestamp);
		
		this.Set2(client, buffer, timestamp);
	}
}

Temporary g_SurvTemporary;

int g_iReplaceClient[MAXPLAYERS+1];
Handle g_hReplaceTimer[MAXPLAYERS+1];

bool IsL4D2;

ConVar pillhot;
ConVar hCvarPillInterval;
ConVar hCvarPillIncrement;
ConVar hCvarPillTotal;

ConVar adrenhot;
ConVar hCvarAdrenInterval;
ConVar hCvarAdrenIncrement;
ConVar hCvarAdrenTotal;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) IsL4D2 = false;
	else if( test == Engine_Left4Dead2 ) IsL4D2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
	fDecayRate = pain_pills_decay_rate.FloatValue;
	pain_pills_decay_rate.AddChangeHook(DecayRateChanged);
	
	pillhot = CreateConVar("l4d_pills_hot", "0", "Pills heal over time");
	hCvarPillInterval = CreateConVar("l4d_pills_hot_interval", "1.0", "Interval for pills hot");
	hCvarPillIncrement = CreateConVar("l4d_pills_hot_increment", "10", "Increment amount for pills hot");
	hCvarPillTotal = CreateConVar("l4d_pills_hot_total", "50", "Total amount for pills hot");
	
	if (GetConVarBool(pillhot)) EnablePillHot();
	HookConVarChange(pillhot, PillHotChanged);
	
	if (IsL4D2)
	{
		adrenhot = CreateConVar("l4d_adrenaline_hot", "0", "Adrenaline heals over time");
		hCvarAdrenInterval = CreateConVar("l4d_adrenaline_hot_interval", "1.0", "Interval for adrenaline hot");
		hCvarAdrenIncrement = CreateConVar("l4d_adrenaline_hot_increment", "15", "Increment amount for adrenaline hot");
		hCvarAdrenTotal = CreateConVar("l4d_adrenaline_hot_total", "25", "Total amount for adrenaline hot");
		
		if (GetConVarBool(adrenhot)) EnableAdrenHot();
		HookConVarChange(adrenhot, AdrenHotChanged);
	}
}

public void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	g_SurvTemporary.Clear();
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iReplaceClient[i] = -1;
		g_hReplaceTimer[i] = null;
	}
}

public void DelayRecord(int client)
{
	if (IsSurvivor(client))
	{
		g_SurvTemporary.Set(client);
	}
}

public void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client)
	{
		int team = event.GetInt("team");
		int oldteam = event.GetInt("oldteam");
		
		if (team == TEAM_SURVIVOR)
		{
			RequestFrame(DelayRecord, client);
		}
		else if (oldteam != TEAM_SURVIVOR) { return; }
		
		g_SurvTemporary.Reset(client);
	}
}

public void PlayerHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client) RequestFrame(DelayRecord, client);
}

public void HealSuccess_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if (client) RequestFrame(DelayRecord, client);
}

public void WeaponFire_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsSurvivor(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	if (!IsL4D2) // seems WeaponID not work in L4D1, untested.
	{
		static char weapon[32];
		event.GetString("weapon", weapon, sizeof(weapon));
		if (strcmp(weapon[7], "pain_pills") == 0)
		{
			g_SurvTemporary.Set(client);
		}
	}
	else
	{
		int wepid = event.GetInt("weaponid");
		if (wepid == WEPID_PAIN_PILLS || wepid == WEPID_ADRENALINE)
		{
			g_SurvTemporary.Set(client);
		}
	}
}

public void Player_BotReplace_Event(Event event, const char[] name, bool dontBroadcast)
{
	int replacer = GetClientOfUserId(event.GetInt("bot"));
	int replacee = GetClientOfUserId(event.GetInt("player"));
	
	if (replacer && replacee)
	{
		g_iReplaceClient[replacee] = replacer;
		if (g_hReplaceTimer[replacee])
		{
			delete g_hReplaceTimer[replacee];
			g_hReplaceTimer[replacee] = CreateTimer(0.1, Timer_ResetReplace, replacee);
		}
	}
}

public void Bot_PlayerReplace_Event(Event event, const char[] name, bool dontBroadcast)
{
	int replacer = GetClientOfUserId(event.GetInt("player"));
	int replacee = GetClientOfUserId(event.GetInt("bot"));
	
	if (replacer && replacee)
	{
		g_iReplaceClient[replacee] = replacer;
		if (g_hReplaceTimer[replacee])
		{
			delete g_hReplaceTimer[replacee];
			g_hReplaceTimer[replacee] = CreateTimer(0.1, Timer_ResetReplace, replacee);
		}
	}
}

public Action Timer_ResetReplace(Handle timer, int client)
{
	g_hReplaceTimer[client] = null;
	g_iReplaceClient[client] = -1;
}

public void PillsUsed_Event(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	if (userid)
	{
		float iPillInterval = GetConVarFloat(hCvarPillInterval);
		int iPillIncrement = GetConVarInt(hCvarPillIncrement);
		int iPillTotal = GetConVarInt(hCvarPillTotal);
		HealEntityOverTime(userid, iPillInterval, iPillIncrement, iPillTotal);
	}
}

public void AdrenalineUsed_Event(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	if (userid)
	{
		float iAdrenInterval = GetConVarFloat(hCvarAdrenInterval);
		int iAdrenIncrement = GetConVarInt(hCvarAdrenIncrement);
		int iAdrenTotal = GetConVarInt(hCvarAdrenTotal);
		HealEntityOverTime(userid, iAdrenInterval, iAdrenIncrement, iAdrenTotal);
	}
}

void HealEntityOverTime(int userid, float interval, int increment, int total)
{
    int client = GetClientOfUserId(userid);
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
    {
        return;
    }
    
    int maxhp = GetEntProp(client, Prop_Send, "m_iMaxHealth", 2);
    
    // Override vanilla healing
    g_SurvTemporary.Apply(client);
    
    if (increment >= total)
    {
        HealTowardsMax(client, total, maxhp);
    }
    else
    {
        HealTowardsMax(client, increment, maxhp);
        DataPack myDP;
        CreateDataTimer(interval, __HOT_ACTION, myDP, 
            TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        WritePackCell(myDP, userid);
        WritePackCell(myDP, client);
        WritePackCell(myDP, increment);
        WritePackCell(myDP, total-increment);
        WritePackCell(myDP, maxhp);
    }
}

public Action __HOT_ACTION(Handle timer, DataPack pack)
{
	ResetPack(pack);
	DataPackPos pos = GetPackPosition(pack);
	int userid = ReadPackCell(pack);
	int lastClient = ReadPackCell(pack);
	int client = GetClientOfUserId(userid);
	
	if (!client || !IsSurvivor(client))
	{
		if (g_iReplaceClient[lastClient] > 0)
		{
			client = g_iReplaceClient[lastClient];
			userid = GetClientUserId(client);
			
			SetPackPosition(pack, pos);
			WritePackCell(pack, userid);
			WritePackCell(pack, client);
		}
		else { return Plugin_Stop; }
	}
	
	int increment = ReadPackCell(pack);
	pos = GetPackPosition(pack);
	int remaining = ReadPackCell(pack);
	int maxhp = ReadPackCell(pack);
	
	//PrintToChatAll("HOT: %d %d %d %d", client, increment, remaining, maxhp);
	
	if (IsIncapacitated(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
    
	if (increment >= remaining)
	{
		HealTowardsMax(client, remaining, maxhp);
		return Plugin_Stop;
	}
	HealTowardsMax(client, increment, maxhp);
	SetPackPosition(pack, pos);
	WritePackCell(pack, remaining-increment);
	
	return Plugin_Continue;
}

void HealTowardsMax(int client, int amount, int max)
{
    float hb = float(amount) + GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    float overflow = (hb+GetClientHealth(client))-max;
    if (overflow > 0)
    {
        hb -= overflow;
    }
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", hb);
    
    g_SurvTemporary.Set(client);
}


/**
 * ConVar Change
 */

public void PillHotChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    bool newval = StringToInt(newValue)!=0;
    if (newval && StringToInt(oldValue) ==0)
    {
        EnablePillHot();
    }
    else if (!newval && StringToInt(oldValue) != 0)
    {
        DisablePillHot();
    }
}

public void AdrenHotChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    bool newval = StringToInt(newValue)!=0;
    if (newval && StringToInt(oldValue) ==0)
    {
        EnableAdrenHot();
    }
    else if (!newval && StringToInt(oldValue) != 0)
    {
        DisableAdrenHot();
    }
}

void EnablePillHot()	{ SwitchEventHooks(true);				HookEvent("pills_used", PillsUsed_Event); }
void EnableAdrenHot()	{ SwitchEventHooks(true);				HookEvent("adrenaline_used", AdrenalineUsed_Event); }
void DisablePillHot()	{ SwitchEventHooks(adrenhot.BoolValue);	UnhookEvent("pills_used", PillsUsed_Event); }
void DisableAdrenHot()	{ SwitchEventHooks(pillhot.BoolValue);	UnhookEvent("adrenaline_used", AdrenalineUsed_Event); }

void SwitchEventHooks(bool hook)
{
	static bool hooked = false;
	
	if (hook && !hooked)
	{
		HookEvent("round_start", RoundStart_Event);
		HookEvent("player_team", PlayerTeam_Event);
		HookEvent("player_hurt", PlayerHurt_Event);
		HookEvent("heal_success", HealSuccess_Event);
		HookEvent("weapon_fire", WeaponFire_Event);
		HookEvent("player_bot_replace", Player_BotReplace_Event);
		HookEvent("bot_player_replace", Bot_PlayerReplace_Event);
		
		hooked = true;
	}
	
	if (!hook && hooked)
	{
		UnhookEvent("round_start", RoundStart_Event);
		UnhookEvent("player_team", PlayerTeam_Event);
		UnhookEvent("player_hurt", PlayerHurt_Event);
		UnhookEvent("heal_success", HealSuccess_Event);
		UnhookEvent("weapon_fire", WeaponFire_Event);
		UnhookEvent("player_bot_replace", Player_BotReplace_Event);
		UnhookEvent("bot_player_replace", Bot_PlayerReplace_Event);
		
		hooked = false;
	}
}

public void DecayRateChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fDecayRate = pain_pills_decay_rate.FloatValue;
}


/**
 * Stock
 */
stock bool IsSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

stock bool IsIncapacitated(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}
