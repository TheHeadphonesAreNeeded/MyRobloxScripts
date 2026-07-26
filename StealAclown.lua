-- ════════════════════════════════════════════════════════
--   ROBA UN PAYASO  ·  AUTO STEAL  v3
--   Tabs: 🎯 Manual | 💰 Best Value | 🔄 Rebirth
-- ════════════════════════════════════════════════════════

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")
local Net               = require(ReplicatedStorage.Packages.Net)
local Synchronizer      = require(ReplicatedStorage.Packages.Synchronizer)

-- Data modules (pcall so missing modules don't crash)
local ok1, AnimalsShared = pcall(require, ReplicatedStorage.Shared.Animals)
if not ok1 then AnimalsShared = nil end
local ok2, AnimalsData   = pcall(require, ReplicatedStorage.Datas.Animals)
if not ok2 then AnimalsData = nil end
local ok3, NumberUtils   = pcall(require, ReplicatedStorage.Utils.NumberUtils)
if not ok3 then NumberUtils = nil end

-- Remotes
local holdRemote     = Net:RemoteEvent("b096e1ca-9c3a-453b-8b60-268b235083b9")
local stealRemote    = Net:RemoteEvent("5aa39ea1-0c65-4fcf-aff9-b18a7ef277c3")
local deliveryRemote = Net:RemoteEvent("5c8f0dd0-0f9e-44ba-8f9b-197958b661ab")

local old = PlayerGui:FindFirstChild("StealUI")
if old then old:Destroy() end

-- ── Value helpers ────────────────────────────────────────
local function getSellValue(name)
    if not AnimalsData then return 0 end
    local ok, v = pcall(function() return AnimalsData:GetSellValue(name) end)
    return (ok and type(v)=="number") and v or 0
end

local function getGenRate(name, mutation, traits)
    if AnimalsShared then
        local ok, v = pcall(function()
            return AnimalsShared:GetGeneration(name, mutation, traits, LocalPlayer)
        end)
        if ok and type(v)=="number" then return v end
    end
    return getSellValue(name)
end

local function fmt(n)
    if NumberUtils then
        local ok, s = pcall(function() return NumberUtils:ToString(n, 2) end)
        if ok then return "$"..s end
    end
    if     n >= 1e12 then return ("$%.2fT"):format(n/1e12)
    elseif n >= 1e9  then return ("$%.2fB"):format(n/1e9)
    elseif n >= 1e6  then return ("$%.2fM"):format(n/1e6)
    elseif n >= 1e3  then return ("$%.1fK"):format(n/1e3)
    else                  return ("$%d"):format(n) end
end

-- ── Channel / plot helpers ───────────────────────────────
local function getAnimalsFromChannel(ch)
    local list = ch:Get("AnimalList") or {}
    local out  = {}
    for slot, data in pairs(list) do
        if type(data)=="table" and data.Index and not data.Steal then
            table.insert(out, {
                slot     = slot,
                name     = data.Index,
                mutation = data.Mutation,
                traits   = data.Traits,
                genRate  = getGenRate(data.Index, data.Mutation, data.Traits),
                sellVal  = getSellValue(data.Index),
            })
        end
    end
    return out
end

local function getOtherPlots()
    local plots = {}
    for _, plot in ipairs(CollectionService:GetTagged("Plot")) do
        local ch = Synchronizer:Get(plot.Name)
        if ch then
            local owner = ch:Get("Owner")
            if owner and typeof(owner)=="Instance" and owner:IsA("Player") and owner ~= LocalPlayer then
                local animals = getAnimalsFromChannel(ch)
                if #animals > 0 then
                    table.insert(plots, { uid=plot.Name, model=plot, player=owner, channel=ch, animals=animals })
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

-- ── Rebirth detection ────────────────────────────────────
local function getRebirthRequirement()
    -- Try player channel
    local pch = Synchronizer:Get(LocalPlayer)
    if pch then
        for _, k in ipairs({"RebirthRequired","RebirthAnimal","RebirthNeeded","RebirthGoal","NextRebirthAnimal","RebirthBrainrot"}) do
            local ok, v = pcall(function() return pch:Get(k) end)
            if ok and type(v)=="string" and #v>0 then return v end
        end
        -- Try if rebirth is a table
        for _, k in ipairs({"Rebirth","RebirthData","NextRebirth"}) do
            local ok, v = pcall(function() return pch:Get(k) end)
            if ok and type(v)=="table" then
                for _, field in ipairs({"Required","Animal","Needed","Goal","Name","Index"}) do
                    if type(v[field])=="string" and #v[field]>0 then return v[field] end
                end
            end
        end
    end
    -- Try LocalPlayer attributes
    for _, k in ipairs({"RebirthRequired","RebirthAnimal","RebirthNeeded","RebirthBrainrot"}) do
        local v = LocalPlayer:GetAttribute(k)
        if type(v)=="string" and #v>0 then return v end
    end
    return nil
end

-- ── Core steal ───────────────────────────────────────────
local isStealing = false

local function doSteal(plotData, animal, onStatus)
    if isStealing then onStatus("⚠️ Already stealing!") return end
    isStealing = true

    local char = LocalPlayer.Character
    local HRP  = char and char:FindFirstChild("HumanoidRootPart")
    if not HRP then onStatus("❌ No character") isStealing=false return end

    local podium    = plotData.model.AnimalPodiums:FindFirstChild(tostring(animal.slot))
    local spawnPart = podium and podium:FindFirstChild("Base") and podium.Base:FindFirstChild("Spawn")
    if not spawnPart then onStatus("❌ Podium not found") isStealing=false return end

    local savedCF = HRP.CFrame

    onStatus("🚀 Teleporting to "..animal.name.."...")
    char:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, 3.5, 0)))
    task.wait(0.12)

    onStatus("⏳ Holding E... (1.5s)")
    holdRemote:FireServer(workspace:GetServerTimeNow()+53, "5c0bd012-dfb2-4bac-8f1a-e41f136e4744")
    holdRemote:FireServer(workspace:GetServerTimeNow()+53, "6be28b5b-dbc3-4aab-aa0c-6ebcfa191f22")

    local promptAtt = spawnPart:FindFirstChild("PromptAttachment")
    if promptAtt then
        for _, pp in ipairs(promptAtt:GetChildren()) do
            if pp:IsA("ProximityPrompt") and pp:GetAttribute("State")=="Steal" then
                pp:InputHoldBegin() break
            end
        end
    end

    task.wait(1.55)

    onStatus("🎪 Grabbing...")
    stealRemote:FireServer(workspace:GetServerTimeNow()+67, "c262398d-68e3-4499-8bea-99766bf11686", plotData.uid, animal.slot)
    task.wait(0.06)
    stealRemote:FireServer(workspace:GetServerTimeNow()+67, "579e6c26-5a80-407d-9488-0f84752e8f1f", plotData.uid, animal.slot)

    if promptAtt then
        for _, pp in ipairs(promptAtt:GetChildren()) do
            if pp:IsA("ProximityPrompt") then pp:InputHoldEnd() end
        end
    end

    onStatus("⌛ Waiting for server...")
    local t0 = tick()
    while not LocalPlayer:GetAttribute("Stealing") and (tick()-t0)<5 do task.wait(0.08) end

    if not LocalPlayer:GetAttribute("Stealing") then
        onStatus("❌ Server rejected (too far / already taken?)")
        char:PivotTo(savedCF) isStealing=false return
    end

    onStatus("🏠 Delivering to base...")
    local dh = getMyDeliveryHitbox()
    if not dh then onStatus("❌ Can't find delivery zone") isStealing=false return end

    char:PivotTo(CFrame.new(dh.Position + Vector3.new(0, 3, 0)))
    task.wait(0.2)
    deliveryRemote:FireServer("7799aa8a-03f9-4df1-ab0f-b6df84f6b36c")
    task.wait(0.05)
    deliveryRemote:FireServer("7799aa8a-03f9-4df1-ab0f-b6df84f6b36c")

    local t1 = tick()
    while LocalPlayer:GetAttribute("Stealing") and (tick()-t1)<5 do task.wait(0.08) end

    if not LocalPlayer:GetAttribute("Stealing") then
        onStatus("✅ "..animal.name.." stolen!")
    else
        onStatus("⚠️ Check your base — may have worked")
    end

    isStealing = false
