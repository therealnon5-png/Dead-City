-- Copy into Pistol > GunScript_Server. Keep its existing RemoteEvents and IgniteScript child.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Gore = require(ServerScriptService:WaitForChild("Server"):WaitForChild("GoreService"))
local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle")
local Setting = require(Tool:WaitForChild("Setting"))
local ChangeAmmoAndClip = script:WaitForChild("ChangeAmmoAndClip")
local InflictTarget = script:WaitForChild("InflictTarget")
local Ammo = script:FindFirstChild("Ammo") or Instance.new("NumberValue")
Ammo.Name, Ammo.Parent = "Ammo", script
local Clips = script:FindFirstChild("Clips") or Instance.new("NumberValue")
Clips.Name, Clips.Parent = "Clips", script
Ammo.Value = Setting.AmmoPerClip
Clips.Value = Setting.LimitedClipEnabled and Setting.Clips or 0

for name, id in pairs({
    IdleAnim = Setting.DualEnabled and 53610688 or Setting.IdleAnimationID,
    FireAnim = Setting.FireAnimationID,
    ReloadAnim = Setting.ReloadAnimationID,
    ShotgunClipinAnim = Setting.ShotgunClipinAnimationID,
}) do
    if id ~= nil and not Tool:FindFirstChild(name) then
        local anim = Instance.new("Animation")
        anim.Name = name
        anim.AnimationId = "rbxassetid://" .. tostring(id)
        anim.Parent = Tool
    end
end

local nextShotAt = 0
local reloadUntil = 0
local function owner(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return character and Tool.Parent == character and humanoid and humanoid.Health > 0, character, humanoid
end

ChangeAmmoAndClip.OnServerEvent:Connect(function(player, requestedAmmo)
    local valid = owner(player)
    if not valid or typeof(requestedAmmo) ~= "number" or requestedAmmo ~= requestedAmmo then return end
    local now = os.clock()
    -- The old client sends its count after every shot. Account for misses here;
    -- hits were already charged in InflictTarget and have the same count.
    if requestedAmmo == Ammo.Value - 1 and now >= nextShotAt and now >= reloadUntil then
        Ammo.Value -= 1
        nextShotAt = now + math.max(0.05, Setting.FireRate or 0.05)
        return
    end
    if requestedAmmo ~= Setting.AmmoPerClip or Ammo.Value >= Setting.AmmoPerClip
        or now < reloadUntil then return end
    if Setting.LimitedClipEnabled and Clips.Value <= 0 then return end
    reloadUntil = os.clock() + math.max(0, Setting.ReloadTime or 0)
    task.delay(math.max(0, Setting.ReloadTime or 0), function()
        local stillEquipped = owner(player)
        if not stillEquipped or os.clock() < reloadUntil - 0.01 then return end
        if Setting.LimitedClipEnabled then Clips.Value -= 1 end
        Ammo.Value = Setting.AmmoPerClip
    end)
end)

InflictTarget.OnServerEvent:Connect(function(player, targetHumanoid, targetTorso, _clientDamage,
        _clientDirection, _clientKnockback, _clientLifesteal, _clientFlaming, hitPart, hitPosition)
    local valid, character, shooter = owner(player)
    if not valid or os.clock() < reloadUntil or Ammo.Value <= 0 then return end
    if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") or not hitPart:IsDescendantOf(workspace)
        or typeof(hitPosition) ~= "Vector3" or hitPosition.X ~= hitPosition.X
        or hitPosition.Y ~= hitPosition.Y or hitPosition.Z ~= hitPosition.Z
        or typeof(targetHumanoid) ~= "Instance"
        or not targetHumanoid:IsA("Humanoid") or targetHumanoid.Health <= 0 then return end
    local now = os.clock()
    if now < nextShotAt then return end
    local origin = Handle.Position
    local direction = hitPosition - origin
    if direction.Magnitude < 0.01 or direction.Magnitude > 500 then return end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    local result = workspace:Raycast(origin, direction.Unit * (direction.Magnitude + 2), params)
    if not result or (result.Position - hitPosition).Magnitude > 6 then return end
    local victim, humanoid, bodyPart = Gore.ResolveHit(result.Instance)
    if not victim or humanoid ~= targetHumanoid or victim == character then return end
    if result.Instance ~= hitPart then
        local claimedVictim = Gore.ResolveHit(hitPart)
        if claimedVictim ~= victim then return end
    end
    local victimPlayer = Players:GetPlayerFromCharacter(victim)
    if victimPlayer and not player.Neutral and not victimPlayer.Neutral
        and victimPlayer.TeamColor == player.TeamColor then return end
    nextShotAt = now + math.max(0.05, Setting.FireRate or 0.05)
    Ammo.Value -= 1
    local damage = Setting.BaseDamage
    if bodyPart and bodyPart.Name == "Head" and Setting.HeadshotEnabled then
        local desired = Setting.BaseDamage * Setting.HeadshotDamageMultiplier
        damage = Gore.IsZombie(victim) and desired / Gore.Config.HeadshotMultiplier or desired
    end
    local applied, actualDamage = Gore.RegisterHit({
        Attacker = player, Character = victim, Humanoid = humanoid,
        BodyPart = bodyPart, Damage = damage,
        Position = result.Position, Normal = result.Normal,
    })
    if not applied then return end
    local knockback = math.max(0, Setting.Knockback or 0)
    local root = victim:FindFirstChild("HumanoidRootPart")
    if knockback > 0 and root then root.AssemblyLinearVelocity += direction.Unit * knockback end
    local lifesteal = math.clamp(Setting.Lifesteal or 0, 0, 1)
    if lifesteal > 0 then shooter.Health = math.min(shooter.MaxHealth, shooter.Health + actualDamage * lifesteal) end
    if Setting.FlamingBullet then
        local template = script:FindFirstChild("IgniteScript")
        if template and not victim:FindFirstChild("IgniteScript") then
            local ignite = template:Clone()
            local creator = ignite:FindFirstChild("creator")
            if creator and creator:IsA("ObjectValue") then creator.Value = player end
            ignite.Parent = victim
            ignite.Disabled = false
        end
    end
end)
