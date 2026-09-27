-- ServerScriptService.Server.GoreService: one authority for zombie damage and R6 visuals.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ZombieRagdoll = require(script.Parent:WaitForChild("ZombieRagdoll"))

local GoreService = {}
GoreService.Config = {
    ZombieTag = "Zombie",
    RootFolderName = "Gore_Body_Folder",
    CorpseLifetime = 8,
    RagdollOnDeath = true, -- false: remove NPC immediately on death; true: keep corpse for CorpseLifetime.
    MatchBodyColors = true, -- false: retain the template's Color.
    UseArmGoreForLegs = true, -- Use the same-side arm if no leg template is available.
    HeadshotMultiplier = 2,
    LimbMultiplier = 0.75,
    BloodLifetime = 0.8,
    MaxBloodParts = 150,
}

local categories = {
    Head = { "Gore_Heads", "Gor_Heads" },
    Torso = { "Gore_Chest", "Gor_Chest" },
    ["Left Arm"] = { "Gore_Arms", "Gor_Arms" },
    ["Right Arm"] = { "Gore_Arms", "Gor_Arms" },
    ["Left Leg"] = { "Gore_Legs", "Gor_Legs" },
    ["Right Leg"] = { "Gore_Legs", "Gor_Legs" },
}
local random = Random.new()
local bloodCount = 0
local bloodAt = setmetatable({}, { __mode = "k" })
local deathHandled = setmetatable({}, { __mode = "k" })
local legArms = { ["Left Leg"] = "Left Arm", ["Right Leg"] = "Right Arm" }
local bodyColorProperties = {
    Head = "HeadColor3", Torso = "TorsoColor3",
    ["Left Arm"] = "LeftArmColor3", ["Right Arm"] = "RightArmColor3",
    ["Left Leg"] = "LeftLegColor3", ["Right Leg"] = "RightLegColor3",
}

local function finiteVector(value)
    return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y
        and value.Z == value.Z and math.abs(value.X) < 1e7
        and math.abs(value.Y) < 1e7 and math.abs(value.Z) < 1e7
end

function GoreService.IsZombie(character)
    return character ~= nil and (CollectionService:HasTag(character, "Zombie")
        or CollectionService:HasTag(character, "zombie"))
end

function GoreService.ResolveHit(instance)
    if typeof(instance) ~= "Instance" or not instance:IsA("BasePart") then return nil end
    local model = instance:FindFirstAncestorOfClass("Model")
    while model do
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local hostName = instance:GetAttribute("GoreHost")
            local host = hostName and model:FindFirstChild(hostName) or nil
            if not host and instance:FindFirstAncestorOfClass("Accessory") then
                host = model:FindFirstChild("Head")
            end
            if not host and instance.Parent == model and categories[instance.Name] then
                host = instance
            end
            return model, humanoid, host
        end
        model = model:FindFirstAncestorOfClass("Model")
    end
    return nil
end

function GoreService.GetZombie(instance)
    local character, humanoid, part = GoreService.ResolveHit(instance)
    if character and GoreService.IsZombie(character) and not Players:GetPlayerFromCharacter(character)
        and humanoid.RigType == Enum.HumanoidRigType.R6 then
        return character, humanoid, part
    end
    return nil
end

local function getFolder(partName)
    local root = ServerStorage:FindFirstChild(GoreService.Config.RootFolderName)
    if not root then return nil end
    for _, alias in ipairs(categories[partName] or {}) do
        local folder = root:FindFirstChild(alias)
        if folder and folder:IsA("Folder") then return folder end
    end
    return nil
end

local function collectTemplates(container, partName, result)
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Folder") then
            collectTemplates(child, partName, result)
        elseif (child:IsA("Model") or child:IsA("BasePart")) and child.Archivable then
            local target = child:GetAttribute("BodyPart") or child.Name
            if target == partName and (child:IsA("BasePart") or child:FindFirstChildWhichIsA("BasePart", true)) then
                table.insert(result, child)
            end
        end
    end
end

