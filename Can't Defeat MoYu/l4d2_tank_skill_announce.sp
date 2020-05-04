#include <sourcemod>
#include <sdkhooks>
#include <colors>

#pragma semicolon 1
#pragma newdecls required

enum L4D2_Team
{
    L4D2Team_Spectator = 1,
    L4D2Team_Survivor,
    L4D2Team_Infected
};

enum L4D2_Infected
{
    L4D2Infected_Smoker = 1,
    L4D2Infected_Boomer,
    L4D2Infected_Hunter,
    L4D2Infected_Spitter,
    L4D2Infected_Jockey,
    L4D2Infected_Charger,
    L4D2Infected_Witch,
    L4D2Infected_Tank
};

enum AttackType
{
	Punch,
	Rock,
	Prop
}
static int			g_iTankAttack[AttackType]			= 0;

enum AttackResult
{
	Incap,
	Death,
	TotalDamage
}
static int			g_iTankResult[AttackResult]			= 0;


static int			g_iTankClient						= 0;
static int			g_iPlayerLastHealth[MAXPLAYERS+1]	= 0;
static bool			g_bAnnounceTankSkill				= false;
static bool			g_bTankInPlay						= false;
static float		g_fTankSpawnTime					= 0.0;
static char			g_sLastHumanTankName[MAX_NAME_LENGTH];

static bool			bLateLoad;


public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_Max)
{
	bLateLoad = late;
	return APLRes_Success;
}

public Plugin myinfo = 
{
	name = "L4D2 Tank Skill Announce",
	author = "Forgetest (Griffin and Blade, as author of l4d_tank_damage_announce)",
	description = "Announce damage dealt to survivors by tank",
	version = "1.2",
	url = "?"
};

public void OnPluginStart()
{
	HookEvent("round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", Event_OnTankSpawn);
	HookEvent("player_hurt", Event_OnPlayerHurt);
	HookEvent("player_incapacitated_start", Event_PlayerIncapStart);
	HookEvent("player_death", Event_PlayerKilled);
	
	if (bLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i)) OnClientPutInServer(i);
		}
	}
}

public void Event_OnRoundStart(Handle event, const char[] name, bool dontBroadcast) { ClearStuff(); }

public void Event_OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_bAnnounceTankSkill) PrintTankSkill();
	ClearStuff();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect_Post(int client)
{
	if (!g_bTankInPlay || client != g_iTankClient) return;
	CreateTimer(0.1, Timer_CheckTank, client); // Use a delayed timer due to bugs where the tank passes to another player
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsValidSurvivor(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor)) return Plugin_Continue;
	
	if (!g_bTankInPlay) return Plugin_Continue;
	
	char classname[64];
	GetEdictClassname(inflictor, classname, sizeof(classname));
	
	if (attacker == g_iTankClient || IsTankHittable(classname))
	{
		int playerHealth = GetSurvivorPermanentHealth(victim) + GetSurvivorTemporaryHealth(victim);
		if (RoundToFloor(damage) >= playerHealth)
		{
			/* Store HP only when the damage is greater than this, so we can turn to IncapStart for Damage record */
			g_iPlayerLastHealth[victim] = playerHealth;
		}
	}
		
	return Plugin_Continue;
}

public void Event_OnTankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_iTankClient = client;
	if (!IsFakeClient(client)) GetClientName(client, g_sLastHumanTankName, sizeof(g_sLastHumanTankName));
	
	if (g_bTankInPlay) return;
	
	g_bTankInPlay = true;
	g_bAnnounceTankSkill = true;
	g_fTankSpawnTime = GetGameTime() + FindConVar("director_tank_lottery_selection_time").FloatValue;
}

public void Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bTankInPlay) return;
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidSurvivor(victim) || IsIncapacitated(victim)) return;
	
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	char weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (attacker != g_iTankClient) return;
	
	int dmg = GetEventInt(event, "dmg_health");
	if (dmg > 0)
	{
		if (StrEqual(weapon, "tank_claw"))
		{
			g_iTankAttack[Punch]++;
		}
		if (StrEqual(weapon, "tank_rock"))
		{
			g_iTankAttack[Rock]++;
		}
		if (IsTankHittable(weapon))
		{
			g_iTankAttack[Prop]++;
		}
		g_iTankResult[TotalDamage] += dmg;
	}
}

public void Event_PlayerIncapStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bTankInPlay) return;
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidSurvivor(victim)) return;
	
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	char weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (attacker != g_iTankClient) return;
	
	if (StrEqual(weapon, "tank_claw"))
	{
		g_iTankAttack[Punch]++;
	}
	if (StrEqual(weapon, "tank_rock"))
	{
		g_iTankAttack[Rock]++;
	}
	if (IsTankHittable(weapon))
	{
		g_iTankAttack[Prop]++;
	}
	g_iTankResult[Incap]++;
	g_iTankResult[TotalDamage] += g_iPlayerLastHealth[victim];
}

