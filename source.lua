-- Services with optimized access
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")

-- Optimized local references
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera
local viewportSize = camera.ViewportSize
local container = Instance.new("Folder", 
    gethui and gethui() or game:GetService("CoreGui"))

-- Optimized math operations
local math_floor = math.floor
local math_round = math.round
local math_sin = math.sin
local math_cos = math.cos
local table_clear = table.clear
local table_unpack = table.unpack
local table_find = table.find
local table_create = table.create
local fromMatrix = CFrame.fromMatrix

-- Cached methods
local wtvp = camera.WorldToViewportPoint
local isA = workspace.IsA
local getPivot = workspace.GetPivot
local findFirstChild = workspace.FindFirstChild
local findFirstChildOfClass = workspace.FindFirstChildOfClass
local getChildren = workspace.GetChildren
local toOrientation = CFrame.identity.ToOrientation
local pointToObjectSpace = CFrame.identity.PointToObjectSpace
local lerpColor = Color3.new().Lerp

-- Optimized vector operations
local min2 = Vector2.zero.Min
local max2 = Vector2.zero.Max
local lerp2 = Vector2.zero.Lerp
local min3 = Vector3.zero.Min
local max3 = Vector3.zero.Max

-- Cached constants
local ZERO_VECTOR2 = Vector2.zero
local ZERO_VECTOR3 = Vector3.zero
local IDENTITY_CFRAME = CFrame.identity

-- Original offsets preserved
local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0)
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1)
local NAME_OFFSET = Vector2.new(0, 2)
local DISTANCE_OFFSET = Vector2.new(0, 2)

-- Optimized vertices table
local VERTICES = {
    Vector3.new(-1, -1, -1),
    Vector3.new(-1, 1, -1),
    Vector3.new(-1, 1, 1),
    Vector3.new(-1, -1, 1),
    Vector3.new(1, -1, -1),
    Vector3.new(1, 1, -1),
    Vector3.new(1, 1, 1),
    Vector3.new(1, -1, 1)
}

-- Optimized body part detection
local BODY_PARTS = {
    Head = true,
    Torso = true,
    UpperTorso = true,
    LowerTorso = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true
}

-- Utility Functions
local function isBodyPart(name)
    return BODY_PARTS[name] or name:find("Torso") or name:find("Leg") or name:find("Arm")
end

local function worldToScreen(world)
    local screen, inBounds = wtvp(camera, world)
    return Vector2.new(screen.X, screen.Y), inBounds, screen.Z
end

-- Color cache system
local colorCache = setmetatable({}, {__mode = "k"})
local function parseColor(self, color, isOutline)
    local cacheKey = {color, isOutline, self.player}
    if colorCache[cacheKey] then return colorCache[cacheKey] end
    
    local parsedColor
    if color == "Team Color" or (self.interface.sharedSettings.useTeamColor and not isOutline) then
        parsedColor = self.interface.getTeamColor(self.player) or Color3.new(1,1,1)
    else
        parsedColor = color
    end
    
    colorCache[cacheKey] = parsedColor
    return parsedColor
end

-- Efficient Drawing Object Creation
local function createDrawing(class, properties)
    local drawing = Drawing.new(class)
    for prop, value in pairs(properties or {}) do
        pcall(function() drawing[prop] = value end)
    end
    return drawing
end

-- Drawing Object Pool
local DrawingPool = {}
DrawingPool.__index = DrawingPool

function DrawingPool.new(drawingClass, initialSize)
    local pool = setmetatable({
        class = drawingClass,
        active = {},
        inactive = {},
        maxPoolSize = initialSize or 50
    }, DrawingPool)
    
    for i = 1, initialSize or 50 do
        table.insert(pool.inactive, createDrawing(drawingClass))
    end
    
    return pool
end

function DrawingPool:acquire(properties)
    local drawing
    if #self.inactive > 0 then
        drawing = table.remove(self.inactive)
    elseif #self.active < self.maxPoolSize then
        drawing = createDrawing(self.class)
    else
        drawing = table.remove(self.active, 1)
    end
    
    for prop, value in pairs(properties or {}) do
        drawing[prop] = value
    end
    
    table.insert(self.active, drawing)
    return drawing
end

function DrawingPool:release(drawing)
    drawing.Visible = false
    for i, active in ipairs(self.active) do
        if active == drawing then
            table.remove(self.active, i)
            table.insert(self.inactive, drawing)
            break
        end
    end
end

-- Advanced Configuration System
local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager.new(defaultConfig)
    return setmetatable({
        _config = defaultConfig or {},
        _listeners = {}
    }, ConfigManager)
end

function ConfigManager:set(key, value)
    local oldValue = self._config[key]
    self._config[key] = value
    
    -- Trigger listeners
    for _, listener in ipairs(self._listeners) do
        if listener.key == key or listener.key == nil then
            pcall(listener.callback, key, value, oldValue)
        end
    end
