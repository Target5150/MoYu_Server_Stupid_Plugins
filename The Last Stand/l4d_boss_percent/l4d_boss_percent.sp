/*

This version of Boss Percents was designed to work with my custom Ready Up plugin. 
It's designed so when boss percentages are changed, it will edit the already existing
Ready Up footer, rather then endlessly stacking them ontop of one another.

It was also created so that my Witch Toggler plugin can properly display if the witch is disabled 
or not on both the ready up menu aswell as when using the !boss commands.

I tried my best to comment everything so it can be very easy to understand what's going on. Just in case you want to 
do some personalization for your server or config. It will also come in handy if somebody finds a bug and I need to figure
out what's going on :D Kinda makes my other plugins look bad huh :/

*/

#include <sourcemod>
#include <builtinvotes>
#include <left4dhooks>
#include <l4d2util_rounds>
#include <l4d2lib>
#include <readyup>
#include <colors>

public Plugin:myinfo =
{
	name = "[L4D2] Boss Percents/Vote Boss Hybrid",
	author = "Spoon",
	version = "3.0.2",
	description = "Displays Boss Flows on Ready-Up and via command. Remade for NextMod.",
	url = "https://github.com/spoon-l4d2"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("SetTankDisabled", Native_SetTankDisabled); 				// Other plugins can use this to set the tank as "disabled" on the ready up, and when the !boss command is used - YOU NEED TO SET THIS EVERY MAP
	CreateNative("SetWitchDisabled", Native_SetWitchDisabled); 				// Other plugins can use this to set the witch as "disabled" on the ready up, and when the !boss command is used - YOU NEED TO SET THIS EVERY MAP
	CreateNative("UpdateBossPercents", Native_UpdateBossPercents); 			// Used for other plugins to update the boss percentages
	CreateNative("IsStaticWitchMap", Native_IsStaticWitchMap); 				// Used for other plugins to check if the current map contains a static witch spawn
	CreateNative("IsStaticTankMap", Native_IsStaticTankMap); 				// Used for other plugins to check if the current map contains a static tank spawn
	CreateNative("GetStoredTankPercent", Native_GetStoredTankPercent); 		// Used for other plugins to get the stored tank percent
	CreateNative("GetReadyUpFooterIndex", Native_GetReadyUpFooterIndex); 	// Used for other plugins to get the ready footer index of the boss percents
	CreateNative("GetStoredWitchPercent", Native_GetStoredWitchPercent); 	// Used for other plugins to get the stored witch percent
	CreateNative("RefreshBossPercentReadyUp", Native_RefreshReadyUp); 		// Used for other plugins to refresh the boss percents on the ready up
	CreateNative("IsDarkCarniRemix", Native_IsDarkCarniRemix); 				// Used for other plugins to check if the current map is Dark Carnival: Remix (It tends to break things when it comes to bosses)
	RegPluginLibrary("l4d_boss_percent");
	return APLRes_Success;
}

// ConVars
new Handle:g_hCvarGlobalPercent 											// Determines if Percents will be displayed to entire team when boss percentage command is used
new Handle:g_hCvarTankPercent; 												// Determines if Tank Percents will be displayed on ready-up and when boss percentage command is used
new Handle:g_hCvarWitchPercent; 											// Determines if Witch Percents will be displayed on ready-up and when boss percentage command is used
new Handle:g_hCvarBossVoting; 												// Determines if boss voting will be enabled

// Handles
new Handle:g_hVsBossBuffer; 												// Boss Buffer
new Handle:g_hVsBossFlowMax; 												// Boss Flow Min
new Handle:g_hVsBossFlowMin; 												// Boss Flow Max
new Handle:g_hStaticTankMaps; 												// Stores All Static Tank Maps
new Handle:g_hStaticWitchMaps; 												// Stores All Static Witch Maps
new Handle:g_forwardUpdateBosses;

// Variables
new bool:g_ReadyUpAvailable; 												// Is Ready-Up plugin loaded?
new g_iReadyUpFooterIndex; 													// Stores the index of our boss percentage string on the ready-up menu footer
new bool:g_bReadyUpFooterAdded;												// Stores if our ready-up footer has been added yet
new String:g_sCurrentMap[64]; 												// Stores the current map name
new bool:g_bWitchDisabled;													// Stores if another plugin has disabled the witch
new bool:g_bTankDisabled;													// Stores if another plugin has disabled the tank

// Dark Carnival: Remix Work Around Variables
new bool:g_bIsRemix; 														// Stores if the current map is Dark Carnival: Remix. So we don't have to keep checking via IsDKR()
new g_idkrwaAmount; 														// Stores the amount of times the DKRWorkaround method has been executed. We only want to execute it twice, one to get the tank percentage, and a second time to get the witch percentage.
int g_fDKRFirstRoundTankPercent; 											// Stores the Tank percent from the first half of a DKR map. Used so we can set the 2nd half to the same percent
int g_fDKRFirstRoundWitchPercent; 											// Stores the Witch percent from the first half of a DKR map. Used so we can set the 2nd half to the same percent
new bool:g_bDKRFirstRoundBossesSet; 										// Stores if the first round of DKR boss percentages have been set

// Boss Voting Variables
new Handle:bv_hVote;														// Our boss vote handle
new bool:bv_bWitch;															// Stores if the Witch percent will change
new bool:bv_bTank;															// Stores if the Tank percent will change
int bv_iTank;																// Where we will keep our requested Tank percentage
int bv_iWitch;																// Where we will keep our requested Witch percentage