public void Event_PlayerKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bTankInPlay) return;
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	char weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (IsValidSurvivor(victim) && (attacker == g_iTankClient || IsTankHittable(weapon)))
	{
		g_iTankResult[Death]++;
	}
	else if (victim == g_iTankClient)
	{
		CreateTimer(0.1, Timer_CheckTank, victim);
	}
}

public Action Timer_CheckTank(Handle timer, any oldtankclient)
{
	if (g_iTankClient != oldtankclient) return; // Tank passed

	int tankclient = FindTankClient();
	if (tankclient && tankclient != oldtankclient)
	{
		g_iTankClient = tankclient;
		return;
	}

	if (g_bAnnounceTankSkill) PrintTankSkill();
	
	ClearStuff();
}

public void PrintTankSkill()
{
	int tankclient = GetTankClient();
	if (!tankclient) return;
	
	char name[MAX_NAME_LENGTH], buffer[32], info[512];
	if (IsFakeClient(tankclient))
	{
		if (g_sLastHumanTankName[0] != '\0')
			Format(name, sizeof(name), "AI [%s]", g_sLastHumanTankName);
		else Format(name, sizeof(name), "AI");
	}
	else strcopy(name, sizeof(name), g_sLastHumanTankName);
	
	int duration = RoundToFloor(GetGameTime() - g_fTankSpawnTime);
	if (duration > 60)
	{
		Format(buffer, sizeof(buffer), "%dmin %ds", duration / 60, duration % 60);
	}
	else
	{
		Format(buffer, sizeof(buffer), "%ds", duration);
	}
	
	DataPack pack = new DataPack();
	CreateDataTimer(5.0, Timer_PrintToChat, pack);
	Format(info, sizeof(info), "[{green}!{default}] {blue}Tank {default}({olive}%s{default}) has {blue}Survived {default}for {green}%s{default}, dealt {green}%d {blue}Damage{default}", name, buffer, g_iTankResult[TotalDamage]);
	pack.WriteString(info);
	Format(info, sizeof(info), "[{green}Detail{default}] Punch {blue}[{olive}%d{blue}] {default}| Rock {blue}[{olive}%d{blue}] {default}| Prop {blue}[{olive}%d{blue}] {default}| Incap {blue}[{olive}%d{blue}] {default}| Death {blue}[{olive}%d{blue}]", g_iTankAttack[Punch], g_iTankAttack[Rock], g_iTankAttack[Prop], g_iTankResult[Incap], g_iTankResult[Death]);
	pack.WriteString(info);
}

public Action Timer_PrintToChat(Handle timer, DataPack pack)
{
	pack.Reset();
	
	char info[512];
	pack.ReadString(info, sizeof(info));
	CPrintToChatAll(info);
	pack.ReadString(info, sizeof(info));
	CPrintToChatAll(info);
}

public void ClearStuff()
{
	g_iTankClient = 0;
	g_bTankInPlay = false;
	g_bAnnounceTankSkill = false;
	g_fTankSpawnTime = 0.0;
	g_sLastHumanTankName = "";
	
	for (int i = 0; i < 3; i++)
	{
		g_iTankAttack[i] = 0;
		g_iTankResult[i] = 0;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iPlayerLastHealth[i] = 0;
	}
}


/* Stocks */

stock int GetTankClient()
{
	if (!g_bTankInPlay) return 0;

	int tankclient = g_iTankClient;

	if (!IsClientInGame(tankclient)) // If tank somehow is no longer in the game (kicked, hence events didn't fire)
	{
		tankclient = FindTankClient(); // find the tank client
		if (!tankclient) return 0;
		g_iTankClient = tankclient;
	}

	return tankclient;
}

stock int FindTankClient()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsTank(i) || !IsPlayerAlive(i))
			continue;

		return i; // Found tank, return
	}
	return 0;
}

stock int GetSurvivorPermanentHealth(int client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock int GetSurvivorTemporaryHealth(int client)
{
	float fDecayRate = GetConVarFloat(FindConVar("pain_pills_decay_rate"));
	float fHealthBuffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	float fHealthBufferTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	int iTempHp = RoundToCeil(fHealthBuffer - ((GetGameTime() - fHealthBufferTime) * fDecayRate)) - 1;
	return iTempHp > 0 ? iTempHp : 0;
}

stock bool IsTankHittable(char[] sClassname)
{
    return StrEqual(sClassname, "prop_physics") || StrEqual(sClassname, "prop_car_alarm");
}

stock bool IsIncapacitated(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

stock bool IsValidSurvivor(int client)
{
	return IsValidClient(client) && view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Survivor;
}

stock bool IsValidInfected(int client)
{
    return IsValidClient(client) && view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Infected;
}

stock bool IsTank(int client)
{
    return IsValidInfected(client) && GetInfectedClass(client) == L4D2Infected_Tank;
}

stock L4D2_Infected GetInfectedClass(int client)
{
    return view_as<L4D2_Infected>(GetEntProp(client, Prop_Send, "m_zombieClass"));
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}