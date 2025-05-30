#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include "include/l4d_heal_overtime.inc"

#define PLUGIN_VERSION "2.6.1"

public Plugin myinfo = 
{
    name = "L4D HOTs",
    author = "ProdigySim, CircleSquared, Forgetest",
    description = "Kit, Pills and Adrenaline heal over time",
    version = PLUGIN_VERSION,
    url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

ConVar
	hCvarKitHot,
	hCvarKitInterval,
	hCvarKitIncrement,
	hCvarKitSelfAmount,
	hCvarKitMateAmount,
	hCvarKitType;

ConVar
	hCvarPillHot,
	hCvarPillInterval,
	hCvarPillIncrement,
	hCvarPillTotal,
	pain_pills_health_value;

ConVar
	hCvarAdrenHot,
	hCvarAdrenInterval,
	hCvarAdrenIncrement,
	hCvarAdrenTotal,
	adrenaline_health_buffer;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	hCvarKitHot =			CreateConVar("l4d_kit_hot",					"0",	"kit heal over time",						FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	hCvarKitInterval =		CreateConVar("l4d_kit_hot_interval",		"1.0",	"Interval for kit hot",						FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.00001);
	hCvarKitIncrement =		CreateConVar("l4d_kit_hot_increment",		"10",	"Increment amount for kit hot",				FCVAR_NOTIFY|FCVAR_SPONLY, true, 1.0);
	hCvarKitSelfAmount =	CreateConVar("l4d_kit_hot_amount_self",		"80",	"HP amount/percent for self kit hot",		FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0);
	hCvarKitMateAmount =	CreateConVar("l4d_kit_hot_amount_teammate",	"60",	"HP amount/percent for teammate kit hot",	FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0);
	hCvarKitType = CreateConVar(
		"l4d_kit_hot_type",
		"1",
		"Type of kit amount.\n0 = Vanilla, 1 = Fixed amount, 2 = Max health percent",
		FCVAR_NOTIFY|FCVAR_SPONLY,
		true, 0.0);
	
	CvarChg_KitHot(hCvarKitHot, "", "");
	hCvarKitHot.AddChangeHook(CvarChg_KitHot);
	
	char buffer[16];
	pain_pills_health_value = FindConVar("pain_pills_health_value");
	pain_pills_health_value.GetString(buffer, sizeof(buffer));
	
	hCvarPillHot =			CreateConVar("l4d_pills_hot",				"0",	"Pills heal over time",				FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	hCvarPillInterval =		CreateConVar("l4d_pills_hot_interval",		"1.0",	"Interval for pills hot",			FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.00001);
	hCvarPillIncrement =	CreateConVar("l4d_pills_hot_increment",		"10",	"Increment amount for pills hot",	FCVAR_NOTIFY|FCVAR_SPONLY, true, 1.0);
	hCvarPillTotal =		CreateConVar("l4d_pills_hot_total",			buffer,	"Total amount for pills hot",		FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0);
	
	CvarChg_PillHot(hCvarPillHot, "", "");
	hCvarPillHot.AddChangeHook(CvarChg_PillHot);
	
	if (GetEngineVersion() == Engine_Left4Dead2)
	{
		adrenaline_health_buffer = FindConVar("adrenaline_health_buffer");
		adrenaline_health_buffer.GetString(buffer, sizeof(buffer));
		
		hCvarAdrenHot = 		CreateConVar("l4d_adrenaline_hot",				"0",	"Adrenaline heals over time",			FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
		hCvarAdrenInterval =	CreateConVar("l4d_adrenaline_hot_interval",		"1.0",	"Interval for adrenaline hot",			FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.00001);
		hCvarAdrenIncrement =	CreateConVar("l4d_adrenaline_hot_increment",	"15",	"Increment amount for adrenaline hot",	FCVAR_NOTIFY|FCVAR_SPONLY, true, 1.0);
		hCvarAdrenTotal =		CreateConVar("l4d_adrenaline_hot_total",		buffer,	"Total amount for adrenaline hot",		FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0);
		
		CvarChg_AdrenHot(hCvarAdrenHot, "", "");
		hCvarAdrenHot.AddChangeHook(CvarChg_AdrenHot);
	}

	AutoExecConfig(true, "l4dhots");
}

public void OnPluginEnd()
{
	ToggleKitHot(false);
	TogglePillHot(false);
	ToggleAdrenHot(false);
}

void HealSuccess_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int target = GetClientOfUserId(event.GetInt("subject"));
	if (!client || !IsClientInGame(client) || !target || !IsClientInGame(target))
		return;
	
	// Calculate target HP according to the type
	int maxHealth = GetEntProp(target, Prop_Data, "m_iMaxHealth");
	int type = hCvarKitType.IntValue;
	int health_restored = event.GetInt("health_restored");

	if (type > 0) // Non-Vanilla
	{
		// Restore the health before heal
		SetEntProp(target, Prop_Send, "m_iHealth", GetClientHealth(target) - health_restored);
	}

	ConVar cvAmount = (client == target ? hCvarKitSelfAmount : hCvarKitMateAmount);
	if (type == 1) // Fixed amount
	{
		health_restored = cvAmount.IntValue;
	}
	else if (type == 2) // Max health percent
	{
		health_restored = RoundToNearest( float(maxHealth) * cvAmount.FloatValue );
	}

	L4D_HealPlayerOverTime(
		target,
		hCvarKitInterval.FloatValue,
		hCvarKitIncrement.IntValue,
		health_restored,
		.maxHealth = maxHealth,
		.type = Heal_PermHealth,
		.immediate = true
	);
}

void PillsUsed_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	L4D_HealPlayerOverTime(
		client,
		hCvarPillInterval.FloatValue,
		hCvarPillIncrement.IntValue,
		hCvarPillTotal.IntValue,
		.type = Heal_TempHealth,
		.immediate = true
	);
}

void AdrenalineUsed_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	L4D_HealPlayerOverTime(
		client,
		hCvarAdrenInterval.FloatValue,
		hCvarAdrenIncrement.IntValue,
		hCvarAdrenTotal.IntValue,
		.type = Heal_TempHealth,
		.immediate = true
	);
}


