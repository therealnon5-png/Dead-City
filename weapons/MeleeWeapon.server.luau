-- Server Script: replace the existing Script inside your melee Tool with this.
-- Keep the Tool's Handle, Hit/Swing sounds, and ChopR6/ChopR15 animations.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
local Gore = require(ServerScriptService:WaitForChild("Server"):WaitForChild("ZombieGore"))

local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle")
local HitSound = Handle:WaitForChild("Hit")
local SwingSound = Handle:WaitForChild("Swing")

local DAMAGE = 20
local SWING_DURATION = 0.8
local MAX_HIT_DISTANCE = 12 -- Studs from the attacker's root; adjust for weapon size.
local goreParts = { Head = true, Torso = true, ["Left Arm"] = true, ["Right Arm"] = true }

local player, character, humanoid, chopAnimation
local swinging = false
local swingId = 0
local nextSwingAt = 0
local hitHumanoids = {}
Tool.Enabled = true

local function isTeamMate(first, second)
    return first and second and not first.Neutral and not second.Neutral
        and first.TeamColor == second.TeamColor
end

local function tagHumanoid(target)
    for _, child in target:GetChildren() do
        if child:IsA("ObjectValue") and child.Name == "creator" then
            child:Destroy()
        end
    end
    local tag = Instance.new("ObjectValue")
    tag.Name = "creator"
    tag.Value = player
    tag.Parent = target
    Debris:AddItem(tag, 2)
end

local function clearEquip()
    swingId += 1 -- Invalidate delayed callbacks from an earlier equip/swing.
    swinging = false
    hitHumanoids = {}
    if chopAnimation then
        chopAnimation:Stop()
        chopAnimation:Destroy()
        chopAnimation = nil
    end
    player, character, humanoid = nil, nil, nil
    Tool.Enabled = true
end

local function equipped()
    clearEquip()
    local owner = Tool.Parent
    local ownerPlayer = Players:GetPlayerFromCharacter(owner)
    local ownerHumanoid = owner:FindFirstChildOfClass("Humanoid")
    if not ownerPlayer or not ownerHumanoid or ownerHumanoid.Health <= 0 then
        return
    end
    player, character, humanoid = ownerPlayer, owner, ownerHumanoid

    local animation = Tool:FindFirstChild("Chop" .. humanoid.RigType.Name)
    if animation and animation:IsA("Animation") then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        local ok, track = pcall(function()
            return animator:LoadAnimation(animation)
        end)
        if ok then
            chopAnimation = track
        else
            warn("Unable to load melee animation: " .. tostring(track))
        end
    else
        warn("Missing Chop" .. humanoid.RigType.Name .. " Animation in " .. Tool.Name)
    end
end

local function activated()
    if not Tool.Enabled or swinging or not humanoid or humanoid.Health <= 0
        or Tool.Parent ~= character or os.clock() < nextSwingAt then
        return
    end
    Tool.Enabled = false
    swinging = true
    hitHumanoids = {}
    nextSwingAt = os.clock() + SWING_DURATION
    swingId += 1
    local thisSwing = swingId
    if chopAnimation then chopAnimation:Play() end
    SwingSound:Play()

    task.delay(SWING_DURATION, function()
        if swingId ~= thisSwing then return end
        swinging = false
        hitHumanoids = {}
        Tool.Enabled = true
    end)
end

local function touched(hit)
    if not swinging or os.clock() >= nextSwingAt or not humanoid or humanoid.Health <= 0
        or Tool.Parent ~= character or not hit or not hit:IsA("BasePart") then
        return
    end
    if hit:IsDescendantOf(character) or hit.Name == "HumanoidRootPart" then return end

    -- Only actual character parts count: accessories and cosmetic gore do not.
    local target = hit.Parent
    if not target or not target:IsA("Model") then return end
    local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 or hitHumanoids[targetHumanoid]
        or target:FindFirstChildOfClass("ForceField")
        or isTeamMate(Players:GetPlayerFromCharacter(target), player) then
        return
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or (hit.Position - root.Position).Magnitude > MAX_HIT_DISTANCE then return end

    -- One damage application per humanoid per swing, even if multiple limbs touch.
    hitHumanoids[targetHumanoid] = true
    tagHumanoid(targetHumanoid)

    -- Run before damage so lethal hits get their replacement and blood effect too.
    if goreParts[hit.Name] and Gore.GetZombie(hit) then
        local callOk, applied, reason = pcall(Gore.ApplyHit, hit)
        if not callOk then
            warn("Zombie gore error: " .. tostring(applied))
        elseif not applied then
            warn("Zombie gore: " .. tostring(reason))
        end
    end
    targetHumanoid:TakeDamage(DAMAGE)
    HitSound:Play()
end

-- Connect once to avoid duplicate callbacks when re-equipping.
Tool.Activated:Connect(activated)
Handle.Touched:Connect(touched)
Tool.Equipped:Connect(equipped)
Tool.Unequipped:Connect(clearEquip)

if Tool.Parent:IsA("Model") and Players:GetPlayerFromCharacter(Tool.Parent) then
    equipped()
end
