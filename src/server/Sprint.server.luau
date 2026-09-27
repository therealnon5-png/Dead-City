local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local remotes = ReplicatedStorage:FindFirstChild("DeadCityRemotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "DeadCityRemotes"
    remotes.Parent = ReplicatedStorage
end
local request = remotes:FindFirstChild("SprintRequest")
if not request then
    request = Instance.new("RemoteEvent")
    request.Name = "SprintRequest"
    request.Parent = remotes
end

local states = {}
local function apply(player)
    local state = states[player]
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not state or not humanoid then return end
    local sprinting = state.held and humanoid.Health > 0 and not humanoid.Sit
    character:SetAttribute("IsSprinting", sprinting)
    humanoid.WalkSpeed = sprinting and Config.Movement.SprintSpeed or Config.Movement.WalkSpeed
end

local function setupCharacter(player, character)
    local state = states[player]
    if not state then return end
    state.held = false
    if state.seated then state.seated:Disconnect(); state.seated = nil end
    if state.died then state.died:Disconnect(); state.died = nil end
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid or player.Character ~= character or states[player] ~= state then return end
    state.seated = humanoid:GetPropertyChangedSignal("Sit"):Connect(function() apply(player) end)
    state.died = humanoid.Died:Connect(function()
        state.held = false
        apply(player)
    end)
    apply(player)
end

local function setupPlayer(player)
    if states[player] then return end
    local state = { held = false }
    states[player] = state
    state.added = player.CharacterAdded:Connect(function(character) setupCharacter(player, character) end)
    if player.Character then task.spawn(setupCharacter, player, player.Character) end
end

request.OnServerEvent:Connect(function(player, held)
    if typeof(held) ~= "boolean" then return end
    local state = states[player]
    if not state or state.held == held then return end
    state.held = held
    apply(player)
end)
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
    local state = states[player]
    if not state then return end
    for _, key in { "added", "seated", "died" } do
        if state[key] then state[key]:Disconnect() end
    end
    states[player] = nil
end)
for _, player in Players:GetPlayers() do setupPlayer(player) end