end

function ConfigManager:get(key, default)
    return self._config[key] ~= nil and self._config[key] or default
end

function ConfigManager:addListener(callback, specificKey)
    local listener = {
        key = specificKey,
        callback = callback
    }
    table.insert(self._listeners, listener)
    return function()
        for i, l in ipairs(self._listeners) do
            if l == listener then
                table.remove(self._listeners, i)
                break
            end
        end
    end
end

-- Performance Monitoring Wrapper
local function performanceWrapper(func)
    return function(...)
        local start = os.clock()
        local result = {func(...)}
        local elapsed = os.clock() - start
        
        if elapsed > 0.01 then  -- Log functions taking more than 10ms
            warn(string.format("Performance warning: %s took %.2f ms", 
                debug.getinfo(func).name or "unknown", elapsed * 1000))
        end
        
        return table_unpack(result)
    end
end

-- Safe Player Iteration
local function safePlayerIteration(callback)
    local success, playerList = pcall(function()
        return players:GetPlayers()
    end)
    
    if success then
        for _, player in ipairs(playerList) do
            if player ~= localPlayer then
                local success, err = pcall(callback, player)
                if not success then
                    warn("Error in player iteration: " .. tostring(err))
                end
            end
        end
    end
end

-- Error-Safe Function Executor
local function safeFunctionCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("Error in function call: " .. tostring(result))
    end
    return success, result
end

-- ESP Object with Advanced Rendering
local ESP = {}
ESP.__index = ESP

function ESP.new(player, interface)
    local self = setmetatable({
        player = player,
        character = nil,
        humanoid = nil,
        rootPart = nil,
        interface = interface,
        
        -- Drawing Object Pools
        boxes = {
            outline = DrawingPool:new("Square"),
            fill = DrawingPool:new("Square"),
        },
        tracers = {
            line = DrawingPool:new("Line"),
        },
        names = DrawingPool:new("Text"),
        healthBars = {
            outline = DrawingPool:new("Square"),
            fill = DrawingPool:new("Square"),
        },
        distanceTexts = DrawingPool:new("Text"),
        
        -- State Tracking
        lastUpdateTime = 0,
        updateInterval = 0.1,
        isVisible = false,
        
        -- Cached Calculations
        screenPosition = ZERO_VECTOR2,
        boundingBox = {min = ZERO_VECTOR3, max = ZERO_VECTOR3},
        distance = 0
    }, ESP)
    
    self:setup()
    return self
end

function ESP:setup()
    -- Character and Component Tracking
    local success, characterResult = pcall(function()
        return self.player.Character
    end)
    
    if not success or not characterResult then return end
    
    self.character = characterResult
    self.humanoid = self.character:FindFirstChildOfClass("Humanoid")
    self.rootPart = self.character:FindFirstChild("HumanoidRootPart")
    
    if not self.rootPart then return end
end

function ESP:updateTracking()
    if not self.rootPart then return false end
    
    local currentTime = tick()
    if currentTime - self.lastUpdateTime < self.updateInterval then
        return self.isVisible
    end
    
    self.lastUpdateTime = currentTime
    
    -- Distance and Visibility Calculations
    local rootPosition = self.rootPart.Position
    local screenPos, onScreen, depth = worldToScreen(rootPosition)
    
    self.screenPosition = screenPos
    self.distance = (localPlayer.Character.HumanoidRootPart.Position - rootPosition).Magnitude
    self.isVisible = onScreen and depth > 0
    
    return self.isVisible
end

function ESP:calculateBoundingBox()
    if not self.character then return end
    
    local parts = {}
    for _, part in ipairs(self.character:GetChildren()) do
        if isBodyPart(part.Name) and part:IsA("BasePart") then
            table.insert(parts, part)
        end
    end
    
    if #parts == 0 then return end
    
    local min, max = parts[1].CFrame, parts[1].CFrame
    for i = 2, #parts do
        min = min3(min, parts[i].CFrame)
        max = max3(max, parts[i].CFrame)
    end
    
    self.boundingBox = {min = min, max = max}
end

function ESP:renderBox()
    if not self:updateTracking() then return end
    
    local boxSettings = self.interface.settings.box
    if not boxSettings.enabled then return end
    
    self:calculateBoundingBox()
    
    local min, max = self.boundingBox.min, self.boundingBox.max
    local topLeft = worldToScreen(Vector3.new(min.X, max.Y, min.Z))
    local topRight = worldToScreen(Vector3.new(max.X, max.Y, min.Z))
    local bottomLeft = worldToScreen(Vector3.new(min.X, min.Y, min.Z))
    local bottomRight = worldToScreen(Vector3.new(max.X, min.Y, min.Z))
    
    local boxOutline = self.boxes.outline:acquire({
        Color = parseColor(self, boxSettings.outlineColor, true),
        Thickness = boxSettings.outlineThickness,
        Visible = true
    })
    
    local boxFill = self.boxes.fill:acquire({
        Color = parseColor(self, boxSettings.color),
        Transparency = boxSettings.transparency,
        Visible = true
    })
