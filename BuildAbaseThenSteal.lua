--[[
    ╔══════════════════════════════════════════╗
    ║         FARM GUI v2 — Build a Base       ║
    ║         6 Features | Live Stats          ║
    ╚══════════════════════════════════════════╝

    FEATURES:
    💰 Auto Collect    — Grabs pad cash every 12s
    🎣 Auto Fish       — Perfect cast + instant reel (max luck)
    🥚 Auto Roll Pet   — Fires egg pad every 10s
    📦 Auto Roll Block — Fires crate pad every 10s
    ⬆️ Auto Upgrade Pet— Levels up equipped pet every 5s
    💸 Auto Sell Stored— Clears stored pets every 15s
]]

-- Destroy any existing FarmGUI
local existing = game.Players.LocalPlayer.PlayerGui:FindFirstChild("FarmGUI")
if existing then existing:Destroy() end

local Players      = game.Players
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local player       = Players.LocalPlayer
local playerGui    = player.PlayerGui

-- Require the game's own Network module (uses anti-cheat rotating key)
local Network = require(game.ReplicatedStorage.Modules.Network)

-- =========================================
-- HELPERS
-- =========================================
local function getPD(key)
    local pd = player:FindFirstChild("PlayerData")
    if pd then
        local v = pd:FindFirstChild(key, true)
        if v and v:IsA("ValueBase") then return v.Value end
    end
    return nil
end

local function fmtNum(n)
    if type(n) ~= "number" then n = 0 end
    if     n >= 1e12 then return string.format("$%.2fT", n / 1e12)
    elseif n >= 1e9  then return string.format("$%.2fB", n / 1e9)
    elseif n >= 1e6  then return string.format("$%.2fM", n / 1e6)
    elseif n >= 1e3  then return string.format("$%.1fK", n / 1e3)
    else                   return "$" .. math.floor(n) end
end

local function myPlot()
    local n = player:GetAttribute("Plot")
    return n and game.Workspace.Plots:FindFirstChild(tostring(n))
end

local function collectInfo()
    local plot = myPlot()
    local col  = plot and plot:FindFirstChild("CollectModel")
    if not col then return "$0", "$0/s" end
    local info = col:FindFirstChild("Info", true)
    local ml   = info and info:FindFirstChild("Label", true)
    local ms   = info and info:FindFirstChild("MPS",   true)
    return (ml and ml.Text or "$0"), (ms and ms.Text or "$0/s")
end

-- =========================================
-- BUILD GUI
-- =========================================
local WIN_W, WIN_H = 304, 468

local gui = Instance.new("ScreenGui")
gui.Name           = "FarmGUI"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

local win = Instance.new("Frame")
win.Name              = "Win"
win.Size              = UDim2.new(0, WIN_W, 0, WIN_H)
win.Position          = UDim2.new(0, -WIN_W - 10, 0.5, -WIN_H / 2)
win.BackgroundColor3  = Color3.fromRGB(9, 11, 18)
win.BorderSizePixel   = 0
win.Parent            = gui
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 14)
local ws = Instance.new("UIStroke", win)
ws.Color        = Color3.fromRGB(35, 200, 110)
ws.Thickness    = 1.4
ws.Transparency = 0.45

-- ── TITLE BAR ──────────────────────────────────────────────────────
local tb = Instance.new("Frame", win)
tb.Size             = UDim2.new(1, 0, 0, 48)
tb.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
tb.BorderSizePixel  = 0
tb.ZIndex           = 2
Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 14)
local tbFix = Instance.new("Frame", tb)
tbFix.Size             = UDim2.new(1, 0, 0, 14)
tbFix.Position         = UDim2.new(0, 0, 1, -14)
tbFix.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
tbFix.BorderSizePixel  = 0
tbFix.ZIndex           = 2

