#include <sourcemod>
#include <sdktools>
#include <l4d2_weapon_stocks>
#include <colors>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"3.3.1"

#define SPECHUD_DRAW_INTERVAL   0.5

#define ZOMBIECLASS_NAME(%0) (L4D2SI_Names[(%0)])

#define CLAMP(%0,%1,%2) (((%0) > (%2)) ? (%2) : (((%0) < (%1)) ? (%1) : (%0)))
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))

public Plugin myinfo = 
{
	name = "Hyper-V HUD Manager",
	author = "Visor, Forgetest",
	description = "Provides different HUDs for spectators",
	version = PLUGIN_VERSION,
	url = "https://github.com/Attano/smplugins"
};

enum L4D2Gamemode
{
	L4D2Gamemode_None,
	L4D2Gamemode_Versus,
	L4D2Gamemode_Scavenge
};

enum L4D2SI 
{
	ZC_None,
	ZC_Smoker,
	ZC_Boomer,
	ZC_Hunter,
	ZC_Spitter,
	ZC_Jockey,
	ZC_Charger,
	ZC_Witch,
	ZC_Tank
};
//L4D2SI storedClass[MAXPLAYERS+1];

enum SurvivorCharacter
{
	SC_NONE=-1,
	SC_NICK=0,
	SC_ROCHELLE,
	SC_COACH,
	SC_ELLIS,
	SC_BILL,
	SC_ZOEY,
	SC_LOUIS,
	SC_FRANCIS
};
ArrayList	hSurvivorArray;
bool		bRefresh;

static const char L4D2SI_Names[][] = 
{
	"None",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank"
};

ConVar survivor_limit;
ConVar z_max_player_zombies;
ConVar l4d_tank_percent;
ConVar l4d_witch_percent;

bool bSpecHudActive[MAXPLAYERS+1];
bool bSpecHudHintShown[MAXPLAYERS+1];
bool bTankHudActive[MAXPLAYERS+1];
bool bTankHudHintShown[MAXPLAYERS+1];

bool bIsLive;

int iTankCount;
int iWitchCount;
StringMap hFirstTankSpawningScheme;
StringMap hSecondTankSpawningScheme;
StringMap hFinaleExceptionMaps;

bool bFlowTankActive;

int iFirstHalfScore;

int ammoOffset;

bool bScoremod;
bool bHybridScoremod;

// readyup
native bool IsInReady();

// pause
native bool IsInPause();

// l4d2_hybrid_scoremod
native int SMPlus_GetHealthBonus();
native int SMPlus_GetDamageBonus();
native int SMPlus_GetPillsBonus();
native int SMPlus_GetMaxHealthBonus();
native int SMPlus_GetMaxDamageBonus();
native int SMPlus_GetMaxPillsBonus();

// l4d2_scoremod
native int HealthBonus();

// l4d_tank_control_eq
native int GetTankSelection();

// l4d2_boss_percent (Credit to spoon)
native bool IsStaticTankMap();
native bool IsStaticWitchMap();
native bool IsDarkCarniRemix();
native int GetStoredTankPercent();
native int GetStoredWitchPercent();

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("IsInReady");
	MarkNativeAsOptional("IsInPause");
	MarkNativeAsOptional("SMPlus_GetHealthBonus");
	MarkNativeAsOptional("SMPlus_GetDamageBonus");
	MarkNativeAsOptional("SMPlus_GetPillsBonus");
	MarkNativeAsOptional("SMPlus_GetMaxHealthBonus");
	MarkNativeAsOptional("SMPlus_GetMaxDamageBonus");
	MarkNativeAsOptional("SMPlus_GetMaxPillsBonus");
	MarkNativeAsOptional("HealthBonus");
	MarkNativeAsOptional("GetTankSelection");
	MarkNativeAsOptional("IsStaticTankMap");
	MarkNativeAsOptional("IsStaticWitchMap");
	MarkNativeAsOptional("GetStoredTankPercent");
	MarkNativeAsOptional("GetStoredWitchPercent");
	MarkNativeAsOptional("IsDarkCarniRemix");
}

