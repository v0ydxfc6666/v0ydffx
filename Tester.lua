-- Load WindUI Library
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")

-- Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Create Window
local Window = WindUI:CreateWindow({
    Title = "RullzsyHUB | Mount Yahayuk",
    Author = "by RullzsyHUB",
    Folder = "RullzsyHUB_MountYahayuk",
    
    OpenButton = {
        Title = "Open RullzsyHUB",
        CornerRadius = UDim.new(0, 8),
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Color = ColorSequence.new(
            Color3.fromRGB(200, 0, 0),
            Color3.fromRGB(255, 50, 50)
        )
    }
})

-- Tags
Window:Tag({
    Title = "v1.0",
    Icon = "github",
    Color = Color3.fromRGB(200, 0, 0)
})

-- Create Tabs
local BypassTab = Window:Tab({
    Title = "Bypass",
    Icon = "shield"
})

local ManualTab = Window:Tab({
    Title = "Auto Walk (Manual)",
    Icon = "hand"
})

local AutomaticTab = Window:Tab({
    Title = "Auto Walk (Automatic)",
    Icon = "bot"
})

local PlayerTab = Window:Tab({
    Title = "Player Menu",
    Icon = "user-cog"
})

local AnimationTab = Window:Tab({
    Title = "Run Animation",
    Icon = "person-standing"
})

local ServerTab = Window:Tab({
    Title = "Finding Server",
    Icon = "globe"
})

local UpdateTab = Window:Tab({
    Title = "Update Checkpoint",
    Icon = "file"
})

--| =========================================================== |--
--| BYPASS SECTION                                              |--
--| =========================================================== |--

getgenv().AntiIdleActive = false
local AntiIdleConnection
local MovementLoop

local function StartAntiIdle()
    if AntiIdleConnection then
        AntiIdleConnection:Disconnect()
        AntiIdleConnection = nil
    end
    if MovementLoop then
        MovementLoop:Disconnect()
        MovementLoop = nil
    end
    AntiIdleConnection = LocalPlayer.Idled:Connect(function()
        if getgenv().AntiIdleActive then
            VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end
    end)
    MovementLoop = RunService.Heartbeat:Connect(function()
        if getgenv().AntiIdleActive and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local root = LocalPlayer.Character.HumanoidRootPart
            if tick() % 60 < 0.05 then
                root.CFrame = root.CFrame * CFrame.new(0, 0, 0.1)
                task.wait(0.1)
                root.CFrame = root.CFrame * CFrame.new(0, 0, -0.1)
            end
        end
    end)
end

local function SetupCharacterListener()
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        newChar:WaitForChild("HumanoidRootPart", 10)
        if getgenv().AntiIdleActive then
            StartAntiIdle()
        end
    end)
end

StartAntiIdle()
SetupCharacterListener()

BypassTab:Section({
    Title = "Bypass List",
})

BypassTab:Toggle({
    Title = "Bypass AFK",
    Desc = "Prevents automatic kick from AFK",
    Icon = "shield",
    Default = false,
    Callback = function(Value)
        getgenv().AntiIdleActive = Value
        if Value then
            StartAntiIdle()
            WindUI:Notify({
                Icon = "shield",
                Title = "Bypass AFK",
                Content = "Bypass AFK activated.",
                Duration = 3
            })
        else
            if AntiIdleConnection then
                AntiIdleConnection:Disconnect()
                AntiIdleConnection = nil
            end
            if MovementLoop then
                MovementLoop:Disconnect()
                MovementLoop = nil
            end
            WindUI:Notify({
                Icon = "shield",
                Title = "Bypass AFK",
                Content = "Bypass AFK deactivated.",
                Duration = 3
            })
        end
    end,
})

--| =========================================================== |--
--| AUTO WALK - MANUAL SECTION                                  |--
--| =========================================================== |--

-- Folder Path
local mainFolder = "ASTRIONHUB"
local jsonFolder = mainFolder .. "/CIELO_manual"
if not isfolder(mainFolder) then makefolder(mainFolder) end
if not isfolder(jsonFolder) then makefolder(jsonFolder) end

-- JSON Files
local baseURL = "https://raw.githubusercontent.com/v0ydxfc6666/v0ydffx/refs/heads/main/CFRAME/ALLDATAMAPS/MANUAL/MT_CIELO/"
local manualJsonFiles = {
    "spawnpoint.json",
    "Checkpoint_1.json",
    "Checkpoint_2.json",
    "Checkpoint_3.json",
    "Checkpoint_4.json",
    "Checkpoint_5.json",
    "Checkpoint_6.json",
    "Checkpoint_7.json",
    "Checkpoint_8.json",
}

-- Variables
local isPlaying = false
local playbackConnection = nil
local playbackSpeed = 1.0
local heightOffset = 0
local isLoopingEnabled = false
local isPaused = false
local lastPlaybackTime = 0
local accumulatedTime = 0
local isFlipped = false
local currentFlipRotation = CFrame.new()
local FLIP_SMOOTHNESS = 0.05

-- Helper Functions
local function vecToTable(v3)
    return {x = v3.X, y = v3.Y, z = v3.Z}
end

