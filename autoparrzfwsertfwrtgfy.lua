-- Auto Parry (Blade Ball / аналог). Требует executor с getconnections.
local StarterGui = game:GetService("StarterGui")
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")

local Player = Players.LocalPlayer

local CONFIG = {
    ToggleKey    = Enum.KeyCode.K,
    ParryWindow  = 0.55,
    Cooldown     = 0.15,
    MinBallSpeed = 1,
    NotifyTime   = 2,
}

local S = { enabled = false, lastParry = 0, isParried = false, indicator = nil }

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = dur or CONFIG.NotifyTime,
        })
    end)
end

local function getBallsContainer()
    return workspace:FindFirstChild("Balls")
end

local function getHRP()
    local ch = Player.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function getIncomingBall()
    local c = getBallsContainer()
    if not c then return nil, nil end
    local hrp = getHRP()
    if not hrp then return nil, nil end
    local best, bestT = nil, math.huge
    for _, ball in ipairs(c:GetChildren()) do
        if ball:GetAttribute("realBall") and ball:GetAttribute("target") == Player.Name then
            local zoomies = ball:FindFirstChild("zoomies")
            if zoomies and zoomies:IsA("BodyVelocity") then
                local speed = zoomies.VectorVelocity.Magnitude
                if speed >= CONFIG.MinBallSpeed then
                    local t = (hrp.Position - ball.Position).Magnitude / speed
                    if t < bestT then bestT = t; best = ball end
                end
            end
        end
    end
    return best, bestT
end

local function fireBlock()
    local pgui = Player:FindFirstChild("PlayerGui")
    if not pgui then return false end
    local hotbar = pgui:FindFirstChild("Hotbar")
    if not hotbar then return false end
    local block = hotbar:FindFirstChild("Block")
    if not block then return false end
    local any = false
    for _, sig in ipairs({block.Activated, block.MouseButton1Click, block.MouseButton1Down}) do
        local ok = pcall(function()
            for _, c in pairs(getconnections(sig)) do c:Fire() end
        end)
        if ok then any = true end
    end
    return any
end

local function tryParry()
    local now = tick()
    if now - S.lastParry < CONFIG.Cooldown then return end
    if S.isParried then return end
    local ball, t = getIncomingBall()
    if not ball or not t then return end
    if t > CONFIG.ParryWindow then return end
    if fireBlock() then
        S.lastParry = now
        S.isParried = true
        task.delay(0.4, function() S.isParried = false end)
    end
end

local watched = {}
local function attachBall(ball)
    if watched[ball] then return end
    watched[ball] = true
    ball:GetAttributeChangedSignal("target"):Connect(function()
        S.isParried = false
    end)
    ball.AncestryChanged:Connect(function(_, parent)
        if not parent then watched[ball] = nil end
    end)
end

local function scanBalls()
    local c = getBallsContainer()
    if not c then return end
    for _, b in ipairs(c:GetChildren()) do attachBall(b) end
end

task.spawn(function()
    while not getBallsContainer() do task.wait(0.5) end
    scanBalls()
    getBallsContainer().ChildAdded:Connect(attachBall)
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == CONFIG.ToggleKey then
        S.enabled = not S.enabled
        notify("Auto Parry", S.enabled and "ON" or "OFF", CONFIG.NotifyTime)
        if S.indicator then
            S.indicator.Text = "AutoParry: " .. (S.enabled and "ON" or "OFF") .. " [K]"
            S.indicator.TextColor3 = S.enabled and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(255, 80, 80)
        end
    end
end)

task.spawn(function()
    local pgui = Player:WaitForChild("PlayerGui")
    local lbl = Instance.new("TextLabel")
    lbl.Name = "AutoParryIndicator"
    lbl.Size = UDim2.new(0, 200, 0, 28)
    lbl.Position = UDim2.new(0, 10, 0, 10)
    lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    lbl.BackgroundTransparency = 0.4
    lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
    lbl.Text = "AutoParry: OFF [K]"
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 15
    lbl.ZIndex = 10
    lbl.Parent = pgui
    S.indicator = lbl
end)

RunService.PreSimulation:Connect(function()
    if not S.enabled then return end
    local ok, err = pcall(tryParry)
    if not ok then warn("[AutoParry] ", err) end
end)
