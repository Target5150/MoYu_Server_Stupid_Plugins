#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D2] Rock Trace Patch",
	author = "Forgetest",
	description = "Prevent SIs from blocking the rock radius check.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define JMP_NEAR_LEN 5
#define MOV_INDIRECT_REG_IMM32_LEN 10

#define GAMEDATA_FILE "l4d2_rock_trace_patch"
#define KEY_CTORCALL "ForEachPlayer_ProximityThink__TraceFilter_ctorCall"
#define KEY_CTORSTACKPTR "ForEachPlayer_ProximityThink__TraceFilter_ctorStackPtr"
#define KEY_VTABLEPTR "CVomit::UpdateAbility__NoInfectedTeamOrGhosts_vtablePtr"

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (!conf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	MemoryPatch hPatch = MemoryPatch.CreateFromConf(conf, KEY_CTORCALL);
	if (!hPatch.Validate()) SetFailState("Failed to validate patch \""...KEY_CTORCALL..."\"");
	
	// relative addressing `CTraceFilterSimpleList()`
	Address addy = hPatch.Address + view_as<Address>(JMP_NEAR_LEN)
					+ LoadFromAddress(hPatch.Address + view_as<Address>(1), NumberType_Int32);
	
	MemoryBlock hAlloc = new MemoryBlock(MOV_INDIRECT_REG_IMM32_LEN + JMP_NEAR_LEN * 2);
	
	// Patch original call to a jump to our block
	if (!hPatch.Enable()) SetFailState("Failed to enable patch \""...KEY_CTORCALL..."\"");
	PatchNearJump(0xE9, hPatch.Address, hAlloc.Address);
	
	// First call the constructor
	PatchNearJump(0xE8, hAlloc.Address, addy); 
	
	// Then change its virtual function `ShouldHitEntity`
	// mov [ebp+?], imm32
	hAlloc.StoreToOffset(JMP_NEAR_LEN, 0xC7, NumberType_Int8);
	hAlloc.StoreToOffset(JMP_NEAR_LEN + 1, 0x85, NumberType_Int8);
	
	addy = GameConfGetAddress(conf, KEY_CTORSTACKPTR);
	if (addy == Address_Null) SetFailState("Failed to get address \""...KEY_CTORSTACKPTR..."\"");
	hAlloc.StoreToOffset(JMP_NEAR_LEN + 2, view_as<int>(addy), NumberType_Int32);
	
	addy = GameConfGetAddress(conf, KEY_VTABLEPTR);
	if (addy == Address_Null) SetFailState("Failed to get address \""...KEY_VTABLEPTR..."\"");
	hAlloc.StoreToOffset(JMP_NEAR_LEN + 6, view_as<int>(addy), NumberType_Int32);
	
	// Finally go back
	PatchNearJump(0xE9, hAlloc.Address + view_as<Address>(MOV_INDIRECT_REG_IMM32_LEN + JMP_NEAR_LEN), hPatch.Address + view_as<Address>(JMP_NEAR_LEN));
}

void PatchNearJump(int instruction, Address src, Address dest)
{
	StoreToAddress(src, instruction, NumberType_Int8);
	StoreToAddress(src + view_as<Address>(1), view_as<int>(dest - src) - 5, NumberType_Int32);
}