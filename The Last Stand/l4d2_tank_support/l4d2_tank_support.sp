#include <sourcemod>
#include <left4dhooks>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <l4d2lib>

new OUR_COLOR[3];
new bool:bVision[MAXPLAYERS + 1];
new bool:bTankAlive;

new Handle:g_ArrayHittableClones;
new Handle:g_ArrayHittables;

new Handle:g_CvarGlowInfected;
new Handle:g_CvarGlowSpectator;

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

public OnPluginStart()
{
	OUR_COLOR[0] = 255;
	OUR_COLOR[1] = 255;
	OUR_COLOR[2] = 255;
	// Setup Clone Array
	g_ArrayHittableClones = CreateArray(32);
	g_ArrayHittables = CreateArray(32);

	g_CvarGlowInfected = CreateConVar("ts_glow_infected", "0", "Show hittable glows to infected team");
	g_CvarGlowSpectator = CreateConVar("ts_glow_spectator", "1", "Show hittable glows to spectators");
	
	HookConVarChange(g_CvarGlowInfected, OnConVarChanged);
	HookConVarChange(g_CvarGlowSpectator, OnConVarChanged);
	
	// Hook First Tank
	HookEvent("tank_spawn", TankSpawnEvent);

	// Clear Vision, just in case.
	HookEvent("player_team", ClearVisionEvent);

	// Clean Arrays.
	HookEvent("tank_killed", ClearArrayEvent);
	HookEvent("round_start", ClearArrayEvent);
	HookEvent("round_end", ClearArrayEvent);
}

public OnPluginEnd() KillClones(true);

public ClearArrayEvent(Handle:event, const String:name[], bool:dontBroadcast) KillClones(true);

public ClearVisionEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsClientInGame(client))
	{
		if (bTankAlive) { RequestFrame(KillClones, false); RequestFrame(RecreateHittableClones); }
	}
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (bTankAlive) { KillClones(false); RecreateHittableClones(); }
}

public bool CheckTeamVisionAccess(L4D2_Team team)
{
	if (GetConVarBool(g_CvarGlowInfected) && team == L4D2Team_Infected) {
		return true;
	} else if (GetConVarBool(g_CvarGlowSpectator) && team == L4D2Team_Spectator) {
		return true;
	}
	return false;
}

public L4D2_OnTankPassControl(oldTank, newTank, passCount)
{
	KillClones(false);
	bVision[newTank] = true;
	if (!IsClientInGame(oldTank) || IsFakeClient(oldTank) || !GetConVarBool(g_CvarGlowInfected))
		bVision[oldTank] = false;

	if (bTankAlive) RecreateHittableClones();
}

public TankSpawnEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsFakeClient(tank)) 
	{
		KillClones(true);
		return;
	}

	if (!bTankAlive)
	{
		RequestFrame(HookProps);
		bTankAlive = true;
	}
}

public CreateClone(any:entity)
{
	decl Float:vOrigin[3];
	decl Float:vAngles[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles); 
	decl String:entityModel[64]; 
	GetEntPropString(entity, Prop_Data, "m_ModelName", entityModel, sizeof(entityModel)); 
	new clone=0;
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

public TankHittablePunched(const String:output[], caller, activator, Float:delay)
{
	new iEntity = EntIndexToEntRef(caller);
	new clone = CreateClone(iEntity);
	if (clone > 0)
	{
		PushArrayCell(g_ArrayHittableClones, clone);
		PushArrayCell(g_ArrayHittables, iEntity);
		MakeEntityVisible(clone, false);
		SDKHook(clone, SDKHook_SetTransmit, CloneTransmit);
		L4D2_SetEntGlow(clone, L4D2Glow_Constant, 3250, 250, OUR_COLOR, false);
	}
}

RecreateHittableClones(any dummy=0)
{
	new ArraySize = GetArraySize(g_ArrayHittables);
	if (ArraySize > 0)
	{
		for (new i = 0; i < ArraySize; i++)
		{
			new storedEntity = GetArrayCell(g_ArrayHittables, i);
			if (IsValidEntity(storedEntity))
			{
				new clone = CreateClone(storedEntity);
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

public Action:CloneTransmit(entity, client)
{
	if (bVision[client])
	{
		// Showing Clone
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

stock KillClones(bool:both)
{
	// 1. Loop through Array.
	// 2. Unhook Clones safely and then Kill them.
	// 3. Empty Array.
	new ArraySize = GetArraySize(g_ArrayHittableClones);
	for (new i = 0; i < ArraySize; i++)
	{
		new storedEntity = GetArrayCell(g_ArrayHittableClones, i);
		if (IsValidEntity(storedEntity))
		{
			SDKUnhook(storedEntity, SDKHook_SetTransmit, CloneTransmit);
			AcceptEntityInput(storedEntity, "Kill");
		}
	}
	ClearArray(g_ArrayHittableClones);
	if (both) { ClearArray(g_ArrayHittables); bTankAlive = false; }

	// 4. Reset bVision
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (!IsTank(i) || !bTankAlive))
		{
			bVision[i] = CheckTeamVisionAccess(L4D2_Team:GetClientTeam(i));
		}
	}
}

stock MakeEntityVisible(ent, bool:visible=true)
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

stock HookProps(any dummy)
{
	new iEntity = -1;
	 
	while ((iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1) 
	{
		if (IsTankHittable(iEntity)) 
		{
			HookSingleEntityOutput(iEntity, "OnHitByTank", TankHittablePunched, true);
		}
	}
	 
	iEntity = -1;
	 
	while ((iEntity = FindEntityByClassname(iEntity, "prop_car_alarm")) != -1) 
	{
		HookSingleEntityOutput(iEntity, "OnHitByTank", TankHittablePunched, true);
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
stock bool:IsTankHittable(iEntity) {
	if (!IsValidEntity(iEntity)) {
		return false;
	}
	
	decl String:className[64];
	
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
stock L4D2_SetEntGlow_Type(entity, L4D2GlowType:type)
{
	SetEntProp(entity, Prop_Send, "m_iGlowType", _:type);
}

/**
 * Set entity glow range.
 *
 * @param entity        Entity index.
 * @parma range            Glow range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
stock L4D2_SetEntGlow_Range(entity, range)
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
stock L4D2_SetEntGlow_MinRange(entity, minRange)
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
stock L4D2_SetEntGlow_ColorOverride(entity, colorOverride[3])
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
stock L4D2_SetEntGlow_Flashing(entity, bool:flashing)
{
	SetEntProp(entity, Prop_Send, "m_bFlashing", _:flashing);
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
stock bool:L4D2_SetEntGlow(entity, L4D2GlowType:type, range, minRange, colorOverride[3], bool:flashing)
{
	decl String:netclass[128];
	GetEntityNetClass(entity, netclass, 128);

	new offset = FindSendPropInfo(netclass, "m_iGlowType");
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

stock bool:L4D2_SetEntGlowOverride(entity, colorOverride[3])
{
	decl String:netclass[128];
	GetEntityNetClass(entity, netclass, 128);

	new offset = FindSendPropInfo(netclass, "m_iGlowType");
	if (offset < 1)
	{
		return false;    
	}

	L4D2_SetEntGlow_ColorOverride(entity, colorOverride);
	return true;
}