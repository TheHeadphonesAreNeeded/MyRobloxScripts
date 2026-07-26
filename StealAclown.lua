-- ╔══════════════════════════════════╗
-- ║     ROBA UN PAYASO  -  AUTO STEAL     ║
-- ╚══════════════════════════════════╝
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Net = require(ReplicatedStorage.Packages.Net)
local Synchronizer = require(ReplicatedStorage.Packages.Synchronizer)

-- Remotes
local holdRemote     = Net:RemoteEvent("b096e1ca-9c3a-453b-8b60-268b235083b9")
local stealRemote    = Net:RemoteEvent("5aa39ea1-0c65-4fcf-aff9-b18a7ef277c3")
local deliveryRemote = Net:RemoteEvent("5c8f0dd0-0f9e-44ba-8f9b-197958b661ab")

-- Remove old GUI
local oldGui = PlayerGui:FindFirstChild("StealUI")
if oldGui then oldGui:Destroy() end

-- Helpers
local function getAnimalsFromChannel(ch)
    local list = ch:Get("AnimalList") or {}
    local animals = {}
    for slot, data in pairs(list) do
        if type(data) == "table" and data.Index and not data.Steal then
            table.insert(animals, { slot = slot, name = data.Index })
        end
    end
    table.sort(animals, function(a, b) return tostring(a.slot) < tostring(b.slot) end)
    return animals
end

local function getOtherPlots()
    local plots = {}
    for _, plot in ipairs(CollectionService:GetTagged("Plot")) do
        local ch = Synchronizer:Get(plot.Name)
        if ch then
            local owner = ch:Get("Owner")
            if owner and typeof(owner) == "Instance" and owner:IsA("Player") and owner ~= LocalPlayer then
                local animals = getAnimalsFromChannel(ch)
                if #animals > 0 then
                    table.insert(plots, { uid = plot.Name, model = plot, player = owner, channel = ch, animals = animals })
                end
            end
        end
    end
    return plots
end

local function getMyDeliveryHitbox()
    for _, plot in ipairs(CollectionService:GetTagged("Plot")) do
        local ch = Synchronizer:Get(plot.Name)
        if ch and ch:Get("Owner") == LocalPlayer then
            return plot:FindFirstChild("DeliveryHitbox")
        end
    end
end

-- Core steal routine
local isStealing = false

local function doSteal(plotData, animal, onStatus)
    if isStealing then onStatus("⚠️ Already stealing!") return end
    isStealing = true

    local char = LocalPlayer.Character
    local HRP = char and char:FindFirstChild("HumanoidRootPart")
    if not HRP then onStatus("❌ No character") isStealing = false return end

    local podium = plotData.model.AnimalPodiums:FindFirstChild(tostring(animal.slot))
    local spawnPart = podium and podium:FindFirstChild("Base") and podium.Base:FindFirstChild("Spawn")
    if not spawnPart then onStatus("❌ Podium not found") isStealing = false return end

    local savedCF = HRP.CFrame

    onStatus("🚀 Teleporting to " .. animal.name .. "...")
    char:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, 3.5, 0)))
    task.wait(0.12)

    onStatus("⏳ Holding E... (1.5s)")
    holdRemote:FireServer(workspace:GetServerTimeNow() + 53, "5c0bd012-dfb2-4bac-8f1a-e41f136e4744")
    holdRemote:FireServer(workspace:GetServerTimeNow() + 53, "6be28b5b-dbc3-4aab-aa0c-6ebcfa191f22")

    local promptAtt = spawnPart:FindFirstChild("PromptAttachment")
    if promptAtt then
        for _, pp in ipairs(promptAtt:GetChildren()) do
            if pp:IsA("ProximityPrompt") and pp:GetAttribute("State") == "Steal" then
                pp:InputHoldBegin() break
            end
        end
    end

    task.wait(1.55)

    onStatus("🎪 Grabbing clown...")
    stealRemote:FireServer(workspace:GetServerTimeNow() + 67, "c262398d-68e3-4499-8bea-99766bf11686", plotData.uid, animal.slot)
    task.wait(0.06)
    stealRemote:FireServer(workspace:GetServerTimeNow() + 67, "579e6c26-5a80-407d-9488-0f84752e8f1f", plotData.uid, animal.slot)

    if promptAtt then
        for _, pp in ipairs(promptAtt:GetChildren()) do
            if pp:IsA("ProximityPrompt") then pp:InputHoldEnd() end
        end
    end

    onStatus("⌛ Waiting for server confirmation...")
    local t0 = tick()
    while not LocalPlayer:GetAttribute("Stealing") and (tick() - t0) < 5 do task.wait(0.08) end

    if not LocalPlayer:GetAttribute("Stealing") then
        onStatus("❌ Server rejected steal (too far / already taken?)")
        char:PivotTo(savedCF)
        isStealing = false
        return
    end

    onStatus("🏠 Teleporting to collection zone...")
    local deliveryHitbox = getMyDeliveryHitbox()
    if not deliveryHitbox then
        onStatus("❌ Can't find your base delivery zone")
        isStealing = false
        return
    end

    char:PivotTo(CFrame.new(deliveryHitbox.Position + Vector3.new(0, 3, 0)))
    task.wait(0.2)
    deliveryRemote:FireServer("7799aa8a-03f9-4df1-ab0f-b6df84f6b36c")
    task.wait(0.05)
    deliveryRemote:FireServer("7799aa8a-03f9-4df1-ab0f-b6df84f6b36c")

    local t1 = tick()
    while LocalPlayer:GetAttribute("Stealing") and (tick() - t1) < 5 do task.wait(0.08) end

    if not LocalPlayer:GetAttribute("Stealing") then
        onStatus("✅ Steal complete! " .. animal.name .. " added to your base!")
    else
        onStatus("⚠️ Delivered — check your base manually")
    end

    isStealing = false