public void OnPluginStart()
{
	survivor_limit			= FindConVar("survivor_limit");
	z_max_player_zombies	= FindConVar("z_max_player_zombies");
	l4d_tank_percent		= FindConVar("l4d_tank_percent");
	l4d_witch_percent		= FindConVar("l4d_witch_percent");
	
	hSurvivorArray				= new ArrayList();
	hFirstTankSpawningScheme	= new StringMap();
	hSecondTankSpawningScheme	= new StringMap();
	hFinaleExceptionMaps		= new StringMap();
	
	ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
	
	RegConsoleCmd("sm_spechud", ToggleSpecHudCmd);
	RegConsoleCmd("sm_tankhud", ToggleTankHudCmd);
	
	RegServerCmd("tank_map_flow_and_second_event",	SetMapFirstTankSpawningScheme);
	RegServerCmd("tank_map_only_first_event",		SetMapSecondTankSpawningScheme);
	RegServerCmd("finale_tank_default",				SetFinaleExceptionMap);
	
	HookEvent("round_end", view_as<EventHook>(OnRoundEnd), EventHookMode_PostNoCopy);
	HookEvent("player_death",	OnPlayerDeath);
	HookEvent("player_team",	OnPlayerTeam);
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		bSpecHudActive[i] = false;
		bSpecHudHintShown[i] = false;
		bTankHudActive[i] = true;
		bTankHudHintShown[i] = false;
	}
	
	CreateTimer(SPECHUD_DRAW_INTERVAL, HudDrawTimer, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	delete hSurvivorArray;
	delete hFirstTankSpawningScheme;
	delete hSecondTankSpawningScheme;
	delete hFinaleExceptionMaps;
}

public void OnAllPluginsLoaded() { bScoremod = LibraryExists("l4d2_scoremod"); bHybridScoremod = LibraryExists("l4d2_hybrid_scoremod"); }
public void OnLibraryAdded(const char[] name) { if(StrEqual(name, "l4d2_scoremod")) bScoremod = true; if(StrEqual(name, "l4d2_hybrid_scoremod")) bHybridScoremod = true; }
public void OnLibraryRemoved(const char[] name) { if(StrEqual(name, "l4d2_scoremod")) bScoremod = false; if(StrEqual(name, "l4d2_hybrid_scoremod")) bHybridScoremod = false; }

public void OnClientPostAdminCheck(int client)
{
	if (IsClientInGame(client) && IsClientSourceTV(client)) // someday
	{
		bSpecHudActive[client] = true;
		bTankHudActive[client] = true;
	}
}

public void OnClientDisconnect(int client)
{
	if (IsClientSourceTV(client)) // whatever
	{
		bSpecHudActive[client] = false;
		bTankHudActive[client] = true;
		return;
	}
	
	bSpecHudHintShown[client] = false;
	bTankHudHintShown[client] = false;
	
	CreateTimer(5.0, Timer_CheckDisconnect, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CheckDisconnect(Handle timer, int client)
{
	if (!IsClientConnected(client)) // reset to default
	{
		bSpecHudActive[client] = false;
		bTankHudActive[client] = true;
	}
}

public void OnMapStart() { bIsLive = false; }
public void OnRoundEnd() { bIsLive = false; }
public void OnRoundIsLive()
{
	bIsLive = true;
	
	//for (int i = 1; i <= MaxClients; ++i) storedClass[i] = ZC_None;
	
	iTankCount = 0;
	iWitchCount = view_as<int>(l4d_witch_percent.BoolValue);
	
	if (GetConVarBool(l4d_tank_percent))
	{
		iTankCount = 1;
		bFlowTankActive = RoundHasFlowTank();
		
		static char mapname[64], dummy;
		GetCurrentMap(mapname, sizeof(mapname));
		
		if (StrEqual(mapname, "hf03_themansion")) iTankCount += 1;
		else if (!IsDarkCarniRemix() && L4D_IsMissionFinalMap())
		{
			iTankCount = 3
						- view_as<int>(hFirstTankSpawningScheme.GetValue(mapname, dummy))
						- view_as<int>(hSecondTankSpawningScheme.GetValue(mapname, dummy))
						- view_as<int>(hFinaleExceptionMaps.Size > 0 && !hFinaleExceptionMaps.GetValue(mapname, dummy))
						- view_as<int>(IsStaticTankMap());
		}
	}
}

public void L4D2_OnEndVersusModeRound_Post() { if (!InSecondHalfOfRound()) iFirstHalfScore = L4D_GetTeamScore(GetRealTeam(0) + 1); }

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || !IsInfected(client)) return;
	
	if (client <= MaxClients && GetInfectedClass(client) == ZC_Tank)
	{
		if (iTankCount > 0) iTankCount--;
		if (!RoundHasFlowTank()) bFlowTankActive = false;
	}
	else if (client > MaxClients && GetInfectedClass(client) == ZC_Witch)
	{
		if (iWitchCount > 0) iWitchCount--;
	}
}

public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		int team = GetEventInt(event, "team"), oldteam = GetEventInt(event, "oldteam");
		
		if (team == 2 || oldteam == 2) bRefresh = true;
		
		//if (team == 3) storedClass[client] = ZC_None;
	}
}

public Action ToggleSpecHudCmd(int client, int args) 
{
	bSpecHudActive[client] = !bSpecHudActive[client];
	CPrintToChat(client, "<{olive}HUD{default}> Spectator HUD is now %s.", (bSpecHudActive[client] ? "{blue}on{default}" : "{red}off{default}"));
}

