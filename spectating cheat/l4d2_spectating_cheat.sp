#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4downtown>

enum
{
	L4D_TEAM_SPECTATOR = 1,
	L4D_TEAM_SURVIVOR,
	L4D_TEAM_INFECTED
}
ConVar g_hCvarColor;
ConVar g_hCvarColor2;
int g_iCvarColor;
int g_iCvarColor2;
static bool bSpecCheatActive[MAXPLAYERS + 1];
int iZombieClass[MAXPLAYERS + 1];
int i_Ent[5000] = -1;
Handle hClientGlowEnts       = INVALID_HANDLE;

public Plugin myinfo = 
{
    name = "l4d2 specating cheat",
    author = "Harry Potter , IA , PaaNChaN ",
    description = "A spectator who watching the survivor at first person view would see the infected model glows though the wall",
    version = "1.6",
    url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/spectating%20cheat"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hCvarColor =	CreateConVar(	"l4d2_specting_cheat_ghost_color",		"255 255 255",		"Ghost glow color, Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);
	g_hCvarColor2 =	CreateConVar(	"l4d2_specting_cheat_alive_color",		"255 0 0",			"Alive glow color, Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);
	
	char sColor[16],sColor2[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	g_iCvarColor = GetColor(sColor);
	g_hCvarColor2.GetString(sColor2, sizeof(sColor2));
	g_iCvarColor2 = GetColor(sColor2);
	
	g_hCvarColor.AddChangeHook(ConVarChanged_Glow);
	g_hCvarColor2.AddChangeHook(ConVarChanged_Glow_2);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	
	RegConsoleCmd("sm_speccheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_watchcheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_lookcheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_seecheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_meetcheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_starecheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_hellocheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_areyoucheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_fuckyoucheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		iZombieClass[i] = -1;
		bSpecCheatActive[i] = false;  
	}
	hClientGlowEnts = CreateArray();
}

public OnPluginEnd() //unload插件的時候移除發光物件
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		iZombieClass[i] = -1;
		bSpecCheatActive[i] = false;  
	}
	UnhookEvent("player_spawn", Event_PlayerSpawn);
	UnhookEvent("player_death", Event_PlayerDeath);
	UnhookEvent("player_disconnect", Event_PlayerDisconnect);
	
	new entity;
	for ( int i = 0; i < GetArraySize(hClientGlowEnts); i++ ) {
		entity = i_Ent[GetArrayCell(hClientGlowEnts, i)];
		if(IsValidEntRef(entity))
			RemoveEdict(entity);
	}
	ClearArray(hClientGlowEnts);
	CloseHandle(hClientGlowEnts);
}

public Action ToggleSpecCheatCmd(int client, int args) 
{
	if(GetClientTeam(client)!= L4D_TEAM_SPECTATOR)
		return;
	bSpecCheatActive[client] = !bSpecCheatActive[client];
	PrintToChat(client, "\x01[\x04WatchMode\x01]\x03 Watch Cheater Mode \x01 is now \x05%s\x01.", (bSpecCheatActive[client] ? "On" : "Off"));
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		iZombieClass[i] = -1;
	}
}

public OnMapStart()
{
	ClearArray(hClientGlowEnts);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{ 
	iZombieClass[GetClientOfUserId(event.GetInt("userid"))] = -1;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client && !dontBroadcast )
	{
		iZombieClass[client] = -1;
		bSpecCheatActive[client] = false;  
	}
}