local function mklbl(parent, txt, sz, font, col, xalign, z)
    local l = Instance.new("TextLabel", parent)
    l.Text               = txt
    l.BackgroundTransparency = 1
    l.TextSize           = sz
    l.Font               = font   or Enum.Font.Gotham
    l.TextColor3         = col    or Color3.fromRGB(220, 220, 220)
    l.TextXAlignment     = xalign or Enum.TextXAlignment.Left
    l.ZIndex             = z      or 3
    return l
end

local titleLbl = mklbl(tb, "🌾  FARM GUI  v2", 15, Enum.Font.GothamBold,
    Color3.fromRGB(45, 235, 130), Enum.TextXAlignment.Left, 3)
titleLbl.Size     = UDim2.new(1, -50, 1, 0)
titleLbl.Position = UDim2.new(0, 14, 0, 0)

local closeBtn = Instance.new("TextButton", tb)
closeBtn.Text             = "✕"
closeBtn.Size             = UDim2.new(0, 28, 0, 28)
closeBtn.Position         = UDim2.new(1, -38, 0.5, -14)
closeBtn.BackgroundColor3 = Color3.fromRGB(170, 45, 45)
closeBtn.TextColor3       = Color3.new(1, 1, 1)
closeBtn.TextSize         = 12
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.BorderSizePixel  = 0
closeBtn.ZIndex           = 3
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 7)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- ── STATS PANEL ────────────────────────────────────────────────────
local statsPanel = Instance.new("Frame", win)
statsPanel.Size             = UDim2.new(1, -20, 0, 60)
statsPanel.Position         = UDim2.new(0, 10, 0, 56)
statsPanel.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
statsPanel.BorderSizePixel  = 0
statsPanel.ZIndex           = 2
Instance.new("UICorner", statsPanel).CornerRadius = UDim.new(0, 10)

local statCfgs = {
    { k = "money",       lbl = "BALANCE",  icon = "💰", col = Color3.fromRGB(255, 200, 50)  },
    { k = "uncollected", lbl = "WAITING",  icon = "💵", col = Color3.fromRGB(50,  220, 110) },
    { k = "mps",         lbl = "PER SEC",  icon = "⚡", col = Color3.fromRGB(100, 160, 255) },
    { k = "rebirths",    lbl = "REBIRTHS", icon = "🔄", col = Color3.fromRGB(200, 100, 255) },
}
local statVals = {}
for i, cfg in ipairs(statCfgs) do
    local w    = 1 / #statCfgs
    local cell = Instance.new("Frame", statsPanel)
    cell.Size                = UDim2.new(w, -3, 1, -2)
    cell.Position            = UDim2.new((i - 1) * w, 2, 0, 1)
    cell.BackgroundTransparency = 1
    cell.ZIndex              = 3

    local ic = mklbl(cell, cfg.icon, 14, nil, cfg.col, Enum.TextXAlignment.Center, 4)
    ic.Size     = UDim2.new(1, 0, 0, 22)
    ic.Position = UDim2.new(0, 0, 0, 3)

    local vl = mklbl(cell, "—", 11, Enum.Font.GothamBold,
        Color3.fromRGB(215, 255, 215), Enum.TextXAlignment.Center, 4)
    vl.Size     = UDim2.new(1, -4, 0, 16)
    vl.Position = UDim2.new(0, 2, 0, 23)

    local sl = mklbl(cell, cfg.lbl, 8, nil,
        Color3.fromRGB(90, 115, 135), Enum.TextXAlignment.Center, 4)
    sl.Size     = UDim2.new(1, -4, 0, 12)
    sl.Position = UDim2.new(0, 2, 0, 40)

    statVals[cfg.k] = vl
end

-- ── PET / ROD STRIP ────────────────────────────────────────────────
local petStrip = Instance.new("Frame", win)
petStrip.Size             = UDim2.new(1, -20, 0, 32)
petStrip.Position         = UDim2.new(0, 10, 0, 124)
petStrip.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
petStrip.BorderSizePixel  = 0
petStrip.ZIndex           = 2
Instance.new("UICorner", petStrip).CornerRadius = UDim.new(0, 8)

