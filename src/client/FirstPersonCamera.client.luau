-- Native first-person mouse look with camera motion and the player's real arms.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local RENDER_NAME = "DeadCityFirstPersonCamera"
local RESET_RENDER_NAME = RENDER_NAME .. "ResetEffects"
local BASE_FOV = 72
local MOTION_SCALE = 1 -- Set to 0 to disable camera bob, lean, and landing motion.
local originalMode = player.CameraMode
local originalMouseIcon = UserInputService.MouseIconEnabled
local originalMouseBehavior = UserInputService.MouseBehavior
local originalFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local character, humanoid, root
local generation = 0
local alive = true
local connections = {}
local parts = {}
local effectCamera, nativeCameraFrame, renderedCameraFrame
local phase, moveWeight, roll, impact, impactVelocity, fallSpeed = 0, 0, 0, 0, 0, 0
local wasGrounded = true
local wasJumping = false
local armNames = {
    ["Left Arm"] = true, ["Right Arm"] = true,
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

local function removeCameraEffects()
    -- The native camera reads last frame's orientation when calculating mouse look.
    -- Give it the unmodified frame so cosmetic roll cannot accumulate near vertical.
    -- Do not overwrite another script's camera change (e.g. a cutscene or recoil).
    if effectCamera and effectCamera == workspace.CurrentCamera
        and effectCamera.CFrame == renderedCameraFrame then
        effectCamera.CFrame = nativeCameraFrame
    end
    effectCamera, nativeCameraFrame, renderedCameraFrame = nil, nil, nil
end

local function restoreCharacter()
    removeCameraEffects()
    for part, previous in parts do
        if part.Parent then part.LocalTransparencyModifier = previous end
    end
    table.clear(parts)
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
    phase, moveWeight, roll, impact, impactVelocity, fallSpeed = 0, 0, 0, 0, 0, 0
    wasGrounded = humanoid.FloorMaterial ~= Enum.Material.Air
    wasJumping = false
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
    end
end

RunService:BindToRenderStep(RESET_RENDER_NAME, Enum.RenderPriority.Camera.Value - 1, removeCameraEffects)
RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, function(rawDt)
    local camera = workspace.CurrentCamera
    local playing = humanoid and humanoid.Health > 0 and root and root.Parent
    local interacting = GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil
        or player:GetAttribute("InventoryOpen") == true
    gui.Enabled = playing ~= nil and playing ~= false and not interacting
    player.CameraMode = Enum.CameraMode.LockFirstPerson
    if not playing or not camera then return end
    if camera.CameraType ~= Enum.CameraType.Custom or camera.CameraSubject ~= humanoid then return end

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
            local visible = (object.Parent == character and armNames[object.Name])
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
    local targetMove = grounded and math.clamp(speed / math.max(humanoid.WalkSpeed, 1), 0, 1.4) or 0
    moveWeight += (targetMove - moveWeight) * smooth(10, dt)
    phase += dt * math.min(speed, 28) * 0.75
    local strafe = camera.CFrame.RightVector:Dot(velocity)
    roll += (math.clamp(-strafe / 500, -0.025, 0.025) - roll) * smooth(8, dt)
    effectCamera = camera
    nativeCameraFrame = camera.CFrame
    camera.CFrame = nativeCameraFrame * CFrame.new(
        math.sin(phase) * 0.022 * moveWeight * MOTION_SCALE,
        (math.cos(phase * 2) * 0.025 * moveWeight + impact) * MOTION_SCALE,
        0
    ) * CFrame.Angles(impact * 0.09 * MOTION_SCALE, 0, roll * MOTION_SCALE)
    renderedCameraFrame = camera.CFrame
    camera.FieldOfView += (BASE_FOV + moveWeight * 3 - camera.FieldOfView) * smooth(5, dt)

    -- Leave real body joints entirely to Animate and the equipped weapon.
    -- Looking up/down must never bend the physical arms or their attached Tool.
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
    RunService:UnbindFromRenderStep(RESET_RENDER_NAME)
    for _, connection in connections do connection:Disconnect() end
    restoreCharacter()
    gui:Destroy()
    player.CameraMode = originalMode
    UserInputService.MouseIconEnabled = originalMouseIcon
    UserInputService.MouseBehavior = originalMouseBehavior
    if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = originalFov end
end)
if player.Character then task.spawn(setup, player.Character) end