public L4D_OnEnterGhostState(int client)
{
	iZombieClass[client] = -1;
	CreateTimer(0.5,CreateInfectedModelGlow,client,TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{ 
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	iZombieClass[client] = -1;
	CreateTimer(0.5,CreateInfectedModelGlow,client,TIMER_FLAG_NO_MAPCHANGE);
}

public Action CreateInfectedModelGlow(Handle timer, int client)
{
	if (!client || 
	!IsClientInGame(client) || 
	GetClientTeam(client) != L4D_TEAM_INFECTED || 
	!IsPlayerAlive(client) ||
	iZombieClass[client] != -1) return;
	
	///////設定發光物件//////////
	// Get Client Model
	char sModelName[64];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	//PrintToChatAll("%N: %s",client,sModelName);
	
	// Spawn dynamic prop entity
	i_Ent[client] = CreateEntityByName("prop_dynamic_ornament");
	if (i_Ent[client] == -1) return;

	// Set new fake model
	PrecacheModel(sModelName);
	SetEntityModel(i_Ent[client], sModelName);
	DispatchSpawn(i_Ent[client]);

	// Set outline glow color
	SetEntProp(i_Ent[client], Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(i_Ent[client], Prop_Send, "m_nSolidType", 0);
	SetEntProp(i_Ent[client], Prop_Send, "m_nGlowRange", 9000);
	SetEntProp(i_Ent[client], Prop_Send, "m_iGlowType", 3);
	if(IsPlayerGhost(client))
		SetEntProp(i_Ent[client], Prop_Send, "m_glowColorOverride", g_iCvarColor);
	else
		SetEntProp(i_Ent[client], Prop_Send, "m_glowColorOverride", g_iCvarColor2);
	AcceptEntityInput(i_Ent[client], "StartGlowing");

	// Set model invisible
	SetEntityRenderMode(i_Ent[client], RENDER_TRANSCOLOR);
	SetEntityRenderColor(i_Ent[client], 0, 0, 0, 0);
	
	// Set model attach to client, and always synchronize
	SetVariantString("!activator");
	AcceptEntityInput(i_Ent[client], "SetAttached", client);
	AcceptEntityInput(i_Ent[client], "TurnOn");
	///////發光物件完成//////////
	
	//設定特感種類
	iZombieClass[client] = GetEntProp(client, Prop_Send, "m_zombieClass");
	
	//Push to Ent Array
	if ( FindValueInArray(hClientGlowEnts, client) == -1 )
		PushArrayCell(hClientGlowEnts, client);
		
	// Trace client and model
	SDKHook(client, SDKHook_PreThinkPost, TracknfectedThink);
	SDKHook(i_Ent[client], SDKHook_SetTransmit, Hook_SetTransmit);
}
public void TracknfectedThink(int client)
{
	if (!client || //非玩家
	!IsClientInGame(client) || //離開
	GetClientTeam(client) != L4D_TEAM_INFECTED || //不在特感隊伍
	!IsPlayerAlive(client) || //沒活著
	iZombieClass[client] == -1 || //地圖開始 剛死掉 剛復活 剛離開
	iZombieClass[client] != GetEntProp(client, Prop_Send, "m_zombieClass") || //特感種類變了 (轉當坦克)
	!IsValidEntity(i_Ent[client]) || i_Ent[client] == -1) //發光物件不存在
	{
		if (IsValidEdict(i_Ent[client]))
		{
			RemoveEdict(i_Ent[client]);
		}
		i_Ent[client] = -1;
		iZombieClass[client] = -1;
		SDKUnhook(client, SDKHook_PreThinkPost, TracknfectedThink);
		SDKUnhook(i_Ent[client], SDKHook_SetTransmit, Hook_SetTransmit);
		new index;
		if ( (index = FindValueInArray(hClientGlowEnts, client)) != -1 )
			RemoveFromArray(hClientGlowEnts, index);
	}
}

public Action Hook_SetTransmit(int entity, int client)
{
	if( bSpecCheatActive[client] && GetClientTeam(client) == L4D_TEAM_SPECTATOR)
		return Plugin_Continue;
	
	return Plugin_Handled;
}

int GetColor(char[] sTemp)
{
	if( StrEqual(sTemp, "") )
		return 0;

	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, 3, 4);

	if( color != 3 )
		return 0;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color;
}

public ConVarChanged_Glow(Handle convar, const char[] oldValue, const char[] newValue) {
	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	g_iCvarColor = GetColor(sColor);
	
	int client;
	for ( int i = 0; i < GetArraySize(hClientGlowEnts); i++ ) {
		client = GetArrayCell(hClientGlowEnts, i);
		if(IsValidEntRef(i_Ent[client]))
		{
			SetEntProp(i_Ent[client], Prop_Send, "m_iGlowType", 3);
			if(IsClientInGame(client)&&IsPlayerGhost(client))
				SetEntProp(i_Ent[client], Prop_Send, "m_glowColorOverride", g_iCvarColor);
		}
	}
}

public ConVarChanged_Glow_2(Handle convar, const char[] oldValue, const char[] newValue) {
	char sColor2[16];
	g_hCvarColor2.GetString(sColor2, sizeof(sColor2));
	g_iCvarColor2 = GetColor(sColor2);
	
	int client;
	for ( int i = 0; i < GetArraySize(hClientGlowEnts); i++ ) {
		client = GetArrayCell(hClientGlowEnts, i);
		if(IsValidEntRef(i_Ent[client]))
		{
			SetEntProp(i_Ent[client], Prop_Send, "m_iGlowType", 3);
			if(IsClientInGame(client)&&!IsPlayerGhost(client))
				SetEntProp(i_Ent[client], Prop_Send, "m_glowColorOverride", g_iCvarColor2);
		}
	}
}

bool IsPlayerGhost(int client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isGhost");
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE && entity!= -1 )
		return true;
	return false;
}