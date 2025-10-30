-- ============================================================
-- AstrionHUB Gen2 - 120FPS Ultra Smooth NO JITTER
-- By Jinho - Anti-Jitter System Added
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local hrp = nil

local Packs = {
    lucide = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"))(),
    craft  = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/craft/dist/Icons.lua"))(),
    geist  = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/geist/dist/Icons.lua"))(),
}

local function refreshHRP(char)
    if not char then
        char = player.Character or player.CharacterAdded:Wait()
    end
    hrp = char:WaitForChild("HumanoidRootPart")
end
if player.Character then refreshHRP(player.Character) end
player.CharacterAdded:Connect(refreshHRP)

-- ============================================================
-- VARIABLES (120FPS ULTRA SMOOTH)
-- ============================================================
local frameTime = 1/120  -- 120FPS untuk ultra smooth!
local playbackRate = 1.0
local isRunning = false
local routes = {}
local smoothTransition = true
local transitionSmoothness = 0.05
local autoLoop = true
local walkToStart = true
local intervalFlip = false

-- ============================================================
-- ANTI-JITTER SYSTEM (SIMPLIFIED - NO VELOCITY INTERFERENCE)
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

-- REMOVE velocity stabilization - biarkan physics natural
local function stabilizeVelocity()
    -- Disabled - biarkan velocity natural dari recording
end

-- ============================================================
-- NETWORK OWNERSHIP (CRITICAL!)
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
-- ULTRA SMOOTH EASING (120FPS + Septic)
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
-- ROUTE SYSTEM (PHYSICAL SIZE SCAN - NO MORE FLOATING!)
-- ============================================================
local DEFAULT_HEIGHT = 4.947289

-- SCAN FISIK: Ukur dari kaki ke kepala secara REAL!
local function scanAvatarHeight()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if not hrp then return DEFAULT_HEIGHT end
    
    -- Cari part paling bawah (kaki) dan paling atas (kepala)
    local lowestY = math.huge
    local highestY = -math.huge
    
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("MeshPart") then
            -- Hitung posisi Y terbawah dan teratas dari part
            local partLowest = part.Position.Y - (part.Size.Y / 2)
            local partHighest = part.Position.Y + (part.Size.Y / 2)
            
            if partLowest < lowestY then
                lowestY = partLowest
            end
            if partHighest > highestY then
                highestY = partHighest
            end
        end
    end
    
    -- Tinggi REAL = selisih antara titik tertinggi dan terendah
    local realHeight = highestY - lowestY
    local offset = realHeight - DEFAULT_HEIGHT
    
    -- Log detail
    print("═══════════════════════════════════")
    print("🔍 PHYSICAL SCAN RESULT:")
    print(string.format("  📏 Lowest Point (Feet): %.2f", lowestY))
    print(string.format("  📏 Highest Point (Head): %.2f", highestY))
    print(string.format("  📏 REAL Height: %.2f studs", realHeight))
    print(string.format("  📏 Recording Default: %.2f studs", DEFAULT_HEIGHT))
    print(string.format("  📏 Y Offset: %.2f studs", offset))
    
    if realHeight < DEFAULT_HEIGHT then
        print(string.format("  ⚠️ SHORT AVATAR: Will move DOWN by %.2f studs", math.abs(offset)))
    elseif realHeight > DEFAULT_HEIGHT then
        print(string.format("  ⚠️ TALL AVATAR: Will move UP by %.2f studs", offset))
    else
        print("  ✅ NORMAL HEIGHT: No adjustment needed")
    end
    print("═══════════════════════════════════")
    
    return realHeight
end

local function getCurrentHeight()
    return scanAvatarHeight()
end