end

-- ══════════════════════════════════════
-- GUI
-- ══════════════════════════════════════
local function mkCorner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 10) c.Parent = p end
local function mkPad(p, a, b, c, d) local u = Instance.new("UIPadding") u.PaddingTop = UDim.new(0, a) u.PaddingBottom = UDim.new(0, b or a) u.PaddingLeft = UDim.new(0, c or a) u.PaddingRight = UDim.new(0, d or c or a) u.Parent = p end

local gui = Instance.new("ScreenGui")
gui.Name = "StealUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 360, 0, 480)
win.Position = UDim2.new(0.5, -180, 0.5, -240)
win.BackgroundColor3 = Color3.fromRGB(14, 10, 22)
win.BorderSizePixel = 0
win.ClipsDescendants = true
win.Parent = gui
mkCorner(win, 14)
local ws = Instance.new("UIStroke") ws.Color = Color3.fromRGB(160, 60, 255) ws.Thickness = 2 ws.Parent = win

local tb = Instance.new("Frame")
tb.Size = UDim2.new(1, 0, 0, 46) tb.BackgroundColor3 = Color3.fromRGB(90, 20, 150) tb.BorderSizePixel = 0 tb.Parent = win
mkCorner(tb, 14)
local tbFix = Instance.new("Frame")
tbFix.Size = UDim2.new(1, 0, 0, 14) tbFix.Position = UDim2.new(0, 0, 1, -14)
tbFix.BackgroundColor3 = Color3.fromRGB(90, 20, 150) tbFix.BorderSizePixel = 0 tbFix.Parent = tb

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -52, 1, 0) titleLbl.Position = UDim2.new(0, 12, 0, 0)
titleLbl.BackgroundTransparency = 1 titleLbl.Text = "🎪 Auto Steal"
titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255) titleLbl.TextSize = 18
titleLbl.Font = Enum.Font.GothamBold titleLbl.TextXAlignment = Enum.TextXAlignment.Left titleLbl.Parent = tb

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30) closeBtn.Position = UDim2.new(1, -40, 0.5, -15)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40) closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255) closeBtn.TextSize = 15
closeBtn.Font = Enum.Font.GothamBold closeBtn.BorderSizePixel = 0 closeBtn.Parent = tb
mkCorner(closeBtn, 8)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Drag
local dragging, ds, sp = false, nil, nil
tb.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true ds = i.Position sp = win.Position end
end)
tb.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
game:GetService("UserInputService").InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - ds
        win.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
    end
