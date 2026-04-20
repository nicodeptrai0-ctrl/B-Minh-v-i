-- ================================================
-- BAY ORBIT v19.0 - VIP 1, VIP 2 & SIDE DASH GOD
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

task.spawn(function()
	loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
end)

-- ================== CONFIG ==================
local ConfigVIP1 = {
	SPEED = 1000,
	MAX_DASH = 0.35,
	BF_DELAY = 0.1,
	PIN_TIME = 0.3,
	REVERSE_DIR = false,
	HOTKEY = "Z",
}

local ConfigVIP2 = {
	SPEED = 1000,
	MAX_DASH = 0.35,
	MOVE_SPEED = 100,
	BF_DELAY = 0.1,
	REVERSE_DIR = false,
	HOTKEY = "C",
}

local ConfigSideDash = {
	SPEED = 600,
	MAX_DASH = 0.3,
	MOVE_SPEED = 100,
	DISTANCE = 20.0,
	REVERSE_DIR = false,
	HOTKEY = "X",
}

local godBFEnabled_VIP1 = false
local godBFEnabled_VIP2 = false
local sideDashGodEnabled = false
local espEnabled = false
local COOLDOWN = 0.01
local ORBIT_RADIUS = 6.0
local STOP_BEHIND_DIST = 6.0
local GROUND_OFFSET = 3.4
local MAX_START_DISTANCE = 15.0

local FACE_TARGET_AFTER = 0.5 -- thời gian hướng mặt vào đối thủ SAU khi orbit xong (giây)

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

