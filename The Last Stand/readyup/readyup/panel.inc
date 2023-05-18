#if defined _readyup_panel_included
 #endinput
#endif
#define _readyup_panel_included

#pragma semicolon 1
#pragma newdecls required

#include "readyup/footer.inc"
#include "readyup/util.inc"

static Footer
	cmdFooter,
	nativeFooter;
	
static int
	curCmd;

static bool
	hiddenPanel[MAXPLAYERS+1];

static float 
	fStartTimestamp;

static Handle
	s_panelTimer,
	s_cmdTimer;

static ConVar g_cvServerNamer;
static ConVar l4d_ready_cfg_name, l4d_ready_server_cvar, l4d_ready_max_players, l4d_ready_swap_footers;
static bool casterSystemAvailable;

methodmap ReadyPanel
{
	public static void Init()
	{
		static bool s_bInit = false;
		if (s_bInit)
			return;
		
		LoadPluginTranslations(TRANSLATION_READYUP_PANEL);
		
		cmdFooter = new Footer();
		cmdFooter.Add("->1. !ready|!r / !unready|!nr");
		cmdFooter.Add("->2. !slots #");
		cmdFooter.Add("->3. !voteboss <tank> <witch>");
		cmdFooter.Add("->4. !match / !rmatch");
		cmdFooter.Add("->5. !show / !hide");
		cmdFooter.Add("->6. !setscores <survs> <inf>");
		cmdFooter.Add("->7. !lerps");
		cmdFooter.Add("->8. !secondary");
		cmdFooter.Add("->9. !forcestart / !fs");
		
		nativeFooter = new Footer();
		
		l4d_ready_cfg_name		= CreateConVar("l4d_ready_cfg_name", "", "Configname to display on the ready-up panel", FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
		l4d_ready_server_cvar	= CreateConVar("l4d_ready_server_cvar", "sn_main_name", "ConVar to retrieve the server name for displaying on the ready-up panel", FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
		l4d_ready_max_players	= CreateConVar("l4d_ready_max_players", "12", "Maximum number of players to show on the ready-up panel.", FCVAR_NOTIFY, true, 0.0, true, MAXPLAYERS+1.0);
		l4d_ready_swap_footers	= CreateConVar("l4d_ready_swap_footers", "0", "Swap print locations of command footers and native footers.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
		
		l4d_ready_server_cvar.AddChangeHook(CvarChg_ServerCvar);
		
		s_bInit = true;
	}
	
	public static void OnPotentialLibraryUpdate()
	{
		FillServerNamer();
		FindCasterSystem();
	}
	
	public static void Create()
	{
		curCmd = 0;
		s_panelTimer = CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT);
		s_cmdTimer = CreateTimer(4.0, MenuCmd_Timer, _, TIMER_REPEAT);
		
		fStartTimestamp = GetGameTime();
	}
	
	public static void Destroy()
	{
		nativeFooter.Clear();
		
		delete s_panelTimer;
		delete s_cmdTimer;
	}
	
	public static Footer GetNativeFooter()
	{
		return nativeFooter;
	}
	
	public static Footer GetCmdFooter()
	{
		return cmdFooter;
	}
	
	public static bool IsActive()
	{
		return s_panelTimer != null;
	}
	
	public static bool IsHiddenTo(int client)
	{
		return hiddenPanel[client];
	}
	
	public static bool SetHiddenTo(int client, bool hidden)
	{
		bool prev = hiddenPanel[client];
		hiddenPanel[client] = hidden;
		return prev;
	}
}

static void FillServerNamer()
{
	char buffer[64];
	l4d_ready_server_cvar.GetString(buffer, sizeof buffer);
	if ((g_cvServerNamer = FindConVar(buffer)) == null)
		g_cvServerNamer = FindConVar("hostname");
}

static void FindCasterSystem()
{
	casterSystemAvailable = LibraryExists("caster_system");
}

static void CvarChg_ServerCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	FillServerNamer();
}

static int DummyHandler(Handle menu, MenuAction action, int param1, int param2) { return 1; }

static Action MenuRefresh_Timer(Handle timer)
{
	ArrayList langClientsArray = new ArrayList(2); // lang id -> client array
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client)) 
			continue;
		
		if (hiddenPanel[client])
			continue;
		
		if (BuiltinVote_IsVoteInProgress() && IsClientInBuiltinVotePool(client))
			continue;
		
		if (Game_IsVoteInProgress())
		{
			int voteteam = Game_GetVoteTeam();
			if (voteteam == -1 || voteteam == GetClientTeam(client))
			{
				continue;
			}
		}
			
		switch (GetClientMenu(client))
		{
			case MenuSource_External, MenuSource_Normal: continue;
		}
		
		ArrayList clientsArray;
		
		int lang = GetClientLanguage(client);
		int index = langClientsArray.FindValue(lang, 0);
		if (index == -1)
		{
			clientsArray = new ArrayList();
			langClientsArray.Set(langClientsArray.Push(lang), clientsArray, 1);
		}
		else
		{
			clientsArray = langClientsArray.Get(index, 1);
		}
		
		clientsArray.Push(client);
	}
	
	int size = langClientsArray.Length;
	for (int i = 0; i < size; ++i)
	{
		ArrayList clientsArray = langClientsArray.Get(i, 1);
		SetGlobalTransTarget(clientsArray.Get(0));
		
		Panel menuPanel = new Panel();
		UpdatePanel(menuPanel);
		
		int count = clientsArray.Length;
		for (int j = 0; j < count; ++j)
		{
			menuPanel.Send(clientsArray.Get(j), DummyHandler, 1);
		}
		
		delete menuPanel;
		delete clientsArray;
	}
	
	delete langClientsArray;
	
	return Plugin_Continue;
}

