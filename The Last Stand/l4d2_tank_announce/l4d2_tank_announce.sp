#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2"

public Plugin myinfo = 
{
	name = "L4D2 Tank Announcer",
	author = "Visor, Forgetest",
	description = "Announce in chat and via a sound when a Tank has spawned",
	version = PLUGIN_VERSION,
	url = "https://github.com/Attano"
};

public void OnMapStart()
{
	PrecacheSound("ui/pickup_secret01.wav");
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
	if (IsFakeClient(tank_index)) // New Tank Spawned
	{
		CPrintToChatAll("{red}[{default}!{red}] {olive}Tank {default}has spawned!");
		EmitSoundToAll("ui/pickup_secret01.wav");
	}
	
	return Plugin_Continue;
}
