-- Native first-person mouse look with camera motion and the player's real arms.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local RENDER_NAME = "DeadCityFirstPersonCamera"
local BASE_FOV = 72
local MOTION_SCALE = 1 -- Set to 0 to disable camera bob, lean, and landing motion.
local WALK_SPEED = math.max(Config.Movement.WalkSpeed, 1)
local originalMode = player.CameraMode
local originalMouseIcon = UserInputService.MouseIconEnabled
local originalMouseBehavior = UserInputService.MouseBehavior
local originalFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local character, humanoid, root
local generation = 0
local alive = true
local connections = {}
local parts, shoulders = {}, {}
local phase, moveWeight, roll, impact, impactVelocity, fallSpeed = 0, 0, 0, 0, 0, 0
local wasGrounded = true
local wasJumping = false
local bodyRay = RaycastParams.new()
bodyRay.FilterType = Enum.RaycastFilterType.Exclude
local bodyNames = {
    ["Left Arm"] = true, ["Right Arm"] = true,
    Torso = true, ["Left Leg"] = true, ["Right Leg"] = true,
    UpperTorso = true, LowerTorso = true,
    LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
    RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
    LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
    RightUpperArm = true, RightLowerArm = true, RightHand = true,
}

-- A Frame is not a button and cannot release mouse capture like a modal GUI.
local gui = Instance.new("ScreenGui")
gui.Name = "DeadCityCrosshair"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
local dot = Instance.new("Frame")
dot.Name = "CenterDot"
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(4, 4)
dot.BackgroundColor3 = Color3.new(1, 1, 1)
dot.BorderSizePixel = 0
dot.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = dot
gui.Parent = player:WaitForChild("PlayerGui")
player.CameraMode = Enum.CameraMode.LockFirstPerson

local function smooth(rate, dt)
    return 1 - math.exp(-rate * dt)
end

local function restoreCharacter()
    for part, previous in parts do
        if part.Parent then part.LocalTransparencyModifier = previous end
    end
    for joint, original in shoulders do
        if joint.Parent then joint.C0 = original end
    end
    table.clear(parts)
    table.clear(shoulders)
    character, humanoid, root = nil, nil, nil
end

local function setup(newCharacter)
    generation += 1
    local thisGeneration = generation
    restoreCharacter()
    local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
    local newRoot = newCharacter:WaitForChild("HumanoidRootPart", 10)
    if not alive or generation ~= thisGeneration or player.Character ~= newCharacter
        or not newHumanoid or not newRoot then return end
    character, humanoid, root = newCharacter, newHumanoid, newRoot
    bodyRay.FilterDescendantsInstances = { character }
    phase, moveWeight, roll, impact, impactVelocity, fallSpeed = 0, 0, 0, 0, 0, 0
    wasGrounded = humanoid.FloorMaterial ~= Enum.Material.Air
    wasJumping = false
    local torso = character:FindFirstChild("Torso")
    if torso then
        for _, name in { "Left Shoulder", "Right Shoulder" } do
            local joint = torso:FindFirstChild(name)
            if joint and joint:IsA("Motor6D") then shoulders[joint] = joint.C0 end
        end
    end
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
    end
end

RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, function(rawDt)
    local camera = workspace.CurrentCamera
    local playing = humanoid and humanoid.Health > 0 and root and root.Parent
    local interacting = GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil
    gui.Enabled = playing ~= nil and playing ~= false and not interacting
    player.CameraMode = Enum.CameraMode.LockFirstPerson
    if not playing or not camera then return end

    -- Roblox's CameraModule handles mouse input, yaw, pitch, and character facing.
    -- Keep capture enforced after that module updates. Shift never unlocks it.
    if not interacting then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end

    -- Run after Roblox's transparency controller, which normally hides all limbs.
    -- These are the real avatar parts, retaining sleeves, skin, meshes and animation.
    for _, object in character:GetDescendants() do
        if object:IsA("BasePart") then
            if parts[object] == nil then parts[object] = object.LocalTransparencyModifier end
            local visible = (object.Parent == character and bodyNames[object.Name])
                or object:FindFirstAncestorWhichIsA("Tool") ~= nil
            object.LocalTransparencyModifier = visible and 0 or 1
        end
    end

    local dt = math.min(rawDt, 1 / 30)
    local velocity = root.AssemblyLinearVelocity
    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
    local jumping = humanoid:GetState() == Enum.HumanoidStateType.Jumping
    if jumping and not wasJumping then impactVelocity = -1.5 end
    if not grounded then fallSpeed = math.max(fallSpeed, -velocity.Y) end
    if grounded and not wasGrounded then
        impactVelocity = -math.clamp(fallSpeed * 0.1, 1.3, 4)
        fallSpeed = 0
    end
    wasGrounded, wasJumping = grounded, jumping
    impactVelocity += (-95 * impact - 17 * impactVelocity) * dt
    impact += impactVelocity * dt
    local walking = grounded and humanoid.MoveDirection.Magnitude > 0.05 and not humanoid.Sit
    local targetMove = walking and math.clamp(speed / WALK_SPEED, 0, 1.6) or 0
    moveWeight += (targetMove - moveWeight) * smooth(10, dt)
    if walking then phase += dt * math.min(speed, 28) * 0.65 end
    local strafe = camera.CFrame.RightVector:Dot(velocity)
    roll += (math.clamp(-strafe / 500, -0.025, 0.025) - roll) * smooth(8, dt)
    -- Move the eye slightly in front of the torso when looking down so the
    -- chest does not fill the whole view. Stop the offset short of walls.
    local lookDown = math.clamp((-camera.CFrame.LookVector.Y - 0.15) / 0.65, 0, 1)
    local forward = root.CFrame.LookVector * (0.55 * lookDown)
    if forward.Magnitude > 0.001 then
        local obstruction = workspace:Raycast(camera.CFrame.Position, forward, bodyRay)
        if obstruction then
            forward = forward.Unit * math.max(0, obstruction.Distance - 0.1)
        end
        camera.CFrame += forward
    end
    camera.CFrame *= CFrame.new(
        math.sin(phase) * 0.038 * moveWeight * MOTION_SCALE,
        (math.cos(phase * 2) * 0.045 * moveWeight + impact) * MOTION_SCALE,
        0
    ) * CFrame.Angles(
        (impact * 0.09 + math.sin(phase * 2) * 0.004 * moveWeight) * MOTION_SCALE,
        0, (roll + math.sin(phase) * 0.006 * moveWeight) * MOTION_SCALE
    )
    local sprintFov = character:GetAttribute("IsSprinting") and math.min(moveWeight, 1) * 5 or 0
    camera.FieldOfView += (BASE_FOV + moveWeight * 3 + sprintFov - camera.FieldOfView) * smooth(5, dt)

    -- Lift the actual R6 arms into the lower view. The Animator's running motion
    -- still plays through Motor6D.Transform. Equipped Tools retain their own pose.
    local toolEquipped = character:FindFirstChildOfClass("Tool") ~= nil
    local pitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
    for joint, original in shoulders do
        if joint.Parent then
            if toolEquipped then
                joint.C0 = original
            else
                local lift = math.clamp(0.55 + pitch * 0.65, -0.45, 1.35)
                local target = CFrame.new(original.Position)
                    * CFrame.Angles(lift, 0, 0) * original.Rotation
                joint.C0 = joint.C0:Lerp(target, smooth(12, dt))
            end
        end
    end
end)

table.insert(connections, player.CharacterAdded:Connect(setup))
table.insert(connections, player.CharacterRemoving:Connect(function()
    generation += 1
    restoreCharacter()
end))
script.Destroying:Connect(function()
    alive = false
    generation += 1
    RunService:UnbindFromRenderStep(RENDER_NAME)
    for _, connection in connections do connection:Disconnect() end
    restoreCharacter()
    gui:Destroy()
    player.CameraMode = originalMode
    UserInputService.MouseIconEnabled = originalMouseIcon
    UserInputService.MouseBehavior = originalMouseBehavior
    if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = originalFov end
end)
if player.Character then task.spawn(setup, player.Character) end
