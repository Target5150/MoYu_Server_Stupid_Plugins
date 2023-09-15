#if defined _readyup_game_included
 #endinput
#endif
#define _readyup_game_included

Action Timer_RestartCountdowns(Handle timer, bool startOn)
{
	RestartCountdowns(startOn);
	return Plugin_Stop;
}

void RestartCountdowns(bool startOn)
{
	if (!inReadyUp && !startOn) {
		return;
	}
	
	if (L4D2_IsScavengeMode())
	{
		RestartScvngSetupCountdown(startOn);
		ResetAccumulatedTime();
	}
	else
	{
		RestartVersusStartCountdown(startOn);
	}
	
	RestartMobCountdown(startOn);
}

void ResetAccumulatedTime()
{
	static ConVar scavenge_round_initial_time = null;
	if (scavenge_round_initial_time == null)
		if ((scavenge_round_initial_time = FindConVar("scavenge_round_initial_time")) == null)
			return;
	
	L4D_NotifyNetworkStateChanged();
	GameRules_SetPropFloat("m_flAccumulatedTime", scavenge_round_initial_time.FloatValue);
}

void RestartVersusStartCountdown(bool startOn)
{
	static ConVar s_cv = null;
	if (s_cv == null)
		if ((s_cv = FindConVar("versus_force_start_time")) == null)
			return;
	
	L4D2_CTimerStart(L4D2CT_VersusStartTimer, startOn ? s_cv.FloatValue : 99999.9);
}

void RestartMobCountdown(bool startOn)
{
	static float fDuration = -1.0;
	
	if (startOn)
	{
		if (fDuration != -1.0) L4D2_CTimerStart(L4D2CT_MobSpawnTimer, fDuration);
	}
	else
	{
		float fTemp = L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer);
		if (fTemp != -1.0 && fTemp < 99999.9)
		{
			fDuration = fTemp;
			L4D2_CTimerStart(L4D2CT_MobSpawnTimer, 99999.9);
		}
	}
}

void RestartScvngSetupCountdown(bool startOn)
{
	static ConVar s_cv = null;
	if (s_cv == null)
		if ((s_cv = FindConVar("scavenge_round_setup_time")) == null)
			return;
	
	CountdownTimer timer = L4D2Direct_GetScavengeRoundSetupTimer();
	if (timer == CTimer_Null)
		return;
	
	CTimer_Start(timer, startOn ? s_cv.FloatValue : 99999.9);
	ToggleCountdownPanel(startOn);
}

void ToggleCountdownPanel(bool onoff, int client = 0)
{
	if (client > 0 && IsClientInGame(client)) ShowVGUIPanel(client, "ready_countdown", _, onoff);
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				ShowVGUIPanel(i, "ready_countdown", _, onoff);
			}
		}
	}
}

void ClearSurvivorProgress()
{
	for (int i = 0; i < 4; i++)
	{
		GameRules_SetProp("m_iVersusDistancePerSurvivor", 0, _,
				i + 4 * GameRules_GetProp("m_bAreTeamsFlipped"));
	}
}

void SetAllowSpawns(bool allow)
{
	director_no_specials.BoolValue = allow;
}

// delay to check. make sure we don't miss the targets we want to hook.
void SetSurvivalButtonStatus(bool IsInReady)
{
	CreateTimer(1.0, Timer_SetSurvivalButtonStatus, IsInReady);
}

void SetSurvivalPropsInvunerable(bool IsInReady)
{
	CreateTimer(1.0, Timer_SetSurvivalPropsInvunerable, IsInReady);
}