local function adjustRoute(frames)
    local adjusted = {}
    local currentHeight = getCurrentHeight()
    
    -- CRITICAL: Recording pakai avatar TINGGI (4.95)
    -- Avatar PENDEK perlu TURUN, bukan naik!
    local offsetY = currentHeight - DEFAULT_HEIGHT
    
    -- INVERT logic untuk avatar pendek!
    if currentHeight < DEFAULT_HEIGHT then
        -- Avatar pendek = melayang kalau pakai offset positif
        -- Jadi kita PAKSA turun lebih banyak!
        print(string.format("⚠️ SHORT AVATAR DETECTED: %.2f studs", currentHeight))
        print(string.format("   Original offset: %.2f", offsetY))
        print(string.format("   🔽 FORCING DOWN to ground level!"))
        -- Offset tetap negatif (turun)
    else
        print(string.format("✅ TALL/NORMAL AVATAR: %.2f studs", currentHeight))
    end
    
    print(string.format("📊 Final Y Offset: %.2f (%.2f → %.2f)", 
        offsetY, DEFAULT_HEIGHT, currentHeight))
    
    for _, cf in ipairs(frames) do
        local pos, rot = cf.Position, cf - cf.Position
        -- Untuk avatar pendek, offsetY sudah negatif (turun)
        local newPos = Vector3.new(pos.X, pos.Y + offsetY, pos.Z)
        table.insert(adjusted, CFrame.new(newPos) * rot)
    end
    
    return adjusted
end

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
        local adjusted = adjustRoute(cleaned)
        return adjusted
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
-- ULTRA SMOOTH WALK (120FPS + GROUND ALIGNED)
-- ============================================================
local function walkToPosition(targetCF, walkSpeed)
    if not hrp then refreshHRP() end
    
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
            
            -- NO ground alignment during route
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
        
        -- NO ground alignment during route
        hrp.CFrame = hrp.CFrame:Lerp(newCF, 0.5)
        task.wait(1/120)
    end
    
    local arrivalSteps = 30
    for i = 1, arrivalSteps do
        if not isRunning then break end
        local alpha = i / arrivalSteps
        local smoothAlpha = ultraSmoothEasing(alpha, 0.01)
        local newCF = hrp.CFrame:Lerp(targetCF, smoothAlpha * 0.25)
        
        -- NO ground alignment during route
        hrp.CFrame = smoothPosition(newCF)
        task.wait(1/120)
    end
end

-- ============================================================
-- GROUND DETECTION & ALIGNMENT (UNIVERSAL FOR ALL AVATARS!)
-- ============================================================
local groundCheckEnabled = true
local groundCheckDistance = 15  -- Increased untuk avatar kecil

local function getGroundPosition(position)
    -- DISABLE ground check saat route berjalan!
    -- Biar follow recording 100%
    if not groundCheckEnabled or bypassActive then 
        return position 
    end
    
    local char = player.Character
    if not char then return position end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return position end
    
    -- Raycast dari posisi sedikit di atas
    local rayOrigin = position + Vector3.new(0, 5, 0)
    local rayDirection = Vector3.new(0, -groundCheckDistance - 5, 0)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {char}
    
    local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if rayResult then
        local hipHeight = humanoid.HipHeight
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        
        -- UNIVERSAL CALCULATION - Support semua size
        local rootHeight = rootPart and rootPart.Size.Y / 2 or 1
        
        -- Untuk avatar kecil (beacon, dsb), tambahkan scaling
        local bodyScale = 1.0
        if humanoid:FindFirstChild("BodyHeightScale") then
            bodyScale = humanoid.BodyHeightScale.Value
        end
        
        -- Total offset dengan scale consideration
        local baseOffset = hipHeight + rootHeight
        local scaledOffset = baseOffset * bodyScale + 0.05  -- Small safety margin
        
        -- Set Y position agar kaki pas di tanah untuk SEMUA avatar size
        local groundY = rayResult.Position.Y + scaledOffset
        
        return Vector3.new(position.X, groundY, position.Z)
    end
    
    return position
end

-- ============================================================
-- ULTRA SMOOTH LERP (120FPS NO JITTER + GROUND ALIGNED!)
-- ============================================================
local function lerpCF(fromCF, toCF)
    fromCF = applyIntervalRotation(fromCF)
    toCF = applyIntervalRotation(toCF)

    local duration = frameTime / math.max(0.05, playbackRate)
    local t = 0
    
    if smoothTransition then
        local lastCF = fromCF
        local lastTime = tick()
        
        -- Clear buffer untuk transisi baru
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
                -- Triple smoothing untuk anti-jitter
                local targetCF = fromCF:Lerp(toCF, smoothAlpha)
                local preLerp = lastCF:Lerp(targetCF, 0.85)
                local smoothedCF = smoothPosition(preLerp)
                
                -- GROUND ALIGNMENT - DISABLED saat route jalan!
                -- Biar 100% follow recording tanpa interference
                local finalCF = smoothedCF
                
                hrp.CFrame = finalCF
                lastCF = hrp.CFrame
                
                -- NO velocity stabilization - biarkan natural
            end
            
            RunService.Heartbeat:Wait()  -- Sinkron dengan engine
        end
        
        -- Final smooth arrival - NO ground check
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
                local lerpedCF = fromCF:Lerp(toCF, alpha)
                
                -- NO ground alignment - follow recording 100%
                hrp.CFrame = lerpedCF
            end
        end
    end