end

function ESP:renderName()
    -- Similar implementation for name rendering
end

function ESP:renderHealthBar()
    -- Similar implementation for health bar
end

function ESP:render()
    self:renderBox()
    self:renderName()
    self:renderHealthBar()
    -- Add other rendering methods
end

function ESP:destroy()
    -- Release all drawing objects back to pool
    for _, pool in pairs(self.boxes) do
        for _, drawing in ipairs(pool.active) do
            pool:release(drawing)
        end
    end
    
    -- Reset all references
    self.character = nil
    self.humanoid = nil
    self.rootPart = nil
end

return ESP

local ESPManager = {}
ESPManager.__index = ESPManager

function ESPManager.new(config)
    local self = setmetatable({
        -- Core Components
        players = {},
        config = ConfigManager.new(config or {}),
        
        -- Performance Optimization
        updateQueue = {},
        lastFullUpdateTime = 0,
        
        -- Drawing Pools
        globalDrawingPools = {
            lines = DrawingPool.new("Line", 100),
            texts = DrawingPool.new("Text", 100),
            squares = DrawingPool.new("Square", 100)
        },
        
        -- Settings
        settings = {
            enabled = true,
            teamCheck = false,
            maxDistance = 1000,
            
            box = {
                enabled = true,
                color = Color3.new(1, 1, 1),
                outlineColor = Color3.new(0, 0, 0),
                transparency = 0.5,
                outlineThickness = 1
            },
            
            name = {
                enabled = true,
                font = Drawing.Fonts.Monospace,
                size = 13,
                color = Color3.new(1, 1, 1)
            },
            
            healthBar = {
                enabled = true,
                gradientColors = {
                    low = Color3.fromRGB(255, 0, 0),
                    high = Color3.fromRGB(0, 255, 0)
                }
            }
        }
    }, ESPManager)
    
    self:initialize()
    return self
end

function ESPManager:initialize()
    -- Player Added Handler
    local function onPlayerAdded(player)
        if player == localPlayer then return end
        
        local espObject = ESP.new(player, self)
        self.players[player] = espObject
    end
    
    -- Player Removal Handler
    local function onPlayerRemoving(player)
        local espObject = self.players[player]
        if espObject then
            espObject:destroy()
            self.players[player] = nil
        end
    end
    
    -- Initial Player Population
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localPlayer then
            onPlayerAdded(player)
        end
    end
    
    -- Connect Listeners
    players.PlayerAdded:Connect(onPlayerAdded)
    players.PlayerRemoving:Connect(onPlayerRemoving)
    
    -- Performance Monitoring Render Loop
    RunService.RenderStepped:Connect(function()
        self:update()
    end)
end

function ESPManager:update()
    local currentTime = tick()
    
    -- Optimize update frequency
    if currentTime - self.lastFullUpdateTime < 0.1 then return end
    self.lastFullUpdateTime = currentTime
    
    -- Parallel Update Processing
    local function processPlayer(player, espObject)
        if not self.settings.enabled then return end
        
        -- Team Check
        if self.settings.teamCheck and 
           player.Team == localPlayer.Team then 
            return 
        end
        
        -- Distance Check
        local distance = espObject.distance or math.huge
        if distance > self.settings.maxDistance then return end
        
        -- Render ESP
        safeFunctionCall(function()
            espObject:render()
        end)
    end
    
    -- Parallel Player Processing
    for player, espObject in pairs(self.players) do
        task.spawn(processPlayer, player, espObject)
    end
end

function ESPManager:toggleESP(state)
    self.settings.enabled = state ~= nil and state or not self.settings.enabled
    return self.settings.enabled
end

function ESPManager:setTeamCheck(state)
    self.settings.teamCheck = state
end

function ESPManager:setMaxDistance(distance)
    self.settings.maxDistance = distance
end

-- Keybind and UI Integration
function ESPManager:setupKeybinds()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Example Keybinds
        if input.KeyCode == Enum.KeyCode.RightControl then
            self:toggleESP()
        end
        
        if input.KeyCode == Enum.KeyCode.T then
            self:setTeamCheck(not self.settings.teamCheck)
        end
    end)
end

-- Configuration Export/Import
function ESPManager:exportConfig()
    return {
        enabled = self.settings.enabled,
        teamCheck = self.settings.teamCheck,
        maxDistance = self.settings.maxDistance,
        -- Add more exportable settings
    }
end

function ESPManager:importConfig(config)
    for key, value in pairs(config) do
        if self.settings[key] ~= nil then
            self.settings[key] = value
        end
    end
end

return ESPManager
