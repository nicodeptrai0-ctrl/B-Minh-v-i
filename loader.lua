local KEY_URL = "https://raw.githubusercontent.com/nicodeptrai0-ctrl/B-Minh-v-i/main/keys.txt"
local SCRIPT_URL = "https://raw.githubusercontent.com/nicodeptrai0-ctrl/B-Minh-v-i/main/script.lua"
local DISCORD = "https://discord.gg/LINK_DISCORD_CUA_BAN"
local player = game:GetService("Players").LocalPlayer

local function parseDate(str)
	local y, m, d = str:match("(%d+)-(%d+)-(%d+)")
	if y and m and d then
		return os.time({year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=23, min=59, sec=59})
	end
	return 0
end

local function getTimeLeft(expiry)
	local diff = expiry - os.time()
	if diff <= 0 then return nil end
	local days = math.floor(diff / 86400)
	local hours = math.floor((diff % 86400) / 3600)
	if days > 0 then
		return days .. " ngay " .. hours .. " gio"
	else
		local mins = math.floor((diff % 3600) / 60)
		return hours .. " gio " .. mins .. " phut"
	end
end

local keyGui = Instance.new("ScreenGui")
keyGui.Name = "KeySystem"
keyGui.ResetOnSpawn = false
keyGui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.new(0, 320, 0, 230)
bg.Position = UDim2.new(0.5, -160, 0.5, -115)
bg.BackgroundColor3 = Color3.fromRGB(15, 5, 25)
bg.BorderSizePixel = 0
bg.Parent = keyGui
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)
local s = Instance.new("UIStroke", bg)
s.Color = Color3.fromRGB(140, 50, 200)
s.Thickness = 2

local t = Instance.new("TextLabel")
t.Size = UDim2.new(1, 0, 0, 35)
t.BackgroundTransparency = 1
t.Text = "B-Minh Script - Key System"
t.TextColor3 = Color3.fromRGB(140, 50, 200)
t.Font = Enum.Font.GothamBold
t.TextSize = 15
t.Parent = bg

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, -20, 0, 20)
info.Position = UDim2.new(0, 10, 0, 35)
info.BackgroundTransparency = 1
info.Text = "Nhap key de su dung script"
info.TextColor3 = Color3.fromRGB(180, 150, 220)
info.Font = Enum.Font.Gotham
info.TextSize = 12
info.Parent = bg

local input = Instance.new("TextBox")
input.Size = UDim2.new(0.85, 0, 0, 32)
input.Position = UDim2.new(0.075, 0, 0, 65)
input.BackgroundColor3 = Color3.fromRGB(25, 10, 40)
input.TextColor3 = Color3.new(1, 1, 1)
input.PlaceholderText = "Nhap key tai day..."
input.PlaceholderColor3 = Color3.fromRGB(100, 80, 130)
input.Text = ""
input.Font = Enum.Font.GothamSemibold
input.TextSize = 13
input.ClearTextOnFocus = true
input.Parent = bg
Instance.new("UICorner", input).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", input).Color = Color3.fromRGB(80, 20, 130)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -10, 0, 18)
status.Position = UDim2.new(0, 5, 0, 105)
status.BackgroundTransparency = 1
status.Text = ""
status.TextColor3 = Color3.fromRGB(255, 80, 80)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.Parent = bg

local timeLeft = Instance.new("TextLabel")
timeLeft.Size = UDim2.new(1, -10, 0, 18)
timeLeft.Position = UDim2.new(0, 5, 0, 125)
timeLeft.BackgroundTransparency = 1
timeLeft.Text = ""
timeLeft.TextColor3 = Color3.fromRGB(100, 200, 255)
timeLeft.Font = Enum.Font.GothamSemibold
timeLeft.TextSize = 11
timeLeft.Parent = bg

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0.4, 0, 0, 30)
btn.Position = UDim2.new(0.05, 0, 0, 155)
btn.BackgroundColor3 = Color3.fromRGB(140, 50, 200)
btn.Text = "Verify Key"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 13
btn.Parent = bg
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

local dcBtn = Instance.new("TextButton")
dcBtn.Size = UDim2.new(0.4, 0, 0, 30)
dcBtn.Position = UDim2.new(0.55, 0, 0, 155)
dcBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
dcBtn.Text = "Discord"
dcBtn.TextColor3 = Color3.new(1, 1, 1)
dcBtn.Font = Enum.Font.GothamBold
dcBtn.TextSize = 13
dcBtn.Parent = bg
Instance.new("UICorner", dcBtn).CornerRadius = UDim.new(0, 5)

dcBtn.MouseButton1Click:Connect(function()
	if setclipboard then
		setclipboard(DISCORD)
		status.Text = "Da copy link Discord!"
		status.TextColor3 = Color3.fromRGB(100, 255, 100)
	end
end)

btn.MouseButton1Click:Connect(function()
	status.Text = "Dang kiem tra..."
	status.TextColor3 = Color3.fromRGB(255, 200, 50)
	timeLeft.Text = ""

	local ok, keys = pcall(function()
		return game:HttpGet(KEY_URL)
	end)
	if not ok then
		status.Text = "Loi ket noi!"
		status.TextColor3 = Color3.fromRGB(255, 80, 80)
		return
	end

	local userKey = input.Text:gsub("%s+", "")
	for line in keys:gmatch("[^\r\n]+") do
		local key, expiry = line:match("^(.-)|(.*)")
		if not key then key = line; expiry = "9999-12-31" end
		key = key:gsub("%s+", "")
		expiry = expiry:gsub("%s+", "")

		if key == userKey and userKey ~= "" then
			local expiryTime = parseDate(expiry)
			local now = os.time()

			if now > expiryTime then
				status.Text = "Key da het han!"
				status.TextColor3 = Color3.fromRGB(255, 80, 80)
				timeLeft.Text = "Het han: " .. expiry
				timeLeft.TextColor3 = Color3.fromRGB(255, 80, 80)
				return
			end

			local remaining = getTimeLeft(expiryTime)
			status.Text = "Key hop le! Loading..."
			status.TextColor3 = Color3.fromRGB(100, 255, 100)
			timeLeft.Text = "Con lai: " .. (remaining or "Lifetime")
			timeLeft.TextColor3 = Color3.fromRGB(100, 200, 255)

			task.wait(1.5)
			keyGui:Destroy()
			loadstring(game:HttpGet(SCRIPT_URL))()
			return
		end
	end

	status.Text = "Key khong hop le!"
	status.TextColor3 = Color3.fromRGB(255, 80, 80)
end)
