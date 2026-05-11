
-- ================================================
-- BO MINH VI DAI v1.0
-- YUJI MODULO & SIDE DASH SYSTEM
-- ================================================
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local enabled = true
local orbiting = false

-- Infinite Yield loaded on startup (user opt-in, runs after Intro Dialog decision)
-- The actual loading is triggered from the toggle in "Other scripts" page

-- ================== CONFIG ==================

local ConfigVIP2 = {
	SPEED = 910,
	MAX_DASH = 0.35,
	MOVE_SPEED = 90,
	BF_DELAY = 0.1,
	BF_TOTAL_TIME = 0.59,
	BF_HIT3_ANIM = 0.1,
	REVERSE_DIR = false,
	HOTKEY = "C",
}

local ConfigSideDash = {
	SPEED = 700,
	MAX_DASH = 0.5,
	MOVE_SPEED = 100,
	DISTANCE = 15.0,
	REVERSE_DIR = false,
	HOTKEY = "X",
}

local godBFEnabled_VIP2 = false
local sideDashGodEnabled = false
local espEnabled = false
local aimbotEnabled = false
local infiniteYieldEnabled = false
local COOLDOWN = 0.01
local ORBIT_RADIUS = 6.0
local STOP_BEHIND_DIST = 6.0
local GROUND_OFFSET = 3.4
local MAX_START_DISTANCE = 15.0

local FACE_TARGET_AFTER = 0.5

local DASH_RIGHT_ID = "rbxassetid://75203303352791"
local DASH_LEFT_ID = "rbxassetid://117223862448096"

-- ================== SETTINGS ==================
local lastUse = 0
local orbitConn = nil
local targetRoot = nil
local bodyVelocity = nil
local bodyGyro = nil
local oldPlatformStand = false
local oldAutoRotate = true
local currentVelocity = Vector3.zero
local smoothedAngle = 0
local orbitDirection = 0
local aimbotLoaded = false
local infiniteYieldLoaded = false
local dashTrack = nil
local faceConn = nil

local rad = math.rad
local sin = math.sin
local cos = math.cos
local abs = math.abs
local clamp = math.clamp
local atan2 = math.atan2
local pi = math.pi
local huge = math.huge
local v3 = Vector3.new
local v3zero = Vector3.zero

local rpl = game:GetService("ReplicatedStorage")
local activateRE
pcall(function()
	activateRE = rpl.Knit.Knit.Services.DivergentFistService.RE.Activated
end)

-- ================== BLACK FLASH ==================
local function triggerDFist()
	local chr = player.Character
	if not chr then return false end
	local mset = chr:FindFirstChild("Moveset")
	if not mset then return false end
	local dfist = mset:FindFirstChild("Divergent Fist")
	if not dfist then return false end
	activateRE:FireServer(dfist)
	return true
end

local function blackflash_VIP2(tRoot)
	if not triggerDFist() then return end
	task.wait(0.29)
	if not triggerDFist() then return end
	task.wait(0.30)
	triggerDFist()
end

