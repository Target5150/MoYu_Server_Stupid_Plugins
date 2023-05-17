#if defined _readyup_game_included
 #endinput
#endif
#define _readyup_game_included

#pragma semicolon 1
#pragma newdecls required

void LockUnlockSurvivalStart(bool lock)
{
	int ent = MaxClients+1;
	while ((ent = FindEntityByClassname(ent, "trigger_finale")) != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, lock ? "Disable" : "Enable");
	}
	
	while ((ent = FindEntityByClassname(ent, "func_button")) != INVALID_ENT_REFERENCE)
	{
		char name[MAX_NAME_LENGTH];
		GetEntPropString(ent, Prop_Data, "m_iName", name, sizeof(name));
		if (StrContains(name, "survival", false) == -1)
			continue;
		
		AcceptEntityInput(ent, lock ? "Lock" : "Unlock");
	}
}

Action Timer_RestartCountdowns(Handle timer, bool startOn)
{
	RestartCountdowns(startOn);
	return Plugin_Stop;
}

void RestartCountdowns(bool startOn)
{
	if (!ReadyManager.InReadyUp() && !startOn) {
		return;
	}
	
	if (L4D2_IsScavengeMode())
	{
		RestartScvngSetupCountdown(startOn);
		ResetAccumulatedTime();
	}
	else if (L4D_IsVersusMode())
	{
		RestartVersusStartCountdown(startOn);
	}
	else if (L4D_IsSurvivalMode())
	{
		RestartSurvivalSetupCountdown(startOn);
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
	static ConVar versus_force_start_time = null;
	if (versus_force_start_time == null)
		if ((versus_force_start_time = FindConVar("versus_force_start_time")) == null)
			return;
	
	L4D2_CTimerStart(L4D2CT_VersusStartTimer, startOn ? versus_force_start_time.FloatValue : 99999.9);
}

void RestartSurvivalSetupCountdown(bool startOn)
{
	static ConVar director_survival_setup_time = null;
	if (director_survival_setup_time == null)
		if ((director_survival_setup_time = FindConVar("director_survival_setup_time")) == null)
			return;
	
	CountdownTimer ct = GetSurvivalSetupTimer();
	
	if (!startOn)
	{
		CTimer_Invalidate(ct);
	}
	else
	{
		float time = L4D2_GetScriptValueFloat("SurvivalSetupTime", director_survival_setup_time.FloatValue);
		CTimer_Start(ct, time);
		SetSurvivalSetupNotifyTime(time);
	}
}

static CountdownTimer GetSurvivalSetupTimer()
{
	static Address s_pSetupTimer = Address_Null;
	if (s_pSetupTimer == Address_Null)
	{
		Address pSurvivalMode = LoadFromAddress(L4D_GetPointer(POINTER_DIRECTOR) + view_as<Address>(1408), NumberType_Int32); // >:(
		s_pSetupTimer = pSurvivalMode + view_as<Address>(68);
	}
	
	return view_as<CountdownTimer>(s_pSetupTimer);
}

static void SetSurvivalSetupNotifyTime(float time)
{
	static Address s_pSetupNotifyTime = Address_Null;
	if (s_pSetupNotifyTime == Address_Null)
	{
		Address pSurvivalMode = LoadFromAddress(L4D_GetPointer(POINTER_DIRECTOR) + view_as<Address>(1408), NumberType_Int32); // >:(
		s_pSetupNotifyTime = pSurvivalMode + view_as<Address>(156);
	}
	
	int decimal = RoundToFloor(time);
	decimal -= decimal % 10;
	StoreToAddress(s_pSetupNotifyTime, decimal, NumberType_Int32, false);
}

static float GetMobSpawnMinInterval()
{
	static ConVar s_cvMinInterval[Difficulty_SIZE];
	if (s_cvMinInterval[0] == null)
	{
		char buffer[64];
		for (int i = 0; i < Difficulty_SIZE; ++i)
		{
			strcopy(buffer, sizeof(buffer), sDifficultyStrings[i]);
			String_ToLower(buffer, sizeof(buffer));
			Format(buffer, sizeof(buffer), "z_mob_spawn_min_interval_%s", buffer);
			
			s_cvMinInterval[i] = FindConVar(buffer);
			if (s_cvMinInterval[i] == null)
			{
				ThrowError("Missing convars for mob spawn interval! (%s)", buffer);
			}
		}
	}
	
	return L4D2_GetScriptValueFloat("MobSpawnMinTime", s_cvMinInterval[GetDifficulty()].FloatValue);
}

static float GetMobSpawnMaxInterval()
{
	static ConVar s_cvMaxInterval[Difficulty_SIZE];
	if (s_cvMaxInterval[0] == null)
	{
		char buffer[64];
		for (int i = 0; i < Difficulty_SIZE; ++i)
		{
			strcopy(buffer, sizeof(buffer), sDifficultyStrings[i]);
			String_ToLower(buffer, sizeof(buffer));
			Format(buffer, sizeof(buffer), "z_mob_spawn_max_interval_%s", buffer);
			
			s_cvMaxInterval[i] = FindConVar(buffer);
			if (s_cvMaxInterval[i] == null)
			{
				ThrowError("Missing convars for mob spawn interval! (%s)", buffer);
			}
		}
	}
	
	return L4D2_GetScriptValueFloat("MobSpawnMaxTime", s_cvMaxInterval[GetDifficulty()].FloatValue);
}

static float GetRandomMobSpawnInterval()
{
	SetRandomSeed(GetTime());
	return GetRandomFloat(GetMobSpawnMinInterval(), GetMobSpawnMaxInterval());
}

void RestartMobCountdown(bool startOn)
{
	float fDuration = startOn ? GetRandomMobSpawnInterval() : 99999.9;
	L4D2_CTimerStart(L4D2CT_MobSpawnTimer, fDuration);
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
	director_no_specials.BoolValue = !allow;
}