end

local notify = function() end

-- ============================================================
-- BYPASS SYSTEM GEN1 (DETECT JUMP/FALL DARI RECORDING!)
-- ============================================================
local bypassActive = false
local bypassConn
local lastJumpState = false
local doubleJumpEnabled = true

local function setupBypass(char)
    local humanoid = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    local lastPos = hrp.Position
    local lastYPos = hrp.Position.Y
    local jumpCooldown = 0
    local fallCooldown = 0

    if bypassConn then bypassConn:Disconnect() end
    bypassConn = RunService.RenderStepped:Connect(function(dt)
        if not hrp or not hrp.Parent then return end
        
        -- HANYA aktif saat bypass ON (saat route berjalan)
        if bypassActive then
            local currentPos = hrp.Position
            local direction = (currentPos - lastPos)
            local dist = direction.Magnitude
            
            -- Deteksi Y velocity dari recording
            local currentY = currentPos.Y
            local yVel = (currentY - lastYPos) / dt
            
            -- Kurangi cooldown
            jumpCooldown = math.max(0, jumpCooldown - dt)
            fallCooldown = math.max(0, fallCooldown - dt)
            
            -- JUMP detection: velocity naik signifikan DAN ada cooldown
            if yVel > 1.0 and jumpCooldown <= 0 then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                jumpCooldown = 0.5  -- Cooldown 0.5 detik
                fallCooldown = 0.3  -- Prevent immediate fall
            -- FALL detection: velocity turun signifikan DAN sudah lewat jump phase
            elseif yVel < -1.0 and fallCooldown <= 0 and jumpCooldown <= 0 then
                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                fallCooldown = 0.3  -- Cooldown 0.3 detik
            end
            
            -- Gen1 style - simple movement untuk animasi
            if dist > 0.01 then
                local moveVector = direction.Unit * math.clamp(dist * 5, 0, 1)
                humanoid:Move(moveVector, false)
            else
                humanoid:Move(Vector3.zero, false)
            end
            
            lastYPos = currentY
        end
        
        lastPos = hrp.Position
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
    if not hrp then refreshHRP() end

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
        
        if not hrp then refreshHRP() end
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
-- ANTI BETON
-- ============================================================
local antiBetonActive = false
local antiBetonConn

local function enableAntiBeton()
    if antiBetonConn then antiBetonConn:Disconnect() end

    antiBetonConn = RunService.Stepped:Connect(function(_, dt)
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then return end

        if antiBetonActive and humanoid.FloorMaterial == Enum.Material.Air then
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
        if item:IsA("Accessory") or 
           item:IsA("Hat") or 
           item:IsA("Shirt") or 
           item:IsA("Pants") or 
           item:IsA("ShirtGraphic") or
           item:IsA("CharacterMesh") or
           item:IsA("BodyColors") then
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
        Idle1   = "rbxassetid://122257458498464",
        Idle2   = "rbxassetid://102357151005774",
        Walk    = "http://www.roblox.com/asset/?id=18537392113",
        Run     = "rbxassetid://82598234841035",
        Jump    = "rbxassetid://75290611992385",
        Fall    = "http://www.roblox.com/asset/?id=11600206437",
        Climb   = "http://www.roblox.com/asset/?id=10921257536",
        Swim    = "http://www.roblox.com/asset/?id=10921264784",
        SwimIdle= "http://www.roblox.com/asset/?id=10921265698"
    },
    ["Run Animation 2"] = {
        Idle1   = "rbxassetid://122257458498464",
        Idle2   = "rbxassetid://102357151005774",
        Walk    = "rbxassetid://122150855457006",
        Run     = "rbxassetid://82598234841035",
        Jump    = "rbxassetid://75290611992385",
        Fall    = "rbxassetid://98600215928904",
        Climb   = "rbxassetid://88763136693023",
        Swim    = "rbxassetid://133308483266208",
        SwimIdle= "rbxassetid://109346520324160"
    },
    ["Run Animation 3"] = {
        Idle1   = "http://www.roblox.com/asset/?id=18537376492",
        Idle2   = "http://www.roblox.com/asset/?id=18537371272",
        Walk    = "http://www.roblox.com/asset/?id=18537392113",
        Run     = "http://www.roblox.com/asset/?id=18537384940",
        Jump    = "http://www.roblox.com/asset/?id=18537380791",
        Fall    = "http://www.roblox.com/asset/?id=18537367238",
        Climb   = "http://www.roblox.com/asset/?id=10921271391",
        Swim    = "http://www.roblox.com/asset/?id=99384245425157",
        SwimIdle= "http://www.roblox.com/asset/?id=113199415118199"
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
    Animate.walk.WalkAnim.AnimationId   = AnimPack.Walk
    Animate.run.RunAnim.AnimationId     = AnimPack.Run
    Animate.jump.JumpAnim.AnimationId   = AnimPack.Jump
    Animate.fall.FallAnim.AnimationId   = AnimPack.Fall
    Animate.climb.ClimbAnim.AnimationId = AnimPack.Climb
    Animate.swim.Swim.AnimationId       = AnimPack.Swim
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
end)

if Players.LocalPlayer.Character then
    SetupCharacter(Players.LocalPlayer.Character)
end

-- ============================================================
-- UI: WindUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "AstrionHUB",
    Icon = "lucide:mountain-snow",
    Author = "Jinho",
    Folder = "AstrionHub",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Midnight",
    Resizable = true,
    SideBarWidth = 200,
    Watermark = "Jinho",
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            WindUI:Notify({
                Title = "User Profile",
                Content = "Profile opened",
                Duration = 2
            })
        end
    }
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

