# InventoryGui connection

Keep your existing design in Studio's StarterGui. These scripts do not replace the layout. Rojo syncs `InventoryController.client.luau` and `InventoryPreview.luau` under `StarterPlayerScripts.Client`.

Expected structure (other layout containers between these objects are supported):

```text
StarterGui
  InventoryGui (ScreenGui)
    CharacterFrame (Frame)
      ViewportFrame (ViewportFrame)
    CloseButton (TextButton or ImageButton)
```

The controller uses the player's runtime copy in PlayerGui. It starts closed. Press **I** to switch `InventoryGui.Enabled` from false to true; press **I** again to switch back, or click the close button. The key is ignored while typing in chat or a text box. Opening releases the mouse and holds the gameplay camera; closing restores the first-person camera and center dot. Escape closes the inventory through Roblox's menu event. Respawn also closes it.

`src/server/InventoryRemote.server.luau` automatically creates `ReplicatedStorage.InventoryToggle` (RemoteEvent). The client changes Enabled immediately, then sends the requested boolean and a revision to the server. The server validates and replies only to that player; delayed replies cannot undo newer input. A missing or broken preview module no longer prevents opening the inventory. Both the server script and client scripts must be synced before restarting Play. The RemoteEvent carries visibility only and does not authorize item changes.

Close buttons may be named `CloseButton`, `Close`, `CloseBtn`, `ExitButton`, or `X` (case insensitive). For another name, add a string attribute `InventoryAction` with value `Close` to that button. Keep the visible layout Frames' Visible properties enabled; the controller switches the ScreenGui's Enabled property. Remove or disable any older inventory toggle controller to avoid double toggles.

The preview uses a local clone inside a WorldModel. It mirrors actual body poses, clothing, skin and equipped Tools. Adding/removing equipment rebuilds it within about 0.1 seconds; clothing and mesh changes also refresh it. Looking around in the menu rotates only the preview head and head accessories, with a smaller body turn. It never modifies the live character's joints. The full preview remains visible even though the first-person camera hides the live torso and head. Camera framing responds to the viewport's dimensions. Very large Tools may extend beyond the portrait.

This connects visibility and the portrait; it does not add item storage, equip buttons or drag-and-drop logic. No Studio UI access was available during implementation, so verify the named hierarchy and close button in your place.

## Studio check

Sync Rojo, stop and restart Play. Press I: inventory appears, dot hides and mouse moves freely. Move the cursor to each side of the portrait: the character should look toward it. Equip/unequip a Tool using your existing controls or change an accessory: the preview should update. Press I or the close button: gameplay mouse capture returns. Reset the character and repeat. Test typing the letter i in chat; the inventory should stay closed.
