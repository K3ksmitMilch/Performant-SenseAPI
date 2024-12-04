-- services
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")

-- variables
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera
local viewportSize = camera.ViewportSize
local container = Instance.new("Folder", gethui and gethui() or game:GetService("CoreGui"))

-- locals
local floor = math.floor
local round = math.round
local sin = math.sin
local cos = math.cos
local clear = table.clear
local unpack = table.unpack
local find = table.find
local create = table.create
local fromMatrix = CFrame.fromMatrix

-- methods
local wtvp = camera.WorldToViewportPoint
local isA = workspace.IsA
local getPivot = workspace.GetPivot
local findFirstChild = workspace.FindFirstChild
local findFirstChildOfClass = workspace.FindFirstChildOfClass
local getChildren = workspace.GetChildren
local lerpColor = Color3.new().Lerp
local min2 = Vector2.zero.Min
local max2 = Vector2.zero.Max
local lerp2 = Vector2.zero.Lerp
local min3 = Vector3.zero.Min
local max3 = Vector3.zero.Max

-- constants
local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0)
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1)
local NAME_OFFSET = Vector2.new(0, 2)
local DISTANCE_OFFSET = Vector2.new(0, 2)
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

-- functions
local function isBodyPart(name)
    return name == "Head" or name:find("Torso") or name:find("Leg") or name:find("Arm")
end

local function getBoundingBox(parts)
    local min, max
    for _, part in ipairs(parts) do
        local cframe, size = part.CFrame, part.Size
        min = min3(min or cframe.Position, (cframe - size * 0.5).Position)
        max = max3(max or cframe.Position, (cframe + size * 0.5).Position)
    end
    local center = (min + max) * 0.5
    local front = Vector3.new(center.X, center.Y, max.Z)
    return CFrame.new(center, front), max - min
end

local function worldToScreen(world)
    local screen, inBounds = wtvp(camera, world)
    return Vector2.new(screen.X, screen.Y), inBounds, screen.Z
end

local function calculateCorners(cframe, size)
    local corners = create(#VERTICES)
    for i = 1, #VERTICES do
        corners[i] = worldToScreen((cframe + size * 0.5 * VERTICES[i]).Position)
    end

    local min = min2(viewportSize, unpack(corners))
    local max = max2(Vector2.zero, unpack(corners))
    return {
        corners = corners,
        topLeft = Vector2.new(floor(min.X), floor(min.Y)),
        topRight = Vector2.new(floor(max.X), floor(min.Y)),
        bottomLeft = Vector2.new(floor(min.X), floor(max.Y)),
        bottomRight = Vector2.new(floor(max.X), floor(max.Y))
    }
end

local function rotateVector(vector, radians)
    local x, y = vector.X, vector.Y
    local c, s = cos(radians), sin(radians)
    return Vector2.new(x * c - y * s, x * s + y * c)
end

local function parseColor(self, color, isOutline)
    if color == "Team Color" or (self.interface.sharedSettings.useTeamColor and not is