public Action ToggleTankHudCmd(int client, int args) 
{
	bTankHudActive[client] = !bTankHudActive[client];
	CPrintToChat(client, "<{olive}HUD{default}> Tank HUD is now %s.", (bTankHudActive[client] ? "{blue}on{default}" : "{red}off{default}"));
}

public Action HudDrawTimer(Handle hTimer)
{
	if (IsInReady() || IsInPause())
		return Plugin_Continue;

	bool bSpecsOnServer = false;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsSpectator(i) && (bSpecHudActive[i] || IsClientSourceTV(i)))
		{
			bSpecsOnServer = true;
			break;
		}
	}

	if (bSpecsOnServer) // Only bother if someone's watching us
	{
		Panel specHud = new Panel();

		FillHeaderInfo(specHud);
		FillSurvivorInfo(specHud);
		FillInfectedInfo(specHud);
		FillTankInfo(specHud);
		FillGameInfo(specHud);

		for (int i = 1; i <= MaxClients; ++i)
		{
			if (!IsClientInGame(i) || !IsSpectator(i) || !bSpecHudActive[i] || IsFakeClient(i))
				continue;

			SendPanelToClient(specHud, i, DummySpecHudHandler, 3);
			if (!bSpecHudHintShown[i])
			{
				bSpecHudHintShown[i] = true;
				CPrintToChat(i, "<{olive}HUD{default}> Type {green}!spechud{default} into chat to toggle the {blue}Spectator HUD{default}.");
			}
		}

		delete specHud;
	}
	
	Panel tankHud = new Panel();
	if (!FillTankInfo(tankHud, true)) // No tank -- no HUD
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!bTankHudActive[i] || !IsClientInGame(i) || IsFakeClient(i) || IsSurvivor(i) || (bSpecHudActive[i] && IsSpectator(i)))
			continue;

		SendPanelToClient(tankHud, i, DummyTankHudHandler, 3);
		if (!bTankHudHintShown[i])
		{
			bTankHudHintShown[i] = true;
			CPrintToChat(i, "<{olive}HUD{default}> Type {green}!tankhud{default} into chat to toggle the {red}Tank HUD{default}.");
		}
	}

	delete tankHud;
	return Plugin_Continue;
}

public int DummySpecHudHandler(Menu hMenu, MenuAction action, int param1, int param2) {}
public int DummyTankHudHandler(Menu hMenu, MenuAction action, int param1, int param2) {}

void FillHeaderInfo(Panel hSpecHud)
{
	ConVar hServerNamer = FindConVar("sn_main_name");
	
	static char buffer[64];
	
	if (hServerNamer != null) {
		hServerNamer.GetString(buffer, sizeof(buffer));
	} else {
		FindConVar("hostname").GetString(buffer, sizeof(buffer));
	}
	
	Format(buffer, sizeof(buffer), "☂ %s [Slots %i/%i | %iT]", buffer, GetRealClientCount(), GetConVarInt(FindConVar("sv_maxplayers")), RoundToNearest(1.0 / GetTickInterval()));
	DrawPanelText(hSpecHud, buffer);
}

void GetMeleePrefix(int client, char[] prefix, int length)
{
	int secondary = GetPlayerWeaponSlot(client, view_as<int>(L4D2WeaponSlot_Secondary));
	WeaponId secondaryWep = IdentifyWeapon(secondary);

	char buf[4];
	switch (secondaryWep)
	{
		case WEPID_NONE: buf = "N";
		case WEPID_PISTOL: buf = (GetEntProp(secondary, Prop_Send, "m_isDualWielding") ? "DP" : "P");
		case WEPID_PISTOL_MAGNUM: buf = "DE";
		case WEPID_MELEE: buf = "M";
		default: buf = "?";
	}

	strcopy(prefix, length, buf);
}