end

-- ════════════════════════════════════════════════════════
-- GUI CONSTANTS + HELPERS
-- ════════════════════════════════════════════════════════
local W, H   = 560, 650
local PURPLE  = Color3.fromRGB(120, 30, 220)
local DPURPLE = Color3.fromRGB(14, 8, 24)
local MPURPLE = Color3.fromRGB(24, 14, 42)
local LPURPLE = Color3.fromRGB(38, 22, 64)
local ACCENT  = Color3.fromRGB(150, 60, 255)
local TEXT    = Color3.fromRGB(225, 210, 255)
local SUBTEXT = Color3.fromRGB(140, 115, 190)
local GREEN   = Color3.fromRGB(80, 210, 100)
local GOLD    = Color3.fromRGB(255, 210, 60)
local RED     = Color3.fromRGB(220, 55, 55)

local function mkCorner(p, r)
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 10) c.Parent = p
end
local function mkPad(p, t, b, l, r)
    local u = Instance.new("UIPadding")
    u.PaddingTop=UDim.new(0,t) u.PaddingBottom=UDim.new(0,b or t)
    u.PaddingLeft=UDim.new(0,l or t) u.PaddingRight=UDim.new(0,r or l or t)
    u.Parent = p
end
local function mkStroke(p, col, th)
    local s = Instance.new("UIStroke") s.Color=col or ACCENT s.Thickness=th or 2 s.Parent=p
end
local function mkLabel(p, text, size, color, bold, xa)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency=1 l.Text=text l.TextSize=size or 13
    l.TextColor3=color or TEXT l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextXAlignment=xa or Enum.TextXAlignment.Left l.Size=UDim2.new(1,0,1,0) l.Parent=p return l
end
local function mkBtn(p, text, size, bold)
    local b = Instance.new("TextButton")
    b.BackgroundTransparency=1 b.Text=text b.TextSize=size or 12 b.BorderSizePixel=0
    b.TextColor3=TEXT b.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    b.Size=UDim2.new(1,0,1,0) b.Parent=p return b
end
local function mkScroll(p, size, pos, bg)
    local s = Instance.new("ScrollingFrame")
    s.Size=size s.Position=pos s.BackgroundColor3=bg or MPURPLE s.BorderSizePixel=0
    s.ScrollBarThickness=4 s.CanvasSize=UDim2.new(0,0,0,0)
    s.ScrollBarImageColor3=ACCENT s.Parent=p mkCorner(s,8) return s
