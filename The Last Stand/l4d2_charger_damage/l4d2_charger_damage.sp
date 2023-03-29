#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D2] Charger Damage",
	author = "Forgetest",
	description = "Adds several convars to control over charge-related damages.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d2_charger_damage"
#define PATCH_OFFSET view_as<Address>(4)

MemoryPatch
	g_patch_OnSlammedSurvivor__advanced_damage,
	g_patch_OnSlammedSurvivor__normal_damage,
	g_patch_OnSlammedSurvivor__expert_damage,
	g_patch_ChargeImpactDistributor__damage;

public void OnPluginStart()
{
	GameData gd = new GameData(GAMEDATA_FILE);
	if (gd == null)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	g_patch_OnSlammedSurvivor__normal_damage = CreateEnabledPatch(gd, "CTerrorPlayer::OnSlammedSurvivor__normal_damage");
	g_patch_OnSlammedSurvivor__advanced_damage = CreateEnabledPatch(gd, "CTerrorPlayer::OnSlammedSurvivor__advanced_damage");
	g_patch_OnSlammedSurvivor__expert_damage = CreateEnabledPatch(gd, "CTerrorPlayer::OnSlammedSurvivor__expert_damage");
	g_patch_ChargeImpactDistributor__damage = CreateEnabledPatch(gd, "ChargeImpactDistributor::operator()__damage");
	
	delete gd;
	
	CreateConVarHook("z_charge_impact_dmg_normal",
					"10.0",
					"Amount of damage done by an end of charge.",
					FCVAR_CHEAT|FCVAR_SPONLY,
					true, 0.0, false, 0.0,
					CvarChg_OnSlammedSurvivor__normal_damage);
	
	CreateConVarHook("z_charge_impact_dmg_hard",
					"15.0",
					"Amount of damage done by an end of charge.",
					FCVAR_CHEAT|FCVAR_SPONLY,
					true, 0.0, false, 0.0,
					CvarChg_OnSlammedSurvivor__advanced_damage);
	
	CreateConVarHook("z_charge_impact_dmg_expert",
					"20.0",
					"Amount of damage done by an end of charge.",
					FCVAR_CHEAT|FCVAR_SPONLY,
					true, 0.0, false, 0.0,
					CvarChg_OnSlammedSurvivor__expert_damage);
	
	CreateConVarHook("z_charge_stumble_damage",
					"2.0",
					"Amount of damage done by an end of missing charge.",
					FCVAR_CHEAT|FCVAR_SPONLY,
					true, 0.0, false, 0.0,
					CvarChg_ChargeImpactDistributor__damage);
}

void CvarChg_OnSlammedSurvivor__normal_damage(ConVar convar, const char[] oldValue, const char[] newValue)
{
	static float s_flNewValue;
	
	s_flNewValue = convar.FloatValue;
	
	StoreToAddress(g_patch_OnSlammedSurvivor__normal_damage.Address + PATCH_OFFSET, GetAddressOfCell(s_flNewValue), NumberType_Int32);
}

void CvarChg_OnSlammedSurvivor__advanced_damage(ConVar convar, const char[] oldValue, const char[] newValue)
{
	static float s_flNewValue;
	
	s_flNewValue = convar.FloatValue;
	
	StoreToAddress(g_patch_OnSlammedSurvivor__advanced_damage.Address + PATCH_OFFSET, GetAddressOfCell(s_flNewValue), NumberType_Int32);
}

void CvarChg_OnSlammedSurvivor__expert_damage(ConVar convar, const char[] oldValue, const char[] newValue)
{
	static float s_flNewValue;
	
	s_flNewValue = convar.FloatValue;
	
	StoreToAddress(g_patch_OnSlammedSurvivor__expert_damage.Address + PATCH_OFFSET, GetAddressOfCell(s_flNewValue), NumberType_Int32);
}

void CvarChg_ChargeImpactDistributor__damage(ConVar convar, const char[] oldValue, const char[] newValue)
{
	static bool hasChecked = false;
	static bool isLinux = true;
	
	if (!hasChecked)
	{
		static const int bytes[3] = { 0xC7, 0x44, 0x24 };
		
		for (int i = 0; i < 3; ++i)
		{
			if (bytes[i] != LoadFromAddress(g_patch_ChargeImpactDistributor__damage.Address + view_as<Address>(i), NumberType_Int8))
			{
				isLinux = false;
				break;
			}
		}
		
		hasChecked = true;
	}
	
	static float s_flNewValue;
	
	s_flNewValue = convar.FloatValue;
	
	int data = isLinux ? view_as<int>(s_flNewValue) :  view_as<int>(GetAddressOfCell(s_flNewValue));
	StoreToAddress(g_patch_ChargeImpactDistributor__damage.Address + PATCH_OFFSET, data, NumberType_Int32);
}

MemoryPatch CreateEnabledPatch(GameData gd, const char[] name)
{
	MemoryPatch hPatch = MemoryPatch.CreateFromConf(gd, name);
	if (!hPatch.Enable())
		SetFailState("Failed to patch \"%s\"", name);
	
	return hPatch;
}

ConVar CreateConVarHook(const char[] name,
	const char[] defaultValue,
	const char[] description="",
	int flags=0,
	bool hasMin=false, float min=0.0,
	bool hasMax=false, float max=0.0,
	ConVarChanged callback)
{
	ConVar cv = CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
	
	Call_StartFunction(INVALID_HANDLE, callback);
	Call_PushCell(cv);
	Call_PushNullString();
	Call_PushNullString();
	Call_Finish();
	
	cv.AddChangeHook(callback);
	
	return cv;
}