void FillSurvivorInfo(Panel hSpecHud)
{
	static char info[512];
	static char buffer[64];
	static char name[MAX_NAME_LENGTH];

	int SurvivorTeamIndex = L4D2_AreTeamsFlipped() ? 1 : 0;
	
	int distance = 0;
	for (int i = 0; i < 4; ++i)
		distance += GameRules_GetProp("m_iVersusDistancePerSurvivor", _, i + 4 * SurvivorTeamIndex);
	
	FormatEx(info, sizeof(info), "->1. Survivors [%d]",
				L4D2Direct_GetVSCampaignScore(SurvivorTeamIndex) + (bIsLive ? distance : 0));
				
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, info);
	
	if (bRefresh)
	{
		bRefresh = false;
		PushSerialSurvivors(hSurvivorArray);
	}
	
	for (int i = 0; i < hSurvivorArray.Length; ++i)
	{
		int client = hSurvivorArray.Get(i);
		
		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client))
		{
			FormatEx(info, sizeof(info), "%s: Dead", name);
		}
		else
		{
			int primaryWep = GetPlayerWeaponSlot(client, view_as<int>(L4D2WeaponSlot_Primary));
			
			int activeWep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			WeaponId activeWepId = IdentifyWeapon(activeWep);

			switch (activeWepId)
			{
				case WEPID_PISTOL, WEPID_PISTOL_MAGNUM:
				{
					if (activeWepId == WEPID_PISTOL && view_as<bool>(GetEntProp(activeWep, Prop_Send, "m_isDualWielding")))
					{
						Format(buffer, sizeof(buffer), "DP");
					}
					else GetLongWeaponName(activeWepId, buffer, sizeof(buffer));
					
					FormatEx(info, sizeof(info), "%s %i", buffer, GetWeaponClip(activeWep));
				}
				default:
				{
					GetLongWeaponName(IdentifyWeapon(primaryWep), buffer, sizeof(buffer));
					FormatEx(info, sizeof(info), "%s %i/%i", buffer, GetWeaponClip(primaryWep), GetWeaponAmmo(client, primaryWep));
				}
			}
			
			// In case with no primary
			if (primaryWep == -1)
			{
				// Shows melee fullname (having melee active with no primary)
				if (activeWepId == WEPID_MELEE || activeWepId == view_as<WeaponId>(WEPID_CHAINSAW))
				{
					MeleeWeaponId meleeWepId = IdentifyMeleeWeapon(activeWep);
					GetLongMeleeWeaponName(meleeWepId, info, sizeof(info));
				}
				Format(info, sizeof(info), "[%s]", info);
			}
			else
			{
				// Default display -> [Primary details | Secondary prefix]
				// Having melee active is also included in this way
				// i.e. [Chrome 8/56 | M]
				if (GetSlotFromWeaponId(activeWepId) != 1 || activeWepId == WEPID_MELEE || activeWepId == view_as<WeaponId>(WEPID_CHAINSAW))
				{
					GetMeleePrefix(client, buffer, sizeof(buffer));
					Format(info, sizeof(info), "[%s | %s]", info, buffer);
				}

				// Secondary active -> [Secondary details | Primary]
				// i.e. [Deagle 8 | Mac 700]
				else
				{
					GetLongWeaponName(IdentifyWeapon(primaryWep), buffer, sizeof(buffer));
					Format(info, sizeof(info), "[%s | %s %i]", info, buffer, GetWeaponClip(primaryWep) + GetWeaponAmmo(client, primaryWep));
				}
			}
			
			if (IsSurvivorHanging(client))
			{
				FormatEx(info, sizeof(info), "%s: %iHP <Hanging>", name, GetSurvivorHealth(client));
			}
			else if (IsIncapacitated(client))
			{
				GetLongWeaponName(activeWepId, buffer, sizeof(buffer));
				FormatEx(info, sizeof(info), "%s: %iHP <#%i> [%s %i]", name, GetSurvivorHealth(client), (GetSurvivorIncapCount(client) + 1), buffer, GetWeaponClip(activeWep));
			}
			else
			{
				int health = GetSurvivorHealth(client) + GetSurvivorTemporaryHealth(client);
				int tempHealth = GetSurvivorTemporaryHealth(client);
				int incapCount = GetSurvivorIncapCount(client);
				if (incapCount == 0)
				{
					//FormatEx(buffer, sizeof(buffer), "#%iT", tempHealth);
					Format(info, sizeof(info), "%s: %iHP%s %s", name, health, (tempHealth > 0 ? "#" : ""), info);
				}
				else
				{
					//FormatEx(buffer, sizeof(buffer), "%i incap%s", incapCount, (incapCount > 1 ? "s" : ""));
					Format(info, sizeof(info), "%s: %iHP (#%i) %s", name, health, incapCount, info);
				}
			}
		}
		
		DrawPanelText(hSpecHud, info);
	}
	
	if (bHybridScoremod)
	{
		int healthBonus	= SMPlus_GetHealthBonus(),	maxHealthBonus = SMPlus_GetMaxHealthBonus();
		int damageBonus	= SMPlus_GetDamageBonus(),	maxDamageBonus = SMPlus_GetMaxDamageBonus();
		int pillsBonus	= SMPlus_GetPillsBonus(),	maxPillsBonus = SMPlus_GetMaxPillsBonus();
		
		int totalBonus		= healthBonus		+ damageBonus		+ pillsBonus;
		int maxTotalBonus	= maxHealthBonus	+ maxDamageBonus	+ maxPillsBonus;
		
		DrawPanelText(hSpecHud, " ");
		
		FormatEx(	info,
					sizeof(info),
					"> HB: %.0f%% | DB: %.0f%% | Pills: %i / %.0f%%",
					ToPercent(healthBonus, maxHealthBonus),
					ToPercent(damageBonus, maxDamageBonus),
					pillsBonus, ToPercent(pillsBonus, maxPillsBonus));
		DrawPanelText(hSpecHud, info);
		
		FormatEx(info, sizeof(info), "> Bonus: %i <%.1f%%>", totalBonus, ToPercent(totalBonus, maxTotalBonus));
		DrawPanelText(hSpecHud, info);
		
		FormatEx(info, sizeof(info), "> Dist: %i", L4D_GetVersusMaxCompletionScore());
		if (InSecondHalfOfRound())
		{
			Format(info, sizeof(info), "%s | R#1: %i <%.1f%%>", info, iFirstHalfScore, ToPercent(iFirstHalfScore, L4D_GetVersusMaxCompletionScore() + maxTotalBonus));
		}
		DrawPanelText(hSpecHud, info);
	}
	
	if (bScoremod)
	{
		int healthBonus = HealthBonus();
		
		DrawPanelText(hSpecHud, " ");
		
		FormatEx(info, sizeof(info), "> Health Bonus: %i", healthBonus);
		DrawPanelText(hSpecHud, info);
		
		FormatEx(info, sizeof(info), "> Dist: %i", L4D_GetVersusMaxCompletionScore());
		if (InSecondHalfOfRound())
		{
			Format(info, sizeof(info), "%s | R#1: %i", info, iFirstHalfScore);
		}
		DrawPanelText(hSpecHud, info);
	}
}