-- ================== CREDIT ==================
local function showCredit()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CreditGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.6, 0, 0.15, 0)
	textLabel.Position = UDim2.new(0.2, 0, 0.4, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "7luvsz"
	textLabel.TextColor3 = Color3.fromRGB(100, 180, 255)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.fromRGB(20, 40, 80)
	textLabel.Parent = screenGui
	local tweenInfo = TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeTween = TweenService:Create(textLabel, tweenInfo, {TextTransparency = 1, TextStrokeTransparency = 1})
	fadeTween:Play()
	fadeTween.Completed:Connect(function() screenGui:Destroy() end)
end
showCredit()

-- ================== HELPERS ==================
local function getRoot(char) return char and char:FindFirstChild("HumanoidRootPart") end
local function getHum(char) return char and char:FindFirstChildOfClass("Humanoid") end

local function getSignedAngle(tRoot, pos)
	local tPos = tRoot.Position
	local toPos = (pos - tPos)
	local flatTo = v3(toPos.X, 0, toPos.Z).Unit
	local fwd = v3(tRoot.CFrame.LookVector.X, 0, tRoot.CFrame.LookVector.Z).Unit
	local rgt = v3(tRoot.CFrame.RightVector.X, 0, tRoot.CFrame.RightVector.Z).Unit
	return atan2(flatTo:Dot(rgt), flatTo:Dot(fwd))
end

local function shortestDelta(from, to)
	local delta = to - from
	while delta > pi do delta = delta - 2 * pi end
	while delta < -pi do delta = delta + 2 * pi end
	return delta
end

local function getClosestTarget(modeToRun)
	local char = player.Character
	local root = getRoot(char)
	if not root then return nil end
	local myPos = root.Position
	local closest, closestDist = nil, huge
	for _, other in ipairs(Players:GetPlayers()) do
		if other == player or not other.Character then continue end
		local oRoot = getRoot(other.Character)
		local oHum = getHum(other.Character)
		if not oRoot or not oHum or oHum.Health <= 0 then continue end
		local dist = (oRoot.Position - myPos).Magnitude
		
		local activeDist = modeToRun == "SIDE_DASH" and ConfigSideDash.DISTANCE or MAX_START_DISTANCE
		if dist > activeDist then continue end
		
		if dist < closestDist then
			closestDist = dist
			closest = oRoot
		end
	end
	return closest
end

-- ================== ORBIT LOGIC ==================
local function stopFaceTarget()
	if faceConn then faceConn:Disconnect() faceConn = nil end
end

local function startFaceTarget(tRoot)
	stopFaceTarget()
	if not tRoot or not tRoot.Parent then return end
	local faceStart = tick()
	faceConn = RunService.RenderStepped:Connect(function()
		if tick() - faceStart > FACE_TARGET_AFTER then stopFaceTarget() return end
		if not tRoot or not tRoot.Parent then stopFaceTarget() return end
		local chr = player.Character
		local root = getRoot(chr)
		if not root then stopFaceTarget() return end
		local toTarget = (tRoot.Position - root.Position) * v3(1, 0, 1)
		if toTarget.Magnitude > 0.35 then
			local goalCF = CFrame.lookAt(root.Position, root.Position + toTarget.Unit)
			root.CFrame = root.CFrame:Lerp(goalCF, 0.88)
		end
	end)
end

local function stopOrbit()
	if not orbiting then return end
	orbiting = false
	local lastTarget = targetRoot
	targetRoot = nil
	currentVelocity = v3zero
	smoothedAngle = 0
	orbitDirection = 0
	if orbitConn then orbitConn:Disconnect() orbitConn = nil end
	if dashTrack then pcall(function() dashTrack:Stop() end) dashTrack = nil end
	local char = player.Character
	local root = getRoot(char)
	local hum = getHum(char)
	if root and bodyVelocity then
		bodyVelocity.Velocity = v3zero
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end
	if root and bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
	if hum then
		hum.PlatformStand = oldPlatformStand
		hum.AutoRotate = oldAutoRotate
		hum:Move(v3zero, false)
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end
	if lastTarget and FACE_TARGET_AFTER > 0 then
		startFaceTarget(lastTarget)
	end
end

local function startOrbit(modeToRun)
	local char = player.Character
	local root = getRoot(char)
	local hum = getHum(char)
	if not root or not hum then return end
	local tRoot = getClosestTarget(modeToRun)
	if not tRoot then return end
	stopOrbit()
	orbiting = true
	targetRoot = tRoot
	oldPlatformStand = hum.PlatformStand
	oldAutoRotate = hum.AutoRotate
	hum.PlatformStand = true
	hum.AutoRotate = false

	local cfg = ConfigVIP2
	if modeToRun == "VIP2" then cfg = ConfigVIP2
	elseif modeToRun == "SIDE_DASH" then cfg = ConfigSideDash end

	local initialAngle = getSignedAngle(tRoot, root.Position)
	local shortDelta = shortestDelta(initialAngle, pi)
	orbitDirection = shortDelta > 0 and -1 or 1
	if cfg.REVERSE_DIR then orbitDirection = -orbitDirection end

	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		local anim = Instance.new("Animation")
		if orbitDirection == -1 then
			anim.AnimationId = DASH_RIGHT_ID
		else
			anim.AnimationId = DASH_LEFT_ID
		end
		dashTrack = animator:LoadAnimation(anim)
		dashTrack.Looped = true
		dashTrack:Play()
		anim:Destroy()
	end

	local startTime = tick()
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {char}
	smoothedAngle = initialAngle

	local currentRadius = modeToRun == "SIDE_DASH" and 5.0 or 6.0
	local currentStopDist = modeToRun == "SIDE_DASH" and 5.0 or 6.0

	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = v3(65000, 3500, 65000)
	bodyVelocity.Velocity = v3zero
	bodyVelocity.Parent = root

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = v3(0, huge, 0)
	bodyGyro.P = 95000
	bodyGyro.D = 3000
	bodyGyro.Parent = root

	orbitConn = RunService.RenderStepped:Connect(function(dt)
		if not orbiting or not targetRoot or not targetRoot.Parent then stopOrbit() return end
		local elapsed = tick() - startTime
		local orbitDuration = cfg.BF_TOTAL_TIME
			and (cfg.BF_TOTAL_TIME + (cfg.BF_HIT3_ANIM or 0) - (cfg.BF_DELAY or 0))
			or (cfg.MAX_DASH + 0.1)
		if elapsed > orbitDuration then stopOrbit() return end
		local root = getRoot(player.Character)
		local hum = getHum(player.Character)
		if not hum or not root or hum.Health <= 0 then stopOrbit() return end

		local behindPos = tRoot.Position - tRoot.CFrame.LookVector * currentStopDist
		smoothedAngle = smoothedAngle + orbitDirection * rad(cfg.SPEED) * dt * 1.12
		local localOffset = v3(sin(smoothedAngle) * currentRadius, 0, -cos(smoothedAngle) * currentRadius)
		local orbitPos = tRoot.Position + tRoot.CFrame:VectorToWorldSpace(localOffset)
		local progress = clamp(elapsed / cfg.MAX_DASH, 0, 1)
		local goalFlat = orbitPos:Lerp(behindPos, progress ^ 1.5)
		local rayResult = Workspace:Raycast(root.Position + v3(0, 20, 0), v3(0, -50, 0), rayParams)
		local targetY = rayResult and (rayResult.Position.Y + GROUND_OFFSET) or (root.Position.Y + 0.3)
		local goalPos = v3(goalFlat.X, targetY, goalFlat.Z)
		local toGoal = goalPos - root.Position
		if toGoal.Magnitude > 0.5 then
			local targetVel = toGoal.Unit * (cfg.MOVE_SPEED * clamp(toGoal.Magnitude / 6, 0.4, 1.1))
			currentVelocity = currentVelocity:Lerp(targetVel, 0.18)
		else
			currentVelocity = currentVelocity * 0.85
		end

		if bodyVelocity then bodyVelocity.Velocity = currentVelocity end

		local toTargetFlat = (tRoot.Position - root.Position) * v3(1, 0, 1)
		if toTargetFlat.Magnitude > 0.35 then
			local goalCFrame = CFrame.lookAt(root.Position, root.Position + toTargetFlat.Unit)
			if bodyGyro then bodyGyro.CFrame = goalCFrame end
			root.CFrame = root.CFrame:Lerp(goalCFrame, 0.88)
		end
	end)
end

-- =====================================================
-- PROFESSIONAL DARK UI - BO MINH VI DAI
-- =====================================================

-- ================== THEME - PROFESSIONAL DARK ==================
local Theme = {
	-- Main colors
	Accent = Color3.fromRGB(170, 45, 45),      -- Dark red (ngầu)
	AccentDark = Color3.fromRGB(120, 30, 30), -- Darker accent
	Background = Color3.fromRGB(12, 12, 14),   -- Very dark background
	Surface = Color3.fromRGB(18, 18, 22),       -- Slightly lighter surface
	SurfaceHover = Color3.fromRGB(25, 25, 30),  -- Hover state
	SurfaceActive = Color3.fromRGB(32, 32, 38), -- Active state

	-- Text colors
	Text = Color3.fromRGB(220, 220, 230),       -- Light gray text
	TextMuted = Color3.fromRGB(140, 145, 160),  -- Muted text
	TextDim = Color3.fromRGB(90, 95, 110),       -- Dim text

	-- Border
	Border = Color3.fromRGB(40, 42, 50),        -- Subtle border
	BorderLight = Color3.fromRGB(55, 58, 70),   -- Light border

	-- Status colors
	Success = Color3.fromRGB(70, 160, 100),     -- Muted green
	Warning = Color3.fromRGB(180, 140, 60),     -- Muted yellow
	Danger = Color3.fromRGB(180, 70, 70),       -- Muted red
	Purple = Color3.fromRGB(160, 40, 40),       -- Dark red purple
}

-- ================== GUI ==================
local function createGUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BoMinhViDai_GUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- ========== MAIN WINDOW ==========
	local mainWindow = Instance.new("Frame")
	mainWindow.Name = "MainWindow"
	mainWindow.Size = UDim2.new(0, 680, 0, 500)
	mainWindow.Position = UDim2.new(0.5, -340, 0.5, -250)
	mainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
	mainWindow.BackgroundColor3 = Theme.Background
	mainWindow.BorderSizePixel = 0
	mainWindow.ClipsDescendants = true
	mainWindow.Parent = screenGui
	Instance.new("UICorner", mainWindow).CornerRadius = UDim.new(0, 12)

	-- Shadow Layer
	local shadow = Instance.new("ImageLabel")
	shadow.Size = UDim2.new(1, 100, 1, 100)
	shadow.Position = UDim2.new(0, -50, 0, -50)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://8992230677"
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 0.6
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(99, 99, 99, 99)
	shadow.ZIndex = 0
	shadow.Parent = mainWindow

	-- ========== TOPBAR ==========
	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.Size = UDim2.new(1, 0, 0, 56)
	topbar.BackgroundColor3 = Theme.Surface
	topbar.BorderSizePixel = 0
	topbar.Parent = mainWindow

	-- Topbar divider
	local topbarDivider = Instance.new("Frame")
	topbarDivider.Size = UDim2.new(1, 0, 0, 1)
	topbarDivider.Position = UDim2.new(0, 0, 1, 0)
	topbarDivider.BackgroundColor3 = Theme.Border
	topbarDivider.BorderSizePixel = 0
	topbarDivider.Parent = topbar

	-- Logo Icon Container
	local logoContainer = Instance.new("Frame")
	logoContainer.Size = UDim2.new(0, 40, 0, 40)
	logoContainer.Position = UDim2.new(0, 14, 0.5, -20)
	logoContainer.BackgroundTransparency = 1
	logoContainer.Parent = topbar

	local logoIcon = Instance.new("ImageLabel")
	logoIcon.Size = UDim2.new(1, 0, 1, 0)
	logoIcon.BackgroundTransparency = 1
	logoIcon.Image = "rbxassetid://132541023644406"
	logoIcon.ScaleType = Enum.ScaleType.Fit
	logoIcon.Parent = logoContainer

	-- Title and Author
	local titleContainer = Instance.new("Frame")
	titleContainer.Size = UDim2.new(0, 280, 0, 40)
	titleContainer.Position = UDim2.new(0, 62, 0.5, -20)
	titleContainer.BackgroundTransparency = 1
	titleContainer.Parent = topbar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, 0, 0, 24)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "Bố Minh VĨ ĐẠI"
	titleLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
	titleLbl.TextSize = 18
	titleLbl.TextColor3 = Theme.Text
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = titleContainer

	local authorLbl = Instance.new("TextLabel")
	authorLbl.Size = UDim2.new(1, 0, 0, 16)
	authorLbl.Position = UDim2.new(0, 0, 0, 22)
	authorLbl.BackgroundTransparency = 1
	authorLbl.Text = "by 7luvsz | Jujutsu Shenanigans"
	authorLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
	authorLbl.TextSize = 11
	authorLbl.TextColor3 = Theme.TextMuted
	authorLbl.TextXAlignment = Enum.TextXAlignment.Left
	authorLbl.Parent = titleContainer

	-- Window Buttons
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Size = UDim2.new(0, 80, 0, 30)
	buttonsContainer.Position = UDim2.new(1, -88, 0.5, -15)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.Parent = topbar

	local btnLayout = Instance.new("UIListLayout", buttonsContainer)
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding = UDim.new(0, 10)
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	-- Minimize Button
	local minBtn = Instance.new("TextButton")
	minBtn.Size = UDim2.new(0, 30, 0, 30)
	minBtn.BackgroundColor3 = Theme.Warning
	minBtn.BackgroundTransparency = 0.5
	minBtn.Text = ""
	minBtn.Parent = buttonsContainer
	Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

	local minIcon = Instance.new("TextLabel")
	minIcon.Size = UDim2.new(1, 0, 1, 0)
	minIcon.BackgroundTransparency = 1
	minIcon.Text = "-"
	minIcon.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
	minIcon.TextSize = 16
	minIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
	minIcon.Parent = minBtn

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.BackgroundColor3 = Theme.Danger
	closeBtn.BackgroundTransparency = 0.6
	closeBtn.Text = ""
	closeBtn.Parent = buttonsContainer
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

	local closeIcon = Instance.new("TextLabel")
	closeIcon.Size = UDim2.new(1, 0, 1, 0)
	closeIcon.BackgroundTransparency = 1
	closeIcon.Text = "X"
	closeIcon.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
	closeIcon.TextSize = 12
	closeIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeIcon.Parent = closeBtn

	-- Button Hover Effects
	minBtn.MouseEnter:Connect(function()
		TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
	end)
	minBtn.MouseLeave:Connect(function()
		TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play()
	end)

	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.6}):Play()
	end)

	closeBtn.MouseButton1Click:Connect(function()
		TweenService:Create(mainWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 0, 0, 0)}):Play()
		task.wait(0.3)
		screenGui:Destroy()
	end)

	-- Minimize Button - Draggable indicator at top-center
	minBtn.MouseButton1Click:Connect(function()
		mainWindow.Visible = false
		local indicator = Instance.new("Frame")
		indicator.Name = "MinimizeIndicator"
		indicator.Size = UDim2.new(0, 160, 0, 36)
		indicator.Position = UDim2.new(0.5, -80, 0, 20)
		indicator.AnchorPoint = Vector2.new(0.5, 0)
		indicator.BackgroundColor3 = Theme.Surface
		indicator.BackgroundTransparency = 0.15
		indicator.BorderSizePixel = 0
		indicator.Parent = screenGui
		Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 8)
		
		local indStroke = Instance.new("UIStroke", indicator)
		indStroke.Color = Theme.Accent
		indStroke.Thickness = 1.5
		indStroke.Transparency = 0.4
		
		local indLbl = Instance.new("TextLabel")
		indLbl.Size = UDim2.new(1, 0, 1, 0)
		indLbl.BackgroundTransparency = 1
		indLbl.Text = "BMVD - Click to open"
		indLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
		indLbl.TextSize = 12
		indLbl.TextColor3 = Theme.Text
		indLbl.Parent = indicator

		local dragging, dragStart, startPos
		local isClick = false
		local clickProcessed = false

		indicator.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				isClick = true
				clickProcessed = false
				dragStart = i.Position
				startPos = indicator.Position
			end
		end)

		indicator.InputChanged:Connect(function(i)
			if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = i.Position - dragStart
				local dist = math.sqrt(delta.X * delta.X + delta.Y * delta.Y)
				if dist > 5 then
					isClick = false
				end
				indicator.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
				dragStart = i.Position
			end
		end)

		indicator.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				if isClick and not clickProcessed then
					clickProcessed = true
					indicator:Destroy()
					mainWindow.Visible = true
					TweenService:Create(mainWindow, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = UDim2.new(0, 680, 0, 500)}):Play()
				end
				dragging = false
			end
		end)

		-- Hover effect
		indicator.MouseEnter:Connect(function()
			TweenService:Create(indicator, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
			TweenService:Create(indStroke, TweenInfo.new(0.2), {Transparency = 0.2}):Play()
		end)
		indicator.MouseLeave:Connect(function()
			TweenService:Create(indicator, TweenInfo.new(0.2), {BackgroundTransparency = 0.15}):Play()
			TweenService:Create(indStroke, TweenInfo.new(0.2), {Transparency = 0.4}):Play()
		end)
	end)

	-- Dragging
	local dragging, dragStart, startPos
	topbar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true; dragStart = i.Position; startPos = mainWindow.Position
		end
	end)
	topbar.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - dragStart
			mainWindow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	-- ========== SIDEBAR ==========
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, 200, 1, -57)
	sidebar.Position = UDim2.new(0, 0, 0, 57)
	sidebar.BackgroundColor3 = Theme.Surface
	sidebar.BorderSizePixel = 0
	sidebar.Parent = mainWindow

	-- Sidebar divider
	local sideDivider = Instance.new("Frame")
	sideDivider.Size = UDim2.new(0, 1, 1, 0)
	sideDivider.Position = UDim2.new(1, 0, 0, 0)
	sideDivider.BackgroundColor3 = Theme.Border
	sideDivider.BorderSizePixel = 0
	sideDivider.Parent = sidebar

	-- Sidebar Title
	local sideTitle = Instance.new("TextLabel")
	sideTitle.Size = UDim2.new(1, -20, 0, 20)
	sideTitle.Position = UDim2.new(0, 16, 0, 14)
	sideTitle.BackgroundTransparency = 1
	sideTitle.Text = "NAVIGATION"
	sideTitle.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
	sideTitle.TextSize = 10
	sideTitle.TextColor3 = Theme.Accent
	sideTitle.TextTransparency = 0.3
	sideTitle.TextXAlignment = Enum.TextXAlignment.Left
	sideTitle.Parent = sidebar

	-- ========== CONTENT AREA ==========
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -201, 1, -57)
	content.Position = UDim2.new(0, 201, 0, 57)
	content.BackgroundTransparency = 1
	content.ClipsDescendants = true
	content.Parent = mainWindow

	-- ========== TABS ==========
	local tabs = {
		{name = "Home", iconText = "H"},
		{name = "Combat", iconText = "C"},
		{name = "Config", iconText = "S"},
		{name = "Other scripts", iconText = "O"},
	}

	local pages = {}
	local sideButtons = {}
	local activeTab = nil

	local function makePage(name)
		local page = Instance.new("ScrollingFrame")
		page.Name = name
		page.Size = UDim2.new(1, 0, 1, 0)
		page.BackgroundTransparency = 1
		page.ScrollBarThickness = 4
		page.ScrollBarImageColor3 = Theme.Accent
		page.ScrollBarImageTransparency = 0.4
		page.BorderSizePixel = 0
		page.Visible = false
		page.CanvasSize = UDim2.new(0, 0, 0, 0)
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.Parent = content
		local layout = Instance.new("UIListLayout", page)
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		local pad = Instance.new("UIPadding", page)
		pad.PaddingTop = UDim.new(0, 16)
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingRight = UDim.new(0, 16)
		pages[name] = page
		return page
	end

	for _, tab in ipairs(tabs) do
		makePage(tab.name)
	end

	-- Select Tab Function
	local function selectTab(tabName)
		if activeTab == tabName then return end
		activeTab = tabName

		for name, page in pairs(pages) do
			if name == tabName then
				page.Visible = true
			else
				page.Visible = false
			end
		end

		for _, btn in pairs(sideButtons) do
			local btnName = btn:GetAttribute("TabName")
			local iconLbl = btn:FindFirstChild("IconLabel")
			local textLbl = btn:FindFirstChild("TextLabel")
			
			if btnName == tabName then
				TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.2}):Play()
				if iconLbl then TweenService:Create(iconLbl, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Accent}):Play() end
				if textLbl then TweenService:Create(textLbl, TweenInfo.new(0.2), {TextColor3 = Theme.Text}):Play() end
			else
				TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
				if iconLbl then TweenService:Create(iconLbl, TweenInfo.new(0.2), {BackgroundColor3 = Theme.SurfaceHover}):Play() end
				if textLbl then TweenService:Create(textLbl, TweenInfo.new(0.2), {TextColor3 = Theme.TextMuted}):Play() end
			end
		end
	end

	-- Create Sidebar Buttons
	for i, tab in ipairs(tabs) do
		local btn = Instance.new("TextButton")
		btn.Name = "Tab_" .. tab.name
		btn:SetAttribute("TabName", tab.name)
		btn.Size = UDim2.new(1, -12, 0, 48)
		btn.Position = UDim2.new(0, 6, 0, 36 + (i - 1) * 54)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = sidebar
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

		local btnBg = Instance.new("Frame")
		btnBg.Size = UDim2.new(1, 0, 1, 0)
		btnBg.BackgroundColor3 = Theme.Accent
		btnBg.BackgroundTransparency = 1
		btnBg.Parent = btn
		Instance.new("UICorner", btnBg).CornerRadius = UDim.new(0, 8)

		-- Icon
		local iconLbl = Instance.new("TextLabel")
		iconLbl.Name = "IconLabel"
		iconLbl.Size = UDim2.new(0, 36, 0, 36)
		iconLbl.Position = UDim2.new(0, 6, 0.5, -18)
		iconLbl.BackgroundColor3 = Theme.SurfaceHover
		iconLbl.BackgroundTransparency = 0.3
		iconLbl.Text = tab.iconText
		iconLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
		iconLbl.TextSize = 14
		iconLbl.TextColor3 = Theme.TextMuted
		iconLbl.Parent = btn
		Instance.new("UICorner", iconLbl).CornerRadius = UDim.new(0, 6)

		-- Text
		local textLbl = Instance.new("TextLabel")
		textLbl.Name = "TextLabel"
		textLbl.Size = UDim2.new(1, -54, 1, 0)
		textLbl.Position = UDim2.new(0, 50, 0, 0)
		textLbl.BackgroundTransparency = 1
		textLbl.Text = tab.name
		textLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold)
		textLbl.TextSize = 14
		textLbl.TextColor3 = Theme.TextMuted
		textLbl.TextXAlignment = Enum.TextXAlignment.Left
		textLbl.Parent = btn

		sideButtons[#sideButtons + 1] = btn
		btn.MouseButton1Click:Connect(function() selectTab(tab.name) end)
		btn.MouseEnter:Connect(function()
			if activeTab ~= tab.name then
				TweenService:Create(btnBg, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play()
				TweenService:Create(iconLbl, TweenInfo.new(0.15), {BackgroundColor3 = Theme.SurfaceActive, TextColor3 = Theme.Text}):Play()
				TweenService:Create(textLbl, TweenInfo.new(0.15), {TextColor3 = Theme.Text}):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			if activeTab ~= tab.name then
				TweenService:Create(btnBg, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
				TweenService:Create(iconLbl, TweenInfo.new(0.15), {BackgroundColor3 = Theme.SurfaceHover, TextColor3 = Theme.TextMuted}):Play()
				TweenService:Create(textLbl, TweenInfo.new(0.15), {TextColor3 = Theme.TextMuted}):Play()
			end
		end)
	end

	-- ========== COMPONENTS ==========

	-- Section Header
	local function addSection(parent, title, order)
		local section = Instance.new("Frame")
		section.Size = UDim2.new(1, 0, 0, 34)
		section.BackgroundTransparency = 1
		section.LayoutOrder = order
		section.Parent = parent

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, 0, 0, 22)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = title
		titleLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
		titleLbl.TextSize = 13
		titleLbl.TextColor3 = Theme.Accent
		titleLbl.TextTransparency = 0.1
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Parent = section

		local divider = Instance.new("Frame")
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.new(0, 0, 0, 28)
		divider.BackgroundColor3 = Theme.Border
		divider.BackgroundTransparency = 0.3
		divider.BorderSizePixel = 0
		divider.Parent = section

		return section
	end

	-- Card (Container)
	local function addCard(parent, order)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 0)
		card.BackgroundColor3 = Theme.Surface
		card.BackgroundTransparency = 0.4
		card.LayoutOrder = order
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.Parent = parent
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
		
		local cardStroke = Instance.new("UIStroke", card)
		cardStroke.Color = Theme.Border
		cardStroke.Thickness = 1
		cardStroke.Transparency = 0.6

		local cardPad = Instance.new("UIPadding", card)
		cardPad.PaddingTop = UDim.new(0, 10)
		cardPad.PaddingBottom = UDim.new(0, 10)
		cardPad.PaddingLeft = UDim.new(0, 10)
		cardPad.PaddingRight = UDim.new(0, 10)

		local cardLayout = Instance.new("UIListLayout", card)
		cardLayout.Padding = UDim.new(0, 8)
		cardLayout.SortOrder = Enum.SortOrder.LayoutOrder

		return card
	end

	-- Toggle Component
	local function addToggle(parent, label, description, initial, order, callback)
		local toggleRow = Instance.new("Frame")
		toggleRow.Size = UDim2.new(1, 0, 0, 52)
		toggleRow.BackgroundTransparency = 1
		toggleRow.LayoutOrder = order
		toggleRow.Parent = parent

		local contentFrame = Instance.new("Frame")
		contentFrame.Size = UDim2.new(1, 0, 1, 0)
		contentFrame.BackgroundColor3 = Theme.Surface
		contentFrame.BackgroundTransparency = 0.5
		contentFrame.Parent = toggleRow
		Instance.new("UICorner", contentFrame).CornerRadius = UDim.new(0, 8)

		local textContainer = Instance.new("Frame")
		textContainer.Size = UDim2.new(1, -70, 1, 0)
		textContainer.Position = UDim2.new(0, 14, 0, 0)
		textContainer.BackgroundTransparency = 1
		textContainer.Parent = contentFrame

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, 0, 0, 20)
		nameLbl.Position = UDim2.new(0, 0, 0, 6)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = label
		nameLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold)
		nameLbl.TextSize = 14
		nameLbl.TextColor3 = Theme.Text
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Parent = textContainer

		if description then
			local descLbl = Instance.new("TextLabel")
			descLbl.Size = UDim2.new(1, 0, 0, 14)
			descLbl.Position = UDim2.new(0, 0, 0, 26)
			descLbl.BackgroundTransparency = 1
			descLbl.Text = description
			descLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
			descLbl.TextSize = 11
			descLbl.TextColor3 = Theme.TextDim
			descLbl.TextXAlignment = Enum.TextXAlignment.Left
			descLbl.Parent = textContainer
		end

		local toggleBg = Instance.new("TextButton")
		toggleBg.Size = UDim2.new(0, 50, 0, 26)
		toggleBg.Position = UDim2.new(1, -60, 0.5, -13)
		toggleBg.BackgroundColor3 = initial and Theme.Accent or Theme.Surface
		toggleBg.BackgroundTransparency = initial and 0 or 0.5
		toggleBg.Text = ""
		toggleBg.AutoButtonColor = false
		toggleBg.Parent = contentFrame
		Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)

		local toggleCircle = Instance.new("Frame")
		toggleCircle.Size = UDim2.new(0, 20, 0, 20)
		toggleCircle.Position = initial and UDim2.new(1, -24, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
		toggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		toggleCircle.Parent = toggleBg
		Instance.new("UICorner", toggleCircle).CornerRadius = UDim.new(1, 0)

		local state = initial
		local function updateToggle()
			TweenService:Create(toggleBg, TweenInfo.new(0.22), {
				BackgroundColor3 = state and Theme.Accent or Theme.Surface,
				BackgroundTransparency = state and 0 or 0.5
			}):Play()
			TweenService:Create(toggleCircle, TweenInfo.new(0.22, Enum.EasingStyle.Back), {
				Position = state and UDim2.new(1, -24, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
			}):Play()
		end

		toggleBg.MouseButton1Click:Connect(function()
			state = not state
			updateToggle()
			if callback then callback(state) end
		end)

		return toggleRow, function(newState)
			state = newState
			updateToggle()
		end
	end

	-- Button Component
	local function addButton(parent, label, color, order, callback)
		color = color or Theme.Accent
		local btn = Instance.new("TextButton")
		local origWidth = 0
		-- Store original size for tweening
		local origSize = UDim2.new(1, 0, 0, 44)
		btn.Size = origSize
		btn.BackgroundColor3 = color
		btn.BackgroundTransparency = 0.15
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.LayoutOrder = order
		btn.Parent = parent
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

		local btnStroke = Instance.new("UIStroke", btn)
		btnStroke.Color = color
		btnStroke.Thickness = 1
		btnStroke.Transparency = 0.5

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
		lbl.TextSize = 14
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.Parent = btn

		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
			TweenService:Create(btnStroke, TweenInfo.new(0.15), {Transparency = 0.2}):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
			TweenService:Create(btnStroke, TweenInfo.new(0.15), {Transparency = 0.5}):Play()
		end)
		btn.MouseButton1Click:Connect(function()
			-- Fixed tween: scale down then back up using proper Vector2
			local tweenIn = TweenService:Create(btn, TweenInfo.new(0.06, Enum.EasingStyle.Back), {
				Size = UDim2.new(1, 0, 0, 40)
			})
			tweenIn:Play()
			tweenIn.Completed:Connect(function()
				local tweenOut = TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back), {
					Size = origSize
				})
				tweenOut:Play()
			end)
			if callback then callback() end
		end)
		return btn
	end

	-- Input Component
	local function addInput(parent, label, configKey, order, configTable)
		local inputRow = Instance.new("Frame")
		inputRow.Size = UDim2.new(1, 0, 0, 54)
		inputRow.BackgroundTransparency = 1
		inputRow.LayoutOrder = order
		inputRow.Parent = parent

		local inputBg = Instance.new("Frame")
		inputBg.Size = UDim2.new(1, 0, 1, 0)
		inputBg.BackgroundColor3 = Theme.Surface
		inputBg.BackgroundTransparency = 0.5
		inputBg.Parent = inputRow
		Instance.new("UICorner", inputBg).CornerRadius = UDim.new(0, 8)

		local inputStroke = Instance.new("UIStroke", inputBg)
		inputStroke.Color = Theme.Border
		inputStroke.Thickness = 1
		inputStroke.Transparency = 0.5

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.45, -14, 1, 0)
		lbl.Position = UDim2.new(0, 14, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
		lbl.TextSize = 13
		lbl.TextColor3 = Theme.Text
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = inputBg

		local tb = Instance.new("TextBox")
		tb.Size = UDim2.new(0.45, -16, 0, 32)
		tb.Position = UDim2.new(0.55, 8, 0.5, -16)
		tb.BackgroundColor3 = Theme.Background
		tb.BackgroundTransparency = 0.3
		tb.TextColor3 = Theme.Text
		tb.Text = tostring(configTable[configKey])
		tb.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
		tb.TextSize = 13
		tb.ClearTextOnFocus = true
		tb.TextXAlignment = Enum.TextXAlignment.Center
		tb.Parent = inputBg
		Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)

		local tbStroke = Instance.new("UIStroke", tb)
		tbStroke.Color = Theme.Accent
		tbStroke.Thickness = 1
		tbStroke.Transparency = 0.6

		tb.FocusLost:Connect(function()
			local txt = tb.Text
			if type(configTable[configKey]) == "number" then
				local num = tonumber(txt)
				if num then configTable[configKey] = num; tb.Text = tostring(num)
				else tb.Text = tostring(configTable[configKey]) end
			else
				if #txt > 0 then configTable[configKey] = txt; tb.Text = txt
				else tb.Text = configTable[configKey] end
			end
		end)
		return tb
	end

	-- Info Row Component
	local function addInfo(parent, label, value, valueColor, order)
		valueColor = valueColor or Theme.Accent
		local infoRow = Instance.new("Frame")
		infoRow.Size = UDim2.new(1, 0, 0, 38)
		infoRow.BackgroundTransparency = 1
		infoRow.LayoutOrder = order
		infoRow.Parent = parent

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.6, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
		lbl.TextSize = 13
		lbl.TextColor3 = Theme.TextMuted
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = infoRow

		local valLbl = Instance.new("TextLabel")
		valLbl.Name = "Value"
		valLbl.Size = UDim2.new(0.4, 0, 1, 0)
		valLbl.Position = UDim2.new(0.6, 0, 0, 0)
		valLbl.BackgroundTransparency = 1
		valLbl.Text = value
		valLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
		valLbl.TextSize = 13
		valLbl.TextColor3 = valueColor
		valLbl.TextXAlignment = Enum.TextXAlignment.Right
		valLbl.Parent = infoRow
		return valLbl
	end

	-- Space
	local function addSpace(parent, height, order)
		local space = Instance.new("Frame")
		space.Size = UDim2.new(1, 0, 0, height or 10)
		space.BackgroundTransparency = 1
		space.LayoutOrder = order or -1
		space.Parent = parent
		return space
	end

	-- ========== PAGE: HOME ==========
	local pageHome = pages["Home"]

	addSection(pageHome, "SCRIPT STATUS", 1)
	local card1 = addCard(pageHome, 2)
	local statusVal = addInfo(card1, "Status", "ONLINE", Theme.Success, 1)

	addSpace(pageHome, 6, 3)
	addSection(pageHome, "INFORMATION", 4)
	local card3 = addCard(pageHome, 5)
	addInfo(card3, "Author", "7luvsz", Theme.Accent, 1)
	addInfo(card3, "Game", "Jujutsu Shenanigans", Theme.Text, 2)
	addInfo(card3, "Version", "v1.0", Theme.Purple, 3)

	addSpace(pageHome, 6, 6)
	addSection(pageHome, "LINKS", 7)
	local card4 = addCard(pageHome, 8)
	addButton(card4, "Join Discord", Color3.fromRGB(88, 101, 242), 1, function()
		setclipboard("https://discord.gg/yourdiscordlink")
		-- Show notification
		local notification = Instance.new("TextLabel")
		notification.Size = UDim2.new(0, 280, 0, 36)
		notification.Position = UDim2.new(0.5, -140, 0.85, 0)
		notification.BackgroundColor3 = Theme.Surface
		notification.BackgroundTransparency = 0.2
		notification.Text = "Link copied to clipboard!"
		notification.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
		notification.TextSize = 13
		notification.TextColor3 = Theme.Text
		notification.Parent = screenGui
		Instance.new("UICorner", notification).CornerRadius = UDim.new(0, 8)
		notification:TweenPosition(UDim2.new(0.5, -140, 0.85, -40), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.3, true)
		task.wait(2)
		notification:TweenPosition(UDim2.new(0.5, -140, 0.85, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true)
		task.wait(0.3)
		notification:Destroy()
	end)

	addSpace(pageHome, 6, 9)
	addSection(pageHome, "THANK YOU", 10)
	local thankCard = addCard(pageHome, 11)

	local thankLbl = Instance.new("TextLabel")
	thankLbl.Size = UDim2.new(1, 0, 0, 30)
	thankLbl.BackgroundTransparency = 1
	thankLbl.Text = "Thank you for using this script!"
	thankLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
	thankLbl.TextSize = 16
	thankLbl.TextColor3 = Theme.Text
	thankLbl.Parent = thankCard

	local thankLbl2 = Instance.new("TextLabel")
	thankLbl2.Size = UDim2.new(1, 0, 0, 24)
	thankLbl2.Position = UDim2.new(0, 0, 0, 28)
	thankLbl2.BackgroundTransparency = 1
	thankLbl2.Text = "Your support means everything to me"
	thankLbl2.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
	thankLbl2.TextSize = 12
	thankLbl2.TextTransparency = 0.3
	thankLbl2.TextColor3 = Theme.TextMuted
	thankLbl2.Parent = thankCard

	-- Rainbow gradient animation for thank you text
	task.spawn(function()
		local t = 0
		while thankCard.Parent and thankCard.Parent.Parent do
			t = t + 0.015
			local hue1 = (t % 1)
			local hue2 = ((t + 0.5) % 1)
			thankLbl.TextColor3 = Color3.fromHSV(hue1, 0.7, 1)
			thankLbl2.TextColor3 = Color3.fromHSV(hue2, 0.5, 0.9)
			task.wait(0.02)
		end
	end)

	-- ========== PAGE: COMBAT ==========
	local pageCombat = pages["Combat"]

	addSection(pageCombat, "COMBAT MODES", 1)
	local combatCard = addCard(pageCombat, 2)

	local toggleYuji, updateYuji = addToggle(combatCard, "Yuji Modulo", "Black Flash Combo System", godBFEnabled_VIP2, 1, function(state)
		godBFEnabled_VIP2 = state
	end)

	local toggleSide, updateSide = addToggle(combatCard, "Side Dash GOD", "Instant Dash Behind Target", sideDashGodEnabled, 2, function(state)
		sideDashGodEnabled = state
	end)

	addSpace(combatCard, 4, 3)
	addSection(combatCard, "ESP SYSTEM", 4)
	addToggle(combatCard, "ESP", "See enemies through walls", false, 5, function(state)
		espEnabled = state
	end)
	addToggle(combatCard, "Box ESP", "Draw box around players", true, 6, function(state) end)
	addToggle(combatCard, "Health Bar", "Show enemy health", true, 7, function(state) end)
	addToggle(combatCard, "Name ESP", "Show player names", true, 8, function(state) end)
	addToggle(combatCard, "Skeleton ESP", "Draw player bones", true, 9, function(state) end)
	addToggle(combatCard, "Chams", "Highlight player models", false, 10, function(state) end)

	addSpace(pageCombat, 6, 11)
	addSection(pageCombat, "HOTKEYS", 12)
	local hotkeyCard = addCard(pageCombat, 13)
	addInfo(hotkeyCard, "Yuji Modulo Key", ConfigVIP2.HOTKEY, Theme.Accent, 1)
	addInfo(hotkeyCard, "Side Dash Key", ConfigSideDash.HOTKEY, Theme.Purple, 2)
	addInfo(hotkeyCard, "Toggle UI", "INSERT", Theme.Text, 3)

	-- ========== PAGE: CONFIG ==========
	local pageConfig = pages["Config"]

	addSection(pageConfig, "YUJI MODULO", 1)
	local yujiCard = addCard(pageConfig, 2)
	addInput(yujiCard, "Speed", "SPEED", 1, ConfigVIP2)
	addInput(yujiCard, "Max Dash", "MAX_DASH", 2, ConfigVIP2)
	addInput(yujiCard, "Black flash before dash", "BF_DELAY", 4, ConfigVIP2)
	addInput(yujiCard, "Hotkey", "HOTKEY", 5, ConfigVIP2)

	addSpace(pageConfig, 6, 3)
	addSection(pageConfig, "SIDE DASH", 4)
	local sideCard = addCard(pageConfig, 5)
	addInput(sideCard, "Speed", "SPEED", 1, ConfigSideDash)
	addInput(sideCard, "Max Dash", "MAX_DASH", 2, ConfigSideDash)
	addInput(sideCard, "Distance", "DISTANCE", 3, ConfigSideDash)
	addInput(sideCard, "Hotkey", "HOTKEY", 4, ConfigSideDash)

	addSpace(pageConfig, 6, 6)
	addSection(pageConfig, "RESET", 7)
	local resetCard = addCard(pageConfig, 8)
	addButton(resetCard, "Reset All Settings", Theme.Danger, 1, function()
		ConfigVIP2.SPEED = 800; ConfigVIP2.MAX_DASH = 0.35; ConfigVIP2.MOVE_SPEED = 100; ConfigVIP2.BF_DELAY = 0.1; ConfigVIP2.REVERSE_DIR = false; ConfigVIP2.HOTKEY = "C"; ConfigVIP2.BF_TOTAL_TIME = 0.59; ConfigVIP2.BF_HIT3_ANIM = 0.1
		ConfigSideDash.SPEED = 600; ConfigSideDash.MAX_DASH = 0.3; ConfigSideDash.MOVE_SPEED = 100; ConfigSideDash.DISTANCE = 20.0; ConfigSideDash.REVERSE_DIR = false; ConfigSideDash.HOTKEY = "X"
	end)

	-- ========== PAGE: OTHER SCRIPTS ==========
	local pageOtherScripts = pages["Other scripts"]

	addSection(pageOtherScripts, "SCRIPTS", 1)
	local scriptsCard = addCard(pageOtherScripts, 2)

	addToggle(scriptsCard, "Infinite Yield", "Admin commands script", false, 1, function(state)
		infiniteYieldEnabled = state
		if state and not infiniteYieldLoaded then
			infiniteYieldLoaded = true
			task.spawn(function()
				loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
			end)
		end
	end)

	addToggle(scriptsCard, "Aimbot Script (WORK ON PC)", "Auto-target nearest enemy", false, 2, function(state)
		aimbotEnabled = state
		if state and not aimbotLoaded then
			aimbotLoaded = true
			task.spawn(function()
				loadstring(game:HttpGet("https://raw.githubusercontent.com/ttwizz/Open-Aimbot/master/source.lua", true))()
			end)
		end
	end)

	-- ========== ENTRANCE ANIMATION ==========
	mainWindow.Size = UDim2.new(0, 0, 0, 0)
	mainWindow.BackgroundTransparency = 1
	TweenService:Create(mainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 680, 0, 500)
	}):Play()
	task.delay(0.3, function()
		TweenService:Create(mainWindow, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
	end)

	-- Select first tab
	selectTab("Home")

	-- Status update loop
	task.spawn(function()
		while screenGui.Parent do
			if statusVal then
				statusVal.Text = enabled and "ONLINE" or "OFFLINE"
				statusVal.TextColor3 = enabled and Theme.Success or Theme.Danger
			end
			if updateYuji then updateYuji(godBFEnabled_VIP2) end
			if updateSide then updateSide(sideDashGodEnabled) end
			task.wait(0.5)
		end
	end)

	return screenGui
end

-- ================== INTRO DIALOG ==================
local function showIntroDialog()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "IntroDialog"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Overlay
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui
	TweenService:Create(overlay, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.4}):Play()

	-- Dialog Card
	local dialog = Instance.new("Frame")
	dialog.Size = UDim2.new(0, 400, 0, 320)
	dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.BackgroundColor3 = Theme.Background
	dialog.BorderSizePixel = 0
	dialog.Parent = screenGui
	Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 16)

	-- Shadow
	local shadow = Instance.new("ImageLabel")
	shadow.Size = UDim2.new(1, 60, 1, 60)
	shadow.Position = UDim2.new(0, -30, 0, -30)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://5554236805"
	shadow.ImageColor3 = Theme.Accent
	shadow.ImageTransparency = 0.6
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(23, 23, 277, 277)
	shadow.ZIndex = 0
	shadow.Parent = dialog

	-- Accent Line
	local accentLine = Instance.new("Frame")
	accentLine.Size = UDim2.new(1, 0, 0, 4)
	accentLine.BackgroundColor3 = Theme.Accent
	accentLine.BorderSizePixel = 0
	accentLine.Parent = dialog
	Instance.new("UICorner", accentLine).CornerRadius = UDim.new(0, 16)

	-- Logo
	local logoFrame = Instance.new("Frame")
	logoFrame.Size = UDim2.new(0, 110, 0, 110)
	logoFrame.Position = UDim2.new(0.5, -55, 0, 30)
	logoFrame.BackgroundTransparency = 1
	logoFrame.Parent = dialog

	local logoImg = Instance.new("ImageLabel")
	logoImg.Size = UDim2.new(1, 0, 1, 0)
	logoImg.BackgroundTransparency = 1
	logoImg.Image = "rbxassetid://71490293048559"
	logoImg.ScaleType = Enum.ScaleType.Fit
	logoImg.Parent = logoFrame

	-- Title
	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -40, 0, 32)
	titleLbl.Position = UDim2.new(0, 20, 0, 145)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "Do you want become Yuji Modulo?"
	titleLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
	titleLbl.TextSize = 20
	titleLbl.TextColor3 = Theme.Text
	titleLbl.TextWrapped = true
	titleLbl.Parent = dialog

	-- Subtitle
	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(1, -40, 0, 24)
	subLbl.Position = UDim2.new(0, 20, 0, 185)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = "Yuji Modulo & Side Dash System"
	subLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
	subLbl.TextSize = 14
	subLbl.TextTransparency = 0.3
	subLbl.TextColor3 = Theme.TextMuted
	subLbl.Parent = dialog

	-- Version
	local verLbl = Instance.new("TextLabel")
	verLbl.Size = UDim2.new(1, -40, 0, 20)
	verLbl.Position = UDim2.new(0, 20, 0, 209)
	verLbl.BackgroundTransparency = 1
	verLbl.Text = "Version 1.0 | by 7luvsz"
	verLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
	verLbl.TextSize = 11
	verLbl.TextTransparency = 0.5
	verLbl.TextColor3 = Theme.TextDim
	verLbl.Parent = dialog

	-- Button Container
	local btnContainer = Instance.new("Frame")
	btnContainer.Size = UDim2.new(1, -80, 0, 44)
	btnContainer.Position = UDim2.new(0, 40, 1, -64)
	btnContainer.BackgroundTransparency = 1
	btnContainer.Parent = dialog

	local btnLayout = Instance.new("UIListLayout", btnContainer)
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding = UDim.new(0, 16)
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- YES Button
	local yesBtn = Instance.new("TextButton")
	yesBtn.Size = UDim2.new(0.6, -8, 1, 0)
	yesBtn.BackgroundColor3 = Theme.Accent
	yesBtn.BackgroundTransparency = 0.1
	yesBtn.Text = "YES"
	yesBtn.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
	yesBtn.TextSize = 14
	yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	yesBtn.AutoButtonColor = false
	yesBtn.Parent = btnContainer
	Instance.new("UICorner", yesBtn).CornerRadius = UDim.new(0, 10)

	local yesStroke = Instance.new("UIStroke", yesBtn)
	yesStroke.Color = Theme.Accent
	yesStroke.Thickness = 1.5
	yesStroke.Transparency = 0.3

	-- NO Button
	local noBtn = Instance.new("TextButton")
	noBtn.Size = UDim2.new(0.4, -8, 1, 0)
	noBtn.BackgroundColor3 = Theme.Surface
	noBtn.BackgroundTransparency = 0.3
	noBtn.Text = "NO"
	noBtn.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
	noBtn.TextSize = 14
	noBtn.TextColor3 = Theme.TextMuted
	noBtn.AutoButtonColor = false
	noBtn.Parent = btnContainer
	Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 10)

	-- Hover Effects
	yesBtn.MouseEnter:Connect(function()
		TweenService:Create(yesBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
	end)
	yesBtn.MouseLeave:Connect(function()
		TweenService:Create(yesBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
	end)
	noBtn.MouseEnter:Connect(function()
		TweenService:Create(noBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
		TweenService:Create(noBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.SurfaceHover}):Play()
	end)
	noBtn.MouseLeave:Connect(function()
		TweenService:Create(noBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
		TweenService:Create(noBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Surface}):Play()
	end)

	-- Entrance Animation
	dialog.Size = UDim2.new(0, 0, 0, 0)
	dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
	TweenService:Create(dialog, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 400, 0, 320),
		Position = UDim2.new(0.5, 0, 0.5, 0)
	}):Play()

	local function closeAndOpen()
		TweenService:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
		TweenService:Create(dialog, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 400, 0, 0),
			Position = UDim2.new(0.5, 0, 0.5, 160)
		}):Play()
		task.wait(0.45)
		screenGui:Destroy()
		createGUI()
	end

	yesBtn.MouseButton1Click:Connect(function()
		godBFEnabled_VIP2 = true -- Enable Yuji Modulo
		TweenService:Create(yesBtn, TweenInfo.new(0.06, Enum.EasingStyle.Back), {Size = UDim2.new(0.6, -8, 1.1, 0)}):Play()
		task.wait(0.06)
		TweenService:Create(yesBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back), {Size = UDim2.new(0.6, -8, 1, 0)}):Play()
		closeAndOpen()
	end)

	noBtn.MouseButton1Click:Connect(function()
		TweenService:Create(noBtn, TweenInfo.new(0.06, Enum.EasingStyle.Back), {Size = UDim2.new(0.4, -8, 1.1, 0)}):Play()
		task.wait(0.06)
		TweenService:Create(noBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back), {Size = UDim2.new(0.4, -8, 1, 0)}):Play()
		task.wait(0.2)
		-- Show "whyyyyy broooooo" message
		screenGui:Destroy()
		local msgGui = Instance.new("ScreenGui")
		msgGui.Parent = player:WaitForChild("PlayerGui")
		
		local msgBg = Instance.new("Frame")
		msgBg.Size = UDim2.new(1, 0, 1, 0)
		msgBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		msgBg.BackgroundTransparency = 1
		msgBg.Parent = msgGui
		TweenService:Create(msgBg, TweenInfo.new(0.5), {BackgroundTransparency = 0.3}):Play()
		
		local msgLbl = Instance.new("TextLabel")
		msgLbl.Size = UDim2.new(0.8, 0, 0.5, 0)
		msgLbl.Position = UDim2.new(0.1, 0, 0.25, 0)
		msgLbl.BackgroundTransparency = 1
		msgLbl.Text = "whyyyyy broooooo"
		msgLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
		msgLbl.TextSize = 48
		msgLbl.TextColor3 = Theme.Danger
		msgLbl.TextTransparency = 1
		msgLbl.TextWrapped = true
		msgLbl.Parent = msgBg
		TweenService:Create(msgLbl, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
		
		-- Rainbow animation
		task.spawn(function()
			local t = 0
			while msgGui.Parent do
				t = t + 0.02
				msgLbl.TextColor3 = Color3.fromHSV(t % 1, 0.8, 1)
				task.wait(0.02)
			end
		end)
		
		task.wait(3)
		TweenService:Create(msgLbl, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		TweenService:Create(msgBg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
		task.wait(0.5)
		msgGui:Destroy()
	end)
end

-- ================== KEYBOARD ==================
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Insert then
		enabled = not enabled
		print("Bo Minh Vi Dai: " .. (enabled and "ON" or "OFF"))
		if not enabled then stopOrbit() end
		return
	end

	if not enabled then return end

	local keyName = input.KeyCode.Name
	local modeToRun = nil
	
	if godBFEnabled_VIP2 and keyName == ConfigVIP2.HOTKEY then modeToRun = "VIP2"
	elseif sideDashGodEnabled and keyName == ConfigSideDash.HOTKEY then modeToRun = "SIDE_DASH"
	end

	if modeToRun then
		local now = tick()
		if now - lastUse < COOLDOWN then return end
		lastUse = now

		if orbiting then
			stopOrbit()
		else
			local char = player.Character
			local root = getRoot(char)
			local hum = getHum(char)
			if not root or not hum or hum.Health <= 0 then return end
			
			local tRoot = getClosestTarget(modeToRun)
			if not tRoot then return end
			
			if modeToRun == "VIP2" then
				task.spawn(blackflash_VIP2, tRoot)
			end
			
			task.spawn(function()
				local currentDelay = 0
				if modeToRun == "VIP2" then currentDelay = ConfigVIP2.BF_DELAY
				elseif modeToRun == "SIDE_DASH" then currentDelay = 0 end
				
				task.wait(currentDelay)
				if enabled then
					startOrbit(modeToRun)
				end
			end)
		end
	end
end)

local function onCharacterAdded(char)
	task.wait(1.2)
	stopOrbit()
end
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

-- Show intro dialog
showIntroDialog()

print("==================================")
print("BO MINH VI DAI v1.0 LOADED!")
print("by 7luvsz")
print("==================================")
print("HOTKEYS:")
print("  INSERT = Toggle ON/OFF")
print("  C = Yuji Modulo (Black Flash)")
print("  X = Side Dash GOD")
print("==================================")

-- ================== ESP SYSTEM ==================
if Drawing then
	local Camera = Workspace.CurrentCamera
	local LP = player

	local ESPSettings = {
		ESPBox = true, ESPHealth = true, ESPNames = true,
		ESPSkeleton = true, ESPChams = true, BoxPadding = 0.5,
		ChamsColor = Color3.fromRGB(60, 140, 255),
		NameColor = Color3.fromRGB(255, 255, 0),
		NeonColor = Color3.fromRGB(60, 140, 255),
	}

	local R15Bones = {
		{"UpperTorso","Head"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
		{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"UpperTorso","LowerTorso"},
		{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},
		{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
	}

	local function GetBoundingVectors(char)
		local cf, size = char:GetBoundingBox()
		size = size + Vector3.new(ESPSettings.BoxPadding, ESPSettings.BoxPadding, ESPSettings.BoxPadding)
		local corners = {}
		for _, s in ipairs({{-1,1,1},{1,1,1},{-1,-1,1},{1,-1,1},{-1,1,-1},{1,1,-1},{-1,-1,-1},{1,-1,-1}}) do
			table.insert(corners, cf * CFrame.new(s[1]*size.X/2, s[2]*size.Y/2, s[3]*size.Z/2))
		end
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		local allOff = true
		for _, c in pairs(corners) do
			local sp, on = Camera:WorldToViewportPoint(c.Position)
			if on then allOff = false; minX = math.min(minX, sp.X); minY = math.min(minY, sp.Y); maxX = math.max(maxX, sp.X); maxY = math.max(maxY, sp.Y) end
		end
		if allOff then return nil, nil, false end
		return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY), true
	end

	local function CreateESP(p)
		if p == LP then return end
		local Box = Drawing.new("Square"); Box.Thickness = 1
		local HealthBar = Drawing.new("Line"); HealthBar.Thickness = 2
		local NameTag = Drawing.new("Text"); NameTag.Size = 18; NameTag.Center = true; NameTag.Outline = true
		local SkeletonLines = {}
		local Highlight = Instance.new("Highlight")
		Highlight.FillColor = ESPSettings.ChamsColor; Highlight.OutlineColor = Color3.new(1,1,1)
		Highlight.FillTransparency = 0.25; Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

		local function Clear()
			Box.Visible = false; HealthBar.Visible = false; NameTag.Visible = false
			for _, l in pairs(SkeletonLines) do l.Visible = false end
			Highlight.Enabled = false
		end

		RunService.RenderStepped:Connect(function()
			if not espEnabled then Clear() return end
			if not p.Parent then Box:Remove(); HealthBar:Remove(); NameTag:Remove(); Highlight:Destroy()
				for _, l in pairs(SkeletonLines) do l:Remove() end return end
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if char and hum and hum.Health > 0 then
				local bPos, bSize, vis = GetBoundingVectors(char)
				if ESPSettings.ESPChams then Highlight.Enabled = true; Highlight.Parent = char; Highlight.Adornee = char
				else Highlight.Enabled = false end
				if vis and bPos and bSize and bSize.X < 5000 and bSize.Y < 5000 then
					if ESPSettings.ESPBox then Box.Visible = true; Box.Position = bPos; Box.Size = bSize; Box.Color = ESPSettings.NeonColor
					else Box.Visible = false end
					if ESPSettings.ESPHealth then
						HealthBar.Visible = true; local hp = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
						HealthBar.From = Vector2.new(bPos.X - 5, bPos.Y + bSize.Y)
						HealthBar.To = Vector2.new(bPos.X - 5, bPos.Y + bSize.Y - (bSize.Y * hp))
						HealthBar.Color = Color3.fromHSV(hp * 0.3, 1, 1)
					else HealthBar.Visible = false end
					if ESPSettings.ESPNames then
						NameTag.Visible = true; NameTag.Text = p.Name:upper()
						NameTag.Position = Vector2.new(bPos.X + bSize.X/2, bPos.Y - 25)
						NameTag.Color = ESPSettings.NameColor
					else NameTag.Visible = false end
					if ESPSettings.ESPSkeleton then
						for i, bm in ipairs(R15Bones) do
							if not SkeletonLines[i] then SkeletonLines[i] = Drawing.new("Line"); SkeletonLines[i].Thickness = 1; SkeletonLines[i].Color = Color3.new(1,1,1) end
							local pA, pB = char:FindFirstChild(bm[1]), char:FindFirstChild(bm[2])
							if pA and pB then
								local vA, oA = Camera:WorldToViewportPoint(pA.Position); local vB, oB = Camera:WorldToViewportPoint(pB.Position)
								if oA and oB then SkeletonLines[i].From = Vector2.new(vA.X, vA.Y); SkeletonLines[i].To = Vector2.new(vB.X, vB.Y); SkeletonLines[i].Visible = true
								else SkeletonLines[i].Visible = false end
							else SkeletonLines[i].Visible = false end
						end
					end
				else Clear() end
			else Clear() end
		end)
	end

	for _, v in ipairs(Players:GetPlayers()) do task.spawn(CreateESP, v) end
	Players.PlayerAdded:Connect(CreateESP)
end