end
local function mkVList(p, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection=Enum.FillDirection.Vertical l.Padding=UDim.new(0,gap or 5) l.Parent=p return l
end
local function mkHList(p, gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection=Enum.FillDirection.Horizontal l.Padding=UDim.new(0,gap or 5) l.Parent=p return l
end
local function autoCanvas(scroll, layout)
    scroll.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 12)
end
local function clearScroll(scroll)
    for _, c in ipairs(scroll:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    scroll.CanvasSize = UDim2.new(0,0,0,0)
end

-- ── Reusable section header row ──────────────────────────
local function mkSectionHeader(parent, yPos, labelText, btnText, btnCallback)
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,24) f.Position=UDim2.new(0,0,0,yPos)
    f.BackgroundTransparency=1 f.Parent=parent

    local lbl = Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-80,1,0) lbl.BackgroundTransparency=1 lbl.Text=labelText
    lbl.TextColor3=Color3.fromRGB(140,100,240) lbl.TextSize=11
    lbl.Font=Enum.Font.GothamBold lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=f

    if btnText and btnCallback then
        local rb=Instance.new("TextButton")
        rb.Size=UDim2.new(0,70,0,20) rb.Position=UDim2.new(1,-70,0.1,0)
        rb.BackgroundColor3=LPURPLE rb.Text=btnText rb.TextColor3=SUBTEXT
        rb.TextSize=11 rb.Font=Enum.Font.Gotham rb.BorderSizePixel=0 rb.Parent=f mkCorner(rb,6)
        rb.MouseButton1Click:Connect(btnCallback)
    end

    return lbl
end

-- ── Row builder for a steal-able brainrot entry ──────────
local function mkBrainrotRow(parent, animal, plotData, btnColor, onSteal)
    local val = animal.genRate > 0 and (fmt(animal.genRate).."/s") or (animal.sellVal>0 and fmt(animal.sellVal) or "")

    local row = Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,52) row.BackgroundColor3=MPURPLE row.BorderSizePixel=0 row.Parent=parent mkCorner(row,8)

    local ico = Instance.new("TextLabel")
    ico.Size=UDim2.new(0,34,1,0) ico.BackgroundTransparency=1 ico.Text="🎪"
    ico.TextSize=20 ico.Font=Enum.Font.GothamBold ico.TextXAlignment=Enum.TextXAlignment.Center ico.Parent=row

    local nLbl = Instance.new("TextLabel")
    nLbl.Size=UDim2.new(1,-178,0,24) nLbl.Position=UDim2.new(0,36,0,4) nLbl.BackgroundTransparency=1
    nLbl.Text=animal.name nLbl.TextColor3=TEXT nLbl.TextSize=13
    nLbl.Font=Enum.Font.GothamBold nLbl.TextXAlignment=Enum.TextXAlignment.Left
    nLbl.TextTruncate=Enum.TextTruncate.AtEnd nLbl.Parent=row

    local subLine = (plotData and ("👤 "..plotData.player.Name.."  ") or "") ..
                    (val~="" and ("💰 "..val) or "") ..
                    "  Slot "..tostring(animal.slot)
    local sLbl = Instance.new("TextLabel")
    sLbl.Size=UDim2.new(1,-178,0,18) sLbl.Position=UDim2.new(0,36,0,28) sLbl.BackgroundTransparency=1
    sLbl.Text=subLine sLbl.TextColor3=GREEN sLbl.TextSize=11
    sLbl.Font=Enum.Font.Gotham sLbl.TextXAlignment=Enum.TextXAlignment.Left sLbl.Parent=row

    local aBtnF=Instance.new("Frame")
    aBtnF.Size=UDim2.new(0,104,0,36) aBtnF.Position=UDim2.new(1,-110,0.5,-18)
    aBtnF.BackgroundColor3=btnColor or PURPLE aBtnF.BorderSizePixel=0 aBtnF.Parent=row mkCorner(aBtnF,7)

    local aBtn=Instance.new("TextButton")
    aBtn.Size=UDim2.new(1,0,1,0) aBtn.BackgroundTransparency=1
    aBtn.Text="⚡ Auto Steal" aBtn.TextColor3=Color3.fromRGB(255,255,255)
    aBtn.TextSize=12 aBtn.Font=Enum.Font.GothamBold aBtn.BorderSizePixel=0 aBtn.Parent=aBtnF

    row.MouseEnter:Connect(function() row.BackgroundColor3=LPURPLE end)
    row.MouseLeave:Connect(function() row.BackgroundColor3=MPURPLE end)
    aBtn.MouseButton1Click:Connect(function()
        if isStealing then return end
        aBtn.Text="..." aBtnF.BackgroundColor3=Color3.fromRGB(55,55,75)
        onSteal(function()
            aBtn.Text="⚡ Auto Steal" aBtnF.BackgroundColor3=(btnColor or PURPLE)
        end)
    end)

    return row
end

-- ════════════════════════════════════════════════════════
-- MAIN WINDOW
-- ════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name="StealUI" gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling gui.DisplayOrder=999

local win = Instance.new("Frame")
win.Size=UDim2.new(0,W,0,H) win.Position=UDim2.new(0.5,-W/2,0.5,-H/2)
win.BackgroundColor3=DPURPLE win.BorderSizePixel=0 win.ClipsDescendants=true win.Parent=gui
mkCorner(win,14) mkStroke(win,ACCENT,2)

-- Title
local tb=Instance.new("Frame")
tb.Size=UDim2.new(1,0,0,50) tb.BackgroundColor3=Color3.fromRGB(75,14,138) tb.BorderSizePixel=0 tb.Parent=win mkCorner(tb,14)
local tbFix=Instance.new("Frame") tbFix.Size=UDim2.new(1,0,0,14) tbFix.Position=UDim2.new(0,0,1,-14)
tbFix.BackgroundColor3=Color3.fromRGB(75,14,138) tbFix.BorderSizePixel=0 tbFix.Parent=tb

local titleLbl=Instance.new("TextLabel")
titleLbl.Size=UDim2.new(1,-54,1,0) titleLbl.Position=UDim2.new(0,14,0,0) titleLbl.BackgroundTransparency=1
titleLbl.Text="🎪 Auto Steal" titleLbl.TextColor3=Color3.fromRGB(255,255,255)
titleLbl.TextSize=21 titleLbl.Font=Enum.Font.GothamBold titleLbl.TextXAlignment=Enum.TextXAlignment.Left titleLbl.Parent=tb