end)

-- Status bar
local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, -16, 0, 28) statusBar.Position = UDim2.new(0, 8, 0, 52)
statusBar.BackgroundColor3 = Color3.fromRGB(25, 15, 40) statusBar.BorderSizePixel = 0 statusBar.Parent = win
mkCorner(statusBar, 7)
local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -8, 1, 0) statusLbl.Position = UDim2.new(0, 8, 0, 0)
statusLbl.BackgroundTransparency = 1 statusLbl.Text = "Select a player → choose a brainrot → hit Auto Steal"
statusLbl.TextColor3 = Color3.fromRGB(200, 170, 255) statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.Gotham statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextTruncate = Enum.TextTruncate.AtEnd statusLbl.Parent = statusBar

-- Players header
local ph = Instance.new("Frame")
ph.Size = UDim2.new(1, -16, 0, 22) ph.Position = UDim2.new(0, 8, 0, 86)
ph.BackgroundTransparency = 1 ph.Parent = win
local phLbl = Instance.new("TextLabel")
phLbl.Size = UDim2.new(1, 0, 1, 0) phLbl.BackgroundTransparency = 1
phLbl.Text = "PLAYERS" phLbl.TextColor3 = Color3.fromRGB(150, 110, 255)
phLbl.TextSize = 11 phLbl.Font = Enum.Font.GothamBold
phLbl.TextXAlignment = Enum.TextXAlignment.Left phLbl.Parent = ph

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 56, 0, 18) refreshBtn.Position = UDim2.new(1, -56, 0.1, 0)
refreshBtn.BackgroundColor3 = Color3.fromRGB(55, 30, 90) refreshBtn.Text = "↺ Refresh"
refreshBtn.TextColor3 = Color3.fromRGB(200, 170, 255) refreshBtn.TextSize = 11
refreshBtn.Font = Enum.Font.Gotham refreshBtn.BorderSizePixel = 0 refreshBtn.Parent = ph
mkCorner(refreshBtn, 6)

-- Player scroll
local pScroll = Instance.new("ScrollingFrame")
pScroll.Size = UDim2.new(1, -16, 0, 110) pScroll.Position = UDim2.new(0, 8, 0, 110)
pScroll.BackgroundColor3 = Color3.fromRGB(20, 12, 34) pScroll.BorderSizePixel = 0
pScroll.ScrollBarThickness = 3 pScroll.CanvasSize = UDim2.new(0, 0, 0, 0) pScroll.Parent = win
mkCorner(pScroll, 8)
local pLayout = Instance.new("UIListLayout")
pLayout.FillDirection = Enum.FillDirection.Vertical pLayout.Padding = UDim.new(0, 4) pLayout.Parent = pScroll
mkPad(pScroll, 5, 5, 6, 6)

-- Divider + Brainrot header
local div = Instance.new("Frame")
div.Size = UDim2.new(1, -16, 0, 1) div.Position = UDim2.new(0, 8, 0, 226)
div.BackgroundColor3 = Color3.fromRGB(90, 40, 160) div.BorderSizePixel = 0 div.Parent = win

local bh = Instance.new("Frame")
bh.Size = UDim2.new(1, -16, 0, 22) bh.Position = UDim2.new(0, 8, 0, 228)
bh.BackgroundTransparency = 1 bh.Parent = win
local bhLbl = Instance.new("TextLabel")
bhLbl.Size = UDim2.new(1, 0, 1, 0) bhLbl.BackgroundTransparency = 1
bhLbl.Text = "BRAINROTS IN BASE" bhLbl.TextColor3 = Color3.fromRGB(150, 110, 255)
bhLbl.TextSize = 11 bhLbl.Font = Enum.Font.GothamBold
bhLbl.TextXAlignment = Enum.TextXAlignment.Left bhLbl.Parent = bh

