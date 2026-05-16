--[[
    SNOW EFFECT - Natural permanent snowfall
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local snowflakes = {}

local CONFIG = {
    Count = 600,
    Size = 0.5,
    Speed = 8,
    Spread = 250,
    FallDistance = 120,
    GroundY = 0,
}

local function getPlayerPos()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then return root.Position end
    local cam = Workspace.CurrentCamera
    if cam then return cam.CFrame.Position end
    return Vector3.new(0, 50, 0)
end

local function spawnFlake(center)
    local angle = math.random() * math.pi * 2
    local dist = math.random() * CONFIG.Spread
    local x = center.X + math.cos(angle) * dist
    local z = center.Z + math.sin(angle) * dist

    local part = Instance.new("Part")
    part.Name = "Snowflake"
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(CONFIG.Size, CONFIG.Size, CONFIG.Size)
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    part.Color = Color3.fromRGB(255, 255, 255)
    part.Material = Enum.Material.Neon
    part.Parent = Workspace

    local progress = math.random()
    local startY = center.Y + progress * CONFIG.FallDistance
    part.Position = Vector3.new(x, startY, z)

    table.insert(snowflakes, {
        Part = part,
        DriftX = (math.random() - 0.5) * 0.5,
        DriftZ = (math.random() - 0.5) * 0.2,
        StartY = startY,
        CurrentY = startY,
    })
end

local initialPos = getPlayerPos()
for i = 1, CONFIG.Count do
    spawnFlake(initialPos)
end

RunService.Heartbeat:Connect(function(dt)
    local p = getPlayerPos()
    local centerY = p.Y
    local groundLevel = CONFIG.GroundY

    local alive = {}
    for i = 1, #snowflakes do
        local flake = snowflakes[i]
        local part = flake.Part

        if part and part.Parent then
            flake.CurrentY = flake.CurrentY - CONFIG.Speed * dt

            if flake.CurrentY <= groundLevel then
                part:Destroy()
            else
                part.Position = Vector3.new(
                    part.Position.X + flake.DriftX * dt,
                    flake.CurrentY,
                    part.Position.Z + flake.DriftZ * dt
                )
                table.insert(alive, flake)
            end
        end
    end

    snowflakes = alive

    while #snowflakes < CONFIG.Count do
        local ok, err = pcall(function()
            spawnFlake(p)
        end)
        if not ok then
            warn("[Snow] Spawn error: " .. tostring(err))
            break
        end
    end
end)

print("[Snow] Natural permanent snowfall activated!")
