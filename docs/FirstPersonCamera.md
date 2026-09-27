# First-person camera

Rojo syncs `src/client/FirstPersonCamera.client.luau` into StarterPlayerScripts and sets StarterPlayer to LockFirstPerson. Restart Play after syncing these changes.

The view stays in first person with the mouse captured in the center. Move the mouse to look around. Hold either Shift to sprint; release to walk. Shift never unlocks the cursor. Escape opens the Roblox menu; closing the menu resumes capture. A small white dot marks the center of the screen.

The actual torso and legs are visible when looking down, along with the arms and equipped Tool. The head, root hitbox and accessories stay hidden to keep them out of the camera. A small forward camera offset when looking down makes room to see the chest and legs; a raycast keeps that offset from passing through walls.

Sprint runs at 24 studs/second and walking at 16, configured in `src/shared/Config.luau`. The client sends Shift intent and `src/server/Sprint.server.luau` selects the speed. Releasing Shift, opening a menu/chat, losing window focus or respawning cancels sprint. Walking adds rhythmic head bob and slight rotation; sprint increases its cadence and field of view. Step motion fades out when idle or airborne. Normal Animate animations follow the increased movement speed.

The script uses Roblox's native camera for aiming and adds gentle movement bob, sideways lean, a jump impulse and a landing dip. Mouse sensitivity follows Roblox settings. Adjust BASE_FOV and MOTION_SCALE at the top of the script; set MOTION_SCALE to 0 to remove the extra camera motion.

The visible arms are the player's actual character parts with their existing skin, sleeves, meshes and animations. No additional hand blocks or cloned arms are created. R6 arms are slightly raised when unarmed and follow the existing Animate script's running motion. Equipping a Tool restores the normal shoulder pose so its animations and real weapon stay together. R6 includes hands as part of each arm, rather than separate hand joints. Camera capture also works on R15; the custom shoulder lift is R6 only.

Test in Studio Play with the game viewport focused: look down to see your torso and legs, walk, hold/release Shift, jump, land, equip and swing the weapon, then reset the character. Verify the Humanoid WalkSpeed changes between 16 and 24, sprint cancels when opening Escape/chat or switching windows, and camera bob settles when standing still. Check that the dot stays centered, the real arms remain visible and mouse capture returns after closing Escape. Keep the normal Roblox Animate script enabled for walking/running animations. Avoid running another custom camera or WalkSpeed controller alongside these scripts.
