#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"1.1.2"

#define OUR_COLOR {255, 255, 255}

bool bVision[MAXPLAYERS+1];
bool bTankAlive;

ArrayList g_ArrayHittableClones;
ArrayList g_ArrayHittables;

ConVar g_CvarGlowInfected;
ConVar g_CvarGlowSpectator;

enum L4D2GlowType 
{ 
	L4D2Glow_None = 0, 
	L4D2Glow_OnUse, 
	L4D2Glow_OnLookAt, 
	L4D2Glow_Constant 
}

enum L4D2_Team
{
    L4D2Team_Spectator = 1,
    L4D2Team_Survivor,
    L4D2Team_Infected
};

enum L4D2_Infected
{
	L4D2Infected_Smoker = 1,
    L4D2Infected_Boomer,
    L4D2Infected_Hunter,
    L4D2Infected_Spitter,
    L4D2Infected_Jockey,
    L4D2Infected_Charger,
    L4D2Infected_Witch,
    L4D2Infected_Tank
};

public Plugin myinfo = 
{
	name = "L4D2 Tank Hittable Glow",
	author = "Sir (Modified by Forgetest)",
	description = "This is such a big QoL Fix and is implemented so smoothly that people often think it's part of the game, why not load it in every config? :D",
	version = PLUGIN_VERSION,
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	// Setup Clone Array
	g_ArrayHittableClones = new ArrayList();
	g_ArrayHittables = new ArrayList();

	g_CvarGlowInfected = CreateConVar("ts_glow_infected", "0", "Show hittable glows to infected team");
	g_CvarGlowSpectator = CreateConVar("ts_glow_spectator", "1", "Show hittable glows to spectators");
	
	g_CvarGlowInfected.AddChangeHook(view_as<ConVarChanged>(OnConVarChanged));
	g_CvarGlowSpectator.AddChangeHook(view_as<ConVarChanged>(OnConVarChanged));
	
	// Hook First Tank
	HookEvent("tank_spawn", TankSpawnEvent);

	// Clear Vision, just in case.
	HookEvent("player_team", ClearVisionEvent);

	// Clean Arrays.
	HookEvent("tank_killed", view_as<EventHook>(ClearArrayEvent), EventHookMode_PostNoCopy);
	HookEvent("round_start", view_as<EventHook>(ClearArrayEvent), EventHookMode_PostNoCopy);
	HookEvent("round_end", view_as<EventHook>(ClearArrayEvent), EventHookMode_PostNoCopy);
}

public void OnPluginEnd() { KillClones(true); }


/**
 *  ConVar Change
 */
public void OnConVarChanged()
{
	if (bTankAlive) { KillClones(false); RecreateHittableClones(); }
}


/**
 *  Events
 */
public void ClearArrayEvent() { KillClones(true); }

public void ClearVisionEvent(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}
	
	if (bTankAlive)
	{
		// Reproduce glows to clear vision of transferred players
		RequestFrame(KillClones, false);
		RequestFrame(RecreateHittableClones);
	}
}

public void TankSpawnEvent(Event event, const char[] name, bool dontBroadcast)
{
	int tank = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsFakeClient(tank)) 
	{
		KillClones(true);
		return;
	}

	if (!bTankAlive)
	{
		HookProps();
		bTankAlive = true;
		bVision[tank] = true;
	}
}

public int L4D2_OnTankPassControl(int oldTank, int newTank, int passCount)
{
	KillClones(false);
	bVision[newTank] = true;
	if (!IsClientInGame(oldTank) || IsFakeClient(oldTank) || !GetConVarBool(g_CvarGlowInfected))
		bVision[oldTank] = false;

	if (bTankAlive) RecreateHittableClones();
}


/**
 *  Hittable Clone
 */