static Action MenuCmd_Timer(Handle timer)
{
	if (cmdFooter.Length)
	{
		curCmd = (curCmd + 1) % cmdFooter.Length;
	}
	return Plugin_Continue;
}

static void FillFooters(Panel menuPanel, bool bTail)
{
	if (l4d_ready_swap_footers.BoolValue)
		bTail = !bTail;
	
	if (!bTail)
	{
		if (cmdFooter.Length)
		{
			char buffer[64];
			FormatEx(buffer, sizeof(buffer), "%t", "Panel_CmdFooter_Title");
			
			menuPanel.DrawText(" ");
			menuPanel.DrawText(buffer);
			menuPanel.DrawText(FooterGet(cmdFooter, curCmd));
		}
	}
	else
	{
		if (nativeFooter.Length)
		{
			menuPanel.DrawText(" ");
			for (int i = 0; i < nativeFooter.Length; i++)
			{
				menuPanel.DrawText(FooterGet(nativeFooter, i));
			}
		}
	}
}

static void UpdatePanel(Panel menuPanel)
{
	char survivorBuffer[400] = "";
	char infectedBuffer[400] = "";
	char casterBuffer[300] = "";
	char specBuffer[200] = "";
	int playerCount = 0;
	int casterCount = 0;
	int specCount = 0;
	int survivorCount = 0;
	int infectedCount = 0;

	char ServerBuffer[128];
	char ServerName[32];
	char cfgName[32];

	int iPassTime = RoundToFloor(GetGameTime() - fStartTimestamp);
	
	ReadyMode readyUpMode = ReadyManager.GetReadyMode();
	int isTeamReadyMode = readyUpMode == ReadyMode_TeamReady;
	int survivorReady = ReadyManager.IsTeamReady(ReadyTeam_Survivor);
	int infectedReady = ReadyManager.IsTeamReady(ReadyTeam_Infected);

	g_cvServerNamer.GetString(ServerName, sizeof(ServerName));
	
	l4d_ready_cfg_name.GetString(cfgName, sizeof(cfgName));
	Format(ServerBuffer, sizeof(ServerBuffer), "%t", "Panel_Title", ServerName, GetSeriousClientCount(), GetMaxPlayers(), cfgName);
	menuPanel.DrawText(ServerBuffer);
	
	FormatTime(ServerBuffer, sizeof(ServerBuffer), NULL_STRING);
	Format(ServerBuffer, sizeof(ServerBuffer), "▸ %s (%02d:%02d)", ServerBuffer, iPassTime / 60, iPassTime % 60);
	menuPanel.DrawText(ServerBuffer);

	FillFooters(menuPanel, false);
	menuPanel.DrawText(" ");
	
	char nameBuf[MAX_NAME_LENGTH];
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			++playerCount;
			GetClientFixedName(client, nameBuf, sizeof(nameBuf));
			
			if (IsPlayer(client))
			{
				static const char 
					hintPhrase[2][2][] = {
						{"HintUnready", "HintTeamUnready"},
						{"HintReady", "HintTeamReady"},
					},
					readyPhrase[2][] = {
						"Panel_Player_Unready",
						"Panel_Player_Ready"
					};

				if (IsPlayerAfk(client))
					Format(nameBuf, sizeof(nameBuf), "%t", "Panel_PlayerName_Afk", nameBuf);

				bool isSurvivor = (GetClientTeam(client) == L4D2Team_Survivor);
				int order = isSurvivor ? ++survivorCount : ++infectedCount;
				
				int isReady = view_as<int>(ReadyManager.IsPlayerReady(client));
				if (isTeamReadyMode)
					isReady = isSurvivor ? survivorReady : infectedReady;
				
				switch (readyUpMode)
				{
					case ReadyMode_PlayerReady:
					{
						if (!ReadyManager.InLiveCountdown()) PrintHintText(client, "%t", hintPhrase[isReady][isTeamReadyMode]);
						Format(nameBuf, sizeof(nameBuf), "%t\n", readyPhrase[isReady], order, nameBuf);
					}
					case ReadyMode_AutoStart:
					{
						Format(nameBuf, sizeof(nameBuf), "%t\n", "Panel_Player_AutoStart", order, nameBuf);
					}
					case ReadyMode_TeamReady:
					{
						if (!ReadyManager.InLiveCountdown()) PrintHintText(client, "%t", hintPhrase[isReady][isTeamReadyMode]);
						Format(nameBuf, sizeof(nameBuf), "%t\n", "Panel_Player_TeamReady", order, nameBuf);
					}
				}
				isSurvivor ? StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf) : StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
			}
			else
			{
				++specCount;
				if (casterSystemAvailable && IsClientCaster(client))
				{
					++casterCount;
					Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
					StrCat(casterBuffer, sizeof(casterBuffer), nameBuf);
				}
				else
				{
					if (playerCount <= l4d_ready_max_players.IntValue)
					{
						Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
						StrCat(specBuffer, sizeof(specBuffer), nameBuf);
					}
				}
			}
		}
	}
	
	static const char 
		teamNamePhrase[2][] = {
			"Panel_TeamUnready", "Panel_TeamReady"
		};
	
	int textCount = 0;
	int bufLen = strlen(survivorBuffer);
	if (bufLen != 0)
	{
		survivorBuffer[bufLen] = '\0';
		ReplaceString(survivorBuffer, sizeof(survivorBuffer), "#", "_");
		Format(nameBuf, sizeof(nameBuf), "%t", isTeamReadyMode ? teamNamePhrase[survivorReady] : "Panel_TeamRaw", ++textCount, "Survivors");
		menuPanel.DrawText(nameBuf);
		menuPanel.DrawText(survivorBuffer);
	}

	bufLen = strlen(infectedBuffer);
	if (bufLen != 0)
	{
		infectedBuffer[bufLen] = '\0';
		ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#", "_");
		Format(nameBuf, sizeof(nameBuf), "%t", isTeamReadyMode ? teamNamePhrase[infectedReady] : "Panel_TeamRaw", ++textCount, "Infected");
		menuPanel.DrawText(nameBuf);
		menuPanel.DrawText(infectedBuffer);
	}
	
	if (specCount && textCount) menuPanel.DrawText(" ");

	if (casterSystemAvailable)
	{
		bufLen = strlen(casterBuffer);
		if (bufLen != 0)
		{
			casterBuffer[bufLen] = '\0';
			Format(nameBuf, sizeof(nameBuf), "%t", "Panel_TeamRaw", ++textCount, casterCount > 1 ? "Casters" : "Caster");
			menuPanel.DrawText(nameBuf);
			ReplaceString(casterBuffer, sizeof(casterBuffer), "#", "_", true);
			menuPanel.DrawText(casterBuffer);
		}
	}
	
	bufLen = strlen(specBuffer);
	if (bufLen != 0)
	{
		specBuffer[bufLen] = '\0';
		Format(nameBuf, sizeof(nameBuf), "%t", "Panel_TeamRaw", ++textCount, specCount > 1 ? "Spectators" : "Spectator");
		menuPanel.DrawText(nameBuf);
		ReplaceString(specBuffer, sizeof(specBuffer), "#", "_");
		if (playerCount > l4d_ready_max_players.IntValue && specCount - casterCount > 1)
			FormatEx(specBuffer, sizeof(specBuffer), "%t", "Panel_Spectator_TooMany", specCount - casterCount);
		menuPanel.DrawText(specBuffer);
	}

	FillFooters(menuPanel, true);
}