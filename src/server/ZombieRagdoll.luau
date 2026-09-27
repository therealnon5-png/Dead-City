-- R6 corpse physics. Runs only in the central server context.
local Ragdoll = {}
local bodyNames = {
    Head = true, Torso = true, ["Left Arm"] = true, ["Right Arm"] = true,
    ["Left Leg"] = true, ["Right Leg"] = true,
}

function Ragdoll.Apply(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health > 0 or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        return false
    end
    if character:FindFirstChild("GoreRagdollConstraints") then return true end
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = false
    humanoid.AutoRotate = false
    humanoid.WalkSpeed = 0
    humanoid.PlatformStand = true
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0) end
    end
    local folder = Instance.new("Folder")
    folder.Name = "GoreRagdollConstraints"
    folder.Parent = character

    -- Preserve the root joint and Gore welds; release only anatomical Motor6Ds.
    for _, joint in ipairs(character:GetDescendants()) do
        if joint:IsA("Motor6D") and joint.Part0 and joint.Part1
            and joint.Part0.Parent == character and joint.Part1.Parent == character
            and bodyNames[joint.Part0.Name] and bodyNames[joint.Part1.Name] then
            local world = joint.Part1.CFrame * joint.C1
            local a0 = Instance.new("Attachment")
            a0.Name = "GoreRagdoll_" .. joint.Name .. "_0"
            a0.CFrame = joint.Part0.CFrame:ToObjectSpace(world)
            a0.Parent = joint.Part0
            local a1 = Instance.new("Attachment")
            a1.Name = "GoreRagdoll_" .. joint.Name .. "_1"
            a1.CFrame = joint.C1
            a1.Parent = joint.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Name = joint.Name
            socket.Attachment0, socket.Attachment1 = a0, a1
            socket.LimitsEnabled = true
            socket.UpperAngle = joint.Part1.Name == "Head" and 35 or 75
            socket.TwistLimitsEnabled = true
            socket.TwistLowerAngle = -45
            socket.TwistUpperAngle = 45
            socket.Parent = folder
            joint.Enabled = false
        end
    end
    local bodies = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanTouch = false
            part.CanCollide = part.Parent == character and bodyNames[part.Name] == true
            if part.Parent == character and (bodyNames[part.Name] or part.Name == "HumanoidRootPart") then
                part.Massless = part.Name == "HumanoidRootPart"
                table.insert(bodies, part)
            end
        end
    end
    -- Avoid limbs colliding with their own torso, while retaining floor collisions.
    for index, first in ipairs(bodies) do
        for secondIndex = index + 1, #bodies do
            local constraint = Instance.new("NoCollisionConstraint")
            constraint.Part0, constraint.Part1 = first, bodies[secondIndex]
            constraint.Parent = folder
        end
        if first:CanSetNetworkOwnership() then first:SetNetworkOwner(nil) end
    end
    character:SetAttribute("GoreRagdolled", true)
    return true
end

return Ragdoll