int CreateClone(int entity)
{
	float vOrigin[3];
	float vAngles[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles); 
	static char entityModel[64]; 
	GetEntPropString(entity, Prop_Data, "m_ModelName", entityModel, sizeof(entityModel)); 
	int clone=0;
	clone = CreateEntityByName("prop_dynamic_override"); //prop_dynamic
	SetEntityModel(clone, entityModel);
	DispatchSpawn(clone);

	TeleportEntity(clone, vOrigin, vAngles, NULL_VECTOR); 
	SetEntProp(clone, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(clone, Prop_Send, "m_nSolidType", 0);
	
	SetVariantString("!activator");
	AcceptEntityInput(clone, "SetParent", entity);

	return clone;
}

void RecreateHittableClones()
{
	int ArraySize = GetArraySize(g_ArrayHittables);
	if (ArraySize > 0)
	{
		for (int i = 0; i < ArraySize; i++)
		{
			int storedEntity = EntRefToEntIndex(GetArrayCell(g_ArrayHittables, i));
			if (IsValidEntity(storedEntity))
			{
				int clone = CreateClone(storedEntity);
				if (clone > 0)
				{
					PushArrayCell(g_ArrayHittableClones, clone);
					MakeEntityVisible(clone, false);
					SDKHook(clone, SDKHook_SetTransmit, CloneTransmit);
					L4D2_SetEntGlow(clone, L4D2Glow_Constant, 3250, 250, OUR_COLOR, false);
				}
			}
		}
	}
}

void KillClones(bool both)
{
	// 1. Loop through Array.
	// 2. Unhook Clones safely and then Kill them.
	// 3. Empty Array.
	int ArraySize = GetArraySize(g_ArrayHittableClones);
	for (int i = 0; i < ArraySize; i++)
	{
		int storedEntity = GetArrayCell(g_ArrayHittableClones, i);
		if (IsValidEntity(storedEntity))
		{
			SDKUnhook(storedEntity, SDKHook_SetTransmit, CloneTransmit);
			RemoveEntity(storedEntity);
		}
	}
	ClearArray(g_ArrayHittableClones);
	if (both)
	{
		ArraySize = GetArraySize(g_ArrayHittables);
		for (int i = 0; i < ArraySize; i++)
		{
			int storedEntity = EntRefToEntIndex(GetArrayCell(g_ArrayHittables, i));
			if (IsValidEntity(storedEntity))
			{
				SDKUnhook(storedEntity, SDKHook_OnTakeDamagePost, PropDamagedPost);
			}
		}
		
		ClearArray(g_ArrayHittables);
		bTankAlive = false;
		
		// Don't forget to remove the Hook.
		DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);
	}

	// 4. Reset bVision
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!bTankAlive || !IsClientInGame(i))
		{
			bVision[i] = false;
		}
		else if (!IsTank(i))
		{
			bVision[i] = CheckTeamVisionAccess(view_as<L4D2_Team>(GetClientTeam(i)));
		}
	}
}

public Action CloneTransmit(int entity, int client)
{
	if (bVision[client])
	{
		// Showing Clone
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

bool CheckTeamVisionAccess(L4D2_Team team)
{
	if (g_CvarGlowInfected.BoolValue && team == L4D2Team_Infected)
		return true;
	
	if (g_CvarGlowSpectator.BoolValue && team == L4D2Team_Spectator)
		return true;

	return false;
}


/**
 *  Hittable Management
 */
void HookProps()
{
	int iEntity = MaxClients+1;
	
	while ((iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1) 
	{
		if (IsValidEntity(iEntity) && GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1))
		{
        	SDKHook(iEntity, SDKHook_OnTakeDamagePost, PropDamagedPost);
		}
	}
	
	iEntity = MaxClients+1;
	
	while ((iEntity = FindEntityByClassname(iEntity, "prop_car_alarm")) != -1) 
	{
        SDKHook(iEntity, SDKHook_OnTakeDamagePost, PropDamagedPost);
	}
	
	// Hittables that spawn while the Tank is live, rather on having OnEntityCreated running all the time, we'll only use this hook while the Tank is alive.
	DHookAddEntityListener(ListenType_Created, PossibleTankPropCreated);
}

public void PossibleTankPropCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "prop_physics")) // Hooks onto c2m2_fairgrounds Forklift, c11m4_terminal World Sphere and Custom Campaign hittables.
    {
        // Use SpawnPost to just push it into the Array right away.
        // These entities get spawned after the Tank has punched them, so doing anything here will not work smoothly.
        SDKHook(entity, SDKHook_OnTakeDamagePost, PropDamagedPost);
    }
}

public void PropDamagedPost(int entity, int attacker, int inflictor, float damage, int damagetype)
{
	if (!bTankAlive) return;
	if (!IsValidEntity(entity)) return;
	if (!attacker
			|| attacker > MaxClients
			|| !IsClientInGame(attacker)
			|| !IsTank(attacker))
		return;
	
	if (GetEntProp(entity, Prop_Send, "m_hasTankGlow", 1)) // Just to be safe.
	{
		int entRef = EntIndexToEntRef(entity);
		if (FindValueInArray(g_ArrayHittables, entRef) == -1)
		{
			// Since the Tank has punch them to spawn, it should be paired with glow right away.
			PushArrayCell(g_ArrayHittables, entRef);
			
			// Reproduce glows to filter glows paired with entities out of existence.
			KillClones(false);
			RecreateHittableClones();
		}
	}
}


