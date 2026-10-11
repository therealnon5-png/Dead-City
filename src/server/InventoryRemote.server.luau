-- Created at runtime; no RemoteEvent needs to be inserted manually in Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:FindFirstChild("InventoryToggle")
if remote then
    assert(remote:IsA("RemoteEvent"), "ReplicatedStorage.InventoryToggle must be a RemoteEvent")
else
    remote = Instance.new("RemoteEvent")
    remote.Name = "InventoryToggle"
    remote.Parent = ReplicatedStorage
end

remote.OnServerEvent:Connect(function(player, enabled, revision)
    if typeof(enabled) ~= "boolean" or typeof(revision) ~= "number"
        or revision ~= revision or revision < 1 or revision > 9007199254740991
        or revision % 1 ~= 0 then return end
    -- UI only. A player can change only their own inventory visibility.
    -- This event does not grant items or equip anything.
    remote:FireClient(player, enabled, revision)
end)
