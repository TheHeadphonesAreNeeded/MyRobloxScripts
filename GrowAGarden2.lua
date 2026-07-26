
task.spawn(function()
local ok0, err0 = pcall(function()

local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local RunSvc  = game:GetService("RunService")
local lp      = Players.LocalPlayer

local Networking  = require(RS.SharedModules.Networking)
local StockValues = RS.StockValues

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name             = "🌻 Grow a Garden 2",
    LoadingTitle     = "Garden Tools",
    LoadingSubtitle  = "by Claude",
    ConfigurationSaving = { Enabled = true, FolderName = "GardenUI", FileName = "Config" },
    KeySystem        = false,
})

-- ============================================================
-- TAB 1 — PLAYER
-- ============================================================
local PlayerTab = Window:CreateTab("Player", 4483362458)

local currentSpeed = 16
local currentJump  = 50
local infJump      = false
local noclipOn     = false
local flyOn        = false
local flySpeed     = 60
local flyConn      = nil
local bGyro, bVel

local function getHum()
    local c = lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- Movement ────────────────────────────────────────────────
PlayerTab:CreateSection("Movement")

PlayerTab:CreateSlider({
    Name = "Walk Speed", Range = {16, 250}, Increment = 1,
    Suffix = " stud/s", CurrentValue = 16, Flag = "WalkSpeed",
    Callback = function(v)
        currentSpeed = v
        local h = getHum(); if h then h.WalkSpeed = v end
    end,
})

PlayerTab:CreateSlider({
    Name = "Jump Power", Range = {50, 500}, Increment = 5,
    Suffix = " power", CurrentValue = 50, Flag = "JumpPower",
    Callback = function(v)
        currentJump = v
        local h = getHum(); if h then h.JumpPower = v end
    end,
})

PlayerTab:CreateToggle({
    Name = "Infinite Jump", CurrentValue = false, Flag = "InfJump",
    Callback = function(v) infJump = v end,
})

UIS.JumpRequest:Connect(function()
    if infJump then
        local h = getHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

lp.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local h = char:WaitForChild("Humanoid", 5)
    if not h then return end
    h.WalkSpeed = currentSpeed
    h.JumpPower  = currentJump
    if flyOn then task.wait(0.2); startFly() end
end)

-- Flight ──────────────────────────────────────────────────
PlayerTab:CreateSection("Flight")

function startFly()
    local char = lp.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    hum.PlatformStand = true

    bGyro = Instance.new("BodyGyro")
    bGyro.P          = 9e4
    bGyro.MaxTorque  = Vector3.new(9e9, 9e9, 9e9)
    bGyro.CFrame     = root.CFrame
    bGyro.Parent     = root

    bVel = Instance.new("BodyVelocity")
    bVel.MaxForce    = Vector3.new(9e9, 9e9, 9e9)
    bVel.P           = 9e4
    bVel.Velocity    = Vector3.zero
    bVel.Parent      = root

    flyConn = RunSvc.Heartbeat:Connect(function()
        if not flyOn or not root or not root.Parent then
            pcall(function() bGyro:Destroy() end)
            pcall(function() bVel:Destroy() end)
            pcall(function() hum.PlatformStand = false end)
            if flyConn then flyConn:Disconnect(); flyConn = nil end
            return
        end
        local cam = workspace.CurrentCamera
        local d   = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then d += cam.CFrame.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d -= cam.CFrame.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then
            d += Vector3.new(0, 1, 0)
        end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.Q) then
            d -= Vector3.new(0, 1, 0)
        end
        bVel.Velocity = d.Magnitude > 0 and d.Unit * flySpeed or Vector3.zero
        bGyro.CFrame  = cam.CFrame
    end)
end

PlayerTab:CreateToggle({
    Name = "Fly  (WASD · E up · Q down)", CurrentValue = false, Flag = "Fly",
    Callback = function(v)
        flyOn = v; if v then startFly() end
    end,
})

PlayerTab:CreateSlider({
    Name = "Fly Speed", Range = {10, 400}, Increment = 5,
    Suffix = " stud/s", CurrentValue = 60, Flag = "FlySpeed",
    Callback = function(v) flySpeed = v end,
})

-- Misc ────────────────────────────────────────────────────
PlayerTab:CreateSection("Misc")

PlayerTab:CreateToggle({
    Name = "Noclip", CurrentValue = false, Flag = "Noclip",
    Callback = function(v) noclipOn = v end,
})

