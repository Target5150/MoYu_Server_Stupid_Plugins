#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "2.0"

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
#define OFFSET_SAFEROOM "SaferoomPatch"
#define OFFSET_BRUSH_1 "BrushPatch1"
#define OFFSET_BRUSH_2 "BrushPatch2"

Address g_pSaferoomPatch, g_pBrushPatch1, g_pBrushPatch2;
bool g_bWindows;

ConVar g_hAllMaps, g_hAllEntities;
StringMap g_hSpitSpreadMaps;

void LoadSDK()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	Address pAddress = GameConfGetAddress(conf, PATCH_KEY);
	if (pAddress == Address_Null)
		SetFailState("Failed to get address of \"" ... PATCH_KEY ... "\"");
	
	int offset = GameConfGetOffset(conf, "OS");
	if (offset == -1)
		SetFailState("Failed to get offset \"OS\"");
		
	g_bWindows = !!offset;
	
	offset = GameConfGetOffset(conf, OFFSET_SAFEROOM);
	if (offset == -1)
		SetFailState("Failed to get offset from \"" ... OFFSET_SAFEROOM ... "\"");
	
	g_pSaferoomPatch = pAddress + view_as<Address>(offset);
	
	if (!g_bWindows)
	{
		offset = GameConfGetOffset(conf, OFFSET_BRUSH_1);
		if (offset == -1)
			SetFailState("Failed to get offset from \"" ... OFFSET_BRUSH_1 ... "\"");
		
		g_pBrushPatch1 = pAddress + view_as<Address>(offset);
	}
	
	offset = GameConfGetOffset(conf, OFFSET_BRUSH_2);
	if (offset == -1)
		SetFailState("Failed to get offset from \"" ... OFFSET_BRUSH_2 ... "\"");
	
	g_pBrushPatch2 = pAddress + view_as<Address>(offset);
	
	delete conf;
}

void ApplySaferoomPatch(bool patch)
{
	static const int PATCH_FALSE = 0x00;
	static const int UNPATCH_TRUE = 0x01;
	
	static bool patched = false;
	
	if (patch && !patched)
	{
		int byte = LoadFromAddress(g_pSaferoomPatch, NumberType_Int8);
		if (byte != UNPATCH_TRUE)
			SetFailState("Failed to apply patch \"" ... PATCH_KEY ... "\" (expecting 0x%x, got 0x%x)", UNPATCH_TRUE, byte);
		
		StoreToAddress(g_pSaferoomPatch, PATCH_FALSE, NumberType_Int8);
		patched = true;
	}
	else if (!patch && patched)
	{
		int byte = LoadFromAddress(g_pSaferoomPatch, NumberType_Int8);
		if (byte != PATCH_FALSE)
			SetFailState("Failed to remove patch \"" ... PATCH_KEY ... "\" (expecting 0x%x, got 0x%x)", PATCH_FALSE, byte);
		
		StoreToAddress(g_pSaferoomPatch, UNPATCH_TRUE, NumberType_Int8);
		patched = false;
	}
}

void ApplyBrushPatch(bool patch)
{
	static const int PATCH_BYTES[2] = {0x90, 0xE9};
	static const int UNPATCH1_BYTES[2] = {0x0F, 0x84};
	static const int UNPATCH2_BYTES[2] = {0x0F, 0x85};
	
	static bool patched = false;
	
	if (patch && !patched)
	{
		for (int i = 0; i < 2; i++)
		{
			int byte = LoadFromAddress(g_pBrushPatch2 + view_as<Address>(i), NumberType_Int8);
			if (byte != UNPATCH2_BYTES[i])
				SetFailState("Failed to apply patch \"" ... OFFSET_BRUSH_2 ... "\" (expecting 0x%x, got 0x%x)", UNPATCH2_BYTES[i], byte);
			
			StoreToAddress(g_pBrushPatch2 + view_as<Address>(i), PATCH_BYTES[i], NumberType_Int8);
			
			if (!g_bWindows)
			{
				byte = LoadFromAddress(g_pBrushPatch1 + view_as<Address>(i), NumberType_Int8);
				if (byte != UNPATCH1_BYTES[i])
					SetFailState("Failed to apply patch \"" ... OFFSET_BRUSH_1 ... "\" (expecting 0x%x, got 0x%x)", UNPATCH1_BYTES[i], byte);
				
				StoreToAddress(g_pBrushPatch1 + view_as<Address>(i), PATCH_BYTES[i], NumberType_Int8);
			}
			patched = true;
		}
	}
	else if (!patch && patched)
	{
		for (int i = 0; i < 2; i++)
		{
			int byte = LoadFromAddress(g_pBrushPatch2 + view_as<Address>(i), NumberType_Int8);
			if (byte != PATCH_BYTES[i])
				SetFailState("Failed to remove patch \"" ... OFFSET_BRUSH_2 ... "\" (expecting 0x%x, got 0x%x)", PATCH_BYTES[i], byte);
			
			StoreToAddress(g_pBrushPatch2 + view_as<Address>(i), UNPATCH2_BYTES[i], NumberType_Int8);
			
			if (!g_bWindows)
			{
				byte = LoadFromAddress(g_pBrushPatch1 + view_as<Address>(i), NumberType_Int8);
				if (byte != PATCH_BYTES[i])
					SetFailState("Failed to remove patch \"" ... OFFSET_BRUSH_1 ... "\" (expecting 0x%x, got 0x%x)", PATCH_BYTES[i], byte);
				
				StoreToAddress(g_pBrushPatch1 + view_as<Address>(i), UNPATCH1_BYTES[i], NumberType_Int8);
			}
			patched = true;
		}
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
				
	g_hAllEntities = CreateConVar(
					"cssc_all_entities",
					"0",
					"Modify projectile behavior to allow spit burst on non-world entities.",
					FCVAR_NOTIFY, true, 0.0, true, 1.0
				);
	
	g_hAllEntities.AddChangeHook(OnAllEntitiesChanged);
	ApplyBrushPatch(g_hAllEntities.BoolValue);
	
	g_hSpitSpreadMaps = new StringMap();
	
	RegServerCmd("saferoom_spit_spread", SetSaferoomSpitSpread);
}

public void OnPluginEnd()
{
	ApplySaferoomPatch(false);
}

public void OnAllEntitiesChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ApplyBrushPatch(g_hAllEntities.BoolValue);
}

public void OnMapStart()
{
	ApplySaferoomPatch(g_hAllMaps.BoolValue || IsSaferoomSpitSpreadMap());
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