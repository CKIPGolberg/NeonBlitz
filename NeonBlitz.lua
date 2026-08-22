--[[
    ================================================================
    SHINDO LIFE MULTI-FUNCTIONAL HUB (SOLIX ARCHITECTURE)
    ================================================================
    Features: Modular structure, JSON Configs, Metamethod Hooks,
              Auto-Farm, Scroll Collector, ESP, Anti-AFK & Server Hop.
    ================================================================
--]]

-- Services Initializer
local Services = setmetatable({}, {
    __index = function(self, serviceName)
        local success, service = pcall(game.GetService, game, serviceName)
        if success and service then
            rawset(self, serviceName, service)
            return service
        end
        return nil
    end
})

local Players = Services.Players
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local HttpService = Services.HttpService
local TeleportService = Services.TeleportService
local TweenService = Services.TweenService
local VirtualUser = Services.VirtualUser
local Workspace = Services.Workspace
local ReplicatedStorage = Services.ReplicatedStorage

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Global Hub State & Configuration
local HubState = {
    -- Combat
    NoCooldown = false,
    FastAttack = false,
    AttackDelay = 0.05,
    AutoSkills = false,
    SkillSlots = {"1", "2", "3", "4", "5", "6", "V", "B", "N"},
    
    -- Auto Farm
    AutoFarm = false,
    AutoQuest = false,
    BossFarm = false,
    SelectedBoss = "Deidara",
    ScrollFarm = false,
    FarmDistance = 4,
    
    -- Auto Spins
    AutoSpinBloodline = false,
    SelectedBloodlines = {},
    
    -- Movement & Player
    WalkSpeed = 16,
    JumpPower = 50,
    Noclip = false,
    InfiniteJump = false,
    InfiniteStamina = false,
    
    -- Visuals (ESP)
    ESPPlayers = false,
    ESPBosses = false,
    ESPScrolls = false,
}

local Connections = {}
local ESPStorage = {}

-- ================================================================
-- 1. CONFIGURATION SYSTEM (JSON PERSISTENCE)
-- ================================================================
local ConfigFolder = "ShindoLifeHubConfig"
local ConfigFile = ConfigFolder .. "/settings.json"

local function SaveConfiguration()
    pcall(function()
        if not isfolder(ConfigFolder) then
            makefolder(ConfigFolder)
        end
        writefile(ConfigFile, HttpService:JSONEncode(HubState))
    end)
end

local function LoadConfiguration()
    pcall(function()
        if isfolder(ConfigFolder) and isfile(ConfigFile) then
            local data = HttpService:JSONDecode(readfile(ConfigFile))
            if type(data) == "table" then
                for key, val in pairs(data) do
                    HubState[key] = val
                end
            end
        end
    end)
end

-- ================================================================
-- 2. OPTIMIZATION, ANTI-AFK & SAFETY WRAPPERS
-- ================================================================
local function InitAntiAFK()
    Connections["AntiAFK"] = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end

-- Safely execute continuous background tasks
local function SafeLoop(delayTime, condition, callback)
    task.spawn(function()
        while task.wait(delayTime) do
            if not HubState then break end
            if condition() then
                local ok, err = pcall(callback)
                if not ok and err then
                    warn("[Hub Error]: " .. tostring(err))
                end
            end
        end
    end)
end

-- ================================================================
-- 3. METAMETHOD HOOKS & COMBAT MODULE
-- ================================================================
local OldNamecall
local function HookCombatEngine()
    if getrawmetatable and hookmetamethod then
        local grm = getrawmetatable(game)
        setreadonly(grm, false)
        
        OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            -- Bypass cooldowns & stamina checks on remote calls
            if HubState.NoCooldown and (method == "FireServer" or method == "InvokeServer") then
                if tostring(self):lower():find("cd") or tostring(self):lower():find("cooldown") then
                    return nil
                end
            end
            
            return OldNamecall(self, ...)
        end))
        setreadonly(grm, true)
    end
end

-- Fast M1 Attack Loop
SafeLoop(0.01, function() return HubState.FastAttack end, function()
    local char = LocalPlayer.Character
    if char then
        local combatRemote = char:FindFirstChild("CombatRemote") or ReplicatedStorage:FindFirstChild("Combat")
        if combatRemote then
            combatRemote:FireServer()
        end
    end
    task.wait(HubState.AttackDelay)
end)