local function tableToVec(t)
    return Vector3.new(t.x, t.y, t.z)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpVector(a, b, t)
    return Vector3.new(lerp(a.X, b.X, t), lerp(a.Y, b.Y, t), lerp(a.Z, b.Z, t))
end

local function lerpAngle(a, b, t)
    local diff = (b - a)
    while diff > math.pi do diff = diff - 2*math.pi end
    while diff < -math.pi do diff = diff + 2*math.pi end
    return a + diff * t
end

local function EnsureJsonFile(fileName)
    local savePath = jsonFolder .. "/" .. fileName
    if isfile(savePath) then return true, savePath end
    
    local ok, res = pcall(function() return game:HttpGet(baseURL..fileName) end)
    if ok and res and #res > 0 then
        writefile(savePath, res)
        return true, savePath
    end
    return false, nil
end

local function loadCheckpoint(fileName)
    local filePath = jsonFolder .. "/" .. fileName
    if not isfile(filePath) then return nil end
    
    local success, result = pcall(function()
        local jsonData = readfile(filePath)
        return HttpService:JSONDecode(jsonData)
    end)
    
    if success then return result else return nil end
end

local function findSurroundingFrames(data, t)
    if #data == 0 then return nil, nil, 0 end
    if t <= data[1].time then return 1, 1, 0 end
    if t >= data[#data].time then return #data, #data, 0 end

    local left, right = 1, #data
    while left < right - 1 do
        local mid = math.floor((left + right) / 2)
        if data[mid].time <= t then
            left = mid
        else
            right = mid
        end
    end

    local i0, i1 = left, right
    local span = data[i1].time - data[i0].time
    local alpha = span > 0 and math.clamp((t - data[i0].time) / span, 0, 1) or 0

    return i0, i1, alpha
end

local function stopPlayback()
    isPlaying = false
    isPaused = false
    accumulatedTime = 0
    lastPlaybackTime = 0
    heightOffset = 0
    isFlipped = false
    currentFlipRotation = CFrame.new()
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end

    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:Move(Vector3.new(0, 0, 0), false)
    end
end

local function startPlayback(data, onComplete)
    if not data or #data == 0 then  
        if onComplete then onComplete() end
        return
    end

    if isPlaying then stopPlayback() end

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    local hum = char:FindFirstChild("Humanoid")
    
    if data[1] then
        local firstFrame = data[1]
        local startPos = tableToVec(firstFrame.position)
        local startYaw = firstFrame.rotation or 0

        hrp.CFrame = CFrame.new(startPos) * CFrame.Angles(0, startYaw, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

        local currentHipHeight = hum.HipHeight
        local recordedHipHeight = data[1].hipHeight or 2
        heightOffset = currentHipHeight - recordedHipHeight
    end

    isPlaying = true
    isPaused = false
    local playbackStartTime = tick()
    lastPlaybackTime = playbackStartTime
    accumulatedTime = 0

    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not isPlaying then return end
        if isPaused then return end

        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then return end
        
        local hrp = char.HumanoidRootPart
        local hum = char.Humanoid

        local currentTime = tick()
        local actualDelta = math.min(currentTime - lastPlaybackTime, 0.1)
        lastPlaybackTime = currentTime
        accumulatedTime = accumulatedTime + (actualDelta * playbackSpeed)
        local totalDuration = data[#data].time

        if accumulatedTime > totalDuration then
            stopPlayback()
            if onComplete then onComplete() end
            return
        end

        local i0, i1, alpha = findSurroundingFrames(data, accumulatedTime)
        local f0, f1 = data[i0], data[i1]
        if not f0 or not f1 then return end

        local pos0, pos1 = tableToVec(f0.position), tableToVec(f1.position)
        local vel0 = f0.velocity and tableToVec(f0.velocity) or Vector3.new(0,0,0)
        local vel1 = f1.velocity and tableToVec(f1.velocity) or Vector3.new(0,0,0)
        local move0 = f0.moveDirection and tableToVec(f0.moveDirection) or Vector3.new(0,0,0)
        local move1 = f1.moveDirection and tableToVec(f1.moveDirection) or Vector3.new(0,0,0)
        local yaw0, yaw1 = f0.rotation or 0, f1.rotation or 0

        local interpPos = lerpVector(pos0, pos1, alpha)
        local interpVel = lerpVector(vel0, vel1, alpha)
        local interpMove = lerpVector(move0, move1, alpha)
        local interpYaw = lerpAngle(yaw0, yaw1, alpha)

        local correctedY = interpPos.Y + heightOffset
        local targetCFrame = CFrame.new(interpPos.X, correctedY, interpPos.Z) * CFrame.Angles(0, interpYaw, 0)
        local targetFlipRotation = isFlipped and CFrame.Angles(0, math.pi, 0) or CFrame.new()
        currentFlipRotation = currentFlipRotation:Lerp(targetFlipRotation, FLIP_SMOOTHNESS)

        local lerpFactor = math.clamp(1 - math.exp(-12 * actualDelta), 0, 1)
        hrp.CFrame = hrp.CFrame:Lerp(targetCFrame * currentFlipRotation, lerpFactor)

        pcall(function()
            hrp.AssemblyLinearVelocity = interpVel
        end)

        if hum then
            hum:Move(interpMove, false)
        end

        if (f0.jumping or f1.jumping) and hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

local function playSingleCheckpoint(fileName, checkpointName)
    stopPlayback()
    
    local ok, path = EnsureJsonFile(fileName)
    if not ok then
        WindUI:Notify({
            Title = "Error",
            Content = "Failed to load checkpoint file!",
            Duration = 4,
            Icon = "x"
        })
        return
    end
    
    local data = loadCheckpoint(fileName)
    if not data or #data == 0 then
        WindUI:Notify({
            Title = "Error",
            Content = "Checkpoint data is empty!",
            Duration = 4,
            Icon = "x"
        })
        return
    end
    
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        WindUI:Notify({
            Title = "Error",
            Content = "Character not found!",
            Duration = 4,
            Icon = "x"
        })
        return
    end
    
    local hrp = char.HumanoidRootPart
    local startPos = tableToVec(data[1].position)
    local distance = (hrp.Position - startPos).Magnitude
    
    if distance > 100 then
        WindUI:Notify({
            Title = "Auto Walk",
            Content = string.format("You're too far (%.0f studs)! Get closer to checkpoint.", distance),
            Duration = 5,
            Icon = "alert-triangle"
        })
        return
    end
    
    WindUI:Notify({
        Title = "Auto Walk",
        Content = "Starting from " .. checkpointName,
        Duration = 2,
        Icon = "play"
    })
    
    startPlayback(data, function()
        WindUI:Notify({
            Title = "Auto Walk",
            Content = "Completed!",
            Duration = 2,
            Icon = "check-check"
        })
    end)
end

-- Manual Tab UI
ManualTab:Section({
    Title = "Manual Auto Walk Settings",
})

ManualTab:Slider({
    Title = "Speed Control",
    Desc = "Adjust auto walk speed",
    Step = 0.1,
    Value = {
        Min = 0.5,
        Max = 1.5,
        Default = 1.0,
    },
    Callback = function(value)
        playbackSpeed = value
    end
})

ManualTab:Space()

ManualTab:Section({
    Title = "Manual Controls",
})

local manualToggles = {}

ManualTab:Toggle({
    Flag = "ManualSpawnpoint",
    Title = "Spawnpoint",
    Desc = "Start from spawn point",
    Icon = "map-pin",
    Default = false,
    Callback = function(Value)
        if Value then
            for flag, toggle in pairs(manualToggles) do
                if flag ~= "ManualSpawnpoint" then
                    toggle:Set(false)
                end
            end
            playSingleCheckpoint("spawnpoint.json", "Spawnpoint")
        else
            stopPlayback()
        end
    end,
})

for i = 1, 5 do
    local flag = "ManualCP" .. i
    manualToggles[flag] = ManualTab:Toggle({
        Flag = flag,
        Title = "Checkpoint " .. i,
        Desc = "Start from checkpoint " .. i,
        Icon = "map-pin",
        Default = false,
        Callback = function(Value)
            if Value then
                for f, toggle in pairs(manualToggles) do
                    if f ~= flag then
                        toggle:Set(false)
                    end
                end
                playSingleCheckpoint("Checkpoint_" .. i .. ".json", "Checkpoint " .. i)
            else
                stopPlayback()
            end
        end,
    })
end

--| =========================================================== |--
--| AUTO WALK - AUTOMATIC SECTION                               |--
--| =========================================================== |--

local autoJsonFolder = mainFolder .. "/CIELO_automatic"
if not isfolder(autoJsonFolder) then makefolder(autoJsonFolder) end

local automaticJsonURL = "https://raw.githubusercontent.com/v0ydxfc6666/v0ydffx/refs/heads/main/CFRAME/ALLDATAMAPS/YAHAYUK.json"
local automaticJsonFile = "automatic_full.json"

local autoPlaybackSpeed = 1.0
local autoIsRunning = false
local autoLoopEnabled = false
local godModeEnabled = false
local autoPlaybackConnection = nil
local autoAccumulatedTime = 0
local autoLastPlaybackTime = 0
local autoCurrentIndex = 1
local autoData = nil
local godModeConnection = nil

local function findClosestFrameIndex(data, currentPos)
    local closestIndex = 1
    local closestDistance = math.huge
    
    for i, frame in ipairs(data) do
        local framePos = tableToVec(frame.position)
        local distance = (currentPos - framePos).Magnitude
        if distance < closestDistance then
            closestDistance = distance
            closestIndex = i
        end
    end
    
    return closestIndex, closestDistance
end

local function LoadAutomaticJson()
    local savePath = autoJsonFolder .. "/" .. automaticJsonFile
    
    if isfile(savePath) then
        local success, result = pcall(function()
            local jsonData = readfile(savePath)
            return HttpService:JSONDecode(jsonData)
        end)
        if success and result then
            return result
        end
    end
    
    local ok, res = pcall(function() 
        return game:HttpGet(automaticJsonURL) 
    end)
    
    if ok and res and #res > 0 then
        writefile(savePath, res)
        local success, result = pcall(function()
            return HttpService:JSONDecode(res)
        end)
        if success then
            return result
        end
    end
    
    return nil
end

local function StartGodMode()
    if godModeConnection then
        godModeConnection:Disconnect()
    end
    
    godModeConnection = RunService.Heartbeat:Connect(function()
        if godModeEnabled and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.Health = humanoid.MaxHealth
            end
        end
    end)
end

local function StopGodMode()
    if godModeConnection then
        godModeConnection:Disconnect()
        godModeConnection = nil
    end
end

local function StopAutomaticWalk()
    autoIsRunning = false
    autoAccumulatedTime = 0
    autoCurrentIndex = 1
    
    if autoPlaybackConnection then
        autoPlaybackConnection:Disconnect()
        autoPlaybackConnection = nil
    end
    
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:Move(Vector3.new(0, 0, 0), false)
    end
end

local function StartAutomaticWalk()
    if autoIsRunning then
        WindUI:Notify({
            Title = "Automatic Auto Walk",
            Content = "Already running!",
            Duration = 2,
            Icon = "alert-triangle"
        })
        return
    end
    
    if not autoData then
        WindUI:Notify({
            Title = "Loading Data",
            Content = "Loading automatic route data...",
            Duration = 3,
            Icon = "download"
        })
        
        autoData = LoadAutomaticJson()
        
        if not autoData or #autoData == 0 then
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to load automatic route data!",
                Duration = 4,
                Icon = "x"
            })
            return
        end
    end
    
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        WindUI:Notify({
            Title = "Error",
            Content = "Character not found!",
            Duration = 3,
            Icon = "x"
        })
        return
    end
    
    local hrp = char.HumanoidRootPart
    local currentPos = hrp.Position
    
    local closestIndex, distance = findClosestFrameIndex(autoData, currentPos)
    autoCurrentIndex = closestIndex
    
    WindUI:Notify({
        Title = "Automatic Auto Walk",
        Content = string.format("Starting from frame %d (%.1f studs away)", closestIndex, distance),
        Duration = 3,
        Icon = "play"
    })
    
    autoIsRunning = true
    autoLastPlaybackTime = tick()
    autoAccumulatedTime = autoData[closestIndex].time or 0
    
    if godModeEnabled then
        StartGodMode()
    end
    
    if autoPlaybackConnection then
        autoPlaybackConnection:Disconnect()
    end
    
    autoPlaybackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not autoIsRunning then return end
        
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then
            StopAutomaticWalk()
            return
        end
        
        local hrp = char.HumanoidRootPart
        local humanoid = char.Humanoid
        
        local currentTime = tick()
        local actualDelta = math.min(currentTime - autoLastPlaybackTime, 0.1)
        autoLastPlaybackTime = currentTime
        autoAccumulatedTime = autoAccumulatedTime + (actualDelta * autoPlaybackSpeed)
        
        while autoCurrentIndex < #autoData and autoData[autoCurrentIndex + 1].time <= autoAccumulatedTime do
            autoCurrentIndex = autoCurrentIndex + 1
        end
        
        if autoCurrentIndex >= #autoData then
            if autoLoopEnabled then
                WindUI:Notify({
                    Title = "Auto Loop",
                    Content = "Restarting from beginning...",
                    Duration = 2,
                    Icon = "repeat"
                })
                autoCurrentIndex = 1
                autoAccumulatedTime = autoData[1].time or 0
            else
                StopAutomaticWalk()
                WindUI:Notify({
                    Title = "Automatic Auto Walk",
                    Content = "Route completed!",
                    Duration = 3,
                    Icon = "check-check"
                })
                return
            end
        end
        
        local frame1 = autoData[autoCurrentIndex]
        local frame2 = autoData[math.min(autoCurrentIndex + 1, #autoData)]
        
        local t1 = frame1.time
        local t2 = frame2.time
        local alpha = t2 > t1 and math.clamp((autoAccumulatedTime - t1) / (t2 - t1), 0, 1) or 0
        
        local pos1 = tableToVec(frame1.position)
        local pos2 = tableToVec(frame2.position)
        local targetPos = lerpVector(pos1, pos2, alpha)
        
        local yaw1 = frame1.rotation or 0
        local yaw2 = frame2.rotation or 0
        local targetYaw = lerpAngle(yaw1, yaw2, alpha)
        
        local targetCFrame = CFrame.new(targetPos) * CFrame.Angles(0, targetYaw, 0)
        hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, 0.5)
        
        if frame1.velocity then
            local vel1 = tableToVec(frame1.velocity)
            local vel2 = frame2.velocity and tableToVec(frame2.velocity) or vel1
            local targetVel = lerpVector(vel1, vel2, alpha)
            hrp.AssemblyLinearVelocity = targetVel
        end
        
        if frame1.moveDirection then
            local move1 = tableToVec(frame1.moveDirection)
            local move2 = frame2.moveDirection and tableToVec(frame2.moveDirection) or move1
            local targetMove = lerpVector(move1, move2, alpha)
            humanoid:Move(targetMove, false)
        end
        
        if frame1.jumping and not frame2.jumping then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

AutomaticTab:Section({
    Title = "Automatic Auto Walk Settings",
})

AutomaticTab:Slider({
    Title = "Speed",
    Desc = "Adjust automatic walk speed",
    Step = 0.1,
    Value = {
        Min = 0.5,
        Max = 2.0,
        Default = 1.0,
    },
    Callback = function(value)
        autoPlaybackSpeed = value
    end
})

AutomaticTab:Space()

AutomaticTab:Button({
    Title = "Start Auto Walk",
    Desc = "Continue from current position",
    Icon = "play",
    Color = Color3.fromRGB(0, 200, 0),
    Callback = function()
        StartAutomaticWalk()
    end
})

AutomaticTab:Space()

AutomaticTab:Button({
    Title = "Stop Auto Walk",
    Desc = "Stop automatic walking",
    Icon = "stop-circle",
    Color = Color3.fromRGB(200, 0, 0),
    Callback = function()
        if autoIsRunning then
            StopAutomaticWalk()
            StopGodMode()
            WindUI:Notify({
                Title = "Automatic Auto Walk",
                Content = "Stopped!",
                Duration = 3,
                Icon = "stop-circle"
            })
        end
    end
})

AutomaticTab:Space()

AutomaticTab:Toggle({
    Title = "Auto Loop",
    Desc = "Automatically restart from beginning when finished",
    Icon = "repeat",
    Default = false,
    Callback = function(Value)
        autoLoopEnabled = Value
        WindUI:Notify({
            Title = "Auto Loop",
            Content = Value and "Enabled" or "Disabled",
            Duration = 2,
            Icon = "repeat"
        })
    end,
})

AutomaticTab:Toggle({
    Title = "God Mode",
    Desc = "Invincibility mode during auto walk",
    Icon = "shield-check",
    Default = false,
    Callback = function(Value)
        godModeEnabled = Value
        
        if Value then
            if autoIsRunning then
                StartGodMode()
            end
            WindUI:Notify({
                Title = "God Mode",
                Content = "Activated",
                Duration = 2,
                Icon = "shield"
            })
        else
            StopGodMode()
            WindUI:Notify({
                Title = "God Mode",
                Content = "Deactivated",
                Duration = 2,
                Icon = "shield"
            })
        end
    end,
})

AutomaticTab:Space()

AutomaticTab:Section({
    Title = "Route Information",
})

local RouteInfo = AutomaticTab:Paragraph({
    Title = "Route Status",
    Desc = "Not loaded yet. Click 'Load Route Data' to check."
})

AutomaticTab:Button({
    Title = "Load Route Data",
    Desc = "Pre-load the automatic route data",
    Icon = "download",
    Callback = function()
        RouteInfo:Set({
            Title = "Loading...",
            Desc = "Downloading route data..."
        })
        
        autoData = LoadAutomaticJson()
        
        if autoData and #autoData > 0 then
            local totalTime = autoData[#autoData].time or 0
            local minutes = math.floor(totalTime / 60)
            local seconds = math.floor(totalTime % 60)
            
            RouteInfo:Set({
                Title = "Route Loaded",
                Desc = string.format("Total Frames: %d\nEstimated Time: %dm %ds\nReady to start!", 
                    #autoData, minutes, seconds)
            })
            
            WindUI:Notify({
                Title = "Route Data",
                Content = "Successfully loaded!",
                Duration = 3,
                Icon = "check-check"
            })
        else
            RouteInfo:Set({
                Title = "Load Failed",
                Desc = "Failed to load route data. Check your connection."
            })
            
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to load route data!",
                Duration = 3,
                Icon = "x"
            })
        end
    end
})

--| =========================================================== |--
--| PLAYER MENU SECTION                                         |--
--| =========================================================== |--

PlayerTab:Section({
    Title = "Nametag Menu",
})

local nametagConnections = {}

PlayerTab:Toggle({
    Title = "Hide Nametags",
    Desc = "Hide all player nametags",
    Icon = "eye-off",
    Default = false,
    Callback = function(Value)
        local function hideNametagsForCharacter(character)
            if not character then return end
            local head = character:FindFirstChild("Head")
            if not head then return end
            for _, obj in pairs(head:GetChildren()) do
                if obj:IsA("BillboardGui") then
                    obj.Enabled = false
                end
            end
        end

        local function showNametagsForCharacter(character)
            if not character then return end
            local head = character:FindFirstChild("Head")
            if not head then return end
            for _, obj in pairs(head:GetChildren()) do
                if obj:IsA("BillboardGui") then
                    obj.Enabled = true
                end
            end
        end

        local function setNametagsVisible(state)
            for _, player in pairs(Players:GetPlayers()) do
                if player.Character then
                    if state then
                        showNametagsForCharacter(player.Character)
                    else
                        hideNametagsForCharacter(player.Character)
                    end
                end
            end
        end

        if Value then
            setNametagsVisible(false)
            nametagConnections = {}
            local function connectPlayer(player)
                local charAddedConn
                charAddedConn = player.CharacterAdded:Connect(function(char)
                    task.wait(1)
                    hideNametagsForCharacter(char)
                end)
                table.insert(nametagConnections, charAddedConn)
            end
            for _, player in pairs(Players:GetPlayers()) do
                connectPlayer(player)
            end
            table.insert(nametagConnections, Players.PlayerAdded:Connect(connectPlayer))
            WindUI:Notify({
                Icon = "eye-off",
                Title = "Hide Nametags",
                Content = "Nametags hidden",
                Duration = 2
            })
        else
            setNametagsVisible(true)
            if nametagConnections then
                for _, conn in pairs(nametagConnections) do
                    if conn.Connected then conn:Disconnect() end
                end
            end
            nametagConnections = {}
            WindUI:Notify({
                Icon = "eye",
                Title = "Hide Nametags",
                Content = "Nametags visible",
                Duration = 2
            })
        end
    end,
})

PlayerTab:Space()

PlayerTab:Section({
    Title = "Walk Menu",
})

local WalkSpeedEnabled = false
local WalkSpeedValue = 16

local function ApplyWalkSpeed(Humanoid)
    if WalkSpeedEnabled then
        Humanoid.WalkSpeed = WalkSpeedValue
    else
        Humanoid.WalkSpeed = 16
    end
end

local function SetupCharacter(Char)
    local Humanoid = Char:WaitForChild("Humanoid")
    ApplyWalkSpeed(Humanoid)
end

LocalPlayer.CharacterAdded:Connect(function(Char)
    task.wait(1)
    SetupCharacter(Char)
end)

if LocalPlayer.Character then
    SetupCharacter(LocalPlayer.Character)
end

PlayerTab:Toggle({
    Title = "Walk Speed",
    Desc = "Enable custom walk speed",
    Icon = "gauge",
    Default = false,
    Callback = function(Value)
        WalkSpeedEnabled = Value
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            ApplyWalkSpeed(LocalPlayer.Character.Humanoid)
        end
        WindUI:Notify({
            Title = "Walk Speed",
            Content = Value and "Enabled" or "Disabled",
            Duration = 2,
            Icon = "gauge"
        })
    end,
})

PlayerTab:Slider({
    Title = "Set Walk Speed",
    Desc = "Adjust walk speed value",
    Step = 1,
    Value = {
        Min = 16,
        Max = 100,
        Default = 16,
    },
    Callback = function(value)
        WalkSpeedValue = value
        if WalkSpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = value
        end
    end
})

PlayerTab:Space()

PlayerTab:Section({
    Title = "Time Menu",
})

local Lighting = game:GetService("Lighting")
local TimeLockEnabled = false
local CurrentTimeValue = 12

PlayerTab:Toggle({
    Title = "Lock Time",
    Desc = "Lock time of day",
    Icon = "clock",
    Default = false,
    Callback = function(Value)
        TimeLockEnabled = Value
        WindUI:Notify({
            Title = "Lock Time",
            Content = Value and "Time locked" or "Time unlocked",
            Duration = 2,
            Icon = "clock"
        })
    end,
})

PlayerTab:Slider({
    Title = "Set Time of Day",
    Desc = "Adjust time (hours)",
    Step = 1,
    Value = {
        Min = 0,
        Max = 24,
        Default = 12,
    },
    Callback = function(value)
        CurrentTimeValue = value
        Lighting.ClockTime = value
    end
})

task.spawn(function()
    while task.wait(1) do
        if TimeLockEnabled then
            Lighting.ClockTime = CurrentTimeValue
        end
    end
end)

--| =========================================================== |--
--| RUN ANIMATION SECTION                                       |--
--| =========================================================== |--

AnimationTab:Section({
    Title = "Animation Pack List",
})

local RunAnimations = {
    {
        name = "Run Animation 1",
        Idle1 = "rbxassetid://122257458498464",
        Idle2 = "rbxassetid://102357151005774",
        Walk = "http://www.roblox.com/asset/?id=18537392113",
        Run = "rbxassetid://82598234841035",
        Jump = "rbxassetid://75290611992385",
        Fall = "http://www.roblox.com/asset/?id=11600206437",
        Climb = "http://www.roblox.com/asset/?id=10921257536",
        Swim = "http://www.roblox.com/asset/?id=10921264784",
        SwimIdle = "http://www.roblox.com/asset/?id=10921265698"
    },
    {
        name = "Run Animation 2",
        Idle1 = "rbxassetid://122257458498464",
        Idle2 = "rbxassetid://102357151005774",
        Walk = "rbxassetid://122150855457006",
        Run = "rbxassetid://82598234841035",
        Jump = "rbxassetid://75290611992385",
        Fall = "rbxassetid://98600215928904",
        Climb = "rbxassetid://88763136693023",
        Swim = "rbxassetid://133308483266208",
        SwimIdle = "rbxassetid://109346520324160"
    },
    {
        name = "Run Animation 3",
        Idle1 = "http://www.roblox.com/asset/?id=18537376492",
        Idle2 = "http://www.roblox.com/asset/?id=18537371272",
        Walk = "http://www.roblox.com/asset/?id=18537392113",
        Run = "http://www.roblox.com/asset/?id=18537384940",
        Jump = "http://www.roblox.com/asset/?id=18537380791",
        Fall = "http://www.roblox.com/asset/?id=18537367238",
        Climb = "http://www.roblox.com/asset/?id=10921271391",
        Swim = "http://www.roblox.com/asset/?id=99384245425157",
        SwimIdle = "http://www.roblox.com/asset/?id=113199415118199"
    },
}

local OriginalAnimations = {}
local currentAnimIndex = nil

local function SaveOriginalAnims(Animate)
    OriginalAnimations = {}
    for _, child in ipairs(Animate:GetDescendants()) do
        if child:IsA("Animation") then
            OriginalAnimations[child] = child.AnimationId
        end
    end
end

local function ApplyAnimation(Animate, Humanoid, pack)
    if Animate:FindFirstChild("idle") and Animate.idle:FindFirstChild("Animation1") then
        Animate.idle.Animation1.AnimationId = pack.Idle1
    end
    if Animate:FindFirstChild("idle") and Animate.idle:FindFirstChild("Animation2") then
        Animate.idle.Animation2.AnimationId = pack.Idle2
    end
    if Animate:FindFirstChild("walk") and Animate.walk:FindFirstChild("WalkAnim") then
        Animate.walk.WalkAnim.AnimationId = pack.Walk
    end
    if Animate:FindFirstChild("run") and Animate.run:FindFirstChild("RunAnim") then
        Animate.run.RunAnim.AnimationId = pack.Run
    end
    if Animate:FindFirstChild("jump") and Animate.jump:FindFirstChild("JumpAnim") then
        Animate.jump.JumpAnim.AnimationId = pack.Jump
    end
    if Animate:FindFirstChild("fall") and Animate.fall:FindFirstChild("FallAnim") then
        Animate.fall.FallAnim.AnimationId = pack.Fall
    end
    if Animate:FindFirstChild("climb") and Animate.climb:FindFirstChild("ClimbAnim") then
        Animate.climb.ClimbAnim.AnimationId = pack.Climb
    end
    if Animate:FindFirstChild("swim") and Animate.swim:FindFirstChild("Swim") then
        Animate.swim.Swim.AnimationId = pack.Swim
    end
    if Animate:FindFirstChild("swimidle") and Animate.swimidle:FindFirstChild("SwimIdle") then
        Animate.swimidle.SwimIdle.AnimationId = pack.SwimIdle
    end
    Humanoid.Jump = true
end

local function RestoreOriginal()
    for anim, id in pairs(OriginalAnimations) do
        if anim and anim:IsA("Animation") then
            anim.AnimationId = id
        end
    end
end

local animationToggles = {}

for i, pack in ipairs(RunAnimations) do
    local flag = "Animation" .. i
    animationToggles[flag] = AnimationTab:Toggle({
        Flag = flag,
        Title = pack.name,
        Desc = "Apply " .. pack.name,
        Icon = "person-standing",
        Default = false,
        Callback = function(Value)
            local Char = LocalPlayer.Character
            if not Char or not Char:FindFirstChild("Animate") or not Char:FindFirstChild("Humanoid") then
                WindUI:Notify({
                    Title = "Error",
                    Content = "Character not ready!",
                    Duration = 2,
                    Icon = "x"
                })
                return
            end
            
            local Animate = Char.Animate
            local Humanoid = Char.Humanoid
            
            if Value then
                for flag, toggle in pairs(animationToggles) do
                    if flag ~= "Animation" .. i then
                        toggle:Set(false)
                    end
                end
                
                SaveOriginalAnims(Animate)
                ApplyAnimation(Animate, Humanoid, pack)
                currentAnimIndex = i
                
                WindUI:Notify({
                    Icon = "person-standing",
                    Title = pack.name,
                    Content = "Animation applied!",
                    Duration = 2
                })
            else
                if currentAnimIndex == i then
                    RestoreOriginal()
                    currentAnimIndex = nil
                    WindUI:Notify({
                        Icon = "person-standing",
                        Title = pack.name,
                        Content = "Animation removed!",
                        Duration = 2
                    })
                end
            end
        end,
    })
end

--| =========================================================== |--
--| FINDING SERVER SECTION                                      |--
--| =========================================================== |--

ServerTab:Section({
    Title = "Server Menu",
})

local PlaceId = game.PlaceId
local Servers = {}

local function FetchServers()
    local Cursor = ""
    Servers = {}

    repeat
        local URL = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100%s", PlaceId, Cursor ~= "" and "&cursor="..Cursor or "")
        local success, Response = pcall(function()
            return game:HttpGet(URL)
        end)
        
        if not success then
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to fetch servers!",
                Duration = 3,
                Icon = "x"
            })
            return {}
        end
        
        local Data = HttpService:JSONDecode(Response)

        for _, server in pairs(Data.data) do
            table.insert(Servers, server)
        end

        Cursor = Data.nextPageCursor
        task.wait(0.5)
    until not Cursor

    return Servers