local closeBtn=Instance.new("TextButton")
closeBtn.Size=UDim2.new(0,32,0,32) closeBtn.Position=UDim2.new(1,-44,0.5,-16)
closeBtn.BackgroundColor3=RED closeBtn.Text="✕" closeBtn.TextColor3=Color3.fromRGB(255,255,255)
closeBtn.TextSize=16 closeBtn.Font=Enum.Font.GothamBold closeBtn.BorderSizePixel=0 closeBtn.Parent=tb mkCorner(closeBtn,8)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Drag
local dragging,ds,sp=false,nil,nil
tb.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true ds=i.Position sp=win.Position end end)
tb.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
game:GetService("UserInputService").InputChanged:Connect(function(i)
    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-ds win.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)

-- Status bar
local statusBar=Instance.new("Frame")
statusBar.Size=UDim2.new(1,-16,0,30) statusBar.Position=UDim2.new(0,8,0,56)
statusBar.BackgroundColor3=MPURPLE statusBar.BorderSizePixel=0 statusBar.Parent=win mkCorner(statusBar,7)
local statusLbl=Instance.new("TextLabel")
statusLbl.Size=UDim2.new(1,-10,1,0) statusLbl.Position=UDim2.new(0,8,0,0) statusLbl.BackgroundTransparency=1
statusLbl.Text="Pick a mode below" statusLbl.TextColor3=Color3.fromRGB(190,160,255) statusLbl.TextSize=12
statusLbl.Font=Enum.Font.Gotham statusLbl.TextXAlignment=Enum.TextXAlignment.Left
statusLbl.TextTruncate=Enum.TextTruncate.AtEnd statusLbl.Parent=statusBar

-- ── Tab bar ──────────────────────────────────────────────
local tabBarH = 42
local tabBar=Instance.new("Frame")
tabBar.Size=UDim2.new(1,-16,0,tabBarH) tabBar.Position=UDim2.new(0,8,0,92)
tabBar.BackgroundColor3=MPURPLE tabBar.BorderSizePixel=0 tabBar.Parent=win mkCorner(tabBar,10)
mkPad(tabBar,5,5,5,5)
local tabHList=mkHList(tabBar,5)
tabHList.VerticalAlignment=Enum.VerticalAlignment.Center

local tabBtnW = math.floor((W-16-10-10)/3)

-- Content area
local contentY = 140
local contentH = H - contentY - 8

local content=Instance.new("Frame")
content.Size=UDim2.new(1,-16,0,contentH) content.Position=UDim2.new(0,8,0,contentY)
content.BackgroundTransparency=1 content.BorderSizePixel=0 content.Parent=win

-- Tab pages
local tabPages = {}
for _, key in ipairs({"manual","best","rebirth"}) do
    local p=Instance.new("Frame") p.Size=UDim2.new(1,0,1,0) p.BackgroundTransparency=1
    p.BorderSizePixel=0 p.Visible=false p.Parent=content tabPages[key]=p
end

local tabs = {}
local activeTab = nil

-- Forward declarations
local buildPlayerList, buildBestList, buildRebirthList

local function switchTab(key)
    activeTab = key
    for k, page in pairs(tabPages) do page.Visible=(k==key) end
    for k, btn in pairs(tabs) do
        btn.BackgroundColor3 = k==key and PURPLE or Color3.fromRGB(32,18,54)
        btn.TextColor3       = k==key and Color3.fromRGB(255,255,255) or SUBTEXT
    end
    if     key=="manual"  and buildPlayerList  then buildPlayerList()
    elseif key=="best"    and buildBestList     then buildBestList()
    elseif key=="rebirth" and buildRebirthList  then buildRebirthList()
    end
end

local tabDefs = {
    {key="manual",  label="🎯 Manual"},
    {key="best",    label="💰 Best Value"},
    {key="rebirth", label="🔄 Rebirth"},
}
for _, td in ipairs(tabDefs) do
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(0,tabBtnW,0,32) btn.BackgroundColor3=Color3.fromRGB(32,18,54)
    btn.Text=td.label btn.TextColor3=SUBTEXT btn.TextSize=13 btn.Font=Enum.Font.GothamBold
    btn.BorderSizePixel=0 btn.Parent=tabBar mkCorner(btn,8)
    tabs[td.key]=btn
    btn.MouseButton1Click:Connect(function() switchTab(td.key) end)
end

-- ════════════════════════════════════════════════════════
-- MANUAL MODE
-- ════════════════════════════════════════════════════════
local manPage     = tabPages["manual"]
local currentPlot = nil

-- Player section
local playerLbl  = mkSectionHeader(manPage, 0, "PLAYERS", "↺ Refresh", function() if buildPlayerList then buildPlayerList() end end)
local pScroll    = mkScroll(manPage, UDim2.new(1,0,0,155), UDim2.new(0,0,0,26))
local pLayout    = mkVList(pScroll, 4) mkPad(pScroll,5,5,6,6)

-- Divider
local mDiv=Instance.new("Frame") mDiv.Size=UDim2.new(1,0,0,1) mDiv.Position=UDim2.new(0,0,0,187)
mDiv.BackgroundColor3=ACCENT mDiv.BorderSizePixel=0 mDiv.Parent=manPage

-- Brainrot section
local brainrotLbl = mkSectionHeader(manPage, 192, "BRAINROTS IN BASE", nil, nil)
local bScrollH    = contentH - 192 - 26 - 4
local bScroll     = mkScroll(manPage, UDim2.new(1,0,0,bScrollH), UDim2.new(0,0,0,218))
local bLayout     = mkVList(bScroll, 4) mkPad(bScroll,5,5,6,6)

