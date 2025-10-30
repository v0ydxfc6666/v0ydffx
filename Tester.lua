-- ============================================================
-- AstrionHUB Gen2 - 120FPS Ultra Smooth NO JITTER (JUMP FIXED)
-- By Jinho - Jump Fix + Avatar Detection
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

local Packs = {
    lucide = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"))(),
    craft  = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/craft/dist/Icons.lua"))(),
    geist  = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/geist/dist/Icons.lua"))(),
}

local function refreshHRP(char)
    character = char
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
end
player.CharacterAdded:Connect(refreshHRP)

-- ============================================================
-- VARIABLES
-- ============================================================
local frameTime = 1/120
local playbackRate = 1.0
local isRunning = false
local routes = {}
local smoothTransition = true
local transitionSmoothness = 0.05
local autoLoop = true
local walkToStart = true
local intervalFlip = false

-- ============================================================
-- ANTI-JITTER SYSTEM
-- ============================================================
local antiJitterEnabled = true
local smoothingBuffer = {}
local bufferSize = 3

local function smoothPosition(newCF)
    if not antiJitterEnabled then return newCF end
    
    table.insert(smoothingBuffer, newCF.Position)
    if #smoothingBuffer > bufferSize then
        table.remove(smoothingBuffer, 1)
    end
    
    local avgPos = Vector3.zero
    for _, pos in ipairs(smoothingBuffer) do
        avgPos = avgPos + pos
    end
    avgPos = avgPos / #smoothingBuffer
    
    return CFrame.new(avgPos) * (newCF - newCF.Position)
end

-- ============================================================
-- NETWORK OWNERSHIP
-- ============================================================
local function setNetworkOwnership(char)
    pcall(function()
        local hrp = char:WaitForChild("HumanoidRootPart")
        hrp:SetNetworkOwner(player)
    end)
end

player.CharacterAdded:Connect(setNetworkOwnership)
if player.Character then setNetworkOwnership(player.Character) end

-- ============================================================
-- ULTRA SMOOTH EASING
-- ============================================================
local function ultraSmoothEasing(t, smoothness)
    local hermite = t * t * (3 - 2 * t)
    
    local septic
    if t < 0.5 then
        septic = 64 * t^7
    else
        local f = 2 * t - 2
        septic = 1 + 64 * f^7 / 2
    end
    
    local smoothstep = t * t * t * (t * (t * 6 - 15) + 10)
    
    local base = hermite * 0.3 + septic * 0.5 + smoothstep * 0.2
    local alpha = t + (base - t) * (1 - smoothness)
    
    return alpha
end

-- ============================================================
-- PARSE CFRAME DATA
-- ============================================================
local function parseCFrameData(data)
    local frames = {}
    for _, entry in ipairs(data) do
        if entry.c then
            table.insert(frames, entry.c)
        elseif typeof(entry) == "CFrame" then
            table.insert(frames, entry)
        end
    end
    return frames
end

-- ============================================================
-- ROUTE SYSTEM (NO AVATAR DETECTOR!)
-- ============================================================
local function removeDuplicateFrames(frames, tolerance)
    tolerance = tolerance or 0.01
    if #frames < 2 then return frames end
    local newFrames = {frames[1]}
    for i = 2, #frames do
        local prev = frames[i-1]
        local curr = frames[i]
        local prevPos, currPos = prev.Position, curr.Position
        local prevRot, currRot = prev - prev.Position, curr - curr.Position
        local posDiff = (prevPos - currPos).Magnitude
        local rotDiff = (prevRot.Position - currRot.Position).Magnitude
        if posDiff > tolerance or rotDiff > tolerance then
            table.insert(newFrames, curr)
        end
    end
    return newFrames
end

local function applyIntervalRotation(cf)
    if intervalFlip then
        local pos = cf.Position
        local rot = cf - pos
        local newRot = CFrame.Angles(0, math.pi, 0) * rot
        return CFrame.new(pos) * newRot
    else
        return cf
    end
end

