#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sourcescramble>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Reachable Patch",
	author = "Forgetest",
	description = "Provide \"SurvivorBot::IsReachable\" for non-bot targets.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	property GameData Super {
		public get() { return view_as<GameData>(this); }
	}
	public int GetOffset(const char[] key) {
		int offset = this.Super.GetOffset(key);
		if (offset == -1) SetFailState("Missing offset \"%s\"", key);
		return offset;
	}
	public Address GetAddress(const char[] key) {
		Address ptr = this.Super.GetAddress(key);
		if (ptr == Address_Null) SetFailState("Missing address \"%s\"", key);
		return ptr;
	}
}

enum struct SurvivorBotPathCost
{
	Address vtable;
	Address nextbot;
	Address locomotion;
	char unk;
	char unk2;
}

enum struct SurvivorTeamSituation
{
	int pad[34];			// 0
	int m_hTeammates[4];	// 136
	int pad2[11];			
	int m_iTeammateCount;	// 196
}

Address g_pFakeBot;
Address g_pFakeSurvivorBotPathCost;
Handle g_hCall_NavAreaBuildPath_SurvivorBotPathCost;
Handle g_hCall_IsReachable;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("L4D_SurvivorBot_NavAreaBuildPath", Ntv_SurvivorBot_NavAreaBuildPath);
	CreateNative("L4D_SurvivorBot_IsReachable", Ntv_SurvivorBot_IsReachable);
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_reachable_patch");

	int iOffs_m_iTeammateCount = SurvivorTeamSituation::m_iTeammateCount * 4;

	// offset to the NextBot vtable
	int iOffs_INextBot = gd.GetOffset("SurvivorBot::INextBot");
	int iOffs_m_locomotor= gd.GetOffset("SurvivorBot::m_locomotor");
	int size = gd.GetOffset("SurvivorBot::m_TeamSituation");

	MemoryBlock pFakeLocomotion = new MemoryBlock(4);
	pFakeLocomotion.StoreToOffset(0, view_as<int>(gd.GetAddress("`vtable for'SurvivorLocomotion")), NumberType_Int32);

	MemoryBlock pFakeBot = new MemoryBlock(size + iOffs_m_iTeammateCount + 4);
	pFakeBot.StoreToOffset(iOffs_INextBot, view_as<int>(gd.GetAddress("`vtable for'SurvivorBot")), NumberType_Int32);
	pFakeBot.StoreToOffset(iOffs_m_locomotor, view_as<int>(pFakeLocomotion.Address), NumberType_Int32);
	pFakeBot.StoreToOffset(size + iOffs_m_iTeammateCount, 0, NumberType_Int32);

	g_pFakeBot = pFakeBot.Address;

	int os = gd.GetOffset("OS");

	if (os != 1 || GetEngineVersion() != Engine_Left4Dead)
	{
		MemoryBlock pMem = new MemoryBlock(14); // sizeof(SurvivorBotPathCost)
												// well for the fuck's sake the above equals 5 so cannot just use it
		pMem.StoreToOffset(0, view_as<int>(gd.GetAddress("`vtable for'SurvivorBotPathCost")), NumberType_Int32);
		pMem.StoreToOffset(4, view_as<int>(pFakeBot.Address) + iOffs_INextBot, NumberType_Int32);
		pMem.StoreToOffset(8, view_as<int>(pFakeLocomotion.Address), NumberType_Int32);
		pMem.StoreToOffset(12, 0, NumberType_Int8);
		pMem.StoreToOffset(13, 1, NumberType_Int8);

		g_pFakeSurvivorBotPathCost = pMem.Address;

		// pointer to an offset used for instruction "call"
		Address pFunc = gd.GetAddress("NavAreaBuildPath<SurvivorBotPathCost>");
		int offset = LoadFromAddress(pFunc, NumberType_Int32);
		pFunc += view_as<Address>(offset + 4); // how "jmp" works

		// see "NavAreaBuildPath_SurvivorBotPathCost"
		StartPrepSDKCall(SDKCall_Static);
		PrepSDKCall_SetAddress(pFunc);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		if (GetEngineVersion() == Engine_Left4Dead2)
			PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
		g_hCall_NavAreaBuildPath_SurvivorBotPathCost = EndPrepSDKCall();
	}

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "SurvivorBot::IsReachable");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hCall_IsReachable = EndPrepSDKCall();

	delete gd;
}

any Ntv_SurvivorBot_NavAreaBuildPath(Handle plugin, int numParams)
{
	float goalPos[3];
	GetNativeArray(3, goalPos, sizeof(goalPos));
	Address closestArea = GetNativeCellRef(4);

	bool result = NavAreaBuildPath_SurvivorBotPathCost(
		GetNativeCell(1),
		GetNativeCell(2),
		IsNativeParamNullVector(3) ? NULL_VECTOR : goalPos,
		closestArea,
		GetNativeCell(5),
		GetNativeCell(6),
		GetNativeCell(7)
	);

	SetNativeCellRef(4, closestArea);
	return result;
}

any Ntv_SurvivorBot_IsReachable(Handle plugin, int numParams)
{
	return IsReachable(GetNativeCell(1), GetNativeCell(2));
}

bool NavAreaBuildPath_SurvivorBotPathCost(
		any startArea,
		any goalArea,
		const float goalPos[3] = NULL_VECTOR,
		Address &closestArea = Address_Null,
		float maxPathLength = 0.0,
		int teamID = -1,
		bool ignoreNavBlockers = false)
{
	if (GetEngineVersion() == Engine_Left4Dead2)
		return SDKCall(g_hCall_NavAreaBuildPath_SurvivorBotPathCost, startArea, goalArea, NULL_VECTOR, goalPos, g_pFakeSurvivorBotPathCost, closestArea, maxPathLength, teamID, ignoreNavBlockers);
	else
		return SDKCall(g_hCall_NavAreaBuildPath_SurvivorBotPathCost, startArea, goalArea, goalPos, g_pFakeSurvivorBotPathCost, closestArea, maxPathLength, teamID, ignoreNavBlockers);
}

bool IsReachable(any startArea, any goalArea)
{
	return SDKCall(g_hCall_IsReachable, g_pFakeBot, startArea, goalArea);
}