RunSvc.Stepped:Connect(function()
    if noclipOn and lp.Character then
        for _, p in lp.Character:GetDescendants() do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

PlayerTab:CreateButton({
    Name = "Reset Character",
    Callback = function()
        local h = getHum(); if h then h.Health = 0 end
    end,
})

-- ============================================================
-- TAB 2 — AUTO BUY
-- ============================================================
local AutoBuyTab = Window:CreateTab("Auto Buy", 4483362458)

local buySeeds  = {}
local buyCrates = {}
local buyGear   = {}
local interval  = 0.5
local masterOn  = false

local function getStock(shop, name)
    local f = StockValues:FindFirstChild(shop); if not f then return 0 end
    local i = f:FindFirstChild("Items");         if not i then return 0 end
    local v = i:FindFirstChild(name);            return v and v.Value or 0
end

-- Master Control ──────────────────────────────────────────
AutoBuyTab:CreateSection("Master Control")

AutoBuyTab:CreateToggle({
    Name = "Enable Auto Buy", CurrentValue = false, Flag = "MasterBuy",
    Callback = function(v) masterOn = v end,
})

AutoBuyTab:CreateSlider({
    Name = "Buy Interval", Range = {0.1, 5}, Increment = 0.1,
    Suffix = "s", CurrentValue = 0.5, Flag = "BuyInterval",
    Callback = function(v) interval = v end,
})

-- Shops ───────────────────────────────────────────────────
AutoBuyTab:CreateSection("Shops")

-- 🌱 Seed Shop
AutoBuyTab:CreateDropdown({
    Name            = "🌱 Seed Shop",
    Options         = {
        -- Common
        "Carrot", "Maple Carrot", "Strawberry", "Maple Strawberry",
        "Blueberry", "Maple Blueberry",
        -- Uncommon
        "Tulip", "Maple Tulip", "Tomato", "Maple Tomato",
        "Apple", "Maple Apple",
        -- Rare
        "Bamboo", "Maple Bamboo", "Corn", "Maple Corn",
        "Cactus", "Maple Cactus", "Pineapple", "Maple Pineapple",
        -- Epic
        "Mushroom", "Maple Mushroom", "Green Bean", "Maple Green Bean",
        "Banana", "Grape", "Coconut", "Mango",
        -- Legendary
        "Rocket Pop", "Dragon Fruit", "Acorn", "Cherry", "Sunflower", "Fire Fern",
        -- Mythic
        "Venus Fly Trap", "Maple Venus Fly Trap", "Pomegranate", "Maple Pomegranate",
        "Poison Apple", "Maple Poison Apple", "Venom Spitter", "Maple Venom Spitter",
        -- Super
        "Moon Bloom", "Sun Bloom", "Hypno Bloom", "Dragon's Breath", "Star Fruit",
        -- Secret / Event
        "Briar Rose", "Ghost Pepper", "Poison Ivy", "Baby Cactus", "Glow Mushroom",
        "Romanesco", "Horned Melon", "Eclipse Bloom", "Plum", "Cinnamon Stick",
        "Conifer Cone", "Conifer Cone Sapling", "Amber Cranberry", "Atlantic Giant Pumpkin",
        -- Endgame
        "Gold", "Rainbow", "Mega",
    },
    CurrentOption   = {},
    MultipleOptions = true,
    Flag            = "SeedDropdown",
    Callback        = function(selected)
        table.clear(buySeeds)
        for _, name in ipairs(selected) do buySeeds[name] = true end
    end,
})

-- 📦 Crate Shop
AutoBuyTab:CreateDropdown({
    Name            = "📦 Crate Shop",
    Options         = {
        "Light Crate", "Arch Crate", "Bench Crate", "Bridge Crate", "Seesaw Crate",
        "Sign Crate", "Teleporter Pad Crate", "Ladder Crate", "Fence Crate",
        "Owner Door Crate", "Conveyor Crate", "Spring Crate", "Roleplay Crate",
        "Bear Trap Crate", "Picture Frame Crate", "Boombox Crate",
        "Fourth Of July Crate", "Rake Crate", "Cobblestone Crate",
        "Fall Cosmetic Crate", "Fall Structure Crate", "Lantern Crate",
        "Common Guild Crate", "Uncommon Guild Crate", "Rare Guild Crate",
        "Epic Guild Crate", "Legendary Guild Crate", "Mythic Guild Crate",
        "Super Guild Crate",
    },
    CurrentOption   = {},
    MultipleOptions = true,
    Flag            = "CrateDropdown",
    Callback        = function(selected)
        table.clear(buyCrates)
        for _, name in ipairs(selected) do buyCrates[name] = true end
    end,
})

-- ⚙️ Gear Shop
AutoBuyTab:CreateDropdown({
    Name            = "⚙️ Gear Shop",
    Options         = {
        "Common Watering Can", "Common Sprinkler", "Sign", "Megaphone", "Harp",
        "Wheelbarrow", "Uncommon Sprinkler", "Rare Sprinkler", "Legendary Sprinkler",
        "Super Watering Can", "Super Sprinkler", "Wind Staff", "Strawberry Sniper",
        "Trowel", "Speed Mushroom", "Jump Mushroom", "Gnome", "Shrink Mushroom",
        "Supersize Mushroom", "Invisibility Mushroom", "Teleporter",
        "Legendary Pet Teleporter", "Mythic Pet Teleporter", "Super Pet Teleporter",
        "Basic Pot", "Flashbang", "Bull Horn", "Player Magnet",
    },
    CurrentOption   = {},
    MultipleOptions = true,
    Flag            = "GearDropdown",
    Callback        = function(selected)
        table.clear(buyGear)
        for _, name in ipairs(selected) do buyGear[name] = true end
    end,
})

-- Buy loop ────────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(interval)
        if not masterOn then continue end

        for name in pairs(buySeeds) do
            if getStock("SeedShop", name) > 0 then
                pcall(function() Networking.SeedShop.PurchaseSeed:Fire(name) end)
                task.wait(0.08)
            end
        end
        for name in pairs(buyCrates) do
            if getStock("CrateShop", name) > 0 then
                pcall(function() Networking.CrateShop.PurchaseCrate:Fire(name) end)
                task.wait(0.08)
            end
        end
        for name in pairs(buyGear) do
            if getStock("GearShop", name) > 0 then
                pcall(function() Networking.GearShop.PurchaseGear:Fire(name) end)
                task.wait(0.08)
            end
        end
    end
end)

Rayfield:LoadConfiguration()

end)
if not ok0 then warn("[GardenUI] FATAL: " .. tostring(err0)) end
end)
