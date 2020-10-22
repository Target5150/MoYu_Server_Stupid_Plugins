#include <sourcemod>
#include <sdktools>
#include <colors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.4.2"

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define ABS(%0) (((%0) < 0) ? -(%0) : (%0))

bool NoSpam[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "No spawn near safe room door.",
	author = "Eyal282 ( FuckTheSchool ), Forgetest",
	description = "To prevent a player breaching safe room door with a bug, prevents him from spawning near safe room door. The minimum distance is proportionate to his speed ",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2520740"
}

ConVar	hAntiBreachConVar;
int		AntiBreachConVar;

bool bDetectAvailable;

// ADT Array is used instead of using a single integer.
// In this way, we secures players from being exploit upon if the end saferoom have multiple doors of entrance, exit etc.
ArrayList aSaferoomDoors;

// [l4d2_saferoom_detect.smx]
native bool SAFEDETECT_IsEntityInStartSaferoom(int entity);

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Prevents loading errors if based plugin is not already running.
	MarkNativeAsOptional("SAFEDETECT_IsEntityInStartSaferoom");
}

public void OnPluginStart()
{
	// The cvar to enable the plugin. 0 = Disabled. Other values = Enabled.
	hAntiBreachConVar = CreateConVar("l4d2_anti_breach", "1", "The cvar to enable the plugin. 0 = Disabled. Other values = Enabled.");
	
	// To prevent waste of resources, hook the change of the console variable AntiBreach
	HookConVarChange(hAntiBreachConVar, AntiBreachConVarChange);
	
	// Save the current value of l4d2_anti_breach in a variable. Main reason is to avoid wasting resources.
	AntiBreachConVar = GetConVarInt(hAntiBreachConVar);
	
	aSaferoomDoors = new ArrayList();

	HookEvent("round_start", view_as<EventHook>(RoundStartEvent), EventHookMode_PostNoCopy);
}

public void OnAllPluginsLoaded() { bDetectAvailable = LibraryExists("saferoom_detect"); }
public void OnLibraryAdded(const char[] name) { if (StrEqual(name, "saferoom_detect"))bDetectAvailable = true; }
public void OnLibraryRemoved(const char[] name) { if (StrEqual(name, "saferoom_detect"))bDetectAvailable = false; }

public void RoundStartEvent()
{
	// Use a delay function to prevent issues
	CreateTimer(12.0, DelayRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action DelayRoundStart(Handle timer)
{
	if (!bDetectAvailable) return;
	
	aSaferoomDoors.Clear();
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != -1)
	{
		// Checking whether a door is around end saferoom seems not as accurate as expected
		// So I try reversing the way to judge
		if (SAFEDETECT_IsEntityInStartSaferoom(entity)) continue;
		
		// Reference for safety
		aSaferoomDoors.Push(EntIndexToEntRef(entity));
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	// Cvar is disabled, aborting.
	if(AntiBreachConVar == 0 || !bDetectAvailable)
		return Plugin_Continue;

	// Player is not attacking and no safe room door closed.
	if(!(buttons & IN_ATTACK))
		return Plugin_Continue;
	
	// Player is either a bot, not infected or not a ghost.
	else if(GetClientTeam(client) != 3 || IsFakeClient(client) || GetEntProp(client, Prop_Send, "m_isGhost") != 1)
		return Plugin_Continue;

	// Being a ghost, the player can not spawn ( seen / close / blocked etc... )
	else if(GetEntProp(client, Prop_Send, "m_ghostSpawnState") != 0)
		return Plugin_Continue;
	
	// Loops through all checkpoint doors stored in array
	for (int i = 0; i < aSaferoomDoors.Length; ++i)
	{
		int door = EntRefToEntIndex(aSaferoomDoors.Get(i));
		if (!IsValidEntity(door) || !IsValidEdict(door)) continue; // probably won't happen
		
		
		/**	https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/server/BasePropDoor.h#L80
		 *
		 *	enum DoorState_t
		 *	{
		 *		DOOR_STATE_CLOSED = 0,
		 *		DOOR_STATE_OPENING,
		 *		DOOR_STATE_OPEN,
		 *		DOOR_STATE_CLOSING,
		 *		DOOR_STATE_AJAR,
		 *	};
		 */
		if (GetEntProp(door, Prop_Send, "m_eDoorState") == 0) // DOOR_STATE_CLOSED
		{
			float clientOrigin[3], doorOrigin[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientOrigin);
			GetEntPropVector(door, Prop_Send, "m_vecOrigin", doorOrigin);
			
			// Calculates the distance between client and the door
			float fDistance = GetVectorDistance(clientOrigin, doorOrigin);
			
			// Player isn't close enough to the door
			// Go next :)
			if (fDistance > 96.0) continue;
			
			float clientVelocity[3], clientAngles[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", clientVelocity);
			GetEntPropVector(client, Prop_Data, "m_angRotation", clientAngles);
			
			// Angles of moving forward(backward) and rightward(leftward)
			float vecFwd[3], vecRight[3];
			GetAngleVectors(clientAngles, vecFwd, vecRight, NULL_VECTOR);
			
			float clientDist[3], vecAngles[3];
			SubtractVectors(doorOrigin, clientOrigin, clientDist); // Vector starts at client, ends at door
			GetVectorAngles(clientDist, vecAngles);
			
			// Normalization to simplify calculations
			NormalizeVector(vecAngles, vecAngles);
			NormalizeVector(vecFwd, vecFwd);
			NormalizeVector(vecRight, vecRight);
			
			// cos<v1,v2> = DotProduct(v1, v2) / Length(v1) / Length(v2)
			// Length of any normalized vector is ~1
			// Calculates cosine of the angle between the velocity direction and the distance direction
			float cosine = MAX(ABS(GetVectorDotProduct(vecAngles, vecFwd)), ABS(GetVectorDotProduct(vecAngles, vecRight)));
			
			float fSpeed = GetVectorLength(clientVelocity); // Where client will be in the next frame
			
			// Player is close enough and has too much speed vs distance from door.
			if(fDistance < fSpeed * cosine)
			{
				if(!NoSpam[client])
				{
					CPrintToChatAll("{red}[{default}Exploit{red}] {olive}%N {default}tried to spawn near end saferoom door{default}.", client);
					CPrintToChat(client, "{red}[{default}Exploit{red}] {green}You can't spawn near end saferoom doors{default}.");
					NoSpam[client] = true;
					CreateTimer(2.5, AllowMessageAgain, client);
				}
				buttons &= ~IN_ATTACK;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action AllowMessageAgain(Handle timer, int client)
{
	NoSpam[client] = false;
}

public void OnClientPutInServer(int client)
{
	NoSpam[client] = false;
}

public void AntiBreachConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	AntiBreachConVar = GetConVarInt(convar);
}

