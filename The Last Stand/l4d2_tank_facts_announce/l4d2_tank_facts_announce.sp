#include <sourcemod>
#include <sdkhooks>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.6"

public Plugin myinfo = 
{
	name = "L4D2 Tank Facts Announce",
	author = "Forgetest (credit to Griffin and Blade)",
	description = "Announce damage dealt to survivors by tank",
	version = PLUGIN_VERSION,
	url = "?"
};

enum struct ITankAttack
{
	int Punch;
	int Rock;
	int Hittable;
	
	void Init() {
		this.Punch = this.Rock = this.Hittable = 0;
	}
}
static ITankAttack		g_eTankAttack;

enum struct IAttackResult
{
	int Incap;
	int Death;
	int TotalDamage;
	
	void Init() {
		this.Incap = this.Death = this.TotalDamage = 0;
	}
}
static IAttackResult	g_eTankResult;


static int			g_iTankClient						= 0;
static int			g_iPlayerLastHealth[MAXPLAYERS+1]	= 0;
static bool			g_bAnnounceTankFacts				= false;
static bool			g_bTankInPlay						= false;
static float		g_fTankSpawnTime					= 0.0;
static char			g_sLastHumanTankName[MAX_NAME_LENGTH];

static bool			bLateLoad;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_Max)
{
	bLateLoad = late;
	return APLRes_Success;
}

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
			if (IsClientInGame(i)) OnClientPutInServer(i);
	}
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ClearStuff();
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bAnnounceTankFacts) PrintTankSkill();
	ClearStuff();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	if (g_bTankInPlay && !IsFakeClient(client) && client == g_iTankClient)
	{
		CreateTimer(0.1, Timer_CheckTank, client); // Use a delayed timer due to bugs where the tank passes to another player
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_bTankInPlay) return Plugin_Continue;
	
	if (!IsValidEntity(victim) || !attacker || !IsValidEntity(attacker) || !IsValidEdict(inflictor)) return Plugin_Continue;
	
	if (!IsSurvivor(victim) || !IsTank(attacker)) return Plugin_Continue;
	
	//char classname[64];
	//GetEdictClassname(inflictor, classname, sizeof(classname));
	
	if (attacker == g_iTankClient /*|| IsTankHittable(classname)*/)
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
	g_bAnnounceTankFacts = true;
	g_fTankSpawnTime = GetGameTime() + FindConVar("director_tank_lottery_selection_time").FloatValue;
}

public void Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bTankInPlay) return;
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim || !IsSurvivor(victim) || IsIncapacitated(victim)) return;
	
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	char weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (attacker != g_iTankClient) return;
	
	int dmg = GetEventInt(event, "dmg_health");
	if (dmg > 0)
	{
		if (StrEqual(weapon, "tank_claw")) {
			g_eTankAttack.Punch++;
		} else if (StrEqual(weapon, "tank_rock")) {
			g_eTankAttack.Rock++;
		//} else if (IsTankHittable(weapon)) {
		} else { // alternation due to l4d2_hittable_control setting 'inflictor' as hittable to 0
			g_eTankAttack.Hittable++;
		}
		
		g_eTankResult.TotalDamage += dmg;
	}
}

public void Event_PlayerIncapStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bTankInPlay) return;
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim || !IsSurvivor(victim)) return;
	
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	char weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (StrEqual(weapon, "tank_claw")) {
		g_eTankAttack.Punch++;
	} else if (StrEqual(weapon, "tank_rock")) {
		g_eTankAttack.Rock++;
	//} else if (IsTankHittable(weapon)) {
	} else if (attacker == g_iTankClient) { // alternation due to l4d2_hittable_control setting 'inflictor' as hittable to 0
		g_eTankAttack.Hittable++;
	}
	
	g_eTankResult.Incap++;
	if (attacker == g_iTankClient) g_eTankResult.TotalDamage += g_iPlayerLastHealth[victim];
}