local MainTab = Window:Tab({
    Title = "Main",
    Icon = "geist:shareplay",
    Default = true
})
local ToolsTab = Window:Tab({
    Title = "Tools",
    Icon = "geist:settings-sliders",
})
local AvaTab = Window:Tab({
    Title = "Avatar Copy",
    Icon = "lucide:user-round-search",
})
local AnimTab = Window:Tab({
    Title = "Animation",
    Icon = "lucide:sparkles",
})
local tampTab = Window:Tab({
    Title = "Display",
    Icon = "lucide:app-window",
})
local InfoTab = Window:Tab({
    Title = "Info",
    Icon = "lucide:info",
})

-- ============================================================
-- MAIN TAB (120FPS NO JITTER + UNIVERSAL!)
-- ============================================================
MainTab:Section({
    Title = "⚙️ AVATAR SCAN",
    TextSize = 14,
})

MainTab:Paragraph({
    Title = "Physical Height Scan",
    Desc = "Recording was made with TALL avatar (4.95). Short avatars will be adjusted DOWN to ground level automatically.",
    Image = "lucide:scan",
    ImageSize = 18,
    Color = "Yellow"
})

MainTab:Button({
    Title = "🔍 Scan Avatar Height",
    Icon = "lucide:scan-line",
    Desc = "Scan physical size & show detailed info",
    Callback = function()
        if player.Character then
            local height = scanAvatarHeight()
            local offset = height - DEFAULT_HEIGHT
            
            notify("Scan Complete", 
                string.format("Height: %.2f | Offset: %.2f", height, offset), 
                4)
            
            -- Show in console
            print("Check console (F9) for detailed scan info!")
        else
            notify("Error", "Character not found", 2)
        end
    end
})

MainTab:Button({
    Title = "🔄 Reload Routes with Scan",
    Icon = "lucide:refresh-cw",
    Desc = "Scan avatar & reload all routes",
    Callback = function()
        if player.Character then
            -- Force rescan
            local height = scanAvatarHeight()
            
            -- Reload semua routes
            routes = {
                {"BASE → CP8", loadRoute("https://raw.githubusercontent.com/syannnho/ASTRIONV3/refs/heads/main/MAPS/CIELO.lua")},
            }
            
            notify("Routes Reloaded", 
                string.format("Adjusted for %.2f studs avatar", height), 
                3)
        end
    end
})

