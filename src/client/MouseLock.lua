-- Keeps the mouse locked to the screen center while the local player is in a match.
-- Tries the PlayerModule shift lock first, falls back to MouseBehavior LockCenter.
-- Only one of the two is ever used. Released in menus, on Escape and when dead.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local MouseLock = {}

type Mode = "Unknown" | "Shift" | "Center"

local mode: Mode = "Unknown"
local controller: any = nil
local shiftRequested = false
local escapeReleased = false
local locked = false
local started = false
local menuClosedAt = -math.huge
local ESCAPE_CLOSE_WINDOW = 0.3

local function getController(): any
	local ok, result = pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if not module then
			return nil
		end
		local playerModule = (require :: any)(module)
		local cameras = playerModule:GetCameras()
		return cameras and cameras.activeMouseLockController
	end)
	if ok and result and type(result.SetIsMouseLocked) == "function" then
		return result
	end
	return nil
end

local function resolveMode()
	if mode ~= "Unknown" then
		return
	end
	controller = getController()
	mode = if controller then "Shift" else "Center"
end

-- Called only on transitions (lock / release), never every frame, so the player's
-- own shift toggle and the PlayerModule are not overridden continuously.
local function setShift(on: boolean): boolean
	if not controller then
		controller = getController()
	end
	if not controller then
		return false
	end
	local ok = pcall(function()
		controller:SetIsMouseLocked(on)
	end)
	if ok then
		shiftRequested = on
	end
	return ok
end

local function setBehavior(target: Enum.MouseBehavior)
	pcall(function()
		if UserInputService.MouseBehavior ~= target then
			UserInputService.MouseBehavior = target
		end
	end)
end

local function setIcon(visible: boolean)
	pcall(function()
		if UserInputService.MouseIconEnabled ~= visible then
			UserInputService.MouseIconEnabled = visible
		end
	end)
end

local function characterAlive(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function shouldLock(): boolean
	if escapeReleased or not UserInputService.MouseEnabled then
		return false
	end
	if player:GetAttribute("InGame") ~= true or player:GetAttribute("MenuOpen") == true then
		return false
	end
	if GuiService.MenuIsOpen then
		return false
	end
	return characterAlive()
end

local function release()
	if mode == "Shift" and shiftRequested then
		setShift(false)
	end
	setBehavior(Enum.MouseBehavior.Default)
	setIcon(true)
	locked = false
end

local function lock()
	resolveMode()
	if mode == "Shift" and not locked then
		if not setShift(true) then
			-- the shift lock controller went away: switch to the fallback for good
			mode = "Center"
			controller = nil
			shiftRequested = false
		end
	end
	if mode == "Center" then
		setBehavior(Enum.MouseBehavior.LockCenter)
	end
	setIcon(false)
	locked = true
end

local function step()
	if shouldLock() then
		lock()
	elseif locked then
		release()
	end
end

function MouseLock.IsLocked(): boolean
	return locked
end

function MouseLock.Init()
	if started then
		return
	end
	started = true

	pcall(function()
		(player :: any).DevEnableMouseLock = true
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape then
			-- an Escape that just closed a menu must not keep the lock off
			if os.clock() - menuClosedAt > ESCAPE_CLOSE_WINDOW then
				escapeReleased = true
			end
			release()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			escapeReleased = false
		end
	end)

	pcall(function()
		GuiService.MenuOpened:Connect(function()
			escapeReleased = true
			release()
		end)
		GuiService.MenuClosed:Connect(function()
			escapeReleased = false
			menuClosedAt = os.clock()
		end)
	end)

	player:GetAttributeChangedSignal("MenuOpen"):Connect(function()
		if player:GetAttribute("MenuOpen") == true then
			release()
		else
			escapeReleased = false
			menuClosedAt = os.clock()
		end
	end)
	player:GetAttributeChangedSignal("InGame"):Connect(function()
		if player:GetAttribute("InGame") ~= true then
			release()
		end
	end)
	player.CharacterAdded:Connect(function()
		escapeReleased = false
	end)

	RunService.RenderStepped:Connect(step)
end

return MouseLock
