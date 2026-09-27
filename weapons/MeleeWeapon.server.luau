--Rescripted by TakeoHonorable
local Tool = script.Parent
Tool.Enabled = true
local Handle = Tool:WaitForChild("Handle")
local Sounds = { Hit = Handle:WaitForChild("Hit"), Swing = Handle:WaitForChild("Swing") }
local Animations = {}
local Services = {
    Players = game:GetService("Players"),
    Debris = game:GetService("Debris"),
}
local events = {}
local Player, Character, Humanoid

-- Keep the event inside this Script's sandbox. The server handler owns GoreService.
local GoreVisualHit = script:FindFirstChild("GoreVisualHit")
if not GoreVisualHit then
    GoreVisualHit = Instance.new("BindableEvent")
    GoreVisualHit.Name = "GoreVisualHit"
    GoreVisualHit.Parent = script
end
local goreWarning
local function ApplyGoreVisual(hit)
    local ok, reason = pcall(function()
        GoreVisualHit:Fire(hit, hit.Position)
    end)
    if not ok and reason ~= goreWarning then
        goreWarning = reason
        warn("[Machete Gore] " .. tostring(reason))
    end
end

function IsTeamMate(Player1, Player2)
    return Player1 and Player2 and not Player1.Neutral and not Player2.Neutral
        and Player1.TeamColor == Player2.TeamColor
end
function TagHumanoid(humanoid, player)
    local Creator_Tag = Instance.new("ObjectValue")
    Creator_Tag.Name = "creator"
    Creator_Tag.Value = player
    Services.Debris:AddItem(Creator_Tag, 2)
    Creator_Tag.Parent = humanoid
end
function UntagHumanoid(humanoid)
    for _, v in pairs(humanoid:GetChildren()) do
        if v:IsA("ObjectValue") and v.Name == "creator" then v:Destroy() end
    end
end
function IsInTable(Table, Value)
    for _, v in pairs(Table) do
        if v == Value then return true end
    end
    return false
end

local HitHumanoids = {}
function Activated()
    if not Tool.Enabled or not Humanoid or Humanoid.Health <= 0 then return end
    Tool.Enabled = false
    delay(0.8, function()
        HitHumanoids = {}
        Tool.Enabled = true
    end)
    Animations.ChopAnim:Play()
    Sounds.Swing:Play()
end
function Touched(hit)
    if not hit or not hit.Parent or Tool.Enabled or Tool.Parent ~= Character then return end
    local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
    local ff = hit.Parent:FindFirstChildOfClass("ForceField")
    if not hum or hum == Humanoid or hum.Health <= 0 or ff
        or IsTeamMate(Services.Players:GetPlayerFromCharacter(hum.Parent), Player)
        or IsInTable(HitHumanoids, hum) then return end
    HitHumanoids[#HitHumanoids + 1] = hum
    UntagHumanoid(hum)
    TagHumanoid(hum, Player)
    ApplyGoreVisual(hit)
    hum:TakeDamage(20)
    Sounds.Hit:Play()
    if not string.find(string.lower(hit.Name), "root")
        and ((string.find(string.lower(hit.Name), "torso") or string.find(string.lower(hit.Name), "head"))
        and Random.new():NextNumber(0, 100) <= 50)
        or (not string.find(string.lower(hit.Name), "torso")
        and not string.find(string.lower(hit.Name), "head") and not string.find(string.lower(hit.Name), "root")) then
        hit.Anchored = false
    end
end
function Equipped()
    Character = Tool.Parent
    Player = Services.Players:GetPlayerFromCharacter(Character)
    Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid or Humanoid.Health <= 0 then return end
    Animations = {
        ChopAnim = Humanoid:LoadAnimation(Tool:WaitForChild("Chop" .. Humanoid.RigType.Name))
    }
    events[#events + 1] = Tool.Activated:Connect(Activated)
    events[#events + 1] = Handle.Touched:Connect(Touched)
end
function Unequipped()
    for _, event in ipairs(events) do event:Disconnect() end
    events = {}
    if Animations.ChopAnim then
        Animations.ChopAnim:Stop()
        Animations.ChopAnim:Destroy()
        Animations.ChopAnim = nil
    end
end
Tool.Equipped:Connect(Equipped)
-- The supplied script defined this cleanup but never connected it.
Tool.Unequipped:Connect(Unequipped)