local function findTemplates(partName)
    local templates = {}
    local folder = getFolder(partName)
    if folder then collectTemplates(folder, partName, templates) end
    local arm = legArms[partName]
    if #templates == 0 and arm and GoreService.Config.UseArmGoreForLegs then
        local armFolder = getFolder(arm)
        if armFolder then
            -- Also allow dedicated leg variants stored in Gore_Arms with BodyPart set.
            collectTemplates(armFolder, partName, templates)
            if #templates == 0 then collectTemplates(armFolder, arm, templates) end
        end
    end
    return templates
end

local function getBodyColor(character, host)
    local colors = character:FindFirstChildOfClass("BodyColors")
    local property = bodyColorProperties[host.Name]
    return colors and property and colors[property] or host.Color
end

local function spawnBlood(part, position, normal)
    local now = os.clock()
    if now - (bloodAt[part] or -math.huge) < 0.15 then return end
    bloodAt[part] = now
    local direction = finiteVector(normal) and normal.Magnitude > 0.001 and normal.Unit or Vector3.yAxis
    for _ = 1, math.min(10, GoreService.Config.MaxBloodParts - bloodCount) do
        local drop = Instance.new("Part")
        drop.Name = "ZombieBlood"
        drop.Shape = Enum.PartType.Ball
        drop.Size = Vector3.new(0.12, 0.12, 0.12)
        drop.Color = Color3.fromRGB(160, 0, 0)
        drop.Material = Enum.Material.SmoothPlastic
        drop.CanCollide = false
        drop.CanTouch = false
        drop.CanQuery = false
        drop.CFrame = CFrame.new(position)
        local a0 = Instance.new("Attachment")
        a0.Position = Vector3.new(0, 0.1, 0)
        a0.Parent = drop
        local a1 = Instance.new("Attachment")
        a1.Position = Vector3.new(0, -0.1, 0)
        a1.Parent = drop
        local trail = Instance.new("Trail")
        trail.Attachment0, trail.Attachment1 = a0, a1
        trail.Color = ColorSequence.new(drop.Color)
        trail.Transparency = NumberSequence.new(0.2, 1)
        trail.Lifetime = 0.18
        trail.Parent = drop
        drop.Parent = workspace
        drop:SetNetworkOwner(nil)
        drop.AssemblyLinearVelocity = part.AssemblyLinearVelocity + direction * random:NextNumber(8, 22)
            + Vector3.new(random:NextNumber(-12, 12), random:NextNumber(3, 12), random:NextNumber(-12, 12))
        bloodCount += 1
        drop.Destroying:Once(function() bloodCount -= 1 end)
        Debris:AddItem(drop, GoreService.Config.BloodLifetime)
    end
end

