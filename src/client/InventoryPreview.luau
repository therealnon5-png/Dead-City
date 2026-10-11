-- Local visual mirror only: never changes the real player's joints or equipment.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Preview = {}
Preview.__index = Preview

local function disconnectAll(list)
    for _, connection in ipairs(list) do connection:Disconnect() end
    table.clear(list)
end

local function pairChildren(source, copy, output)
    table.insert(output, { source, copy })
    local candidates = copy:GetChildren()
    local used = {}
    for _, child in ipairs(source:GetChildren()) do
        if child.Archivable then
            for index, candidate in ipairs(candidates) do
                if not used[index] and candidate.Name == child.Name and candidate.ClassName == child.ClassName then
                    used[index] = true
                    pairChildren(child, candidate, output)
                    break
                end
            end
        end
    end
end

function Preview.new(viewport, character)
    local self = setmetatable({}, Preview)
    self.viewport, self.character = viewport, character
    self.connections, self.appearanceConnections, self.parts = {}, {}, {}
    self.dirty, self.lastBuild = true, -math.huge
    self.yaw, self.pitch = 0, 0
    self.previousCamera = viewport.CurrentCamera
    self.world = Instance.new("WorldModel")
    self.world.Name = "InventoryCharacterWorld"
    self.world.Parent = viewport
    self.camera = Instance.new("Camera")
    self.camera.Name = "InventoryPortraitCamera"
    self.camera.FieldOfView = 35
    self.camera.Parent = viewport
    viewport.CurrentCamera = self.camera
    local function markDirty() self.dirty = true end
    table.insert(self.connections, character.DescendantAdded:Connect(markDirty))
    table.insert(self.connections, character.DescendantRemoving:Connect(markDirty))
    return self
end

function Preview:Rebuild()
    local root = self.character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local originalArchivable = self.character.Archivable
    self.character.Archivable = true
    local ok, clone = pcall(function() return self.character:Clone() end)
    self.character.Archivable = originalArchivable
    if not ok or not clone then return end
    local pairsList = {}
    pairChildren(self.character, clone, pairsList)
    local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
    if cloneHumanoid then
        cloneHumanoid.RequiresNeck = false
        cloneHumanoid.BreakJointsOnDeath = false
        cloneHumanoid.AutoRotate = false
    end
    disconnectAll(self.appearanceConnections)
    self.parts = {}
    local head = self.character:FindFirstChild("Head")
    for _, pair in ipairs(pairsList) do
        local source, copy = pair[1], pair[2]
        if source:IsA("BasePart") then
            local followsHead = source == head
            local accessory = source:FindFirstAncestorWhichIsA("Accessory")
            if accessory then
                local handle = accessory:FindFirstChild("Handle")
                local weld = handle and handle:FindFirstChild("AccessoryWeld")
                followsHead = weld ~= nil and (weld.Part0 == head or weld.Part1 == head)
            end
            copy.Anchored = true
            copy.CanCollide, copy.CanTouch, copy.CanQuery = false, false, false
            copy.LocalTransparencyModifier = 0
            table.insert(self.parts, { source = source, copy = copy, followsHead = followsHead })
            if source:IsA("MeshPart") then
                for _, property in ipairs({ "MeshId", "TextureID" }) do
                    table.insert(self.appearanceConnections, source:GetPropertyChangedSignal(property):Connect(function() self.dirty = true end))
                end
            end
        elseif source:IsA("Shirt") or source:IsA("Pants") or source:IsA("ShirtGraphic")
            or source:IsA("CharacterMesh") or source:IsA("DataModelMesh")
            or source:IsA("Decal") or source:IsA("SurfaceAppearance") or source:IsA("BodyColors") then
            table.insert(self.appearanceConnections, source.Changed:Connect(function() self.dirty = true end))
        end
    end
    for _, object in ipairs(clone:GetDescendants()) do
        if object:IsA("LuaSourceContainer") or object:IsA("JointInstance") or object:IsA("Constraint")
            or object:IsA("Animator") or object:IsA("Sound") or object:IsA("ParticleEmitter")
            or object:IsA("Trail") or object:IsA("Beam") or object:IsA("BillboardGui") then
            object:Destroy()
        elseif object:IsA("Humanoid") then
            object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
    if self.model then self.model:Destroy() end
    self.model = clone
    clone.Name = "PlayerPreview"
    clone.Parent = self.world
    -- Fit the body, excluding large Tools so equipping does not zoom the face away.
    local low, high = Vector3.new(-1.5, -3, -1), Vector3.new(1.5, 3, 1)
    for _, entry in ipairs(self.parts) do
        if entry.source.Parent == self.character then
            local position = root.CFrame:PointToObjectSpace(entry.source.Position)
            local half = entry.source.Size / 2
            low = Vector3.new(math.min(low.X, position.X - half.X), math.min(low.Y, position.Y - half.Y), math.min(low.Z, position.Z - half.Z))
            high = Vector3.new(math.max(high.X, position.X + half.X), math.max(high.Y, position.Y + half.Y), math.max(high.Z, position.Z + half.Z))
        end
    end
    self.height, self.width, self.centerY = high.Y - low.Y, high.X - low.X, (high.Y + low.Y) / 2
    self.dirty, self.lastBuild = false, os.clock()
