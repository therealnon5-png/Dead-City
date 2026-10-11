# First-person camera

Rojo syncs `src/client/FirstPersonCamera.client.luau` into StarterPlayerScripts and sets StarterPlayer to LockFirstPerson. Restart Play after syncing these changes.

The view stays in first person with the mouse captured in the center. Move the mouse to look around. Shift does not release the cursor or switch camera modes. Escape opens the Roblox menu; closing the menu resumes capture. A small white dot marks the center of the screen.

This is the arms-only version: the torso, legs, head and accessories are hidden locally. The camera uses its normal eye position without a forward offset. The added sprint system has been removed.

The script uses Roblox's native camera for aiming and adds gentle movement bob, sideways lean, a jump impulse and a landing dip. Mouse sensitivity follows Roblox settings. Adjust BASE_FOV and MOTION_SCALE at the top of the script; set MOTION_SCALE to 0 to remove the extra camera motion.

The visible arms are the player's actual character parts with their existing skin, sleeves, meshes and animations. No additional hand blocks or cloned arms are created. The camera does not change any shoulder or body joints: Animate and the equipped weapon control the arm pose. This prevents camera pitch from bending the physical arms or moving the attached weapon. Arms may rest near the lower edges of the view when idle. R6 includes hands as part of each arm, rather than separate hand joints. Camera capture also works on R15.

Camera bob and roll are removed before Roblox calculates the next frame's mouse look, then applied again to the new camera frame. This prevents those visual effects feeding back into the camera orientation at steep viewing angles. Effects pause while a different camera type or subject is active.

After installing this fix, stop and restart Play to replace any shoulder offsets left on the current character by the older script. Test looking straight down while standing, walking sideways, jumping and holding a Tool, then look level again. The arms should follow normal animations without twisting with the mouse.

Test in Studio Play with the game viewport focused: look left/right/up/down, press Shift, run, jump, land, equip and swing the weapon, then reset the character. Check that the dot stays centered, the real arms remain visible and mouse capture returns after closing Escape. Keep the normal Roblox Animate script enabled for walking/running animations. Avoid running another custom camera script alongside this one.