local function buildBrainrotList(plotData)
    clearScroll(bScroll)
    brainrotLbl.Text = "BRAINROTS — "..plotData.player.Name
    if #plotData.animals == 0 then
        local e=Instance.new("TextLabel") e.Size=UDim2.new(1,0,0,36) e.BackgroundTransparency=1
        e.Text="No stealable brainrots" e.TextColor3=SUBTEXT e.TextSize=12 e.Font=Enum.Font.Gotham e.Parent=bScroll
        autoCanvas(bScroll,bLayout) return
    end
    for _, animal in ipairs(plotData.animals) do
        mkBrainrotRow(bScroll, animal, nil, PURPLE, function(done)
            local ch=Synchronizer:Get(plotData.uid)
            if not ch then statusLbl.Text="❌ Lost channel" done() return end
            local fresh=(ch:Get("AnimalList") or {})[animal.slot]
            if not fresh or type(fresh)~="table" or fresh.Steal then
                statusLbl.Text="❌ No longer available" done() return
            end
            task.spawn(function()
                doSteal(plotData, animal, function(m) statusLbl.Text=m end)
                done()
            end)
        end)
    end
    autoCanvas(bScroll,bLayout)
end

buildPlayerList = function()
    clearScroll(pScroll)
    local plots = getOtherPlots()
    playerLbl.Text = "PLAYERS  ("..#plots.." with brainrots)"
    if #plots == 0 then
        local e=Instance.new("TextLabel") e.Size=UDim2.new(1,0,0,36) e.BackgroundTransparency=1
        e.Text="No other players with stealable brainrots" e.TextColor3=SUBTEXT e.TextSize=12 e.Font=Enum.Font.Gotham e.Parent=pScroll
        if currentPlot then currentPlot=nil clearScroll(bScroll) brainrotLbl.Text="BRAINROTS IN BASE" end
        autoCanvas(pScroll,pLayout) return
    end
    local updated=nil
    for _, pd in ipairs(plots) do
        if currentPlot and pd.uid==currentPlot.uid then updated=pd end
        local row=Instance.new("TextButton")
        row.Size=UDim2.new(1,0,0,42) row.BackgroundColor3=MPURPLE row.BorderSizePixel=0
        row.AutoButtonColor=false row.Text="" row.Parent=pScroll mkCorner(row,8)

        local ico=Instance.new("TextLabel") ico.Size=UDim2.new(0,30,1,0) ico.BackgroundTransparency=1
        ico.Text="👤" ico.TextSize=18 ico.Font=Enum.Font.Gotham ico.TextXAlignment=Enum.TextXAlignment.Center ico.Parent=row

        local nm=Instance.new("TextLabel") nm.Size=UDim2.new(1,-110,1,0) nm.Position=UDim2.new(0,34,0,0)
        nm.BackgroundTransparency=1 nm.Text=pd.player.Name nm.TextColor3=TEXT nm.TextSize=14
        nm.Font=Enum.Font.GothamBold nm.TextXAlignment=Enum.TextXAlignment.Left nm.Parent=row

        local cnt=Instance.new("TextLabel") cnt.Size=UDim2.new(0,72,1,0) cnt.Position=UDim2.new(1,-74,0,0)
        cnt.BackgroundTransparency=1 cnt.Text=tostring(#pd.animals).." 🎪" cnt.TextColor3=Color3.fromRGB(160,120,255)
        cnt.TextSize=13 cnt.Font=Enum.Font.Gotham cnt.TextXAlignment=Enum.TextXAlignment.Right cnt.Parent=row

        row.MouseEnter:Connect(function() row.BackgroundColor3=LPURPLE end)
        row.MouseLeave:Connect(function() row.BackgroundColor3=MPURPLE end)
        row.MouseButton1Click:Connect(function()
            currentPlot=pd statusLbl.Text="Viewing "..pd.player.Name.."'s brainrots"
            buildBrainrotList(pd)
        end)
    end
    if updated then
        currentPlot=updated buildBrainrotList(updated)
    elseif currentPlot then
        currentPlot=nil clearScroll(bScroll) brainrotLbl.Text="BRAINROTS IN BASE"
        statusLbl.Text="Player left or ran out of brainrots"
    end
    autoCanvas(pScroll,pLayout)
end

-- ════════════════════════════════════════════════════════
-- BEST VALUE MODE
-- ════════════════════════════════════════════════════════
local bestPage = tabPages["best"]
local sortMode = "gen" -- "gen" | "sell"

-- Controls bar
local ctrlBar=Instance.new("Frame")
ctrlBar.Size=UDim2.new(1,0,0,40) ctrlBar.BackgroundColor3=MPURPLE ctrlBar.BorderSizePixel=0 ctrlBar.Parent=bestPage mkCorner(ctrlBar,8)

local function mkCtrlBtn(text, xOff, w, col)
    local f=Instance.new("Frame") f.Size=UDim2.new(0,w,0,30) f.Position=UDim2.new(0,xOff,0.5,-15)
    f.BackgroundColor3=col or LPURPLE f.BorderSizePixel=0 f.Parent=ctrlBar mkCorner(f,7)
    local b=Instance.new("TextButton") b.Size=UDim2.new(1,0,1,0) b.BackgroundTransparency=1
    b.Text=text b.TextColor3=Color3.fromRGB(255,255,255) b.TextSize=12 b.Font=Enum.Font.GothamBold
    b.BorderSizePixel=0 b.Parent=f return b, f
end

local ctrlLbl=Instance.new("TextLabel") ctrlLbl.Size=UDim2.new(0,65,1,0) ctrlLbl.Position=UDim2.new(0,10,0,0)
ctrlLbl.BackgroundTransparency=1 ctrlLbl.Text="Sort by:" ctrlLbl.TextColor3=SUBTEXT
ctrlLbl.TextSize=12 ctrlLbl.Font=Enum.Font.GothamBold ctrlLbl.TextXAlignment=Enum.TextXAlignment.Left ctrlLbl.Parent=ctrlBar

local sortGenBtn,  sortGenF  = mkCtrlBtn("💰 Gen/s",      76,  110, PURPLE)
local sortSellBtn, sortSellF = mkCtrlBtn("🏷️ Sell Value", 192, 110, LPURPLE)
local stealBestBtn,stealBestF= mkCtrlBtn("🏆 Steal Best", 316, 120, Color3.fromRGB(180,90,10))

local function updateSortBtns()
    sortGenF.BackgroundColor3  = sortMode=="gen"  and PURPLE or LPURPLE
    sortSellF.BackgroundColor3 = sortMode=="sell" and PURPLE or LPURPLE
end

-- Best list
local bestLbl = mkSectionHeader(bestPage, 48, "ALL STEALABLE BRAINROTS", "↺ Refresh", function() if buildBestList then buildBestList() end end)
local bestScrollH = contentH - 48 - 26 - 4
local bestScroll  = mkScroll(bestPage, UDim2.new(1,0,0,bestScrollH), UDim2.new(0,0,0,74))
local bestLayout  = mkVList(bestScroll, 4) mkPad(bestScroll,5,5,6,6)

buildBestList = function()
    clearScroll(bestScroll)
    local plots = getOtherPlots()
    local all   = {}
    for _, pd in ipairs(plots) do
        for _, a in ipairs(pd.animals) do
            table.insert(all, {animal=a, plotData=pd})
        end
    end
    table.sort(all, function(a,b)
        if sortMode=="gen" then return a.animal.genRate > b.animal.genRate
        else                    return a.animal.sellVal  > b.animal.sellVal end
    end)
    bestLbl.Text = "ALL STEALABLE BRAINROTS — "..#all.." found"
    if #all == 0 then
        local e=Instance.new("TextLabel") e.Size=UDim2.new(1,0,0,36) e.BackgroundTransparency=1
        e.Text="No stealable brainrots in any base" e.TextColor3=SUBTEXT e.TextSize=12 e.Font=Enum.Font.Gotham e.Parent=bestScroll
        autoCanvas(bestScroll,bestLayout) return
    end
    for rank, entry in ipairs(all) do
        local animal, pd = entry.animal, entry.plotData
        local val = sortMode=="gen" and (fmt(animal.genRate).."/s") or fmt(animal.sellVal)

        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,0,0,56) row.BackgroundColor3=MPURPLE row.BorderSizePixel=0 row.Parent=bestScroll mkCorner(row,8)

        -- Rank badge
        local rankCol = rank==1 and GOLD or rank==2 and Color3.fromRGB(192,192,192) or rank==3 and Color3.fromRGB(200,120,40) or SUBTEXT
        local rLbl=Instance.new("TextLabel") rLbl.Size=UDim2.new(0,36,1,0) rLbl.BackgroundTransparency=1
        rLbl.Text="#"..rank rLbl.TextColor3=rankCol rLbl.TextSize=14 rLbl.Font=Enum.Font.GothamBold
        rLbl.TextXAlignment=Enum.TextXAlignment.Center rLbl.Parent=row

        local nLbl=Instance.new("TextLabel") nLbl.Size=UDim2.new(1,-186,0,26) nLbl.Position=UDim2.new(0,40,0,4)
        nLbl.BackgroundTransparency=1 nLbl.Text=animal.name nLbl.TextColor3=TEXT nLbl.TextSize=13
        nLbl.Font=Enum.Font.GothamBold nLbl.TextXAlignment=Enum.TextXAlignment.Left
        nLbl.TextTruncate=Enum.TextTruncate.AtEnd nLbl.Parent=row

        local infoLbl=Instance.new("TextLabel") infoLbl.Size=UDim2.new(1,-186,0,18) infoLbl.Position=UDim2.new(0,40,0,30)
        infoLbl.BackgroundTransparency=1 infoLbl.TextColor3=GREEN infoLbl.TextSize=11
        infoLbl.Text="👤 "..pd.player.Name.."  💰 "..val.."  Slot "..tostring(animal.slot)
        infoLbl.Font=Enum.Font.Gotham infoLbl.TextXAlignment=Enum.TextXAlignment.Left infoLbl.Parent=row

        local aBtnF=Instance.new("Frame") aBtnF.Size=UDim2.new(0,108,0,38) aBtnF.Position=UDim2.new(1,-114,0.5,-19)
        aBtnF.BackgroundColor3=rank==1 and Color3.fromRGB(160,100,10) or PURPLE aBtnF.BorderSizePixel=0 aBtnF.Parent=row mkCorner(aBtnF,7)
        local aBtn=Instance.new("TextButton") aBtn.Size=UDim2.new(1,0,1,0) aBtn.BackgroundTransparency=1
        aBtn.Text=rank==1 and "🏆 Steal #1" or "⚡ Steal" aBtn.TextColor3=Color3.fromRGB(255,255,255)
        aBtn.TextSize=12 aBtn.Font=Enum.Font.GothamBold aBtn.BorderSizePixel=0 aBtn.Parent=aBtnF

        row.MouseEnter:Connect(function() row.BackgroundColor3=LPURPLE end)
        row.MouseLeave:Connect(function() row.BackgroundColor3=MPURPLE end)
        aBtn.MouseButton1Click:Connect(function()
            if isStealing then statusLbl.Text="⚠️ Already stealing!" return end
            aBtn.Text="..." aBtnF.BackgroundColor3=Color3.fromRGB(55,55,75)
            task.spawn(function()
                doSteal(pd, animal, function(m) statusLbl.Text=m end)
                task.wait(0.5) buildBestList()
                aBtn.Text="⚡ Steal" aBtnF.BackgroundColor3=PURPLE
            end)
        end)
    end
    autoCanvas(bestScroll,bestLayout)
