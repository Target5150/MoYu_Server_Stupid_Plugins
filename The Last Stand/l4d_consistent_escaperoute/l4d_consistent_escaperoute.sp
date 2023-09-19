#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.1.2"

public Plugin myinfo =
{
	name = "[L4D & 2] Consistent Escape Route",
	author = "Forgetest",
	description = "True L4D.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	public Address GetAddressOrFail(const char[] key) {
		Address addr = this.GetAddress(key);
		if (addr == Address_Null) SetFailState("Missing address \"%s\"", key);
		return addr;
	}
	public int GetOffsetOrFail(const char[] key) {
		int offset = this.GetOffset(key);
		if (offset == -1) SetFailState("Missing offset \"%s\"", key);
		return offset;
	}
}

int g_iOffs_m_nMainPathAreaCount, g_iOffs_m_flowToGoal, g_iOffs_m_flMapMaxFlowDistance;
Handle g_hSDKCall_ResetPath, g_hSDKCall_AddArea, g_hSDKCall_FinishPath;

methodmap CEscapeRoute
{
	public CEscapeRoute(Address addr) {
		return view_as<CEscapeRoute>(addr);
	}
	
	public void ResetPath() {
		SDKCall(g_hSDKCall_ResetPath, this);
	}
	
	public void AddArea(TerrorNavArea area) {
		SDKCall(g_hSDKCall_AddArea, this, area);
	}
	
	public void FinishPath() {
		SDKCall(g_hSDKCall_FinishPath, this);
	}
	
	public TerrorNavArea GetMainPathArea(int index) {
		return LoadFromAddress(view_as<Address>(this)
							+ view_as<Address>(g_iOffs_m_nMainPathAreaCount + 8)
							+ view_as<Address>(index * 4),
							NumberType_Int32);
	}
	
	property int m_nMainPathAreaCount {
		public get() { return LoadFromAddress(view_as<Address>(this)
										+ view_as<Address>(g_iOffs_m_nMainPathAreaCount),
										NumberType_Int32); }
	}
}

methodmap CUtlVector
{
	public int Size() {
		return LoadFromAddress(view_as<Address>(this) + view_as<Address>(12), NumberType_Int32);
	}
	
	property Address m_pElements {
		public get() { return LoadFromAddress(view_as<Address>(this), NumberType_Int32); }
	}
}

methodmap NavAreaVector < CUtlVector
{
	public NavAreaVector(Address addr) {
		return view_as<NavAreaVector>(addr);
	}
	
	public TerrorNavArea At(int index) {
		return LoadFromAddress(this.m_pElements + view_as<Address>(index * 4), NumberType_Int32);
	}
}

methodmap TerrorNavArea
{
	public TerrorNavArea(Address addr) {
		return view_as<TerrorNavArea>(addr);
	}
	
	public int GetID() {
		return L4D_GetNavAreaID(view_as<Address>(this));
	}
	
	public void RemoveSpawnAttributes(int flag) {
		int spawnAttributes = L4D_GetNavArea_SpawnAttributes(view_as<Address>(this));
		L4D_SetNavArea_SpawnAttributes(view_as<Address>(this), spawnAttributes & ~flag);
	}
	
	property float m_flowToGoal {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_flowToGoal), NumberType_Int32); }
		public set(float flow) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_flowToGoal), flow, NumberType_Int32); }
	}
	
	property float m_flowFromStart {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_flowToGoal + 4), NumberType_Int32); }
		public set(float flow) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_flowToGoal + 4), flow, NumberType_Int32); }
	}
}

methodmap TerrorNavMesh
{
	public TerrorNavArea GetNavAreaByID(int id) {
		return view_as<TerrorNavArea>(L4D_GetNavAreaByID(id));
	}
	
	property float m_flMapMaxFlowDistance {
		public get() { return LoadFromAddress(L4D_GetPointer(POINTER_NAVMESH) + view_as<Address>(g_iOffs_m_flMapMaxFlowDistance), NumberType_Int32); }
		public set(float flow) { StoreToAddress(L4D_GetPointer(POINTER_NAVMESH) + view_as<Address>(g_iOffs_m_flMapMaxFlowDistance), flow, NumberType_Int32); }
	}
}

CEscapeRoute g_spawnPath;
Address g_pSpawnPath;

NavAreaVector TheNavAreas;
TerrorNavMesh TheNavMesh;

ArrayList g_aSpawnPathAreas;

enum
{
	NAV_AREA_ID,
	FLOW_TO_GOAL,
	FLOW_FROM_START,
	
	NUM_OF_FLOW_INFO
}
ArrayList g_aAreaFlows;