local function loadRoute(url)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and type(result) == "table" then
        local parsedFrames = parseCFrameData(result)
        local cleaned = removeDuplicateFrames(parsedFrames, 0.01)
        return cleaned
    else
        warn("Failed to load route from: "..url)
        return {}
    end
end

routes = {
    {"BASE → CP8", loadRoute("https://raw.githubusercontent.com/syannnho/ASTRIONV3/refs/heads/main/MAPS/CIELO.lua")},
}

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
local VirtualUser = game:GetService("VirtualUser")
local antiIdleActive = true
local antiIdleConn

local function respawnPlayer()
    player.Character:BreakJoints()
end

local function getNearestRoute()
    local nearestIdx, dist = 1, math.huge
    if hrp then
        local pos = hrp.Position
        for i,data in ipairs(routes) do
            for _,cf in ipairs(data[2]) do
                local d = (cf.Position - pos).Magnitude
                if d < dist then
                    dist = d
                    nearestIdx = i
                end
            end
        end
    end
    return nearestIdx
end

local function getNearestFrameIndex(frames)
    local startIdx, dist = 1, math.huge
    if hrp then
        local pos = hrp.Position
        for i,cf in ipairs(frames) do
            local d = (cf.Position - pos).Magnitude
            if d < dist then
                dist = d
                startIdx = i
            end
        end
    end
    if startIdx >= #frames then
        startIdx = math.max(1, #frames - 1)
    end
    return startIdx
end

-- ============================================================
-- ULTRA SMOOTH WALK
-- ============================================================
local function walkToPosition(targetCF, walkSpeed)
    if not hrp then return end
    
    walkSpeed = walkSpeed or 16
    local startPos = hrp.Position
    local targetPos = targetCF.Position
    local distance = (targetPos - startPos).Magnitude
    
    if distance < 5 then
        local steps = 20
        for i = 1, steps do
            if not isRunning then break end
            local alpha = i / steps
            local smoothAlpha = ultraSmoothEasing(alpha, 0.02)
            local newCF = hrp.CFrame:Lerp(targetCF, smoothAlpha * 0.3)
            hrp.CFrame = smoothPosition(newCF)
            task.wait(1/120)
        end
        return
    end
    
    while (hrp.Position - targetPos).Magnitude > 3 do
        if not isRunning then break end
        local currentPos = hrp.Position
        local direction = (targetPos - currentPos).Unit
        local step = math.min(walkSpeed * (1/120), (targetPos - currentPos).Magnitude)
        local lookCF = CFrame.lookAt(currentPos, targetPos)
        local newPos = currentPos + direction * step
        local newCF = CFrame.new(newPos) * (lookCF - lookCF.Position)
        hrp.CFrame = hrp.CFrame:Lerp(newCF, 0.5)
        task.wait(1/120)
    end
    
    local arrivalSteps = 30
    for i = 1, arrivalSteps do
        if not isRunning then break end
        local alpha = i / arrivalSteps
        local smoothAlpha = ultraSmoothEasing(alpha, 0.01)
        local newCF = hrp.CFrame:Lerp(targetCF, smoothAlpha * 0.25)
        hrp.CFrame = smoothPosition(newCF)
        task.wait(1/120)
    end
end

-- ============================================================
-- ULTRA SMOOTH LERP (SIMPLE - NO DETECTION!)
-- ============================================================
local function lerpCF(fromCF, toCF)
    fromCF = applyIntervalRotation(fromCF)
    toCF = applyIntervalRotation(toCF)

    local duration = frameTime / math.max(0.05, playbackRate)
    local t = 0
    
    if smoothTransition then
        local lastCF = fromCF
        local lastTime = tick()
        smoothingBuffer = {}
        
        while t < duration do
            if not isRunning then break end
            local currentTime = tick()
            local dt = currentTime - lastTime
            lastTime = currentTime
            t += dt
            
            local alpha = t / duration
            local smoothAlpha = ultraSmoothEasing(alpha, transitionSmoothness)
            smoothAlpha = math.min(smoothAlpha, 1)
            
            if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
                local targetCF = fromCF:Lerp(toCF, smoothAlpha)
                local preLerp = lastCF:Lerp(targetCF, 0.85)
                local smoothedCF = smoothPosition(preLerp)
                
                hrp.CFrame = smoothedCF
                lastCF = hrp.CFrame
            end
            
            RunService.Heartbeat:Wait()
        end
        
        if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
            local finalCF = smoothPosition(hrp.CFrame:Lerp(toCF, 0.9))
            hrp.CFrame = finalCF
        end
    else
        while t < duration do
            if not isRunning then break end
            local dt = RunService.Heartbeat:Wait()
            t += dt
            local alpha = math.min(t / duration, 1)
            if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
                hrp.CFrame = fromCF:Lerp(toCF, alpha)
            end
        end
    end
end

local notify = function() end

-- ============================================================
-- BYPASS SYSTEM
-- ============================================================
local bypassActive = false
local bypassConn

local function setupBypass(char)
    local hum = char:WaitForChild("Humanoid")
    local root = char:WaitForChild("HumanoidRootPart")
    local lastPos = root.Position

    if bypassConn then bypassConn:Disconnect() end
    bypassConn = RunService.RenderStepped:Connect(function()
        if not root or not root.Parent then return end
        
        if bypassActive then
            local currentPos = root.Position
            local direction = (currentPos - lastPos)
            local dist = direction.Magnitude
            
            if dist > 0.01 then
                local moveVector = direction.Unit * math.clamp(dist * 5, 0, 1)
                hum:Move(moveVector, false)
            else
                hum:Move(Vector3.zero, false)
            end
        end
        
        lastPos = root.Position
    end)
end

player.CharacterAdded:Connect(setupBypass)
if player.Character then setupBypass(player.Character) end

local function setBypass(state)
    bypassActive = state
    if state then
        notify("Bypass Animation", "Active", 2)
    else
        notify("Bypass Animation", "Inactive", 2)
    end
end

-- ============================================================
-- ROUTE EXECUTION
-- ============================================================
local function runRouteOnce()
    if #routes == 0 then return end
    if not hrp then return end

    setBypass(true)
    isRunning = true

    local idx = getNearestRoute()
    local frames = routes[idx][2]
    if #frames < 2 then 
        isRunning = false
        setBypass(false)
        return 
    end

    local startIdx = getNearestFrameIndex(frames)
    local startCF = frames[startIdx]
    local distance = (hrp.Position - startCF.Position).Magnitude
    
    if walkToStart and distance > 50 then
        walkToPosition(startCF, 20)
    elseif distance > 5 then
        local steps = math.ceil(distance / 2)
        for i = 1, steps do
            if not isRunning then break end
            local alpha = i / steps
            hrp.CFrame = hrp.CFrame:Lerp(startCF, alpha * 0.5)
            task.wait(0.03)
        end
    end
    
    for i = startIdx, #frames - 1 do
        if not isRunning then break end
        lerpCF(frames[i], frames[i+1])
    end

    isRunning = false
    setBypass(false)
    notify("Route", "Completed", 2)
end

local function runAllRoutes()
    if #routes == 0 then return end
    isRunning = true
    local loopCount = 0

    while isRunning do
        loopCount = loopCount + 1
        if not hrp then break end
        setBypass(true)
        local idx = getNearestRoute()
        
        if loopCount == 1 then
            local frames = routes[idx][2]
            if #frames > 0 then
                local startIdx = getNearestFrameIndex(frames)
                local startCF = frames[startIdx]
                local distance = (hrp.Position - startCF.Position).Magnitude
                if walkToStart and distance > 50 then
                    walkToPosition(startCF, 20)
                end
            end
        end

        for r = idx, #routes do
            if not isRunning then break end
            local frames = routes[r][2]
            if #frames < 2 then continue end
            local startIdx = 1
            if r == idx and loopCount == 1 then
                startIdx = getNearestFrameIndex(frames)
            end
            for i = startIdx, #frames - 1 do
                if not isRunning then break end
                lerpCF(frames[i], frames[i+1])
            end
        end

        setBypass(false)
        if not isRunning then break end
        if autoLoop then
            task.wait(1)
        else
            respawnPlayer()
            task.wait(5)
        end
    end
end

local function stopRoute()
    isRunning = false
    if bypassActive then
        bypassActive = false
        notify("Bypass Animation", "Inactive", 2)
    end
    if hrp then
        _G.LastStopPosition = hrp.CFrame
    end
end

-- ============================================================
-- ANTI BETON (JUMP FIXED!)
-- ============================================================
local antiBetonActive = false
local antiBetonConn
local jumpStateConn
local isJumping = false
local jumpDebounce = false

local function enableAntiBeton()
    if antiBetonConn then antiBetonConn:Disconnect() end
    if jumpStateConn then jumpStateConn:Disconnect() end
    
    -- Monitor jump state
    jumpStateConn = humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            isJumping = true
            jumpDebounce = true
            task.delay(0.5, function()
                jumpDebounce = false
            end)
        elseif newState == Enum.HumanoidStateType.Freefall then
            if not jumpDebounce then
                isJumping = false
            end
        elseif newState == Enum.HumanoidStateType.Landed then
            isJumping = false
            jumpDebounce = false
        end
    end)
    
    antiBetonConn = RunService.Stepped:Connect(function(_, dt)
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then return end
        
        if antiBetonActive and humanoid.FloorMaterial == Enum.Material.Air and not isJumping and not jumpDebounce then
            local targetY = -50
            local currentY = hrp.Velocity.Y
            local newY = currentY + (targetY - currentY) * math.clamp(dt * 2.5, 0, 1)
            hrp.Velocity = Vector3.new(hrp.Velocity.X, newY, hrp.Velocity.Z)
        end
    end)
