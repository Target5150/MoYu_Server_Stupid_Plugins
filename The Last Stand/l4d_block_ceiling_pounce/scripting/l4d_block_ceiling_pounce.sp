#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo =
{
	name = "[L4D & 2] Block Ceiling Pounce",
	author = "Forgetest",
	description = "Block infinite ceiling pounces.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	property GameData Super {
		public get() { return view_as<GameData>(this); }
	}
	public Address GetAddress(const char[] key) {
		Address ptr = this.Super.GetAddress(key);
		if (ptr == Address_Null) SetFailState("Missing address \"%s\"", key);
		return ptr;
	}
	public DynamicDetour CreateDetourOrFail(
			const char[] name,
			DHookCallback preHook = INVALID_FUNCTION,
			DHookCallback postHook = INVALID_FUNCTION) {
		DynamicDetour hSetup = DynamicDetour.FromConf(this, name);
		if (!hSetup)
			SetFailState("Missing detour setup \"%s\"", name);
		if (preHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Pre, preHook))
			SetFailState("Failed to pre-detour \"%s\"", name);
		if (postHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Post, postHook))
			SetFailState("Failed to post-detour \"%s\"", name);
		return hSetup;
	}
}

methodmap Address {}
methodmap CGameTrace < Address
{
	public void GetEndPosition(float vec[3]) {
		vec[0] = LoadFromAddress(this + view_as<Address>(12), NumberType_Int32);
		vec[1] = LoadFromAddress(this + view_as<Address>(16), NumberType_Int32);
		vec[2] = LoadFromAddress(this + view_as<Address>(20), NumberType_Int32);
	}

	property int surface_flags {
		public get() { return LoadFromAddress(this + view_as<Address>(66), NumberType_Int16); }
	}
}
CGameTrace g_TouchTrace;

bool g_bFirstCeiling[MAXPLAYERS+1];

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_block_ceiling_pounce");
	g_TouchTrace = view_as<CGameTrace>(gd.GetAddress("g_TouchTrace"));

	delete gd.CreateDetourOrFail("CLunge::OnTouch", _, DTR_OnTouch_Post);
	delete gd;

	HookEvent("pounce_end", Event_pounce_end);
}

// This one gets called also whenever a lunge begins.
void Event_pounce_end(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;
	
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (ability == -1 || GetEntPropFloat(ability, Prop_Send, "m_lungeAgainTimer", 1) > GetGameTime())
		return;
	
	g_bFirstCeiling[client] = true;
}

MRESReturn DTR_OnTouch_Post(int ability, DHookParam hParams)
{
	if (hParams.IsNull(1))
		return MRES_Ignored;

	int client = GetEntPropEnt(ability, Prop_Send, "m_owner");
    if (!IsClientInGame(client))
        return MRES_Ignored;
    
    float vPos[3], vTouch[3];
	GetClientAbsOrigin(client, vPos);
	g_TouchTrace.GetEndPosition(vTouch);

	if (vPos[2] < vTouch[2])
	{
		// TODO: We shouldn't assume the "ceiling" is always a skybox...
		//		But doing only "vPos[2] < vTouch[2]" gives us false positives when the hunter is falling.
		//		Low priority until there're actual issues.
		if (g_TouchTrace.surface_flags & (SURF_SKY2D|SURF_SKY))
		{
			if (!g_bFirstCeiling[client])
			{
				SetEntPropFloat(ability, Prop_Send, "m_lungeAgainTimer", -1.0, 1);
			}
			g_bFirstCeiling[client] = false;
		}
	}
    
	return MRES_Ignored;
}
