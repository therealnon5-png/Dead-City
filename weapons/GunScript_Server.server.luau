local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle")
local Player
local Character
local Humanoid
--local TEAM
local VisualizeBullet = script.Parent:WaitForChild("VisualizeBullet")
local Module = require(Tool:WaitForChild("Setting"))
local ChangeAmmoAndClip = script:WaitForChild("ChangeAmmoAndClip")
local InflictTarget = script:WaitForChild("InflictTarget")
local Grip2
local Handle2
if Module.DualEnabled then
    Handle2 = Tool:WaitForChild("Handle2", 1)
    if Handle2 == nil and Module.DualEnabled then error('"Dual" setting is enabled but "Handle2" is missing!') end
end
local AmmoValue = script:FindFirstChild("Ammo") or Instance.new("NumberValue", script)
AmmoValue.Name = "Ammo"
AmmoValue.Value = Module.AmmoPerClip
local ClipsValue = script:FindFirstChild("Clips") or Instance.new("NumberValue", script)
ClipsValue.Name = "Clips"
ClipsValue.Value = Module.LimitedClipEnabled and Module.Clips or 0
if Module.IdleAnimationID ~= nil or Module.DualEnabled then
    local IdleAnim = Instance.new("Animation", Tool)
    IdleAnim.Name = "IdleAnim"
    IdleAnim.AnimationId = "rbxassetid://" .. (Module.DualEnabled and 53610688 or Module.IdleAnimationID)
end
if Module.FireAnimationID ~= nil then
    local FireAnim = Instance.new("Animation", Tool)
    FireAnim.Name = "FireAnim"
    FireAnim.AnimationId = "rbxassetid://" .. Module.FireAnimationID
end
if Module.ReloadAnimationID ~= nil then
    local ReloadAnim = Instance.new("Animation", Tool)
    ReloadAnim.Name = "ReloadAnim"
    ReloadAnim.AnimationId = "rbxassetid://" .. Module.ReloadAnimationID
end
if Module.ShotgunClipinAnimationID ~= nil then
    local ShotgunClipinAnim = Instance.new("Animation", Tool)
    ShotgunClipinAnim.Name = "ShotgunClipinAnim"
    ShotgunClipinAnim.AnimationId = "rbxassetid://" .. Module.ShotgunClipinAnimationID
end

-- This BindableEvent lives inside this Script's sandbox. GoreService runs in Server.
local GoreVisualHit = script:FindFirstChild("GoreVisualHit")
if not GoreVisualHit then
    GoreVisualHit = Instance.new("BindableEvent")
    GoreVisualHit.Name = "GoreVisualHit"
    GoreVisualHit.Parent = script
end
local goreWarning
local function ApplyGoreVisual(hitPart, hitPosition)
    local ok, reason = pcall(function()
        GoreVisualHit:Fire(hitPart, hitPosition)
    end)
    if not ok and reason ~= goreWarning then
        goreWarning = reason
        warn("[Pistol Gore] " .. tostring(reason))
    end