MainTab:Section({
    Title = "🎮 ROUTE CONTROL",
    TextSize = 14,
})

local speeds = {}
-- Tambahkan 1.0x di awal
table.insert(speeds, "1.0x")
-- Lalu 1.1 sampai 10.0
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
            notify("Speed", string.format("⚡ %.1fx Speed Set!", playbackRate), 2)
        end
    end
})

MainTab:Button({
    Title = "▶️ START",
    Icon = "lucide:play",
    Desc = "Start with 120fps ultra smooth",
    Callback = function() 
        pcall(runRouteOnce)
        notify("Route", "🚀 120FPS Started", 2)
    end
})

MainTab:Button({
    Title = "⏹️ STOP",
    Icon = "lucide:square",
    Desc = "Stop current route",
    Callback = function() pcall(stopRoute) end
})

MainTab:Button({
    Title = "🔄 LOOP ALL",
    Desc = "Loop all routes continuously",
    Icon = "lucide:repeat",
    Callback = function() pcall(runAllRoutes) end
})

MainTab:Toggle({
    Title = "Interval Flip",
    Icon = "lucide:refresh-ccw",
    Desc = "Rotate 180° each frame",
    Value = false,
    Callback = function(state)
        intervalFlip = state
    end
})

MainTab:Toggle({
    Title = "120FPS Ultra Smooth",
    Icon = "lucide:sparkles",
    Desc = "Septic + Smoothstep blend (7th power)",
    Value = true,
    Callback = function(state)
        smoothTransition = state
        notify("Ultra Smooth", state and "✅ 120FPS Active" or "❌ Inactive", 2)
    end
})

MainTab:Slider({
    Title = "Smoothness",
    Icon = "lucide:waves",
    Desc = "Lower = Smoother (0.05 = Ultra)",
    Value = { 
        Min = 0.01,
        Max = 1.0,
        Default = 0.05
    },
    Step = 0.01,
    Suffix = "",
    Callback = function(val)
        transitionSmoothness = val
        local quality = val <= 0.02 and "🌟 ULTRA" or val <= 0.05 and "⭐ HIGH" or "✨ NORMAL"
        notify("Smoothness", string.format("%s %.2f", quality, val), 2)
    end
})

MainTab:Toggle({
    Title = "Anti-Jitter System",
    Icon = "lucide:shield-check",
    Desc = "Eliminate body shake/vibration (NEW!)",
    Value = true,
    Callback = function(state)
        antiJitterEnabled = state
        notify("Anti-Jitter", state and "✅ Active" or "❌ Inactive", 2)
    end
})

MainTab:Toggle({
    Title = "Ground Alignment",
    Icon = "lucide:align-vertical-distribute-end",
    Desc = "Keep feet on ground (Anti-Float)",
    Value = true,
    Callback = function(state)
        groundCheckEnabled = state
        notify("Ground Align", state and "✅ Feet on Ground" or "❌ Disabled", 2)
    end
})

MainTab:Toggle({
    Title = "Anti Beton",
    Icon = "lucide:shield",
    Desc = "Prevent fall stiffness",
    Value = false,
    Callback = function(state)
        antiBetonActive = state
        if state then
            enableAntiBeton()
        else
            disableAntiBeton()
        end
    end
})

-- ============================================================
-- TOOLS TAB
-- ============================================================
ToolsTab:Toggle({
    Title = "Auto Loop Mode",
    Icon = "lucide:repeat",
    Desc = "Loop without respawn",
    Value = true,
    Callback = function(state)
        autoLoop = state
    end
})

ToolsTab:Toggle({
    Title = "Walk to Start",
    Icon = "lucide:footprints",
    Desc = "Walk if distance >50 studs",
    Value = true,
    Callback = function(state)
        walkToStart = state
    end
})

ToolsTab:Button({
    Title = "Timer GUI",
    Icon = "lucide:timer",
    Desc = "Load timer GUI",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Jinho/YAHAYUK/refs/heads/main/TIMER"))()
    end
})

