#if defined _l4d_heal_overtime_included
	#endinput
#endif
#define _l4d_heal_overtime_included

#include <sourcemod>

stock static ArrayList __g_HOTPairList;

enum HealType
{
	Heal_PermHealth,
	Heal_TempHealth,

	MAX_HEAL_TYPES
};

stock void L4DHOT_Init()
{
	static bool s_bInit = false;
	if (s_bInit)
		return;

	delete __g_HOTPairList;
	__g_HOTPairList = new ArrayList(2);

	HookEvent("player_bot_replace", __Event_player_bot_replace);
	HookEvent("bot_player_replace", __Event_bot_player_replace);

	s_bInit = true;
}

stock void L4D_HealPlayerOverTime(
	int client,
	float interval,
	int increment,
	int total,
	int maxHealth = -1,
	HealType type = Heal_TempHealth,
	bool immediate = true)
{
	L4DHOT_Init();

	if (client <= 0 || client > MaxClients)
		ThrowError("Invalid client index (%d)", client);

	if (!IsClientInGame(client))
		ThrowError("Client (%d) is not in game", client);

	if (!IsPlayerAlive(client))
		ThrowError("Client (%d) is not alive", client);

	if (GetClientTeam(client) == 3 && type == Heal_TempHealth)
		ThrowError("Temp health cannot be applied to infected player (%d)", client);

	__HealPlayerOverTime(
		client,
		type,
		increment,
		increment >= total ? increment : total,
		maxHealth > 0 ? maxHealth : GetEntProp(client, Prop_Data, "m_iMaxHealth"),
		interval,
		immediate);
}

stock static void __HealPlayerOverTime(
	int client,
	HealType type,
	int increment,
	int remaining,
	int maxHealth,
	float interval,
	bool immediate)
{
	if (immediate)
	{
		__HealTowardsMax(client, increment, maxHealth, type);
		remaining -= increment;
	}

	if (remaining == 0)
		return;

	int userid = GetClientUserId(client);

	DataPack dp;
	CreateDataTimer(interval, __HOT_ACTION, dp, TIMER_REPEAT);
	dp.WriteCell(userid);
	dp.WriteCell(type);
	dp.WriteCell(increment);
	dp.WriteCell(remaining);
	dp.WriteCell(maxHealth);

	__g_HOTPairList.Set( __g_HOTPairList.Push(userid), dp, 1 );
}

stock static Action __HOT_ACTION(Handle timer, DataPack dp)
{
	dp.Reset();

	int userid = dp.ReadCell();
	int client = GetClientOfUserId(userid);
	
	if (client
	 && IsClientInGame(client)
	 && IsPlayerAlive(client)
	 && !GetEntProp(client, Prop_Send, "m_isIncapacitated")
	 && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		HealType type = dp.ReadCell();
		int increment = dp.ReadCell();
		DataPackPos pos = dp.Position;
		int remaining = dp.ReadCell();
		int maxHealth = dp.ReadCell();

		if (increment < remaining)
		{
			__HealTowardsMax(client, increment, maxHealth, type);
			remaining -= increment;

			dp.Position = pos;
			dp.WriteCell(remaining);

			return Plugin_Continue;
		}
		else
		{
			__HealTowardsMax(client, remaining, maxHealth, type);
		}
	}
	
	__g_HOTPairList.Erase( __g_HOTPairList.FindValue(dp, 1) );

	return Plugin_Stop;
}

stock static void __HealTowardsMax(int client, int amount, int max, HealType type)
{
	switch (type)
	{
	case Heal_PermHealth:
		{
			int perm = GetClientHealth(client) + amount;
			if (perm > max)
			{
				perm = max;
			}
			SetEntProp(client, Prop_Send, "m_iHealth", perm);

			// replaces portion of temp health with perm health
			float hb = GetTempHealth(client);
			float overflow = float(perm) + hb - max;
			if (overflow > 0)
			{
				hb -= overflow;
			}
			SetTempHealth(client, hb);
		}
	
	case Heal_TempHealth:
		{
			float hb = GetTempHealth(client) + amount;
			float overflow = hb + GetClientHealth(client) - max;
			if (overflow > 0)
			{
				hb -= overflow;
			}
			SetTempHealth(client, hb);
		}
	}
}

stock static void __Event_player_bot_replace(Event event, const char[] name, bool dontBroadcast)
{
	__HandlePlayerReplace(event.GetInt("bot"), event.GetInt("player"));
}

stock static void __Event_bot_player_replace(Event event, const char[] name, bool dontBroadcast)
{
	__HandlePlayerReplace(event.GetInt("player"), event.GetInt("bot"));
}

stock static void __HandlePlayerReplace(int userid, int replaced)
{
	DataPack dp;
	int index;
	while ((index = __g_HOTPairList.FindValue(replaced, 0)) != -1)
	{
		dp = __g_HOTPairList.Get(index, 1);
		dp.Reset();
		dp.WriteCell(userid);
		__g_HOTPairList.Erase(index);
		__g_HOTPairList.Set( __g_HOTPairList.Push(userid), dp, 1 );
	}
}

// Stolen from left4dhooks thanks to Silvers
stock static float GetTempHealth(int client)
{
	static ConVar pain_pills_decay_rate = null;
	if (!pain_pills_decay_rate)
		pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");

	float elaspedTime = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	float health = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	health -= elaspedTime * pain_pills_decay_rate.FloatValue;
	return health < 0.0 ? 0.0 : health;
}

// Stolen from left4dhooks thanks to Silvers
stock static void SetTempHealth(int client, float amount)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", amount < 0.0 ? 0.0 : amount);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}