function GoreService.ApplyGore(character, host, position, normal)
    if not GoreService.IsZombie(character) or not host or host.Parent ~= character or not categories[host.Name] then
        return false, "Invalid zombie body part"
    end
    position = finiteVector(position) and position or host.Position
    if host:GetAttribute("GoreApplied") then
        spawnBlood(host, position, normal)
        return true, "Already replaced"
    end
    local templates = findTemplates(host.Name)
    if #templates == 0 then
        spawnBlood(host, position, normal)
        return false, "No matching gore template for " .. host.Name
    end
    local clone = templates[random:NextInteger(1, #templates)]:Clone()
    clone.Name = "Gore_" .. host.Name
    for _, child in ipairs(clone:GetDescendants()) do
        if child:IsA("LuaSourceContainer") or child:IsA("Humanoid") or child:IsA("JointInstance")
            or child:IsA("Constraint") then
            child:Destroy()
        end
    end
    local parts = {}
    if clone:IsA("BasePart") then table.insert(parts, clone) end
    for _, child in ipairs(clone:GetDescendants()) do
        if child:IsA("BasePart") then table.insert(parts, child) end
    end
    if #parts == 0 then clone:Destroy() return false, "Template has no BasePart" end
    local offsetValue = clone:FindFirstChild("GoreOffset")
    local offset = offsetValue and offsetValue:IsA("CFrameValue") and offsetValue.Value or CFrame.identity
    clone:PivotTo(host.CFrame * offset)
    local tint = GoreService.Config.MatchBodyColors and getBodyColor(character, host) or nil
    for _, part in ipairs(parts) do
        -- Mark blood/bone pieces PreserveGoreColor=true to keep their asset color.
        if tint and part:GetAttribute("PreserveGoreColor") ~= true then part.Color = tint end
        part.Anchored = false
        part.Massless = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = true
        part:SetAttribute("GoreHost", host.Name)
        if categories[part.Name] or part.Name == "HumanoidRootPart" then part.Name = "GorePart" end
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1 = host, part
        weld.Parent = part
    end
    clone.Parent = character
    -- Keep R6 joints and the original hitbox so animation and hit detection continue.
    host.Transparency = 1
    host.CastShadow = false
    host:SetAttribute("GoreApplied", true)
    host:SetAttribute("GoreHitbox", true)
    for _, child in ipairs(host:GetDescendants()) do
        if child:IsA("Decal") or child:IsA("Texture") then child.Transparency = 1 end
    end
    spawnBlood(host, position, normal)
    return true, clone
end

function GoreService.ApplyHit(hitPart, position, normal)
    local character, _, host = GoreService.GetZombie(hitPart)
    if not character or not host then return false, "Hit is not a tagged R6 zombie part" end
    return GoreService.ApplyGore(character, host, position, normal)
end

function GoreService.RegisterHit(info)
    if typeof(info) ~= "table" then return false end
    local character = info.Character
    local humanoid = info.Humanoid
    local part = info.BodyPart
    local damage = info.Damage
    if typeof(character) ~= "Instance" or not character:IsA("Model") or not character:IsDescendantOf(workspace)
        or typeof(humanoid) ~= "Instance" or not humanoid:IsA("Humanoid") or humanoid.Parent ~= character
        or humanoid.Health <= 0 or character:FindFirstChildOfClass("ForceField")
        or typeof(damage) ~= "number" or damage ~= damage
        or damage <= 0 or damage > 500 then return false end
    if part ~= nil and (typeof(part) ~= "Instance" or not part:IsA("BasePart") or part.Parent ~= character) then
        return false
    end
    local attacker = info.Attacker
    if attacker ~= nil and (typeof(attacker) ~= "Instance" or not attacker:IsA("Player")) then return false end
    if attacker then
        for _, child in ipairs(humanoid:GetChildren()) do
            if child:IsA("ObjectValue") and child.Name == "creator" then child:Destroy() end
        end
        local tag = Instance.new("ObjectValue")
        tag.Name, tag.Value, tag.Parent = "creator", attacker, humanoid
        Debris:AddItem(tag, 3)
    end
    local isZombie = GoreService.IsZombie(character) and not Players:GetPlayerFromCharacter(character)
    if isZombie and part and humanoid.RigType == Enum.HumanoidRigType.R6 then
        local ok, reason = GoreService.ApplyGore(character, part, info.Position, info.Normal)
        if not ok then warn("[GoreService] " .. tostring(reason)) end
    end
    local multiplier = 1
    if isZombie and part then
        if part.Name == "Head" then multiplier = GoreService.Config.HeadshotMultiplier
        elseif part.Name ~= "Torso" then multiplier = GoreService.Config.LimbMultiplier end
    end
    local actualDamage = damage * multiplier
    humanoid:TakeDamage(actualDamage)
    return true, actualDamage
end

function GoreService.OnZombieDied(character)
    if deathHandled[character] or not character.Parent then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health > 0 then return end
    deathHandled[character] = true
    character:SetAttribute("GoreDead", true)
    if not GoreService.Config.RagdollOnDeath then
        character:Destroy()
        return
    end
    if not ZombieRagdoll.Apply(character) then
        warn("[GoreService] Ragdoll requires an intact R6 rig: " .. character.Name)
    end
    if GoreService.Config.CorpseLifetime > 0 then
        Debris:AddItem(character, GoreService.Config.CorpseLifetime)
    end
end

function GoreService.Init()
    local root = ServerStorage:FindFirstChild(GoreService.Config.RootFolderName)
    if not root then
        warn("[GoreService] Missing ServerStorage." .. GoreService.Config.RootFolderName)
        return false
    end
    for _, name in ipairs({ "Head", "Torso", "Left Arm", "Right Arm" }) do
        local folder = getFolder(name)
        local templates = {}
        if folder then collectTemplates(folder, name, templates) end
        if #templates == 0 then warn("[GoreService] Missing template for " .. name) end
    end
    return true
end

return GoreService