end

sortGenBtn.MouseButton1Click:Connect(function()  sortMode="gen"  updateSortBtns() buildBestList() end)
sortSellBtn.MouseButton1Click:Connect(function() sortMode="sell" updateSortBtns() buildBestList() end)
stealBestBtn.MouseButton1Click:Connect(function()
    if isStealing then statusLbl.Text="⚠️ Already stealing!" return end
    local plots=getOtherPlots()
    local best, bestVal = nil, -1
    for _, pd in ipairs(plots) do
        for _, a in ipairs(pd.animals) do
            local v = sortMode=="gen" and a.genRate or a.sellVal
            if v>bestVal then bestVal=v best={pd=pd,animal=a} end
        end
    end
    if not best then statusLbl.Text="❌ No brainrots found anywhere" return end
    statusLbl.Text="🏆 Stealing best: "..best.animal.name
    task.spawn(function()
        doSteal(best.pd, best.animal, function(m) statusLbl.Text=m end)
        task.wait(0.5) buildBestList()
    end)
end)

-- ════════════════════════════════════════════════════════
-- REBIRTH MODE
-- ════════════════════════════════════════════════════════
local rbPage = tabPages["rebirth"]
local rebirthTarget = nil

-- Info card
local infoCard=Instance.new("Frame")
infoCard.Size=UDim2.new(1,0,0,90) infoCard.BackgroundColor3=MPURPLE infoCard.BorderSizePixel=0 infoCard.Parent=rbPage mkCorner(infoCard,10)
mkStroke(infoCard, Color3.fromRGB(255,200,60), 1)

