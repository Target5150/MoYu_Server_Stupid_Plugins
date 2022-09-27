#if defined _l4d2_uncommon_adjustment_uncommon_attract_included
 #endinput
#endif
#define _l4d2_uncommon_adjustment_uncommon_attract_included

#include <sourcescramble>

enum struct UncommonAttract_t
{
	MemoryPatch hPatch1;
	MemoryPatch hPatch2;
	
	void Init(GameData conf)
	{
		static const char s_keyPatch1[] = "InfectedAlert::OnSound__Uncommon_attract_skip";
		static const char s_keyPatch2[] = "InfectedWander::OnSound__Uncommon_attract_skip";
		
		this.hPatch1 = MemoryPatch.CreateFromConf(conf, s_keyPatch1);
		this.hPatch2 = MemoryPatch.CreateFromConf(conf, s_keyPatch2);
		
		__Assert(this.hPatch1 != null, "Missing patch setup \"%s\"", s_keyPatch1);
		__Assert(this.hPatch2 != null, "Missing patch setup \"%s\"", s_keyPatch2);
	}
	
	bool Enable()
	{
		this.hPatch1.Disable();
		this.hPatch2.Disable();
		return true;
	}
	
	bool Disable()
	{
		return this.hPatch1.Enable() && this.hPatch2.Enable();
	}
}
