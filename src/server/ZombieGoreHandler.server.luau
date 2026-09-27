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
