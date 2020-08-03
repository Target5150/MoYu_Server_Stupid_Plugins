#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
#include <l4d2_weapon_stocks>
//#include <readyup>
//#include <pause>
#include <colors>
//#include <l4d2_scoremod>

#define SPECHUD_DRAW_INTERVAL   0.5

#define HYBRID_SCOREMOD_COMPILE	1
#define SCOREMOD_COMPILE		0

#define ZOMBIECLASS_NAME(%0) (L4D2SI_Names[(%0)])

#define CLAMP(%0,%1,%2) (((%0) > (%2)) ? (%2) : (((%0) < (%1)) ? (%1) : (%0)))
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))

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

static const String:L4D2SI_Names[][] = 
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


new Handle:survivor_limit;
new Handle:z_max_player_zombies;
new Handle:l4d_tank_percent;
new Handle:l4d_witch_percent;

new bool:bSpecHudActive[MAXPLAYERS + 1];
new bool:bSpecHudHintShown[MAXPLAYERS + 1];
new bool:bTankHudActive[MAXPLAYERS + 1];
new bool:bTankHudHintShown[MAXPLAYERS + 1];

//new bool:hybridScoringAvailable;

enum survivorSerial
{
	Nick,
	Rochelle,
	Coach,
	Ellis,
	Bill,
	Zoey,
	Louis,
	Francis
}
new Handle:hSurvivorArray;
new bool:bShouldRefresh;

new bool:bIsLive;

new iTankCount;
new Handle:hDoubleTankMapTrie;

new ammoOffset;

// readyup
native IsInReady();

// pause
native IsInPause();

#if HYBRID_SCOREMOD_COMPILE
// l4d2_hybrid_scoremod
native SMPlus_GetHealthBonus();
native SMPlus_GetDamageBonus();
native SMPlus_GetPillsBonus();
native SMPlus_GetMaxHealthBonus();
native SMPlus_GetMaxDamageBonus();
native SMPlus_GetMaxPillsBonus();
#endif

#if SCOREMOD_COMPILE
// l4d2_scoremod
native HealthBonus();
#endif

// l4d_tank_control_eq
native GetTankSelection();

// l4d2_boss_percent (Credit to spoon)
native IsStaticTankMap();
native IsStaticWitchMap();
native GetStoredTankPercent();
native GetStoredWitchPercent();


public Plugin:myinfo = 
{
	name = "Hyper-V HUD Manager [Public Version]",
	author = "Visor, Forgetest",
	description = "Provides different HUDs for spectators",
	version = "3.0.0",
	url = "https://github.com/Attano/smplugins"
};

public OnPluginStart() 
{
	survivor_limit = FindConVar("survivor_limit");
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	
	l4d_tank_percent = FindConVar("l4d_tank_percent");
	l4d_witch_percent = FindConVar("l4d_witch_percent");
	
	RegConsoleCmd("sm_spechud", ToggleSpecHudCmd);
	RegConsoleCmd("sm_tankhud", ToggleTankHudCmd);

	for (new i = 1; i < MaxClients; ++i)
	{
		bSpecHudActive[i] = false;
		bSpecHudHintShown[i] = false;
		bTankHudActive[i] = true;
		bTankHudHintShown[i] = false;
	}
	
	ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
	
	hSurvivorArray = CreateArray();
	
	RegServerCmd("tank_map_flow_and_second_event", SetMapFirstTankSpawningScheme);
	hDoubleTankMapTrie = CreateTrie();
	
	HookEvent("round_end", EventHook:OnRoundEnd);
	HookEvent("player_team", OnPlayerTeam);
	HookEvent("tank_killed", OnTankDeath);
	
	CreateTimer(SPECHUD_DRAW_INTERVAL, HudDrawTimer, _, TIMER_REPEAT);
}
/*
public OnAllPluginsLoaded()
{
	hybridScoringAvailable = (LibraryExists("l4d2_hybrid_scoremod") || LibraryExists("l4d2_hybrid_scoremod_zone"));
}

public OnLibraryRemoved(const String:name[])
{
	if (StrContains(name, "l4d2_hybrid_scoremod", true) != -1)
	{
		hybridScoringAvailable = false;
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrContains(name, "l4d2_hybrid_scoremod", true) != -1)
	{
		hybridScoringAvailable = true;
	}
}*/

