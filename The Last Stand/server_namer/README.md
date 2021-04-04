# server_namer

**Plugin forum**: https://forums.alliedmods.net/showthread.php?p=2030557

- Modified to support hostname containing UTF-8 characters via reading text
- Remarks that only if the **Text File** is empty or missing will it instead read the hostname from convar **sn_main_name**

### Installation
1. Put the **server_namer.smx** to your _plugins_ folder.
2. Put the **server_namer.txt** to your _configs_ folder.
3. Put a **Text File containing Hostname** to anywhere within _sourcemod/configs/_ folder.
4. Set the convars in your _server.cfg_.
	- The value of `sn_main_name_path` should be the path where the **Text File** is (i.e. `hostname/sn_main_name.txt`).