-- Brainrot scroll
local bScroll = Instance.new("ScrollingFrame")
bScroll.Size = UDim2.new(1, -16, 0, 195) bScroll.Position = UDim2.new(0, 8, 0, 254)
bScroll.BackgroundColor3 = Color3.fromRGB(20, 12, 34) bScroll.BorderSizePixel = 0
bScroll.ScrollBarThickness = 3 bScroll.CanvasSize = UDim2.new(0, 0, 0, 0) bScroll.Parent = win
mkCorner(bScroll, 8)
local bLayout = Instance.new("UIListLayout")
bLayout.FillDirection = Enum.FillDirection.Vertical bLayout.Padding = UDim.new(0, 4) bLayout.Parent = bScroll
mkPad(bScroll, 5, 5, 6, 6)

local function updateCanvas(scroll, layout)
    scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end

local function clearChildren(scroll)
    for _, c in ipairs(scroll:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
end

-- ══════════════════════════════════════
-- LIST BUILDERS
-- ══════════════════════════════════════
local currentPlot = nil
local buildPlayerList  -- forward declare so buildBrainrotList can call it

local function buildBrainrotList(plotData)
    clearChildren(bScroll)
    bhLbl.Text = "BRAINROTS — " .. plotData.player.Name

    if #plotData.animals == 0 then
        local e = Instance.new("TextLabel")
        e.Size = UDim2.new(1, 0, 0, 34) e.BackgroundTransparency = 1
        e.Text = "No stealable brainrots" e.TextColor3 = Color3.fromRGB(130, 120, 160)
        e.TextSize = 12 e.Font = Enum.Font.Gotham e.Parent = bScroll
        updateCanvas(bScroll, bLayout) return
    end

    for _, animal in ipairs(plotData.animals) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 44) row.BackgroundColor3 = Color3.fromRGB(30, 18, 50)
        row.BorderSizePixel = 0 row.Parent = bScroll mkCorner(row, 8)

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 28, 1, 0) icon.BackgroundTransparency = 1
        icon.Text = "🎪" icon.TextSize = 18 icon.Font = Enum.Font.GothamBold
        icon.TextXAlignment = Enum.TextXAlignment.Center icon.Parent = row

        local nLbl = Instance.new("TextLabel")
        nLbl.Size = UDim2.new(1, -160, 0, 22) nLbl.Position = UDim2.new(0, 32, 0, 3)
        nLbl.BackgroundTransparency = 1 nLbl.Text = animal.name
        nLbl.TextColor3 = Color3.fromRGB(230, 210, 255) nLbl.TextSize = 12
        nLbl.Font = Enum.Font.GothamBold nLbl.TextXAlignment = Enum.TextXAlignment.Left
        nLbl.TextTruncate = Enum.TextTruncate.AtEnd nLbl.Parent = row

        local sLbl = Instance.new("TextLabel")
        sLbl.Size = UDim2.new(1, -160, 0, 16) sLbl.Position = UDim2.new(0, 32, 0, 24)
        sLbl.BackgroundTransparency = 1 sLbl.Text = "Slot " .. tostring(animal.slot)
        sLbl.TextColor3 = Color3.fromRGB(130, 110, 170) sLbl.TextSize = 10
        sLbl.Font = Enum.Font.Gotham sLbl.TextXAlignment = Enum.TextXAlignment.Left sLbl.Parent = row

        local aBtnFrame = Instance.new("Frame")
        aBtnFrame.Size = UDim2.new(0, 90, 0, 32) aBtnFrame.Position = UDim2.new(1, -96, 0.5, -16)
        aBtnFrame.BackgroundColor3 = Color3.fromRGB(140, 30, 220) aBtnFrame.BorderSizePixel = 0
        aBtnFrame.Parent = row mkCorner(aBtnFrame, 7)

        local aBtn = Instance.new("TextButton")
        aBtn.Size = UDim2.new(1, 0, 1, 0) aBtn.BackgroundTransparency = 1
        aBtn.Text = "⚡ Auto Steal" aBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        aBtn.TextSize = 11 aBtn.Font = Enum.Font.GothamBold
        aBtn.BorderSizePixel = 0 aBtn.Parent = aBtnFrame

        aBtn.MouseButton1Click:Connect(function()
            if isStealing then statusLbl.Text = "⚠️ Already stealing!" return end
            aBtn.Text = "..."
            aBtnFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 90)

            local ch = Synchronizer:Get(plotData.uid)
            if not ch then statusLbl.Text = "❌ Lost plot channel" return end
            local fresh = ch:Get("AnimalList") or {}
            local slot = fresh[animal.slot]
            if not slot or type(slot) ~= "table" or slot.Steal then
                statusLbl.Text = "❌ Brainrot no longer available"
                aBtn.Text = "⚡ Auto Steal" aBtnFrame.BackgroundColor3 = Color3.fromRGB(140, 30, 220)
                return
            end

            task.spawn(function()
                doSteal(plotData, animal, function(msg) statusLbl.Text = msg end)
                task.wait(0.5)
                aBtn.Text = "⚡ Auto Steal"
                aBtnFrame.BackgroundColor3 = Color3.fromRGB(140, 30, 220)
            end)
        end)

        row.MouseEnter:Connect(function() row.BackgroundColor3 = Color3.fromRGB(45, 25, 70) end)
        row.MouseLeave:Connect(function() row.BackgroundColor3 = Color3.fromRGB(30, 18, 50) end)
    end

    bLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        updateCanvas(bScroll, bLayout)
    end)
    updateCanvas(bScroll, bLayout)
