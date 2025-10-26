
-- ============================================================
-- CORE (fungsi asli + log/notify)
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
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

local frameTime = 1/30
local playbackRate = 1.0
local isRunning = false
local routes = {}
local smoothTransition = true
local transitionSmoothness = 0.1
local autoLoop = true
local walkToStart = true

-- ============================================================
-- NEW: Parse CFrame format dari recorder baru
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
-- ROUTE EXAMPLE
-- ============================================================
local DEFAULT_HEIGHT = 4.947289

local function getCurrentHeight()
    local char = player.Character or player.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    return humanoid.HipHeight + (char:FindFirstChild("Head") and char.Head.Size.Y or 2)
end

local function adjustRoute(frames)
    local adjusted = {}
    local currentHeight = getCurrentHeight()
    local offsetY = currentHeight - DEFAULT_HEIGHT
    for _, cf in ipairs(frames) do
        local pos, rot = cf.Position, cf - cf.Position
        local newPos = Vector3.new(pos.X, pos.Y + offsetY, pos.Z)
        table.insert(adjusted, CFrame.new(newPos) * rot)
    end
    return adjusted
end

local intervalFlip = false

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
        return adjustRoute(cleaned)
    else
        warn("Failed to load route from: "..url)
        return {}
    end
end

routes = {
    {"BASE → CP8", loadRoute("https://raw.githubusercontent.com/syannnho/ASTRIONV3/refs/heads/main/MAPS/KOTA_BUKAN_GUNUNG_1.lua")},
}

-- ============================================================
-- Fungsi bantu & core logic
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

local function walkToPosition(targetCF, walkSpeed)
    if not hrp then refreshHRP() end
    
    walkSpeed = walkSpeed or 16
    local startPos = hrp.Position
    local targetPos = targetCF.Position
    local distance = (targetPos - startPos).Magnitude
    
    if distance < 5 then
        local steps = 10
        for i = 1, steps do
            if not isRunning then break end
            local alpha = i / steps
            hrp.CFrame = hrp.CFrame:Lerp(targetCF, alpha)
            task.wait(0.03)
        end
        return
    end
    
    while (hrp.Position - targetPos).Magnitude > 3 do
        if not isRunning then break end
        
        local currentPos = hrp.Position
        local direction = (targetPos - currentPos).Unit
        local step = math.min(walkSpeed * 0.05, (targetPos - currentPos).Magnitude)
        
        local lookCF = CFrame.lookAt(currentPos, targetPos)
        local newPos = currentPos + direction * step
        local newCF = CFrame.new(newPos) * (lookCF - lookCF.Position)
        
        hrp.CFrame = hrp.CFrame:Lerp(newCF, 0.3)
        task.wait(0.03)
    end
    
    hrp.CFrame = hrp.CFrame:Lerp(targetCF, 0.5)
end

local function lerpCF(fromCF, toCF)
    fromCF = applyIntervalRotation(fromCF)
    toCF = applyIntervalRotation(toCF)

    local duration = frameTime / math.max(0.05, playbackRate)
    local t = 0
    
    if smoothTransition then
        local lastCF = fromCF
        
        while t < duration do
            if not isRunning then break end
            local dt = task.wait()
            t += dt
            
            local alpha = t / duration
            local smoothAlpha
            
            if alpha < 0.5 then
                smoothAlpha = 4 * alpha * alpha * alpha
            else
                local f = 2 * alpha - 2
                smoothAlpha = 1 + f * f * f / 2
            end
            
            smoothAlpha = alpha + (smoothAlpha - alpha) * (1 - transitionSmoothness)
            smoothAlpha = math.min(smoothAlpha, 1)
            
            if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
                local targetCF = fromCF:Lerp(toCF, smoothAlpha)
                hrp.CFrame = lastCF:Lerp(targetCF, 0.7)
                lastCF = hrp.CFrame
            end
        end
        
        if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
            hrp.CFrame = hrp.CFrame:Lerp(toCF, 0.8)
        end
    else
        while t < duration do
            if not isRunning then break end
            local dt = task.wait()
            t += dt
            local alpha = math.min(t / duration, 1)
            if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
                hrp.CFrame = fromCF:Lerp(toCF, alpha)
            end
        end
    end