/**
 * ConVar Change
 */
void CvarChg_KitHot(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ToggleKitHot(hCvarKitHot.BoolValue);
}

void CvarChg_PillHot(ConVar convar, const char[] oldValue, const char[] newValue)
{
	TogglePillHot(hCvarPillHot.BoolValue);
}

void CvarChg_AdrenHot(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ToggleAdrenHot(hCvarAdrenHot.BoolValue);
}

void ToggleKitHot(bool enable)
{
	static bool enabled = false;
	
	if (enable && !enabled)
	{
		HookEvent("heal_success", HealSuccess_Event, EventHookMode_Pre);
		
		enabled = true;
	}
	else if (!enable && enabled)
	{
		UnhookEvent("heal_success", HealSuccess_Event, EventHookMode_Pre);
		
		enabled = false;
	}
}

void TogglePillHot(bool enable)
{
	static bool enabled = false;
	static int origValue;
	
	if (enable && !enabled)
	{
		pain_pills_health_value.Flags &= ~FCVAR_REPLICATED;
		origValue = pain_pills_health_value.IntValue;
		pain_pills_health_value.IntValue = 0;
		
		HookEvent("pills_used", PillsUsed_Event, EventHookMode_Pre);
		
		enabled = true;
	}
	else if (!enable && enabled)
	{
		pain_pills_health_value.Flags &= FCVAR_REPLICATED;
		pain_pills_health_value.IntValue = origValue;
		
		UnhookEvent("pills_used", PillsUsed_Event, EventHookMode_Pre);
		
		enabled = false;
	}
}

void ToggleAdrenHot(bool enable)
{
	static bool enabled = false;
	static int origValue;
	
	if (enable && !enabled)
	{
		adrenaline_health_buffer.Flags &= ~FCVAR_REPLICATED;
		origValue = adrenaline_health_buffer.IntValue;
		adrenaline_health_buffer.IntValue = 0;
		
		HookEvent("adrenaline_used", AdrenalineUsed_Event, EventHookMode_Pre);
		
		enabled = true;
	}
	else if (!enable && enabled)
	{
		adrenaline_health_buffer.Flags &= FCVAR_REPLICATED;
		adrenaline_health_buffer.IntValue = origValue;
		
		UnhookEvent("adrenaline_used", AdrenalineUsed_Event, EventHookMode_Pre);
		
		enabled = false;
	}
}