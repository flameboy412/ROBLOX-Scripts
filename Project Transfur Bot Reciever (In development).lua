-- RECEIVER: listens for private whispers instead of HTTPS. Place in StarterPlayerScripts on the receiver client.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local SENDER_NAME = "XXXm00r"  -- the sender who will whisper commands
local OWNER_NAME = "XXXm00r"   -- exclude on flingall

local SUCCESS_VEL = 80
local SUCCESS_DIST = 25
local DETECT_WINDOW = 3.0

local function notify(t, m)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title=t, Text=m, Duration=2})
    end)
end

-- SkidFling (unchanged core)
local FlingActive = false
getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

local function SkidFling(TargetPlayer)
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local RootPart = Humanoid.RootPart
    local TCharacter = TargetPlayer.Character
    if not TCharacter then return end

    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")

    if RootPart.Velocity.Magnitude < 50 then
        getgenv().OldPos = RootPart.CFrame
    end
    if THumanoid and THumanoid.Sit then return end

    if THead then
        workspace.CurrentCamera.CameraSubject = THead
    elseif Handle then
        workspace.CurrentCamera.CameraSubject = Handle
    elseif THumanoid and TRootPart then
        workspace.CurrentCamera.CameraSubject = THumanoid
    end
    if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end

    local function FPos(BasePart, Pos, Ang)
        RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
        Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
        RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local function SFBasePart(BasePart)
        local TimeToWait = 2
        local t0 = tick()
        local Angle = 0
        repeat
            if BasePart and BasePart.Parent and Humanoid.Parent then
                if BasePart.Velocity.Magnitude < 50 then
                    Angle += 100
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + Humanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0)); task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + Humanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + Humanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0)); task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + Humanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + Humanoid.MoveDirection, CFrame.Angles(math.rad(Angle),0 ,0)); task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + Humanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                else
                    FPos(BasePart, CFrame.new(0, 1.5, Humanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, -Humanoid.WalkSpeed), CFrame.Angles(0, 0, 0)); task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, Humanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)); task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)); task.wait()
                end
            end
        until t0 + TimeToWait < tick() or not FlingActive
    end

    workspace.FallenPartsDestroyHeight = 0/0

    local BV = Instance.new("BodyVelocity")
    BV.Parent = RootPart
    BV.Velocity = Vector3.new(0, 0, 0)
    BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    if TRootPart then
        SFBasePart(TRootPart)
    elseif THead then
        SFBasePart(THead)
    elseif Handle then
        SFBasePart(Handle)
    end

    BV:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = Humanoid

    if getgenv().OldPos then
        repeat
            RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
            Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
            Humanoid:ChangeState("GettingUp")
            for _, part in pairs(Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity, part.RotVelocity = Vector3.new(), Vector3.new()
                end
            end
            task.wait()
        until (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
        workspace.FallenPartsDestroyHeight = getgenv().FPDH
    end
end

local function detectSuccess(target)
    local char = target.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if not hum or not root then return false end

    local startPos = root.Position
    local ok = false
    local t0 = tick()
    while tick() - t0 < DETECT_WINDOW do
        if not hum.Parent or not root.Parent then break end
        local vel = root.Velocity.Magnitude
        local dist = (root.Position - startPos).Magnitude
        local st = hum:GetState()
        if vel >= SUCCESS_VEL or dist >= SUCCESS_DIST
            or st == Enum.HumanoidStateType.Freefall
            or st == Enum.HumanoidStateType.FallingDown
            or st == Enum.HumanoidStateType.Ragdoll then
            ok = true
            break
        end
        RunService.Heartbeat:Wait()
    end
    return ok
end

local function flingOnceWithDetect(target)
    if not target or target == LocalPlayer then return false end
    FlingActive = true
    task.spawn(function() pcall(function() SkidFling(target) end) end)
    local ok = detectSuccess(target)
    FlingActive = false
    return ok
end

local allLoop
local function startFlingAll(ownerFrom)
    if allLoop then return end
    allLoop = task.spawn(function()
        local marked = {}
        while allLoop do
            local list = Players:GetPlayers()
            for i = 1, #list do
                local pl = list[i]
                if pl ~= LocalPlayer and pl.Name ~= OWNER_NAME and pl.Name ~= ownerFrom and not marked[pl.UserId] then
                    local ok = flingOnceWithDetect(pl)
                    if ok then
                        marked[pl.UserId] = true
                    end
                    task.wait(0.1)
                end
            end
            task.wait(0.25)
        end
    end)
end

local function stopAll()
    FlingActive = false
    if allLoop then allLoop = nil end
end

-- Handle incoming private whispers
local function handleWhisper(senderPlayer, message)
    -- Only accept whispers from the designated sender
    if not senderPlayer or senderPlayer.Name ~= SENDER_NAME then return end

    -- Parse semicolon-prefixed commands
    if message:sub(1, 1) == ";" then
        local cmd = message:sub(2):gsub("^%s+", ""):gsub("%s+$", "")
        local lower = cmd:lower()

        if lower == "unfling" then
            stopAll()
            notify("Receiver", "Unfling command received")

        elseif lower == "flingall" then
            stopAll()
            startFlingAll(SENDER_NAME)
            notify("Receiver", "Flinging all (except "..OWNER_NAME..")")

        elseif lower:sub(1,6) == "fling " then
            stopAll()
            local targetName = cmd:sub(7)
            if #targetName > 0 then
                local target
                local list = Players:GetPlayers()
                for i = 1, #list do
                    local p = list[i]
                    if p ~= LocalPlayer then
                        if p.Name:lower():sub(1,#targetName) == targetName:lower()
                            or (p.DisplayName and p.DisplayName:lower():sub(1,#targetName) == targetName:lower()) then
                            target = p
                            break
                        end
                    end
                end

                if target and target.Name ~= OWNER_NAME and target.Name ~= SENDER_NAME then
                    local ok = flingOnceWithDetect(target)
                    notify("Receiver", (ok and "Fling successful" or "Fling failed") .. ": " .. target.Name)
                else
                    notify("Receiver", "Target not found or protected: " .. targetName)
                end
            end
        end
    end
end

-- Set up whisper listeners (TextChatService or Legacy)
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    -- Listen for direct messages
    local function checkDirectMessages()
        while true do
            local success, messages = pcall(function()
                return TextChatService:GetDirectMessagesAsync()
            end)
            if success and messages then
                for _, msg in ipairs(messages) do
                    local senderPlayer = Players:GetPlayerByUserId(msg.AuthorUserId)
                    if senderPlayer and senderPlayer.Name == SENDER_NAME then
                        handleWhisper(senderPlayer, msg.Text)
                    end
                end
            end
            task.wait(1.0)
        end
    end
    task.spawn(checkDirectMessages)
else
    -- Legacy chat system - listen for whisper events
    local events = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents", 10)
    local onWhisper = events and events:FindFirstChild("OnWhisperMessage")
    if onWhisper then
        onWhisper.OnClientEvent:Connect(function(from, msg)
            local sender = Players:FindFirstChild(from)
            handleWhisper(sender, msg)
        end)
    end
end

notify("Receiver Ready", "Listening for whispers from "..SENDER_NAME)