void FillInfectedInfo(Panel hSpecHud)
{
	static char info[512];
	static char buffer[32];
	static char name[MAX_NAME_LENGTH];

	int InfectedTeamIndex = L4D2_AreTeamsFlipped() ? 0 : 1;
	
	FormatEx(info, sizeof(info), "->2. Infected [%d]", L4D2Direct_GetVSCampaignScore(InfectedTeamIndex));
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, info);

	int infectedCount;
	for (int client = 1; client <= MaxClients && infectedCount < GetConVarInt(z_max_player_zombies); client++) 
	{
		if (!IsInfected(client))
			continue;

		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client)) 
		{
			CountdownTimer spawnTimer = L4D2Direct_GetSpawnTimer(client);
			float timeLeft = -1.0;
			if (spawnTimer != CTimer_Null)
			{
				timeLeft = CTimer_GetRemainingTime(spawnTimer);
			}

			if (timeLeft < 0.0)
			{
				FormatEx(info, sizeof(info), "%s: Dead", name);
			}
			else
			{
				FormatEx(buffer, sizeof(buffer), "%is", RoundToNearest(timeLeft));
				FormatEx(info, sizeof(info), "%s: Dead (%s)", name, (RoundToNearest(timeLeft) ? buffer : "Spawning..."));
				//if (storedClass[client] > ZC_None) {
				//	FormatEx(info, sizeof(info), "%s: Dead (%s) [%s]", name, ZOMBIECLASS_NAME(storedClass[client]), (RoundToNearest(timeLeft) ? buffer : "Spawning..."));
				//} else {
				//	FormatEx(info, sizeof(info), "%s: Dead (%s)", name, (RoundToNearest(timeLeft) ? buffer : "Spawning..."));
				//}
			}
		}
		else
		{
			L4D2SI zClass = GetInfectedClass(client);
			if (zClass == ZC_Tank)
				continue;
			
			int iHP = GetClientHealth(client), iMaxHP = GetEntProp(client, Prop_Send, "m_iMaxHealth");
			if (IsInfectedGhost(client))
			{
				// TODO: Handle a case of respawning chipped SI, show the ghost's health
				if (iHP < iMaxHP) FormatEx(buffer, sizeof(buffer), "(Ghost@%iHP)", iHP);
				
				FormatEx(info, sizeof(info), "%s: %s %s", name, ZOMBIECLASS_NAME(zClass), iHP < iMaxHP ? buffer : "(Ghost)");
			}
			else
			{
				int entAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
				float fCooldown;
				
				if (entAbility != -1)
				{
					fCooldown = GetEntPropFloat(entAbility, Prop_Send, "m_timestamp") - GetGameTime();
					FormatEx(buffer, sizeof(buffer), "[%.0fs]", fCooldown);
				}
				
				if (GetEntityFlags(client) & FL_ONFIRE)
				{
					FormatEx(info, sizeof(info), "%s: %s (%iHP) [On Fire]", name, ZOMBIECLASS_NAME(zClass), iHP);
					
					if (fCooldown > 0.0 && fCooldown < 99.9 && !HasAbilityVictim(client)) {
						Format(info, sizeof(info), "%s %s", info, buffer);
					}
				}
				else
				{
					FormatEx(info, sizeof(info), "%s: %s (%iHP)", name, ZOMBIECLASS_NAME(zClass), iHP, buffer);
					
					if (fCooldown > 0.0 && fCooldown < 99.9 && !HasAbilityVictim(client)) {
						Format(info, sizeof(info), "%s %s", info, buffer);
					}
				}
			}
		}

		infectedCount++;
		DrawPanelText(hSpecHud, info);
	}
	
	if (!infectedCount)
	{
		DrawPanelText(hSpecHud, "There are no SI at this moment.");
	}
}