end

buildPlayerList = function()
    clearChildren(pScroll)
    local plots = getOtherPlots()
    phLbl.Text = "PLAYERS  (" .. #plots .. " with brainrots)"

    if #plots == 0 then
        local e = Instance.new("TextLabel")
        e.Size = UDim2.new(1, 0, 0, 34) e.BackgroundTransparency = 1
        e.Text = "No other players with stealable brainrots"
        e.TextColor3 = Color3.fromRGB(130, 120, 160) e.TextSize = 11
        e.Font = Enum.Font.Gotham e.Parent = pScroll
        updateCanvas(pScroll, pLayout)

        -- Clear brainrot panel if selected player is gone
        if currentPlot then
            local stillExists = false
            for _, p in ipairs(plots) do
                if p.uid == currentPlot.uid then stillExists = true break end
            end
            if not stillExists then
                currentPlot = nil
                clearChildren(bScroll)
                bhLbl.Text = "BRAINROTS IN BASE"
            end
        end
        return
    end

    -- Check if currentPlot player is still in the new list
    local updatedCurrentPlot = nil
    for _, plotData in ipairs(plots) do
        if currentPlot and plotData.uid == currentPlot.uid then
            updatedCurrentPlot = plotData
        end

        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 36) row.BackgroundColor3 = Color3.fromRGB(28, 16, 46)
        row.BorderSizePixel = 0 row.AutoButtonColor = false row.Text = "" row.Parent = pScroll
        mkCorner(row, 8)

        local pIco = Instance.new("TextLabel")
        pIco.Size = UDim2.new(0, 26, 1, 0) pIco.BackgroundTransparency = 1
        pIco.Text = "👤" pIco.TextSize = 16 pIco.Font = Enum.Font.Gotham
        pIco.TextXAlignment = Enum.TextXAlignment.Center pIco.Parent = row

        local pName = Instance.new("TextLabel")
        pName.Size = UDim2.new(1, -90, 1, 0) pName.Position = UDim2.new(0, 30, 0, 0)
        pName.BackgroundTransparency = 1 pName.Text = plotData.player.Name
        pName.TextColor3 = Color3.fromRGB(230, 220, 255) pName.TextSize = 13
        pName.Font = Enum.Font.GothamBold pName.TextXAlignment = Enum.TextXAlignment.Left pName.Parent = row

        local pCount = Instance.new("TextLabel")
        pCount.Size = UDim2.new(0, 60, 1, 0) pCount.Position = UDim2.new(1, -64, 0, 0)
        pCount.BackgroundTransparency = 1 pCount.Text = tostring(#plotData.animals) .. " 🎪"
        pCount.TextColor3 = Color3.fromRGB(160, 120, 255) pCount.TextSize = 12
        pCount.Font = Enum.Font.Gotham pCount.TextXAlignment = Enum.TextXAlignment.Right pCount.Parent = row

        row.MouseEnter:Connect(function() row.BackgroundColor3 = Color3.fromRGB(48, 26, 78) end)
        row.MouseLeave:Connect(function() row.BackgroundColor3 = Color3.fromRGB(28, 16, 46) end)
        row.MouseButton1Click:Connect(function()
            currentPlot = plotData
            statusLbl.Text = "Viewing " .. plotData.player.Name .. "'s brainrots — click ⚡ Auto Steal"
            buildBrainrotList(plotData)
        end)
    end

    -- If the selected player is still around, refresh their brainrot panel silently
    if updatedCurrentPlot then
        currentPlot = updatedCurrentPlot
        buildBrainrotList(updatedCurrentPlot)
    elseif currentPlot then
        -- Selected player left / lost all brainrots
        currentPlot = nil
        clearChildren(bScroll)
        bhLbl.Text = "BRAINROTS IN BASE"
        statusLbl.Text = "Player left or lost all brainrots"
    end

    pLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        updateCanvas(pScroll, pLayout)
    end)
    updateCanvas(pScroll, pLayout)
