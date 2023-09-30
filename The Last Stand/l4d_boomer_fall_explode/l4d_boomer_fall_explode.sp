#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Boomer Fall Explode",
	author = "Forgetest",
	description = "Allow boomers to fall and explode on survivors.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	public MemoryPatch CreatePatchOrFail(const char[] name, bool enable = false) {
		MemoryPatch hPatch = MemoryPatch.CreateFromConf(this, name);
		if (!(enable ? hPatch.Enable() : hPatch.Validate()))
			SetFailState("Failed to patch \"%s\"", name);
		return hPatch;
	}
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_boomer_fall_explode");
	gd.CreatePatchOrFail("CTerrorPlayer::OnFallDamage__playerzombie_ignore", true);
	gd.CreatePatchOrFail("CTerrorPlayer::Event_Killed__playerzombie_nop", true);
	delete gd;
}