public OnClientDisconnect(client)
{
	bSpecHudHintShown[client] = false;
	bTankHudHintShown[client] = false;
	CreateTimer(5.0, Timer_CheckDisconnect, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_CheckDisconnect(Handle:timer, any:client)
{
	if (client <= 0 || client > MaxClients)
	{
		return Plugin_Handled;
	}
	
	if (!IsClientConnected(client))
	{
		bSpecHudActive[client] = false;
		bTankHudActive[client] = true;
	}
	
	return Plugin_Handled;
}

public OnMapStart() { bIsLive = false; }
public OnRoundEnd() { bIsLive = false; }
public OnRoundIsLive()
{
	bIsLive = true;
	
	decl String:mapname[64], dummy;
	GetCurrentMap(mapname, sizeof(mapname));
	iTankCount = 1 + _:GetTrieValue(hDoubleTankMapTrie, mapname, dummy);
}

public Action:SetMapFirstTankSpawningScheme(args)
{
	decl String:mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hDoubleTankMapTrie, mapname, true);
}

public OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		new team = GetEventInt(event, "team"), oldteam = GetEventInt(event, "oldteam");
		if (team == 2 || oldteam == 2)
		{
			bShouldRefresh = true;
		}
	}
}

public OnTankDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (iTankCount > 0) iTankCount--;
}

public Action:ToggleSpecHudCmd(client, args) 
{
	bSpecHudActive[client] = !bSpecHudActive[client];
	CPrintToChat(client, "<{olive}HUD{default}> Spectator HUD is now %s.", (bSpecHudActive[client] ? "{blue}on{default}" : "{red}off{default}"));
}

public Action:ToggleTankHudCmd(client, args) 
{
	bTankHudActive[client] = !bTankHudActive[client];
	CPrintToChat(client, "<{olive}HUD{default}> Tank HUD is now %s.", (bTankHudActive[client] ? "{blue}on{default}" : "{red}off{default}"));
}

public Action:HudDrawTimer(Handle:hTimer) 
{
	if (IsInReady() || IsInPause())
		return Plugin_Handled;

	new bool:bSpecsOnServer = false;
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (IsSpectator(i) && bSpecHudActive[i])
		{
			bSpecsOnServer = true;
			break;
		}
	}

	if (bSpecsOnServer) // Only bother if someone's watching us
	{
		new Handle:specHud = CreatePanel();

		FillHeaderInfo(specHud);
		FillSurvivorInfo(specHud);
		FillInfectedInfo(specHud);
		FillTankInfo(specHud);
		FillGameInfo(specHud);

		for (new i = 1; i <= MaxClients; ++i)
		{
			if (!bSpecHudActive[i] || !IsSpectator(i) || IsFakeClient(i))
				continue;

			SendPanelToClient(specHud, i, DummySpecHudHandler, 3);
			if (!bSpecHudHintShown[i])
			{
				bSpecHudHintShown[i] = true;
				CPrintToChat(i, "<{olive}HUD{default}> Type {green}!spechud{default} into chat to toggle the {blue}Spectator HUD{default}.");
			}
		}

		CloseHandle(specHud);
	}
	
	new Handle:tankHud = CreatePanel();
	if (!FillTankInfo(tankHud, true)) // No tank -- no HUD
		return Plugin_Handled;

	for (new i = 1; i <= MaxClients; ++i)
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

	CloseHandle(tankHud);
	return Plugin_Continue;
}

public DummySpecHudHandler(Handle:hMenu, MenuAction:action, param1, param2) {}
public DummyTankHudHandler(Handle:hMenu, MenuAction:action, param1, param2) {}