local petLbl = mklbl(petStrip, "🐾  Pet: —", 10, nil,
    Color3.fromRGB(200, 180, 255), Enum.TextXAlignment.Left, 3)
petLbl.Size     = UDim2.new(0.5, -8, 1, 0)
petLbl.Position = UDim2.new(0, 10, 0, 0)

local rodLbl = mklbl(petStrip, "🎣  Rod: —", 10, nil,
    Color3.fromRGB(180, 210, 255), Enum.TextXAlignment.Left, 3)
rodLbl.Size     = UDim2.new(0.5, -8, 1, 0)
rodLbl.Position = UDim2.new(0.5, 4, 0, 0)

-- ── SEPARATOR ──────────────────────────────────────────────────────
local sep = Instance.new("Frame", win)
sep.Size             = UDim2.new(1, -30, 0, 1)
sep.Position         = UDim2.new(0, 15, 0, 163)
sep.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
sep.BorderSizePixel  = 0
sep.ZIndex           = 2

-- ── FEATURE TOGGLES ────────────────────────────────────────────────
local featureDefs = {
    { id = "collect", label = "Auto Collect",     icon = "💰", desc = "Every 12s — grabs pad cash",    col = Color3.fromRGB(50,  210, 100) },
    { id = "rod",     label = "Auto Fish",         icon = "🎣", desc = "Perfect cast + instant reel",  col = Color3.fromRGB(80,  150, 255) },
    { id = "pet",     label = "Auto Roll Pet",     icon = "🥚", desc = "Fires egg pad every 10s",      col = Color3.fromRGB(220, 100, 255) },
    { id = "block",   label = "Auto Roll Block",   icon = "📦", desc = "Fires crate pad every 10s",    col = Color3.fromRGB(255, 160, 50)  },
    { id = "upgrade", label = "Auto Upgrade Pet",  icon = "⬆️", desc = "Spends cash on equipped pet",  col = Color3.fromRGB(255, 80,  150) },
    { id = "sell",    label = "Auto Sell Stored",  icon = "💸", desc = "Clears pet storage every 15s", col = Color3.fromRGB(170, 210, 50)  },
}

local states  = {}
local buttons = {}
for _, f in ipairs(featureDefs) do states[f.id] = false end

