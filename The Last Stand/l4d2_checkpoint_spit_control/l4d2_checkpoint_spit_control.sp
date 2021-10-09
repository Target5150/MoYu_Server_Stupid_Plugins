#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <dhooks>

#define PLUGIN_VERSION "2.2"

public Plugin myinfo =
{
	name = "[L4D2] Checkpoint Spit Spread Control",
	author = "Forgetest",
	description = "Allow spit to spread in saferoom",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d2_checkpoint_spit_control"
#define KEY_DETONATE "CSpitterProjectile_Detonate"
#define KEY_BOUNCETOUCH "CSpitterProjectile_BounceTouch"

#define PATCH_SAFEROOM "SaferoomPatch"
#define PATCH_BRUSH_1 "BrushPatch1"
#define PATCH_BRUSH_2 "BrushPatch2"
#define PATCH_BRUSH_3 "BrushPatch3"

MemoryPatch g_hSaferoomPatch, g_hBrushPatch1, g_hBrushPatch2, g_hBrushPatch3;
bool g_bLinux;

DynamicDetour g_hDetour_Detonate, g_hDetour_BounceTouch;

ConVar g_hAllMaps, g_hAllEntities;
StringMap g_hSpitSpreadMaps;

void LoadSDK()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
	
	int offset = GameConfGetOffset(conf, "OS");
	if (offset == -1)
		SetFailState("Failed to get offset \"OS\"");
		
	g_bLinux = !offset;
	
	g_hSaferoomPatch = MemoryPatch.CreateFromConf(conf, PATCH_SAFEROOM);
	if (!g_hSaferoomPatch || !g_hSaferoomPatch.Validate())
		SetFailState("Failed to validate patch \"" ... PATCH_SAFEROOM ... "\"");
	
	if (g_bLinux)
	{
		g_hBrushPatch1 = MemoryPatch.CreateFromConf(conf, PATCH_BRUSH_1);
		if (!g_hBrushPatch1 || !g_hBrushPatch1.Validate())
			SetFailState("Failed to validate patch \"" ... PATCH_BRUSH_1 ... "\"");
	}
	
	g_hBrushPatch2 = MemoryPatch.CreateFromConf(conf, PATCH_BRUSH_2);
	if (!g_hBrushPatch2 || !g_hBrushPatch2.Validate())
		SetFailState("Failed to validate patch \"" ... PATCH_BRUSH_2 ... "\"");
	
	g_hBrushPatch3 = MemoryPatch.CreateFromConf(conf, PATCH_BRUSH_2);
	if (!g_hBrushPatch3 || !g_hBrushPatch3.Validate())
		SetFailState("Failed to validate patch \"" ... PATCH_BRUSH_2 ... "\"");
	
	SetupDetour(conf);
	
	delete conf;
}

void SetupDetour(Handle conf)
{
	g_hDetour_Detonate = DynamicDetour.FromConf(conf, KEY_DETONATE);
	if (g_hDetour_Detonate == null)
		SetFailState("Missing detour setup \"" ... KEY_DETONATE ... "\"");
	
	g_hDetour_BounceTouch = DynamicDetour.FromConf(conf, KEY_BOUNCETOUCH);
	if (g_hDetour_BounceTouch == null)
		SetFailState("Missing detour setup \"" ... KEY_BOUNCETOUCH ... "\"");
}

void ApplySaferoomPatch(bool patch)
{
	static bool patched = false;
	
	if (patch && !patched)
	{
		if (!g_hSaferoomPatch.Enable())
			SetFailState("Failed to apply patch \"" ... PATCH_SAFEROOM ... "\"");
		
		patched = true;
	}
	else if (!patch && patched)
	{
		g_hSaferoomPatch.Disable();
		patched = false;
	}
}

void ApplyBrushPatch(bool patch)
{
	static bool patched = false;
	
	if (patch && !patched)
	{
		if (g_bLinux && !g_hBrushPatch1.Enable())
			SetFailState("Failed to apply patch \"" ... PATCH_BRUSH_1 ... "\"");
		
		if (!g_hBrushPatch2.Enable())
			SetFailState("Failed to apply patch \"" ... PATCH_BRUSH_2 ... "\"");
		
		if (!g_hBrushPatch3.Enable())
			SetFailState("Failed to apply patch \"" ... PATCH_BRUSH_2 ... "\"");
		
		patched = true;
	}
	else if (!patch && patched)
	{
		if (g_bLinux) g_hBrushPatch1.Disable();
		g_hBrushPatch2.Disable();
		g_hBrushPatch3.Disable();
		patched = false;
	}
}

