#pragma newdecls required

#include <sourcemod>

/******************************************************************
*
* v1.0
* ------------------------
* ------- Details: -------
* ------------------------
* - Establishes Server Commands for the following:
* --> Unloading Plugins with the argument being the folder you want to unload the plugins from, leave the argument empty if you wish to unload just the main folder.
* --> Reserving Plugins, meaning these plugins will not be unloaded when the previously mentioned Plugin Unload is unloading the folder these plugins reside in.
* --> Unloading Reserved Plugins, this function will unload the reserved plugins in the order from "Last Reserved" to "First Reserved".

* v1.1
* ------------------------
* ------- Details: -------
* ------------------------
* - Overhauled it with keyCat's feedback in mind.
* --> Unloading Plugins with the pred_unload_plugins will push all currently loaded plugins to the Array and unloads them from Last loaded to First loaded. This way, dependencies should'nt be an issue.
* --> Removed the possibility of just Unloading Reserved Plugins... as there's no need for it?
*
*
* v1.2
* ------------------------
* ------- Details: -------
* ------------------------
* - Removed the unnecessary "ReservePlugin" function.
* - Added a failsafe after plugins are supposed to be unloaded, as we've seen some cases where this plugin would be the only one refusing to unload, thus never refreshing the plugins.
* - Added a less messy way of preventing double pushing, as this plugin is the only one that could possibly be double pushed. (StrEqual instead of FindInArray for every single plugin)
*
*
* v1.2.1
* ------------------------
* ------- Details: -------
* ------------------------
* - Removed the unnecessary "ReservePlugin" function.
* - Added a failsafe after plugins are supposed to be unloaded, as we've seen some cases where this plugin would be the only one refusing to unload, thus never refreshing the plugins.
* - Added a less messy way of preventing double pushing, as this plugin is the only one that could possibly be double pushed. (StrEqual instead of FindInArray for every single plugin)
*
*
* v1.3.0 (Modified by Forgetest)
* ------------------------
* ------- Details: -------
* ------------------------
* - Used ArrayStack instead since we always want to unload plugins in reverse order.
* - Avoided some string operations since plugin can be addressed via Handle.
* - Alternative solution for missing plugins after unload due to early refresh.
*
******************************************************************/

public Plugin myinfo = 
{
	name = "Predictable Plugin Unloader",
	author = "Sir (heavily influenced by keyCat), Forgetest",
	version = "1.4.0",
	description = "Allows for unloading plugins from last to first."
}

public void OnPluginStart()
{
	RegServerCmd("pred_unload_plugins", UnloadPlugins, "Unload Plugins!");
}

public void OnPluginEnd()
{
	ServerCommand("sm plugins refresh");
}

Action UnloadPlugins(int args) 
{
	ArrayStack aReservedPlugins = new ArrayStack();
	
	Handle pluginIterator = GetPluginIterator();
	Handle currentPlugin;

	// Gotta reserve ourself of course.
	// - Supports moving the plugin to another folder. (INVALID_HANDLE simply gets the calling plugin)
	Handle myself = GetMyHandle();

	if (args == -1)
	{
		// Ourself as the last to unload.
		aReservedPlugins.Push(myself);
	}

	while (MorePlugins(pluginIterator))
	{
		currentPlugin = ReadPlugin(pluginIterator);

		// Prevent double pushing.
		if (currentPlugin != myself) {
			aReservedPlugins.Push(currentPlugin);
		}
	}
	
	//CloseHandle(currentPlugin); // This one I probably don't have to close, but whatevs.
	CloseHandle(pluginIterator);

	ServerCommand("sm plugins load_unlock");

	char sReserved[PLATFORM_MAX_PATH];
	while (PopStackCell(aReservedPlugins, currentPlugin))
	{
		GetPluginFilename(currentPlugin, sReserved, sizeof(sReserved));
		ServerCommand("sm plugins unload %s", sReserved);
	}
	
	delete aReservedPlugins;
	
	if (args != -1)
	{
		RequestFrame(OnNextFrame_DoubleCheck);
	}
	
	return Plugin_Handled;
}

void OnNextFrame_DoubleCheck()
{
	UnloadPlugins(-1);
}