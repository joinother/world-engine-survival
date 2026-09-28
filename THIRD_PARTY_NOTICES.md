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
