-- Replace Source in zombie_npc > ZombieScript. This folder is not Rojo-synced.
local Players = game:GetService("Players")
local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local hrpOfNPC = npc:WaitForChild("HumanoidRootPart")
humanoid.BreakJointsOnDeath = false -- Preserve joints until the central Gore handler ragdolls them.

local maxDistance = math.huge
local nextHit = setmetatable({}, { __mode = "k" })
local alive = true
local connections = {}
local function stop()
    if not alive then return end
    alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    table.clear(nextHit)
end

table.insert(connections, humanoid.Touched:Connect(function(touch)
    if not alive or humanoid.Health <= 0 or not touch or not touch.Parent then return end
    local character = touch:FindFirstAncestorOfClass("Model")
    local player = character and Players:GetPlayerFromCharacter(character)
    local target = character and character:FindFirstChildOfClass("Humanoid")
    if not player or not target or target.Health <= 0 then return end
    local now = os.clock()
    if now < (nextHit[player] or 0) then return end
    nextHit[player] = now + 1
    target:TakeDamage(20)
end))
table.insert(connections, humanoid.Died:Connect(stop))
table.insert(connections, npc.Destroying:Connect(stop))

while alive and npc.Parent and humanoid.Health > 0 do
    local closestHRP
    local closestDistance = maxDistance
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local target = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if target and root and target.Health > 0 then
            local distance = (hrpOfNPC.Position - root.Position).Magnitude
            if distance < closestDistance then
                closestDistance, closestHRP = distance, root
            end
        end
    end
    if closestHRP then humanoid:MoveTo(closestHRP.Position) end
    task.wait(0.1)
end
stop()