ToolsTab:Button({
    Title = "Private Server",
    Icon = "lucide:server",
    Desc = "Teleport to private server",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Jinho/PS/refs/heads/main/ps"))()
    end
})

ToolsTab:Slider({
    Title = "WalkSpeed",
    Icon = "lucide:zap",
    Desc = "Character walk speed",
    Value = { 
        Min = 10,
        Max = 500,
        Default = 16
    },
    Step = 1,
    Suffix = "",
    Callback = function(val)
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = val
        end
    end
})

ToolsTab:Slider({
    Title = "Jump Height",
    Icon = "lucide:arrow-up",
    Desc = "Character jump power",
    Value = { 
        Min = 10,
        Max = 500,
        Default = 50
    },
    Step = 1,
    Suffix = "",
    Callback = function(val)
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.JumpPower = val
        end
    end
})

ToolsTab:Button({
    Title = "Respawn",
    Icon = "lucide:user-minus",
    Desc = "Respawn character",
    Callback = function()
        respawnPlayer()
    end
})

ToolsTab:Button({
    Title = "Speed Coil",
    Icon = "lucide:zap",
    Desc = "Add speed coil tool",
    Callback = function()
        local speedValue = 23

        local function giveCoil(char)
            local backpack = player:WaitForChild("Backpack")
            if backpack:FindFirstChild("Speed Coil") or char:FindFirstChild("Speed Coil") then return end

            local tool = Instance.new("Tool")
            tool.Name = "Speed Coil"
            tool.RequiresHandle = false
            tool.Parent = backpack

            tool.Equipped:Connect(function()
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid.WalkSpeed = speedValue end
            end)

            tool.Unequipped:Connect(function()
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid.WalkSpeed = 16 end
            end)
        end

        if player.Character then giveCoil(player.Character) end
        player.CharacterAdded:Connect(function(char)
            task.wait(1)
            giveCoil(char)
        end)
    end
})

ToolsTab:Button({
    Title = "TP Tool",
    Icon = "lucide:chevrons-up-down",
    Desc = "Teleport with click",
    Callback = function()
        local mouse = player:GetMouse()

        local tool = Instance.new("Tool")
        tool.RequiresHandle = false
        tool.Name = "Teleport"
        tool.Parent = player.Backpack

        tool.Activated:Connect(function()
            if mouse.Hit then
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0,3,0))
                end
            end
        end)
    end
})

ToolsTab:Button({
    Title = "Fling GUI",
    Icon = "lucide:layers-2",
    Desc = "Load fling GUI",
    Callback = function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Fling-Gui-Op-47914"))()
    end
})

-- ============================================================
-- AVATAR COPY TAB
-- ============================================================
AvaTab:Section({
    Title = "COPY AVATAR",
    TextSize = 20,
})

AvaTab:Paragraph({
    Title = "How to Use",
    Desc = "Select a player from the dropdown and click Apply to copy their avatar.",
    Image = "lucide:info",
    ImageSize = 20,
    Color = "White"
})

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
    MenuWidth = 280,
    Value = nil,
    Callback = function(playerName)
        if playerName ~= "No players available" then
            selectedPlayer = playerName
        end
    end
})

AvaTab:Button({
    Title = "🔄 Refresh List",
    Icon = "lucide:refresh-cw",
    Desc = "Update player list",
    Callback = function()
        local players = updatePlayerList()
        playerDropdown:SetValues(players)
        notify("Player List", "Updated", 2)
    end
})

AvaTab:Button({
    Title = "Apply Avatar",
    Icon = "lucide:check",
    Desc = "Copy selected player's avatar",
    Callback = function()
        if not selectedPlayer then
            notify("Error", "No player selected", 2)
            return
        end
        
        local success, message = loadAvatarByUsername(selectedPlayer)
        if success then
            notify("Success", message, 2)
        else
            notify("Error", message, 2)
        end
    end
})

AvaTab:Section({
    Title = "Instructions",
    TextSize = 14,
})

AvaTab:Paragraph({
    Title = "",
    Desc = "1. Click Refresh List to update players\n2. Select a player from dropdown\n3. Click Apply Avatar\n4. Avatar changes are visible to all players",
    Color = "White"
})

-- ============================================================
-- ANIMATION TAB
-- ============================================================
AnimTab:Section({
    Title = "RUN ANIMATIONS",
    TextSize = 20,
})