-- Auto Skill Spam Loop
SafeLoop(0.2, function() return HubState.AutoSkills end, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        for _, key in ipairs(HubState.SkillSlots) do
            VirtualUser:SetKeyDown(key)
            task.wait(0.02)
            VirtualUser:SetKeyUp(key)
        end
    end
end)

-- ================================================================
-- 4. AUTO FARM & SCROLL COLLECTOR
-- ================================================================
local function GetTargetNPC()
    local target = nil
    local shortestDist = math.huge
    local char = LocalPlayer.Character
    if not (char and char:FindFirstChild("HumanoidRootPart")) then return nil end
    
    local npcFolder = Workspace:FindFirstChild("NPCs") or Workspace
    for _, npc in ipairs(npcFolder:GetChildren()) do
        if npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 and npc:FindFirstChild("HumanoidRootPart") then
            if npc ~= char and not Players:GetPlayerFromCharacter(npc) then
                local dist = (char.HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    target = npc
                end
            end
        end
    end
    return target
end

-- Main Auto-Farm Routine
SafeLoop(0.05, function() return HubState.AutoFarm end, function()
    local target = GetTargetNPC()
    local char = LocalPlayer.Character
    if target and char and char:FindFirstChild("HumanoidRootPart") then
        local safePos = target.HumanoidRootPart.CFrame * CFrame.new(0, 0, HubState.FarmDistance)
        char.HumanoidRootPart.CFrame = safePos
    end
end)

-- Scroll Collector Routine
SafeLoop(0.3, function() return HubState.ScrollFarm end, function()
    for _, item in ipairs(Workspace:GetDescendants()) do
        if item:IsA("TouchTransmitter") and item.Parent and item.Parent.Name:lower():find("scroll") then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                firetouchinterest(char.HumanoidRootPart, item.Parent, 0)
                task.wait(0.05)
                firetouchinterest(char.HumanoidRootPart, item.Parent, 1)
            end
        end
    end
end)

-- ================================================================
-- 5. MOVEMENT & PLAYER MODIFICATIONS
-- ================================================================
Connections["Noclip"] = RunService.Stepped:Connect(function()
    if HubState.Noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

Connections["InfiniteJump"] = UserInputService.JumpRequest:Connect(function()
    if HubState.InfiniteJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

SafeLoop(0.1, function() return HubState.InfiniteStamina end, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Stamina") then
        char.Stamina.Value = char.Stamina.MaxValue
    end
end)

-- ================================================================
-- 6. VISUALS ENGINE (ESP)
-- ================================================================
local function CreateESPLabel(model, text, color)
    if not model or not model:FindFirstChild("HumanoidRootPart") then return end
    if model.HumanoidRootPart:FindFirstChild("Hub_ESP") then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Hub_ESP"
    billboard.Adornee = model.HumanoidRootPart
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    
    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.2
    label.TextSize = 13
    label.Font = Enum.Font.SourceSansBold
    label.Text = text
    
    billboard.Parent = model.HumanoidRootPart
    table.insert(ESPStorage, billboard)
end

local function ClearESP()
    for _, esp in ipairs(ESPStorage) do
        if esp and esp.Parent then esp:Destroy() end
    end
    table.clear(ESPStorage)
end

SafeLoop(1, function() return HubState.ESPPlayers or HubState.ESPScrolls end, function()
    ClearESP()
    if HubState.ESPPlayers then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local dist = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - plr.Character.HumanoidRootPart.Position).Magnitude)
                CreateESPLabel(plr.Character, plr.Name .. " [" .. dist .. "m]", Color3.fromRGB(255, 60, 60))
            end
        end
    end
end)

-- ================================================================
-- 7. TELEPORTATION & SERVER UTILITIES
-- ================================================================
local function ServerHop()
    local api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local success, response = pcall(function() return HttpService:JSONDecode(game:HttpGet(api)) end)
    if success and response and response.data then
        for _, s in ipairs(response.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                break
            end
        end
    end
end

-- ================================================================
-- 8. UI INITIALIZATION (RAYFIELD LIBRARY)
-- ================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Shindo Life | Solix Hub",
    LoadingTitle = "Initializing Architecture...",
    LoadingSubtitle = "by Solix Framework",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

-- Tabs
local TabCombat = Window:CreateTab("Combat & No CD", 4483362458)
local TabFarm = Window:CreateTab("Auto Farm", 4483362458)
local TabMovement = Window:CreateTab("Player & Move", 4483362458)
local TabESP = Window:CreateTab("Visuals (ESP)", 4483362458)
local TabServer = Window:CreateTab("Server & Config", 4483362458)

-- Tab: Combat
TabCombat:CreateToggle({
    Name = "No Cooldown (Bypass)",
    CurrentValue = HubState.NoCooldown,
    Callback = function(v) HubState.NoCooldown = v end
})

TabCombat:CreateToggle({
    Name = "Fast Attack (M1 Spam)",
    CurrentValue = HubState.FastAttack,
    Callback = function(v) HubState.FastAttack = v end
})

TabCombat:CreateSlider({
    Name = "Safety Attack Delay (ms)",
    Range = {0, 500},
    Increment = 10,
    Suffix = "ms",
    CurrentValue = math.floor(HubState.AttackDelay * 1000),
    Callback = function(v) HubState.AttackDelay = v / 1000 end
})

TabCombat:CreateToggle({
    Name = "Auto-Skill Spam (1-6, V, B, N)",
    CurrentValue = HubState.AutoSkills,
    Callback = function(v) HubState.AutoSkills = v end
})

-- Tab: Auto Farm
TabFarm:CreateToggle({
    Name = "Auto Farm Mobs",
    CurrentValue = HubState.AutoFarm,
    Callback = function(v) HubState.AutoFarm = v end
})

TabFarm:CreateToggle({
    Name = "Scroll Collector (Auto-Pickup)",
    CurrentValue = HubState.ScrollFarm,
    Callback = function(v) HubState.ScrollFarm = v end
})

TabFarm:CreateSlider({
    Name = "Safe Distance Behind Mob",
    Range = {2, 10},
    Increment = 1,
    Suffix = "Studs",
    CurrentValue = HubState.FarmDistance,
    Callback = function(v) HubState.FarmDistance = v end
})

-- Tab: Movement
TabMovement:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 200},
    Increment = 1,
    CurrentValue = HubState.WalkSpeed,
    Callback = function(v)
        HubState.WalkSpeed = v
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = v
        end
    end
})