end

local notify = function() end
local function logAndNotify(msg, val)
    local text = val and (msg .. " " .. tostring(val)) or msg
    print(text)
end

-- === VAR BYPASS WITH DOUBLE JUMP SUPPORT ===
local bypassActive = false
local bypassConn
local lastJumpState = false
local doubleJumpEnabled = true

local function setupBypass(char)
    local humanoid = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    local lastPos = hrp.Position
    local isDoubleJumping = false
    local doubleJumpForce = 50

    if bypassConn then bypassConn:Disconnect() end
    bypassConn = RunService.RenderStepped:Connect(function()
        if not hrp or not hrp.Parent then return end
        if bypassActive then
            local direction = (hrp.Position - lastPos)
            local dist = direction.Magnitude

            local yDiff = hrp.Position.Y - lastPos.Y
            local currentState = humanoid:GetState()
            
            if yDiff > 0.5 and not isDoubleJumping then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                isDoubleJumping = true
                
                if doubleJumpEnabled and currentState == Enum.HumanoidStateType.Freefall then
                    local currentVelocity = hrp.AssemblyLinearVelocity
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        currentVelocity.X,
                        doubleJumpForce,
                        currentVelocity.Z
                    )
                end
            elseif yDiff < -1 then
                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                isDoubleJumping = false
            elseif math.abs(yDiff) < 0.1 then
                isDoubleJumping = false
            end

            if dist > 0.01 then
                local moveVector = direction.Unit * math.clamp(dist * 5, 0, 1)
                humanoid:Move(moveVector, false)
            else
                humanoid:Move(Vector3.zero, false)
            end
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
    end
end

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

local function runSpecificRoute(routeIdx)
    if not routes[routeIdx] then return end
    if not hrp then refreshHRP() end
    isRunning = true
    local frames = routes[routeIdx][2]
    if #frames < 2 then 
        isRunning = false 
        return 
    end
    local startIdx = getNearestFrameIndex(frames)
    for i = startIdx, #frames - 1 do
        if not isRunning then break end
        lerpCF(frames[i], frames[i+1])
    end
    isRunning = false
end

-- ===============================
-- Anti Beton Ultra-Smooth
-- ===============================
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
-- AVATAR COPY FEATURE
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

    -- Find player in server first
    local targetPlayer = nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name == username then
            targetPlayer = plr
            break
        end
    end

    -- Get userId either from server player or API
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

    -- Get humanoid description
    local success2, humanoidDesc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(userId)
    end)
    if not success2 then
        return false, "Failed to get avatar"
    end

    -- Store current character properties
    local character = player.Character
    local humanoid = character:FindFirstChild("Humanoid")
    
    if not humanoid then
        return false, "Humanoid not found"
    end

    -- Remove ALL current accessories, clothing, and body parts (except core parts)
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
    
    -- Wait for removal to complete
    task.wait(0.15)

    -- Method 1: Try ApplyDescriptionClientServer (best for visibility)
    local success3 = pcall(function()
        humanoid:ApplyDescriptionClientServer(humanoidDesc)
    end)
    
    if not success3 then
        -- Method 2: Fallback to ApplyDescription
        local success4 = pcall(function()
            humanoid:ApplyDescription(humanoidDesc)
        end)
        
        if not success4 then
            -- Method 3: Manual application as last resort
            pcall(function()
                -- Body colors
                if humanoidDesc.HeadColor then
                    local bodyColors = character:FindFirstChild("Body Colors") or Instance.new("BodyColors", character)
                    bodyColors.HeadColor3 = humanoidDesc.HeadColor
                    bodyColors.LeftArmColor3 = humanoidDesc.LeftArmColor
                    bodyColors.RightArmColor3 = humanoidDesc.RightArmColor
                    bodyColors.LeftLegColor3 = humanoidDesc.LeftLegColor
                    bodyColors.RightLegColor3 = humanoidDesc.RightLegColor
                    bodyColors.TorsoColor3 = humanoidDesc.TorsoColor
                end
                
                -- Apply scales
                humanoid.BodyDepthScale.Value = humanoidDesc.BodyTypeScale
                humanoid.BodyHeightScale.Value = humanoidDesc.HeightScale
                humanoid.BodyWidthScale.Value = humanoidDesc.WidthScale
                humanoid.HeadScale.Value = humanoidDesc.HeadScale
                
                -- Shirt
                if humanoidDesc.Shirt and humanoidDesc.Shirt ~= "" then
                    local shirt = Instance.new("Shirt", character)
                    shirt.ShirtTemplate = humanoidDesc.Shirt
                end
                
                -- Pants
                if humanoidDesc.Pants and humanoidDesc.Pants ~= "" then
                    local pants = Instance.new("Pants", character)
                    pants.PantsTemplate = humanoidDesc.Pants
                end
                
                -- Apply accessories
                local function applyAccessory(assetId)
                    if assetId and assetId ~= "" and assetId ~= "0" then
                        local success, accessory = pcall(function()
                            return game:GetObjects("rbxassetid://" .. assetId)[1]
                        end)
                        if success and accessory and accessory:IsA("Accessory") then
                            humanoid:AddAccessory(accessory)
                        end
                    end
                end
                
                -- Apply all accessories from description
                applyAccessory(humanoidDesc.HatAccessory)
                applyAccessory(humanoidDesc.HairAccessory)
                applyAccessory(humanoidDesc.FaceAccessory)
                applyAccessory(humanoidDesc.NeckAccessory)
                applyAccessory(humanoidDesc.ShoulderAccessory)
                applyAccessory(humanoidDesc.FrontAccessory)
                applyAccessory(humanoidDesc.BackAccessory)
                applyAccessory(humanoidDesc.WaistAccessory)
            end)
        end
    end
    
    -- Final wait to ensure everything loads
    task.wait(0.5)
    
    -- Force character refresh to ensure visibility
    pcall(function()
        humanoid:BuildRigFromAttachments()
    end)

    return true, "Avatar copied: " .. username
