local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local waypoints = {}
local isRunning = false
local currentTween = nil

local TWEEN_SPEED = 100 -- Studs per second
local WAIT_TIME = 3 -- Seconds to sleep at each waypoint

-- ==========================================
-- 1. GUI CREATION
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local AddWpBtn = Instance.new("TextButton")
local StartBtn = Instance.new("TextButton")
local StopBtn = Instance.new("TextButton")
local ClearBtn = Instance.new("TextButton")
local StatusLabel = Instance.new("TextLabel")

-- Try to parent to CoreGui for executors, fallback to PlayerGui for Studio
local success, _ = pcall(function()
	ScreenGui.Parent = game:GetService("CoreGui")
end)
if not success then
	ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

ScreenGui.Name = "WaypointGUI"
ScreenGui.ResetOnSpawn = false

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -125)
MainFrame.Size = UDim2.new(0, 200, 0, 250)
MainFrame.Active = true
MainFrame.Draggable = true -- Allows the user to drag the UI around

Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.GothamBold
Title.Text = "Waypoint Looper"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14

StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0, 0, 0, 35)
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Waypoints: 0"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextSize = 14

local function createButton(name, text, posY)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Parent = MainFrame
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	btn.Position = UDim2.new(0.1, 0, 0, posY)
	btn.Size = UDim2.new(0.8, 0, 0, 35)
	btn.Font = Enum.Font.GothamBold
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 14
	return btn
end

AddWpBtn = createButton("AddWpBtn", "Add WP (Current Pos)", 60)
StartBtn = createButton("StartBtn", "Start Loop", 105)
StopBtn = createButton("StopBtn", "Stop Loop", 150)
ClearBtn = createButton("ClearBtn", "Clear Waypoints", 195)

-- ==========================================
-- 2. LOGIC & FUNCTIONS
-- ==========================================

-- Function to safely Tween the character
local function tweenTo(targetCFrame)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	
	local hrp = character.HumanoidRootPart
	
	-- Calculate time based on distance so the speed remains consistent
	local distance = (hrp.Position - targetCFrame.Position).Magnitude
	local tweenTime = distance / TWEEN_SPEED
	
	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)
	currentTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
	
	-- Anchor the root part so gravity doesn't mess up the tween
	hrp.Anchored = true
	currentTween:Play()
	currentTween.Completed:Wait()
	hrp.Anchored = false
end

-- Add Waypoint Button
AddWpBtn.MouseButton1Click:Connect(function()
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		table.insert(waypoints, character.HumanoidRootPart.CFrame)
		StatusLabel.Text = "Waypoints: " .. #waypoints
	end
end)

-- Start Loop Button
StartBtn.MouseButton1Click:Connect(function()
	if isRunning then return end
	if #waypoints == 0 then 
		StatusLabel.Text = "Add a WP first!"
		task.wait(2)
		StatusLabel.Text = "Waypoints: " .. #waypoints
		return 
	end
	
	isRunning = true
	StatusLabel.Text = "Status: RUNNING"
	StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	
	task.spawn(function()
		while isRunning do
			for i, wpCFrame in ipairs(waypoints) do
				if not isRunning then break end
				
				-- 1. Tween to Waypoint
				tweenTo(wpCFrame)
				
				if not isRunning then break end
				
				-- 2. Sleep for 5 seconds
				task.wait(WAIT_TIME)
			end
		end
	end)
end)

-- Stop Loop Button
StopBtn.MouseButton1Click:Connect(function()
	isRunning = false
	if currentTween then
		currentTween:Cancel()
		
		-- Ensure character is unanchored if stopped mid-tween
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			char.HumanoidRootPart.Anchored = false
		end
	end
	
	StatusLabel.Text = "Status: STOPPED"
	StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	task.wait(1.5)
	StatusLabel.Text = "Waypoints: " .. #waypoints
	StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
end)

-- Clear Waypoints Button
ClearBtn.MouseButton1Click:Connect(function()
	if isRunning then return end -- Don't clear while running
	waypoints = {}
	StatusLabel.Text = "Waypoints: 0"
end)
