# R6 zombie gore setup

Rojo syncs `src/server/ZombieGore.luau` to `ServerScriptService.Server.ZombieGore` as a ModuleScript. Your existing Studio models stay in ServerStorage.

## Prepare models

Apply the `Zombie` tag (or lowercase `zombie`) to the NPC **Model**, not its Humanoid or individual parts. The NPC must be an R6 rig with a Humanoid.

Use these exact folders and template names:

```text
ServerStorage
  Gore_Body_Folder
    Gor_Heads
      Head (Model)
      Head (another Model / variant)
    Gore_Arms
      Left Arm (Model)
      Right Arm (Model)
    Gore_Chest
      Torso (Model)
```

You can give variants unique names such as `Head_01` if each has a string attribute `BodyPart` set to `Head`, `Left Arm`, `Right Arm`, or `Torso`. Subfolders are supported. Chest uses the R6 name `Torso`. Left and right arms are selected separately. Models must contain BaseParts and have Archivable enabled.

Set each model's pivot to the center/orientation of the R6 body part it replaces. Model geometry should be sized for your rig. The script aligns that pivot with the original part, then welds every replacement part to it. It does not automatically resize assets. BasePart templates also work.

## Connect your attack system

Humanoid health changes do not identify which body part was hit. Your weapon must pass the result of its hit detection to this module. From a **server** script, after validating the attack:

```lua
local Gore = require(game:GetService("ServerScriptService").Server.ZombieGore)

-- hitPart is the BasePart hit by your server raycast or melee hitbox.
local zombie, humanoid = Gore.GetZombie(hitPart)
if zombie and humanoid.Health > 0 then
    local ok, reason = Gore.ApplyHit(hitPart)
    if not ok then
        warn(reason)
    end
    humanoid:TakeDamage(25)
end
```

Apply visuals before damage so a lethal hit is also processed. The module never changes health or destroys the original body parts. Legs can still receive damage through your attack system but have no gore replacement. Repeated hits keep one replacement per part; head hits can produce another short blood burst. Droplets expire after 0.8 seconds, with a global limit of 150.

## Adapt the gun in message.txt

For the melee weapon, use the complete replacement script and instructions in [Melee weapon setup](MeleeWeapon.md). The gun instructions below are separate.

The note's gun is not present as a Tool in this filesystem. Make these changes in its existing scripts in Studio. Do not place its Tool scripts directly in `src/server` or `src/client`: they depend on `script.Parent` being the Tool.

In the client, replace the damage request with:

```lua
Receiver:FireServer("Damage", hitHumanoid, Damage, hitObject)
```

The current team check blocks NPCs when the shooter is on a team. Replace that condition with:

```lua
if not hitPlayer or MyPlayer.Neutral or hitPlayer.TeamColor ~= MyPlayer.TeamColor then
```

The client's old raycast ignores transparent parts, which would skip replaced limbs. In `RayIgnoreCheck`, replace `hit.Transparency >= 1` with:

```lua
(hit.Transparency >= 1 and not hit:GetAttribute("GoreHitbox"))
```

Also add this check at the beginning of `RayIgnoreCheck` to skip the cosmetic replacements and droplets:

```lua
if hit and hit:IsA("BasePart") and not hit.CanQuery then
    return true
end
```

At the top of the Tool's **server** script, add:

```lua
local Gore = require(game:GetService("ServerScriptService").Server.ZombieGore)
local lastHit = 0
local SERVER_DAMAGE = 25
local RANGE = 350
local FIRE_INTERVAL = 0.5
```

Replace the server's existing `elseif action == "Damage" then` branch with the following body (keep the callback's closing `end` statements). This version targets zombies only and ignores the client-provided damage amount:

```lua
elseif action == "Damage" then
    local character = player.Character
    local shooter = character and character:FindFirstChildOfClass("Humanoid")
    if Tool.Parent ~= character or not shooter or shooter.Health <= 0 then
        return
    end
    local now = os.clock()
    if now - lastHit < FIRE_INTERVAL then return end
    lastHit = now

    local requestedPart = Data[3]
    local zombie, humanoid = Gore.GetZombie(requestedPart)
    if not zombie or humanoid ~= Data[1] or humanoid.Health <= 0 then return end
    local direction = requestedPart.Position - Handle.Position
    if direction.Magnitude < 0.001 or direction.Magnitude > RANGE then return end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    local result = workspace:Raycast(Handle.Position, direction.Unit * (direction.Magnitude + 2), params)
    if not result then return end
    local actualZombie = Gore.GetZombie(result.Instance)
    if actualZombie ~= zombie then return end

    local ok, reason = Gore.ApplyHit(result.Instance)
    if not ok and result.Instance.Name ~= "Left Leg" and result.Instance.Name ~= "Right Leg" then
        warn(reason)
    end
    humanoid:TakeDamage(SERVER_DAMAGE)
```

This checks equipment, life, range, cadence, and line of sight, and uses the part actually struck by the server raycast. The legacy gun still tracks ammo and reload on the client; a complete weapon system should validate those on the server as well. This compatibility hook validates a ray toward the requested part's center; a future server-authoritative firing system should raycast the actual shot direction instead.

## Studio checks

1. Tag an R6 NPC and fire at its head, both arms, and torso. Check that the correct variant appears and follows walking animations.
2. Shoot the same part again: there should be no stacked replacements. Repeated head shots should still burst briefly.
3. Check that face decals disappear and droplets clear. Hats/accessories are left intact.
4. Hit a leg or an untagged NPC: no gore replacement should appear.
5. Temporarily rename an asset folder: the module should report the missing folder without hiding the original part.

API references: [CollectionService tags](https://create.roblox.com/docs/reference/engine/classes/CollectionService), [Model pivots](https://create.roblox.com/docs/reference/engine/classes/Model), and [weld constraints](https://create.roblox.com/docs/physics/constraints/weld).
