# Predictable Unloader ([Original](https://github.com/SirPlease/L4D2-Competitive-Rework/tree/master/addons/sourcemod/scripting) by [SirPlease](https://github.com/SirPlease),)

### Introduction

- Do the same, but a bit fresher.
	- Used `ArrayStack` instead since we always want to unload plugins in reverse order.
	- Avoided some string operations since plugin can be addressed via `Handle`.
	- Alternative solution for missing plugins after unload due to early refresh.
	
<hr>

### Command
```
/** 
 * @brief Unload Plugins!
 * @remark Server Command
 *
 * @noargument
 */
pred_unload_plugins
```