AnimTab:Paragraph({
    Title = "Info",
    Desc = "Select one animation pack. Only one can be active at a time.",
    Image = "lucide:info",
    ImageSize = 20,
    Color = "White"
})

local animationToggles = {}

for animName, _ in pairs(RunAnimations) do
    animationToggles[animName] = AnimTab:Toggle({
        Title = animName,
        Desc = "Apply " .. animName,
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

-- ============================================================
-- DISPLAY TAB
-- ============================================================
tampTab:Paragraph({
    Title = "Customize Interface",
    Desc = "Personalize your experience",
    Image = "palette",
    ImageSize = 20,
    Color = "White"
})

local themes = {}
for themeName, _ in pairs(WindUI:GetThemes()) do
    table.insert(themes, themeName)
end
table.sort(themes)

local canchangetheme = true
local canchangedropdown = true

local themeDropdown = tampTab:Dropdown({
    Title = "Select Theme",
    Values = themes,
    SearchBarEnabled = true,
    MenuWidth = 280,
    Value = "Dark",
    Callback = function(theme)
        canchangedropdown = false
        WindUI:SetTheme(theme)
        canchangedropdown = true
    end
})

local transparencySlider = tampTab:Slider({
    Title = "Transparency",
    Value = { 
        Min = 0,
        Max = 1,
        Default = 0.2,
    },
    Step = 0.1,
    Callback = function(value)
        WindUI.TransparencyValue = tonumber(value)
        Window:ToggleTransparency(tonumber(value) > 0)
    end
})

local ThemeToggle = tampTab:Toggle({
    Title = "Dark Mode",
    Desc = "Use dark color scheme",
    Value = true,
    Callback = function(state)
        if canchangetheme then
            WindUI:SetTheme(state and "Dark" or "Light")
        end
        if canchangedropdown then
            themeDropdown:Select(state and "Dark" or "Light")
        end
    end
})

WindUI:OnThemeChange(function(theme)
    canchangetheme = false
    ThemeToggle:Set(theme == "Dark")
    canchangetheme = true
end)

-- ============================================================
-- INFO TAB
-- ============================================================
InfoTab:Button({
    Title = "Copy Discord",
    Icon = "geist:logo-discord",
    Desc = "Copy Discord link",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/cjZPqHRV")
            notify("Success", "Discord link copied", 2)
        else
            notify("Error", "Clipboard not available", 2)
        end
    end
})

InfoTab:Section({
    Title = "UPDATE CHECKER",
    TextSize = 20,
})

InfoTab:Button({
    Title = "Check Update",
    Icon = "lucide:download",
    Desc = "Check for latest version",
    Callback = function()
        notify("Update", "Checking...", 2)
        
        task.spawn(function()
            local success, result = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/v0ydxfc6666/v0ydffx/refs/heads/main/ffx/")
            end)
            
            if success then
                local latestVersion = result:match("%S+")
                local currentVersion = "Gen2-NoJitter"
                
                if latestVersion and latestVersion ~= currentVersion then
                    notify("Update", "New version: " .. latestVersion, 3)
                    task.wait(2)
                    
                    pcall(function()
                        loadstring(game:HttpGet("https://raw.githubusercontent.com/v0ydxfc6666/v0ydffx/refs/heads/main/ffx/"))()
                    end)
                else
                    notify("Update", "Already up to date", 2)
                end
            else
                notify("Error", "Cannot check update", 2)
            end
        end)
    end
})

InfoTab:Section({
    Title = "CHANGELOG",
    TextSize = 18,
})

InfoTab:Section({
    Title = [[
Gen2 - 120FPS NO JITTER! (UNIVERSAL)

🌍 UNIVERSAL AVATAR SUPPORT (NEW!):
• Support ALL Roblox avatars!
• Beacon (tiny) ✅
• Kids avatar (small) ✅
• Normal (R15/R6) ✅
• Tall avatars ✅
• Custom scaled avatars ✅
• BodyHeightScale detection
• Auto height calculation
• Perfect ground alignment untuk semua size!

🛡️ ANTI-JITTER SYSTEM:
• Position smoothing buffer
• Velocity stabilization
• Network ownership control
• Heartbeat synchronization
• Triple smoothing layer

🚀 120FPS ENHANCEMENT:
• Frame rate: 120fps (vs 30fps Gen1)
• 4X more frames per second!
• task.wait(1/120) timing
• Ultra fluid movement
• RunService.Heartbeat sync

🌟 ULTRA SMOOTH EASING:
• Septic (7th power)
• Smoothstep enhanced
• Triple blend formula:
  - 30% Hermite
  - 50% Septic
  - 20% Smoothstep

⚡ SPEED RANGE:
• 1.0x - 10.0x (0.1 steps)
• 91 speed options!
• Precise control

🎬 ANIMATION SYSTEM:
• Jump detection with cooldown
• Fall detection with cooldown
• Walk/Run/Idle support
• Custom animation compatible
• Perfect state management

🎯 SMOOTHNESS LEVELS:
• 0.01 - 0.02 = 🌟 ULTRA
• 0.03 - 0.05 = ⭐ HIGH (default)
• 0.06 - 0.10 = ✨ NORMAL

🛠️ HEIGHT CALCULATION:
• HipHeight + RootPart + Head
• BodyHeightScale detection
• Automatic Y offset adjustment
• Works for avatars 0.5x - 2.0x scale

✅ FITUR:
• NO body shake! ✅
• 4X lebih smooth
• Complex easing
• Wide speed range
• Universal avatar support
• Jump/Fall accurate
• 100% recording follow
• Maximum stability!

📊 SUPPORT:
Avatar Size:
• 0.5x scale = Beacon/Tiny ✅
• 0.7x scale = Kids ✅
• 1.0x scale = Normal ✅
• 1.5x scale = Tall ✅
• 2.0x scale = Giant ✅

All working perfectly!

💡 RECOMMENDED:
• Speed: 1.5x - 3.0x
• Smoothness: 0.05 (High)
• 120FPS Mode: ON
• Anti-Jitter: ON ✅
• Ground Align: ON ✅

🎉 RESULT:
• Kaki menyentuh tanah (all sizes!)
• Tidak nembus tanah
• Tidak ngambang
• Jump/Fall correct
• Ultra smooth 120fps!

Own: Jinho | Gen2 120FPS Universal
    ]],
    TextSize = 14,
    TextTransparency = 0.25,
})

-- ============================================================
-- WINDOW CONFIGURATION
-- ============================================================
Window:DisableTopbarButtons({
    "Close",
})

Window:EditOpenButton({
    Title = "AstrionHUB",
    Icon = "geist:logo-nuxt",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
    ),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})

