#include <sourcemod>
#include <dhooks>

public void OnPluginStart()
{
	GameData gd = new GameData("aggresive_specials_patch");
	
	int offset = gd.GetOffset("OS");
	
	if (offset == 0)
	{
		offset = gd.GetOffset("SpecialInfectedAssault__offset");
		Address pStr = gd.GetMemSig("SpecialInfectedAssault");
		
		delete gd;
		
		char sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/aggresive_specials_patch_temp.txt");
		File hFile = OpenFile(sPath, "w", false);
	
		char sAddress[512];
		char sHexAddr[32];
		
		FormatEx(sAddress, sizeof(sAddress), "%X", pStr);
		ReverseAddress(sAddress, sHexAddr);
		
		sAddress[0] = '\0';
		for( int x = 0; x < offset; x++ )
		{
			StrCat(sAddress, sizeof(sAddress), "\\x2A");
		}
		StrCat(sAddress, sizeof(sAddress), "\\x68");
		StrCat(sAddress, sizeof(sAddress), sHexAddr);
	
		hFile.WriteLine("\"Games\"");
		hFile.WriteLine("{");
		hFile.WriteLine("	\"#default\"");
		hFile.WriteLine("	{");
		hFile.WriteLine("		\"Signatures\"");
		hFile.WriteLine("		{");
		hFile.WriteLine("			\"CDirectorChallengeMode::SpecialsShouldAssault\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"library\"	\"server\"");
		hFile.WriteLine("				\"windows\"	\"%s\"", sAddress);
		hFile.WriteLine("			}");
		hFile.WriteLine("		}");
		hFile.WriteLine("	}");
		hFile.WriteLine("}");
		
		hFile.Flush();
		delete hFile;
		
		gd = new GameData("aggresive_specials_patch_temp");
	}
	
	DynamicDetour hDetour = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Int, ThisPointer_Ignore);
	hDetour.SetFromConf(gd, SDKConf_Signature, "CDirectorChallengeMode::SpecialsShouldAssault");
	hDetour.Enable(Hook_Pre, DTR_CDirectorChallengeMode__SpecialsShouldAssault);
	
	delete hDetour;
	delete gd;
}

MRESReturn DTR_CDirectorChallengeMode__SpecialsShouldAssault(DHookReturn hReturn)
{
	hReturn.Value = 1;
	return MRES_Supercede;
}

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