end

-- ============================================================
-- RUN ANIMATION SYSTEM
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
    ["Run Animation 4"] = {
        Idle1   = "http://www.roblox.com/asset/?id=118832222982049",
        Idle2   = "http://www.roblox.com/asset/?id=76049494037641",
        Walk    = "http://www.roblox.com/asset/?id=92072849924640",
        Run     = "http://www.roblox.com/asset/?id=72301599441680",
        Jump    = "http://www.roblox.com/asset/?id=104325245285198",
        Fall    = "http://www.roblox.com/asset/?id=121152442762481",
        Climb   = "http://www.roblox.com/asset/?id=507765644",
        Swim    = "http://www.roblox.com/asset/?id=99384245425157",
        SwimIdle= "http://www.roblox.com/asset/?id=113199415118199"
    },
    ["Run Animation 5"] = {
        Idle1   = "http://www.roblox.com/asset/?id=656117400",
        Idle2   = "http://www.roblox.com/asset/?id=656118341",
        Walk    = "http://www.roblox.com/asset/?id=656121766",
        Run     = "http://www.roblox.com/asset/?id=656118852",
        Jump    = "http://www.roblox.com/asset/?id=656117878",
        Fall    = "http://www.roblox.com/asset/?id=656115606",
        Climb   = "http://www.roblox.com/asset/?id=656114359",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 6"] = {
        Idle1   = "http://www.roblox.com/asset/?id=616006778",
        Idle2   = "http://www.roblox.com/asset/?id=616008087",
        Walk    = "http://www.roblox.com/asset/?id=616013216",
        Run     = "http://www.roblox.com/asset/?id=616010382",
        Jump    = "http://www.roblox.com/asset/?id=616008936",
        Fall    = "http://www.roblox.com/asset/?id=616005863",
        Climb   = "http://www.roblox.com/asset/?id=616003713",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 7"] = {
        Idle1   = "http://www.roblox.com/asset/?id=1083195517",
        Idle2   = "http://www.roblox.com/asset/?id=1083214717",
        Walk    = "http://www.roblox.com/asset/?id=1083178339",
        Run     = "http://www.roblox.com/asset/?id=1083216690",
        Jump    = "http://www.roblox.com/asset/?id=1083218792",
        Fall    = "http://www.roblox.com/asset/?id=1083189019",
        Climb   = "http://www.roblox.com/asset/?id=1083182000",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 8"] = {
        Idle1   = "http://www.roblox.com/asset/?id=616136790",
        Idle2   = "http://www.roblox.com/asset/?id=616138447",
        Walk    = "http://www.roblox.com/asset/?id=616146177",
        Run     = "http://www.roblox.com/asset/?id=616140816",
        Jump    = "http://www.roblox.com/asset/?id=616139451",
        Fall    = "http://www.roblox.com/asset/?id=616134815",
        Climb   = "http://www.roblox.com/asset/?id=616133594",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 9"] = {
        Idle1   = "http://www.roblox.com/asset/?id=616088211",
        Idle2   = "http://www.roblox.com/asset/?id=616089559",
        Walk    = "http://www.roblox.com/asset/?id=616095330",
        Run     = "http://www.roblox.com/asset/?id=616091570",
        Jump    = "http://www.roblox.com/asset/?id=616090535",
        Fall    = "http://www.roblox.com/asset/?id=616087089",
        Climb   = "http://www.roblox.com/asset/?id=616086039",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 10"] = {
        Idle1   = "http://www.roblox.com/asset/?id=910004836",
        Idle2   = "http://www.roblox.com/asset/?id=910009958",
        Walk    = "http://www.roblox.com/asset/?id=910034870",
        Run     = "http://www.roblox.com/asset/?id=910025107",
        Jump    = "http://www.roblox.com/asset/?id=910016857",
        Fall    = "http://www.roblox.com/asset/?id=910001910",
        Climb   = "http://www.roblox.com/asset/?id=616086039",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 11"] = {
        Idle1   = "http://www.roblox.com/asset/?id=742637544",
        Idle2   = "http://www.roblox.com/asset/?id=742638445",
        Walk    = "http://www.roblox.com/asset/?id=742640026",
        Run     = "http://www.roblox.com/asset/?id=742638842",
        Jump    = "http://www.roblox.com/asset/?id=742637942",
        Fall    = "http://www.roblox.com/asset/?id=742637151",
        Climb   = "http://www.roblox.com/asset/?id=742636889",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 12"] = {
        Idle1   = "http://www.roblox.com/asset/?id=616111295",
        Idle2   = "http://www.roblox.com/asset/?id=616113536",
        Walk    = "http://www.roblox.com/asset/?id=616122287",
        Run     = "http://www.roblox.com/asset/?id=616117076",
        Jump    = "http://www.roblox.com/asset/?id=616115533",
        Fall    = "http://www.roblox.com/asset/?id=616108001",
        Climb   = "http://www.roblox.com/asset/?id=616104706",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 13"] = {
        Idle1   = "http://www.roblox.com/asset/?id=657595757",
        Idle2   = "http://www.roblox.com/asset/?id=657568135",
        Walk    = "http://www.roblox.com/asset/?id=657552124",
        Run     = "http://www.roblox.com/asset/?id=657564596",
        Jump    = "http://www.roblox.com/asset/?id=658409194",
        Fall    = "http://www.roblox.com/asset/?id=657600338",
        Climb   = "http://www.roblox.com/asset/?id=658360781",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 14"] = {
        Idle1   = "http://www.roblox.com/asset/?id=616158929",
        Idle2   = "http://www.roblox.com/asset/?id=616160636",
        Walk    = "http://www.roblox.com/asset/?id=616168032",
        Run     = "http://www.roblox.com/asset/?id=616163682",
        Jump    = "http://www.roblox.com/asset/?id=616161997",
        Fall    = "http://www.roblox.com/asset/?id=616157476",
        Climb   = "http://www.roblox.com/asset/?id=616156119",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 15"] = {
        Idle1   = "http://www.roblox.com/asset/?id=845397899",
        Idle2   = "http://www.roblox.com/asset/?id=845400520",
        Walk    = "http://www.roblox.com/asset/?id=845403856",
        Run     = "http://www.roblox.com/asset/?id=845386501",
        Jump    = "http://www.roblox.com/asset/?id=845398858",
        Fall    = "http://www.roblox.com/asset/?id=845396048",
        Climb   = "http://www.roblox.com/asset/?id=845392038",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 16"] = {
        Idle1   = "http://www.roblox.com/asset/?id=782841498",
        Idle2   = "http://www.roblox.com/asset/?id=782845736",
        Walk    = "http://www.roblox.com/asset/?id=782843345",
        Run     = "http://www.roblox.com/asset/?id=782842708",
        Jump    = "http://www.roblox.com/asset/?id=782847020",
        Fall    = "http://www.roblox.com/asset/?id=782846423",
        Climb   = "http://www.roblox.com/asset/?id=782843869",
        Swim    = "http://www.roblox.com/asset/?id=18537389531",
        SwimIdle= "http://www.roblox.com/asset/?id=18537387180"
    },
    ["Run Animation 17"] = {
        Idle1   = "http://www.roblox.com/asset/?id=891621366",
        Idle2   = "http://www.roblox.com/asset/?id=891633237",
        Walk    = "http://www.roblox.com/asset/?id=891667138",
        Run     = "http://www.roblox.com/asset/?id=891636393",
        Jump    = "http://www.roblox.com/asset/?id=891627522",
        Fall    = "http://www.roblox.com/asset/?id=891617961",
        Climb   = "http://www.roblox.com/asset/?id=891609353",
        Swim    = "http://www.roblox.com/asset/?id=18537389531",
        SwimIdle= "http://www.roblox.com/asset/?id=18537387180"
    },
    ["Run Animation 18"] = {
        Idle1   = "http://www.roblox.com/asset/?id=750781874",
        Idle2   = "http://www.roblox.com/asset/?id=750782770",
        Walk    = "http://www.roblox.com/asset/?id=750785693",
        Run     = "http://www.roblox.com/asset/?id=750783738",
        Jump    = "http://www.roblox.com/asset/?id=750782230",
        Fall    = "http://www.roblox.com/asset/?id=750780242",
        Climb   = "http://www.roblox.com/asset/?id=750779899",
        Swim    = "http://www.roblox.com/asset/?id=18537389531",
        SwimIdle= "http://www.roblox.com/asset/?id=18537387180"
    }
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
    local player = Players.LocalPlayer
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
-- MAIN TAB
-- ============================================================
local speeds = {}
for v = 0.25, 3, 0.25 do
    table.insert(speeds, string.format("%.2fx", v))
