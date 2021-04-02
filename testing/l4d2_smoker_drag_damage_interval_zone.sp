#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

ConVar g_cDragInterval, g_cFirstInterval, g_cFirstDamage;
float g_fDragInterval, g_fFirstInterval, g_fFirstDamage;

public Plugin myinfo =
{
	name = "L4D2 Smoker Drag Damage Interval",
	author = "Visor, Sir",
	description = "Implements a native-like cvar that should've been there out of the box",
	version = "0.8",
	url = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart()
{
	HookEvent("tongue_grab", OnTongueGrab);

	char value[8];
	GetConVarString(FindConVar("tongue_choke_damage_interval"), value, sizeof(value));
	g_cDragInterval = CreateConVar("tongue_drag_damage_interval", value, "How often the drag does damage.");
	g_cFirstInterval = CreateConVar("tongue_drag_first_damage_interval", "0.0", "After how many seconds do we apply our first tick of damage? | 0.0 to Disable.");
	g_cFirstDamage = CreateConVar("tongue_drag_first_damage", "3.0", "How much damage do we apply on the first tongue hit? | Only applies when first_damage_interval is used");

	HookConVarChange(FindConVar("tongue_choke_damage_amount"), tongue_choke_damage_amount_ValueChanged);
}

public void OnConfigsExecuted()
{
	g_fDragInterval = g_cDragInterval.FloatValue;
	g_fFirstInterval = g_cFirstInterval.FloatValue;
	g_fFirstDamage = g_cFirstDamage.FloatValue;
}

public void tongue_choke_damage_amount_ValueChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetConVarInt(convar, 1); // hack-hack: game tries to change this cvar for some reason, can't be arsed so HARDCODETHATSHIT
}

public void OnTongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "victim"));
	
	if (g_fFirstInterval > 0.0)
	{
		UpdateDragDamageInterval(client, g_fFirstInterval);
		CreateTimer(g_fFirstInterval, FirstDamage, client);
	}
	else
	{
		UpdateDragDamageInterval(client, g_fDragInterval);
		
		CreateTimer(
				g_fDragInterval + 0.1, 
				FixDragInterval, 
				client, 
				TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE
		);
	}
}

public Action FirstDamage(Handle timer, int client)
{
	if (!IsSurvivor(client) || !IsSurvivorBeingDragged(client))
	{
		return;
	}

	for (int i = 1; i < MaxClients + 1; i++)
	{
		if (IsTongue(i))
		{
			SDKHooks_TakeDamage(client, i, i, g_fFirstDamage - 1.0, DMG_ACID);
			break;
		}
	}

	UpdateDragDamageInterval(client, g_fDragInterval + 0.1);
}

public Action FixDragInterval(Handle timer, int client)
{
	if (!IsSurvivor(client) || !IsSurvivorBeingDragged(client))
	{
		return Plugin_Stop;
	}

	UpdateDragDamageInterval(client, g_fDragInterval);
	return Plugin_Continue;
}

void UpdateDragDamageInterval(int client, float val)
{
	SetEntDataFloat(client, 13352, (GetGameTime() + val));
}

bool IsSurvivorBeingDragged(int client)
{
	return ((GetEntData(client, 13284) > 0) && !IsSurvivorBeingChoked(client));
}

bool IsSurvivorBeingChoked(int client)
{
	return (GetEntData(client, 13308) > 0);
}

bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

bool IsTongue(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0);
}