local rbHeaderLbl=Instance.new("TextLabel")
rbHeaderLbl.Size=UDim2.new(1,-16,0,20) rbHeaderLbl.Position=UDim2.new(0,10,0,8) rbHeaderLbl.BackgroundTransparency=1
rbHeaderLbl.Text="🔄 REBIRTH REQUIREMENT" rbHeaderLbl.TextColor3=Color3.fromRGB(255,200,60)
rbHeaderLbl.TextSize=11 rbHeaderLbl.Font=Enum.Font.GothamBold rbHeaderLbl.TextXAlignment=Enum.TextXAlignment.Left rbHeaderLbl.Parent=infoCard

local rbAnimalLbl=Instance.new("TextLabel")
rbAnimalLbl.Size=UDim2.new(1,-130,0,30) rbAnimalLbl.Position=UDim2.new(0,10,0,28) rbAnimalLbl.BackgroundTransparency=1
rbAnimalLbl.Text="Not detected" rbAnimalLbl.TextColor3=GOLD rbAnimalLbl.TextSize=17
rbAnimalLbl.Font=Enum.Font.GothamBold rbAnimalLbl.TextXAlignment=Enum.TextXAlignment.Left
rbAnimalLbl.TextTruncate=Enum.TextTruncate.AtEnd rbAnimalLbl.Parent=infoCard

local detectBtn=Instance.new("TextButton")
detectBtn.Size=UDim2.new(0,108,0,28) detectBtn.Position=UDim2.new(1,-116,0,28)
detectBtn.BackgroundColor3=Color3.fromRGB(55,30,100) detectBtn.Text="🔍 Auto Detect"
detectBtn.TextColor3=Color3.fromRGB(200,170,255) detectBtn.TextSize=12 detectBtn.Font=Enum.Font.GothamBold
detectBtn.BorderSizePixel=0 detectBtn.Parent=infoCard mkCorner(detectBtn,7)

local rbSubLbl=Instance.new("TextLabel")
rbSubLbl.Size=UDim2.new(1,-16,0,18) rbSubLbl.Position=UDim2.new(0,10,0,66) rbSubLbl.BackgroundTransparency=1
rbSubLbl.Text="Click Auto Detect or type name below" rbSubLbl.TextColor3=SUBTEXT
rbSubLbl.TextSize=11 rbSubLbl.Font=Enum.Font.Gotham rbSubLbl.TextXAlignment=Enum.TextXAlignment.Left rbSubLbl.Parent=infoCard

-- Search bar
local searchBar=Instance.new("Frame")
searchBar.Size=UDim2.new(1,0,0,40) searchBar.Position=UDim2.new(0,0,0,97)
searchBar.BackgroundColor3=MPURPLE searchBar.BorderSizePixel=0 searchBar.Parent=rbPage mkCorner(searchBar,8)
mkPad(searchBar,6,6,8,8)

local inputBox=Instance.new("TextBox")
inputBox.Size=UDim2.new(1,-96,0,28) inputBox.BackgroundColor3=LPURPLE inputBox.BorderSizePixel=0
inputBox.Text="" inputBox.PlaceholderText="Type brainrot name to search..."
inputBox.TextColor3=TEXT inputBox.PlaceholderColor3=SUBTEXT
inputBox.TextSize=12 inputBox.Font=Enum.Font.Gotham inputBox.ClearTextOnFocus=false
inputBox.MultiLine=false inputBox.Parent=searchBar mkCorner(inputBox,7) mkPad(inputBox,0,0,8,8)

local searchBtn2=Instance.new("TextButton")
searchBtn2.Size=UDim2.new(0,82,0,28) searchBtn2.Position=UDim2.new(1,-84,0.5,-14)
searchBtn2.BackgroundColor3=PURPLE searchBtn2.Text="🔍 Search"
searchBtn2.TextColor3=Color3.fromRGB(255,255,255) searchBtn2.TextSize=12
searchBtn2.Font=Enum.Font.GothamBold searchBtn2.BorderSizePixel=0 searchBtn2.Parent=searchBar mkCorner(searchBtn2,7)