end

local function disableAntiBeton()
    if antiBetonConn then
        antiBetonConn:Disconnect()
        antiBetonConn = nil
    end
    if jumpStateConn then
        jumpStateConn:Disconnect()
        jumpStateConn = nil
    end
    isJumping = false
    jumpDebounce = false
end

-- ============================================================
-- AVATAR COPY
-- ============================================================
local function getPlayersInServer()
    local playerList = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            table.insert(playerList, plr.Name)
        end
    end
    table.sort(playerList)
    return playerList
end

local function loadAvatarByUsername(username)
    if not username or username == "" then
        return false, "Username cannot be empty"
    end
    if not player.Character then
        return false, "Character not found"
    end
    local targetPlayer = nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name == username then
            targetPlayer = plr
            break
        end
    end
    local userId = nil
    if targetPlayer then
        userId = targetPlayer.UserId
    else
        local success, result = pcall(function()
            return Players:GetUserIdFromNameAsync(username)
        end)
        if not success then
            return false, "User not found: " .. username
        end
        userId = result
    end
    local success2, humanoidDesc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(userId)
    end)
    if not success2 then
        return false, "Failed to get avatar"
    end
    local character = player.Character
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        return false, "Humanoid not found"
    end
    for _, item in pairs(character:GetChildren()) do
        if item:IsA("Accessory") or item:IsA("Hat") or item:IsA("Shirt") or 
           item:IsA("Pants") or item:IsA("ShirtGraphic") or
           item:IsA("CharacterMesh") or item:IsA("BodyColors") then
            item:Destroy()
        end
    end
    task.wait(0.15)
    local success3 = pcall(function()
        humanoid:ApplyDescriptionClientServer(humanoidDesc)
    end)
    if not success3 then
        pcall(function()
            humanoid:ApplyDescription(humanoidDesc)
        end)
    end
    task.wait(0.5)
    pcall(function()
        humanoid:BuildRigFromAttachments()
    end)
    return true, "Avatar copied: " .. username
