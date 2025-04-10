#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>

#define ABSORB_PREF_COOKIE_NAME "l4d_auto_pickup_weapon"

static Cookie g_Cookie;
static char g_Buffer[2] = { '0' };

static bool g_bCached[MAXPLAYERS+1];
static bool g_bSavedPref[MAXPLAYERS+1];

static ConVar g_cvDefault;

void AbsorbPref_Init()
{
	g_Cookie = new Cookie(
		ABSORB_PREF_COOKIE_NAME,
		"Client preference for plugin \""...ABSORB_PREF_COOKIE_NAME..."\"",
		CookieAccess_Public);
	
	g_cvDefault = CreateConVar(
		"auto_pickup_weapon_default",
		"1",
		"Default enabled of auto pick-up weapon.",
		FCVAR_NONE, true, 0.0, true, 1.0);
}

bool AbsorbPref_Set(int client, bool val)
{
	if (IsFakeClient(client)
	 || !AreClientCookiesCached(client))
		return false;

	g_Buffer[0] = val ? '1' : '0';
	g_Cookie.Set(client, g_Buffer);

	g_bSavedPref[client] = val;

	return true;
}

bool AbsorbPref_Get(int client)
{
	if (IsFakeClient(client)
	 || !AreClientCookiesCached(client))
		return g_cvDefault.BoolValue;

	if (!g_bCached[client])
		OnClientCookiesCached(client);

	return g_bSavedPref[client];
}

bool AbsorbPref_Toggle(int client)
{
	return AbsorbPref_Set(client, !g_bSavedPref[client]);
}

public void OnClientCookiesCached(int client)
{
	if (!IsFakeClient(client))
	{
		g_bCached[client] = true;
		g_Cookie.Get(client, g_Buffer, sizeof(g_Buffer));
		g_bSavedPref[client] = g_Buffer[0] != '0';
	}
}
