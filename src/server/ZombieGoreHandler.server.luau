local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local GoreService = require(script.Parent:WaitForChild("GoreService"))

GoreService.Init()
local remotes = ReplicatedStorage:FindFirstChild("GoreRemotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "GoreRemotes"
    remotes.Parent = ReplicatedStorage
end
local weaponHit = remotes:FindFirstChild("WeaponHit")
if not weaponHit then
    weaponHit = Instance.new("RemoteEvent")
    weaponHit.Name = "WeaponHit"
    weaponHit.Parent = remotes
end
local goreHitEvent = ServerStorage:FindFirstChild("GoreHitEvent")
if not goreHitEvent then
    goreHitEvent = Instance.new("BindableEvent")
    goreHitEvent.Name = "GoreHitEvent"
    goreHitEvent.Parent = ServerStorage
end
goreHitEvent.Event:Connect(function(info)
    GoreService.RegisterHit(info)
end)

-- Tool scripts can be sandboxed. Listen to an event inside each Tool rather
-- than requiring GoreService or firing a BindableEvent outside that container.
local watchedTools = setmetatable({}, { __mode = "k" })
local watchedEvents = setmetatable({}, { __mode = "k" })
local function connectVisualEvent(tool, event)
    if event.Name ~= "GoreVisualHit" or not event:IsA("BindableEvent")
        or watchedEvents[event] then return end
    watchedEvents[event] = true
    event.Event:Connect(function(hitPart, hitPosition)
        if tool.Parent == nil or not tool:IsDescendantOf(workspace) then return end
        local character = tool.Parent
        local player = Players:GetPlayerFromCharacter(character)
        local attacker = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local handle = tool:FindFirstChild("Handle")
        if not player or not attacker or attacker.Health <= 0 or not root
            or not handle or not handle:IsA("BasePart") then return end
        if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart")
            or not hitPart:IsDescendantOf(workspace) then return end
        local zombie, victim, host = GoreService.GetZombie(hitPart)
        -- Bindable callbacks may run after the weapon's lethal TakeDamage.
        if not zombie or not victim or not host then return end
        local position = host.Position
        if typeof(hitPosition) == "Vector3" and hitPosition.X == hitPosition.X
            and hitPosition.Y == hitPosition.Y and hitPosition.Z == hitPosition.Z
            and (hitPosition - host.Position).Magnitude <= host.Size.Magnitude + 3 then
            position = hitPosition
        end
        if tool.Name == "Machete" then
            if (host.Position - root.Position).Magnitude > 12 then return end
        elseif tool.Name == "Pistol" then
            if (host.Position - root.Position).Magnitude > 5000 then return end
            local direction = position - handle.Position
            if direction.Magnitude < 0.01 then return end
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { character }
            local ray = workspace:Raycast(handle.Position, direction.Unit * (direction.Magnitude + 3), params)
            if not ray then return end
            local rayZombie, _, rayHost = GoreService.GetZombie(ray.Instance)
            if rayZombie ~= zombie or rayHost ~= host then return end
        else
            return
        end
        local applied, reason = GoreService.ApplyGore(zombie, host, position)
        if not applied then warn("[ZombieGoreHandler] " .. tostring(reason)) end
    end)
end

local function watchTool(tool)
    if not tool:IsA("Tool") or watchedTools[tool] then return end
    watchedTools[tool] = true
    tool.DescendantAdded:Connect(function(child) connectVisualEvent(tool, child) end)
    for _, child in ipairs(tool:GetDescendants()) do
        connectVisualEvent(tool, child)
    end
end

local function watchContainer(container)
    for _, child in ipairs(container:GetChildren()) do watchTool(child) end
    container.ChildAdded:Connect(watchTool)
end

local function watchPlayer(player)
    player.CharacterAdded:Connect(watchContainer)
    if player.Character then watchContainer(player.Character) end
    task.spawn(function()
        local backpack = player:WaitForChild("Backpack")
        watchContainer(backpack)
    end)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end

local setup = setmetatable({}, { __mode = "k" })
local function setupZombie(character)
    if not character:IsA("Model") or setup[character] then return end
    setup[character] = true
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
    if not humanoid or not humanoid:IsA("Humanoid") or not character.Parent then
        setup[character] = nil
        return
    end
    character:SetAttribute("GoreReady", true)
    humanoid.BreakJointsOnDeath = false
    humanoid.Died:Once(function()
        GoreService.OnZombieDied(character)
    end)
end
for _, tag in ipairs({ "Zombie", "zombie" }) do
    for _, zombie in ipairs(CollectionService:GetTagged(tag)) do task.spawn(setupZombie, zombie) end
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(zombie)
        task.spawn(setupZombie, zombie)
    end)
end

-- Generic remote is opt-in. Weapon scripts should call RegisterHit after server validation.
local lastHit = {}
weaponHit.OnServerEvent:Connect(function(player, requestedPart, hitPosition)
    local character = player.Character
    local shooter = character and character:FindFirstChildOfClass("Humanoid")
    local tool = character and character:FindFirstChildOfClass("Tool")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not shooter or shooter.Health <= 0 or not tool or not root
        or tool:GetAttribute("GoreRemoteEnabled") ~= true then return end
    if typeof(requestedPart) ~= "Instance" or not requestedPart:IsA("BasePart")
        or not requestedPart:IsDescendantOf(workspace) or typeof(hitPosition) ~= "Vector3"
        or hitPosition.X ~= hitPosition.X or hitPosition.Y ~= hitPosition.Y or hitPosition.Z ~= hitPosition.Z then return end
    local damage = tool:GetAttribute("Damage")
    local cooldown = tool:GetAttribute("FireRate")
    if typeof(damage) ~= "number" or damage ~= damage or damage <= 0 or damage > 500
        or typeof(cooldown) ~= "number" or cooldown ~= cooldown or cooldown < 0.05 then return end
    local now = os.clock()
    if now - (lastHit[player] or -math.huge) < cooldown then return end
    local originPart = tool:FindFirstChild("Handle")
    local origin = originPart and originPart:IsA("BasePart") and originPart.Position or root.Position
    local direction = hitPosition - origin
    if direction.Magnitude < 0.01 or direction.Magnitude > 500 then return end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    local ray = workspace:Raycast(origin, direction.Unit * (direction.Magnitude + 2), params)
    if not ray or ray.Instance ~= requestedPart or (ray.Position - hitPosition).Magnitude > 6 then return end
    local victim, humanoid, bodyPart = GoreService.ResolveHit(ray.Instance)
    if not victim or not humanoid or humanoid.Health <= 0 or victim == character then return end
    local victimPlayer = Players:GetPlayerFromCharacter(victim)
    if victimPlayer and not player.Neutral and not victimPlayer.Neutral
        and victimPlayer.TeamColor == player.TeamColor then return end
    lastHit[player] = now
    GoreService.RegisterHit({
        Attacker = player, Character = victim, Humanoid = humanoid, BodyPart = bodyPart,
        Damage = damage, Position = ray.Position, Normal = ray.Normal,
    })
end)
Players.PlayerRemoving:Connect(function(player) lastHit[player] = nil end)