end

-- ============================================================
-- RUN ANIMATIONS
-- ============================================================
local RunAnimations = {
    ["Run Animation 1"] = {
        Idle1 = "rbxassetid://122257458498464", Idle2 = "rbxassetid://102357151005774",
        Walk = "http://www.roblox.com/asset/?id=18537392113", Run = "rbxassetid://82598234841035",
        Jump = "rbxassetid://75290611992385", Fall = "http://www.roblox.com/asset/?id=11600206437",
        Climb = "http://www.roblox.com/asset/?id=10921257536", Swim = "http://www.roblox.com/asset/?id=10921264784",
        SwimIdle = "http://www.roblox.com/asset/?id=10921265698"
    },
    ["Run Animation 2"] = {
        Idle1 = "rbxassetid://122257458498464", Idle2 = "rbxassetid://102357151005774",
        Walk = "rbxassetid://122150855457006", Run = "rbxassetid://82598234841035",
        Jump = "rbxassetid://75290611992385", Fall = "rbxassetid://98600215928904",
        Climb = "rbxassetid://88763136693023", Swim = "rbxassetid://133308483266208",
        SwimIdle = "rbxassetid://109346520324160"
    },
    ["Run Animation 3"] = {
        Idle1 = "http://www.roblox.com/asset/?id=18537376492", Idle2 = "http://www.roblox.com/asset/?id=18537371272",
        Walk = "http://www.roblox.com/asset/?id=18537392113", Run = "http://www.roblox.com/asset/?id=18537384940",
        Jump = "http://www.roblox.com/asset/?id=18537380791", Fall = "http://www.roblox.com/asset/?id=18537367238",
        Climb = "http://www.roblox.com/asset/?id=10921271391", Swim = "http://www.roblox.com/asset/?id=99384245425157",
        SwimIdle = "http://www.roblox.com/asset/?id=113199415118199"
    },
}