end
MainTab:Dropdown({
    Title = "Speed",
    Icon = "lucide:zap",
    Values = speeds,
    Value = "1.00x",
    Callback = function(option)
        local num = tonumber(option:match("([%d%.]+)"))
        if num then
            playbackRate = num
        end
    end
})

MainTab:Button({
    Title = "▶️ START",
    Icon = "lucide:play",
    Desc = "Start replay route",
    Callback = function() pcall(runRouteOnce) end
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
    Title = "Smooth Transition",
    Icon = "lucide:sparkles",
    Desc = "Ultra smooth movement",
    Value = true,
    Callback = function(state)
        smoothTransition = state
    end
})

MainTab:Slider({
    Title = "Smoothness",
    Icon = "lucide:waves",
    Desc = "Transition smoothness level",
    Value = { 
        Min = 0.1,
        Max = 1.0,
        Default = 0.1
    },
    Step = 0.05,
    Suffix = "",
    Callback = function(val)
        transitionSmoothness = val
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
                local currentVersion = "Gen1"
                
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
Gen1 - Major Update

Features:
• Avatar Copy System - Select and copy player avatars
• 18 Run Animation Packs - Custom character animations
• Ultra Smooth Movement - Advanced cubic easing
• Speed Control - Adjustable playback speed
• Route System - START/STOP/LOOP controls
• Anti Beton - Smooth fall prevention

Tools:
• WalkSpeed & Jump Height sliders
• Speed Coil & TP Tool
• Timer GUI & Private Server
• Fling GUI

How to Use:
1. Set speed and options
2. Click START to begin
3. Use STOP to halt
4. Enable Auto Loop for continuous play

Avatar Copy:
1. Select player from dropdown
2. Click Apply Avatar
3. Changes visible to all

Animations:
1. Toggle animation pack ON
2. Auto-applies to character
3. Toggle OFF to reset

Own: Jinho | Gen1
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
    Title = "Gen1",
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
notify("AstrionHUB Gen1", "Loaded Successfully", 2)

pcall(function()
    Window:Show()
    MainTab:Show()
end)
