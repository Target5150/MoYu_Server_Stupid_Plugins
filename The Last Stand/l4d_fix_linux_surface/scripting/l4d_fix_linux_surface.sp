#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[L4D & 2] Fix Linux Surface",
	author = "Forgetest",
	description = "Tricky fix for surfaces with wrong attributes (i.e. friction) on linux dedicated servers.",
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

methodmap Address {}

int g_iOffs_CCollisionBSPData__map_surfaces;
int g_iOffs_CCollisionBSPData__numtextures;
// int g_iOffs_CCollisionBSPData__map_texturenames;

methodmap CRangeValidatedArray < Address
{
	public any At(int i, int size = 4)
	{
		return this.m_pArray + view_as<Address>(i*size);
	}

	property Address m_pArray
	{
		public get() { return LoadFromAddress(this, NumberType_Int32); }
	}
}

methodmap CCollisionBSPData < Address
{
	property CRangeValidatedArray map_surfaces
	{
		public get() { return view_as<CRangeValidatedArray>(this + view_as<Address>(g_iOffs_CCollisionBSPData__map_surfaces)); }
	}

	// property Address map_texturenames
	// {
	// 	public get() { return LoadFromAddress(this + view_as<Address>(g_iOffs_CCollisionBSPData__map_texturenames), NumberType_Int32); }
	// }

	property int numtextures
	{
		public get() { return LoadFromAddress(this + view_as<Address>(g_iOffs_CCollisionBSPData__numtextures), NumberType_Int32); }
	}
}

methodmap CSurface_t < Address
{
	property Address name
	{
		public get() { return LoadFromAddress(this, NumberType_Int32); }
	}
	property int surfaceProps
	{
		public get() { return LoadFromAddress(this + view_as<Address>(4), NumberType_Int16); }
		public set(int surfaceProps) { StoreToAddress(this + view_as<Address>(4), surfaceProps, NumberType_Int16); }
	}
	property int flags
	{
		public get() { return LoadFromAddress(this + view_as<Address>(6), NumberType_Int16); }
	}
}
CCollisionBSPData g_BSPData;

Address g_pPhysprops;
Handle g_Call_IPhysicsSurfaceProps_GetSurfaceIndex;
methodmap IPhysicsSurfaceProps
{
	public int GetSurfaceIndex(const char[] pSurfacePropName)
	{
		return SDKCall(g_Call_IPhysicsSurfaceProps_GetSurfaceIndex, this, pSurfacePropName);
	}
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_fix_linux_surface");

	g_BSPData = view_as<CCollisionBSPData>(gd.GetAddress("g_BSPData"));
	g_iOffs_CCollisionBSPData__map_surfaces = gd.GetOffset("CCollisionBSPData::map_surfaces");
	g_iOffs_CCollisionBSPData__numtextures = gd.GetOffset("CCollisionBSPData::numtextures");
	// g_iOffs_CCollisionBSPData__map_texturenames = gd.GetOffset("CCollisionBSPData::map_texturenames");

	g_pPhysprops = gd.GetAddress("physprops");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gd, SDKConf_Virtual, "IPhysicsSurfaceProps::GetSurfaceIndex");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_Call_IPhysicsSurfaceProps_GetSurfaceIndex = EndPrepSDKCall();

	delete gd;
}

public void OnMapStart()
{
	CRangeValidatedArray surfaces = g_BSPData.map_surfaces;
	IPhysicsSurfaceProps physprops = LoadFromAddress(g_pPhysprops, NumberType_Int32);

	// PrintToServer("g_BSPData.numtextures = %d", g_BSPData.numtextures);

	KeyValues kv = new KeyValues("");

	for (int i = g_BSPData.numtextures-1; i >= 0; --i)
	{
		CSurface_t surface = surfaces.At(i, 8);

		// if (surface.surfaceProps != 0)
		// 	continue;

		char path[PLATFORM_MAX_PATH] = "";
		if (surface.name)
			ReadMemoryString(surface.name, path, sizeof(path));
		
		if (!path[0])
			continue;
		
		StripExtension(path, sizeof(path));
		String_ToLower(path, sizeof(path));
		ReplaceString(path, sizeof(path), "\\", "/");
		Format(path, sizeof(path), "materials/%s.vmt", path);

		kv.JumpToKey("vmt", true);
		if (LoadVMTFile(kv, path))
		{
			char prop[64];
			kv.GetString("$surfaceprop", prop, sizeof(prop));

			if (prop[0])
			{
				surface.surfaceProps = physprops.GetSurfaceIndex(prop);
			}

			// PrintToServer("#%d surface (#%d) [%s] [%s]", i, surface.surfaceProps, path, prop);
		}
		kv.DeleteThis();
	}

	delete kv;
}