end

function Preview:Step(dt)
    if self.dirty and os.clock() - self.lastBuild > 0.1 then self:Rebuild() end
    local root = self.character:FindFirstChild("HumanoidRootPart")
    if not root or not self.model then return end
    local size = self.viewport.AbsoluteSize
    if size.X < 1 or size.Y < 1 then return end
    local mouse = UserInputService:GetMouseLocation()
    local screen = self.viewport:FindFirstAncestorWhichIsA("ScreenGui")
    if screen and not screen.IgnoreGuiInset then
        local inset = GuiService:GetGuiInset()
        mouse = mouse - inset
    end
    local relative = mouse - (self.viewport.AbsolutePosition + size / 2)
    local targetYaw = math.clamp(relative.X / (size.X / 2), -1, 1) * math.rad(35)
    local targetPitch = -math.clamp(relative.Y / (size.Y / 2), -1, 1) * math.rad(20)
    local alpha = 1 - math.exp(-10 * math.min(dt, 0.1))
    self.yaw = self.yaw + (targetYaw - self.yaw) * alpha
    self.pitch = self.pitch + (targetPitch - self.pitch) * alpha
    local display = CFrame.Angles(0, math.pi + self.yaw * 0.25, 0)
    local head = self.character:FindFirstChild("Head")
    local headPosition = head and root.CFrame:PointToObjectSpace(head.Position) or Vector3.new(0, 1.5, 0)
    local headTurn = CFrame.new(headPosition) * CFrame.Angles(self.pitch, self.yaw * 0.75, 0) * CFrame.new(-headPosition)
    for _, entry in ipairs(self.parts) do
        local source, copy = entry.source, entry.copy
        if source:IsDescendantOf(self.character) and copy.Parent then
            local pose = root.CFrame:ToObjectSpace(source.CFrame)
            copy.CFrame = display * (entry.followsHead and headTurn * pose or pose)
            copy.Color, copy.Material, copy.Size = source.Color, source.Material, source.Size
            copy.Transparency = source.Transparency
            copy.LocalTransparencyModifier = 0 -- Ignore first-person hiding on the live rig.
        end
    end
    local aspect = size.X / size.Y
    local distance = math.max(self.height, self.width / aspect) * 0.58 / math.tan(math.rad(self.camera.FieldOfView / 2)) + 1
    local center = Vector3.new(0, self.centerY, 0)
    self.camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0.2, distance), center)
end

function Preview:Destroy()
    disconnectAll(self.connections)
    disconnectAll(self.appearanceConnections)
    if self.viewport.CurrentCamera == self.camera then self.viewport.CurrentCamera = self.previousCamera end
    self.world:Destroy()
    self.camera:Destroy()
end

return Preview
