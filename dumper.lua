-- =========================================================
-- Enhanced Roblox Variable & Game State Gatherer
-- Safe to run in LocalScript or via Executor
-- =========================================================

-- Hook print to capture output for the clipboard and GUI
local originalPrint = print
local outputBuffer = {}
local function print(...)
    local args = {...}
    local strParts = {}
    for _, v in ipairs(args) do
        table.insert(strParts, tostring(v))
    end
    local str = table.concat(strParts, " ")
    originalPrint(str)
    table.insert(outputBuffer, str)
end

-- Improved dumpTable with cyclic reference protection
local function dumpTable(tbl, indent, maxDepth, currentDepth, visited)
    indent = indent or ""
    maxDepth = maxDepth or 3
    currentDepth = currentDepth or 0
    visited = visited or {}
    
    if type(tbl) ~= "table" then return tostring(tbl) end
    if currentDepth > maxDepth then return "{... (Max Depth Reached)}" end
    if visited[tbl] then return "{... (Cyclic Reference)}" end
    
    visited[tbl] = true
    local str = "{\n"
    
    for k, v in pairs(tbl) do
        local key = type(k) == "string" and '"' .. k .. '"' or tostring(k)
        
        if type(v) == "table" then
            str = str .. indent .. "  [" .. key .. "] = " .. dumpTable(v, indent .. "  ", maxDepth, currentDepth + 1, visited) .. ",\n"
        elseif type(v) == "string" then
            str = str .. indent .. "  [" .. key .. '] = "' .. v .. '",\n'
        else
            str = str .. indent .. "  [" .. key .. "] = " .. tostring(v) .. ",\n"
        end
    end
    
    return str .. indent .. "}"
end

-- Safely get properties without throwing errors
local function safeGet(obj, prop)
    local success, result = pcall(function() return obj[prop] end)
    return success and result or "Locked/Nil"
end

print("\n========================================")
print("=== ROBLOX GAME STATE DUMPER STARTED ===")
print("========================================")
print("Game Name:", game.Name)
print("PlaceId:", game.PlaceId)
print("JobId:", game.JobId)
print("Players Count:", #game.Players:GetPlayers())
print("Current Time:", os.date("%Y-%m-%d %H:%M:%S"))

-- 1. Core Services
print("\n[1. Core Services]")
local servicesToFind = {"Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst", "ServerStorage", "StarterGui", "StarterPlayer", "Workspace", "SoundService", "Teams"}
for _, serviceName in ipairs(servicesToFind) do
    local success, service = pcall(function() return game:GetService(serviceName) end)
    if success and service then
        print("  [+] Found:", serviceName, "->", service.ClassName)
    else
        print("  [-] Not Accessible:", serviceName)
    end
end

-- 2. Player Info
local Players = game:GetService("Players")
local player = Players.LocalPlayer
if player then
    print("\n[2. LocalPlayer Info]")
    print("  Username:", player.Name)
    print("  UserId:", player.UserId)
    print("  AccountAge:", player.AccountAge, "days")
    
    local character = player.Character
    print("  Character:", character and character.Name or "nil")
    print("  Team:", player.Team and player.Team.Name or "No Team")
    
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        print("  Health:", humanoid and math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth) or "N/A")
        print("  WalkSpeed:", humanoid and humanoid.WalkSpeed or "N/A")
    end
    
    -- Check for leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        print("  Leaderstats:")
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat:IsA("ValueBase") then
                print("    > " .. stat.Name .. ": " .. tostring(stat.Value))
            end
        end
    end
end

-- 3. Workspace Items / Entities (With lag protection)
print("\n[3. Workspace Important Items]")
local workspaceCount = 0
local workspaceMaxPrints = 50 -- Prevent lag/crashing from huge games