FillHeaderInfo(Handle:hSpecHud)
{
	new Handle:ServerNamer = FindConVar("sn_main_name");
	
	decl String:buffer[64];
	if (ServerNamer != INVALID_HANDLE) GetConVarString(ServerNamer, buffer, sizeof(buffer));
	else GetConVarString(FindConVar("hostname"), buffer, sizeof(buffer));
	
	Format(buffer, sizeof(buffer), "☂ %s [Slots %i/%i | %iT]", buffer, GetRealClientCount(), GetConVarInt(FindConVar("sv_maxplayers")), RoundToNearest(1.0 / GetTickInterval()));
	DrawPanelText(hSpecHud, buffer);
	
	//FormatEx(buffer, sizeof(buffer), "Slots %i/%i | Tickrate %i", GetRealClientCount(), GetConVarInt(FindConVar("sv_maxplayers")), RoundToNearest(1.0 / GetTickInterval()));
}

GetMeleePrefix(client, String:prefix[], length)
{
	new secondary = GetPlayerWeaponSlot(client, _:L4D2WeaponSlot_Secondary);
	new WeaponId:secondaryWep = IdentifyWeapon(secondary);

	decl String:buf[4];
	switch (secondaryWep)
	{
		case WEPID_NONE: buf = "N";
		case WEPID_PISTOL: buf = (GetEntProp(secondary, Prop_Send, "m_isDualWielding") ? "DP" : "P");
		case WEPID_MELEE: buf = "M";
		case WEPID_PISTOL_MAGNUM: buf = "DE";
		default: buf = "?";
	}

	strcopy(prefix, length, buf);
}