local OriginalAnimations = {}
local CurrentPack = nil

local function SaveOriginalAnimations(Animate)
    OriginalAnimations = {}
    for _, child in ipairs(Animate:GetDescendants()) do
        if child:IsA("Animation") then
            OriginalAnimations[child] = child.AnimationId
        end
    end
end

local function ApplyAnimations(Animate, Humanoid, AnimPack)
    Animate.idle.Animation1.AnimationId = AnimPack.Idle1
    Animate.idle.Animation2.AnimationId = AnimPack.Idle2
    Animate.walk.WalkAnim.AnimationId = AnimPack.Walk
    Animate.run.RunAnim.AnimationId = AnimPack.Run
    Animate.jump.JumpAnim.AnimationId = AnimPack.Jump
    Animate.fall.FallAnim.AnimationId = AnimPack.Fall
    Animate.climb.ClimbAnim.AnimationId = AnimPack.Climb
    Animate.swim.Swim.AnimationId = AnimPack.Swim
    Animate.swimidle.SwimIdle.AnimationId = AnimPack.SwimIdle
    Humanoid.Jump = true
end

local function RestoreOriginal()
    for anim, id in pairs(OriginalAnimations) do
        if anim and anim:IsA("Animation") then
            anim.AnimationId = id
        end
    end
end

local function SetupCharacter(Char)
    local Animate = Char:WaitForChild("Animate")
    local Humanoid = Char:WaitForChild("Humanoid")
    SaveOriginalAnimations(Animate)
    if CurrentPack then
        ApplyAnimations(Animate, Humanoid, CurrentPack)
    end
end

Players.LocalPlayer.CharacterAdded:Connect(function(Char)
    task.wait(1)
    SetupCharacter(Char)
    refreshHRP(Char)
end)

if Players.LocalPlayer.Character then
    SetupCharacter(Players.LocalPlayer.Character)
end

-- ============================================================
-- UI: WindUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "AstrionHUB Gen2",
    Icon = "lucide:mountain-snow",
    Author = "Jinho",
    Folder = "AstrionHub",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Midnight",
    Resizable = true,
    SideBarWidth = 200,
    Watermark = "Jinho"
})

notify = function(title, content, duration)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content or "",
            Duration = duration or 2,
            Icon = "bell",
        })
    end)
end

