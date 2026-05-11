--[[
    KEY SYSTEM - BO MINH VI DAI
    Fetch keys from GitHub + load script from GitHub
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- ================== CONFIG ==================
local CONFIG = {
    -- Link file KEY tren GitHub (mỗi dòng là 1 key)
    KEYS_URL = "https://raw.githubusercontent.com/nicodeptrai0-ctrl/BoMinhViDai/main/jujutsushenanigans/main/0396196227a.txt",

    -- Link script chinh
    SCRIPT_URL = "https://raw.githubusercontent.com/nicodeptrai0-ctrl/BoMinhViDai/main/jujutsushenanigans/main/conmemaytrungcho.lua",
}

local THEME = {
    Background = Color3.fromRGB(12, 12, 14),
    Surface = Color3.fromRGB(18, 18, 22),
    Text = Color3.fromRGB(220, 220, 230),
    TextMuted = Color3.fromRGB(140, 145, 160),
    Accent = Color3.fromRGB(170, 45, 45),
    Border = Color3.fromRGB(40, 42, 50),
    Danger = Color3.fromRGB(180, 70, 70),
    Success = Color3.fromRGB(70, 160, 100),
    Warning = Color3.fromRGB(200, 170, 50),
}

-- Cache key
local cachedKeys = nil
local keyLoadFailed = false

-- ================== FETCH KEYS FROM GITHUB ==================
local function fetchKeysFromGitHub()
    if cachedKeys then return cachedKeys, true end
    if keyLoadFailed then return nil, false end

    local success, result = pcall(function()
        local response = game:HttpGet(CONFIG.KEYS_URL)
        -- Strip BOM if present
        response = response:gsub("^\xEF\xBB\xBF", "")
        print("[Debug] Raw response bytes: " .. #response)
        print("[Debug] Response repr: " .. response:sub(1, 100):gsub(".", function(c) return string.format("\\%d", string.byte(c)) end))
        local keys = {}
        for line in response:gmatch("[^\r\n]+") do
            local trimmed = line:gsub("^%s*(.-)%s*$", "%1")
            if trimmed ~= "" and trimmed:sub(1, 2) ~= "--" then
                -- Format: KEY|expiry (hoặc KEY|expiry|extra)
                local keyOnly = trimmed:match("^([^|]+)")
                if keyOnly then
                    local k = keyOnly:gsub("^%s*(.-)%s*$", "%1")
                    if k ~= "" then
                        table.insert(keys, k)
                    end
                end
            end
        end
        return keys
    end)

    if success and result and #result > 0 then
        cachedKeys = result
        print("[KeySystem] Loaded " .. #result .. " keys from GitHub")
        return result, true
    else
        keyLoadFailed = true
        warn("[KeySystem] Failed to load keys from GitHub: " .. tostring(result))
        return nil, false
    end
end

local function validateKey(key)
    print("[Debug] User entered: [" .. key .. "] len=" .. #key)
    local keys, loaded = fetchKeysFromGitHub()
    if not loaded then
        warn("[KeySystem] Cannot validate - keys not loaded")
        return false
    end
    print("[Debug] Total keys: " .. #keys)
    for i, validKey in ipairs(keys) do
        print("[Debug] Comparing user [" .. key .. "] with key #" .. i .. " [" .. validKey .. "] len=" .. #validKey)
        if key == validKey then
            print("[Debug] MATCH!")
            return true
        end
    end
    print("[Debug] No match found")
    return false
end

-- ================== GUI ELEMENTS ==================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KeySystem_GUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Background overlay
local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.3
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

-- Dialog box
local dialog = Instance.new("Frame")
dialog.Size = UDim2.new(0, 400, 0, 360)
dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
dialog.AnchorPoint = Vector2.new(0.5, 0.5)
dialog.BackgroundColor3 = THEME.Background
dialog.BorderSizePixel = 0
dialog.Parent = screenGui
Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 16)

local border = Instance.new("UIStroke", dialog)
border.Color = THEME.Accent
border.Thickness = 1

-- Logo
local logoFrame = Instance.new("Frame")
logoFrame.Size = UDim2.new(0, 80, 0, 80)
logoFrame.Position = UDim2.new(0.5, -40, 0, 25)
logoFrame.BackgroundTransparency = 1
logoFrame.Parent = dialog

local logoImg = Instance.new("ImageLabel")
logoImg.Size = UDim2.new(1, 0, 1, 0)
logoImg.BackgroundTransparency = 1
logoImg.Image = "rbxassetid://74401499826061"
logoImg.ScaleType = Enum.ScaleType.Fit
logoImg.Parent = logoFrame

-- Title
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -40, 0, 32)
titleLbl.Position = UDim2.new(0, 20, 0, 112)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "Jujutsu Shenanigans"
titleLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
titleLbl.TextSize = 22
titleLbl.TextColor3 = THEME.Text
titleLbl.Parent = dialog

-- Subtitle
local subLbl = Instance.new("TextLabel")
subLbl.Size = UDim2.new(1, -40, 0, 20)
subLbl.Position = UDim2.new(0, 20, 0, 145)
subLbl.BackgroundTransparency = 1
subLbl.Text = "Enter your key to access"
subLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
subLbl.TextSize = 13
subLbl.TextTransparency = 0.4
subLbl.TextColor3 = THEME.TextMuted
subLbl.Parent = dialog

-- Input box
local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, -40, 0, 42)
inputFrame.Position = UDim2.new(0, 20, 0, 175)
inputFrame.BackgroundColor3 = THEME.Surface
inputFrame.BorderSizePixel = 0
inputFrame.Parent = dialog
Instance.new("UICorner", inputFrame).CornerRadius = UDim.new(0, 10)

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -16, 1, 0)
inputBox.Position = UDim2.new(0, 8, 0, 0)
inputBox.BackgroundTransparency = 1
inputBox.Text = ""
inputBox.PlaceholderText = "Enter your key here..."
inputBox.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
inputBox.TextSize = 14
inputBox.TextColor3 = THEME.Text
inputBox.PlaceholderColor3 = THEME.TextMuted
inputBox.Parent = inputFrame

-- Status label
local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -40, 0, 18)
statusLbl.Position = UDim2.new(0, 20, 0, 222)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = ""
statusLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
statusLbl.TextSize = 12
statusLbl.Parent = dialog

-- Error label
local errorLbl = Instance.new("TextLabel")
errorLbl.Size = UDim2.new(1, -40, 0, 18)
errorLbl.Position = UDim2.new(0, 20, 0, 245)
errorLbl.BackgroundTransparency = 1
errorLbl.Text = ""
errorLbl.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
errorLbl.TextSize = 12
errorLbl.TextColor3 = THEME.Danger
errorLbl.Parent = dialog

-- Submit button
local submitBtn = Instance.new("TextButton")
submitBtn.Size = UDim2.new(1, -40, 0, 40)
submitBtn.Position = UDim2.new(0, 20, 0, 295)
submitBtn.BackgroundColor3 = THEME.Accent
submitBtn.BorderSizePixel = 0
submitBtn.Text = "SUBMIT"
submitBtn.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold)
submitBtn.TextSize = 15
submitBtn.TextColor3 = THEME.Text
submitBtn.AutoButtonColor = false
submitBtn.Parent = dialog
Instance.new("UICorner", submitBtn).CornerRadius = UDim.new(0, 10)

-- Hover effect
submitBtn.MouseEnter:Connect(function()
    TweenService:Create(submitBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(200, 55, 55)
    }):Play()
end)
submitBtn.MouseLeave:Connect(function()
    TweenService:Create(submitBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = THEME.Accent
    }):Play()
