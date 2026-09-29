# Third-party notices

## Godot Engine

The project uses Godot Engine 4.x. Godot is distributed under the MIT license. See the official Godot repository and documentation for the complete license and third-party notices.

## teratron/godot-mcp

The local development bridge is based on `teratron/godot-mcp`, an MIT-licensed project:
https://github.com/teratron/godot-mcp

The bridge is kept as a development tool under `addons/godot_mcp/`. It is not part of the game's runtime design. The Rust MCP binary is built locally under the repository's `.tools/` directory and should not be committed to the game repository.

## Cataclysm-DDA

Cataclysm-DDA is used as a design and architecture reference. We do not copy its source code, data, fonts, artwork, names, or text into this project:
https://github.com/CleverRaven/Cataclysm-DDA

The Cataclysm project declares CC BY-SA 3.0 for the main project, with separately licensed third-party components. Any future code or data import must be reviewed file by file and must preserve the applicable attribution and share-alike requirements.

## Luanti / Veloren

Luanti and Veloren are studied for modding, server and client boundaries, and community workflows. No source code or assets from them are currently included. Their LGPL-2.1 and GPL-3.0 terms respectively must be reviewed before any direct reuse.

## Poly Haven

Poly Haven is an optional source for prototype textures, HDRIs and models. Downloaded assets are CC0, but each imported asset will still carry a local provenance record. Live API use has additional attribution and usage requirements.

## Additional reference projects

The following projects are architectural references only at this stage:

- [Terasology](https://github.com/MovingBlocks/Terasology): Apache-2.0 code and generally CC-BY-4.0 artwork; useful for voxel modules and community content boundaries.
- [OpenRA](https://github.com/OpenRA/OpenRA): GPL-3.0; useful for YAML rules, Lua scripting, Mod SDKs and dedicated-server workflows.
- [0 A.D.](https://github.com/0ad/0ad): mixed GPL-2.0, LGPL-2.1 and MIT components; useful for actor templates and component-oriented simulation.
- [Endless Sky](https://github.com/endless-sky/endless-sky): GPL-3.0 code with separately licensed art and audio; useful for plugin and content review workflows.
- [OpenRCT2](https://github.com/OpenRCT2/OpenRCT2): GPL-3.0 engine with a documented JavaScript plugin API; useful for versioned extensions and hot reload.

No source code or assets from these projects are included in `res://`.

## Asset sources under evaluation

- [Kenney](https://kenney.nl/assets): official support guidance states game assets are public-domain CC0.
- [Poly Haven](https://polyhaven.com/license): models, textures and HDRIs are CC0; the website and API still have separate terms.
- [Quaternius](https://github.com/Quaternius/quaternius.github.io/blob/main/license.html): use the current QAL or the exact license attached to each asset pack; do not redistribute raw packs as standalone assets.
- [Freesound](https://freesound.org/): every sound is reviewed individually because the library contains multiple licenses.

Kenney City Kit Suburban, City Kit Roads and Car Kit assets are now imported under `assets/kenney/`. Each selected GLB and texture has a hash and provenance entry in `assets/ASSET_MANIFEST.json`; the packs include their CC0 license text alongside the files. The original ZIP downloads and unused source formats remain outside the runtime tree under the ignored `work/` directory.

## Project Zomboid mod ecosystem

Project Zomboid mods are not automatically reusable assets. The official [Modding Policy](https://projectzomboid.com/blog/modding-policy/) places responsibility for third-party permissions on the mod author, and the [Terms and Conditions](https://store.steampowered.com/eula/108600_eula_1) keep the game and its assets proprietary. Workshop availability therefore does not make a PZ mod compatible with this project's open-source distribution. We may study PZ's design and use independently licensed toolchains or libraries, but we do not copy PZ code, art, maps, models, or Workshop content without an explicit license.

Open-source PZ-adjacent tools can still be references: [Storm](https://github.com/pzstorm/storm) is GPL-3.0, [Capsid](https://github.com/pzstorm/capsid) provides an MIT-licensed mod template, and [pz_lua_commons](https://github.com/escapepz/pz_lua_commons) is MIT. These target the PZ modding environment and are not runtime dependencies here.
