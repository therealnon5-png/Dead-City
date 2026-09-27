-- Client-side controls, UI, and effects start here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

print(Config.GameName .. " client started")