for _, obj in ipairs(workspace:GetDescendants()) do
    if workspaceCount >= workspaceMaxPrints then
        print("  ... (Truncated to prevent lag. Found too many items)")
        break
    end
    
    -- Filter for common points of interest
    local name = obj.Name:lower()
    if obj:IsA("Model") or obj:IsA("Folder") then
        if name:find("door") or name:find("coin") or name:find("chest") or name:find("npc") or name:find("drop") then
            print("  [" .. obj.ClassName .. "] " .. obj:GetFullName())
            workspaceCount = workspaceCount + 1
        end
    end
    
    -- Prevent script execution timeout on massive games
    if workspaceCount % 500 == 0 then task.wait() end 
end

-- 4. ReplicatedStorage Important Stuff (Remotes, Modules)
print("\n[4. ReplicatedStorage - Remotes & Modules]")
local RS = game:GetService("ReplicatedStorage")
local rsCount = 0

for _, obj in ipairs(RS:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        print("  [NETWORK] " .. obj.ClassName .. " | " .. obj:GetFullName())
        rsCount = rsCount + 1
    elseif obj:IsA("ModuleScript") then
        print("  [MODULE]  " .. obj.ClassName .. " | " .. obj:GetFullName())
        rsCount = rsCount + 1
    end
end
if rsCount == 0 then print("  No Remotes or Modules found in ReplicatedStorage.") end

-- 5. Player UI (Look for hidden/disabled menus)
print("\n[5. PlayerGui - Interfaces]")
if player then
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local state = gui.Enabled and "Visible" or "Hidden"
                print("  [UI] " .. gui.Name .. " (" .. state .. ")")
            end
        end
    end
end

-- 6. Global Environment (_G / shared)
print("\n[6. Global Environment (_G & shared)]")
local _gSuccess, _gData = pcall(function() return dumpTable(_G, "  ", 2) end)
if _gSuccess and _gData ~= "{\n  }" then
    print("  _G Variables:\n" .. _gData)
else
    print("  _G is empty or protected.")
end

local sharedSuccess, sharedData = pcall(function() return dumpTable(shared, "  ", 2) end)
if sharedSuccess and sharedData ~= "{\n  }" then
    print("  shared Variables:\n" .. sharedData)
else
    print("  shared is empty or protected.")
end

print("\n======================================")
print("=== DUMP COMPLETE ====================")
print("======================================")

-- Compile final string
local finalString = table.concat(outputBuffer, "\n")

-- Clipboard Logic
if setclipboard then
    setclipboard(finalString)
elseif toclipboard then
    toclipboard(finalString)
end

-- ==========================================
-- GUI CREATION FOR IN-GAME VIEWING
-- ==========================================
local CoreGui = game:GetService("CoreGui")
-- Try to use CoreGui first to hide from game anti-cheats, fallback to PlayerGui
local successCore, _ = pcall(function() return CoreGui.Name end)
local targetParent = successCore and CoreGui or (player and player:WaitForChild("PlayerGui"))

if targetParent then
    -- Remove old GUI if it exists
    if targetParent:FindFirstChild("StateDumperGUI") then
        targetParent.StateDumperGUI:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StateDumperGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = targetParent
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 600, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true -- Allows moving the window around
    mainFrame.Parent = screenGui
    
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 30)
    topBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Roblox Game State Dumper"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "TerminateBtn"
    closeBtn.Size = UDim2.new(0, 40, 1, 0)
    closeBtn.Position = UDim2.new(1, -40, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = topBar
    
    -- Terminate GUI functionality
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -40)
    scrollFrame.Position = UDim2.new(0, 10, 0, 35)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.Parent = mainFrame
    
    local textOutput = Instance.new("TextLabel")
    textOutput.Size = UDim2.new(1, -10, 0, 0)
    textOutput.AutomaticSize = Enum.AutomaticSize.Y
    textOutput.BackgroundTransparency = 1
    textOutput.Text = finalString
    textOutput.TextColor3 = Color3.fromRGB(200, 200, 200)
    textOutput.Font = Enum.Font.Code
    textOutput.TextSize = 13
    textOutput.TextXAlignment = Enum.TextXAlignment.Left
    textOutput.TextYAlignment = Enum.TextYAlignment.Top
    textOutput.TextWrapped = true
    textOutput.Parent = scrollFrame
end
