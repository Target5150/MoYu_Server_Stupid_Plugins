#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Ghost Checkpoint Spawn",
	author = "Forgetest",
	description = "Changes to conditions for ghost spawning in start areas.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d_ghost_checkpoint_spawn"
#define PATCH_INITIAL_CHECKPOINT "CTerrorPlayer::OnPreThinkGhostState__GetInitialCheckpoint_patch"
#define OFFSET_LAST_SURVIVOR_LEFT_START_AREA "CDirector::m_bLastSurvivorLeftStartArea"

#define OPCODE_CALL_NEAR 0xE8

enum struct L4D1CheckpointSpawnPatch
{
	MemoryPatch m_patches[2];
	Address m_pfnGetLastCheckpoint;
	
	void Init(GameData conf) {
		this.m_patches[0] = MemoryPatch.CreateFromConf(conf, PATCH_INITIAL_CHECKPOINT);
		this.m_patches[1] = MemoryPatch.CreateFromConf(conf, PATCH_INITIAL_CHECKPOINT..."2");
		
		if (!this.m_patches[0].Validate() || !this.m_patches[1].Validate())
			SetFailState("Failed to validate patch \""...PATCH_INITIAL_CHECKPOINT..."\"");
		
		this.m_pfnGetLastCheckpoint = conf.GetMemSig("TerrorNavMesh::GetLastCheckpoint");
		if (this.m_pfnGetLastCheckpoint == Address_Null)
			SetFailState("Missing signature \"TerrorNavMesh::GetLastCheckpoint\"");
	}
	
	void Enable() {
		this.m_patches[0].Enable(), this.m_patches[1].Enable();
		PatchNearJump(OPCODE_CALL_NEAR, this.m_patches[0].Address, this.m_pfnGetLastCheckpoint);
		PatchNearJump(OPCODE_CALL_NEAR, this.m_patches[1].Address, this.m_pfnGetLastCheckpoint);
	}
	
	void Disable() {
		this.m_patches[0].Disable(), this.m_patches[1].Disable();
	}
}
L4D1CheckpointSpawnPatch g_L4D1SpawnPatch;

int g_iOffs_LastSurvivorLeftStartArea;
methodmap CDirector
{
	property bool m_bLastSurvivorLeftStartArea {
		public set(bool val) { StoreToAddress(L4D_GetPointer(POINTER_DIRECTOR) + view_as<Address>(g_iOffs_LastSurvivorLeftStartArea), view_as<int>(val), NumberType_Int32); }
	}
}
CDirector TheDirector;

bool g_bIntroCondition, g_bGlobalCondition;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	return APLRes_Success;
}

public void OnPluginStart()
{
	bool bLeft4Dead2;
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: bLeft4Dead2 = false;
		case Engine_Left4Dead2: bLeft4Dead2 = true;
		default:
		{
			SetFailState("Plugin supports L4D & 2 only");
		}
	}
	
	GameData conf = new GameData(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	if (!bLeft4Dead2)
		g_L4D1SpawnPatch.Init(conf);
	
	g_iOffs_LastSurvivorLeftStartArea = conf.GetOffset(OFFSET_LAST_SURVIVOR_LEFT_START_AREA);
	if (g_iOffs_LastSurvivorLeftStartArea == -1)
		SetFailState("Missing offset \""...OFFSET_LAST_SURVIVOR_LEFT_START_AREA..."\"");
	
	delete conf;
	
	ConVar cv;
	cv = CreateConVar("z_ghost_unrestricted_spawn_in_start",
							"0",
							"Allow ghost to materialize in start saferoom even if not all survivors leave.\n"
						...	"0 = Disable, 1 = Intro maps only, 2 = All maps",
							FCVAR_SPONLY|FCVAR_NOTIFY,
							true, 0.0, true, 2.0);
	CVarChg_UnrestrictedSpawn(cv, "", "");
	cv.AddChangeHook(CVarChg_UnrestrictedSpawn);
	
	if (bLeft4Dead2)
		return;
	
	cv = CreateConVar("l4d1_ghost_spawn_in_start",
							"0",
							"L4D1 only. Allow ghost to materialize in start saferoom when all survivors leave.\n"
						...	"0 = Disable, 1 = Enable",
							FCVAR_SPONLY|FCVAR_NOTIFY,
							true, 0.0, true, 1.0);
	CVarChg_L4D1SpawnPatch(cv, "", "");
	cv.AddChangeHook(CVarChg_L4D1SpawnPatch);
}

void CVarChg_UnrestrictedSpawn(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int val = convar.IntValue;
	
	g_bIntroCondition = val == 1;
	g_bGlobalCondition = val == 2;
}

void CVarChg_L4D1SpawnPatch(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.BoolValue ? g_L4D1SpawnPatch.Enable() : g_L4D1SpawnPatch.Disable();
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	if (g_bGlobalCondition
		|| (L4D_IsFirstMapInScenario() && g_bIntroCondition)
	) {
		TheDirector.m_bLastSurvivorLeftStartArea = true;
	}
}

void PatchNearJump(int instruction, Address src, Address dest)
{
	StoreToAddress(src, instruction, NumberType_Int8);
	StoreToAddress(src + view_as<Address>(1), view_as<int>(dest - src) - 5, NumberType_Int32);
}