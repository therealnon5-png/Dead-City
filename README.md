# Dead City

A starter Roblox project for editing Luau in Cursor and syncing scripts into Roblox Studio with Rojo.

For R6 zombie part replacements and weapon integration, see [Zombie gore setup](docs/ZombieGore.md).

For the R6 first-person camera and animated arms, see [First-person camera](docs/FirstPersonCamera.md).

For the existing Studio backpack GUI, I-key controls and live character portrait, see [InventoryGui setup](docs/InventoryGui.md).

## Folder layout

- `src/server`: server scripts, synced to `ServerScriptService.Server`.
- `src/client`: client scripts, synced to `StarterPlayer.StarterPlayerScripts.Client`.
- `src/shared`: modules available to both sides, synced to `ReplicatedStorage.Shared`. Do not put secrets here.
- `default.project.json`: the Rojo mapping for this project.

Files ending in `.server.luau` become Scripts, `.client.luau` become LocalScripts, and other `.luau` files become ModuleScripts.

## Connect Cursor to Studio

1. Install the Rojo CLI and Roblox Studio plugin using the [official installation guide](https://rojo.space/docs/v7/getting-started/installation/).
2. Open this folder in Cursor. You can also install the Rojo editor extension in Cursor; the terminal workflow below works without it.
3. Open your game or a new Baseplate in Roblox Studio.
4. In Cursor's terminal, run:

   ```powershell
   rojo serve default.project.json
   ```

5. Open the Rojo plugin in Studio and connect to `localhost` on port `34872`. Review and accept the initial sync.
6. Edit and save files in Cursor to sync them into Studio. Press Play in Studio to see the server and client startup messages in Output.

Keep the Rojo server running while editing. Stop it with Ctrl+C when finished. Make script changes in the source files; Rojo syncs those files into Studio, not Studio edits back into this folder. Build your map in Studio and save your place there.

## Optional place build

To build a place containing the synced code:

```powershell
New-Item -ItemType Directory -Force build
rojo build default.project.json -o build/DeadCity.rbxlx
```

This includes only the content defined in the Rojo project. Map edits made only in Studio are not included.
