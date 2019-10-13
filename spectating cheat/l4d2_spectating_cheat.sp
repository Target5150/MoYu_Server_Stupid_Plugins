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
Handle g_hCvarColor;
Handle g_hCvarColor2;
int g_iCvarColor;
int g_iCvarColor2;
static bool bSpecCheatActive[MAXPLAYERS + 1];
int iZombieClass[MAXPLAYERS + 1] = -1;
int i_Ent[5000] = -1;

public Plugin myinfo = 
{
    name = "l4d2 specating cheat",
    author = "Harry Potter",
    description = "If a spectator watching survivor at first person view, would see the infected model glows though the wall",
    version = "1.1",
    url = "https://steamcommunity.com/id/AkemiHomuraGoddess/"
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
	g_hCvarColor =	CreateConVar(	"l4d2_specting_cheat_ghost_color",		"255 255 255",		"Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);
	g_hCvarColor2 =	CreateConVar(	"l4d2_specting_cheat_alive_color",		"255 0 0",			"Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);
	g_iCvarColor = GetColor(g_hCvarColor);
	g_iCvarColor2 = GetColor(g_hCvarColor2);
	HookConVarChange(g_hCvarColor, ConVarChanged_Glow);
	HookConVarChange(g_hCvarColor2, ConVarChanged_Glow_2);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	
	RegConsoleCmd("sm_speccheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_watchcheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_lookcheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	RegConsoleCmd("sm_seecheat", ToggleSpecCheatCmd, "Toggle Speatator watching cheat");
	
	for (int i = 1; i <= MaxClients; i++) 
		bSpecCheatActive[i] = false;  
}

public Action ToggleSpecCheatCmd(int client, int args) 
{
	if(GetClientTeam(client)!= L4D_TEAM_SPECTATOR)
		return;
	bSpecCheatActive[client] = !bSpecCheatActive[client];
	PrintToChat(client, "\x01[\x04WatchMode\x01]\x03 Watch Cheater Mode \x01 is now \x05%s\x01.", (bSpecCheatActive[client] ? "On" : "Off"));
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		iZombieClass[i] = -1;
	}
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{ 
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	iZombieClass[client] = -1;
}

public OnClientPutInServer(client)
{
	iZombieClass[client] = -1;
}

public L4D_OnEnterGhostState(int client)
{
	iZombieClass[client] = -1;
	CreateTimer(0.1,CreateInfectedModelGlow,client,TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{ 
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	iZombieClass[client] = -1;
	CreateTimer(0.1,CreateInfectedModelGlow,client,TIMER_FLAG_NO_MAPCHANGE);
}

public Action CreateInfectedModelGlow(Handle timer, int client)
{
	if (!client || 
	!IsClientInGame(client) || 
	GetClientTeam(client) != L4D_TEAM_INFECTED || 
	!IsPlayerAlive(client) ||
	iZombieClass[client] != -1) return;
	
	///////設定發光物件//////////
	char sModelName[64];
	//法一. 自身模組發光//
	GetEntPropString(client, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	/////////////////////
	//法二. 帽子模組發光//
	//Format(sModelName, sizeof(sModelName), "models/props_fairgrounds/garbage_popcorn_box.mdl");
	/////////////////////
	//PrintToChatAll("%N: %s",client,sModelName);
	
	// Spawn dynamic prop entity
	i_Ent[client] = CreateEntityByName("prop_dynamic_override");
	if (i_Ent[client] == -1) return;

	SetEntityModel(i_Ent[client], sModelName);
	DispatchSpawn(i_Ent[client]);

	SetEntProp(i_Ent[client], Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(i_Ent[client], Prop_Send, "m_nSolidType", 0);
	SetEntProp(i_Ent[client], Prop_Send, "m_nGlowRange", 4500);
	SetEntProp(i_Ent[client], Prop_Send, "m_iGlowType", 3);
	if(IsPlayerGhost(client))
		SetEntProp(i_Ent[client], Prop_Send, "m_glowColorOverride", g_iCvarColor);
	else
		SetEntProp(i_Ent[client], Prop_Send, "m_glowColorOverride", g_iCvarColor2);
	AcceptEntityInput(i_Ent[client], "StartGlowing");

	SetEntityRenderMode(i_Ent[client], RENDER_TRANSCOLOR);
	SetEntityRenderColor(i_Ent[client], 0, 0, 0, 0);

	float vPos[3];
	float vAng[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", vPos);
	GetEntPropVector(client, Prop_Send, "m_angRotation", vAng);
	//法二. 帽子高度調整//
	//vPos[2] += 50;
	/////////////////////
	SetEntPropVector(i_Ent[client], Prop_Send, "m_vecOrigin", vPos);
	SetEntPropVector(i_Ent[client], Prop_Send, "m_angRotation", vAng);

	SetVariantString("!activator");
	AcceptEntityInput(i_Ent[client], "SetParent", client);
	
	TeleportEntity(i_Ent[client], Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0}, NULL_VECTOR);
	///////發光物件完成//////////
	
	iZombieClass[client] = GetEntProp(client, Prop_Send, "m_zombieClass");
	SDKHook(client, SDKHook_PreThinkPost, TracknfectedThink);
	SDKHook(i_Ent[client], SDKHook_SetTransmit, Hook_SetTransmit);
}
public void TracknfectedThink(int client)
{
	if (!client || //非玩家
	!IsClientInGame(client) || //離開
	GetClientTeam(client) != L4D_TEAM_INFECTED || //不在特感隊伍
	!IsPlayerAlive(client) || //沒活著
	iZombieClass[client] == -1 || //回合開始 剛死掉 剛復活 剛進來
	iZombieClass[client] != GetEntProp(client, Prop_Send, "m_zombieClass") || //特感種類變了 (轉當坦克)
	!IsValidEntity(i_Ent[client])) //發光物件不存在
	{
		if (IsValidEdict(i_Ent[client]))
		{
			RemoveEdict(i_Ent[client]);
		}
		iZombieClass[client] = -1;
		SDKUnhook(client, SDKHook_PreThinkPost, TracknfectedThink);
		SDKUnhook(i_Ent[client], SDKHook_SetTransmit, Hook_SetTransmit);
		return;
	}
	
	SetEntProp(i_Ent[client], Prop_Send, "m_nSequence", GetEntProp(client, Prop_Send, "m_nSequence"));
	
	SetEntPropFloat(i_Ent[client], Prop_Send, "m_flPlaybackRate", GetEntPropFloat(client, Prop_Send, "m_flPlaybackRate"));
	SetEntProp(i_Ent[client], Prop_Send, "m_nSequence", GetEntProp(client, Prop_Send, "m_nSequence"));
	SetEntPropFloat(i_Ent[client], Prop_Send, "m_flPoseParameter", GetEntPropFloat(client, Prop_Send, "m_flPoseParameter", 0), 0);
	SetEntPropFloat(i_Ent[client], Prop_Send, "m_flCycle", GetEntPropFloat(client, Prop_Send, "m_flCycle"));
	for (new i = 1; i < 23; i++)SetEntPropFloat(i_Ent[client], Prop_Send, "m_flPoseParameter", GetEntPropFloat(client, Prop_Send, "m_flPoseParameter", i), i);
	
	if(!(GetEntityFlags(client) &1<<5))
	{
	float vPos[3];
	float vAng[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", vPos);
	GetEntPropVector(client, Prop_Send, "m_angRotation", vAng);
	TeleportEntity(i_Ent[client], NULL_VECTOR, vAng, NULL_VECTOR);
	}
}

public Action Hook_SetTransmit(int entity, int client)
{
	if( bSpecCheatActive[client] && GetClientTeam(client) == L4D_TEAM_SPECTATOR)
		return Plugin_Continue;
	
	return Plugin_Handled;
}

GetColor(Handle hCvar)
{
	decl String:sTemp[12];
	GetConVarString(hCvar, sTemp, sizeof(sTemp));
	
	if( StrEqual(sTemp, "") )
		return 0;

	decl String:sColors[3][4];
	new color = ExplodeString(sTemp, " ", sColors, 3, 4);

	if( color != 3 )
		return 0;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color;
}

public ConVarChanged_Glow( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
	g_iCvarColor = GetColor(g_hCvarColor);
}

public ConVarChanged_Glow_2( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
	g_iCvarColor2 = GetColor(g_hCvarColor2);
}

stock IsPlayerGhost(client)
{
	return GetEntProp(client, Prop_Send, "m_isGhost");
}