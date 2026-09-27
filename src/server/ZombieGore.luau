-- Call ApplyHit from a server attack script AFTER validating the attack.
-- This module handles visuals only; damage belongs to your attack system.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local ZombieGore = {}
local random = Random.new()
local categories = {
    Head = "Gor_Heads", -- Matches your folder spelling.
    ["Left Arm"] = "Gore_Arms",
    ["Right Arm"] = "Gore_Arms",
    Torso = "Gore_Chest",
}
local bloodTimes = setmetatable({}, { __mode = "k" })
local activeDrops = 0

function ZombieGore.GetZombie(hitPart)
    if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") then
        return nil
    end
    local npc = hitPart.Parent
    if not npc or not npc:IsA("Model") or not npc:IsDescendantOf(workspace) then
        return nil
    end
    if Players:GetPlayerFromCharacter(npc) then
        return nil
    end
    if not CollectionService:HasTag(npc, "Zombie")
        and not CollectionService:HasTag(npc, "zombie") then
        return nil
    end
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        return nil
    end
    return npc, humanoid
end

local function bloodBurst(head)
    local now = os.clock()
    if now - (bloodTimes[head] or -math.huge) < 0.15 then
        return
    end
    bloodTimes[head] = now
    for _ = 1, math.min(10, 150 - activeDrops) do
        local drop = Instance.new("Part")
        drop.Name = "ZombieBlood"
        drop.Shape = Enum.PartType.Ball
        local size = random:NextNumber(0.07, 0.16)
        drop.Size = Vector3.new(size, size, size)
        drop.Color = Color3.fromRGB(160, 0, 0)
        drop.Material = Enum.Material.SmoothPlastic
        drop.CanCollide = false
        drop.CanTouch = false
        drop.CanQuery = false
        drop.CFrame = head.CFrame

        local start = Instance.new("Attachment")
        start.Position = Vector3.new(0, size / 2, 0)
        start.Parent = drop
        local finish = Instance.new("Attachment")
        finish.Position = Vector3.new(0, -size / 2, 0)
        finish.Parent = drop
        local trail = Instance.new("Trail")
        trail.Attachment0 = start
        trail.Attachment1 = finish
        trail.Color = ColorSequence.new(drop.Color)
        trail.Transparency = NumberSequence.new(0.2, 1)
        trail.Lifetime = 0.18
        trail.FaceCamera = true
        trail.Parent = drop

        drop.Parent = workspace
        drop:SetNetworkOwner(nil)
        drop.AssemblyLinearVelocity = head.AssemblyLinearVelocity
            + Vector3.new(random:NextNumber(-18, 18), random:NextNumber(8, 24), random:NextNumber(-18, 18))
        activeDrops += 1
        drop.Destroying:Once(function()
            activeDrops -= 1
        end)
        Debris:AddItem(drop, 0.8)
    end
end

local function collectTemplates(folder, bodyPartName, results)
    for _, child in folder:GetChildren() do
        if child:IsA("Folder") then
            collectTemplates(child, bodyPartName, results)
        elseif child:IsA("Model") or child:IsA("BasePart") then
            local target = child:GetAttribute("BodyPart") or child.Name
            if target == bodyPartName and child.Archivable
                and (child:IsA("BasePart") or child:FindFirstChildWhichIsA("BasePart", true)) then
                table.insert(results, child)
            end
        end
    end
end

function ZombieGore.ApplyHit(hitPart)
    local npc = ZombieGore.GetZombie(hitPart)
    if not npc then
        return false, "Hit must be an original body part of a tagged R6 NPC"
    end
    local category = categories[hitPart.Name]
    if not category then
        return false, "Unsupported body part"
    end
    if hitPart.Name == "Head" then
        bloodBurst(hitPart)
    end
    if hitPart:FindFirstChild("GoreReplacement") then
        return true, "Already replaced"
    end

    local root = ServerStorage:FindFirstChild("Gore_Body_Folder")
    local folder = root and root:FindFirstChild(category)
    if not folder then
        return false, "Missing ServerStorage.Gore_Body_Folder." .. category
    end
    local templates = {}
    collectTemplates(folder, hitPart.Name, templates)
    if #templates == 0 then
        return false, "No matching gore template for " .. hitPart.Name
    end

    local replacement = templates[random:NextInteger(1, #templates)]:Clone()
    replacement.Name = "GoreReplacement"
    -- Templates are visual assets. Remove executable code and old joints.
    for _, object in replacement:GetDescendants() do
        if object:IsA("LuaSourceContainer") or object:IsA("JointInstance")
            or object:IsA("Constraint") then
            object:Destroy()
        end
    end
    replacement:PivotTo(hitPart.CFrame)
    local parts = {}
    if replacement:IsA("BasePart") then
        table.insert(parts, replacement)
    end
    for _, object in replacement:GetDescendants() do
        if object:IsA("BasePart") then
            table.insert(parts, object)
        end
    end
    if #parts == 0 then
        replacement:Destroy()
        return false, "Template has no cloneable BaseParts"
    end
    for _, part in parts do
        part.Anchored = false
        part.Massless = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = hitPart
        weld.Part1 = part
        weld.Parent = part
    end

    -- Preserve the original hitbox and every R6 Motor6D, including the neck.
    hitPart.Transparency = 1
    for _, object in hitPart:GetDescendants() do
        if object:IsA("Decal") or object:IsA("Texture") then
            object.Transparency = 1
        end
    end
    hitPart:SetAttribute("GoreHitbox", true)
    replacement.Parent = hitPart
    return true, "Replaced"
end

return ZombieGore
