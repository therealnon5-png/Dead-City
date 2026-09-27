local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle")
local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = Workspace.CurrentCamera
local Character = Workspace:WaitForChild(Player.Name)
local Humanoid = Character:WaitForChild("Humanoid")
--local TEAM = Character:WaitForChild("TEAM")
local VisualizeBullet = script.Parent:WaitForChild("VisualizeBullet")
local Module = require(Tool:WaitForChild("Setting"))
local GunScript_Server = Tool:WaitForChild("GunScript_Server")
local ChangeAmmoAndClip = GunScript_Server:WaitForChild("ChangeAmmoAndClip")
local InflictTarget = GunScript_Server:WaitForChild("InflictTarget")
local AmmoValue = GunScript_Server:WaitForChild("Ammo")
local ClipsValue = GunScript_Server:WaitForChild("Clips")
local GUI = script:WaitForChild("GunGUI")
local IdleAnim
local FireAnim
local ReloadAnim
local ShotgunClipinAnim
local Grip2
local Handle2
local HandleToFire = Handle

if Module.DualEnabled then
	Handle2 = Tool:WaitForChild("Handle2",2)
	if Handle2 == nil and Module.DualEnabled then error("\"Dual\" setting is enabled but \"Handle2\" is missing!") end
end

local Equipped = false
local Enabled = true
local Down = false
local Reloading = false
local AimDown = false
local Ammo = AmmoValue.Value
local Clips = ClipsValue.Value
local MaxClip = Module.MaxClip
local PiercedHumanoid = {}

if Module.IdleAnimationID ~= nil or Module.DualEnabled then
	IdleAnim = Tool:WaitForChild("IdleAnim")
	IdleAnim = Humanoid:LoadAnimation(IdleAnim)
end
if Module.FireAnimationID ~= nil then
	FireAnim = Tool:WaitForChild("FireAnim")
	FireAnim = Humanoid:LoadAnimation(FireAnim)
end
if Module.ReloadAnimationID ~= nil then
	ReloadAnim = Tool:WaitForChild("ReloadAnim")
	ReloadAnim = Humanoid:LoadAnimation(ReloadAnim)
end
if Module.ShotgunClipinAnimationID ~= nil then
	ShotgunClipinAnim = Tool:WaitForChild("ShotgunClipinAnim")
	ShotgunClipinAnim = Humanoid:LoadAnimation(ShotgunClipinAnim)
end

function wait(TimeToWait)
	if TimeToWait ~= nil then
		local TotalTime = 0
		TotalTime = TotalTime + game:GetService("RunService").Heartbeat:wait()
		while TotalTime < TimeToWait do
			TotalTime = TotalTime + game:GetService("RunService").Heartbeat:wait()
		end
	else
		game:GetService("RunService").Heartbeat:wait()
	end
end

function RayCast(Start,Direction,Range,Ignore)
	local Hit,EndPos = game.Workspace:FindPartOnRay(Ray.new(Start,Direction*Range),Ignore)
	if Hit then
		if ((Hit.Transparency > 0.75 and not Hit:GetAttribute("GoreHitbox"))
			or not Hit.CanQuery
			or Hit:GetAttribute("GoreHost") ~= nil -- Aim at the original R6 hitbox under the cosmetic Gore.
			or Hit.Name == "Handle"
			or Hit.Name == "Effect"
			or Hit.Name == "Bullet"
			or Hit.Name == "Laser"
			or string.lower(Hit.Name) == "water"
			or Hit.Name == "Rail"
			or Hit.Name == "Arrow"
			or (Hit.Parent:FindFirstChild("Humanoid") and Hit.Parent.Humanoid.Health == 0)
			or (Hit.Parent:FindFirstChild("Humanoid") and Hit.Parent:FindFirstChild("TEAM") and TEAM and Hit.Parent.TEAM.Value == TEAM.Value))
			or (Hit.Parent:FindFirstChild("Humanoid") and PiercedHumanoid[Hit.Parent.Humanoid]) then
			Hit,EndPos = RayCast(EndPos+(Direction*.01),Direction,Range-((Start-EndPos).magnitude),Ignore)
		end
	end
	return Hit,EndPos
end

function ShakeCamera()
	if Module.CameraShakingEnabled then
		local Intensity = Module.Intensity/(AimDown and Module.MouseSensitive or 1)
		for i = 1, 10 do
			local cam_rot = Camera.CoordinateFrame - Camera.CoordinateFrame.p
			local cam_scroll = (Camera.CoordinateFrame.p - Camera.Focus.p).magnitude
			local ncf = CFrame.new(Camera.Focus.p)*cam_rot*CFrame.fromEulerAnglesXYZ((-Intensity+(math.random()*(Intensity*2)))/100, (-Intensity+(math.random()*(Intensity*2)))/100, 0)
			Camera.CoordinateFrame = ncf*CFrame.new(0, 0, cam_scroll)
			wait()
		end
	end
