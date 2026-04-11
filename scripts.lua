local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local enabled = true
local orbiting = false
task.spawn(function()
	loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
end)
local Config = {
	ANG_SPEED_DEG = 750,
	STICK_TIME = 0.45,
	MAX_ORBIT_TIME = 0.45,
	MOVE_SPEED = 100,
}
local COOLDOWN = 0.01
local ORBIT_RADIUS = 5.0
local STOP_BEHIND_DIST = 5.0
local GROUND_OFFSET = 3.4
local MAX_START_DISTANCE = 15.0
local BLACKFLASH_DELAY = 0
local DASH_RIGHT_ID = "rbxassetid://75203303352791"
local DASH_LEFT_ID = "rbxassetid://117223862448096"
local lastUse = 0
local orbitConn = nil
local targetRoot = nil
local bodyVelocity = nil
local bodyGyro = nil
local oldPlatformStand = false
local oldAutoRotate = true
local stickMode = false
local stickStartTime = 0
local currentVelocity = Vector3.zero
local smoothedAngle = 0
local orbitDirection = 0
local aimbotLoaded = false
local dashTrack = nil
local rpl = game:GetService("ReplicatedStorage")
local activateRE = rpl.Knit.Knit.Services.DivergentFistService.RE.Activated
local function blackflash()
	local chr = player.Character
	if not chr then return end
	local mset = chr:FindFirstChild("Moveset")
	if not mset then return end
	local dfist = mset:FindFirstChild("Divergent Fist")
	if not dfist then return end
	activateRE:FireServer(dfist)
	task.wait(0.29)
	chr = player.Character
	if not chr then return end
	mset = chr:FindFirstChild("Moveset")
	if not mset then return end
	dfist = mset:FindFirstChild("Divergent Fist")
	if not dfist then return end
	activateRE:FireServer(dfist)
	task.wait(0.30)
	chr = player.Character
	if not chr then return end
	mset = chr:FindFirstChild("Moveset")
	if not mset then return end
	dfist = mset:FindFirstChild("Divergent Fist")
	if not dfist then return end
	activateRE:FireServer(dfist)