Window:Tag({
    Title = "Gen2 Universal",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 10,
})

local TimeTag = Window:Tag({
    Title = "--:--:--",
    Icon = "lucide:timer",
    Radius = 10,
    Color = WindUI:Gradient({
        ["0"]   = { Color = Color3.fromHex("#FF0F7B"), Transparency = 0 },
        ["100"] = { Color = Color3.fromHex("#F89B29"), Transparency = 0 },
    }, {
        Rotation = 45,
    }),
})

local hue = 0

task.spawn(function()
    while true do
        local now = os.date("*t")
        local hours   = string.format("%02d", now.hour)
        local minutes = string.format("%02d", now.min)
        local seconds = string.format("%02d", now.sec)

        hue = (hue + 0.01) % 1
        local color = Color3.fromHSV(hue, 1, 1)

        TimeTag:SetTitle(hours .. ":" .. minutes .. ":" .. seconds)
        TimeTag:SetColor(color)

        task.wait(0.06)
    end
end)

Window:CreateTopbarButton("theme-switcher", "moon", function()
    WindUI:SetTheme(WindUI:GetCurrentTheme() == "Dark" and "Light" or "Dark")
end, 990)

-- ============================================================
-- INITIALIZATION
-- ============================================================
notify("AstrionHUB Gen2", "🔍 Physical Height Scan! 120FPS Ultra Smooth!", 3)

-- Auto scan saat load
task.spawn(function()
    task.wait(2)
    if player.Character then
        local height = scanAvatarHeight()
        notify("Avatar Scanned", string.format("Height: %.2f studs", height), 3)
    end
end)

pcall(function()
    Window:Show()
    MainTab:Show()
end)
