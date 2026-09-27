-- Server-side game logic starts here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

print(Config.GameName .. " server started")
