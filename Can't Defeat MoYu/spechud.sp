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

new bool:hybridScoringAvailable;

native bool:IsInReady();
native bool:IsInPause();
native SMPlus_GetHealthBonus();
native SMPlus_GetDamageBonus();
native SMPlus_GetPillsBonus();
native SMPlus_GetMaxHealthBonus();
native SMPlus_GetMaxDamageBonus();
native SMPlus_GetMaxPillsBonus();
native GetTankSelection();

native bool:IsStaticTankMap();
native bool:IsStaticWitchMap();
native GetStoredTankPercent();
native GetStoredWitchPercent();

enum SurvivorSeq
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

public Plugin:myinfo = 
{
	name = "Hyper-V HUD Manager [Public Version]",
	author = "Visor",
	description = "Provides different HUDs for spectators",
	version = "2.9",
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
	
	for (new i = 1; i < MaxClients; i++)
	{
		bSpecHudActive[i] = false;
		bSpecHudHintShown[i] = false;
		bTankHudActive[i] = true;
		bTankHudHintShown[i] = false;
	}
	
	hSurvivorArray = CreateArray();
	
	CreateTimer(SPECHUD_DRAW_INTERVAL, HudDrawTimer, _, TIMER_REPEAT);
}

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
}

public OnClientDisconnect(client)
{
	bSpecHudHintShown[client] = false;
	bTankHudHintShown[client] = false;
	CreateTimer(5.0, Timer_CheckDisconnect, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_CheckDisconnect(Handle:timer, any:client)
{
	if (client < 0 || client > MaxClients)
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
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsSpectator(i))
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

		for (new i = 1; i <= MaxClients; i++) 
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

	for (new i = 1; i <= MaxClients; i++) 
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
	DrawPanelText(hSpecHud, "♟ Spectator HUD ♟");

	decl String:buffer[512];
	Format(buffer, sizeof(buffer), "▸ Slots %i/%i | Tickrate %i", GetRealClientCount(), GetConVarInt(FindConVar("sv_maxplayers")), RoundToNearest(1.0 / GetTickInterval()));
	DrawPanelText(hSpecHud, buffer);
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
	
	Format(info, sizeof(info), "->1. Survivors [%d]", L4D2Direct_GetVSCampaignScore(SurvivorTeamIndex));
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, info);
	
	ClearArray(hSurvivorArray);
	StoreSequentialSurvivorsToArray(hSurvivorArray);
	
	for (new i = 0; i < GetArraySize(hSurvivorArray); i++) 
	{
		new client = GetArrayCell(hSurvivorArray, i);
		
		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client))
		{
			Format(info, sizeof(info), "%s: Dead", name);
		}
		else
		{
			new WeaponId:primaryWep = IdentifyWeapon(GetPlayerWeaponSlot(client, _:L4D2WeaponSlot_Primary));
			GetLongWeaponName(primaryWep, info, sizeof(info));
			GetMeleePrefix(client, buffer, sizeof(buffer)); 
			Format(info, sizeof(info), "%s/%s", info, buffer);

			if (IsSurvivorHanging(client))
			{
				Format(info, sizeof(info), "%s: %iHP <Hanging> [%s]", name, GetSurvivorHealth(client), info);
			}
			else if (IsIncapacitated(client))
			{
				Format(info, sizeof(info), "%s: %iHP <Incapped(#%i)> [%s]", name, GetSurvivorHealth(client), (GetSurvivorIncapCount(client) + 1), info);
			}
			else
			{
				new health = GetSurvivorHealth(client) + GetSurvivorTemporaryHealth(client);
				new tempHealth = GetSurvivorTemporaryHealth(client);
				new incapCount = GetSurvivorIncapCount(client);
				if (incapCount == 0)
				{
					Format(buffer, sizeof(buffer), "#%iT", tempHealth);
					Format(info, sizeof(info), "%s: %iHP%s [%s]", name, health, (tempHealth ? buffer : ""), info);
				}
				else
				{
					Format(buffer, sizeof(buffer), "%i incap%s", incapCount, (incapCount > 1 ? "s" : ""));
					Format(info, sizeof(info), "%s: %iHP (%s) [%s]", name, health, buffer, info);
				}
			}
		}
		
		DrawPanelText(hSpecHud, info);
	}
	
	
	
	if (hybridScoringAvailable)
	{
		new healthBonus = SMPlus_GetHealthBonus();
		new damageBonus = SMPlus_GetDamageBonus();
		new pillsBonus = SMPlus_GetPillsBonus();
		new totalBonus = healthBonus + damageBonus + pillsBonus;
		new maxTotalBonus = SMPlus_GetMaxHealthBonus() + SMPlus_GetMaxDamageBonus() + SMPlus_GetMaxPillsBonus();
		
		DrawPanelText(hSpecHud, " ");
		Format(info, sizeof(info), " HB: %i <%.1f%%>", healthBonus, ToPercent(healthBonus, SMPlus_GetMaxHealthBonus()));
		DrawPanelText(hSpecHud, info);
		Format(info, sizeof(info), " DB: %i <%.1f%%>", damageBonus, ToPercent(damageBonus, SMPlus_GetMaxDamageBonus()));
		DrawPanelText(hSpecHud, info);
		Format(info, sizeof(info), " Pills: %i <%.1f%%>", pillsBonus, ToPercent(pillsBonus, SMPlus_GetMaxPillsBonus()));
		DrawPanelText(hSpecHud, info);
		Format(info, sizeof(info), " Total: %i <%.1f%%>", totalBonus, ToPercent(totalBonus, maxTotalBonus));
		DrawPanelText(hSpecHud, info);
	}
}

