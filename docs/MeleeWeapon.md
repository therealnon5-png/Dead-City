# Connect the melee weapon

1. Run Rojo and connect Studio so `ServerScriptService.Server.ZombieGore` exists.
2. Open `weapons/MeleeWeapon.server.luau` in this project. Copy its full contents into the existing **server Script inside your Tool**, replacing the old script. Do not keep both scripts running.
3. Keep `Handle` with its `Hit` and `Swing` sounds, and the `ChopR6` Animation inside the Tool (`ChopR15` is optional for R15 attackers). Enable `CanTouch` on Handle and the zombie's original body parts.
4. Tag each R6 zombie Model `Zombie` or `zombie` and keep your assets in `ServerStorage.Gore_Body_Folder`, following [the gore model setup](ZombieGore.md).

The `weapons` folder is intentionally outside the default Rojo mapping: this script must run inside your existing Tool, whose name and assets are not available in this project. The gore module itself continues to sync through Rojo. Further edits to this weapon file need copying into the Tool unless you add a Rojo mapping for that Tool.

Each swing lasts 0.8 seconds and deals 20 damage once per target. The first valid body part touched chooses the gore replacement. Head hits produce blood trails; arm and torso hits replace the matching part. Legs receive ordinary damage. Non-zombie enemies still receive normal damage without gore, while teammates and ForceField-protected targets are excluded. The invisible original parts remain hittable.

Unequipping cancels the active swing. Re-equipping does not bypass its cooldown or add duplicate event handlers. Hits farther than 12 studs from the attacker's root are rejected; adjust `MAX_HIT_DISTANCE` for your weapon.

## Verify in Studio

- Play with an R6 tagged zombie and strike its head, torso, and each arm; check welded alignment while it animates.
- Confirm health decreases by only 20 per swing even when several parts touch the Handle. A leg touched first consumes that target's hit for the swing without triggering gore.
- Strike an already replaced head again: damage and the temporary blood burst should still work without stacking models.
- Unequip during a swing and repeatedly re-equip; idle contact must not deal damage.
- Check lethal hits, untagged NPCs, teammates, and ForceFields.

This retains the original weapon's `Handle.Touched` approach. A part already touching the Handle before activation may need to separate and touch again to generate a new contact event.