end

refreshBtn.MouseButton1Click:Connect(buildPlayerList)

-- ══════════════════════════════════════
-- AUTO-UPDATE SYSTEM
-- ══════════════════════════════════════

-- Debounced rebuild so rapid events don't spam rebuilds
local rebuildQueued = false
local function scheduleRebuild()
    if rebuildQueued then return end
    rebuildQueued = true
    task.delay(0.4, function()
        rebuildQueued = false
        if gui.Parent then -- only rebuild if GUI is still alive
            buildPlayerList()
        end
    end)
end

-- Track channel listeners per plot so we can clean them up
local plotListeners = {} -- [plotName] = disconnect function

local function watchPlot(plot)
    local uid = plot.Name
    if plotListeners[uid] then return end -- already watching

    -- Wait for channel to exist (non-blocking poll)
    task.spawn(function()
        local ch
        local attempts = 0
        while not ch and attempts < 20 do
            ch = Synchronizer:Get(uid)
            if not ch then task.wait(0.5) end
            attempts += 1
        end
        if not ch then return end

        -- Listen for AnimalList changes on this plot
        local conn = ch:OnChanged("AnimalList", function()
            scheduleRebuild()
        end)

        -- Also listen for Owner changes (plot claimed/unclaimed)
        local ownerConn = ch:OnChanged("Owner", function()
            scheduleRebuild()
        end)

        -- Store cleanup
        plotListeners[uid] = function()
            if typeof(conn) == "function" then conn()
            elseif conn and conn.Disconnect then conn:Disconnect() end

            if typeof(ownerConn) == "function" then ownerConn()
            elseif ownerConn and ownerConn.Disconnect then ownerConn:Disconnect() end
        end
    end)
end

local function unwatchPlot(plot)
    local uid = plot.Name
    if plotListeners[uid] then
        plotListeners[uid]()
        plotListeners[uid] = nil
    end
end

-- Watch all existing plots
for _, plot in ipairs(CollectionService:GetTagged("Plot")) do
    watchPlot(plot)
end

-- Watch plots added in the future (e.g. late-joining player claims a plot)
CollectionService:GetInstanceAddedSignal("Plot"):Connect(function(plot)
    watchPlot(plot)
    scheduleRebuild()
end)

CollectionService:GetInstanceRemovedSignal("Plot"):Connect(function(plot)
    unwatchPlot(plot)
    scheduleRebuild()
end)

-- Players joining / leaving
Players.PlayerAdded:Connect(function()
    scheduleRebuild()
end)

Players.PlayerRemoving:Connect(function(player)
    -- If the leaving player was selected, clear the brainrot panel immediately
    if currentPlot and currentPlot.player == player then
        currentPlot = nil
        clearChildren(bScroll)
        bhLbl.Text = "BRAINROTS IN BASE"
        statusLbl.Text = player.Name .. " left the game"
    end
    scheduleRebuild()
end)

-- Clean up all listeners when the GUI is destroyed
gui.Destroying:Connect(function()
    for uid, disconnect in pairs(plotListeners) do
        disconnect()
        plotListeners[uid] = nil
    end
end)

-- Initial load
buildPlayerList()
gui.Parent = PlayerGui
print("✅ Auto Steal UI loaded with live updates!")