bool FillTankInfo(Panel hSpecHud, bool bTankHUD = false)
{
	int tank = FindTank();
	if (tank == -1)
		return false;

	static char info[512];
	static char name[MAX_NAME_LENGTH];

	if (bTankHUD)
	{
		GetConVarString(FindConVar("l4d_ready_cfg_name"), info, sizeof(info));
		Format(info, sizeof(info), "%s :: Tank HUD", info);
		DrawPanelText(hSpecHud, info);
		
		int len = strlen(info);
		for (int i = 0; i < len; ++i)
		{
			info[i] = '_';
		}
		DrawPanelText(hSpecHud, info);
	}
	else
	{
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, "->3. Tank");
	}

	// Draw owner & pass counter
	int passCount = L4D2Direct_GetTankPassedCount();
	switch (passCount)
	{
		case 0: FormatEx(info, sizeof(info), "native");
		case 1: FormatEx(info, sizeof(info), "%ist", passCount);
		case 2: FormatEx(info, sizeof(info), "%ind", passCount);
		case 3: FormatEx(info, sizeof(info), "%ird", passCount);
		default: FormatEx(info, sizeof(info), "%ith", passCount);
	}

	if (!IsFakeClient(tank))
	{
		GetClientFixedName(tank, name, sizeof(name));
		Format(info, sizeof(info), "Control  : %s (%s)", name, info);
	}
	else
	{
		Format(info, sizeof(info), "Control  : AI (%s)", info);
	}
	DrawPanelText(hSpecHud, info);

	// Draw health
	int health = GetClientHealth(tank);
	int maxhealth = GetEntProp(tank, Prop_Send, "m_iMaxHealth");
	if (health <= 0 || IsIncapacitated(tank) || !IsPlayerAlive(tank))
	{
		info = "Health   : Dead";
	}
	else
	{
		int healthPercent = RoundFloat((100.0 / maxhealth) * health);
		FormatEx(info, sizeof(info), "Health   : %i / %i%%", health, ((healthPercent < 1) ? 1 : healthPercent));
	}
	DrawPanelText(hSpecHud, info);

	// Draw frustration
	if (!IsFakeClient(tank))
	{
		FormatEx(info, sizeof(info), "Frustr.   : %d%%", GetTankFrustration(tank));
	}
	else
	{
		info = "Frustr.   : AI";
	}
	DrawPanelText(hSpecHud, info);

	// Draw lerptime
	if (!IsFakeClient(tank))
	{
		FormatEx(info, sizeof(info), "Network : %ims / %.1f", RoundToNearest(GetClientAvgLatency(tank, NetFlow_Both) * 500.0), GetLerpTime(tank) * 1000.0);
	}
	else
	{
		info = "Network : AI";
	}
	DrawPanelText(hSpecHud, info);

	// Draw fire status
	if (GetEntityFlags(tank) & FL_ONFIRE)
	{
		int timeleft = RoundToCeil(health / (maxhealth / GetConVarFloat(FindConVar("tank_burn_duration"))));
		FormatEx(info, sizeof(info), "On Fire   : %is", timeleft);
		DrawPanelText(hSpecHud, info);
	}
	
	return true;
}

