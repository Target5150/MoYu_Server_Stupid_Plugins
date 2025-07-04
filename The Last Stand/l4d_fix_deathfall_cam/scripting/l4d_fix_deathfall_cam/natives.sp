#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

void Natives_Init()
{
	CreateNative("L4D_ReleaseFromViewControl", Ntv_ReleaseFromViewControl);
}

static any Ntv_ReleaseFromViewControl(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	
	if (!IsClientInGame(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) not in-game", client);

	return ReleaseFromViewControl(client);
}