/**
 *  Stocks
 */
stock void MakeEntityVisible(int ent, bool visible=true)
{
	if(visible)
	{
		SetEntityRenderMode(ent, RENDER_NORMAL);
		SetEntityRenderColor(ent, 255, 255, 255, 255);
	}
	else
	{
		SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
		SetEntityRenderColor(ent, 0, 0, 0, 0);
	}
}

/**
 * Is the player the tank? 
 *
 * @param client client ID
 * @return bool
 */
stock bool IsTank(int client) {
    return view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Infected
        && GetInfectedClass(client) == L4D2Infected_Tank;
}

/**
 * Returns the ID of the client's infected class. Use GetInfectedClassName()
 * to convert it to a string.
 *
 * @param client client ID
 * @return class ID
 */
stock L4D2_Infected GetInfectedClass(int client) {
    return view_as<L4D2_Infected>(GetEntProp(client, Prop_Send, "m_zombieClass"));
}

/**
 * Is the tank able to punch the entity with the tank? 
 *
 * @param iEntity entity ID
 * @return bool
 */
stock bool IsTankHittable(int iEntity) {
	if (!IsValidEntity(iEntity)) {
		return false;
	}
	
	char className[64];
	
	GetEdictClassname(iEntity, className, sizeof(className));
	if ( StrEqual(className, "prop_physics") ) {
		if ( GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1) ) {
			return true;
		}
	}
	else if ( StrEqual(className, "prop_car_alarm") ) {
		return true;
	}
	
	return false;
}

/**
 * Set entity glow type.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_Type(int entity, L4D2GlowType type)
{
	SetEntProp(entity, Prop_Send, "m_iGlowType", view_as<int>(type));
}

/**
 * Set entity glow range.
 *
 * @param entity        Entity index.
 * @parma range            Glow range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_Range(int entity, int range)
{
	SetEntProp(entity, Prop_Send, "m_nGlowRange", range);
}

/**
 * Set entity glow min range.
 *
 * @param entity        Entity index.
 * @parma minRange        Glow min range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_MinRange(int entity, int minRange)
{
	SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", minRange);
}

/**
 * Set entity glow color.
 *
 * @param entity        Entity index.
 * @parma colorOverride    Glow color, RGB.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_ColorOverride(int entity, int colorOverride[3])
{
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", colorOverride[0] + (colorOverride[1] * 256) + (colorOverride[2] * 65536));
}

/**
 * Set entity glow flashing state.
 *
 * @param entity        Entity index.
 * @parma flashing        Whether glow will be flashing.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntGlow_Flashing(int entity, bool flashing)
{
	SetEntProp(entity, Prop_Send, "m_bFlashing", view_as<int>(flashing));
}

/**
 * Set entity glow. This is consider safer and more robust over setting each glow
 * property on their own because glow offset will be check first.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @param range            Glow max range, 0 for unlimited.
 * @param minRange        Glow min range.
 * @param colorOverride Glow color, RGB.
 * @param flashing        Whether the glow will be flashing.
 * @return                True if glow was set, false if entity does not support
 *                        glow.
 */
stock bool L4D2_SetEntGlow(int entity, L4D2GlowType type, int range, int minRange, int colorOverride[3], bool flashing)
{
	char netclass[128];
	GetEntityNetClass(entity, netclass, 128);

	int offset = FindSendPropInfo(netclass, "m_iGlowType");
	if (offset < 1)
	{
		return false;
	}

	L4D2_SetEntGlow_Type(entity, type);
	L4D2_SetEntGlow_Range(entity, range);
	L4D2_SetEntGlow_MinRange(entity, minRange);
	L4D2_SetEntGlow_ColorOverride(entity, colorOverride);
	L4D2_SetEntGlow_Flashing(entity, flashing);
	return true;
}

stock bool L4D2_SetEntGlowOverride(int entity, int colorOverride[3])
{
	char netclass[128];
	GetEntityNetClass(entity, netclass, 128);

	int offset = FindSendPropInfo(netclass, "m_iGlowType");
	if (offset < 1)
	{
		return false;
	}

	L4D2_SetEntGlow_ColorOverride(entity, colorOverride);
	return true;
}