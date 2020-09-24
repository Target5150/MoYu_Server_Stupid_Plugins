# server_namer

[> Plugin forum](https://forums.alliedmods.net/showthread.php?p=2030557)

- Modified to support hostname containing UTF-8 characters via reading text
- Remarks that only if **sn_main_name.txt** is empty will it instead read the hostname from convar **sn_main_name**

# Installation
1. Put the **server_namer.smx** to your _plugins_ folder.
2. Put the **server_namer.txt** to your _configs_ folder.
3. Put the **sn_main_name.txt** to _sourcemod/configs/hostname_ folder.
4. Set the convars in your _server.cfg_.