local function blackflash_VIP1(tRoot)
	if not triggerDFist() then return end
	task.wait(0.29)
	if not triggerDFist() then return end
	task.wait(0.30)

	local chr = player.Character
	if not chr then return end

	-- SIÊU GHIM (Ping Prediction + No Collide để đấm mượt dù xoay camera loạn xạ)
	local myRoot = getRoot(chr)
	local myHum = getHum(chr)
	if myRoot and tRoot and tRoot.Parent then
		local pinStart = tick()
		local pinDuration = 0.5 -- Thời gian ghim đủ 0.5s để tung hit
		local rsConn
		
		local oldAuto = true
		if myHum then 
			oldAuto = myHum.AutoRotate
			myHum.AutoRotate = false 
		end
		
		if faceConn then faceConn:Disconnect() faceConn = nil end
		
		rsConn = RunService.RenderStepped:Connect(function()
			if tick() - pinStart > pinDuration or not tRoot or not tRoot.Parent or not myRoot or not myRoot.Parent then
				if rsConn then rsConn:Disconnect() end
				if myHum then myHum.AutoRotate = oldAuto end
				-- Bật lại va chạm
				for _, part in ipairs(chr:GetDescendants()) do
					if part:IsA("BasePart") then part.CanCollide = true end
				end
				if tRoot and tRoot.Parent then startFaceTarget(tRoot) end
				return
			end
			
			-- TẮT VA CHẠM (No-Collide): Đứng xuyên vào địch mà không làm cả hai bị văng đi
			for _, part in ipairs(chr:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
			
			myRoot.AssemblyLinearVelocity = v3zero
			myRoot.AssemblyAngularVelocity = v3zero
			
			-- PING PREDICTION (Dự đoán góc xoay): Tính toán trước lưng địch sẽ ở đâu sau 0.15s
			local angVel = tRoot.AssemblyAngularVelocity
			local spinSpeed = clamp(angVel.Y, -30, 30) -- Giới hạn tốc độ xoay để không bay quá xa
			local predictedCF = tRoot.CFrame * CFrame.Angles(0, spinSpeed * 0.15, 0)
			
			local flatVector = v3(predictedCF.LookVector.X, 0, predictedCF.LookVector.Z)
			local flatLook = (flatVector.Magnitude > 0.001) and flatVector.Unit or v3(0, 0, -1)
			
			local PIN_DIST = 2.0 -- Đứng cực gần để hitbox đấm chắc chắn trúng
			local targetPos = tRoot.Position
			local behindPos = targetPos - flatLook * PIN_DIST
			
			myRoot.CFrame = CFrame.lookAt(behindPos, targetPos)
		end)
	end

	triggerDFist()
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
	textLabel.Text = "Synzji"
	textLabel.TextColor3 = Color3.fromRGB(80, 170, 255)
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
	if modeToRun == "VIP1" then cfg = ConfigVIP1
	elseif modeToRun == "VIP2" then cfg = ConfigVIP2
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

	if modeToRun == "VIP1" then
		-- ================= VIP 1: ORBIT CÓ GHIM =================
		orbitConn = RunService.RenderStepped:Connect(function(dt)
			if not orbiting or not targetRoot or not targetRoot.Parent then stopOrbit() return end
			
			local root = getRoot(player.Character)
			local hum = getHum(player.Character)
			if not hum or not root or hum.Health <= 0 then stopOrbit() return end

			local elapsed = tick() - startTime
			if elapsed > cfg.MAX_DASH + cfg.PIN_TIME then 
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then part.CanCollide = true end
				end
				stopOrbit() 
				return 
			end

			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
			
			local angVel = tRoot.AssemblyAngularVelocity
			local spinSpeed = clamp(angVel.Y, -30, 30) 
			local predictedCF = tRoot.CFrame * CFrame.Angles(0, spinSpeed * 0.15, 0)
			local flatVector = v3(predictedCF.LookVector.X, 0, predictedCF.LookVector.Z)
			local flatLook = (flatVector.Magnitude > 0.001) and flatVector.Unit or v3(0, 0, -1)
			
			local PIN_DIST = 4.0 
			local behindPos = tRoot.Position - flatLook * PIN_DIST
			
			local progress = clamp(elapsed / cfg.MAX_DASH, 0, 1)
			
			if progress >= 1 and dashTrack and dashTrack.IsPlaying then
				dashTrack:Stop()
			end
			
			smoothedAngle = smoothedAngle + orbitDirection * rad(cfg.SPEED) * dt * 1.12
			local localOffset = v3(sin(smoothedAngle) * ORBIT_RADIUS, 0, -cos(smoothedAngle) * ORBIT_RADIUS)
			local orbitPos = tRoot.Position + tRoot.CFrame:VectorToWorldSpace(localOffset)
			
			local goalFlat = orbitPos:Lerp(behindPos, progress ^ 1.5)
			local goalPos = v3(goalFlat.X, tRoot.Position.Y, goalFlat.Z)
			
			root.AssemblyLinearVelocity = v3zero
			root.AssemblyAngularVelocity = v3zero
			root.CFrame = CFrame.lookAt(goalPos, v3(tRoot.Position.X, root.Position.Y, tRoot.Position.Z))
		end)
	else
		-- ================= VIP 2 & SIDE DASH: ORBIT MƯỢT KHÔNG GHIM =================
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
			if elapsed > cfg.MAX_DASH + 0.1 then stopOrbit() return end
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
end

-- ================== XENON HUB GUI ==================
local function createConfigMenu()
	local ACCENT = Color3.fromRGB(60, 140, 255)
	local ACCENT_DARK = Color3.fromRGB(30, 80, 180)
	local BG_MAIN = Color3.fromRGB(22, 24, 32)
	local BG_SIDE = Color3.fromRGB(28, 30, 40)
	local BG_TOP = Color3.fromRGB(26, 28, 38)
	local BG_INPUT = Color3.fromRGB(35, 38, 50)
	local TEXT_W = Color3.fromRGB(220, 225, 240)
	local TEXT_DIM = Color3.fromRGB(140, 145, 165)
	local DIVIDER = Color3.fromRGB(45, 48, 60)
	local TOGGLE_ON = Color3.fromRGB(60, 200, 120)
	local TOGGLE_OFF = Color3.fromRGB(70, 72, 85)
	local DANGER = Color3.fromRGB(200, 50, 70)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "OrbitConfigMenu"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- ===== MAIN FRAME =====
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 520, 0, 360)
	mainFrame.Position = UDim2.new(0.5, -260, 0.3, 0)
	mainFrame.BackgroundColor3 = BG_MAIN
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui
	Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
	local ms = Instance.new("UIStroke", mainFrame)
	ms.Color = Color3.fromRGB(50, 55, 75)
	ms.Thickness = 1.5
	ms.Transparency = 0.3

	-- ===== TOP BAR =====
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 40)
	topBar.BackgroundColor3 = BG_TOP
	topBar.BorderSizePixel = 0
	topBar.Parent = mainFrame

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.7, 0, 1, 0)
	titleLbl.Position = UDim2.new(0, 14, 0, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.RichText = true
	titleLbl.Text = '<font color="#3C8CFF"><b>Bố Minh</b></font> <font color="#A0C4FF">VĨ ĐẠI</font>'
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.TextSize = 16
	titleLbl.TextColor3 = ACCENT
	titleLbl.TextStrokeTransparency = 0.6
	titleLbl.TextStrokeColor3 = Color3.fromRGB(10, 20, 50)
	titleLbl.Parent = topBar

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(0.4, 0, 0, 14)
	subLbl.Position = UDim2.new(0, 14, 1, -16)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = "Jujutsu Shenanigans"
	subLbl.TextColor3 = TEXT_DIM
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.Font = Enum.Font.Gotham
	subLbl.TextSize = 10
	subLbl.Parent = topBar

	-- Close btn
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -36, 0, 5)
	closeBtn.BackgroundColor3 = DANGER
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.Parent = topBar
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
	closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

	-- Minimize btn
	local minBtn = Instance.new("TextButton")
	minBtn.Size = UDim2.new(0, 30, 0, 30)
	minBtn.Position = UDim2.new(1, -70, 0, 5)
	minBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
	minBtn.Text = "_"
	minBtn.TextColor3 = TEXT_W
	minBtn.Font = Enum.Font.GothamBold
	minBtn.TextSize = 14
	minBtn.Parent = topBar
	Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

	local minimized = false
	local savedSize
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			savedSize = mainFrame.Size
			TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = UDim2.new(0, mainFrame.Size.X.Offset, 0, 40)}):Play()
		else
			TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = savedSize or UDim2.new(0, 520, 0, 360)}):Play()
		end
	end)

	-- Drag
	local dragging, dragStart, startPos
	topBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true; dragStart = i.Position; startPos = mainFrame.Position
		end
	end)
	topBar.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	-- ===== TOP DIVIDER =====
	local topDiv = Instance.new("Frame")
	topDiv.Size = UDim2.new(1, 0, 0, 1)
	topDiv.Position = UDim2.new(0, 0, 0, 40)
	topDiv.BackgroundColor3 = DIVIDER
	topDiv.BorderSizePixel = 0
	topDiv.Parent = mainFrame

	-- ===== SIDEBAR =====
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 140, 1, -41)
	sidebar.Position = UDim2.new(0, 0, 0, 41)
	sidebar.BackgroundColor3 = BG_SIDE
	sidebar.BorderSizePixel = 0
	sidebar.Parent = mainFrame

	local sideDiv = Instance.new("Frame")
	sideDiv.Size = UDim2.new(0, 1, 1, 0)
	sideDiv.Position = UDim2.new(1, 0, 0, 0)
	sideDiv.BackgroundColor3 = DIVIDER
	sideDiv.BorderSizePixel = 0
	sideDiv.Parent = sidebar

	-- ===== CONTENT AREA =====
	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -141, 1, -41)
	content.Position = UDim2.new(0, 141, 0, 41)
	content.BackgroundTransparency = 1
	content.ClipsDescendants = true
	content.Parent = mainFrame

	-- Pages
	local pages = {}
	local function makePage(name)
		local p = Instance.new("ScrollingFrame")
		p.Name = name
		p.Size = UDim2.new(1, 0, 1, 0)
		p.BackgroundTransparency = 1
		p.ScrollBarThickness = 3
		p.ScrollBarImageColor3 = ACCENT
		p.BorderSizePixel = 0
		p.Visible = false
		p.CanvasSize = UDim2.new(0, 0, 0, 0)
		p.AutomaticCanvasSize = Enum.AutomaticSize.Y
		p.Parent = content
		local layout = Instance.new("UIListLayout", p)
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		local pad = Instance.new("UIPadding", p)
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pages[name] = p
		return p
	end

	local pageGeneral = makePage("General")
	local pageFeatures = makePage("Features")
	local pageConfig = makePage("Config")

	-- Sidebar buttons
	local sideButtons = {}
	local tabNames = {
		{name = "General", icon = "⚙️"},
		{name = "Features", icon = "⚡"},
		{name = "Config", icon = "🔧"},
	}

	local function selectTab(tabName)
		for n, pg in pairs(pages) do pg.Visible = (n == tabName) end
		for _, btn in pairs(sideButtons) do
			if btn.Name == tabName then
				btn.BackgroundColor3 = ACCENT
				btn.BackgroundTransparency = 0
				btn:FindFirstChildOfClass("TextLabel").TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				btn.BackgroundTransparency = 1
				btn:FindFirstChildOfClass("TextLabel").TextColor3 = TEXT_DIM
			end
		end
	end

	local sideLabel = Instance.new("TextLabel")
	sideLabel.Size = UDim2.new(1, -10, 0, 28)
	sideLabel.Position = UDim2.new(0, 5, 0, 8)
	sideLabel.BackgroundTransparency = 1
	sideLabel.Text = "Main"
	sideLabel.TextColor3 = TEXT_DIM
	sideLabel.TextXAlignment = Enum.TextXAlignment.Left
	sideLabel.Font = Enum.Font.GothamBold
	sideLabel.TextSize = 10
	sideLabel.Parent = sidebar

	for i, tab in ipairs(tabNames) do
		local btn = Instance.new("TextButton")
		btn.Name = tab.name
		btn.Size = UDim2.new(1, -10, 0, 32)
		btn.Position = UDim2.new(0, 5, 0, 28 + (i - 1) * 36)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Parent = sidebar
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -10, 1, 0)
		lbl.Position = UDim2.new(0, 10, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = tab.icon .. "  " .. tab.name
		lbl.TextColor3 = TEXT_DIM
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamSemibold
		lbl.TextSize = 13
		lbl.Parent = btn

		sideButtons[#sideButtons + 1] = btn
		btn.MouseButton1Click:Connect(function() selectTab(tab.name) end)
	end

	-- ===== HELPER: SECTION TITLE =====
	local function addSectionTitle(parent, text, order)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 24)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = ACCENT
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 13
		lbl.LayoutOrder = order
		lbl.Parent = parent
	end

	-- ===== HELPER: INFO ROW =====
	local function addInfoRow(parent, label, valueText, order)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Parent = parent

		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(0.5, 0, 1, 0)
		l.BackgroundTransparency = 1
		l.Text = label
		l.TextColor3 = TEXT_DIM
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Font = Enum.Font.Gotham
		l.TextSize = 12
		l.Parent = row

		local v = Instance.new("TextLabel")
		v.Name = "Value"
		v.Size = UDim2.new(0.5, 0, 1, 0)
		v.Position = UDim2.new(0.5, 0, 0, 0)
		v.BackgroundTransparency = 1
		v.Text = valueText
		v.TextColor3 = TEXT_W
		v.TextXAlignment = Enum.TextXAlignment.Right
		v.Font = Enum.Font.GothamSemibold
		v.TextSize = 12
		v.Parent = row
		return v
	end

	-- ===== HELPER: TOGGLE =====
	local function addToggle(parent, labelText, initial, order, callback)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundColor3 = BG_INPUT
		row.LayoutOrder = order
		row.Parent = parent
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		local rpad = Instance.new("UIPadding", row)
		rpad.PaddingLeft = UDim.new(0, 10)
		rpad.PaddingRight = UDim.new(0, 10)

		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(0.7, 0, 1, 0)
		l.BackgroundTransparency = 1
		l.Text = labelText
		l.TextColor3 = TEXT_W
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Font = Enum.Font.GothamSemibold
		l.TextSize = 12
		l.Parent = row

		local togBg = Instance.new("TextButton")
		togBg.Size = UDim2.new(0, 40, 0, 20)
		togBg.Position = UDim2.new(1, -40, 0.5, -10)
		togBg.BackgroundColor3 = initial and TOGGLE_ON or TOGGLE_OFF
		togBg.Text = ""
		togBg.Parent = row
		Instance.new("UICorner", togBg).CornerRadius = UDim.new(1, 0)

		local circle = Instance.new("Frame")
		circle.Size = UDim2.new(0, 16, 0, 16)
		circle.Position = initial and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		circle.Parent = togBg
		Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

		local state = initial
		local function updateVisuals()
			TweenService:Create(togBg, TweenInfo.new(0.2), {BackgroundColor3 = state and TOGGLE_ON or TOGGLE_OFF}):Play()
			TweenService:Create(circle, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
		end

		togBg.MouseButton1Click:Connect(function()
			state = not state
			updateVisuals()
			if callback then callback(state) end
		end)
		
		local function setState(newState)
			if state ~= newState then
				state = newState
				updateVisuals()
			end
		end

		return row, setState
	end

	-- ===== HELPER: INPUT ROW =====
	local function addInputRow(parent, labelText, configKey, order, configTable)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundColor3 = BG_INPUT
		row.LayoutOrder = order
		row.Parent = parent
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(0.6, -10, 1, 0)
		l.Position = UDim2.new(0, 10, 0, 0)
		l.BackgroundTransparency = 1
		l.Text = labelText
		l.TextColor3 = TEXT_W
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Font = Enum.Font.Gotham
		l.TextSize = 12
		l.Parent = row

		local tb = Instance.new("TextBox")
		tb.Size = UDim2.new(0.35, -10, 0, 22)
		tb.Position = UDim2.new(0.65, 0, 0.5, -11)
		tb.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
		tb.TextColor3 = Color3.fromRGB(255, 255, 255)
		tb.Text = tostring(configTable[configKey])
		tb.Font = Enum.Font.GothamSemibold
		tb.TextSize = 12
		tb.ClearTextOnFocus = true
		tb.Parent = row
		Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)
		local tbs = Instance.new("UIStroke", tb)
		tbs.Color = DIVIDER
		tbs.Thickness = 1

		tb.FocusLost:Connect(function()
			local txt = tb.Text:upper()
			if type(configTable[configKey]) == "number" then
				local num = tonumber(txt)
				if num then configTable[configKey] = num; tb.Text = tostring(num)
				else tb.Text = tostring(configTable[configKey]) end
			else
				if txt:len() > 0 then
					configTable[configKey] = txt
					tb.Text = txt
				else
					tb.Text = configTable[configKey]
				end
			end
		end)
		return tb
	end

	-- =========================================
	-- PAGE: GENERAL
	-- =========================================
	addSectionTitle(pageGeneral, "📊 Status", 1)
	local statusVal = addInfoRow(pageGeneral, "Script Status", "ON", 2)
	addInfoRow(pageGeneral, "Hotkey Orbit", "Custom (Check Config)", 3)
	addInfoRow(pageGeneral, "Toggle ON/OFF", "Insert", 4)

	local gDiv = Instance.new("Frame")
	gDiv.Size = UDim2.new(1, 0, 0, 1)
	gDiv.BackgroundColor3 = DIVIDER
	gDiv.BorderSizePixel = 0
	gDiv.LayoutOrder = 5
	gDiv.Parent = pageGeneral

	addSectionTitle(pageGeneral, "ℹ️ Info", 6)
	addInfoRow(pageGeneral, "Version", "v19.0 (VIP SEPARATE)", 7)
	addInfoRow(pageGeneral, "Author", "Synzji", 8)

	-- =========================================
	-- PAGE: FEATURES
	-- =========================================
	addSectionTitle(pageFeatures, "⚔️ Combat", 1)

	addToggle(pageFeatures, "🔥 GOD Black Flash VIP 1 (Có Ghim)", godBFEnabled_VIP1, 2, function(state)
		godBFEnabled_VIP1 = state
	end)

	addToggle(pageFeatures, "🔥 GOD Black Flash VIP 2 (Không Ghim)", godBFEnabled_VIP2, 3, function(state)
		godBFEnabled_VIP2 = state
	end)

	addToggle(pageFeatures, "⚡ Side Dash GOD (Chỉ Lướt)", sideDashGodEnabled, 4, function(state)
		sideDashGodEnabled = state
	end)

	addToggle(pageFeatures, "🎯 Aimbot", false, 5, function(state)
		if state and not aimbotLoaded then
			aimbotLoaded = true
			task.spawn(function()
				loadstring(game:HttpGet("https://raw.githubusercontent.com/ttwizz/Open-Aimbot/master/source.lua", true))()
			end)
		end
	end)

	local fDiv = Instance.new("Frame")
	fDiv.Size = UDim2.new(1, 0, 0, 1)
	fDiv.BackgroundColor3 = DIVIDER
	fDiv.BorderSizePixel = 0
	fDiv.LayoutOrder = 6
	fDiv.Parent = pageFeatures

	addSectionTitle(pageFeatures, "👁️ Visuals", 7)

	addToggle(pageFeatures, "👁️ ESP (Box/Name/Health)", false, 8, function(state)
		espEnabled = state
	end)

	-- =========================================
	-- PAGE: CONFIG
	-- =========================================
	addSectionTitle(pageConfig, "🔄 VIP 1 Settings", 1)

	local tbSpeed1 = addInputRow(pageConfig, "SPEED", "SPEED", 2, ConfigVIP1)
	local tbDash1 = addInputRow(pageConfig, "MAX DASH", "MAX_DASH", 3, ConfigVIP1)
	local tbKey1 = addInputRow(pageConfig, "HOTKEY", "HOTKEY", 4, ConfigVIP1)

	local cDiv1 = Instance.new("Frame")
	cDiv1.Size = UDim2.new(1, 0, 0, 1)
	cDiv1.BackgroundColor3 = DIVIDER
	cDiv1.BorderSizePixel = 0
	cDiv1.LayoutOrder = 5
	cDiv1.Parent = pageConfig

	addSectionTitle(pageConfig, "🔄 VIP 2 Settings", 6)

	local tbSpeed2 = addInputRow(pageConfig, "SPEED", "SPEED", 7, ConfigVIP2)
	local tbDash2 = addInputRow(pageConfig, "MAX DASH", "MAX_DASH", 8, ConfigVIP2)
	local tbKey2 = addInputRow(pageConfig, "HOTKEY", "HOTKEY", 9, ConfigVIP2)

	local cDiv2 = Instance.new("Frame")
	cDiv2.Size = UDim2.new(1, 0, 0, 1)
	cDiv2.BackgroundColor3 = DIVIDER
	cDiv2.BorderSizePixel = 0
	cDiv2.LayoutOrder = 10
	cDiv2.Parent = pageConfig

	addSectionTitle(pageConfig, "⚡ Side Dash GOD Settings", 11)

	local tbSpeed3 = addInputRow(pageConfig, "SPEED", "SPEED", 12, ConfigSideDash)
	local tbDash3 = addInputRow(pageConfig, "MAX DASH", "MAX_DASH", 13, ConfigSideDash)
	local tbDist3 = addInputRow(pageConfig, "DISTANCE", "DISTANCE", 14, ConfigSideDash)
	local tbKey3 = addInputRow(pageConfig, "HOTKEY", "HOTKEY", 15, ConfigSideDash)

	local cDiv3 = Instance.new("Frame")
	cDiv3.Size = UDim2.new(1, 0, 0, 1)
	cDiv3.BackgroundColor3 = DIVIDER
	cDiv3.BorderSizePixel = 0
	cDiv3.LayoutOrder = 16
	cDiv3.Parent = pageConfig

	-- Reset button
	local resetBtn = Instance.new("TextButton")
	resetBtn.Size = UDim2.new(1, 0, 0, 32)
	resetBtn.BackgroundColor3 = ACCENT_DARK
	resetBtn.Text = "🔄 Reset to Default"
	resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextSize = 12
	resetBtn.LayoutOrder = 17
	resetBtn.Parent = pageConfig
	Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)

	resetBtn.MouseButton1Click:Connect(function()
		ConfigVIP1.SPEED = 1000; ConfigVIP1.MAX_DASH = 0.35; ConfigVIP1.BF_DELAY = 0.1; ConfigVIP1.PIN_TIME = 0.3; ConfigVIP1.REVERSE_DIR = false; ConfigVIP1.HOTKEY = "Z"
		ConfigVIP2.SPEED = 1000; ConfigVIP2.MAX_DASH = 0.35; ConfigVIP2.MOVE_SPEED = 100; ConfigVIP2.BF_DELAY = 0.1; ConfigVIP2.REVERSE_DIR = false; ConfigVIP2.HOTKEY = "X"
		ConfigSideDash.SPEED = 950; ConfigSideDash.MAX_DASH = 0.35; ConfigSideDash.MOVE_SPEED = 100; ConfigSideDash.DISTANCE = 15.0; ConfigSideDash.REVERSE_DIR = false; ConfigSideDash.HOTKEY = "C"
		
		tbSpeed1.Text = "1000"; tbDash1.Text = "0.35"; tbKey1.Text = "Z"
		tbSpeed2.Text = "1000"; tbDash2.Text = "0.35"; tbKey2.Text = "X"
		tbSpeed3.Text = "950"; tbDash3.Text = "0.35"; tbDist3.Text = "15.0"; tbKey3.Text = "C"
	end)

	-- ===== RESIZE HANDLE =====
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Size = UDim2.new(0, 18, 0, 18)
	resizeHandle.Position = UDim2.new(1, -18, 1, -18)
	resizeHandle.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
	resizeHandle.Text = "⤡"
	resizeHandle.TextColor3 = TEXT_DIM
	resizeHandle.Font = Enum.Font.GothamBold
	resizeHandle.TextSize = 10
	resizeHandle.ZIndex = 10
	resizeHandle.Parent = mainFrame
	Instance.new("UICorner", resizeHandle).CornerRadius = UDim.new(0, 4)

	local resizing, resizeStart, resizeSize
	resizeHandle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = true; resizeStart = i.Position
			resizeSize = mainFrame.Size
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if resizing and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - resizeStart
			local newW = math.clamp(resizeSize.X.Offset + d.X, 400, 800)
			local newH = math.clamp(resizeSize.Y.Offset + d.Y, 250, 600)
			mainFrame.Size = UDim2.new(0, newW, 0, newH)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
	end)

	-- Select default tab
	selectTab("General")

	-- Status update loop
	task.spawn(function()
		while screenGui.Parent do
			if statusVal then
				statusVal.Text = enabled and "ON" or "OFF"
				statusVal.TextColor3 = enabled and TOGGLE_ON or DANGER
			end
			task.wait(0.5)
		end
	end)
end
createConfigMenu()

-- ================== KEYBOARD ==================
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Insert then
		enabled = not enabled
		print("Bay Orbit: " .. (enabled and "ON" or "OFF"))
		if not enabled then stopOrbit() end
		return
	end

	if not enabled then return end

	local keyName = input.KeyCode.Name
	local modeToRun = nil
	
	if godBFEnabled_VIP1 and keyName == ConfigVIP1.HOTKEY then modeToRun = "VIP1"
	elseif godBFEnabled_VIP2 and keyName == ConfigVIP2.HOTKEY then modeToRun = "VIP2"
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
			
			if modeToRun == "VIP1" then
				task.spawn(blackflash_VIP1, tRoot)
			elseif modeToRun == "VIP2" then
				task.spawn(blackflash_VIP2, tRoot)
			end
			
			task.spawn(function()
				local currentDelay = 0
				if modeToRun == "VIP1" then currentDelay = ConfigVIP1.BF_DELAY
				elseif modeToRun == "VIP2" then currentDelay = ConfigVIP2.BF_DELAY
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
print("SIDE DASH ORBIT v19.0 + BLACK FLASH VIP COMBINED READY")
print("HOTKEYS Custom in GUI | Insert = ON/OFF")

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