local TOGGLE_Y_START = 170
for i, f in ipairs(featureDefs) do
    local card = Instance.new("Frame", win)
    card.Size             = UDim2.new(1, -20, 0, 44)
    card.Position         = UDim2.new(0, 10, 0, TOGGLE_Y_START + (i - 1) * 47)
    card.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
    card.BorderSizePixel  = 0
    card.ZIndex           = 2
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local bar = Instance.new("Frame", card)
    bar.Size             = UDim2.new(0, 3, 0.6, 0)
    bar.Position         = UDim2.new(0, 0, 0.2, 0)
    bar.BackgroundColor3 = f.col
    bar.BorderSizePixel  = 0
    bar.ZIndex           = 3
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

    local ic = mklbl(card, f.icon, 17, nil, Color3.new(1, 1, 1), Enum.TextXAlignment.Center, 3)
    ic.Size     = UDim2.new(0, 32, 1, 0)
    ic.Position = UDim2.new(0, 8, 0, 0)

    local nl = mklbl(card, f.label, 12, Enum.Font.GothamBold,
        Color3.fromRGB(215, 240, 215), Enum.TextXAlignment.Left, 3)
    nl.Size     = UDim2.new(1, -110, 0, 20)
    nl.Position = UDim2.new(0, 44, 0, 5)

    local dl = mklbl(card, f.desc, 9, nil,
        Color3.fromRGB(90, 115, 135), Enum.TextXAlignment.Left, 3)
    dl.Size     = UDim2.new(1, -110, 0, 14)
    dl.Position = UDim2.new(0, 44, 0, 26)

    local btn = Instance.new("TextButton", card)
    btn.Text             = "OFF"
    btn.Size             = UDim2.new(0, 54, 0, 26)
    btn.Position         = UDim2.new(1, -64, 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(26, 32, 46)
    btn.TextColor3       = Color3.fromRGB(100, 115, 140)
    btn.TextSize         = 11
    btn.Font             = Enum.Font.GothamBold
    btn.BorderSizePixel  = 0
    btn.ZIndex           = 3
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local bstroke = Instance.new("UIStroke", btn)
    bstroke.Color     = Color3.fromRGB(40, 52, 72)
    bstroke.Thickness = 1

    buttons[f.id] = { btn = btn, stroke = bstroke, color = f.col }

    local fid, fcol = f.id, f.col
    btn.MouseButton1Click:Connect(function()
        states[fid] = not states[fid]
        local on = states[fid]
        if on then
            btn.Text             = "ON ✓"
            btn.BackgroundColor3 = Color3.fromRGB(12, 38, 22)
            btn.TextColor3       = fcol
            bstroke.Color        = fcol
        else
            btn.Text             = "OFF"
            btn.BackgroundColor3 = Color3.fromRGB(26, 32, 46)
            btn.TextColor3       = Color3.fromRGB(100, 115, 140)
            bstroke.Color        = Color3.fromRGB(40, 52, 72)
        end
    end)
end

-- ── STATUS BAR ─────────────────────────────────────────────────────
local sBar = Instance.new("Frame", win)
sBar.Size             = UDim2.new(1, -20, 0, 30)
sBar.Position         = UDim2.new(0, 10, 1, -40)
sBar.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
sBar.BorderSizePixel  = 0
sBar.ZIndex           = 2
Instance.new("UICorner", sBar).CornerRadius = UDim.new(0, 8)

local sDot = Instance.new("Frame", sBar)
sDot.Size             = UDim2.new(0, 7, 0, 7)
sDot.Position         = UDim2.new(0, 10, 0.5, -3.5)
sDot.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
sDot.BorderSizePixel  = 0
sDot.ZIndex           = 3
Instance.new("UICorner", sDot).CornerRadius = UDim.new(1, 0)

local sLbl = mklbl(sBar, "idle — all systems ready", 10, nil,
    Color3.fromRGB(110, 130, 155), Enum.TextXAlignment.Left, 3)
sLbl.Size     = UDim2.new(1, -28, 1, 0)
sLbl.Position = UDim2.new(0, 24, 0, 0)

local function setStatus(msg, col)
    sLbl.Text               = msg
    sDot.BackgroundColor3   = col or Color3.fromRGB(70, 70, 90)
end

-- ── DRAG ───────────────────────────────────────────────────────────
local dragging, ds, sp = false, nil, nil
tb.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; ds = i.Position; sp = win.Position
    end
end)
tb.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - ds
        win.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
    end
end)

-- =========================================
-- FARM LOGIC
-- =========================================
local busy    = {}
local lastRun = {}
for _, f in ipairs(featureDefs) do
    busy[f.id]    = false
    lastRun[f.id] = 0
end

-- ── AUTO COLLECT ───────────────────────────────────────────────────
local function doCollect()
    if busy.collect then return end
    busy.collect = true
    setStatus("collecting cash...", Color3.fromRGB(50, 210, 100))

    local plot = myPlot()
    local col  = plot and plot:FindFirstChild("CollectModel")
    local pad  = col  and col:FindFirstChild("Pad", true)
    if pad then
        local c = player.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if h then
            local saved = h.CFrame
            h.CFrame = CFrame.new(pad.Position + Vector3.new(0, 3,   0))
            task.wait(0.4)
            h.CFrame = CFrame.new(pad.Position + Vector3.new(0, 2.4, 0))
            task.wait(0.7)
            h.CFrame = saved
            setStatus("cash collected ✓", Color3.fromRGB(50, 210, 100))
        end
    end

    lastRun.collect = tick()
    busy.collect    = false
