-- =========================================================================
-- Waypoint Tween Pathing GUI
-- =========================================================================

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local waypoints = {}
local isRunning = false

-- =========================================================================
-- GUI CREATION
-- =========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "WaypointFarmerGUI"
ScreenGui.ResetOnSpawn = false

-- Safely mount GUI (supports both Studio and Executors)
local success, coreGui = pcall(function() return game:GetService("CoreGui") end)
ScreenGui.Parent = (success and coreGui) and coreGui or LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 250, 0, 310)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -155)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true -- Allows you to drag the menu around

local UIListLayout = Instance.new("UIListLayout", MainFrame)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local UIPadding = Instance.new("UIPadding", MainFrame)
UIPadding.PaddingTop = UDim.new(0, 10)

-- Title
local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, -20, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "Waypoint Controller"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16

-- Tween Speed Input
local SpeedInput = Instance.new("TextBox", MainFrame)
SpeedInput.Size = UDim2.new(1, -20, 0, 30)
SpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedInput.Font = Enum.Font.Gotham
SpeedInput.PlaceholderText = "Speed (Studs/Sec) [Default: 50]"
SpeedInput.Text = "50"
SpeedInput.TextSize = 14

-- Sleep Input
local SleepInput = Instance.new("TextBox", MainFrame)
SleepInput.Size = UDim2.new(1, -20, 0, 30)
SleepInput.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
SleepInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SleepInput.Font = Enum.Font.Gotham
SleepInput.PlaceholderText = "Sleep (Seconds) [Default: 1]"
SleepInput.Text = "1"
SleepInput.TextSize = 14

-- Add WP Button
local AddWPBtn = Instance.new("TextButton", MainFrame)
AddWPBtn.Size = UDim2.new(1, -20, 0, 35)
AddWPBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
AddWPBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AddWPBtn.Font = Enum.Font.GothamBold
AddWPBtn.Text = "Add Waypoint Here"
AddWPBtn.TextSize = 14

-- Clear WP Button
local ClearWPBtn = Instance.new("TextButton", MainFrame)
ClearWPBtn.Size = UDim2.new(1, -20, 0, 35)
ClearWPBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ClearWPBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearWPBtn.Font = Enum.Font.GothamBold
ClearWPBtn.Text = "Clear All Waypoints"
ClearWPBtn.TextSize = 14

-- Status Label
local StatusLabel = Instance.new("TextLabel", MainFrame)
StatusLabel.Size = UDim2.new(1, -20, 0, 20)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Waypoints: 0"
StatusLabel.TextSize = 12

-- Start/Stop Button
local ToggleBtn = Instance.new("TextButton", MainFrame)
ToggleBtn.Size = UDim2.new(1, -20, 0, 45)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 210)
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.Text = "START"
ToggleBtn.TextSize = 18

-- =========================================================================
-- LOGIC & FUNCTIONS
-- =========================================================================

-- Function to handle the actual tweening
local function tweenTo(targetCFrame)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    local speed = tonumber(SpeedInput.Text) or 50
    
    -- Calculate distance to make speed consistent regardless of how far the WP is
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local duration = distance / speed
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    
    -- Optional: If you find yourself falling through the map while tweening, 
    -- uncomment the two lines below to freeze physics during the move.
    -- hrp.Anchored = true 
    tween:Play()
    tween.Completed:Wait()
    -- hrp.Anchored = false
end

-- Add Waypoint Event
AddWPBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        table.insert(waypoints, char.HumanoidRootPart.CFrame)
        StatusLabel.Text = "Waypoints: " .. #waypoints
    end
end)

-- Clear Waypoint Event
ClearWPBtn.MouseButton1Click:Connect(function()
    waypoints = {}
    StatusLabel.Text = "Waypoints: 0"
end)

-- Toggle Start/Stop Event
ToggleBtn.MouseButton1Click:Connect(function()
    if #waypoints == 0 then return end -- Don't start if no waypoints exist
    
    isRunning = not isRunning
    
    if isRunning then
        ToggleBtn.Text = "STOP"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        
        -- Run the loop on a separate thread so it doesn't freeze the game
        task.spawn(function()
            while isRunning do
                for i, wpCFrame in ipairs(waypoints) do
                    if not isRunning then break end
                    
                    -- 1. Tween to Waypoint
                    tweenTo(wpCFrame)
                    
                    if not isRunning then break end
                    
                    -- 2. Sleep phase
                    local sleepDuration = tonumber(SleepInput.Text) or 1
                    task.wait(sleepDuration)
                end
            end
            
            -- Reset button appearance when loop is manually stopped
            ToggleBtn.Text = "START"
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 210)
        end)
    else
        -- If clicked while running, this flips the boolean and stops the loop at the next check
        ToggleBtn.Text = "START"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 210)
    end
end)