FillInfectedInfo(Handle:hSpecHud) 
{
	decl String:info[512];
	decl String:buffer[32];
	decl String:name[MAX_NAME_LENGTH];

	new InfectedTeamIndex = GameRules_GetProp("m_bAreTeamsFlipped") ? 0 : 1;
	
	Format(info, sizeof(info), "->2. Infected [%d]", L4D2Direct_GetVSCampaignScore(InfectedTeamIndex));
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
				Format(info, sizeof(info), "%s: Dead", name);
			}
			else
			{
				Format(buffer, sizeof(buffer), "%is", RoundToNearest(timeLeft));
				Format(info, sizeof(info), "%s: Dead (%s)", name, (RoundToNearest(timeLeft) ? buffer : "Spawning..."));
			}
		}
		else 
		{
			new L4D2SI:zClass = GetInfectedClass(client);
			if (zClass == ZC_Tank)
				continue;

			if (IsInfectedGhost(client))
			{
				// TO-DO: Handle a case of respawning chipped SI, show the ghost's health
				Format(info, sizeof(info), "%s: %s (Ghost)", name, ZOMBIECLASS_NAME(zClass));
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
							/* Weird exception where Smoker has CD shown while he is pulling/choking a survivor */
							buffer = "";
						else
							Format(buffer, sizeof(buffer), " [CD (%is)]", RoundToNearest(fCooldown));
					}
					else
						buffer = "";
				}
				
				if (GetEntityFlags(client) & FL_ONFIRE)
				{
					Format(info, sizeof(info), "%s: %s (%iHP) [On Fire]%s", name, ZOMBIECLASS_NAME(zClass), GetClientHealth(client), buffer);
				}
				else
				{
					Format(info, sizeof(info), "%s: %s (%iHP)%s", name, ZOMBIECLASS_NAME(zClass), GetClientHealth(client), buffer);
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
		DrawPanelText(hSpecHud, "___________________");
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
		case 0: Format(info, sizeof(info), "native");
		case 1: Format(info, sizeof(info), "%ist", passCount);
		case 2: Format(info, sizeof(info), "%ind", passCount);
		case 3: Format(info, sizeof(info), "%ird", passCount);
		default: Format(info, sizeof(info), "%ith", passCount);
	}

	if (!IsFakeClient(tank))
	{
		GetClientFixedName(tank, name, sizeof(name));
		Format(info, sizeof(info), "Control : %s (%s)", name, info);
	}
	else
	{
		Format(info, sizeof(info), "Control : AI (%s)", info);
	}
	DrawPanelText(hSpecHud, info);

	// Draw health
	new health = GetClientHealth(tank);
	new maxhealth = GetEntProp(tank, Prop_Send, "m_iMaxHealth");
	if (health <= 0 || IsIncapacitated(tank) || !IsPlayerAlive(tank))
	{
		info = "Health  : Dead";
	}
	else
	{
		new healthPercent = RoundFloat((100.0 / maxhealth) * health);
		Format(info, sizeof(info), "Health  : %i / %i%%", health, ((healthPercent < 1) ? 1 : healthPercent));
	}
	DrawPanelText(hSpecHud, info);

	// Draw frustration
	if (!IsFakeClient(tank))
	{
		Format(info, sizeof(info), "Frustr.  : %d%%", GetTankFrustration(tank));
	}
	else
	{
		info = "Frustr.  : AI";
	}
	DrawPanelText(hSpecHud, info);

	// Draw lerptime
	if (!IsFakeClient(tank))
	{
		Format(info, sizeof(info), "Ping|Lerp: %ims | %.1f", RoundToNearest(GetClientAvgLatency(tank, NetFlow_Both) * 500.0), GetLerpTime(tank) * 1000.0);
	}
	else
	{
		info = "Ping|Lerp: AI";
	}
	DrawPanelText(hSpecHud, info);

	// Draw fire status
	if (GetEntityFlags(tank) & FL_ONFIRE)
	{
		new timeleft = RoundToCeil(health / (maxhealth / Float:GetConVarInt(FindConVar("tank_burn_duration"))));
		Format(info, sizeof(info), "On Fire : %is", timeleft);
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
	decl String:buffer[512];

	GetConVarString(FindConVar("l4d_ready_cfg_name"), info, sizeof(info));

	if (GetCurrentGameMode() == L4D2Gamemode_Scavenge)
	{
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, "->3. Game");

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

		Format(info, sizeof(info), "Half: %s", (InSecondHalfOfRound() ? "2nd" : "1st"));
		DrawPanelText(hSpecHud, info);

		Format(info, sizeof(info), "Round: %s", buffer);
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
		/*
		new String:tankOwnerName[MAX_NAME_LENGTH] = "";
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && IsInfected(i))
			{
				if (L4D2Direct_GetTankTickets(i) == 20000)
				{
					GetClientFixedName(i, tankOwnerName, sizeof(tankOwnerName));
					Format(tankOwnerName, sizeof(tankOwnerName), "(%s)", tankOwnerName);
					break;
				}
			}
		}*/

		if (l4d_tank_percent == INVALID_HANDLE || GetConVarBool(l4d_tank_percent))
		{	
			Format(buffer, sizeof(buffer), "%i%%", tankPercent);
			Format(info, sizeof(info), "Tank: %s", (tankPercent ? buffer : (IsStaticTankMap() ? "Static" : "None")));
		}
		if (l4d_witch_percent == INVALID_HANDLE || GetConVarBool(l4d_witch_percent))
		{
			Format(buffer, sizeof(buffer), "%i%%", witchPercent);
			Format(info, sizeof(info), "%s | Witch: %s", info, (witchPercent ? buffer : (IsStaticWitchMap() ? "Static" : "None")));
		}
		Format(info, sizeof(info), "%s | Cur: %i%%", info, survivorFlow);
		DrawPanelText(hSpecHud, info);
		
		new tankClient = GetTankSelection();
		if (tankClient != -1)
		{
			GetClientFixedName(tankClient, buffer, sizeof(buffer));
			Format(info, sizeof(info), "*Tank Selection -> %s", buffer);
			DrawPanelText(hSpecHud, info);
		}
	}
}

