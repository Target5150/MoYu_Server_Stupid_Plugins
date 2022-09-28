#if defined _l4d2_uncommon_adjustment_uncommon_attract_included
 #endinput
#endif
#define _l4d2_uncommon_adjustment_uncommon_attract_included

#include <sourcescramble>

#define PATCH_COUNT 3

static const char s_keyPatch[PATCH_COUNT][] = {
	"InfectedAlert::OnSound__Uncommon_attract_skip",
	"InfectedWander::OnSound__Uncommon_attract_skip",
	"InfectedAttack::OnSound__Uncommon_attract_skip"
};

enum struct UncommonAttract_t
{
	MemoryPatch hPatches[PATCH_COUNT];
	
	void Init(GameData conf)
	{
		for (int i = 0; i < PATCH_COUNT; ++i)
		{
			this.hPatches[i] = MemoryPatch.CreateFromConf(conf, s_keyPatch[i]);
			__Assert(this.hPatches[i] != null, "Missing patch setup \"%s\"", s_keyPatch[i]);
		}
	}
	
	bool Enable()
	{
		for (int i = 0; i < PATCH_COUNT; ++i)
			this.hPatches[i].Disable();
		
		return true;
	}
	
	bool Disable()
	{
		for (int i = 0; i < PATCH_COUNT; ++i)
			if (!this.hPatches[i].Enable())
				return false;
		
		return true;
	}
}