end)

-- ================== ENTRANCE ANIMATION ==================
dialog.Size = UDim2.new(0, 0, 0, 0)
dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
TweenService:Create(dialog, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
    Size = UDim2.new(0, 400, 0, 360),
    Position = UDim2.new(0.5, 0, 0.5, 0)
}):Play()

-- ================== LOAD SCRIPT ==================
local function loadMainScript()
    statusLbl.Text = "Loading script..."
    statusLbl.TextColor3 = THEME.Warning

    local success, result = pcall(function()
        return loadstring(game:HttpGet(CONFIG.SCRIPT_URL))()
    end)

    if success then
        statusLbl.Text = "Script loaded successfully!"
        statusLbl.TextColor3 = THEME.Success
        print("[KeySystem] Script loaded from GitHub")
    else
        errorLbl.Text = "Failed to load script!"
        statusLbl.Text = ""
        warn("[KeySystem] Failed to load script: " .. tostring(result))
    end
end

-- ================== SUBMIT HANDLER ==================
local function shakeError()
    TweenService:Create(inputFrame, TweenInfo.new(0.1), {
        BackgroundColor3 = Color3.fromRGB(50, 20, 20)
    }):Play()
    TweenService:Create(submitBtn, TweenInfo.new(0.06, Enum.EasingStyle.Back), {
        Size = UDim2.new(1, -44, 0, 44)
    }):Play()
    task.wait(0.06)
    TweenService:Create(submitBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back), {
        Size = UDim2.new(1, -40, 0, 40)
    }):Play()
    task.wait(0.3)
    TweenService:Create(inputFrame, TweenInfo.new(0.2), {
        BackgroundColor3 = THEME.Surface
    }):Play()
end

local function onSubmit()
    local key = inputBox.Text

    if key == "" then
        errorLbl.Text = "Please enter a key!"
        shakeError()
        return
    end

    statusLbl.Text = "Validating key..."
    statusLbl.TextColor3 = THEME.Warning
    errorLbl.Text = ""

    -- Fetch keys if not loaded yet
    if not cachedKeys and not keyLoadFailed then
        local _, loaded = fetchKeysFromGitHub()
        if not loaded then
            errorLbl.Text = "Cannot connect to server!"
            statusLbl.Text = ""
            shakeError()
            return
        end
    end

    if validateKey(key) then
        -- Success
        submitBtn.Text = "ACCESS GRANTED!"
        submitBtn.BackgroundColor3 = THEME.Success
        statusLbl.Text = "Key accepted!"
        statusLbl.TextColor3 = THEME.Success
        TweenService:Create(submitBtn, TweenInfo.new(0.06, Enum.EasingStyle.Back), {
            Size = UDim2.new(1, -44, 0, 44)
        }):Play()
        task.wait(0.06)
        TweenService:Create(submitBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back), {
            Size = UDim2.new(1, -40, 0, 40)
        }):Play()
        task.wait(0.8)

        -- Close key system
        TweenService:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        TweenService:Create(dialog, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 400, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 180)
        }):Play()
        task.wait(0.45)
        screenGui:Destroy()

        -- Load main script
        loadMainScript()
    else
        errorLbl.Text = "Invalid key! Try again."
        statusLbl.Text = ""
        shakeError()
        inputBox:ClearText()
    end
end

-- Submit events
submitBtn.MouseButton1Click:Connect(onSubmit)
inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        onSubmit()
    end
end)

print("==================================")
print("KEY SYSTEM - BO MINH VI DAI")