-- Rebirth results
local rbFoundLbl  = mkSectionHeader(rbPage, 145, "SEARCHING...", "↺ Refresh", function() if buildRebirthList then buildRebirthList() end end)
local rbScrollH   = contentH - 145 - 26 - 4
local rbScroll    = mkScroll(rbPage, UDim2.new(1,0,0,rbScrollH), UDim2.new(0,0,0,171))
local rbLayout    = mkVList(rbScroll, 4) mkPad(rbScroll,5,5,6,6)

local function searchForAnimal(targetName)
    clearScroll(rbScroll)
    if not targetName or #targetName==0 then rbFoundLbl.Text="Enter a brainrot name above" return end
    rebirthTarget=targetName
    local lower=targetName:lower()
    local plots=getOtherPlots()
    local found={}
    for _, pd in ipairs(plots) do
        for _, a in ipairs(pd.animals) do
            if a.name:lower():find(lower,1,true) then
                table.insert(found, {animal=a, plotData=pd})
            end
        end
    end
    -- Sort found by gen rate descending
    table.sort(found, function(a,b) return a.animal.genRate > b.animal.genRate end)
    rbFoundLbl.Text="\""..targetName.."\" — "..(#found>0 and (#found.." found ✅") or "not found ❌")
    if #found==0 then
        local e=Instance.new("TextLabel") e.Size=UDim2.new(1,0,0,56) e.BackgroundTransparency=1
        e.Text="❌ Not found in any player's base right now.\nWait for someone to get it or check another server."
        e.TextColor3=Color3.fromRGB(230,90,90) e.TextSize=12 e.Font=Enum.Font.Gotham
        e.TextWrapped=true e.Parent=rbScroll autoCanvas(rbScroll,rbLayout) return
    end
    for _, entry in ipairs(found) do
        local animal, pd = entry.animal, entry.plotData
        mkBrainrotRow(rbScroll, animal, pd, Color3.fromRGB(20,140,60), function(done)
            local ch=Synchronizer:Get(pd.uid)
            if not ch then statusLbl.Text="❌ Lost channel" done() return end
            local fresh=(ch:Get("AnimalList") or {})[animal.slot]
            if not fresh or type(fresh)~="table" or fresh.Steal then
                statusLbl.Text="❌ No longer available" done() return
            end
            task.spawn(function()
                doSteal(pd, animal, function(m) statusLbl.Text=m end)
                done() task.wait(0.5) searchForAnimal(rebirthTarget)
            end)
        end)
    end
    autoCanvas(rbScroll,rbLayout)
end

buildRebirthList = function()
    if rebirthTarget then searchForAnimal(rebirthTarget) end
end

detectBtn.MouseButton1Click:Connect(function()
    rbAnimalLbl.Text="Detecting..." rbSubLbl.Text="Scanning player data..."
    task.spawn(function()
        local req=getRebirthRequirement()
        if req then
            rbAnimalLbl.Text=req rbSubLbl.Text="✅ Auto-detected!"
            inputBox.Text=req searchForAnimal(req)
        else
            rbAnimalLbl.Text="Not detected" rbSubLbl.Text="⚠️ Type name below and hit Search"
        end
    end)
end)

local function doSearch()
    local name=inputBox.Text:match("^%s*(.-)%s*$")
    if #name>0 then rbAnimalLbl.Text=name searchForAnimal(name) end
end
searchBtn2.MouseButton1Click:Connect(doSearch)
inputBox.FocusLost:Connect(function(enter) if enter then doSearch() end end)

-- ════════════════════════════════════════════════════════
-- AUTO-UPDATE SYSTEM
-- ════════════════════════════════════════════════════════
local rebuildQueued = false
local function scheduleRebuild()
    if rebuildQueued then return end
    rebuildQueued=true
    task.delay(0.4, function()
        rebuildQueued=false
        if not gui.Parent then return end
        if     activeTab=="manual"  then buildPlayerList()
        elseif activeTab=="best"    then buildBestList()
        elseif activeTab=="rebirth" then buildRebirthList()
        end
    end)
end

local plotListeners = {}
local function watchPlot(plot)
    local uid=plot.Name
    if plotListeners[uid] then return end
    task.spawn(function()
        local ch, n = nil, 0
        while not ch and n<20 do ch=Synchronizer:Get(uid) if not ch then task.wait(0.5) end n+=1 end
        if not ch then return end
        local function tryDc(c)
            if typeof(c)=="function" then c() elseif c and c.Disconnect then c:Disconnect() end
        end
        local c1=ch:OnChanged("AnimalList", scheduleRebuild)
        local c2=ch:OnChanged("Owner",      scheduleRebuild)
        plotListeners[uid]=function() tryDc(c1) tryDc(c2) end
    end)
end
local function unwatchPlot(plot)
    local uid=plot.Name
    if plotListeners[uid] then plotListeners[uid]() plotListeners[uid]=nil end
end

for _, plot in ipairs(CollectionService:GetTagged("Plot")) do watchPlot(plot) end
CollectionService:GetInstanceAddedSignal("Plot"):Connect(function(p)   watchPlot(p)   scheduleRebuild() end)
CollectionService:GetInstanceRemovedSignal("Plot"):Connect(function(p) unwatchPlot(p) scheduleRebuild() end)

Players.PlayerAdded:Connect(scheduleRebuild)
Players.PlayerRemoving:Connect(function(player)
    if currentPlot and currentPlot.player==player then
        currentPlot=nil clearScroll(bScroll) brainrotLbl.Text="BRAINROTS IN BASE"
        statusLbl.Text=player.Name.." left"
    end
    scheduleRebuild()
end)
gui.Destroying:Connect(function()
    for uid, dc in pairs(plotListeners) do dc() plotListeners[uid]=nil end
end)

-- Boot
switchTab("manual")
gui.Parent=PlayerGui
print("✅ Auto Steal v3 loaded!")
