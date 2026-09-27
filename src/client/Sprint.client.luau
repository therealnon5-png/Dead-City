-- Hold either Shift to sprint. Sends intent only; speed is chosen by the server.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local request = ReplicatedStorage:WaitForChild("DeadCityRemotes"):WaitForChild("SprintRequest")
local held = {}
local sent = false
local connections = {}

local function update()
    local sprinting = next(held) ~= nil
    if sprinting ~= sent then
        sent = sprinting
        request:FireServer(sprinting)
    end
end
local function release()
    table.clear(held)
    update()
end
local function isShift(key)
    return key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift
end
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
    if processed or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
    if isShift(input.KeyCode) then held[input.KeyCode] = true; update() end
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(input)
    if isShift(input.KeyCode) then held[input.KeyCode] = nil; update() end
end))
table.insert(connections, UserInputService.WindowFocusReleased:Connect(release))
table.insert(connections, UserInputService.TextBoxFocused:Connect(release))
table.insert(connections, GuiService.MenuOpened:Connect(release))
table.insert(connections, Players.LocalPlayer.CharacterRemoving:Connect(release))
table.insert(connections, Players.LocalPlayer.CharacterAdded:Connect(release))
script.Destroying:Connect(function()
    release()
    for _, connection in connections do connection:Disconnect() end
end)
