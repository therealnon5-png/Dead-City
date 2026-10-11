local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Preview
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ACTION = "DeadCityToggleInventory"
local RENDER = "DeadCityInventory"
local inventory, modal, preview, savedCamera
local opened = false
local connections, guiConnections, buttons = {}, {}, {}
local remote, revision = nil, 0
local attach

local function destroyPreview()
    if preview then preview:Destroy(); preview = nil end
end

local function startPreview()
    destroyPreview()
    if not inventory or not player.Character then return end
    local frame = inventory:FindFirstChild("CharacterFrame", true)
    local viewport = frame and frame:FindFirstChild("ViewportFrame", true)
    if viewport and viewport:IsA("ViewportFrame") then
        if not Preview then
            local module = script.Parent:FindFirstChild("InventoryPreview")
            if not module then warn("Inventory is open, but InventoryPreview is missing"); return end
            local ok, result = pcall(require, module)
            if not ok then warn("Inventory preview failed to load: " .. tostring(result)); return end
            Preview = result
        end
        local ok, result = pcall(Preview.new, viewport, player.Character)
        if ok then preview = result else warn("Inventory preview failed: " .. tostring(result)) end
    else
        warn("InventoryGui needs CharacterFrame.ViewportFrame for the character preview")
    end
end

local function setOpen(value)
    if value and not inventory then
        warn("Put your InventoryGui ScreenGui inside StarterGui, then restart Play")
        return
    end
    -- Enabled is the actual open/closed state, including when another script edits it.
    if inventory and inventory.Enabled ~= value then inventory.Enabled = value end
    if opened == value then return end
    opened = value
    player:SetAttribute("InventoryOpen", opened)
    if modal then modal.Visible = opened end
    if opened then
        local camera = workspace.CurrentCamera
        if camera then
            savedCamera = { camera = camera, kind = camera.CameraType }
            camera.CameraType = Enum.CameraType.Scriptable
        end
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        startPreview()
    else
        destroyPreview()
        if savedCamera and savedCamera.camera == workspace.CurrentCamera
            and savedCamera.camera.CameraType == Enum.CameraType.Scriptable then
            savedCamera.camera.CameraType = savedCamera.kind
        end
        savedCamera = nil
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
    end
end

local function requestOpen(value)
    revision = revision + 1
    setOpen(value) -- Immediate UI feedback; never wait for the network or preview.
    if remote then remote:FireServer(value, revision) end
end

local function connectButton(object)
    if not object:IsA("GuiButton") or buttons[object] then return end
    local name = string.lower(object.Name):gsub("[%s_%-]", "")
    if object:GetAttribute("InventoryAction") == "Close" or name == "close" or name == "closebutton"
        or name == "closebtn" or name == "exitbutton" or name == "x" then
        buttons[object] = true
        table.insert(guiConnections, object.Activated:Connect(function() requestOpen(false) end))
    end
end

local function detach()
    requestOpen(false)
    for _, connection in ipairs(guiConnections) do connection:Disconnect() end
    table.clear(guiConnections)
    table.clear(buttons)
    if modal then modal:Destroy(); modal = nil end
    inventory = nil
end

attach = function(candidate)
    if candidate.Name ~= "InventoryGui" or not candidate:IsA("ScreenGui") or candidate == inventory then return end
    detach()
    inventory = candidate
    inventory.Enabled = false
    player:SetAttribute("InventoryOpen", false)
    modal = Instance.new("TextButton")
    modal.Name = "InventoryMouseCapture"
    modal.Size = UDim2.fromOffset(1, 1)
    modal.BackgroundTransparency = 1
    modal.Text = ""
    modal.Modal = true
    modal.Selectable = false
    modal.Visible = false
    modal.Parent = inventory
    for _, object in ipairs(inventory:GetDescendants()) do connectButton(object) end
    table.insert(guiConnections, inventory.DescendantAdded:Connect(function(object)
        connectButton(object)
        if opened and object:IsA("ViewportFrame") then startPreview() end
    end))
    table.insert(guiConnections, inventory:GetPropertyChangedSignal("Enabled"):Connect(function()
        setOpen(inventory.Enabled)
    end))
end

ContextActionService:BindActionAtPriority(ACTION, function(_, state)
    if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
    return Enum.ContextActionResult.Sink -- I must not also trigger Roblox camera zoom.
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.I)

-- Do not reject gameProcessed here: Roblox's own I zoom binding can consume it.
-- Text entry and the Escape menu are explicitly excluded instead.
table.insert(connections, UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode ~= Enum.KeyCode.I or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return end
    if not inventory then
        local candidate = playerGui:FindFirstChild("InventoryGui", true)
        if candidate then attach(candidate) end
    end
    if not inventory then
        warn("InventoryGui ScreenGui not found in PlayerGui. Keep it in StarterGui and restart Play.")
        return
    end
    requestOpen(not inventory.Enabled)
end))

local function connectRemote(candidate)
    if candidate.Name ~= "InventoryToggle" or not candidate:IsA("RemoteEvent") or candidate == remote then return end
    remote = candidate
    table.insert(connections, candidate.OnClientEvent:Connect(function(enabled, responseRevision)
        if typeof(enabled) == "boolean" and responseRevision == revision then setOpen(enabled) end
    end))
    if revision > 0 then remote:FireServer(opened, revision) end
end
table.insert(connections, ReplicatedStorage.ChildAdded:Connect(connectRemote))
local existingRemote = ReplicatedStorage:FindFirstChild("InventoryToggle")
if existingRemote then connectRemote(existingRemote) end

table.insert(connections, playerGui.DescendantAdded:Connect(attach))
table.insert(connections, playerGui.DescendantRemoving:Connect(function(child)
    if child == inventory then detach() end
end))
table.insert(connections, player.CharacterRemoving:Connect(function() requestOpen(false) end))
table.insert(connections, player.CharacterAdded:Connect(function() requestOpen(false) end))
table.insert(connections, GuiService.MenuOpened:Connect(function() requestOpen(false) end))
for _, child in ipairs(playerGui:GetDescendants()) do attach(child) end
RunService:BindToRenderStep(RENDER, Enum.RenderPriority.Camera.Value + 5, function(dt)
    if not opened then return end
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    if preview then
        local ok, err = pcall(preview.Step, preview, dt)
        if not ok then destroyPreview(); warn("Inventory preview stopped: " .. tostring(err)) end
    end
end)
script.Destroying:Connect(function()
    detach()
    ContextActionService:UnbindAction(ACTION)
    RunService:UnbindFromRenderStep(RENDER)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    player:SetAttribute("InventoryOpen", false)
end)