// Percent Variables
int g_fWitchPercent;														// Stores current Witch Percent
int g_fTankPercent;															// Stores current Tank Percent

public OnPluginStart()
{
	// Variable Setting
	g_hVsBossBuffer = FindConVar("versus_boss_buffer"); // Get the boss buffer
	g_hStaticWitchMaps = CreateTrie(); // Create list of static witch maps
	g_hStaticTankMaps = CreateTrie(); // Create list of static tank maps
	
	// Forwards
	g_forwardUpdateBosses = CreateGlobalForward("OnUpdateBosses", ET_Event);

	// ConVars
	g_hCvarGlobalPercent = CreateConVar("l4d_global_percent", "0", "Display boss percentages to entire team when using commands"); // Sets if Percents will be displayed to entire team when boss percentage command is used
	g_hCvarTankPercent = CreateConVar("l4d_tank_percent", "1", "Display Tank flow percentage in chat"); // Sets if Tank Percents will be displayed on ready-up and when boss percentage command is used
	g_hCvarWitchPercent = CreateConVar("l4d_witch_percent", "1", "Display Witch flow percentage in chat"); // Sets if Witch Percents will be displayed on ready-up and when boss percentage command is used
	g_hCvarBossVoting = CreateConVar("l4d_boss_vote", "1", "Enable boss voting"); // Sets if boss voting is enabled or disabled

	// Commands
	RegConsoleCmd("sm_boss", BossCmd); // Used to see percentages of both bosses
	RegConsoleCmd("sm_tank", BossCmd); // Used to see percentages of both bosses
	RegConsoleCmd("sm_witch", BossCmd); // Used to see percentages of both bosses
	RegConsoleCmd("sm_voteboss", VoteBossCmd); // Allows players to vote for custom boss spawns
	RegConsoleCmd("sm_bossvote", VoteBossCmd); // Allows players to vote for custom boss spawns
	
	// Admin Commands
	RegAdminCmd("sm_ftank", ForceTankCommand, ADMFLAG_BAN);
	RegAdminCmd("sm_fwitch", ForceWitchCommand, ADMFLAG_BAN);
	
	// Server Commands
	RegServerCmd("static_witch_map", StaticWitchMap_Command); // Server command that is used to store static witch maps
	RegServerCmd("static_tank_map", StaticTankMap_Command); // Server command that is used to store static tank maps

	// Hooks/Events
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy); // Called when a player has left the saferoom
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy); // When a new round starts (2 rounds in 1 map -- this should be called twice a map)
	HookEvent("player_say", DKRWorkaround, EventHookMode_Post); // Called when a message is sent in chat. Used to grab the Dark Carnival: Remix boss percentages.
}

/* ========================================================
// ====================== Section #1 ======================
// ======================= Natives ========================
// ========================================================
 *
 * This section contains all the methods that other plugins 
 * can use.
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

// Allows other plugins to update boss percentages
public Native_UpdateBossPercents(Handle:plugin, numParams)
{
	CreateTimer(0.1, GetBossPercents);
	CreateTimer(0.2, UpdateReadyUpFooter);
	return true;
}

// Allows other plugins to check if the current map contains a static witch spawn
public Native_IsStaticWitchMap(Handle:plugin, numParams){
	return IsStaticWitchMap();
}

// Allows other plugins to check if the current map contains a static tank spawn
public Native_IsStaticTankMap(Handle:plugin, numParams){
	return IsStaticTankMap();
}

public Native_IsDarkCarniRemix(Handle:plugin, numParams)
{
	return IsDKR();
}

public Native_SetWitchDisabled(Handle:plugin, numParams)
{
	int n_trueFalse = GetNativeCell(1);
	 
	if (n_trueFalse == 0)
	{
		g_bWitchDisabled = false;
	}
	else 
	{
		g_bWitchDisabled = true;
	}
	
	return;
}

public Native_SetTankDisabled(Handle:plugin, numParams)
{
	int n_trueFalse = GetNativeCell(1);
	 
	if (n_trueFalse == 0)
	{
		g_bTankDisabled = false;
	}
	else 
	{
		g_bTankDisabled = true;
	}
	
	return;
}

public Native_GetStoredWitchPercent(Handle:plugin, numParams)
{
	return g_fWitchPercent;
}

public Native_GetStoredTankPercent(Handle:plugin, numParams)
{
	return g_fTankPercent;
}

public Native_GetReadyUpFooterIndex(Handle:plugin, numParams)
{
	if (g_ReadyUpAvailable)
		return g_iReadyUpFooterIndex;
	else
		return -1;
}

public Native_RefreshReadyUp(Handle:plugin, numParams)
{
	if (g_ReadyUpAvailable)
	{
		CreateTimer(0.2, UpdateReadyUpFooter);
		return true;
	} 
	else 
	{
		return false;
	}
}

/* ========================================================
// ====================== Section #2 ======================
// ==================== Ready Up Check ====================
// ========================================================
 *
 * This section makes sure that the Ready Up plugin is loaded.
 * 
 * It's needed to make sure we can actually add to the Ready
 * Up menu, or if we should just diplay percentages in chat.
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

public OnAllPluginsLoaded()
{
	g_ReadyUpAvailable = LibraryExists("readyup");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "readyup")) g_ReadyUpAvailable = false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "readyup")) g_ReadyUpAvailable = true;
}

/* ========================================================
// ====================== Section #3 ======================
// ======================== Events ========================
// ========================================================
 *
 * This section is where all of our events will be. Just to
 * make things easier to keep track of.
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

// Called when a new map is loaded
public void OnMapStart()
{		

	// Get Current Map
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	
	// Check if the current map is part of the Dark Carnival: Remix Campaign -- and save it
	g_bIsRemix = IsDKR();
	
}

// Called when a map ends 
public void OnMapEnd()
{
	// Reset Variables
	g_fDKRFirstRoundTankPercent = -1;
	g_fDKRFirstRoundWitchPercent = -1;
	g_fWitchPercent = -1;
	g_fTankPercent = -1;
	g_bDKRFirstRoundBossesSet = false;
	g_idkrwaAmount = 0;
	g_bTankDisabled = false;
	g_bWitchDisabled = false;
}

/* Called when survivors leave the saferoom
 * If the Ready Up plugin is not available, we use this. 
 * It will print boss percents upon survivors leaving the saferoom.
*/
public LeftStartAreaEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_ReadyUpAvailable) {
		for (new client = 1; client <= MaxClients; client++)
		{
			if (IsClientConnected(client) && IsClientInGame(client)) 
			{
				PrintBossMiddleMan(client);
			}
		}
		
		// If it's the first round of a Dark Carnival: Remix map, we want to save our boss percentages so we can set them next round
		if (g_bIsRemix && !InSecondHalfOfRound()) {
			g_fDKRFirstRoundTankPercent = g_fTankPercent;
			g_fDKRFirstRoundWitchPercent = g_fWitchPercent;
		}
	}
	
}

