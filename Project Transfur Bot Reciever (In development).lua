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

local FlingLoopThread      = nil      -- coroutine that keeps flinging
local FlingAllMode         = false    -- true -> fling everybody (except owner)
local TargetTable          = {}       -- [UserId] = Player

local SUCCESS_VEL = 80
local SUCCESS_DIST = 25
local DETECT_WINDOW = 3.0

--------------------------------------------------------------------
-- >>> 1)  put this near the other "local ..." declarations
--------------------------------------------------------------------
local COMMAND_LIST = {
    ";cmds",
    ";fling [username]",
    ";flingall",
    ";unfling",
    ";meleekill [username] [tool name]",
    ";gunkill [tool name]",
    ";grabguns",
    ";grabmelees",
    ";grabarmor",
    ";hitboxexp",
    ";ammo",
    ";grabheals",
    ";heal",
    ";radio",
    ";follow [username]",
    ";tp [username]"
}

-- small cache so we don't create the channel every line we send
local replyDM = {channel = nil}
local function sendDMToOwner(txt : string)
    local owner = Players:FindFirstChild(OWNER_NAME)
    if not owner then return end
    if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return end

    if not replyDM.channel then
        local ok, ch = pcall(function()
            return TextChatService:CreateDirectMessageChannelAsync(owner.UserId)
        end)
        if ok and ch then
            replyDM.channel = ch
        else
            return
        end
    end
    pcall(function() replyDM.channel:SendAsync(txt) end)
end

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

------------------------------------------------------------------------
-- >>>  continuous flinging coroutine
------------------------------------------------------------------------
local function startFlingLoop()
    if FlingLoopThread then return end           -- already running
    FlingLoopThread = task.spawn(function()
        while FlingActive do
            -- build current target list each cycle --------------------
            local list = {}
            if FlingAllMode then
                for _,plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Name ~= OWNER_NAME then
                        table.insert(list,plr)
                    end
                end
            else
                for _,plr in pairs(TargetTable) do
                    if plr and plr.Parent then
                        table.insert(list,plr)
                    end
                end
            end

            -- fling everyone in that list ----------------------------
            for _,plr in ipairs(list) do
                if not FlingActive then break end
                pcall(function() SkidFling(plr) end)
                task.wait(0.05)                   -- tiny delay between targets
            end

            task.wait(0.25)                       -- wait before next cycle
        end
    end)
end

local function stopFlingLoop()
    FlingActive, FlingAllMode = false, false
    TargetTable               = {}
    FlingLoopThread           = nil
    toast("Receiver", "Stopped fling")
end

------------------------------------------------------------------------
-- >>>  completely replace the old handleDMText() with this one
------------------------------------------------------------------------
local function handleDMText(fromName : string , text : string)
    if fromName ~= OWNER_NAME          then return end
    if type(text) ~= "string"          then return end
    if text:sub(1,1) ~= ";"            then return end   -- must start with ;

    local cmd = text:sub(2):lower()                     -- trim leading ";"

    --------------------------------------------------------------------
    if cmd == "cmds" then                     --  ;cmds
        for _,line in ipairs(COMMAND_LIST) do
            sendDMToOwner(line)
            task.wait(0.05)                   -- slight spacing
        end
        return
    end

    --------------------------------------------------------------------
    if cmd == "unfling" then                        --  ;unfling
        stopFlingLoop()
        return
    end

    --------------------------------------------------------------------
    if cmd == "flingall" then                       --  ;flingall
        FlingActive   = true
        FlingAllMode  = true
        startFlingLoop()
        toast("Receiver","Now flinging everyone except "..OWNER_NAME)
        return
    end

    --------------------------------------------------------------------
    local who = cmd:match("^fling%s+(.+)$")         --  ;fling <name>
    if who and #who > 0 then
        local target = nil
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer
               and p.Name:lower():sub(1,#who) == who:lower()
               and p.Name ~= OWNER_NAME then
                target = p
                break
            end
        end
        if target then
            FlingActive            = true
            FlingAllMode           = false
            TargetTable[target.UserId] = target
            startFlingLoop()
            toast("Receiver","Flinging "..target.Name)
        else
            toast("Receiver","Target not found")
        end
        return
    end
end

------------------------------------------------------------------------
-- >>>  finally, keep the DM-hooking code but CALL the new handler
--      (replace the old bindTCS() with this compact version)
------------------------------------------------------------------------
local function bindTCS()
    if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return end

    local function hook(ch : TextChannel)
        if not ch.Name:match("^RBXWhisper") then return end
        ch.MessageReceived:Connect(function(msg)
            local src = msg.TextSource
            local plr = src and Players:GetPlayerByUserId(src.UserId)
            if plr then handleDMText(plr.Name , msg.Text) end
        end)
    end

    -- existing & future whisper channels
    for _,c in ipairs(TextChatService.TextChannels:GetChildren()) do
        if c:IsA("TextChannel") then hook(c) end
    end
    TextChatService.TextChannels.ChildAdded:Connect(function(c)
        if c:IsA("TextChannel") then hook(c) end
    end)

    -- be sure a DM channel with the owner exists so the first whisper arrives
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