float g_flMapMaxFlowDistance;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_consistent_escaperoute");
	
	g_pSpawnPath = gd.GetAddressOrFail("TheEscapeRoute");
	
	g_iOffs_m_nMainPathAreaCount = gd.GetOffsetOrFail("CEscapeRoute::m_nMainPathAreaCount");
	g_iOffs_m_flowToGoal = gd.GetOffsetOrFail("TerrorNavArea::m_flowToGoal");
	g_iOffs_m_flMapMaxFlowDistance = gd.GetOffsetOrFail("TerrorNavMesh::m_flMapMaxFlowDistance");
	
	StartPrepSDKCall(SDKCall_Raw);
	if ( PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "CEscapeRoute::ResetPath") == false )
		SetFailState("Missing signature \"CEscapeRoute::ResetPath\"");
	g_hSDKCall_ResetPath = EndPrepSDKCall();
	if (g_hSDKCall_ResetPath == null)
		SetFailState("Failed to create SDKCall \"CEscapeRoute::ResetPath\"");
	
	StartPrepSDKCall(SDKCall_Raw);
	if ( PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "CEscapeRoute::AddArea") == false )
		SetFailState("Missing signature \"CEscapeRoute::AddArea\"");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // TerrorNavArea
	g_hSDKCall_AddArea = EndPrepSDKCall();
	if (g_hSDKCall_AddArea == null)
		SetFailState("Failed to create SDKCall \"CEscapeRoute::AddArea\"");
	
	StartPrepSDKCall(SDKCall_Raw);
	if ( PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "CEscapeRoute::FinishPath") == false )
		SetFailState("Missing signature \"CEscapeRoute::FinishPath\"");
	g_hSDKCall_FinishPath = EndPrepSDKCall();
	if (g_hSDKCall_FinishPath == null)
		SetFailState("Failed to create SDKCall \"CEscapeRoute::FinishPath\"");
	
	delete gd;
	
	g_aSpawnPathAreas = new ArrayList();
	g_aAreaFlows = new ArrayList(NUM_OF_FLOW_INFO);
	
	HookEvent("round_start_post_nav", Event_RoundStartPostNav);
}

void Event_RoundStartPostNav(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.1, Timer_RoundStartPostNav, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_RoundStartPostNav(Handle timer)
{
	if (!L4D_IsVersusMode())
		return Plugin_Stop;
	
	g_spawnPath = LoadFromAddress(g_pSpawnPath, NumberType_Int32);
	TheNavAreas = NavAreaVector(L4D_GetPointer(POINTER_THENAVAREAS));
	
	if (InSecondHalfOfRound())
	{
		if (g_aAreaFlows.Length)
		{
			for (int i = 0; i < g_aAreaFlows.Length; ++i)
			{
				TerrorNavArea area = TheNavMesh.GetNavAreaByID(g_aAreaFlows.Get(i, NAV_AREA_ID));
				area.m_flowToGoal = g_aAreaFlows.Get(i, FLOW_TO_GOAL);
				area.m_flowFromStart = g_aAreaFlows.Get(i, FLOW_FROM_START);
			}
			
			TheNavMesh.m_flMapMaxFlowDistance = g_flMapMaxFlowDistance;
		}
		
		if (g_aSpawnPathAreas.Length)
		{
			for (int i = 0; i < g_spawnPath.m_nMainPathAreaCount; ++i)
			{
				TerrorNavArea area = g_spawnPath.GetMainPathArea(i);
				area.RemoveSpawnAttributes(NAV_SPAWN_ESCAPE_ROUTE);
			}
			
			PrintToServer("[l4d_consistent_escaperoute] Second half (%i / %i nav) (%.5f)", g_spawnPath.m_nMainPathAreaCount, TheNavAreas.Size(), g_flMapMaxFlowDistance);
			
			g_spawnPath.ResetPath();
			
			for (int i = 0; i < g_aSpawnPathAreas.Length; ++i)
			{
				int id = g_aSpawnPathAreas.Get(i);
				
				TerrorNavArea area = TheNavMesh.GetNavAreaByID(id);
				g_spawnPath.AddArea(area);
			}
			
			g_spawnPath.FinishPath();
		}
		
		PrintToServer("[l4d_consistent_escaperoute] Restored escape route from last half (%i / %i nav)", g_aSpawnPathAreas.Length, TheNavAreas.Size());
	}
	else
	{
		g_aSpawnPathAreas.Clear();
		g_aAreaFlows.Clear();
		
		for (int i = 0; i < g_spawnPath.m_nMainPathAreaCount; ++i)
		{
			TerrorNavArea area = g_spawnPath.GetMainPathArea(i);
			g_aSpawnPathAreas.Push(area.GetID());
		}
		
		g_aAreaFlows.Resize(TheNavAreas.Size());
		for (int i = 0; i < TheNavAreas.Size(); ++i)
		{
			TerrorNavArea area = TheNavAreas.At(i);
			g_aAreaFlows.Set(i, area.GetID(), NAV_AREA_ID);
			g_aAreaFlows.Set(i, area.m_flowToGoal, FLOW_TO_GOAL);
			g_aAreaFlows.Set(i, area.m_flowFromStart, FLOW_FROM_START);
		}
		
		g_flMapMaxFlowDistance = TheNavMesh.m_flMapMaxFlowDistance;
		
		PrintToServer("[l4d_consistent_escaperoute] Cached escape route of first half (%i / %i nav) (%.5f)", g_aSpawnPathAreas.Length, TheNavAreas.Size(), g_flMapMaxFlowDistance);
	}
	
	return Plugin_Stop;
}

stock bool InSecondHalfOfRound()
{
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}
