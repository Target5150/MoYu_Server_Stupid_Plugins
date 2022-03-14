#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "2.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Tongue Bend Fix",
	author = "Forgetest",
	description = "Fix unexpected tongue breaks for \"bending too many times\".",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d_tongue_bend_fix"
#define KEY_FUNCTION "CTongue::OnUpdateAttachedToTargetState"
#define PATCH_SURFIX "__UpdateBend_jump_patch"

Address g_pAddr;

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (!conf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	int offs = GameConfGetOffset(conf, "OS");
	if (offs == -1) SetFailState("Missing offset \"OS\"");
	
	if (offs == 1) // linux
	{
		MemoryPatch hPatch = MemoryPatch.CreateFromConf(conf, KEY_FUNCTION...PATCH_SURFIX);
		if (hPatch.Enable()) return;
		
		SetFailState("Failed to enable patch \""...KEY_FUNCTION...PATCH_SURFIX..."\"");
	}
	
	g_pAddr = GameConfGetAddress(conf, "TongueState_StrFind");
	if (g_pAddr == Address_Null)
		SetFailState("Missing address \"TongueState_StrFind\"");
	
	delete conf;
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/"...GAMEDATA_FILE...".txt");
	
	File f = OpenFile(sPath, "rw");
	
	char buffer[64];
	while (f.ReadLine(buffer, sizeof(buffer)) && StrContains(buffer, "\"tongueStateInfo\"") == -1) {}
	if (f.EndOfFile())
		SetFailState("Missing signature frame \"tongueStateInfo\"");
	
	f.ReadLine(buffer, sizeof(buffer)); // "{"
	f.ReadLine(buffer, sizeof(buffer)); // "library" "server"
	
	int pos = f.Position;
	f.ReadLine(buffer, sizeof(buffer)); // "windows" ""
	if (StrContains(buffer, "\"windows\"") == -1)
		SetFailState("Incorrect formatted signature frame \"tongueStateInfo\"");
	
	f.Seek(pos, SEEK_SET);
	
	FormatEx(buffer, sizeof(buffer), "\x%X", view_as<int>(g_pAddr) & 0xFF);
	for (int i = 1; i < 4; ++i)
	{
		Format(buffer, sizeof(buffer), "%s\x%X", buffer, view_as<int>(g_pAddr) & (0xFF << (8*i)));
	}
	f.WriteLine("				\"windows\"		\"%s\"", buffer);
	
	f.Flush();
	delete f;
	
	conf = LoadGameConfigFile(GAMEDATA_FILE);
	
	g_pAddr = GameConfGetAddress(conf, KEY_FUNCTION);
	if (g_pAddr == Address_Null || (g_pAddr = LoadFromAddress(g_pAddr, NumberType_Int32)) == Address_Null)
		SetFailState("Failed to generate address of \""...KEY_FUNCTION..."\"");
	
	offs = GameConfGetOffset(conf, KEY_FUNCTION...PATCH_SURFIX);
	if (offs == -1)
		SetFailState("Missing offset \""...KEY_FUNCTION...PATCH_SURFIX..."\"");
	
	g_pAddr += view_as<Address>(offs);
	
	delete conf;
	
	ApplyPatch(true);
}

public void OnPluginEnd()
{
	ApplyPatch(false);
}

void ApplyPatch(bool patch)
{
	static bool patched = false;
	if (patch && !patched)
	{
		if (LoadFromAddress(g_pAddr, NumberType_Int8) != 0x0F || LoadFromAddress(g_pAddr + view_as<Address>(1), NumberType_Int8) != 0x84)
			SetFailState("Failed to validate patch \""...KEY_FUNCTION...PATCH_SURFIX..."\"");
		
		StoreToAddress(g_pAddr, 0x90, NumberType_Int8);
		StoreToAddress(g_pAddr + view_as<Address>(1), 0xEB, NumberType_Int8);
	}
	else if (!patch && patched)
	{
		StoreToAddress(g_pAddr, 0x0F, NumberType_Int8);
		StoreToAddress(g_pAddr + view_as<Address>(1), 0x84, NumberType_Int8);
	}
}