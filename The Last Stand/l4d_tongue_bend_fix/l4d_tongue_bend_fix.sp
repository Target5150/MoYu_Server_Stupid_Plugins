#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "2.1"

public Plugin myinfo =
{
	name = "[L4D & 2] Tongue Bend Fix",
	author = "Forgetest",
	description = "Fix unexpected tongue breaks for \"bending too many times\".",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

#define GAMEDATA_FILE "l4d_tongue_bend_fix"
#define GAMEDATA_TEMP "l4d_tongue_bend_fix_temp"
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
	
	offs = GameConfGetOffset(conf, KEY_FUNCTION...PATCH_SURFIX);
	if (offs == -1)
		SetFailState("Missing offset \""...KEY_FUNCTION...PATCH_SURFIX..."\"");
	
	g_pAddr = GameConfGetAddress(conf, "TongueState_StrFind");
	if (g_pAddr == Address_Null)
		SetFailState("Missing address \"TongueState_StrFind\"");
	
	delete conf;
	
	char buffer[20], sBytes[32];
	FormatEx(buffer, sizeof(buffer), "%X", g_pAddr);
	ReverseAddress(buffer, sBytes);
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/"...GAMEDATA_TEMP...".txt");
	
	File hFile = OpenFile(sPath, "w", false);
	
	hFile.WriteLine("\"Games\"");
	hFile.WriteLine("{");
	hFile.WriteLine("	\"#default\"");
	hFile.WriteLine("	{");
	hFile.WriteLine("		\"Addresses\"");
	hFile.WriteLine("		{");
	hFile.WriteLine("			\"CTongue::OnUpdateAttachedToTargetState\"");
	hFile.WriteLine("			{");
	hFile.WriteLine("				\"windows\"");
	hFile.WriteLine("				{");
	hFile.WriteLine("					\"signature\"	\"tongueStateInfo\"");
	hFile.WriteLine("					\"read\"		\"56\"");
	hFile.WriteLine("				}");
	hFile.WriteLine("			}");
	hFile.WriteLine("		}");
	hFile.WriteLine("		\"Signatures\"");
	hFile.WriteLine("		{");
	hFile.WriteLine("			\"tongueStateInfo\"");
	hFile.WriteLine("			{");
	hFile.WriteLine("				\"library\"		\"server\"");
	hFile.WriteLine("				\"windows\"		\"%s\"", sBytes);
	hFile.WriteLine("			}");
	hFile.WriteLine("		}");
	hFile.WriteLine("	}");
	hFile.WriteLine("}");
	
	FlushFile(hFile);
	delete hFile;
	
	conf = LoadGameConfigFile(GAMEDATA_TEMP);
	
	g_pAddr = GameConfGetAddress(conf, KEY_FUNCTION);
	if (g_pAddr == Address_Null)
		SetFailState("Failed to generate address of \""...KEY_FUNCTION..."\"");
	
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

// From left4dhooks, credit to Silvers.
void ReverseAddress(const char[] sBytes, char sReturn[32])
{
	sReturn[0] = 0;
	char sByte[3];
	for( int i = strlen(sBytes) - 2; i >= -1 ; i -= 2 )
	{
		strcopy(sByte, i >= 1 ? 3 : i + 3, sBytes[i >= 0 ? i : 0]);

		StrCat(sReturn, sizeof(sReturn), "\\x");
		if( strlen(sByte) == 1 )
			StrCat(sReturn, sizeof(sReturn), "0");
		StrCat(sReturn, sizeof(sReturn), sByte);
	}
}