/* Called when the round goes live (Requires Ready Up Plugin)
 * If the Ready Up plugin is available, we use this.
 * It will print boss percents after all players are ready and the round goes live.
*/
public OnRoundIsLive()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client)) 
		{
			PrintBossMiddleMan(client);
		}
	}
	
	// If it's the first round of a Dark Carnival: Remix map, we want to save our boss percentages so we can set them next round
	if (g_bIsRemix && !InSecondHalfOfRound()) {
		g_fDKRFirstRoundTankPercent = g_fTankPercent;
		g_fDKRFirstRoundWitchPercent = g_fWitchPercent;
	}
}

/* Called when a new round starts (twice each map)
 * Here we will need to refresh the boss percents.
*/
public RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{	
	// Reset Ready Up Variables
	g_bReadyUpFooterAdded = false;
	g_iReadyUpFooterIndex = -1;
	
	// Check if the current map is part of the Dark Carnival: Remix Campaign -- and save it
	g_bIsRemix = IsDKR();
	
	// Find percentages and update readyup footer
	CreateTimer(5.0, GetBossPercents);
	CreateTimer(6.0, UpdateReadyUpFooter);
	
}

/* ========================================================
// ====================== Section #4 ======================
// ================== Static Map Control ==================
// ========================================================
 *
 * This section is where all of our methods that have to due
 * with Static Boss Spawn maps will go.
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

// Server Command - When it is executed it will add a static witch map name to a list.
public Action:StaticWitchMap_Command(args)
{
	decl String:mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(g_hStaticWitchMaps, mapname, true);
}

// Server Command - When it is executed it will add a static tank map name to a list.
public Action:StaticTankMap_Command(args)
{
	decl String:mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(g_hStaticTankMaps, mapname, true);
}

// Checks the static witch map list to see if the current map contains a static witch spawn
public bool:IsStaticWitchMap(){
	new tempValue;
	if (GetTrieValue(g_hStaticWitchMaps, g_sCurrentMap, tempValue)) {
		return true;				
	}
	else {
		return false;
	}
}

// Checks the static tank map list to see if the current map contains a static tank spawn
public bool:IsStaticTankMap(){
	new tempValue;
	if (GetTrieValue(g_hStaticTankMaps, g_sCurrentMap, tempValue)) {
		return true;				
	}
	else {
		return false;
	}
}

/* ========================================================
// ====================== Section #5 ======================
// ============ Dark Carnival: Remix Workaround ===========
// ========================================================
 *
 * This section is where all of our DKR work around stuff
 * well be kept. DKR has it's own boss flow "randomizer"
 * and therefore needs to be set as a static map to avoid
 * having 2 tanks on the map. Because of this, we need to 
 * do a few extra steps to determine the boss spawn percents.
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

// Check if the current map name is equal to and of the Dark Carnival: Remix map names
public bool:IsDKR()
{
	if (StrEqual(g_sCurrentMap, "dkr_m1_motel", true) || StrEqual(g_sCurrentMap, "dkr_m2_carnival", true) || StrEqual(g_sCurrentMap, "dkr_m3_tunneloflove", true) || StrEqual(g_sCurrentMap, "dkr_m4_ferris", true) || StrEqual(g_sCurrentMap, "dkr_m5_stadium", true))
	{
		return true;
	}
	return false;
	
}

// Finds a percentage from a string
public int GetPercentageFromText(String:text[])
{
	// Check to see if text contains '%' - Store the index if it does
	int index = StrContains(text, "%", false);
	
	// If the index isn't -1 (No '%' found) then find the percentage
	if (index > -1) {
		new String:sBuffer[12]; // Where our percentage will be kept.
		
		// If the 3rd character before the '%' symbol is a number it's 100%.
		if (IsCharNumeric(text[index-3])) {
			return 100;
		}
		
		// Check to see if the characters that are 1 and 2 characters before our '%' symbol are numbers
		if (IsCharNumeric(text[index-2]) && IsCharNumeric(text[index-1])) {
		
			// If both characters are numbers combine them into 1 string
			Format(sBuffer, sizeof(sBuffer), "%c%c", text[index-2], text[index-1]);
			
			// Convert our string to an int
			return StringToInt(sBuffer);
		}
	}
	
	// Couldn't find a percentage
	return -1;
}

/*
 *
 * On Dark Carnival: Remix there is a script to display custom boss percentages to users via chat.
 * We can "intercept" this message and read the boss percentages from the message.
 * From there we can add them to our Ready Up menu and to our !boss commands
 *
 */