void FillGameInfo(Panel hSpecHud)
{
	// Turns out too much info actually CAN be bad, funny ikr
	int tank = FindTank();
	if (tank != -1)
		return;

	static char info[512];
	static char buffer[32];

	GetConVarString(FindConVar("l4d_ready_cfg_name"), info, sizeof(info));

	if (GetCurrentGameMode() == L4D2Gamemode_Scavenge)
	{
		Format(info, sizeof(info), "->3. %s", info);
		
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, info);

		int round = GetScavengeRoundNumber();
		switch (round)
		{
			case 0: Format(buffer, sizeof(buffer), "N/A");
			case 1: Format(buffer, sizeof(buffer), "%ist", round);
			case 2: Format(buffer, sizeof(buffer), "%ind", round);
			case 3: Format(buffer, sizeof(buffer), "%ird", round);
			default: Format(buffer, sizeof(buffer), "%ith", round);
		}

		FormatEx(info, sizeof(info), "Half: %s | Round: %s", (InSecondHalfOfRound() ? "2nd" : "1st"), buffer);
		DrawPanelText(hSpecHud, info);
	}
	else
	{
		Format(info, sizeof(info), "->3. %s (R#%d)", info, InSecondHalfOfRound() + 1);
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, info);

		int tankPercent = GetStoredTankPercent();
		int witchPercent = GetStoredWitchPercent();
		int survivorFlow = RoundToNearest(GetBossProximity() * 100.0);
		
		bool textBehind = false;
		
		// tank percent
		if (GetConVarBool(l4d_tank_percent))
		{
			if (iTankCount > 0)
			{
				textBehind = true;
				FormatEx(buffer, sizeof(buffer), "%i%%", tankPercent);
				FormatEx(info, sizeof(info), "Tank: %s", (((bFlowTankActive && RoundHasFlowTank()) || IsDarkCarniRemix()) ? buffer : (IsStaticTankMap() ? "Static" : "Event")));
			}
		}
		
		// witch percent
		if (GetConVarBool(l4d_witch_percent))
		{
			if (iWitchCount > 0)
			{
				FormatEx(buffer, sizeof(buffer), "%i%%", witchPercent);
				Format(buffer, sizeof(buffer), "Witch: %s", (RoundHasFlowWitch() ? buffer : (IsStaticWitchMap() ? "Static" : "Event")));
				
				if (textBehind) {
					Format(info, sizeof(info), "%s | %s", info, buffer);
				} else {
					textBehind = true;
					FormatEx(info, sizeof(info), "%s", buffer);
				}
			}
		}
		
		// progress percent
		if (textBehind) {
			Format(info, sizeof(info), "%s | Cur: %i%%", info, survivorFlow);
		} else {
			FormatEx(info, sizeof(info), "Cur: %i%%", survivorFlow);
		}
		
		DrawPanelText(hSpecHud, info);
		
		// tank selection
		if (GetConVarBool(l4d_tank_percent))
		{
			int tankClient = GetTankSelection();
			if (tankClient != -1 && iTankCount > 0)
			{
				GetClientFixedName(tankClient, buffer, sizeof(buffer));
				FormatEx(info, sizeof(info), "Tank -> %N", tankClient);
				DrawPanelText(hSpecHud, info);
			}
		}
	}
}

public Action SetMapFirstTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hFirstTankSpawningScheme, mapname, true);
}

public Action SetMapSecondTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hSecondTankSpawningScheme, mapname, true);
}

public Action SetFinaleExceptionMap(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hFinaleExceptionMaps, mapname, true);
}

/**
 *	Stocks
**/
int GetRealTeam(int team)
{
	return view_as<int>(view_as<bool>(team) ^ (InSecondHalfOfRound() != view_as<int>(L4D2_AreTeamsFlipped())));
}

bool HasAbilityVictim(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0
			|| GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0
			|| GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0
			|| GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0
			|| GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0;
}

#define OFFSET_IAMMO_PISTOLS	0
#define OFFSET_IAMMO_SMG		20
#define OFFSET_IAMMO_SHOTGUN	28
#define OFFSET_IAMMO_CSS_SNIPER	40
stock int GetWeaponAmmo(int client, int weapon)
{
	static int offset;
	switch (IdentifyWeapon(weapon))
	{
		case WEPID_PISTOL, WEPID_PISTOL_MAGNUM: offset = OFFSET_IAMMO_PISTOLS;
		case WEPID_SMG, WEPID_SMG_SILENCED: offset = OFFSET_IAMMO_SMG;
		case WEPID_PUMPSHOTGUN, WEPID_SHOTGUN_CHROME: offset = OFFSET_IAMMO_SHOTGUN;
		case WEPID_SNIPER_AWP, WEPID_SNIPER_SCOUT: offset = OFFSET_IAMMO_CSS_SNIPER;
		default: return -1;
	}
	return GetEntData(client, ammoOffset + offset);
} 

stock int GetWeaponClip(int weapon)
{
	return weapon == -1 ? -1 : GetEntProp(weapon, Prop_Send, "m_iClip1");
} 

void PushSerialSurvivors(ArrayList &array)
{
	array.Clear();
	
	int survivorCount;
	for (int client = 1; client <= MaxClients && survivorCount < GetConVarInt(survivor_limit); ++client) 
	{
		if (IsSurvivor(client)) array.Push(client);
	}
	array.SortCustom(ArraySort);
}

public int ArraySort(int index1, int index2, Handle array, Handle hndl)
{
	SurvivorCharacter sc1 = GetFixedSurvivorCharacter(GetArrayCell(array, index1));
	SurvivorCharacter sc2 = GetFixedSurvivorCharacter(GetArrayCell(array, index2));
	
	if (sc1 > sc2) {
		// goes after the second
		return 1;
	} else if (sc1 < sc2) {
		// goes before the second
		return -1;
	} else {
		// equal
		return 0;
	}
}

SurvivorCharacter GetFixedSurvivorCharacter(int client)
{
	int sc = GetEntProp(client, Prop_Send, "m_survivorCharacter");
	
	switch (sc)
	{
		case 6:						// Francis' netprop is 6
			return SC_FRANCIS;		// but here to match the official serial
			
		case 7:						// Louis' netprop is 7
			return SC_LOUIS;		// but here to match the official serial
			
		case 9, 11:					// Bill's alternative netprop
			return SC_BILL;			// match it correctly
	}
	return view_as<SurvivorCharacter>(sc);
}