local function enableAntiIdle()
    if antiIdleConn then antiIdleConn:Disconnect() end
    antiIdleConn = player.Idled:Connect(function()
        if antiIdleActive then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

enableAntiIdle()

local MainTab = Window:Tab({Title = "Main", Icon = "geist:shareplay", Default = true})
local ToolsTab = Window:Tab({Title = "Tools", Icon = "geist:settings-sliders"})
local AvaTab = Window:Tab({Title = "Avatar Copy", Icon = "lucide:user-round-search"})
local AnimTab = Window:Tab({Title = "Animation", Icon = "lucide:sparkles"})
local tampTab = Window:Tab({Title = "Display", Icon = "lucide:app-window"})
local InfoTab = Window:Tab({Title = "Info", Icon = "lucide:info"})

-- MAIN TAB
MainTab:Section({Title = "🚀 CONTROLS", TextSize = 16})

local speeds = {"1.0x"}
for v = 1.1, 10.0, 0.1 do
    table.insert(speeds, string.format("%.1fx", v))
end

MainTab:Dropdown({
    Title = "Speed",
    Icon = "lucide:zap",
    Values = speeds,
    Value = "1.0x",
    Callback = function(option)
        local num = tonumber(option:match("([%d%.]+)"))
        if num then
            playbackRate = num
            notify("Speed", string.format("⚡ %.1fx", playbackRate), 2)
        end
    end
})

MainTab:Button({Title = "▶️ START", Icon = "lucide:play", Callback = function() pcall(runRouteOnce) notify("Route", "Started", 2) end})
MainTab:Button({Title = "⏹️ STOP", Icon = "lucide:square", Callback = function() pcall(stopRoute) end})
MainTab:Button({Title = "🔄 LOOP ALL", Icon = "lucide:repeat", Callback = function() pcall(runAllRoutes) end})

MainTab:Section({Title = "🎛️ SETTINGS", TextSize = 14})

MainTab:Toggle({Title = "Ultra Smooth", Value = true, Callback = function(s) smoothTransition = s end})
MainTab:Slider({Title = "Smoothness", Value = {Min=0.01, Max=1.0, Default=0.05}, Step=0.01, Callback = function(v) transitionSmoothness = v end})
MainTab:Toggle({Title = "Anti-Jitter", Value = true, Callback = function(s) antiJitterEnabled = s end})
MainTab:Toggle({Title = "Anti Beton", Value = false, Callback = function(s) antiBetonActive = s if s then enableAntiBeton() else disableAntiBeton() end end})

-- TOOLS TAB
ToolsTab:Toggle({Title = "Auto Loop", Value = true, Callback = function(s) autoLoop = s end})
ToolsTab:Toggle({Title = "Walk to Start", Value = true, Callback = function(s) walkToStart = s end})
ToolsTab:Slider({Title = "WalkSpeed", Value = {Min=10, Max=500, Default=16}, Step=1, Callback = function(v) if character and character:FindFirstChild("Humanoid") then character.Humanoid.WalkSpeed = v end end})
ToolsTab:Slider({Title = "Jump Height", Value = {Min=10, Max=500, Default=50}, Step=1, Callback = function(v) if character and character:FindFirstChild("Humanoid") then character.Humanoid.JumpPower = v end end})
ToolsTab:Button({Title = "Respawn", Icon = "lucide:user-minus", Callback = function() respawnPlayer() end})

-- AVATAR TAB
AvaTab:Section({Title = "COPY AVATAR", TextSize = 16})

local selectedPlayer = nil
local playerDropdown

local function updatePlayerList()
    local players = getPlayersInServer()
    if #players == 0 then
        players = {"No players available"}
    end
    return players
end

playerDropdown = AvaTab:Dropdown({
    Title = "Select Player",
    Icon = "lucide:users",
    Values = updatePlayerList(),
    SearchBarEnabled = true,
    Value = nil,
    Callback = function(playerName)
        if playerName ~= "No players available" then
            selectedPlayer = playerName
        end
    end
})

AvaTab:Button({
    Title = "🔄 Refresh",
    Icon = "lucide:refresh-cw",
    Callback = function()
        playerDropdown:SetValues(updatePlayerList())
        notify("Player List", "Updated", 2)
    end
})

AvaTab:Button({
    Title = "Apply Avatar",
    Icon = "lucide:check",
    Callback = function()
        if not selectedPlayer then
            notify("Error", "No player selected", 2)
            return
        end
        local success, message = loadAvatarByUsername(selectedPlayer)
        notify(success and "Success" or "Error", message, 2)
    end
})

-- ANIMATION TAB
AnimTab:Section({Title = "RUN ANIMATIONS", TextSize = 16})

local animationToggles = {}

for animName, _ in pairs(RunAnimations) do
    animationToggles[animName] = AnimTab:Toggle({
        Title = animName,
        Value = false,
        Callback = function(Value)
            if Value then
                for otherName, toggle in pairs(animationToggles) do
                    if otherName ~= animName then
                        toggle:Set(false)
                    end
                end
                CurrentPack = RunAnimations[animName]
            elseif CurrentPack == RunAnimations[animName] then
                CurrentPack = nil
                RestoreOriginal()
            end
            local Char = Players.LocalPlayer.Character
            if Char and Char:FindFirstChild("Animate") and Char:FindFirstChild("Humanoid") then
                if CurrentPack then
                    ApplyAnimations(Char.Animate, Char.Humanoid, CurrentPack)
                else
                    RestoreOriginal()
                end
            end
        end,
    })
end

-- DISPLAY TAB
local themes = {}
for themeName, _ in pairs(WindUI:GetThemes()) do
    table.insert(themes, themeName)
end
table.sort(themes)

local themeDropdown = tampTab:Dropdown({
    Title = "Theme",
    Values = themes,
    Value = "Dark",
    Callback = function(theme)
        WindUI:SetTheme(theme)
    end
})

tampTab:Slider({
    Title = "Transparency",
    Value = {Min=0, Max=1, Default=0.2},
    Step = 0.1,
    Callback = function(value)
        WindUI.TransparencyValue = tonumber(value)
        Window:ToggleTransparency(tonumber(value) > 0)
    end
})

-- INFO TAB
InfoTab:Button({
    Title = "Copy Discord",
    Icon = "geist:logo-discord",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/cjZPqHRV")
            notify("Success", "Discord copied", 2)
        end
    end
})

InfoTab:Section({Title = "CHANGELOG", TextSize = 14})
InfoTab:Section({
    Title = [[
Gen2 - JUMP FIXED! ✅

🔧 JUMP FIX:
• StateChanged detection
• Jump debounce (0.5s)
• Freefall protection
• Landing detection
• Anti-beton smart disable

✅ FIXES:
• Jump = Jump animation ✅
• Fall = Fall animation ✅
• Anti-beton won't interfere
• Smooth transitions kept

🛡️ ANTI-JITTER:
• Position smoothing
• Network ownership
• Heartbeat sync
• Triple smoothing layer

🚀 120FPS:
• Ultra smooth movement
• Septic easing (7th)
• Speed: 1.0x - 10.0x
• Follow recording 100%

🎯 FEATURES:
• Smooth transitions
• Custom animations
• Speed control
• Loop mode
• Smart anti-beton

💡 JUMP LOGIC:
✅ Jumping state tracked
✅ 0.5s debounce period
✅ Anti-beton auto-pause
✅ Landing detection
✅ Natural animations

Own: Jinho | Gen2 Jump Fixed
    ]],
    TextSize = 14,
    TextTransparency = 0.25,
})

-- WINDOW CONFIG
Window:DisableTopbarButtons({"Close"})
Window:EditOpenButton({
    Title = "AstrionHUB",
    Icon = "geist:logo-nuxt",
    CornerRadius = UDim.new(0,16),
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
    ),
    Enabled = true,
    Draggable = true,
})

Window:Tag({
    Title = "Jump Fixed",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 10,
})

-- INITIALIZATION
notify("AstrionHUB Gen2", "✅ Jump Fixed - 120FPS!", 3)

pcall(function()
    Window:Show()
    MainTab:Show()
end)