//-----------------------------------------------------------------------------
// VMT parser
// https://github.com/VSES/SourceEngine2007/blob/43a5c90a5ada1e69ca044595383be67f40b33c61/src_main/materialsystem/cmaterial.cpp#L3051-L3203
//-----------------------------------------------------------------------------
void InsertKeyValues(KeyValues dest, KeyValues src, bool bCheckForExistence)
{
	if (!src.GotoFirstSubKey(false))
		return;

	char buffer[512];
	do
	{
		src.GetSectionName(buffer, sizeof(buffer));
		if (!dest.JumpToKey(buffer, !bCheckForExistence))
			continue;

		switch (src.GetDataType(NULL_STRING))
		{
			case KvData_String:
			{
				src.GetString(NULL_STRING, buffer, sizeof(buffer));
				dest.SetString(NULL_STRING, buffer);
			}
			case KvData_Int, KvData_Ptr: dest.SetNum(NULL_STRING, src.GetNum(NULL_STRING));
			case KvData_Float: dest.SetFloat(NULL_STRING, src.GetFloat(NULL_STRING));
		}

		dest.GoBack(); // dest.JumpToKey(buffer, !bCheckForExistence)
	}
	while (src.GotoNextKey(false));

	src.GoBack(); // src.GotoFirstSubKey(false))

	if (bCheckForExistence && dest.GotoFirstSubKey(true))
	{
		do
		{
			dest.GetSectionName(buffer, sizeof(buffer));
			if (!src.JumpToKey(buffer))
				continue;
			
			if (src.GetDataType(NULL_STRING) != KvData_None)
			{
				InsertKeyValues(dest, src, bCheckForExistence);
			}

			src.GoBack(); // src.JumpToKey(buffer)
		}
		while (dest.GotoNextKey(true));

		dest.GoBack(); // dest.GotoFirstSubKey(true)
	}
}

void ApplyPatchKeyValues(KeyValues kv, KeyValues patches)
{
	if (patches.JumpToKey("insert"))
	{
		InsertKeyValues(kv, patches, false);
		patches.GoBack();
	}

	if (patches.JumpToKey("replace"))
	{
		InsertKeyValues(kv, patches, true);
		patches.GoBack();
	}
}

void ExpandPatchFile(KeyValues kv)
{
	char buffer[512];
	KeyValues patches = new KeyValues("");

	int count = 0;
	while (count < 10 && kv.GetSectionName(buffer, sizeof(buffer)) && !strcmp(buffer, "patch"))
	{
		ApplyPatchKeyValues(kv, patches);
		patches.Import(kv);

		kv.GetString("include", buffer, sizeof(buffer));
		kv.DeleteKey("include");
		if (!buffer[0])
		{
			LogError(" ExpandPatchFile: VMT patch file has no $include key - invalid! ");
			return;
		}

		kv.DeleteThis();
		kv.JumpToKey("vmt", true);

		if (!kv.ImportFromFile(buffer))
		{
			LogError(" ExpandPatchFile: Failed to import VMT file ");
			return;
		}
	}

	ApplyPatchKeyValues(kv, patches);
	delete patches;
}

bool LoadVMTFile(KeyValues kv, const char[] file)
{
	if (!kv.ImportFromFile(file))
		return false;
	
	ExpandPatchFile(kv);
	return true;
}

bool StripExtension(char[] str, int maxlength)
{
	int end = Math_Min(strlen(str), maxlength) - 1;

	while (end > 0 && str[end] != '.' && str[end] != '\\' && str[end] != '/')
	{
		--end;
	}

	if (end > 0 && str[end] != '\\' && str[end] != '/')
	{
		str[end] = '\0';
		return true;
	}

	return false;
}

stock void ReadMemoryString(Address src, char[] dest, int maxlength)
{
	int i = 0;
	char c = LoadFromAddress(src, NumberType_Int8);
	while (c && i < maxlength-1)
	{
		dest[i] = c;
		++i;
		c = LoadFromAddress(src + view_as<Address>(i), NumberType_Int8);
	}
	dest[i] = 0;
}

stock any Math_Min(any a, any b)
{
	return a < b ? a : b;
}

// from l4d2util_stocks.inc thanks to @A1mDev
stock void String_ToLower(char[] str, const int MaxSize)
{
	int iSize = strlen(str); //Сounts string length to zero terminator

	for (int i = 0; i < iSize && i < MaxSize; i++) { //more security, so that the cycle is not endless
		if (IsCharUpper(str[i])) {
			str[i] = CharToLower(str[i]);
		}
	}

	str[iSize] = '\0';
}