FillSurvivorInfo(Handle:hSpecHud) 
{
	decl String:info[512];
	decl String:buffer[64];
	decl String:name[MAX_NAME_LENGTH];

	new SurvivorTeamIndex = GameRules_GetProp("m_bAreTeamsFlipped") ? 1 : 0;
	
	new distance = 0;
	for (new i = 0; i < 4; ++i)
		distance += GameRules_GetProp("m_iVersusDistancePerSurvivor", _, i + 4 * SurvivorTeamIndex);
	
	FormatEx(info, sizeof(info), "->1. Survivors [%d]",
				L4D2Direct_GetVSCampaignScore(SurvivorTeamIndex) + (bIsLive ? distance : 0));
				
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, info);
	
	if (bShouldRefresh)
	{
		bShouldRefresh = false;
		ClearArray(hSurvivorArray);
		PushSerialSurvivors(hSurvivorArray);
	}
	
	for (new i = 0; i < GetArraySize(hSurvivorArray); ++i)
	{
		new client = GetArrayCell(hSurvivorArray, i);
		
		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client))
		{
			FormatEx(info, sizeof(info), "%s: Dead", name);
		}
		else
		{
			new primaryWep = GetPlayerWeaponSlot(client, _:L4D2WeaponSlot_Primary);
			
			new activeWep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			new WeaponId:activeWepId = IdentifyWeapon(activeWep);

			switch (activeWepId)
			{
				case WEPID_PISTOL, WEPID_PISTOL_MAGNUM:
				{
					if (activeWepId == WEPID_PISTOL && bool:GetEntProp(activeWep, Prop_Send, "m_isDualWielding"))
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
				if (activeWepId == WEPID_MELEE || activeWepId == WeaponId:WEPID_CHAINSAW)
				{
					new MeleeWeaponId:meleeWepId = IdentifyMeleeWeapon(activeWep);
					GetLongWeaponName(meleeWepId, info, sizeof(info));
				}
				Format(info, sizeof(info), "[%s]", info);
			}
			else
			{
				// Default display -> [Primary details | Secondary prefix]
				// Having melee active is also included in this way
				// i.e. [Chrome 8/56 | M]
				if (GetSlotFromWeaponId(activeWepId) != 1 || activeWepId == WEPID_MELEE || activeWepId == WeaponId:WEPID_CHAINSAW)
				{
					GetMeleePrefix(client, buffer, sizeof(buffer));
					Format(info, sizeof(info), "[%s | %s]", info, buffer);
				}

				// Having secondary active -> [Secondary details | Primary weapon name]
				// i.e. [Deagle 8 | Mac]
				else
				{
					GetLongWeaponName(IdentifyWeapon(primaryWep), buffer, sizeof(buffer));
					Format(info, sizeof(info), "[%s | %s]", info, buffer);
				}
			}
			
			if (IsSurvivorHanging(client))
			{
				FormatEx(info, sizeof(info), "%s: %iHP <Hanging>", name, GetSurvivorHealth(client));
			}
			else if (IsIncapacitated(client))
			{
				GetLongWeaponName(activeWepId, buffer, sizeof(buffer));
				FormatEx(info, sizeof(info), "%s: %iHP <Incapped#%i> [%s %i]", name, GetSurvivorHealth(client), (GetSurvivorIncapCount(client) + 1), buffer, GetWeaponClip(activeWep));
			}
			else
			{
				new health = GetSurvivorHealth(client) + GetSurvivorTemporaryHealth(client);
				new tempHealth = GetSurvivorTemporaryHealth(client);
				new incapCount = GetSurvivorIncapCount(client);
				if (incapCount == 0)
				{
					FormatEx(buffer, sizeof(buffer), "#%iT", tempHealth);
					Format(info, sizeof(info), "%s: %iHP%s %s", name, health, (tempHealth ? buffer : ""), info);
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
	
#if HYBRID_SCOREMOD_COMPILE
	// l4d2_hybrid_scoremod
	new healthBonus = SMPlus_GetHealthBonus();
	new damageBonus = SMPlus_GetDamageBonus();
	new pillsBonus = SMPlus_GetPillsBonus();
	new totalBonus = healthBonus + damageBonus + pillsBonus;
	new maxTotalBonus = SMPlus_GetMaxHealthBonus() + SMPlus_GetMaxDamageBonus() + SMPlus_GetMaxPillsBonus();
	
	DrawPanelText(hSpecHud, " ");
	FormatEx(info, sizeof(info), " HB: %i <%.1f%%>", healthBonus, ToPercent(healthBonus, SMPlus_GetMaxHealthBonus()));
	DrawPanelText(hSpecHud, info);
	FormatEx(info, sizeof(info), " DB: %i <%.1f%%>", damageBonus, ToPercent(damageBonus, SMPlus_GetMaxDamageBonus()));
	DrawPanelText(hSpecHud, info);
	FormatEx(info, sizeof(info), " Pills: %i <%.1f%%>", pillsBonus, ToPercent(pillsBonus, SMPlus_GetMaxPillsBonus()));
	DrawPanelText(hSpecHud, info);
	FormatEx(info, sizeof(info), " Total: %i <%.1f%%>", totalBonus, ToPercent(totalBonus, maxTotalBonus));
	DrawPanelText(hSpecHud, info);
#endif
	
#if SCOREMOD_COMPILE
	// l4d2_scoremod
	new healthBonus = HealthBonus();
	
	DrawPanelText(hSpecHud, " ");
	FormatEx(info, sizeof(info), " Health Bonus: %i", healthBonus);
	DrawPanelText(hSpecHud, info);
#endif
}

FillInfectedInfo(Handle:hSpecHud)
{
	decl String:info[512];
	decl String:buffer[32];
	decl String:name[MAX_NAME_LENGTH];

	new InfectedTeamIndex = GameRules_GetProp("m_bAreTeamsFlipped") ? 0 : 1;
	
	FormatEx(info, sizeof(info), "->2. Infected [%d]", L4D2Direct_GetVSCampaignScore(InfectedTeamIndex));
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, info);

	new infectedCount;
	for (new client = 1; client <= MaxClients && infectedCount < GetConVarInt(z_max_player_zombies); client++) 
	{
		if (!IsInfected(client))
			continue;

		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client)) 
		{
			new CountdownTimer:spawnTimer = L4D2Direct_GetSpawnTimer(client);
			new Float:timeLeft = -1.0;
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
			}
		}
		else 
		{
			new L4D2SI:zClass = GetInfectedClass(client);
			if (zClass == ZC_Tank)
				continue;
			
			new iHP = GetClientHealth(client), iMaxHP = GetEntProp(client, Prop_Send, "m_iMaxHealth");
			if (IsInfectedGhost(client))
			{
				FormatEx(info, sizeof(info), "%s: %s (Ghost)", name, ZOMBIECLASS_NAME(zClass));
				
				// TODO: Handle a case of respawning chipped SI, show the ghost's health
				if (iHP < iMaxHP) Format(info, sizeof(info), "%s (%iHP)", info, iHP);
			}
			else
			{
				new entAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
				if (entAbility != -1)
				{
					new Float:fCooldown = GetEntPropFloat(entAbility, Prop_Send, "m_timestamp") - GetGameTime();
					new Float:fCooldownDuration = GetEntPropFloat(entAbility, Prop_Send, "m_duration");
					
					if (fCooldown > 0.0					/* Ability is in Cooldown */
						&& fCooldownDuration > 1.0		/* Cooldown is long enough to get shown */
						&& fCooldownDuration < 30.0)	/* Cooldown duration is in reasonable range */
					{
						if (zClass == ZC_Smoker
							&& GetEntPropEnt(client, Prop_Send, "m_tongueVictim"))
							/* Weird exception where Smoker has CD shown while pulling/choking a survivor */
							buffer = "";
						else
							FormatEx(buffer, sizeof(buffer), " [%is]", RoundToNearest(fCooldown));
					}
					else buffer = "";
				}
				
				if (GetEntityFlags(client) & FL_ONFIRE)
				{
					FormatEx(info, sizeof(info), "%s: %s (%iHP) [On Fire]%s", name, ZOMBIECLASS_NAME(zClass), iHP, buffer);
				}
				else
				{
					FormatEx(info, sizeof(info), "%s: %s (%iHP)%s", name, ZOMBIECLASS_NAME(zClass), iHP, buffer);
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

bool:FillTankInfo(Handle:hSpecHud, bool:bTankHUD = false)
{
	new tank = FindTank();
	if (tank == -1)
		return false;

	decl String:info[512];
	decl String:name[MAX_NAME_LENGTH];

	if (bTankHUD)
	{
		GetConVarString(FindConVar("l4d_ready_cfg_name"), info, sizeof(info));
		Format(info, sizeof(info), "%s :: Tank HUD", info);
		DrawPanelText(hSpecHud, info);
		
		new len = strlen(info);
		for (new i = 0; i < len; ++i)
		{
			if (i == 0) info = "_";
			else StrCat(info, sizeof(info), "_");
		}
		DrawPanelText(hSpecHud, info);
	}
	else
	{
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, "->3. Tank");
	}

	// Draw owner & pass counter
	new passCount = L4D2Direct_GetTankPassedCount();
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
		Format(info, sizeof(info), "Control   : %s (%s)", name, info);
	}
	else
	{
		Format(info, sizeof(info), "Control   : AI (%s)", info);
	}
	DrawPanelText(hSpecHud, info);

	// Draw health
	new health = GetClientHealth(tank);
	new maxhealth = GetEntProp(tank, Prop_Send, "m_iMaxHealth");
	if (health <= 0 || IsIncapacitated(tank) || !IsPlayerAlive(tank))
	{
		info = "Health    : Dead";
	}
	else
	{
		new healthPercent = RoundFloat((100.0 / maxhealth) * health);
		FormatEx(info, sizeof(info), "Health    : %i / %i%%", health, ((healthPercent < 1) ? 1 : healthPercent));
	}
	DrawPanelText(hSpecHud, info);

	// Draw frustration
	if (!IsFakeClient(tank))
	{
		FormatEx(info, sizeof(info), "Frustr.    : %d%%", GetTankFrustration(tank));
	}
	else
	{
		info = "Frustr.    : AI";
	}
	DrawPanelText(hSpecHud, info);

	// Draw lerptime
	if (!IsFakeClient(tank))
	{
		FormatEx(info, sizeof(info), "Ping|Lerp: %ims | %.1f", RoundToNearest(GetClientAvgLatency(tank, NetFlow_Both) * 500.0), GetLerpTime(tank) * 1000.0);
	}
	else
	{
		info = "Ping|Lerp: AI";
	}
	DrawPanelText(hSpecHud, info);

	// Draw fire status
	if (GetEntityFlags(tank) & FL_ONFIRE)
	{
		new timeleft = RoundToCeil(health / (maxhealth / GetConVarFloat(FindConVar("tank_burn_duration"))));
		FormatEx(info, sizeof(info), "On Fire   : %is", timeleft);
		DrawPanelText(hSpecHud, info);
	}
	
	return true;
}

FillGameInfo(Handle:hSpecHud)
{
	// Turns out too much info actually CAN be bad, funny ikr
	new tank = FindTank();
	if (tank != -1)
		return;

	decl String:info[512];
	decl String:buffer[32];

	GetConVarString(FindConVar("l4d_ready_cfg_name"), info, sizeof(info));

	if (GetCurrentGameMode() == L4D2Gamemode_Scavenge)
	{
		Format(info, sizeof(info), "->3. %s", info);
		
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, info);

		new round = GetScavengeRoundNumber();
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

/*
		Format(info, sizeof(info), "Natural horde: %is", CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer()) ? RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : 0);
		DrawPanelText(hSpecHud, info);

		Format(info, sizeof(info), "Survivor progress: %i%%", RoundToNearest(GetHighestSurvivorFlow() * 100.0));
		DrawPanelText(hSpecHud, info);
*/

		new tankPercent = GetStoredTankPercent();
		new witchPercent = GetStoredWitchPercent();
		new survivorFlow = RoundToNearest(GetBossProximity() * 100.0);
		
		new textBehind = false;
		if (l4d_tank_percent == INVALID_HANDLE || GetConVarBool(l4d_tank_percent))
		{
			if ((tankPercent || IsStaticTankMap()) && iTankCount)
			{
				textBehind = true;
				FormatEx(buffer, sizeof(buffer), "%i%%", tankPercent);
				FormatEx(info, sizeof(info), "Tank: %s", (tankPercent ? buffer : (IsStaticTankMap() ? "Static" : "None")));
			}
		}
		if (l4d_witch_percent == INVALID_HANDLE || GetConVarBool(l4d_witch_percent))
		{
			if (RoundHasFlowWitch() || IsStaticWitchMap())
			{			
				FormatEx(buffer, sizeof(buffer), "%i%%", witchPercent);
				
				if (textBehind) Format(info, sizeof(info), "%s | Witch: %s", info, (witchPercent ? buffer : (IsStaticWitchMap() ? "Static" : "None")));
				else
				{
					textBehind = true;
					FormatEx(info, sizeof(info), "Witch: %s", (witchPercent ? buffer : (IsStaticWitchMap() ? "Static" : "None")));
				}
			}
		}
		if (textBehind) Format(info, sizeof(info), "%s | Cur: %i%%", info, survivorFlow);
		else FormatEx(info, sizeof(info), "Cur: %i%%", survivorFlow);
		
		DrawPanelText(hSpecHud, info);
		
		if (GetConVarBool(l4d_tank_percent))
		{
			new tankClient = GetTankSelection();
			if (tankClient != -1 && iTankCount > 0 && (tankPercent || IsStaticTankMap()))
			{
				GetClientFixedName(tankClient, buffer, sizeof(buffer));
				FormatEx(info, sizeof(info), "Tank -> %N", tankClient);
				DrawPanelText(hSpecHud, info);
			}
		}
	}
}

/**
 *	Stocks
**/

#define OFFSET_IAMMO_PISTOLS	0
#define OFFSET_IAMMO_SMG		20
#define OFFSET_IAMMO_SHOTGUN	28
#define OFFSET_IAMMO_CSS_SNIPER	40
stock GetWeaponAmmo(client, weapon)
{
	new offset;
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

stock GetWeaponClip(weapon)
{
	return weapon == -1 ? -1 : GetEntProp(weapon, Prop_Send, "m_iClip1");
} 

PushSerialSurvivors(&Handle:hArray)
{
	new survivorCount;
	for (new client = 1; client <= MaxClients && survivorCount < GetConVarInt(survivor_limit); ++client) 
	{
		if (IsSurvivor(client))
		{
			survivorCount++;
			
			new index = PushArrayCell(hArray, client), netprop = GetCharacterNetprop(client);
			
			for (new i = GetArraySize(hArray) - 1; i >= 0; --i)
			{
				if (netprop < GetCharacterNetprop(GetArrayCell(hArray, i)))
				{
					SwapArrayItems(hArray, index, i);
					index = i;
				}
			}
		}
	}
}

GetCharacterNetprop(client)
{
	new netprop = GetEntProp(client, Prop_Send, "m_survivorCharacter");
	
	switch (netprop)
	{
		case 6:					// Francis' netprop is 6
			return _:Francis;	// but here to match the official serial
			
		case 7:					// Louis' netprop is 7
			return _:Louis;		// but here to match the official serial
			
		case 9, 11:				// Bill's alternative netprop
			return _:Bill;		// match it correctly
	}
	return netprop;
}

/*
stock GetFakePing(client, bool:goldSource=true)
{
	if (IsFakeClient(client)) {
		return 0;
	}

	new ping;
	new Float:latency = GetClientLatency(client, NetFlow_Outgoing); // in seconds

	// that should be the correct latency, we assume that cmdrate is higher
	// then updaterate, what is the case for default settings
	decl String:cl_cmdrate[4];
	GetClientInfo(client, "cl_cmdrate", cl_cmdrate, sizeof(cl_cmdrate));

	new Float:tickRate = GetTickInterval();
	latency -= (0.5 / StringToInt(cl_cmdrate)) + GetTickInterval() * 1.0; // correct latency

	if (goldSource) {
		// in GoldSrc we had a different, not fixed tickrate. so we have to adjust
		// Source pings by half a tick to match the old GoldSrc pings.
		latency -= tickRate * 0.5;
	}

	ping = RoundFloat(latency * 1000.0); // as msecs
	ping = CLAMP(ping, 5, 1000); // set bounds, dont show pings under 5 msecs

	return ping;
}*/

Float:GetLerpTime(client)
{
	new Handle:cVarMinUpdateRate = FindConVar("sv_minupdaterate");
	new Handle:cVarMaxUpdateRate = FindConVar("sv_maxupdaterate");
	new Handle:cVarMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
	new Handle:cVarMaxInterpRatio = FindConVar("sv_client_max_interp_ratio");

	decl String:buffer[64];
	
	if (!GetClientInfo(client, "cl_updaterate", buffer, sizeof(buffer))) buffer = "";
	new updateRate = StringToInt(buffer);
	updateRate = RoundFloat(CLAMP(float(updateRate), GetConVarFloat(cVarMinUpdateRate), GetConVarFloat(cVarMaxUpdateRate)));
	
	if (!GetClientInfo(client, "cl_interp_ratio", buffer, sizeof(buffer))) buffer = "";
	new Float:flLerpRatio = StringToFloat(buffer);
	
	if (!GetClientInfo(client, "cl_interp", buffer, sizeof(buffer))) buffer = "";
	new Float:flLerpAmount = StringToFloat(buffer);	
	
	if (cVarMinInterpRatio != INVALID_HANDLE && cVarMaxInterpRatio != INVALID_HANDLE && GetConVarFloat(cVarMinInterpRatio) != -1.0 ) {
		flLerpRatio = CLAMP(flLerpRatio, GetConVarFloat(cVarMinInterpRatio), GetConVarFloat(cVarMaxInterpRatio) );
	}
	
	return MAX(flLerpAmount, flLerpRatio / updateRate);
}

stock Float:ToPercent(score, maxbonus)
{
	return (score < 1 ? 0.0 : (100.0 * score / maxbonus));
}

GetClientFixedName(client, String:name[], length)
{
	GetClientName(client, name, length);

	if (name[0] == '[')
	{
		decl String:temp[MAX_NAME_LENGTH];
		strcopy(temp, sizeof(temp), name);
		temp[sizeof(temp)-2] = 0;
		strcopy(name[1], length-1, temp);
		name[0] = ' ';
	}

	if (strlen(name) > 21)
	{
		name[18] = name[19] = name[20] = '.';
		name[21] = 0;
	}
}

GetRealClientCount() 
{
	new clients = 0;
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i)) clients++;
	}
	return clients;
}

