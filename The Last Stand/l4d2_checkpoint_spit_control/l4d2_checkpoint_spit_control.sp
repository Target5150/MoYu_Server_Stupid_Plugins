#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D2] Checkpoint Spit Spread Control",
	author = "Forgetest",
	description = "Allow spit to spread in saferoom",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d2_checkpoint_spit_control"
#define PATCH_KEY "CSpitterProjectile_Detonate"

Address g_pAddress;

ConVar g_hAllMaps;
StringMap g_hSpitSpreadMaps;

void LoadSDK()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	g_pAddress = GameConfGetAddress(conf, PATCH_KEY);
	if (g_pAddress == Address_Null)
		SetFailState("Failed to get address of \"" ... PATCH_KEY ... "\"");
		
	int offset = GameConfGetOffset(conf, "PatchOffset");
	if (offset == -1)
		SetFailState("Failed to get offset from \"PatchOffset\"");
	
	g_pAddress += view_as<Address>(offset);
	delete conf;
}

void ApplyPatch(bool patch)
{
	static const int PATCH_FALSE = 0x00;
	static const int UNPATCH_TRUE = 0x01;
	
	static bool patched = false;
	
	if (patch && !patched)
	{
		int byte = LoadFromAddress(g_pAddress, NumberType_Int8);
		if (byte != UNPATCH_TRUE)
			SetFailState("Failed to apply patch \"" ... PATCH_KEY ... "\" (expecting 0x%x, got 0x%x)", UNPATCH_TRUE, byte);
		
		StoreToAddress(g_pAddress, PATCH_FALSE, NumberType_Int8);
		patched = true;
	}
	else if (!patch && patched)
	{
		int byte = LoadFromAddress(g_pAddress, NumberType_Int8);
		if (byte != PATCH_FALSE)
			SetFailState("Failed to remove patch \"" ... PATCH_KEY ... "\" (expecting 0x%x, got 0x%x)", PATCH_FALSE, byte);
		
		StoreToAddress(g_pAddress, UNPATCH_TRUE, NumberType_Int8);
		patched = false;
	}
}

public void OnPluginStart()
{
	LoadSDK();
	
	g_hAllMaps = CreateConVar(
					"cssc_global",
					"0",
					"Remove saferoom spit-spread preservation mechanic on all maps by default.",
					FCVAR_NOTIFY, true, 0.0, true, 1.0
				);
	
	g_hSpitSpreadMaps = new StringMap();
	
	RegServerCmd("saferoom_spit_spread", SetSaferoomSpitSpread);
}

public void OnPluginEnd()
{
	ApplyPatch(false);
}

public void OnMapStart()
{
	ApplyPatch(g_hAllMaps.BoolValue || IsSaferoomSpitSpreadMap());
}

bool IsSaferoomSpitSpreadMap()
{
	if (!g_hSpitSpreadMaps.Size) return false;
	
	char map[128];
	GetCurrentMapLower(map, sizeof map);
	bool dummy;
	return g_hSpitSpreadMaps.GetValue(map, dummy);
}

public Action SetSaferoomSpitSpread(int args)
{
	char map[128];
	GetCmdArg(1, map, sizeof map);
	String_ToLower(map);
	g_hSpitSpreadMaps.SetValue(map, true, false);
}

stock int GetCurrentMapLower(char[] buffer, int maxlength)
{
	int bytes = GetCurrentMap(buffer, maxlength);
	String_ToLower(buffer);
	return bytes;
}

stock void String_ToLower(char[] buffer)
{
	int len = strlen(buffer);
	for (int i = 0; i < len; ++i) buffer[i] = CharToLower(buffer[i]);
}