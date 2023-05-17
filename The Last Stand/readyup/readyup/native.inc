#if defined _readyup_native_included
 #endinput
#endif
#define _readyup_native_included

#pragma semicolon 1
#pragma newdecls required

#include "readyup/player.inc"
#include "readyup/panel.inc"

void SetupNatives()
{
	CreateNative("AddStringToReadyFooter",	Native_AddStringToReadyFooter);
	CreateNative("EditFooterStringAtIndex", Native_EditFooterStringAtIndex);
	CreateNative("FindIndexOfFooterString", Native_FindIndexOfFooterString);
	CreateNative("GetFooterStringAtIndex",	Native_GetFooterStringAtIndex);
	CreateNative("IsInReady",				Native_IsInReady);
	CreateNative("IsInLiveCountdown",		Native_IsInLiveCountdown);
	CreateNative("IsReady",					Native_IsPlayerReady);
	CreateNative("IsPlayerReady",			Native_IsPlayerReady);
	CreateNative("IsPlayerReady",			Native_IsTeamReady);
	CreateNative("ToggleReadyPanel",		Native_ToggleReadyPanel);
	CreateNative("StartCustomReadyUp",		Native_StartCustomReadyUp);
}

any Native_AddStringToReadyFooter(Handle plugin, int numParams)
{
	Footer nativeFooter = ReadyPanel.GetFooter();
	if (nativeFooter)
	{
		char buffer[MAX_FOOTER_LEN];
		GetNativeString(1, buffer, sizeof(buffer));
		return nativeFooter.Add(buffer);
	}
	return -1;
}

any Native_EditFooterStringAtIndex(Handle plugin, int numParams)
{
	Footer nativeFooter = ReadyPanel.GetFooter();
	if (nativeFooter)
	{
		char buffer[MAX_FOOTER_LEN];
		GetNativeString(2, buffer, sizeof(buffer));
		int index = GetNativeCell(1);
		return nativeFooter.Edit(index, buffer);
	}
	return false;
}

any Native_FindIndexOfFooterString(Handle plugin, int numParams)
{
	Footer nativeFooter = ReadyPanel.GetFooter();
	if (nativeFooter)
	{
		char buffer[MAX_FOOTER_LEN];
		GetNativeString(1, buffer, sizeof(buffer));
		return nativeFooter.Find(buffer);
	}
	return -1;
}

any Native_GetFooterStringAtIndex(Handle plugin, int numParams)
{
	Footer nativeFooter = ReadyPanel.GetFooter();
	if (nativeFooter)
	{
		int index = GetNativeCell(1), maxlen = GetNativeCell(3);
		SetNativeString(2, FooterGet(nativeFooter, index), maxlen, true);
		return true;
	}

	return false;
}

any Native_IsInReady(Handle plugin, int numParams)
{
	return ReadyManager.InReadyUp();
}

any Native_IsInLiveCountdown(Handle plugin, int numParams)
{
	return ReadyManager.InLiveCountdown();
}

any Native_IsPlayerReady(Handle plugin, int numParams)
{
	if (!ReadyManager.InReadyUp())
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "The game is not currently in the ready-up phase");
	}
	
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	}

	if (!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);
	}
	
	return ReadyManager.IsPlayerReady(client);
}

any Native_IsTeamReady(Handle plugin, int numParams)
{
	if (!ReadyManager.InReadyUp())
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "The game is not currently in the ready-up phase");
	}
	
	ReadyTeam team = GetNativeCell(1);
	if (team <= ReadyTeam_Invalid || team >= ReadyTeam_SIZE)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid ReadyTeam index %d", team);
	}

	return ReadyManager.IsTeamReady(team);
}

any Native_ToggleReadyPanel(Handle plugin, int numParams)
{
	if (ReadyPanel.IsActive())
	{
		// TODO: Inform the client(s) that panel is supressed?
		bool hide = !GetNativeCell(1);
		
		int client = GetNativeCell(2);
		if (client && IsClientInGame(client))
		{
			return ReadyPanel.SetHiddenTo(client, hide);
		}
		else
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i))
				{
					ReadyPanel.SetHiddenTo(i, hide);
				}
			}
			return true;
		}
	}
	return false;
}

any Native_StartCustomReadyUp(Handle plugin, int numParams)
{
	if (ReadyManager.InReadyUp())
		return false;
	
	ReadyMode readyUpMode = GetNativeCell(1);
	if (readyUpMode <= ReadyMode_Disable || readyUpMode >= ReadyMode_SIZE)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid ReadyMode index %d", readyUpMode);
	
	ReadyManager.SetCustomReadyUpOwner(plugin);
	ReadyManager.Create(readyUpMode);
	
	return true;
}