end

-- ── AUTO FISH (PerfectCast, max luck 2x–5x, skips minigame) ───────
local function doFish()
    if busy.rod then return end
    busy.rod = true
    local c = player.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h then
        local saved = h.CFrame
        setStatus("heading to dock...", Color3.fromRGB(80, 150, 255))
        h.CFrame = CFrame.new(0, 10, 0)          -- island center
        task.wait(0.25)
        Network.send("rod_zone")                  -- register in fishing zone
        task.wait(0.3)
        setStatus("casting... 🎣  PerfectCast x5 luck", Color3.fromRGB(80, 150, 255))
        Network.send("rod_cast", "PerfectCast", 1.0)
        task.wait(0.6)                            -- bite delay (server: 0.5–0.55s)
        task.wait(1.6)                            -- MIN_REEL_TIME = 1.5s
        Network.send("rod_catch")
        setStatus("reeled in! 🐟  waiting for reveal...", Color3.fromRGB(80, 200, 255))
        task.wait(3.5)                            -- reveal animation
        h.CFrame = saved
        setStatus("fish done ✓", Color3.fromRGB(80, 200, 255))
    end
    lastRun.rod = tick()
    busy.rod    = false
end

-- ── FIRE PROXIMITY PROMPT ──────────────────────────────────────────
local function firePrompt(pad)
    local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return false end
    prompt.Enabled = true
    local ok = pcall(function()
        fireproximityprompt(prompt)               -- executor built-in
    end)
    if not ok then
        -- Fallback: try the game service
        pcall(function()
            game:GetService("ProximityPromptService"):PromptTriggered(prompt, player)
        end)
    end
    return true
end

-- ── AUTO ROLL PET ──────────────────────────────────────────────────
local function doRollPet()
    if busy.pet then return end
    busy.pet = true
    local plot = myPlot()
    local egg  = plot and plot:FindFirstChild("EggModel")
    local pad  = egg  and egg:FindFirstChild("Pad", true)
    if pad then
        local c = player.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if h then
            local saved = h.CFrame
            setStatus("rolling pet egg... 🥚", Color3.fromRGB(220, 100, 255))
            h.CFrame = CFrame.new(pad.Position + Vector3.new(0, 3, 0))
            task.wait(0.35)
            firePrompt(pad)
            task.wait(0.6)
            h.CFrame = saved
            setStatus("pet roll fired ✓", Color3.fromRGB(220, 100, 255))
        end
    else
        setStatus("egg pad not found", Color3.fromRGB(200, 80, 80))
    end
    lastRun.pet = tick()
    busy.pet    = false
end

-- ── AUTO ROLL BLOCK ────────────────────────────────────────────────
local function doRollBlock()
    if busy.block then return end
    busy.block = true
    local plot  = myPlot()
    local crate = plot  and plot:FindFirstChild("CrateModel")
    local pad   = crate and crate:FindFirstChild("Pad", true)
    if pad then
        local c = player.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if h then
            local saved = h.CFrame
            setStatus("rolling block crate... 📦", Color3.fromRGB(255, 160, 50))
            h.CFrame = CFrame.new(pad.Position + Vector3.new(0, 3, 0))
            task.wait(0.35)
            firePrompt(pad)
            task.wait(0.6)
            h.CFrame = saved
            setStatus("block roll fired ✓", Color3.fromRGB(255, 160, 50))
        end
    else
        setStatus("crate pad not found", Color3.fromRGB(200, 80, 80))
    end
    lastRun.block = tick()
    busy.block    = false
end