end
local function showCredit()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CreditGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.6, 0, 0.15, 0)
	textLabel.Position = UDim2.new(0.2, 0, 0.4, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "Trung Top 1 TQT"
	textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.Parent = screenGui
	local tweenInfo = TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeTween = TweenService:Create(textLabel, tweenInfo, {TextTransparency = 1, TextStrokeTransparency = 1})
	fadeTween:Play()
	fadeTween.Completed:Connect(function() screenGui:Destroy() end)
end
showCredit()
local function getRoot(char) return char and char:FindFirstChild("HumanoidRootPart") end
local function getHum(char) return char and char:FindFirstChildOfClass("Humanoid") end
local function getSignedAngle(tRoot, pos)
	local tPos = tRoot.Position
	local toPos = (pos - tPos)
	local flatTo = Vector3.new(toPos.X, 0, toPos.Z).Unit
	local fwd = Vector3.new(tRoot.CFrame.LookVector.X, 0, tRoot.CFrame.LookVector.Z).Unit
	local rgt = Vector3.new(tRoot.CFrame.RightVector.X, 0, tRoot.CFrame.RightVector.Z).Unit
	return math.atan2(flatTo:Dot(rgt), flatTo:Dot(fwd))
end
local function shortestDelta(from, to)
	local delta = to - from
	while delta > math.pi do delta = delta - 2 * math.pi end
	while delta < -math.pi do delta = delta + 2 * math.pi end
	return delta
end
local function getClosestTarget()
	local char = player.Character
	local root = getRoot(char)
	if not root then return nil end
	local myPos = root.Position
	local closest, closestDist = nil, math.huge
	for _, other in ipairs(Players:GetPlayers()) do
		if other == player or not other.Character then continue end
		local oRoot = getRoot(other.Character)
		local oHum = getHum(other.Character)
		if not oRoot or not oHum or oHum.Health <= 0 then continue end
		local dist = (oRoot.Position - myPos).Magnitude
		if dist > MAX_START_DISTANCE then continue end
		if dist < closestDist then
			closestDist = dist
			closest = oRoot
		end
	end
	return closest
end
local function stopOrbit()
	if not orbiting then return end
	orbiting = false
	stickMode = false
	targetRoot = nil
	currentVelocity = Vector3.zero
	smoothedAngle = 0
	orbitDirection = 0
	if orbitConn then orbitConn:Disconnect() orbitConn = nil end
	if dashTrack then pcall(function() dashTrack:Stop() end) dashTrack = nil end
	local char = player.Character
	local root = getRoot(char)
	local hum = getHum(char)
	if root and bodyVelocity then
		bodyVelocity.Velocity = Vector3.zero
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end
	if root and bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
	if hum then
		hum.PlatformStand = oldPlatformStand
		hum.AutoRotate = oldAutoRotate
		hum:Move(Vector3.zero, false)
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end
end
local function startOrbit()
	local char = player.Character
	local root = getRoot(char)
	local hum = getHum(char)
	if not root or not hum then return end
	local tRoot = getClosestTarget()
	if not tRoot then return end
	stopOrbit()
	orbiting = true
	stickMode = false
	targetRoot = tRoot
	oldPlatformStand = hum.PlatformStand
	oldAutoRotate = hum.AutoRotate
	hum.PlatformStand = true
	hum.AutoRotate = false
	local initialAngle = getSignedAngle(tRoot, root.Position)
	local shortDelta = shortestDelta(initialAngle, math.pi)
	orbitDirection = shortDelta > 0 and -1 or 1
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
	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(65000, 3500, 65000)
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.Parent = root
	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(0, math.huge, 0)
	bodyGyro.P = 95000
	bodyGyro.D = 3000
	bodyGyro.Parent = root
	local startTime = tick()
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {char}
	smoothedAngle = initialAngle
	orbitConn = RunService.RenderStepped:Connect(function(dt)
		if not orbiting or not targetRoot or not targetRoot.Parent then stopOrbit() return end
		local elapsed = tick() - startTime
		if elapsed > Config.MAX_ORBIT_TIME + Config.STICK_TIME + 0.7 then stopOrbit() return end
		local root = getRoot(player.Character)
		local hum = getHum(player.Character)
		if not hum or not root or hum.Health <= 0 then stopOrbit() return end
		local behindPos = tRoot.Position - tRoot.CFrame.LookVector * STOP_BEHIND_DIST
		if elapsed <= Config.MAX_ORBIT_TIME then
			stickMode = false
			smoothedAngle = smoothedAngle + orbitDirection * math.rad(Config.ANG_SPEED_DEG) * dt * 1.12
			local localOffset = Vector3.new(math.sin(smoothedAngle) * ORBIT_RADIUS, 0, -math.cos(smoothedAngle) * ORBIT_RADIUS)
			local orbitPos = tRoot.Position + tRoot.CFrame:VectorToWorldSpace(localOffset)
			local progress = math.clamp(elapsed / Config.MAX_ORBIT_TIME, 0, 1)
			local goalFlat = orbitPos:Lerp(behindPos, math.pow(progress, 1.5))
			local rayResult = Workspace:Raycast(root.Position + Vector3.new(0,20,0), Vector3.new(0,-50,0), rayParams)
			local targetY = rayResult and (rayResult.Position.Y + GROUND_OFFSET) or (root.Position.Y + 0.3)
			local goalPos = Vector3.new(goalFlat.X, targetY, goalFlat.Z)
			local toGoal = goalPos - root.Position
			if toGoal.Magnitude > 0.5 then
				local targetVel = toGoal.Unit * (Config.MOVE_SPEED * math.clamp(toGoal.Magnitude / 6, 0.4, 1.1))
				currentVelocity = currentVelocity:Lerp(targetVel, 0.18)
			else
				currentVelocity = currentVelocity * 0.85
			end
		else
			if dashTrack then pcall(function() dashTrack:Stop() end) dashTrack = nil end
			if not stickMode then
				stickMode = true
				stickStartTime = tick()
				currentVelocity = Vector3.zero
			end
			local rayResult = Workspace:Raycast(root.Position + Vector3.new(0,16,0), Vector3.new(0,-45,0), rayParams)
			local targetY = rayResult and (rayResult.Position.Y + GROUND_OFFSET) or (root.Position.Y + 0.2)
			local stickGoal = Vector3.new(behindPos.X, targetY, behindPos.Z)
			local toStick = stickGoal - root.Position
			if toStick.Magnitude > 0.15 then
				local targetVel = toStick.Unit * Config.MOVE_SPEED * 1.5 * math.clamp(toStick.Magnitude / 3, 0.6, 1.5)
				currentVelocity = currentVelocity:Lerp(targetVel, 0.55)
			else
				currentVelocity = Vector3.zero
				root.CFrame = CFrame.new(stickGoal) * CFrame.Angles(0, math.atan2((tRoot.Position - stickGoal).X, (tRoot.Position - stickGoal).Z), 0)
			end
			if tick() - stickStartTime >= Config.STICK_TIME then
				stopOrbit()
				return
			end
		end
		bodyVelocity.Velocity = currentVelocity
		local toTargetFlat = (tRoot.Position - root.Position) * Vector3.new(1, 0, 1)
		if toTargetFlat.Magnitude > 0.35 then
			local goalCFrame = CFrame.lookAt(root.Position, root.Position + toTargetFlat.Unit)
			bodyGyro.CFrame = goalCFrame
			root.CFrame = root.CFrame:Lerp(goalCFrame, 0.88)
		end
	end)
end

-- ================== PURPLE GUI ==================
local function createConfigMenu()
	local PURPLE = Color3.fromRGB(140, 50, 200)
	local DARK_PURPLE = Color3.fromRGB(80, 20, 130)
	local BG_COLOR = Color3.fromRGB(15, 5, 25)
	local TEXT_COLOR = Color3.fromRGB(220, 180, 255)
	local INPUT_BG = Color3.fromRGB(25, 10, 40)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "OrbitConfigMenu"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 320, 0, 420)
	mainFrame.Position = UDim2.new(0.5, -160, 0.3, 0)
	mainFrame.BackgroundColor3 = BG_COLOR
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 6)
	uiCorner.Parent = mainFrame

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = PURPLE
	uiStroke.Thickness = 2
	uiStroke.Transparency = 0.3
	uiStroke.Parent = mainFrame

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 32)
	titleBar.BackgroundColor3 = Color3.fromRGB(25, 8, 45)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame
	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(0, 6)
	tbCorner.Parent = titleBar

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -10, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Le Minh Top 1 ITC"
	title.TextColor3 = PURPLE
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.Parent = titleBar

	-- Divider
	local div1 = Instance.new("Frame")
	div1.Size = UDim2.new(1, -16, 0, 1)
	div1.Position = UDim2.new(0, 8, 0, 36)
	div1.BackgroundColor3 = DARK_PURPLE
	div1.BorderSizePixel = 0
	div1.Parent = mainFrame

	-- Drag
	local dragging, dragStart, startPos
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position
		end
	end)
	titleBar.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	-- Status section
	local statusFrame = Instance.new("Frame")
	statusFrame.Size = UDim2.new(1, -16, 0, 30)
	statusFrame.Position = UDim2.new(0, 8, 0, 42)
	statusFrame.BackgroundTransparency = 1
	statusFrame.Parent = mainFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(0.5, 0, 1, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Status"
	statusLabel.TextColor3 = PURPLE
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 13
	statusLabel.Parent = statusFrame

	local statusValue = Instance.new("TextLabel")
	statusValue.Name = "StatusValue"
	statusValue.Size = UDim2.new(0.5, 0, 1, 0)
	statusValue.Position = UDim2.new(0.5, 0, 0, 0)
	statusValue.BackgroundTransparency = 1
	statusValue.Text = "ON"
	statusValue.TextColor3 = Color3.fromRGB(100, 255, 100)
	statusValue.TextXAlignment = Enum.TextXAlignment.Right
	statusValue.Font = Enum.Font.GothamBold
	statusValue.TextSize = 13
	statusValue.Parent = statusFrame

	local div2 = Instance.new("Frame")
	div2.Size = UDim2.new(1, -16, 0, 1)
	div2.Position = UDim2.new(0, 8, 0, 75)
	div2.BackgroundColor3 = DARK_PURPLE
	div2.BorderSizePixel = 0
	div2.Parent = mainFrame

	-- Config section title
	local configTitle = Instance.new("TextLabel")
	configTitle.Size = UDim2.new(1, -16, 0, 25)
	configTitle.Position = UDim2.new(0, 8, 0, 80)
	configTitle.BackgroundTransparency = 1
	configTitle.Text = "Config"
	configTitle.TextColor3 = PURPLE
	configTitle.TextXAlignment = Enum.TextXAlignment.Left
	configTitle.Font = Enum.Font.GothamBold
	configTitle.TextSize = 13
	configTitle.Parent = mainFrame

	-- Settings
	local settings = {
		{ display = "Speed (deg/s)", value = "ANG_SPEED_DEG" },
		{ display = "Stick Time (s)", value = "STICK_TIME" },
		{ display = "Orbit Time (s)", value = "MAX_ORBIT_TIME" },
		{ display = "Move Speed", value = "MOVE_SPEED" },
	}
	local yOffset = 108
	for i, setting in ipairs(settings) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -16, 0, 28)
		row.Position = UDim2.new(0, 8, 0, yOffset)
		row.BackgroundTransparency = 1
		row.Parent = mainFrame

		local dot = Instance.new("TextLabel")
		dot.Size = UDim2.new(0, 12, 1, 0)
		dot.BackgroundTransparency = 1
		dot.Text = ">"
		dot.TextColor3 = PURPLE
		dot.Font = Enum.Font.GothamBold
		dot.TextSize = 12
		dot.Parent = row

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.55, -12, 1, 0)
		label.Position = UDim2.new(0, 14, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = setting.display
		label.TextColor3 = TEXT_COLOR
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Font = Enum.Font.Gotham
		label.TextSize = 12
		label.Parent = row

		local textBox = Instance.new("TextBox")
		textBox.Size = UDim2.new(0.35, 0, 0, 22)
		textBox.Position = UDim2.new(0.63, 0, 0.5, -11)
		textBox.BackgroundColor3 = INPUT_BG
		textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		textBox.Text = tostring(Config[setting.value])
		textBox.Font = Enum.Font.GothamSemibold
		textBox.TextSize = 12
		textBox.ClearTextOnFocus = true
		textBox.Parent = row
		local tbC = Instance.new("UICorner")
		tbC.CornerRadius = UDim.new(0, 4)
		tbC.Parent = textBox
		local tbS = Instance.new("UIStroke")
		tbS.Color = DARK_PURPLE
		tbS.Thickness = 1
		tbS.Parent = textBox

		textBox.FocusLost:Connect(function()
			local num = tonumber(textBox.Text)
			if num then
				Config[setting.value] = num
				textBox.Text = tostring(num)
			else
				textBox.Text = tostring(Config[setting.value])
			end
		end)
		yOffset = yOffset + 32
	end

	-- Divider
	local div3 = Instance.new("Frame")
	div3.Size = UDim2.new(1, -16, 0, 1)
	div3.Position = UDim2.new(0, 8, 0, yOffset + 5)
	div3.BackgroundColor3 = DARK_PURPLE
	div3.BorderSizePixel = 0
	div3.Parent = mainFrame

	-- Features section
	local featTitle = Instance.new("TextLabel")
	featTitle.Size = UDim2.new(1, -16, 0, 25)
	featTitle.Position = UDim2.new(0, 8, 0, yOffset + 10)
	featTitle.BackgroundTransparency = 1
	featTitle.Text = "Features"
	featTitle.TextColor3 = PURPLE
	featTitle.TextXAlignment = Enum.TextXAlignment.Left
	featTitle.Font = Enum.Font.GothamBold
	featTitle.TextSize = 13
	featTitle.Parent = mainFrame

	-- Aimbot toggle
	local aimbotRow = Instance.new("Frame")
	aimbotRow.Size = UDim2.new(1, -16, 0, 28)
	aimbotRow.Position = UDim2.new(0, 8, 0, yOffset + 38)
	aimbotRow.BackgroundTransparency = 1
	aimbotRow.Parent = mainFrame

	local aimbotCheck = Instance.new("TextButton")
	aimbotCheck.Size = UDim2.new(0, 18, 0, 18)
	aimbotCheck.Position = UDim2.new(0, 0, 0.5, -9)
	aimbotCheck.BackgroundColor3 = INPUT_BG
	aimbotCheck.Text = ""
	aimbotCheck.Parent = aimbotRow
	local acC = Instance.new("UICorner")
	acC.CornerRadius = UDim.new(0, 3)
	acC.Parent = aimbotCheck
	local acS = Instance.new("UIStroke")
	acS.Color = DARK_PURPLE
	acS.Thickness = 1
	acS.Parent = aimbotCheck

	local aimbotX = Instance.new("TextLabel")
	aimbotX.Size = UDim2.new(1, 0, 1, 0)
	aimbotX.BackgroundTransparency = 1
	aimbotX.Text = "X"
	aimbotX.TextColor3 = Color3.fromRGB(255, 80, 80)
	aimbotX.Font = Enum.Font.GothamBold
	aimbotX.TextSize = 14
	aimbotX.Parent = aimbotCheck

	local aimbotLabel = Instance.new("TextLabel")
	aimbotLabel.Size = UDim2.new(0.8, -22, 1, 0)
	aimbotLabel.Position = UDim2.new(0, 24, 0, 0)
	aimbotLabel.BackgroundTransparency = 1
	aimbotLabel.Text = "Aimbot"
	aimbotLabel.TextColor3 = TEXT_COLOR
	aimbotLabel.TextXAlignment = Enum.TextXAlignment.Left
	aimbotLabel.Font = Enum.Font.Gotham
	aimbotLabel.TextSize = 12
	aimbotLabel.Parent = aimbotRow

	aimbotCheck.MouseButton1Click:Connect(function()
		if not aimbotLoaded then
			aimbotLoaded = true
			aimbotX.Text = "V"
			aimbotX.TextColor3 = Color3.fromRGB(100, 255, 100)
			task.spawn(function()
				loadstring(game:HttpGet("https://raw.githubusercontent.com/ttwizz/Open-Aimbot/master/source.lua", true))()
			end)
		end
	end)

	-- Bottom buttons
	local resetBtn = Instance.new("TextButton")
	resetBtn.Size = UDim2.new(0.45, 0, 0, 28)
	resetBtn.Position = UDim2.new(0.025, 0, 1, -40)
	resetBtn.BackgroundColor3 = DARK_PURPLE
	resetBtn.Text = "Reset"
	resetBtn.TextColor3 = TEXT_COLOR
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextSize = 12
	resetBtn.Parent = mainFrame
	local rC = Instance.new("UICorner")
	rC.CornerRadius = UDim.new(0, 4)
	rC.Parent = resetBtn

	resetBtn.MouseButton1Click:Connect(function()
		Config.ANG_SPEED_DEG = 800
		Config.STICK_TIME = 0.5
		Config.MAX_ORBIT_TIME = 0.3
		Config.MOVE_SPEED = 100
		for _, child in ipairs(mainFrame:GetDescendants()) do
			if child:IsA("TextBox") then
				local row = child.Parent
				local lbl = row:FindFirstChildOfClass("TextLabel")
				if lbl then
					if lbl.Text:find("Speed") and not lbl.Text:find("Move") then child.Text = "800"
					elseif lbl.Text:find("Stick") then child.Text = "0.5"
					elseif lbl.Text:find("Orbit") then child.Text = "0.3"
					elseif lbl.Text:find("Move") then child.Text = "100" end
				end
			end
		end
	end)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0.45, 0, 0, 28)
	closeBtn.Position = UDim2.new(0.525, 0, 1, -40)
	closeBtn.BackgroundColor3 = Color3.fromRGB(130, 20, 50)
	closeBtn.Text = "Close"
	closeBtn.TextColor3 = TEXT_COLOR
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 12
	closeBtn.Parent = mainFrame
	local cC = Instance.new("UICorner")
	cC.CornerRadius = UDim.new(0, 4)
	cC.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		screenGui:Destroy()
	end)

	-- Update status
	task.spawn(function()
		while screenGui.Parent do
			local sv = statusFrame:FindFirstChild("StatusValue")
			if sv then
				sv.Text = enabled and "ON" or "OFF"
				sv.TextColor3 = enabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 80, 80)
			end
			task.wait(0.5)
		end
	end)
end
createConfigMenu()

UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.C then
		local now = tick()
		if now - lastUse < COOLDOWN or not enabled then return end
		lastUse = now
		if orbiting then
			stopOrbit()
		else
			task.spawn(blackflash)
			task.delay(BLACKFLASH_DELAY, function()
				if enabled and not orbiting then
					startOrbit()
				end
			end)
		end
	elseif input.KeyCode == Enum.KeyCode.Insert then
		enabled = not enabled
		print("Bay Orbit: " .. (enabled and "ON" or "OFF"))
		if not enabled then stopOrbit() end
	end
end)
local function onCharacterAdded(char)
	task.wait(1.2)
	stopOrbit()
end
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end
print("SIDE DASH ORBIT + BLACK FLASH READY")
print("C = Dash Orbit + BF | Insert = ON/OFF")