end
ChangeAmmoAndClip.OnServerEvent:connect(function(Player, Ammo, Clips)
    -- Preserve the original post-shot/post-reload protocol and timing.
    if Tool.Parent ~= Player.Character then return end
    if typeof(Ammo) ~= "number" or Ammo ~= Ammo or Ammo < 0 or Ammo > Module.AmmoPerClip then return end
    if typeof(Clips) ~= "number" or Clips ~= Clips or Clips < 0 or Clips > Module.MaxClip then return end
    AmmoValue.Value = Ammo
    ClipsValue.Value = Clips
end)
InflictTarget.OnServerEvent:connect(function(Player, TargetHumanoid, TargetTorso, Damage, Direction, Knockback, Lifesteal, FlamingBullet, HitPart, HitPosition)
    -- Keep the original eight payload arguments; append only Gore hit metadata.
    if Tool.Parent ~= Player.Character then return end
    local attackerHumanoid = Tool.Parent:FindFirstChildOfClass("Humanoid")
    if not attackerHumanoid or attackerHumanoid.Health <= 0 then return end
    if typeof(TargetHumanoid) ~= "Instance" or not TargetHumanoid:IsA("Humanoid")
        or not TargetHumanoid:IsDescendantOf(workspace) or TargetHumanoid.Health <= 0 then return end
    local target = TargetHumanoid.Parent
    if target == Player.Character or typeof(TargetTorso) ~= "Instance" or not TargetTorso:IsA("BasePart")
        or not TargetTorso:IsDescendantOf(target) then return end
    if typeof(Direction) ~= "Vector3" or Direction.Magnitude ~= Direction.Magnitude
        or Direction.Magnitude < 0.001 or Direction.Magnitude == math.huge then return end
    Direction = Direction.Unit
    if (TargetTorso.Position - Handle.Position).Magnitude > 5000 + (Module.Radius or 0) then return end
    local validHit = typeof(HitPart) == "Instance" and HitPart:IsA("BasePart") and HitPart.Parent == target
    local headDamage = Module.BaseDamage * (Module.HeadshotEnabled and Module.HeadshotDamageMultiplier or 1)
    if validHit then
        Damage = HitPart.Name == "Head" and headDamage or Module.BaseDamage
    else
        -- Compatibility with original clients: only Setting's damage values are accepted.
        Damage = Damage == headDamage and headDamage or Module.BaseDamage
    end
    Knockback, Lifesteal, FlamingBullet = Module.Knockback, Module.Lifesteal, Module.FlamingBullet
    if Player and TargetHumanoid and TargetHumanoid.Health ~= 0 and TargetTorso then
        while TargetHumanoid:FindFirstChild("creator") do TargetHumanoid.creator:Destroy() end
        local creator = Instance.new("ObjectValue", TargetHumanoid)
        creator.Name = "creator"
        creator.Value = Player
        game.Debris:AddItem(creator, 5)
        if validHit and not target:FindFirstChildOfClass("ForceField") then
            local position = HitPart.Position
            if typeof(HitPosition) == "Vector3" and (HitPosition - HitPart.Position).Magnitude <= HitPart.Size.Magnitude + 2 then
                position = HitPosition
            end
            ApplyGoreVisual(HitPart, position)
        end
        TargetHumanoid:TakeDamage(Damage)
        if Knockback > 0 then TargetTorso.Velocity = Direction * Knockback end
        if Lifesteal > 0 and Humanoid and Humanoid.Health ~= 0 then
            Humanoid.Health = Humanoid.Health + (Damage * Lifesteal)
        end
        if FlamingBullet then
            local Debuff = TargetHumanoid.Parent:FindFirstChild("IgniteScript") or script.IgniteScript:Clone()
            Debuff.creator.Value = Player
            Debuff.Disabled = false
            Debuff.Parent = TargetHumanoid.Parent
        end
    end
end)
Tool.Equipped:connect(function()
    Player = game.Players:GetPlayerFromCharacter(Tool.Parent)
    Character = Tool.Parent
    Humanoid = Character:FindFirstChild("Humanoid")
    --TEAM = Character:FindFirstChild("TEAM")
    if Module.DualEnabled and Workspace.FilteringEnabled then
        Handle2.CanCollide = false
        local LeftArm = Tool.Parent:FindFirstChild("Left Arm")
        local RightArm = Tool.Parent:FindFirstChild("Right Arm")
        if RightArm then
            local Grip = RightArm:WaitForChild("RightGrip", 0.01)
            if Grip then
                Grip2 = Grip:Clone()
                Grip2.Name = "LeftGrip"
                Grip2.Part0 = LeftArm
                Grip2.Part1 = Handle2
                --Grip2.C1 = Grip2.C1:inverse()
                Grip2.Parent = LeftArm
            end
        end
    end
end)
Tool.Unequipped:connect(function()
    if Module.DualEnabled and Workspace.FilteringEnabled then
        Handle2.CanCollide = true
        if Grip2 then Grip2:Destroy() end
    end
end)
