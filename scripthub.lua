local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer

local callback = Instance.new("BindableFunction")

callback.OnInvoke = function(button)
    if button == "yes daddy" then
        print("Loading Infinite Yield...")

        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
        ))()

    elseif button == "no fuck u" then
        Player:Kick("Permanent Ban\n\nYou have been removed from this experience for violating the rules.\n\nReason: Exploiting / unauthorized modifications.\n\nThis ban is permanent.")
    end
end
if game.placeId == 115797356 then
    loadstring(game:HttpGet('https://raw.githubusercontent.com/TheHeadphonesAreNeeded/MyRobloxScripts/refs/heads/main/ChickenFarm.lua'))()
else
    StarterGui:SetCore("SendNotification", {
        Title = "Game not supported",
        Text = "Press yes to do infinite yield",
        Duration = 5,
        Button1 = "yes daddy",
        Button2 = "no fuck u",
        Callback = callback
    })
end