public Action:DKRWorkaround(Handle:event, String:name[], bool:dontBroadcast)
{
	// If the current map is not part of the Dark Carnival: Remix campaign, don't continue
	if (!g_bIsRemix) return;
	
	// Check if the function has already ran more than twice this map
	if (g_bDKRFirstRoundBossesSet || InSecondHalfOfRound()) return;
	
	// Check if the message is not from a user (Which means its from the map script)
	new UserID = GetEventInt(event, "userid", 0);
	if (!UserID && !InSecondHalfOfRound())
	{
	
		// Get the message text
		new String:sBuffer[128];
		GetEventString(event, "text", sBuffer, sizeof(sBuffer), "");
		
		// If the message contains "The Tank" we can try to grab the Tank Percent from it
		if (StrContains(sBuffer, "The Tank", false) > -1)
		{	
			// Create a new int and find the percentage
			int percentage;
			percentage = GetPercentageFromText(sBuffer);
			
			// If GetPercentageFromText didn't return -1 that means it returned our boss percentage.
			// So, if it did return -1, something weird happened, set our boss to 0 for now.
			if (percentage > -1) {
				g_fTankPercent = percentage;
			} else {
				g_fTankPercent = 0;					
			} 
			
			g_fDKRFirstRoundTankPercent = g_fTankPercent;
		}
		
		// If the message contains "The Witch" we can try to grab the Witch Percent from it
		if (StrContains(sBuffer, "The Witch", false) > -1)
		{
			// Create a new int and find the percentage
			int percentage;
			percentage = GetPercentageFromText(sBuffer);
			
			// If GetPercentageFromText didn't return -1 that means it returned our boss percentage.
			// So, if it did return -1, something weird happened, set our boss to 0 for now.
			if (percentage > -1){
				g_fWitchPercent = percentage;
			
			} else {
				g_fWitchPercent = 0;
			}
			
			g_fDKRFirstRoundWitchPercent = g_fWitchPercent;
		}
		
		// Increase the amount of times we've done this function. We only want to do it twice. Once for each boss, for each map.
		g_idkrwaAmount = g_idkrwaAmount + 1;
		
		// Check if both bosses have already been set 
		if (g_idkrwaAmount > 1)
		{
			// This function has been executed two or more times, so we should be done here for this map.
			g_bDKRFirstRoundBossesSet = true;
		}
		
		UpdateReadyUpFooter(INVALID_HANDLE);
	}
}

/* ========================================================
// ====================== Section #6 ======================
// ================= Percent Updater/Saver ================
// ========================================================
 *
 * This section is where we will save our boss percents and
 * where we will call the methods to update our boss percents
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

// This method will return the Tank flow for a specified round
stock Float:GetTankFlow(round)
{
	return L4D2Direct_GetVSTankFlowPercent(round) -
		( Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}

stock Float:GetWitchFlow(round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round) -
		( Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}

/* 
 *
 * This method will find the current boss percents and will
 * save them to our boss percent variables.
 * This method will be called upon every new round
 *
 */
public Action:GetBossPercents(Handle:timer)
{
	// We need to do things a little differently if it's Dark Carnival: Remix
	if (g_bIsRemix)
	{
		// Our boss percents should be set for us via the Workaround method on round one - so lets skip it
		if (InSecondHalfOfRound()) 
		{
			// When the first round begines, this variables are set. So, we can just copy them for our second round.
			g_fWitchPercent = g_fDKRFirstRoundWitchPercent;
			g_fTankPercent = g_fDKRFirstRoundTankPercent;
			
		}
		else 
		{
			// Bosses cannot be changed on Dark Carnival: Remix maps. Unless they are completely disabled. So, we need to check if that's the case here
			
			if (g_bDKRFirstRoundBossesSet)
			{
				// If the Witch is not set to spawn this round, set it's percentage to 0
				if (!L4D2Direct_GetVSWitchToSpawnThisRound(0))
				{
					// Not quite enough yet. We also want to check if the flow is 0
					if ((GetWitchFlow(0) * 100.0) < 1) 
					{
						// One last check
							if (g_bWitchDisabled)
								g_fWitchPercent = 0;				
					}
				}
				else 
				{
					// The boss must have been re-enabled :)
					g_fWitchPercent = g_fDKRFirstRoundWitchPercent;
				}
				
				// If the Tank is not set to spawn this round, set it's percentage to 0
				if (!L4D2Direct_GetVSTankToSpawnThisRound(0))
				{
					// Not quite enough yet. We also want to check if the flow is 0
					if ((GetTankFlow(0) * 100) < 1) 
					{
						// One last check
							if (g_bTankDisabled)
								g_fTankPercent = 0;		
					}
				}
				else 
				{
					// The boss must have been re-enabled :)
					g_fTankPercent = g_fDKRFirstRoundTankPercent;
				}
			}
		}
	} 
	else 
	{
		// This will be any map besides Remix
		if (InSecondHalfOfRound()) 
		{

			// We're in the second round
			
			// If the witch flow isn't already 0 from the first round then get the round 2 witch flow
			if (g_fWitchPercent != 0)
				g_fWitchPercent = RoundToNearest(GetWitchFlow(1) * 100.0);
				
			// If the tank flow isn't already 0 from the first round then get the round 2 tank flow
			if (g_fTankPercent != 0)
				g_fTankPercent = RoundToNearest(GetTankFlow(1) * 100.0);
				
		}
		else 
		{
		
			// We're in the first round.
			
			// Set our boss percents to 0 - If bosses are not set to spawn this round, they will remain 0
			g_fWitchPercent = 0;
			g_fTankPercent = 0;
		
			// If the Witch is set to spawn this round. Find the witch flow and set it as our witch percent
			if (L4D2Direct_GetVSWitchToSpawnThisRound(0))
			{
				g_fWitchPercent = RoundToNearest(GetWitchFlow(0) * 100.0);
			}
			
			// If the Tank is set to spawn this round. Find the witch flow and set it as our witch percent
			if (L4D2Direct_GetVSTankToSpawnThisRound(0))
			{
				g_fTankPercent = RoundToNearest(GetTankFlow(0) * 100.0);
			}
			
		}
	}
}