InSecondHalfOfRound()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

GetScavengeRoundNumber()
{
	return GameRules_GetProp("m_nRoundNumber");
}

Float:GetBossProximity()
{
	new Float:proximity = GetHighestSurvivorFlow() + (GetConVarFloat(FindConVar("versus_boss_buffer")) / L4D2Direct_GetMapMaxFlowDistance());
	return MIN(proximity, 1.0);
}

Float:GetClientFlow(client)
{
	return (L4D2Direct_GetFlowDistance(client) / L4D2Direct_GetMapMaxFlowDistance());
}

Float:GetHighestSurvivorFlow()
{
	new Float:flow;
	new Float:maxflow = 0.0;
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsSurvivor(i))
		{
			flow = GetClientFlow(i);
			if (flow > maxflow)
			{
				maxflow = flow;
			}
		}
	}
	return maxflow;
}

bool:RoundHasFlowTank()
{
	return L4D2Direct_GetVSTankToSpawnThisRound(_:InSecondHalfOfRound());
}

bool:RoundHasFlowWitch()
{
	return L4D2Direct_GetVSWitchToSpawnThisRound(_:InSecondHalfOfRound());
}
/*
Float:GetTankFlow() 
{
	return L4D2Direct_GetVSTankFlowPercent(0) -
		(Float:GetConVarInt(FindConVar("versus_boss_buffer")) / L4D2Direct_GetMapMaxFlowDistance());
}

Float:GetWitchFlow() 
{
	return L4D2Direct_GetVSWitchFlowPercent(0) -
		(Float:GetConVarInt(FindConVar("versus_boss_buffer")) / L4D2Direct_GetMapMaxFlowDistance());
}*/

bool:IsSpectator(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 1;
}

bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool:IsInfected(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

bool:IsInfectedGhost(client) 
{
	return bool:GetEntProp(client, Prop_Send, "m_isGhost");
}

L4D2SI:GetInfectedClass(client)
{
	return IsInfected(client) ? (L4D2SI:GetEntProp(client, Prop_Send, "m_zombieClass")) : ZC_None;
}

FindTank() 
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsInfected(i) && GetInfectedClass(i) == ZC_Tank && IsPlayerAlive(i))
			return i;
	}

	return -1;
}

GetTankFrustration(tank)
{
	return (100 - GetEntProp(tank, Prop_Send, "m_frustration"));
}

bool:IsIncapacitated(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool:IsSurvivorHanging(client)
{
	return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

GetSurvivorIncapCount(client)
{
	return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

GetSurvivorTemporaryHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}

GetSurvivorHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

L4D2Gamemode:GetCurrentGameMode()
{
	static String:sGameMode[32];
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
