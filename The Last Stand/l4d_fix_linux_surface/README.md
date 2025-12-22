# [L4D & 2] Fix Linux Surface

### Introduction
- Tricky fix for surfaces with wrong attributes on linux dedicated servers.
    - e.g. You won't slide on ice surfaces.
    - Windows gamedata is also provided for validation.
- Details/Causes when researching on the issue:
    - `CMaterial` fails to parse VMT vars without shaders from `ShaderSystem()->FindShader(const char*)`.

<hr>

### Installation
1. Put **plugins/l4d_fix_linux_surface.smx** to your _plugins_ folder.

<hr>

### Changelog
(v1.0 2024/04/23 UTC+8) Initial release.
