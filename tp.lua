local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ==========================================
-- 1. GUI CREATION
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WaypointGUI"
screenGui.ResetOnSpawn = false -- Keeps the GUI when you reset
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 250)
frame.Position = UDim2.new(0, 20, 0.5, -125)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.Parent = frame
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center

-- Helper function to create buttons
local function createButton(text, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 160, 0, 40)
	btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.Text = text
	btn.LayoutOrder = order
	btn.Parent = frame
	return btn
end

local btnWp1 = createButton("Set WP 1", 1)
local btnWp2 = createButton("Set WP 2", 2)
local btnWp3 = createButton("Set WP 3", 3)

local btnStart = createButton("Start", 4)
btnStart.BackgroundColor3 = Color3.fromRGB(40, 150, 40) -- Green for start

-- ==========================================
-- 2. LOGIC & LOOP
-- ==========================================
local waypoints = {nil, nil, nil}
local isRunning = false
local tweenSpeed = 50 -- Studs per second (adjust to make movement faster/slower)

-- Function to save the player's current position as a waypoint
local function setWaypoint(index, button)
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		waypoints[index] = char.HumanoidRootPart.CFrame
		button.Text = "WP " .. index .. " (Set!)"
		button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	end
end

btnWp1.MouseButton1Click:Connect(function() setWaypoint(1, btnWp1) end)
btnWp2.MouseButton1Click:Connect(function() setWaypoint(2, btnWp2) end)
btnWp3.MouseButton1Click:Connect(function() setWaypoint(3, btnWp3) end)

-- Function to handle the actual tweening
local function tweenTo(targetCFrame)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Calculate time based on distance so the character moves at a consistent speed
	local distance = (hrp.Position - targetCFrame.Position).Magnitude
	local tweenTime = math.max(distance / tweenSpeed, 0.1)

	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
	
	hrp.Anchored = true -- Anchoring prevents physics glitches while moving
	tween:Play()
	tween.Completed:Wait() -- Wait until the tween finishes
	hrp.Anchored = false
end

-- Function to handle a custom interruptible wait
local function interruptibleWait(seconds)
	local waitStart = os.clock()
	while os.clock() - waitStart < seconds do
		if not isRunning then break end
		task.wait(0.1)
	end
end

-- Start/Stop Button Logic
btnStart.MouseButton1Click:Connect(function()
	-- If already running, stop it
	if isRunning then
		isRunning = false
		btnStart.Text = "Start"
		btnStart.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
		return
	end

	-- Make sure all waypoints exist before starting
	if not waypoints[1] or not waypoints[2] or not waypoints[3] then
		btnStart.Text = "Missing WPs!"
		task.wait(1)
		btnStart.Text = "Start"
		return
	end

	isRunning = true
	btnStart.Text = "Stop"
	btnStart.BackgroundColor3 = Color3.fromRGB(150, 40, 40) -- Red for stop

	-- Run the loop in a separate thread so it doesn't freeze the game
	task.spawn(function()
		while isRunning do
			-- WP 1
			if not isRunning then break end
			tweenTo(waypoints[1])
			interruptibleWait(5)

			-- WP 2
			if not isRunning then break end
			tweenTo(waypoints[2])
			interruptibleWait(5)

			-- WP 3
			if not isRunning then break end
			tweenTo(waypoints[3])
			interruptibleWait(5)
		end
	end)
end)