end

function Fire(ShootingHandle)
	local PierceAvailable = Module.Piercing
	PiercedHumanoid = {}
	if FireAnim then FireAnim:Play(nil,nil,Module.FireAnimationSpeed) end
	if not ShootingHandle.FireSound.Playing or not ShootingHandle.FireSound.Looped then ShootingHandle.FireSound:Play() script.Parent.Model.casing:FireServer() end
	local Start = (Humanoid.Torso.CFrame * CFrame.new(0,1.5,0)).p--(Handle.CFrame * CFrame.new(Module.MuzzleOffset.X,Module.MuzzleOffset.Y,Module.MuzzleOffset.Z)).p
	local Spread = Module.Spread*(AimDown and 1-Module.SpreadRedution or 1)
	local Direction = (CFrame.new(Start,Mouse.Hit.p) * CFrame.Angles(math.rad(-Spread+(math.random()*(Spread*2))),math.rad(-Spread+(math.random()*(Spread*2))),0)).lookVector
	while PierceAvailable >= 0 do
		local Hit,EndPos = RayCast(Start,Direction,5000,Character)
		if not Module.ExplosiveEnabled then
			if Hit and Hit.Parent then
				local TargetHumanoid = Hit.Parent:FindFirstChild("Humanoid")
				local TargetTorso = Hit.Parent:FindFirstChild("HumanoidRootPart")
				--local TargetTEAM = Hit.Parent:FindFirstChild("TEAM")
				if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
					--if TargetTEAM and TargetTEAM.Value ~= TEAM.Value then
						InflictTarget:FireServer(TargetHumanoid,
												TargetTorso,
												(Hit.Name == "Head" and Module.HeadshotEnabled) and Module.BaseDamage * Module.HeadshotDamageMultiplier or Module.BaseDamage,
												Direction,
												Module.Knockback,
												Module.Lifesteal,
												Module.FlamingBullet, Hit, EndPos)
						PiercedHumanoid[TargetHumanoid] = true
					--end
				else
					PierceAvailable = 0
				end
			end
		else
			local Explosion = Instance.new("Explosion")
			Explosion.BlastRadius = Module.Radius
			Explosion.BlastPressure = 0
			Explosion.Position = EndPos
			Explosion.Parent = Workspace.CurrentCamera
			Explosion.Hit:connect(function(Hit)
				if Hit and Hit.Parent and Hit.Name == "Torso" then
					local TargetHumanoid = Hit.Parent:FindFirstChild("Humanoid")
					local TargetTorso = Hit.Parent:FindFirstChild("Torso")
					--local TargetTEAM = Hit.Parent:FindFirstChild("TEAM")
					if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
						--if TargetTEAM and TargetTEAM.Value ~= TEAM.Value then
							InflictTarget:FireServer(TargetHumanoid,
													TargetTorso,
													(Hit.Name == "Head" and Module.HeadshotEnabled) and Module.BaseDamage * Module.HeadshotDamageMultiplier or Module.BaseDamage,
													Direction,
													Module.Knockback,
													Module.Lifesteal,
													Module.FlamingBullet, Hit, EndPos)
						--end
					end
				end
			end)
			PierceAvailable = 0
		end
		PierceAvailable = Hit and (PierceAvailable - 1) or -1
		script.Parent.BulletVisualizerScript.Visualize:Fire(nil,ShootingHandle,
																	Module.MuzzleOffset,
																	EndPos,
																	script.MuzzleEffect,
																	script.HitEffect,
																	Module.HitSoundIDs[math.random(1,#Module.HitSoundIDs)],
																	{Module.ExplosiveEnabled,Module.BlastRadius,Module.BlastPressure},
																	{Module.BulletSpeed,Module.BulletSize,Module.BulletColor,Module.BulletTransparency,Module.BulletMaterial,Module.FadeTime},
																	false,
																	PierceAvailable == -1 and Module.VisualizerEnabled or false)
		script.Parent.VisualizeBullet:FireServer(ShootingHandle,
														Module.MuzzleOffset,
														EndPos,
														script.MuzzleEffect,
														script.HitEffect,
														Module.HitSoundIDs[math.random(1,#Module.HitSoundIDs)],
														{Module.ExplosiveEnabled,Module.BlastRadius,Module.BlastPressure},
														{Module.BulletSpeed,Module.BulletSize,Module.BulletColor,Module.BulletTransparency,Module.BulletMaterial,Module.FadeTime},
														true,
														PierceAvailable == -1 and Module.VisualizerEnabled or false)
		Start = EndPos + (Direction*0.01)
	end
end

function Reload()
	if Enabled and not Reloading and (Clips > 0 or not Module.LimitedClipEnabled) and Ammo < Module.AmmoPerClip then
		Reloading = true
		if AimDown then
			Workspace.CurrentCamera.FieldOfView = 70
			--[[local GUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild("ZoomGui")
			if GUI then GUI:Destroy() end]]
			GUI.Scope.Visible = false
			game.Players.LocalPlayer.CameraMode = Enum.CameraMode.Classic
			script["Mouse Sensitivity"].Disabled = true
			AimDown = false
			Mouse.Icon = "rbxassetid://"..Module.MouseIconID
		end
		UpdateGUI()
		if Module.ShotgunReload then
			for i = 1,(Module.AmmoPerClip - Ammo) do
				if ShotgunClipinAnim then ShotgunClipinAnim:Play(nil,nil,Module.ShotgunClipinAnimationSpeed) end
				Handle.ShotgunClipin:Play()
				wait(Module.ShellClipinSpeed)
			end
		end
		if ReloadAnim then ReloadAnim:Play(nil,nil,Module.ReloadAnimationSpeed) end
		Handle.ReloadSound:Play() script.Parent.Model.reload:FireServer()
		wait(Module.ReloadTime)
		if Module.LimitedClipEnabled then Clips = Clips - 1 end
		Ammo = Module.AmmoPerClip
		ChangeAmmoAndClip:FireServer(Ammo,Clips)
		Reloading = false
		UpdateGUI()
	end
end

function UpdateGUI()
	GUI.Frame.Ammo.Fill:TweenSizeAndPosition(UDim2.new(Ammo/Module.AmmoPerClip,0,1,0), UDim2.new(0,0,0,0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.25, true)
	GUI.Frame.Clips.Fill:TweenSizeAndPosition(UDim2.new(Clips/Module.MaxClip,0,1,0), UDim2.new(0,0,0,0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.25, true)
	GUI.Frame.Ammo.Current.Text = Ammo
	GUI.Frame.Ammo.Max.Text = Module.AmmoPerClip
	GUI.Frame.Clips.Current.Text = Clips
	GUI.Frame.Clips.Max.Text = Module.MaxClip

	GUI.Frame.Ammo.Current.Visible = not Reloading
	GUI.Frame.Ammo.Max.Visible = not Reloading
	GUI.Frame.Ammo.Frame.Visible = not Reloading
	GUI.Frame.Ammo.Reloading.Visible = Reloading

	GUI.Frame.Clips.Current.Visible = not (Clips <= 0)
	GUI.Frame.Clips.Max.Visible = not (Clips <= 0)
	GUI.Frame.Clips.Frame.Visible = not (Clips <= 0)
	GUI.Frame.Clips.NoMoreClip.Visible = (Clips <= 0)
	
	GUI.Frame.Clips.Visible = Module.LimitedClipEnabled
	GUI.Frame.Size = Module.LimitedClipEnabled and UDim2.new(0,250,0,100) or UDim2.new(0,250,0,55)
	GUI.Frame.Position = Module.LimitedClipEnabled and UDim2.new(1,-260,1,-110)or UDim2.new(1,-260,1,-65)
end

Mouse.Button1Down:connect(function()
	Down = true
	local IsChargedShot = false
	if Equipped and Enabled and Down and not Reloading and Ammo > 0 and Humanoid.Health > 0 then
		Enabled = false
		if Module.ChargedShotEnabled then
			if HandleToFire:FindFirstChild("ChargeSound") then HandleToFire.ChargeSound:Play() end
			wait(Module.ChargingTime)
			IsChargedShot = true
		end
		if Module.MinigunEnabled then
			if HandleToFire:FindFirstChild("WindUp") then HandleToFire.WindUp:Play() end
			wait(Module.DelayBeforeFiring)
		end
		while Equipped and not Reloading and (Down or IsChargedShot) and Ammo > 0 and Humanoid.Health > 0 do
			IsChargedShot = false
			for i = 1,(Module.BurstFireEnabled and Module.BulletPerBurst or 1) do
				Spawn(ShakeCamera)
				for x = 1,(Module.ShotgunEnabled and Module.BulletPerShot or 1) do
					Fire(HandleToFire)
				end
				Ammo = Ammo - 1
				ChangeAmmoAndClip:FireServer(Ammo,Clips)
				UpdateGUI()
				if Module.BurstFireEnabled then wait(Module.BurstRate) end
				if Ammo <= 0 then break end
			end
			HandleToFire = (HandleToFire == Handle and Module.DualEnabled) and Handle2 or Handle
			wait(Module.FireRate)
			if not Module.Auto then break end
		end
		if HandleToFire.FireSound.Playing and HandleToFire.FireSound.Looped then HandleToFire.FireSound:Stop() end
		if Module.MinigunEnabled then
			if HandleToFire:FindFirstChild("WindDown") then HandleToFire.WindDown:Play() end
			wait(Module.DelayAfterFiring)
		end
		Enabled = true
		if Ammo <= 0 then Reload() end
	end
end)
Mouse.Button1Up:connect(function()
	Down = false
end)

ChangeAmmoAndClip.OnClientEvent:connect(function(ChangedAmmo,ChangedClips)
	Ammo = ChangedAmmo
	Clips = ChangedClips
	UpdateGUI()
end)
Tool.Equipped:connect(function(TempMouse)
	Equipped = true
	UpdateGUI()
	if Module.AmmoPerClip ~= math.huge then GUI.Parent = Player.PlayerGui end
	TempMouse.Icon = "rbxassetid://"..Module.MouseIconID
	if IdleAnim then IdleAnim:Play(nil,nil,Module.IdleAnimationSpeed) end
	TempMouse.KeyDown:connect(function(Key)
		if string.lower(Key) == "r" then
			Reload()
		elseif string.lower(Key) == "e" then
			if not Reloading and AimDown == false and Module.SniperEnabled then
				Workspace.CurrentCamera.FieldOfView = Module.FieldOfView
				--[[local GUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild("ZoomGui") or Tool.ZoomGui:Clone()
				GUI.Parent = game.Players.LocalPlayer.PlayerGui]]
				GUI.Scope.Visible = true
				game.Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
				script["Mouse Sensitivity"].Disabled = false
				AimDown = true
				Mouse.Icon="http://www.roblox.com/asset?id=187746799"
			else
				Workspace.CurrentCamera.FieldOfView = 70
				--[[local GUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild("ZoomGui")
				if GUI then GUI:Destroy() end]]
				GUI.Scope.Visible = false
				game.Players.LocalPlayer.CameraMode = Enum.CameraMode.Classic
				script["Mouse Sensitivity"].Disabled = true
				AimDown = false
				Mouse.Icon = "rbxassetid://"..Module.MouseIconID
			end
		end
	end)
	if Module.DualEnabled and not Workspace.FilteringEnabled then
		Handle2.CanCollide = false
		local LeftArm = Tool.Parent:FindFirstChild("Left Arm")
		local RightArm = Tool.Parent:FindFirstChild("Right Arm")
		if RightArm then
			local Grip = RightArm:WaitForChild("RightGrip",0.01)
			if Grip then
				Grip2 = Grip:Clone()
				Grip2.Name = "LeftGrip"
				Grip2.Part0 = LeftArm
				Grip2.Part1 = Handle2
				--Grip2.C1 = Grip2.C1:inverse()
				Grip2.Parent = LeftArm
			end
		end
	end
end)
Tool.Unequipped:connect(function()
	Equipped = false
	GUI.Parent = script
	if IdleAnim then IdleAnim:Stop() end
		if AimDown then
			Workspace.CurrentCamera.FieldOfView = 70
			--[[local GUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild("ZoomGui")
			if GUI then GUI:Destroy() end]]
			GUI.Scope.Visible = false
			game.Players.LocalPlayer.CameraMode = Enum.CameraMode.Classic
			script["Mouse Sensitivity"].Disabled = true
			AimDown = false
			Mouse.Icon = "rbxassetid://"..Module.MouseIconID
		end
	if Module.DualEnabled and not Workspace.FilteringEnabled then
		Handle2.CanCollide = true
		if Grip2 then Grip2:Destroy() end
	end
end)
Humanoid.Died:connect(function()
	Equipped = false
	GUI.Parent = script
	if IdleAnim then IdleAnim:Stop() end
		if AimDown then
			Workspace.CurrentCamera.FieldOfView = 70
			--[[local GUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild("ZoomGui")
			if GUI then GUI:Destroy() end]]
			GUI.Scope.Visible = false
			game.Players.LocalPlayer.CameraMode = Enum.CameraMode.Classic
			script["Mouse Sensitivity"].Disabled = true
			AimDown = false
			Mouse.Icon = "rbxassetid://"..Module.MouseIconID
		end
	if Module.DualEnabled and not Workspace.FilteringEnabled then
		Handle2.CanCollide = true
		if Grip2 then Grip2:Destroy() end
	end
end)