void ToggleDetour(bool enable)
{
	static bool enabled = false;
	if (enable && !enabled)
	{
		if (!g_hDetour_BounceTouch.Enable(Hook_Pre, OnSpitProjectileBounceTouch))
			SetFailState("Failed to enable pre-detour \"" ... KEY_BOUNCETOUCH ... "\"");
		
		if (!g_hDetour_BounceTouch.Enable(Hook_Post, OnSpitProjectileBounceTouch_Post))
			SetFailState("Failed to enable post-detour \"" ... KEY_BOUNCETOUCH ... "\"");
		
		if (!g_hDetour_Detonate.Enable(Hook_Pre, OnSpitProjectileDetonate))
			SetFailState("Failed to enable pre-detour \"" ... KEY_DETONATE ... "\"");
		
		if (!g_hDetour_Detonate.Enable(Hook_Post, OnSpitProjectileDetonate_Post))
			SetFailState("Failed to enable post-detour \"" ... KEY_DETONATE ... "\"");
		
		enabled = true;
	}
	else if (!enable && enabled)
	{
		if (!g_hDetour_BounceTouch.Disable(Hook_Pre, OnSpitProjectileBounceTouch))
			SetFailState("Failed to enable pre-detour \"" ... KEY_BOUNCETOUCH ... "\"");
		
		if (!g_hDetour_BounceTouch.Disable(Hook_Post, OnSpitProjectileBounceTouch_Post))
			SetFailState("Failed to enable post-detour \"" ... KEY_BOUNCETOUCH ... "\"");
		
		if (!g_hDetour_Detonate.Disable(Hook_Pre, OnSpitProjectileDetonate))
			SetFailState("Failed to disable pre-detour \"" ... KEY_DETONATE ... "\"");
		
		if (!g_hDetour_Detonate.Disable(Hook_Post, OnSpitProjectileDetonate_Post))
			SetFailState("Failed to disable post-detour \"" ... KEY_DETONATE ... "\"");
		
		enabled = false;
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
	ToggleDetour(g_hAllEntities.BoolValue);
	
	g_hSpitSpreadMaps = new StringMap();
	
	RegServerCmd("saferoom_spit_spread", SetSaferoomSpitSpread);
}

public void OnPluginEnd()
{
	ApplySaferoomPatch(false);
	ApplyBrushPatch(false);
}

public void OnAllEntitiesChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ToggleDetour(g_hAllEntities.BoolValue);
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

int g_iProjectileLastTouch = 0;

public MRESReturn OnSpitProjectileBounceTouch(int pThis, DHookParam hParams)
{
	g_iProjectileLastTouch = hParams.Get(1);
	//static char buffer[64];
	//GetEntityClassname(g_iProjectileLastTouch, buffer, 64);
	//PrintToChatAll("BounceTouch: %s (#%i)", buffer, g_iProjectileLastTouch);
}

public MRESReturn OnSpitProjectileBounceTouch_Post(int pThis, DHookParam hParams)
{
	g_iProjectileLastTouch = 0;
}

public MRESReturn OnSpitProjectileDetonate(int pThis)
{
	//static char buffer[64];
	//GetEntityClassname(g_iProjectileLastTouch, buffer, 64);
	//PrintToChatAll("Detonate: %s (#%i)", buffer, g_iProjectileLastTouch);
	
	if (IsValidEntity(g_iProjectileLastTouch) && g_iProjectileLastTouch > MaxClients)
	{
		if (IsValidForSpitBurst(g_iProjectileLastTouch))
		{
			//PrintToChatAll("\x04Detonate: IsValidForSpitBurst (%s)", buffer);
			ApplyBrushPatch(true);
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn OnSpitProjectileDetonate_Post(int pThis)
{
	ApplyBrushPatch(false);
}

bool IsValidForSpitBurst(int entity)
{
	//static char clsname[64];
	return Entity_IsSolid(entity)/* && GetEntityClassname(entity, clsname, sizeof clsname) && strncmp(clsname, "func_breakable", 14) != 0*/;
}

stock bool IsAnySpitterAlive()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 4 && IsPlayerAlive(i))
			return true;
	}
	return false;
}

// https://forums.alliedmods.net/showthread.php?t=147732
#define SOLID_NONE 0
#define FSOLID_NOT_SOLID 0x0004
/**
 * Checks whether the entity is solid or not.
 *
 * @param entity            Entity index.
 * @return                    True if the entity is solid, false otherwise.
 */
stock bool Entity_IsSolid(int entity)
{
    return (GetEntProp(entity, Prop_Send, "m_nSolidType", 1) != SOLID_NONE &&
            !(GetEntProp(entity, Prop_Send, "m_usSolidFlags", 2) & FSOLID_NOT_SOLID));
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