end

local ServerListSection = nil

local function CreateServerButtons()
    if ServerListSection then
        ServerListSection = nil
    end
    
    WindUI:Notify({
        Title = "Finding Servers",
        Content = "Searching for servers...",
        Duration = 3,
        Icon = "search"
    })
    
    local allServers = FetchServers()
    
    if #allServers == 0 then
        WindUI:Notify({
            Title = "Error",
            Content = "No servers found!",
            Duration = 3,
            Icon = "x"
        })
        return
    end
    
    ServerTab:Space()
    ServerTab:Section({
        Title = "Available Servers",
    })

    for _, server in pairs(allServers) do
        local playerCount = string.format("%d/%d", server.playing, server.maxPlayers)
        local isSafe = server.playing <= (server.maxPlayers / 2)

        local emoji = isSafe and "🟢" or "🟥"
        local safety = isSafe and "Safe" or "No Safe"

        local name = string.format("%s Server [%s] - %s", emoji, playerCount, safety)

        ServerTab:Button({
            Title = name,
            Icon = "server",
            Color = isSafe and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0),
            Callback = function()
                WindUI:Notify({
                    Title = "Teleporting",
                    Content = "Joining server...",
                    Duration = 2,
                    Icon = "loader"
                })
                TeleportService:TeleportToPlaceInstance(PlaceId, server.id)
            end,
        })
    end

    WindUI:Notify({
        Title = "Complete",
        Content = string.format("Found %d servers!", #allServers),
        Duration = 3,
        Icon = "check-check"
    })
end

ServerTab:Button({
    Title = "START FIND SERVER",
    Desc = "Search for servers with low player count",
    Icon = "search",
    Color = Color3.fromRGB(50, 150, 250),
    Callback = function()
        CreateServerButtons()
    end
})

--| =========================================================== |--
--| UPDATE CHECKPOINT SECTION                                   |--
--| =========================================================== |--

UpdateTab:Section({
    Title = "Update Checkpoints",
})

local UpdateStatus = UpdateTab:Paragraph({
    Title = "Status",
    Desc = "Ready to update checkpoints"
})

local updateInProgress = false

UpdateTab:Button({
    Title = "Update Manual JSON",
    Desc = "Update all manual checkpoint files",
    Icon = "download",
    Color = Color3.fromRGB(50, 150, 250),
    Callback = function()
        if updateInProgress then
            WindUI:Notify({
                Title = "Update",
                Content = "Update already in progress!",
                Duration = 2,
                Icon = "alert-triangle"
            })
            return
        end
        
        updateInProgress = true
        
        UpdateStatus:Set({
            Title = "Updating...",
            Desc = "Updating manual checkpoint files..."
        })
        
        task.spawn(function()
            for i, f in ipairs(manualJsonFiles) do
                local savePath = jsonFolder .. "/" .. f
                if isfile(savePath) then delfile(savePath) end
                
                local ok, res = pcall(function() return game:HttpGet(baseURL..f) end)
                if ok and res and #res > 0 then
                    writefile(savePath, res)
                    UpdateStatus:Set({
                        Title = "Updating...",
                        Desc = string.format("Progress: %d/%d - %s", i, #manualJsonFiles, f)
                    })
                else
                    WindUI:Notify({
                        Title = "Error",
                        Content = "Failed to update: " .. f,
                        Duration = 3,
                        Icon = "x"
                    })
                end
                task.wait(0.3)
            end
            
            UpdateStatus:Set({
                Title = "Complete!",
                Desc = "All manual checkpoints updated successfully!"
            })
            
            WindUI:Notify({
                Title = "Update Complete",
                Content = "Manual checkpoints updated!",
                Duration = 3,
                Icon = "check-check"
            })
            
            updateInProgress = false
        end)
    end
})

UpdateTab:Space()

UpdateTab:Button({
    Title = "Update Automatic JSON",
    Desc = "Update automatic checkpoint file",
    Icon = "download",
    Color = Color3.fromRGB(50, 150, 250),
    Callback = function()
        if updateInProgress then
            WindUI:Notify({
                Title = "Update",
                Content = "Update already in progress!",
                Duration = 2,
                Icon = "alert-triangle"
            })
            return
        end
        
        updateInProgress = true
        
        UpdateStatus:Set({
            Title = "Updating...",
            Desc = "Updating automatic checkpoint file..."
        })
        
        task.spawn(function()
            local savePath = autoJsonFolder .. "/" .. automaticJsonFile
            if isfile(savePath) then delfile(savePath) end
            
            local ok, res = pcall(function() 
                return game:HttpGet(automaticJsonURL) 
            end)
            
            if ok and res and #res > 0 then
                writefile(savePath, res)
                autoData = nil
                
                UpdateStatus:Set({
                    Title = "Complete!",
                    Desc = "Automatic checkpoint updated successfully!"
                })
                
                WindUI:Notify({
                    Title = "Update Complete",
                    Content = "Automatic checkpoint updated!",
                    Duration = 3,
                    Icon = "check-check"
                })
            else
                UpdateStatus:Set({
                    Title = "Failed!",
                    Desc = "Failed to update automatic checkpoint."
                })
                
                WindUI:Notify({
                    Title = "Error",
                    Content = "Failed to update automatic checkpoint!",
                    Duration = 3,
                    Icon = "x"
                })
            end
            
            updateInProgress = false
        end)
    end
})

UpdateTab:Space()

UpdateTab:Section({
    Title = "File Verification",
})

task.spawn(function()
    task.wait(1)
    for i, f in ipairs(manualJsonFiles) do
        local ok = EnsureJsonFile(f)
        UpdateStatus:Set({
            Title = "Checking Files",
            Desc = string.format("Verifying: %d/%d - %s", i, #manualJsonFiles, ok and "✓" or "✗")
        })
        task.wait(0.3)
    end
    UpdateStatus:Set({
        Title = "Ready",
        Desc = "All checkpoint files verified!"
    })
end)

-- Final notification
WindUI:Notify({
    Title = "RullzsyHUB Loaded",
    Content = "All systems ready!",
    Duration = 5,
    Icon = "check-check"
})