public bool:DisabledTankCheck()
{
	if (!IsStaticTankMap()) return false;
	if (g_fTankPercent > 0) return false;
	if (g_bIsRemix) return false;
	
	if (InSecondHalfOfRound())
	{
		if (!L4D2Direct_GetVSTankToSpawnThisRound(1))
		{
			return true;
		}
	}
	else
	{
		if (!L4D2Direct_GetVSTankToSpawnThisRound(0))
		{
			return true;
		}
	}
	
	return false;
}

/* 
 *
 * This method will update the ready up footer with our
 * current boss percntages
 * This method will be called upon every new round
 *
 */
public Action:UpdateReadyUpFooter(Handle:timer) 
{
	// Check to see if Ready Up plugin is available
	if (g_ReadyUpAvailable) 
	{
		// Create some variables
		new String:p_sTankString[32]; // Private Variable - Where our formatted Tank string will be kept
		new String:p_sWitchString[32]; // Private Variable - Where our formatted Witch string will be kept
		new bool:p_bStaticTank; // Private Variable - Stores if current map contains static tank spawn
		new bool:p_bStaticWitch; // Private Variable - Stores if current map contains static witch spawn
		new String:p_sNewFooter[65]; // Private Variable - Where our new footer string will be kept

		
		// Check if the current map is from Dark Carnival: Remix
		if (!g_bIsRemix)
		{
			p_bStaticTank = IsStaticTankMap();
			p_bStaticWitch = IsStaticWitchMap();
		}

		// Format our Tank String
		if (g_fTankPercent > 0) // If Tank percent is not 0
		{
			Format(p_sTankString, sizeof(p_sTankString), "Tank: %d%%", g_fTankPercent);
		}
		else if (g_bTankDisabled) // If another plugin has disabled the tank
		{
			Format(p_sTankString, sizeof(p_sTankString), "Tank: Disabled");
		}
		else if (p_bStaticTank) // If current map contains static Tank
		{
			Format(p_sTankString, sizeof(p_sTankString), "Tank: Static Spawn");
		}
		else // There is no Tank (Flow = 0)
		{
			Format(p_sTankString, sizeof(p_sTankString), "Tank: None");
		}
		
		// Format our Witch String
		if (g_fWitchPercent > 0) // If Witch percent is not 0
		{
			Format(p_sWitchString, sizeof(p_sWitchString), "Witch: %d%%", g_fWitchPercent);
		}
		else if (g_bWitchDisabled) // If another plugin has disabled the witch
		{
			Format(p_sWitchString, sizeof(p_sWitchString), "Witch: Disabled");
		}
		else if (p_bStaticWitch) // If current map contains static Witch
		{
			Format(p_sWitchString, sizeof(p_sWitchString), "Witch: Static Spawn");
		}
		else // There is no Witch (Flow = 0)
		{
			Format(p_sWitchString, sizeof(p_sWitchString), "Witch: None");
		}
		
		// Combine our Tank and Witch strings together
		if (GetConVarBool(g_hCvarWitchPercent) && GetConVarBool(g_hCvarTankPercent)) // Display Both Tank and Witch Percent
		{
			Format(p_sNewFooter, sizeof(p_sNewFooter), "%s, %s", p_sTankString, p_sWitchString);
		}
		else if (GetConVarBool(g_hCvarWitchPercent)) // Display just Witch Percent
		{
			Format(p_sNewFooter, sizeof(p_sNewFooter), "%s", p_sWitchString);
		}
		else if (GetConVarBool(g_hCvarTankPercent)) // Display just Tank Percent
		{
			Format(p_sNewFooter, sizeof(p_sNewFooter), "%s", p_sTankString);
		}	
		
		// Check to see if the Ready Up footer has already been added 
		if (g_bReadyUpFooterAdded) 
		{
			// Ready Up footer already exists, so we can just edit it.
			EditFooterStringAtIndex(g_iReadyUpFooterIndex, p_sNewFooter);
		}
		else
		{
			// Ready Up footer hasn't been added yet. Must be the start of a new round! Lets add it.
			g_iReadyUpFooterIndex = AddStringToReadyFooter(p_sNewFooter);
			g_bReadyUpFooterAdded = true;
		}
	}
}

