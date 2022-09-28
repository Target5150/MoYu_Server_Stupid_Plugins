#if defined _l4d2_uncommon_adjustment_util_included
 #endinput
#endif
#define _l4d2_uncommon_adjustment_util_included

void __Assert(bool test, const char[] error, any ...)
{
	if (!test)
	{
		char buffer[256];
		VFormat(buffer, sizeof(buffer), error, 3);
		SetFailState("%s", buffer);
	}
}

void ResetEntityHealth(int entity, int health)
{
	SetEntProp(entity, Prop_Data, "m_iMaxHealth", health);
	SetEntProp(entity, Prop_Data, "m_iHealth", health);
}