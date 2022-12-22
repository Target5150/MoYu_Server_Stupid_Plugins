#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D2] SG552 Rate of Fire Patch",
	author = "Forgetest",
	description = "Restore normal rate of fire on scoping.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

#define GAMEDATA_FILE "l4d2_sg552_firerate_patch"
#define GAMEDATA_TEMP_FILE "l4d2_sg552_firerate_patch.temp"

Address g_pfnGetRateOfFire;

public void OnPluginStart()
{
	GameData gc = new GameData(GAMEDATA_FILE);
	if (!gc)
		SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
	
	int os = gc.GetOffset("OS");
	if (os == -1)
		SetFailState("Missing offset \"OS\"");
	
	Address pflFireRate = gc.GetMemSig("0.13500001");
	if (pflFireRate == Address_Null)
		SetFailState("Missing signature \"0.13500001\"");
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/"...GAMEDATA_TEMP_FILE...".txt");
	
	File f = OpenFile(sPath, "w");
	
	char buffer[128];
	if (!gc.GetKeyValue("temp_sig_pattern", buffer, sizeof(buffer)))
		SetFailState("Missing key \"temp_sig_pattern\"");
	
	int len = strlen(buffer);
	AddressToSignature(pflFireRate, buffer[len], sizeof(buffer) - len);
	
	f.WriteLine("\"Games\"");
	f.WriteLine("{");
	f.WriteLine("	\"left4dead2\"");
	f.WriteLine("	{");
	f.WriteLine("		\"Signatures\"");
	f.WriteLine("		{");
	f.WriteLine("			\"temp_sig\"");	
	f.WriteLine("			{");
	f.WriteLine("				\"library\"		\"server\"");	
	f.WriteLine("				\"%s\"		\"%s\"", os ? "linux" : "windows", buffer);
	f.WriteLine("			}");
	f.WriteLine("		}");
	f.WriteLine("	}");
	f.WriteLine("}");
	f.Flush();
	
	delete f;
	delete gc;
	
	gc = new GameData(GAMEDATA_TEMP_FILE);
	
	g_pfnGetRateOfFire = gc.GetMemSig("temp_sig");
	if (g_pfnGetRateOfFire == Address_Null)
		SetFailState("Failed to get function address from temp sig");
	
	delete gc;
	
	if (!DeleteFile(sPath))
		SetFailState("Failed to delete file (%s)", sPath);
	
	TogglePatchJump(true);
}

public void OnPluginEnd()
{
	TogglePatchJump(false);
}

void TogglePatchJump(bool toggle)
{
	static bool state = false;
	static int orig_byte = -1;
	
	if (toggle == state)
		return;
	
	if (toggle)
	{
		int byte = LoadFromAddress(g_pfnGetRateOfFire, NumberType_Int8);
		switch (byte)
		{
			case 0x74: StoreToAddress(g_pfnGetRateOfFire, 0xEB, NumberType_Int8);
			case 0x75: StoreToAddress(g_pfnGetRateOfFire, 0x9090, NumberType_Int16);
			default:
			{
				SetFailState("Unexpected byte 0x%X for jump patch", byte);
			}
		}
		
		state = true;
		orig_byte = byte;
	}
	else if (orig_byte != -1)
	{
		StoreToAddress(g_pfnGetRateOfFire, orig_byte, NumberType_Int8);
		state = false;
		orig_byte = -1;
	}
}

void AddressToSignature(Address addr, char[] buffer, int maxlength)
{
	for (int i = 0; i < 4; ++i)
	{
		FormatEx(buffer[i * 4], maxlength - i * 4, "\\x%X", ((view_as<int>(addr) >> (i * 8)) & 0xFF));
	}
}