/* ========================================================
// ====================== Section #7 ======================
// ======================= Commands =======================
// ========================================================
 *
 * This is where all of our boss commands will go
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

public Action:BossCmd(client, args)
{
	// Show our boss percents
	PrintBossPercents(INVALID_HANDLE, client);
	CreateTimer(0.1, PrintCurrent, client);
}

public Action PrintCurrent(Handle timer, int client) {
	FakeClientCommand(client, "say /current");
}

public void PrintBossMiddleMan(client) {
	// Show our boss percents
	CreateTimer(0.1, PrintBossPercents, client);
}

public Action:PrintBossPercents(Handle:timer, any:client)
{
	// Create some variables
	new String:p_sTankString[80]; // Private Variable - Where our formatted Tank string will be kept
	new String:p_sWitchString[80]; // Private Variable - Where our formatted Witch string will be kept
	new bool:p_bStaticTank; // Private Variable - Stores if current map contains static tank spawn
	new bool:p_bStaticWitch; // Private Variable - Stores if current map contains static witch spawn

		
	// Check if the current map is from Dark Carnival: Remix
	if (!g_bIsRemix)
	{
		// Not part of the Dark Carnival: Remix Campaign -- Check to see if map contains static boss spawns - and store it to a bool variable
		p_bStaticTank = IsStaticTankMap();
		p_bStaticWitch = IsStaticWitchMap();
	}
	
	// Format String For Tank
	if (g_fTankPercent > 0) // If Tank percent is not equal to 0
	{
		Format(p_sTankString, sizeof(p_sTankString), "<{olive}Tank{default}> {red}%d%%", g_fTankPercent);
	}  
	else if (g_bTankDisabled) // If another plugin has disabled the tank
	{
		Format(p_sTankString, sizeof(p_sTankString), "<{olive}Tank{default}> {red}Disabled");
	} 
	else if (p_bStaticTank) // If current map has static Tank spawn
	{
		Format(p_sTankString, sizeof(p_sTankString), "<{olive}Tank{default}> {red}Static Spawn");
	} 
	else // There is no Tank
	{
		Format(p_sTankString, sizeof(p_sTankString), "<{olive}Tank{default}> {red}None");
	}
	
	// Format String For Witch
	if (g_fWitchPercent > 0) // If Witch percent is not equal to 0
	{
		Format(p_sWitchString, sizeof(p_sWitchString), "<{olive}Witch{default}> {red}%d%%", g_fWitchPercent);
	}  
	else if (g_bWitchDisabled) // If another plugin has disabled the witch
	{
		Format(p_sWitchString, sizeof(p_sWitchString), "<{olive}Witch{default}> {red}Disabled");
	} 
	else if (p_bStaticWitch) // If current map has static Witch spawn
	{
		Format(p_sWitchString, sizeof(p_sWitchString), "<{olive}Witch{default}> {red}Static Spawn");
	} 
	else // There is no Witch
	{
		Format(p_sWitchString, sizeof(p_sWitchString), "<{olive}Witch{default}> {red}None");
	}
	
	// Print Messages to client
	
	if (GetConVarBool(g_hCvarTankPercent))
	{
		if (GetConVarBool(g_hCvarGlobalPercent))
		{
			int team = GetClientTeam(client);
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
					CPrintToChat(i, p_sTankString);
			}
		}
		else
		{
			CPrintToChat(client, p_sTankString);
		}
	}
	if (GetConVarBool(g_hCvarWitchPercent))
	{
		if (GetConVarBool(g_hCvarGlobalPercent))
		{
			int team = GetClientTeam(client);
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
					CPrintToChat(i, p_sWitchString);
			}
		}
		else
		{
			CPrintToChat(client, p_sWitchString);
		}
	}
}

/* ========================================================
// ====================== Section #8 ======================
// ====================== Boss Votin ======================
// ========================================================
 *
 *
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

public Action:UpdatedForward(Handle:timer)
{
	Call_StartForward(g_forwardUpdateBosses);
	Call_Finish();
}

public bool:IsInteger(String:buffer[])
{
    new len = strlen(buffer);
    for (new i = 0; i < len; i++)
    {
        if ( !IsCharNumeric(buffer[i]) )
            return false;
    }

    return true;    
}

public bool:RunVoteChecks(client)
{
	if (g_bIsRemix)
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss voting is not available on this map.")
		return false;
	}
	if (!IsInReady())
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss voting is only available during ready up.")
		return false;
	}
	if (InSecondHalfOfRound())
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss voting is only available during the first round of a map.")
		return false;
	}
	if (GetClientTeam(client) == 1)
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss voting is not available for spectators.")
		return false;
	}
	return true;
}

public Action:VoteBossCmd(client, args)
{
	if (!GetConVarBool(g_hCvarBossVoting)) return;
	if (!RunVoteChecks(client)) return;
	if (args != 2)
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Usage: !voteboss {olive}<{default}tank{olive}> <{default}witch{olive}>{default}.")
		return;
	}
	
	// Get all non-spectating players
	new iNumPlayers;
	decl iPlayers[MaxClients];
	for (new i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == 1))
		{
			continue;
		}
		iPlayers[iNumPlayers++] = i;
	}
	
	// Get Requested Boss Percents
	new String:bv_sTank[32];
	new String:bv_sWitch[32];
	GetCmdArg(1, bv_sTank, 32);
	GetCmdArg(2, bv_sWitch, 32);
	
	// Make sure the args are actual numbers
	if (!IsInteger(bv_sTank))
		return;
	if (!IsInteger(bv_sWitch))
		return;
	
	// Check to make sure static bosses don't get changed
	if (!IsStaticTankMap())
	{
		bv_bTank = true;
		bv_iTank = StringToInt(bv_sTank);
	}
	else
	{
		bv_bTank = false;
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Tank spawn is static and can not be changed on this map.");
	}
	
	if (!IsStaticWitchMap())
	{
		bv_bWitch = true;
		bv_iWitch = StringToInt(bv_sWitch);
	}
	else
	{
		bv_bWitch = false;
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Witch spawn is static and can not be changed on this map.");
	}
	
	// Check if percent is within limits
	if (!ValidateFlow(bv_iTank, bv_iWitch, bv_bTank, bv_bWitch))
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss percents are {olive}invalid{default} or {olive}banned{default}.");
		return;
	}
	
	// Check if a new vote is allowed to be called
	if (IsNewBuiltinVoteAllowed() && !IsBuiltinVoteInProgress())
	{
		
		new String:bv_voteTitle[64];
		
		// Set vote title
		if (bv_bTank && bv_bWitch)	// Both Tank and Witch can be changed 
		{
			Format(bv_voteTitle, 64, "Set Tank to: %s and Witch to: %s?", bv_sTank, bv_sWitch);
		}
		else if (bv_bTank)	// Only Tank can be changed -- Witch must be static
		{
			Format(bv_voteTitle, 64, "Set Tank to: %s?", bv_sTank);
		}
		else if (bv_bWitch) // Only Witch can be changed -- Tank must be static
		{
			Format(bv_voteTitle, 64, "Set Witch to: %s?", bv_sWitch);
		}
		else // Neither can be changed... ok...
		{
			return;
		}
		
		// Start the vote!
		bv_hVote = CreateBuiltinVote(BossVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(bv_hVote, bv_voteTitle);
		SetBuiltinVoteInitiator(bv_hVote, client);
		SetBuiltinVoteResultCallback(bv_hVote, BossVoteResultHandler);
		DisplayBuiltinVote(bv_hVote, iPlayers, iNumPlayers, 20);
		FakeClientCommand(client, "Vote Yes");
	}
	else
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss Vote cannot be called right now...")
		return;
	}
}

public BossVoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			bv_hVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public BossVoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
			
				// One last ready-up check.
				if (!IsInReady())  {
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
					CPrintToChatAll("{blue}<{green}BossVote{blue}>{default} Spawns can only be set during ready up.");
					return;
				}
				
				if (bv_bTank && bv_bWitch)	// Both Tank and Witch can be changed 
				{
					DisplayBuiltinVotePass(vote, "Setting Boss Spawns...");
					SetTankPercent(bv_iTank);
					SetWitchPercent(bv_iWitch);
				}
				else if (bv_bTank)	// Only Tank can be changed -- Witch must be static
				{
					DisplayBuiltinVotePass(vote, "Setting Tank Spawn...");
					SetTankPercent(bv_iTank);
				}
				else if (bv_bWitch) // Only Witch can be changed -- Tank must be static
				{
					DisplayBuiltinVotePass(vote, "Setting Witch Spawn...");
					SetWitchPercent(bv_iWitch);
				}
				else // Neither can be changed... ok...
				{
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
					return;
				}
				
				// Update our shiz yo
				CreateTimer(0.1, GetBossPercents);
				CreateTimer(0.2, UpdateReadyUpFooter);
				
				// Forward da message man :)
				Call_StartForward(g_forwardUpdateBosses);
				Call_Finish();
				
				return;
			}
		}
	}
	
	// Vote Failed
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

// credit to SirPlease
bool ValidateFlow(int iTank, int iWitch, bool bTank, bool bWitch)
{
	int iBossMinFlow = RoundToCeil(GetConVarFloat(g_hVsBossFlowMin) * 100);
	int iBossMaxFlow = RoundToFloor(GetConVarFloat(g_hVsBossFlowMax) * 100);
	
	// mapinfo override
	iBossMinFlow = L4D2_GetMapValueInt("versus_boss_flow_min", iBossMinFlow);
	iBossMaxFlow = L4D2_GetMapValueInt("versus_boss_flow_max", iBossMaxFlow);
	
	if (bTank)
	{
		int iMinBanFlow = L4D2_GetMapValueInt("tank_ban_flow_min", -1);
		int iMaxBanFlow = L4D2_GetMapValueInt("tank_ban_flow_max", -1);
		int iMinBanFlowB = L4D2_GetMapValueInt("tank_ban_flow_min_b", -1);
		int iMaxBanFlowB = L4D2_GetMapValueInt("tank_ban_flow_max_b", -1);
		int iMinBanFlowC = L4D2_GetMapValueInt("tank_ban_flow_min_c", -1);
		int iMaxBanFlowC = L4D2_GetMapValueInt("tank_ban_flow_max_c", -1);
		
		// check each array index to see if it is within a ban range
		bool bValidSpawn[101] = {false, ...};
		int iValidSpawnTotal = 0;
		for (int i = 0; i <= 100; i++) {
		    bValidSpawn[i] = (iBossMinFlow <= i && i <= iBossMaxFlow) && !(iMinBanFlow <= i && i <= iMaxBanFlow) && !(iMinBanFlowB <= i && i <= iMaxBanFlowB) && !(iMinBanFlowC <= i && i <= iMaxBanFlowC);
		    if (bValidSpawn[i]) iValidSpawnTotal++;
		}
		
		if (iValidSpawnTotal == 0) {
			return false;
		}
		
		return bValidSpawn[iTank];
	}
	
	if (bWitch)
	{
		iBossMinFlow = L4D2_GetMapValueInt("witch_flow_min", iBossMinFlow);
		iBossMaxFlow = L4D2_GetMapValueInt("witch_flow_max", iBossMaxFlow);
		
		return iBossMinFlow <= iWitch && iWitch <= iBossMaxFlow;
	}
	
	return false;
}

public SetWitchPercent(int percent)
{
	new Float:p_newPercent;
	p_newPercent = float(percent);
	
	if (p_newPercent == 0)
	{
		L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
		L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
	}
	else if (p_newPercent == 100.0)
	{
		L4D2Direct_SetVSWitchFlowPercent(0, 1.0);
		L4D2Direct_SetVSWitchFlowPercent(1, 1.0);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
	}
	else
	{
		p_newPercent = (p_newPercent/100);
		L4D2Direct_SetVSWitchFlowPercent(0, p_newPercent);
		L4D2Direct_SetVSWitchFlowPercent(1, p_newPercent);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
	}
}

public SetTankPercent(int percent)
{
	new Float:p_newPercent;
	p_newPercent = float(percent);

	if (p_newPercent == 0.0)
	{
		L4D2Direct_SetVSTankFlowPercent(0, 0.0);
		L4D2Direct_SetVSTankFlowPercent(1, 0.0);
		L4D2Direct_SetVSTankToSpawnThisRound(0, false);
		L4D2Direct_SetVSTankToSpawnThisRound(1, false);
	}
	else if (p_newPercent == 100.0)
	{
		L4D2Direct_SetVSTankFlowPercent(0, 1.0);
		L4D2Direct_SetVSTankFlowPercent(1, 1.0);
		L4D2Direct_SetVSTankToSpawnThisRound(0, true);
		L4D2Direct_SetVSTankToSpawnThisRound(1, true);
	}
	else
	{
		p_newPercent = (p_newPercent/100);
		L4D2Direct_SetVSTankFlowPercent(0, p_newPercent);
		L4D2Direct_SetVSTankFlowPercent(1, p_newPercent);
		L4D2Direct_SetVSTankToSpawnThisRound(0, true);
		L4D2Direct_SetVSTankToSpawnThisRound(1, true);
	}
}

/* ========================================================
// ====================== Section #9 ======================
// ==================== Admin Commands ====================
// ========================================================
 *
 * Where the admin commands for setting boss spawns will go
 *
 * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
*/

