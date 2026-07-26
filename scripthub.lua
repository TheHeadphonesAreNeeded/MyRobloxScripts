-- ════════════════════════════════════════════════════════
--   Headphones Hub  ·  Universal Loader
--   Sell Lemons | Chicken Farm | Steal a Clown
-- ════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local StarterGui        = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player            = Players.LocalPlayer

local GAMES = {
    {
        name     = "Chicken Farm",
        placeIds = { 115797356 },
        url      = "https://raw.githubusercontent.com/TheHeadphonesAreNeeded/MyRobloxScripts/refs/heads/main/ChickenFarm.lua",
        detect   = function()
            local paper = ReplicatedStorage:FindFirstChild("Paper")
            return paper ~= nil
                and paper:FindFirstChild("Remotes") ~= nil
        end,
    },
    {
        name     = "Roba un Payaso (Steal a Clown)",
        placeIds = { 86754403332185 },
        url      = "https://raw.githubusercontent.com/TheHeadphonesAreNeeded/MyRobloxScripts/refs/heads/main/StealAclown.lua",
        detect   = function()
            local pkgs = ReplicatedStorage:FindFirstChild("Packages")
            return pkgs ~= nil
                and pkgs:FindFirstChild("Synchronizer") ~= nil
                and pkgs:FindFirstChild("Net") ~= nil
        end,
    },
    {
        name     = "Sell Lemons",
        placeIds = { 79268393072444 },
        url      = "https://raw.githubusercontent.com/TheHeadphonesAreNeeded/MyRobloxScripts/refs/heads/main/SellLemons",
        detect   = function()
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name:sub(1, 6) == "Tycoon" and obj:FindFirstChild("Owner") then
                    return true
                end
            end
            return false
        end,
    },
}

local function detectGame()
    local placeId = game.PlaceId

    for _, g in ipairs(GAMES) do
        for _, id in ipairs(g.placeIds) do
            if placeId == id then
                return g
            end
        end
    end

    for _, g in ipairs(GAMES) do
        local ok, result = pcall(g.detect)
        if ok and result then
            return g
        end
    end

    return nil
end

local matched = detectGame()

if matched then
    print("[HeadphonesHub] ✅ it worked: " .. matched.name .. " — injecting...")
    local ok, err = pcall(function()
        loadstring(game:HttpGet(matched.url))()
    end)
    if not ok then
        warn("[HeadphonesHub] ❌ scipt did bad: " .. tostring(err))
    end
else
    print("[HeadphonesHub] ⚠️ BAD GAME (PlaceId=" .. tostring(game.PlaceId) .. ")")

    local callback = Instance.new("BindableFunction")
    callback.OnInvoke = function(button)
        if button == "yes daddy" then
            print("[HeadphonesHub] Loading Infinite Yield...")
            loadstring(game:HttpGet(
                "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
            ))()
        elseif button == "no fuck u" then
            Player:Kick(
                "Permanent Ban\n\n" ..
                "You have been removed from this experience for violating the rules.\n\n" ..
                "Reason: Exploiting / unauthorized modifications.\n\n" ..
                "This ban is permanent."
            )
        end
    end

    StarterGui:SetCore("SendNotification", {
        Title    = "Game not supported",
        Text     = "Press yes to do infinite yield",
        Duration = 5,
        Button1  = "yes daddy",
        Button2  = "no fuck u",
        Callback = callback,
    })
end