/* Stocks */

StoreSequentialSurvivorsToArray(&Handle:hArray)
{
	new survivorCount;
	for (new client = 1; client <= MaxClients && survivorCount < GetConVarInt(survivor_limit); client++) 
	{
		if (IsSurvivor(client))
		{
			survivorCount++;
			
			new index = PushArrayCell(hArray, client), netprop = GetCharacterNetprop(client);
			
			for (new i = GetArraySize(hArray) - 1; i >= 0; i--)
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
	if (netprop == 6)		// Francis netprop = 6
		return _:Francis;	// but here we want to match the official sequence
	if (netprop == 7)		// Louis netprop = 7
		return _:Louis;		// but here we want to match the official sequence
	
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

//Float:GetAbilityCooldownTime(client, L4D2SI:zClass)
//{
//	new iEntity = -1;
//	while ((iEntity = FindEntityByClassname(iEntity, L4D2SI_AbilityNames[zClass])) != -1)
//	{
//		if (GetEntPropEnt(iEntity, Prop_Send, "m_owner") == client) { break; }
//	}
//	
//	return iEntity == -1 ? 0.0 : GetEntPropFloat(iEntity, Prop_Send, "m_duration");
//}

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

Float:ToPercent(score, maxbonus)
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

	if (strlen(name) > 20) 
	{
		name[17] = name[18] = name[19] = '.';
		name[20] = 0;
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
/*
bool:RoundHasFlowTank()
{
	return L4D2Direct_GetVSTankToSpawnThisRound(_:InSecondHalfOfRound());
}

bool:RoundHasFlowWitch()
{
	return L4D2Direct_GetVSWitchToSpawnThisRound(_:InSecondHalfOfRound());
}

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