public Action:ForceTankCommand(client, args)
{
	if (!GetConVarBool(g_hCvarBossVoting)) return;
	if (g_bIsRemix)
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Command not available on this map.");
		return;
	}
	
	if (IsStaticTankMap())
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Tank spawn is static and can not be changed on this map.");
		return;
	}
	
	if (!IsInReady())
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Command can only be used during ready up.");
		return;
	}
	
	// Get Requested Tank Percent
	new String:bv_sTank[32];
	GetCmdArg(1, bv_sTank, 32);
	
	// Make sure the cmd argument is a number
	if (!IsInteger(bv_sTank))
		return;
	
	// Convert it to in int boy
	int p_iRequestedPercent;
	p_iRequestedPercent = StringToInt(bv_sTank);
	
	// Check if percent is within limits
	if (p_iRequestedPercent > 100 || p_iRequestedPercent < 0)
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss percent needs to be between {olive}0{default} and {olive}100{default}.");
		return;
	}
	
	// Set the boss
	SetTankPercent(p_iRequestedPercent);
	
	// Let everybody know
	new String:clientName[32];
	GetClientName(client, clientName, sizeof(clientName));
	CPrintToChatAll("{blue}<{green}BossVote{blue}>{default} Tank spawn set to {olive}%i%%{default} by Admin {blue}%s{default}.", p_iRequestedPercent, clientName);
	
	// Update our shiz yo
	CreateTimer(0.1, GetBossPercents);
	CreateTimer(0.2, UpdateReadyUpFooter);
	
	// Forward da message man :)
	CreateTimer(0.5, UpdatedForward);
	return;
}