public void Event_PlayerKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bTankInPlay) return;
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!victim) return;
	
	if (IsSurvivor(victim))
	{
		g_eTankResult.Death++;
	}
	else if (victim == g_iTankClient)
	{
		CreateTimer(0.1, Timer_CheckTank, victim);
	}
}

public Action Timer_CheckTank(Handle timer, int oldtankclient)
{
	if (g_iTankClient != oldtankclient) return; // Tank passed

	int tankclient = FindTankClient(-1);
	if (tankclient && tankclient != oldtankclient)
	{
		g_iTankClient = tankclient;
		return;
	}

	if (g_bAnnounceTankFacts) PrintTankSkill();
	
	ClearStuff();
}

public void PrintTankSkill()
{
	int tankclient = GetTankClient();
	if (!tankclient) return;
	
	char name[MAX_NAME_LENGTH], buffer[16], info[128];
	if (IsFakeClient(tankclient))
	{
		if (g_sLastHumanTankName[0] != '\0')
			Format(name, sizeof(name), "AI [%s]", g_sLastHumanTankName);
		else Format(name, sizeof(name), "AI");
	}
	else GetClientName(tankclient, name, sizeof(name));
	
	int duration = RoundToFloor(GetGameTime() - g_fTankSpawnTime);
	if (duration > 60)
	{
		Format(buffer, sizeof(buffer), "%dmin %ds", duration / 60, duration % 60);
	}
	else
	{
		Format(buffer, sizeof(buffer), "%ds", duration > 0 ? duration : 0);
	}
	
	DataPack dp;
	CreateDataTimer(3.0, Timer_PrintToChat, dp);
	
	// [!] Facts of the Tank (AI)
	// > Punch: 4 / Rock: 2 / Hittable: 0
	// > Incap: 1 / Death: 0 from Survivors
	// > Duration: 1min 7s / Total Damage: 144
	
	FormatEx(info, sizeof(info), "[{green}!{default}] {blue}Facts {default}of the {blue}Tank {default}({olive}%s{default})", name);
	dp.WriteString(info);
	FormatEx(info, sizeof(info), "{green}> {default}Punch: {red}%i {green}/ {default}Rock: {red}%i {green}/ {default}Hittable: {red}%i", g_eTankAttack.Punch, g_eTankAttack.Rock, g_eTankAttack.Hittable);
	dp.WriteString(info);
	FormatEx(info, sizeof(info), "{green}> {default}Incap: {olive}%i {green}/ {default}Death: {olive}%i {default}from {blue}Survivors", g_eTankResult.Incap, g_eTankResult.Death);
	dp.WriteString(info);
	FormatEx(info, sizeof(info), "{green}> {default}Duration: {lightgreen}%s {green}/ {default}Total damage: {lightgreen}%i", buffer, g_eTankResult.TotalDamage);
	dp.WriteString(info);
}

public Action Timer_PrintToChat(Handle timer, DataPack dp)
{
	dp.Reset();
	
	// Processing teamcolor tags requires a few more time than doing non-teamcolor ones
	// To print messages in a proper order, extra tags are added to slow processing of certain messages down
	
	char info[128];
	dp.ReadString(info, sizeof(info));
	CPrintToChatAll(info);
	dp.ReadString(info, sizeof(info));
	CPrintToChatAll("{red}%s", info);
	dp.ReadString(info, sizeof(info));
	CPrintToChatAll("{blue}{blue}%s", info);
	dp.ReadString(info, sizeof(info));
	CPrintToChatAll("{lightgreen}{lightgreen}{lightgreen}%s", info);
	
	// Since the DataTimer would auto-close handles passed,
	// here we've just done.
}

public void ClearStuff()
{
	g_iTankClient = 0;
	g_bTankInPlay = false;
	g_bAnnounceTankFacts = false;
	g_fTankSpawnTime = 0.0;
	strcopy(g_sLastHumanTankName, sizeof(g_sLastHumanTankName), "");
	
	g_eTankAttack.Init();
	g_eTankResult.Init();
	
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
		tankclient = FindTankClient(-1); // find the tank client
		if (!tankclient) return 0;
		g_iTankClient = tankclient;
	}

	return tankclient;
}