-- ── AUTO UPGRADE PET ───────────────────────────────────────────────
local function doUpgrade()
    if busy.upgrade then return end
    busy.upgrade = true
    local pd      = player:FindFirstChild("PlayerData")
    local pfolder = pd and pd:FindFirstChild("Pets")
    local eq      = pfolder and pfolder:FindFirstChild("Equipped")
    if eq then
        local sent = 0
        for _, slot in pairs(eq:GetChildren()) do
            local nm = slot:FindFirstChild("Name")
            local lv = slot:FindFirstChild("Level")
            if nm then
                setStatus("upgrading " .. nm.Value .. " lv" ..
                    tostring(lv and lv.Value or "?") .. "...",
                    Color3.fromRGB(255, 80, 150))
                Network.send("upgrade_pet", slot.Name)
                sent = sent + 1
                task.wait(0.2)
            end
        end
        setStatus(sent > 0 and "pet upgraded ✓" or "no pets equipped",
            Color3.fromRGB(255, 80, 150))
    else
        setStatus("no pets folder", Color3.fromRGB(100, 110, 130))
    end
    lastRun.upgrade = tick()
    busy.upgrade    = false
end

-- ── AUTO SELL STORED PETS ──────────────────────────────────────────
local function doSell()
    if busy.sell then return end
    busy.sell = true
    local pd      = player:FindFirstChild("PlayerData")
    local pfolder = pd and pd:FindFirstChild("Pets")
    local stored  = pfolder and pfolder:FindFirstChild("Stored")
    if stored then
        local n = 0
        for _, slot in pairs(stored:GetChildren()) do
            Network.send("sell_pet", slot.Name)
            n = n + 1
            task.wait(0.12)
        end
        setStatus(n > 0 and ("sold " .. n .. " stored pets ✓") or "storage empty",
            Color3.fromRGB(170, 210, 50))
    else
        setStatus("no stored pets", Color3.fromRGB(100, 110, 130))
    end
    lastRun.sell = tick()
    busy.sell    = false
end

-- =========================================
-- MAIN LOOP
-- =========================================
local INTERVALS = { collect = 12, rod = 8, pet = 10, block = 10, upgrade = 5, sell = 15 }
local ACTIONS   = {
    collect = doCollect,
    rod     = doFish,
    pet     = doRollPet,
    block   = doRollBlock,
    upgrade = doUpgrade,
    sell    = doSell,
}

RunService.Heartbeat:Connect(function()
    -- Live stat updates
    local money    = getPD("Money")    or 0
    local rebirths = getPD("Rebirths") or 0
    local petName  = getPD("Name")     or "—"
    local petLv    = getPD("Level")    or 1
    local rodName  = getPD("Equipped") or "—"
    local uncol, mps = collectInfo()

    statVals.money.Text       = fmtNum(money)
    statVals.rebirths.Text    = tostring(rebirths)
    statVals.uncollected.Text = uncol
    statVals.mps.Text         = mps
    petLbl.Text               = "🐾  " .. petName .. "  lv" .. petLv
    rodLbl.Text               = "🎣  " .. rodName

    -- Dispatch active features
    local now     = tick()
    local anyBusy = false
    for _, f in ipairs(featureDefs) do
        if busy[f.id] then anyBusy = true end
        if states[f.id] and not busy[f.id]
            and (now - lastRun[f.id]) >= INTERVALS[f.id] then
            task.spawn(ACTIONS[f.id])
        end
    end

    -- Show idle message when nothing is running
    if not anyBusy then
        local anyOn = false
        for _, f in ipairs(featureDefs) do
            if states[f.id] then anyOn = true; break end
        end
        if not anyOn then
            setStatus("idle — all systems ready", Color3.fromRGB(70, 70, 90))
        end
    end
end)

-- Slide-in entrance animation
TweenService:Create(win,
    TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    { Position = UDim2.new(0, 24, 0.5, -WIN_H / 2) }
):Play()

print("[FarmGUI v2] ✅ Loaded — 6 features ready")