public Action:ForceWitchCommand(client, args)
{
	if (!GetConVarBool(g_hCvarBossVoting)) return;
	if (g_bIsRemix)
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Command not available on this map.");
		return;
	}
	
	if (IsStaticWitchMap())
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Witch spawn is static and can not be changed on this map.");
		return;
	}
	
	if (!IsInReady())
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Command can only be used during ready up.");
		return;
	}
	
	// Get Requested Witch Percent
	new String:bv_sWitch[32];
	GetCmdArg(1, bv_sWitch, 32);
	
	// Make sure the cmd argument is a number
	if (!IsInteger(bv_sWitch))
		return;
	
	// Convert it to in int boy
	int p_iRequestedPercent;
	p_iRequestedPercent = StringToInt(bv_sWitch);
	
	// Check if percent is within limits
	if (p_iRequestedPercent > 100 || p_iRequestedPercent < 0)
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss percent needs to be between {olive}0{default} and {olive}100{default}.");
		return;
	}
	
	// Set the boss
	SetWitchPercent(p_iRequestedPercent);
	
	// Let everybody know
	new String:clientName[32];
	GetClientName(client, clientName, sizeof(clientName));
	CPrintToChatAll("{blue}<{green}BossVote{blue}>{default} Witch spawn set to {olive}%i%%{default} by Admin {blue}%s{default}.", p_iRequestedPercent, clientName);
	
	// Update our shiz yo
	CreateTimer(0.1, GetBossPercents);
	CreateTimer(0.2, UpdateReadyUpFooter);
	
	// Forward da message man :)
	CreateTimer(0.5, UpdatedForward);
	return;
}