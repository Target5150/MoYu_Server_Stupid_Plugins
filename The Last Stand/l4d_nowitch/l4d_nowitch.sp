#include <sourcemod>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "No Witch",
	author = "Sir",
	description = "Slays any Witch that spwns",
	version = "1",
	url = "Nuh-uh"
}

public Action L4D_OnSpawnWitch(const float vecPos[3], const float vecAng[3])
{
	return Plugin_Handled;
}

public Action L4D2_OnSpawnWitchBride(const float vecPos[3], const float vecAng[3])
{
	return Plugin_Handled;
}
