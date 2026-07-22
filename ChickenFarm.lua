local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Headphones Hub",
   Icon = 0, -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
   LoadingTitle = "Headphones Hub",
   LoadingSubtitle = "by .headph0nes",
   ShowText = "Rayfield", -- for mobile users to unhide Rayfield, change if you'd like
   Theme = "Amethyst", -- Check https://docs.sirius.menu/rayfield/configuration/themes

   ToggleUIKeybind = Enum.KeyCode.Insert, -- The keybind to toggle the UI visibility (string like "K" or Enum.KeyCode)

   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false, -- Prevents Rayfield from emitting warnings when the script has a version mismatch with the interface.

   -- ScriptID = "sid_xxxxxxxxxxxx", -- Your Script ID from developer.sirius.menu — enables analytics, managed keys, and script hosting

   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil, -- Create a custom folder for your hub/game
      FileName = "Headphones Hub"
   },

   Discord = {
      Enabled = false, -- Prompt the user to join your Discord server if their executor supports it
      Invite = "noinvitelink", -- The Discord invite code, do not include Discord.gg/. E.g. Discord.gg/ABCD would be ABCD
      RememberJoins = true -- Set this to false to make them join the Discord every time they load it up
   },

   KeySystem = false, -- Set this to true to use our key system
   KeySettings = {
      Title = "Untitled",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided", -- Use this to tell the user how to get a key
      FileName = "Key", -- It is recommended to use something unique, as other scripts using Rayfield may overwrite your key file
      SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
      GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
      Key = {"Hello"} -- List of keys that the system will accept, can be RAW file links (pastebin, github, etc.) or simple strings ("hello", "key22")
   }
})

local MainTab = Window:CreateTab("Farming", nil) -- Title, Image
local MainSection = MainTab:CreateSection("Main")
Rayfield:Notify({
   Title = "Headphones hub",
   Content = "Headphones hub injected!",
   Duration = 6.5,
   Image = nil,
   
})


local AutoPickup = false

local Toggle = MainTab:CreateToggle({
    Name = "Auto Pickup",
    CurrentValue = false,
    Flag = "AutoPickup",
    Callback = function(Value)
        AutoPickup = Value

        if AutoPickup then
            task.spawn(function()
                while AutoPickup do
                    local player = game:GetService("Players").LocalPlayer
                    local character = player.Character or player.CharacterAdded:Wait()
                    local hrp = character:WaitForChild("HumanoidRootPart")

                    local eggs = workspace:FindFirstChild("Eggs")
                    if eggs then
                        for _, egg in ipairs(eggs:GetChildren()) do
                            if egg:IsA("Model") then
                                local hitbox = egg:FindFirstChild("Part", true)

                                if hitbox and hitbox:IsA("BasePart") then
                                    firetouchinterest(hrp, hitbox, 0)
                                    task.wait()
                                    firetouchinterest(hrp, hitbox, 1)
                                end
                            end
                        end
                    end

                    task.wait(5)
                end
            end)
        end
    end,
})

local AutoDeposit = false

local Toggle = MainTab:CreateToggle({
    Name = "Auto Deposit",
    CurrentValue = false,
    Flag = "AutoDeposit",
    Callback = function(Value)
        AutoDeposit = Value

        if AutoDeposit then
            task.spawn(function()
                while AutoDeposit do
                
                     local Event = game:GetService("ReplicatedStorage").Paper.Remotes.__remotefunction
                     local Result = table.pack(Event:InvokeServer(
                       "Deposit Eggs"
                    ))

                     local ExpectedResult = table.unpack({
                        false
                    })


                    task.wait(10)
                end
            end)
        end
    end,
})
local AutoCollectCash = false

local Toggle = MainTab:CreateToggle({
    Name = "Auto Collect Cash",
    CurrentValue = false,
    Flag = "AutoCollectCash",
    Callback = function(Value)
        AutoCollectCash = Value

        if AutoCollectCash then
            task.spawn(function()
                while AutoCollectCash do

                 local Event = game:GetService("ReplicatedStorage").Paper.Remotes.__remotefunction
                 local Result = table.pack(Event:InvokeServer(
                    "Collect Cash"
                 ))

                 local ExpectedResult = table.unpack({
                    false
                 })
                    task.wait(5)
                end
            end)
        end
    end,
})
local AutoBuyChickens = false

local Toggle = MainTab:CreateToggle({
    Name = "Auto Buy Chickens (x100)",
    CurrentValue = false,
    Flag = "AutoBuyChickens",
    Callback = function(Value)
        AutoBuyChickens = Value

        if AutoBuyChickens then
            task.spawn(function()
                while AutoBuyChickens do
                 local Event = game:GetService("ReplicatedStorage").Paper.Remotes.__remotefunction
                 Event:InvokeServer(
                    "Buy Chickens",
                    100
                 )
                    task.wait(5)
                end
            end)
        end
    end,
})