void SetSurvivalGascansInvunerable(bool IsInReady)
{
	char sName[64];
	int iCount = GetEntityCount();
	for (int iEntity = MaxClients + 1; iEntity < iCount; iEntity++)
	{
		if (!IsValidEntity(iEntity))
			continue;

		GetEntityClassname(iEntity, sName, sizeof(sName));

		if (StrEqual(sName, "weapon_gascan"))
		{
			if (IsInReady)
			{
				SDKHook(iEntity, SDKHook_OnTakeDamage, OnTakeDamage);
				#if DEBUG
				PrintToConsoleAll("SDKHook Enabled, Entity: %d", iEntity);
				#endif
			}
			else
			{
				SDKUnhook(iEntity, SDKHook_OnTakeDamage, OnTakeDamage);
				#if DEBUG
				PrintToConsoleAll("SDKHook Disabled, Entity: %d", iEntity);
				#endif
			}
		}
	}
}

Action Timer_SetSurvivalButtonStatus(Handle timer, bool InReady)
{
	char sName[64];
	int iCount = GetEntityCount();
	for (int iEntity = MaxClients + 1; iEntity < iCount; iEntity++)
	{
		if (!IsValidEntity(iEntity))
			continue;

		GetEntityClassname(iEntity, sName, sizeof(sName));

		if (StrEqual(sName, "func_button") || 
			StrEqual(sName, "func_button_timed")) 	// `func_button_timed` for c7m1 tank train door/c9m2 generator.
		{
			if (InReady)
				AcceptEntityInput(iEntity, "Lock");		//since m_bLocked is only for doors.
			else
				AcceptEntityInput(iEntity, "Unlock");
		}

		// why dont you use func_button.
		char sMapName[64];
		GetCurrentMap(sMapName, sizeof(sMapName))
		if (StrEqual(sMapName, "c12m2_traintunnel") || StrEqual(sMapName, "c11m5_runway"))
		{
			if (StrEqual(sName, "prop_door_rotating"))		// since `prop_door_rotating` exists in most survival maps, and they are not the trigger.
			{
				if (InReady)
					AcceptEntityInput(iEntity, "Lock");
				else
					AcceptEntityInput(iEntity, "Unlock");
			}
/*
			if (StrEqual(sName, "trigger_final"))			// this entity dose not have input `Lock` `Unlock`.
			{
				if (InReady)
					AcceptEntityInput(iEntity, "Disable");	// edit: dont work.
				else
					AcceptEntityInput(iEntity, "Enable");
			}
*/
		}
	}

	return Plugin_Handled;
}

// Efforts from [L4D1 & L4D2] Gascan Invulnerable by Mart.
Action Timer_SetSurvivalPropsInvunerable(Handle timer, bool InReady)
{
	char sName[64];
	int iCount = GetEntityCount();
	for (int iEntity = MaxClients + 1; iEntity < iCount; iEntity++)
	{
		if (!IsValidEntity(iEntity))
			continue;

		GetEntityClassname(iEntity, sName, sizeof(sName));

		if (StrEqual(sName, "prop_physics"))
		{
			// make sure we only(?) hook gascans or gastanks.
			// Improvement needed: Is there a better way to only hook gascans and gastanks? (if we don't check thier models...)
			if (HasEntProp(iEntity, Prop_Send, "m_isCarryable"))
			{
				if (InReady)
				{
					SDKHook(iEntity, SDKHook_OnTakeDamage, OnTakeDamage);
					#if DEBUG
					PrintToConsoleAll("SDKHook Enabled, Entity: %d", iEntity);
					#endif
				}
				else
				{
					SDKUnhook(iEntity, SDKHook_OnTakeDamage, OnTakeDamage);
					#if DEBUG
					PrintToConsoleAll("SDKHook Disabled, Entity: %d", iEntity);
					#endif
				}
			}

		}
	}

	return Plugin_Handled;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{

#if DEBUG
		PrintToChatAll("OnTakeDamage Called. Taken damage: %f", damage);
#endif

	damagetype &= ~(DMG_BURN|DMG_ENERGYBEAM);
	damage = 0.0;

#if DEBUG
		PrintToChatAll("OnTakeDamage Called. Damage changed to: %f", damage);
#endif

	return Plugin_Changed;
}