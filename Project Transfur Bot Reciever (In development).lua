-- LocalScript (RECEIVER: ic33srr) — Listens for private chat from "XXXm00r" and executes fling commands
-- Place in StarterPlayerScripts or StarterGui on ic33srr's client.

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local OWNER_NAME = "XXXm00r" -- sender
local ownerPlayer = nil

-- Notify helper
local function toast(t, m)
    pcall(function() StarterGui:SetCore("SendNotification", {Title=t, Text=m, Duration=2}) end)
end

-- Fling implementation (SkidFling + success detect)
local FlingActive = false
getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

local SUCCESS_VEL = 80
local SUCCESS_DIST = 25
local DETECT_WINDOW = 3.0

local function SkidFling(TargetPlayer)
    local Player     = LocalPlayer
    local Character  = Player.Character
    local Humanoid   = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart   = Humanoid and Humanoid.RootPart
    local TCharacter = TargetPlayer.Character
    if not (Character and Humanoid and RootPart and TCharacter) then return end

    local THumanoid  = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart  = THumanoid and THumanoid.RootPart
    local THead      = TCharacter:FindFirstChild("Head")
    local Accessory  = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle     = Accessory and Accessory:FindFirstChild("Handle")

    if RootPart.Velocity.Magnitude < 50 then getgenv().OldPos = RootPart.CFrame end
    if THumanoid and THumanoid.Sit then return end

    if THead then workspace.CurrentCamera.CameraSubject = THead
    elseif Handle then workspace.CurrentCamera.CameraSubject = Handle
    elseif THumanoid then workspace.CurrentCamera.CameraSubject = THumanoid end
    if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end

    local function FPos(BasePart, Pos, Ang)
        RootPart.CFrame     = CFrame.new(BasePart.Position) * Pos * Ang
        Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
        RootPart.Velocity   = Vector3.new(9e7, 9e8, 9e7)
        RootPart.RotVelocity= Vector3.new(9e8, 9e8, 9e8)
    end

    local function SF(BasePart)
        local t0, Angle = tick(),0
        repeat
            if BasePart.Velocity.Magnitude < 50 then
                Angle += 100
                FPos(BasePart, CFrame.new(0, 1.5, 0) , CFrame.Angles(math.rad(Angle),0 ,0)); task.wait()
                FPos(BasePart, CFrame.new(0,-1.5, 0) , CFrame.Angles(math.rad(Angle),0 ,0)); task.wait()
            else
                FPos(BasePart, CFrame.new(0, 1.5, Humanoid.WalkSpeed), CFrame.Angles(math.rad(90),0,0)); task.wait()
                FPos(BasePart, CFrame.new(0,-1.5,-Humanoid.WalkSpeed), CFrame.Angles(0,0,0));           task.wait()
            end
        until tick()-t0 > 2 or not FlingActive
    end

    workspace.FallenPartsDestroyHeight = 0/0
    local bv      = Instance.new("BodyVelocity",RootPart)
    bv.Velocity   = Vector3.zero
    bv.MaxForce   = Vector3.new(9e9,9e9,9e9)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,false)

    if TRootPart then       SF(TRootPart)
    elseif THead then       SF(THead)
    elseif Handle then      SF(Handle) end

    bv:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,true)
    workspace.CurrentCamera.CameraSubject = Humanoid

    if getgenv().OldPos then
        repeat
            RootPart.CFrame = getgenv().OldPos * CFrame.new(0,.5,0)
            Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0,.5,0))
            Humanoid:ChangeState("GettingUp")
            for _,p in ipairs(Character:GetChildren()) do
                if p:IsA("BasePart") then p.Velocity, p.RotVelocity = Vector3.zero, Vector3.zero end
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

-- Fling-all loop
local flingAllThread
local function startFlingAll()
    if flingAllThread then return end
    flingAllThread = task.spawn(function()
        local done = {}
        while flingAllThread do
            local list = Players:GetPlayers()
            for i = 1, #list do
                local pl = list[i]
                if pl ~= LocalPlayer and pl.Name ~= OWNER_NAME and not done[pl.UserId] then
                    local ok = flingOnceWithDetect(pl)
                    if ok then
                        done[pl.UserId] = true
                    end
                    task.wait(0.1)
                end
            end
            task.wait(0.25)
        end
    end)
    toast("Receiver", "Flinging all (except "..OWNER_NAME..")")
end
local function stopAll()
    FlingActive = false
    if flingAllThread then flingAllThread = nil end
    toast("Receiver", "Stopped fling")
end

-- Handle incoming DM text (string beginning with ';')
local function handleDMText(fromName, text)
    if fromName ~= OWNER_NAME then return end
    if type(text) ~= "string" then return end
    local t = text:lower()
    if t:sub(1,1) ~= ";" then return end
    t = t:sub(2) -- remove ';'
    if t == "flingall" then
        stopAll()
        startFlingAll()
        return
    end
    if t == "unfling" then
        stopAll()
        return
    end
    local who = t:match("^fling%s+(.+)$")
    if who and #who > 0 then
        local target = nil
        local list = Players:GetPlayers()
        for i = 1, #list do
            local p = list[i]
            if p ~= LocalPlayer and p.Name:lower():sub(1, #who:lower()) == who:lower() then
                target = p
                break
            end
        end
        if target and target.Name ~= OWNER_NAME then
            local ok = flingOnceWithDetect(target)
            toast("Receiver", ok and ("Flinged "..target.Name) or ("Failed "..target.Name))
        else
            toast("Receiver", "Target not found")
        end
    end
end

-- TextChatService (new) DM hookup
local function bindTCS()
    if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return end

    -- helper to attach to any whisper channel we see
    local function hook(ch : TextChannel)
        if not ch.Name:match("^RBXWhisper") then return end
        ch.MessageReceived:Connect(function(msg)
            local src = msg.TextSource
            local plr = src and Players:GetPlayerByUserId(src.UserId)
            if plr and plr.Name == OWNER_NAME then
                handleDMText(plr.Name , msg.Text)
            end
        end)
    end

    -- existing channels
    for _,ch in ipairs(TextChatService.TextChannels:GetChildren()) do
        if ch:IsA("TextChannel") then hook(ch) end
    end

    -- future channels
    TextChatService.TextChannels.ChildAdded:Connect(function(ch)
        if ch:IsA("TextChannel") then hook(ch) end
    end)

    -- be sure the DM channel exists so first whisper is possible
    task.spawn(function()
        local owner = Players:FindFirstChild(OWNER_NAME) or Players.PlayerAdded:Wait()
        pcall(function() hook(TextChatService:CreateDirectMessageChannelAsync(owner.UserId)) end)
    end)
end

-- Legacy chat whisper hookup
local function bindLegacy()
    local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    local onMsg = events and events:FindFirstChild("OnMessageDoneFiltering")
    if onMsg then
        onMsg.OnClientEvent:Connect(function(data)
            -- data.FromSpeaker, data.Message, data.OriginalChannel (often "Whisper" for DMs)
            if data and data.FromSpeaker == OWNER_NAME then
                -- Only process whispers or anything that starts with ';'
                local channel = tostring(data.OriginalChannel or data.Channel or "")
                if channel:lower():find("whisper") or (type(data.Message)=="string" and data.Message:find("^;")) then
                    handleDMText(OWNER_NAME, data.Message)
                end
            end
        end)
    end
end

-- Bind listeners
bindTCS()
bindLegacy()

toast("Receiver Ready", "Listening for DMs from "..OWNER_NAME)