float GetLerpTime(int client)
{
	ConVar cVarMinUpdateRate = FindConVar("sv_minupdaterate");
	ConVar cVarMaxUpdateRate = FindConVar("sv_maxupdaterate");
	ConVar cVarMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
	ConVar cVarMaxInterpRatio = FindConVar("sv_client_max_interp_ratio");

	static char buffer[64];
	
	if (!GetClientInfo(client, "cl_updaterate", buffer, sizeof(buffer))) buffer = "";
	int updateRate = StringToInt(buffer);
	updateRate = RoundFloat(CLAMP(float(updateRate), GetConVarFloat(cVarMinUpdateRate), GetConVarFloat(cVarMaxUpdateRate)));
	
	if (!GetClientInfo(client, "cl_interp_ratio", buffer, sizeof(buffer))) buffer = "";
	float flLerpRatio = StringToFloat(buffer);
	
	if (!GetClientInfo(client, "cl_interp", buffer, sizeof(buffer))) buffer = "";
	float flLerpAmount = StringToFloat(buffer);	
	
	if (cVarMinInterpRatio != null && cVarMaxInterpRatio != null && GetConVarFloat(cVarMinInterpRatio) != -1.0 ) {
		flLerpRatio = CLAMP(flLerpRatio, GetConVarFloat(cVarMinInterpRatio), GetConVarFloat(cVarMaxInterpRatio) );
	}
	
	return MAX(flLerpAmount, flLerpRatio / updateRate);
}

stock float ToPercent(int score, int maxbonus)
{
	return (score < 1 ? 0.0 : (100.0 * score / maxbonus));
}

void GetClientFixedName(int client, char[] name, int length)
{
	GetClientName(client, name, length);

	if (name[0] == '[')
	{
		static char temp[MAX_NAME_LENGTH];
		strcopy(temp, sizeof(temp), name);
		temp[sizeof(temp)-2] = 0;
		strcopy(name[1], length-1, temp);
		name[0] = ' ';
	}

	if (strlen(name) > 18)
	{
		name[15] = name[16] = name[17] = '.';
		name[18] = 0;
	}
}

int GetRealClientCount() 
{
	int clients = 0;
	for (int i = 1; i <= MaxClients; ++i) 
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i)) clients++;
	}
	return clients;
}

int InSecondHalfOfRound()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

int GetScavengeRoundNumber()
{
	return GameRules_GetProp("m_nRoundNumber");
}

float GetBossProximity()
{
	float proximity = GetHighestSurvivorFlow() + (GetConVarFloat(FindConVar("versus_boss_buffer")) / L4D2Direct_GetMapMaxFlowDistance());
	return MIN(proximity, 1.0);
}

float GetClientFlow(int client)
{
	return (L4D2Direct_GetFlowDistance(client) / L4D2Direct_GetMapMaxFlowDistance());
}

float GetHighestSurvivorFlow()
{
	float flow;
	for (int i = 1; i <= MaxClients; ++i) 
	{
		if (IsSurvivor(i))
		{
			flow = MAX(flow, GetClientFlow(i));
		}
	}
	return flow;
}

bool RoundHasFlowTank()
{
	return L4D2Direct_GetVSTankToSpawnThisRound(InSecondHalfOfRound());
}

bool RoundHasFlowWitch()
{
	return L4D2Direct_GetVSWitchToSpawnThisRound(InSecondHalfOfRound());
}

bool IsSpectator(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 1;
}

bool IsSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool IsInfected(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 3;
}

bool IsInfectedGhost(int client) 
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
}

L4D2SI GetInfectedClass(int client)
{
	return view_as<L4D2SI>(GetEntProp(client, Prop_Send, "m_zombieClass"));
}

int FindTank() 
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsInfected(i) && GetInfectedClass(i) == ZC_Tank && IsPlayerAlive(i))
			return i;
	}

	return -1;
}

int GetTankFrustration(int tank)
{
	return (100 - GetEntProp(tank, Prop_Send, "m_frustration"));
}

bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

bool IsSurvivorHanging(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

int GetSurvivorIncapCount(int client)
{
	return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

int GetSurvivorTemporaryHealth(int client)
{
	int temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}

int GetSurvivorHealth(int client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

L4D2Gamemode GetCurrentGameMode()
{
	static char sGameMode[32];
	if (sGameMode[0] == EOS)
	{
		GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	}
	if (StrContains(sGameMode, "scavenge") > -1)
	{
		return L4D2Gamemode_Scavenge;
	}
	if (StrContains(sGameMode, "versus") > -1
		|| StrEqual(sGameMode, "mutation12")) // realism versus
	{
		return L4D2Gamemode_Versus;
	}
	else
	{
		return L4D2Gamemode_None; // Unsupported
	}
}