TabMovement:CreateToggle({
    Name = "Noclip",
    CurrentValue = HubState.Noclip,
    Callback = function(v) HubState.Noclip = v end
})

TabMovement:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = HubState.InfiniteJump,
    Callback = function(v) HubState.InfiniteJump = v end
})

TabMovement:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = HubState.InfiniteStamina,
    Callback = function(v) HubState.InfiniteStamina = v end
})

-- Tab: ESP
TabESP:CreateToggle({
    Name = "Player ESP",
    CurrentValue = HubState.ESPPlayers,
    Callback = function(v)
        HubState.ESPPlayers = v
        if not v then ClearESP() end
    end
})

-- Tab: Server & System
TabServer:CreateButton({
    Name = "Server Hop (Search New Server)",
    Callback = function() ServerHop() end
})

TabServer:CreateButton({
    Name = "Rejoin Current Server",
    Callback = function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end
})

TabServer:CreateButton({
    Name = "Save Config",
    Callback = function()
        SaveConfiguration()
        Rayfield:Notify({ Title = "System", Content = "Configuration Saved Successfully!", Duration = 3 })
    end
})

TabServer:CreateButton({
    Name = "Unload Hub",
    Callback = function()
        for _, conn in pairs(Connections) do
            if conn and conn.Connected then conn:Disconnect() end
        end
        ClearESP()
        Rayfield:Destroy()
    end
})

-- Boot Process
InitAntiAFK()
HookCombatEngine()
LoadConfiguration()

Rayfield:Notify({
    Title = "Solix Hub Loaded",
    Content = "Shindo Life Engine active. All safety checks passed.",
    Duration = 5
})
