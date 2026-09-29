-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local Players = game:GetService("Players");
local RunService = game:GetService("RunService");
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules");
local Configs = Modules:WaitForChild("Configs");
local Handlers = Modules:WaitForChild("Handlers");
local PrestigeAutomationConfig = require(Configs:WaitForChild("PrestigeAutomationConfig"));
local DataHandler = require(Handlers:WaitForChild("DataHandler"));
local PrestigeHandler = require(Handlers:WaitForChild("PrestigeHandler"));
local RebirthHandler = require(Handlers:WaitForChild("RebirthHandler"));
local Packets = require(Modules:WaitForChild("Network"):WaitForChild("Packets"));
local Requests = require(Modules:WaitForChild("Network"):WaitForChild("Requests"));
local u1 = {};
local u2 = {};

for _, v in pairs(PrestigeAutomationConfig.UnlocksByPrestige) do
    for _, v2 in ipairs(v) do
        u1[v2.Id] = v2;
    end;
end;

local function unlockedActionsForCount(p3) -- Line: 69
    -- upvalues: PrestigeAutomationConfig (copy)
    local v4 = {};

    for i, v in pairs(PrestigeAutomationConfig.UnlocksByPrestige) do
        if i <= p3 then
            for _, v2 in ipairs(v) do
                v4[v2.Id] = true;
            end;
        end;
    end;

    return v4;
end;

function u2.GetUnlockedActions(p5) -- Line: 81
    -- upvalues: unlockedActionsForCount (copy), PrestigeHandler (copy)
    return unlockedActionsForCount(PrestigeHandler.GetCount(p5));
end;

function u2.IsActionEnabled(p6, p7) -- Line: 85
    -- upvalues: DataHandler (copy), PrestigeAutomationConfig (copy)
    local Profile = DataHandler.GetProfile(p6);

    if not (Profile and Profile.Data) then
        return false;
    end;

    if type(Profile.Data.PrestigeAutomation) ~= "table" then
        Profile.Data.PrestigeAutomation = {};
    end;

    local v8 = Profile.Data.PrestigeAutomation[p7];

    if v8 == nil then
        return PrestigeAutomationConfig.DefaultEnabled;
    end;

    return v8;
end;

function u2.SetActionEnabled(p9, p10, p11) -- Line: 104
    -- upvalues: u1 (copy), unlockedActionsForCount (copy), PrestigeHandler (copy), DataHandler (copy)
    if not u1[p10] then
        return nil;
    end;

    if not unlockedActionsForCount(PrestigeHandler.GetCount(p9))[p10] then
        return nil;
    end;

    local Profile = DataHandler.GetProfile(p9);

    if not (Profile and Profile.Data) then
        return nil;
    end;

    if type(Profile.Data.PrestigeAutomation) ~= "table" then
        Profile.Data.PrestigeAutomation = {};
    end;

    Profile.Data.PrestigeAutomation[p10] = p11 and true or false;

    return Profile.Data.PrestigeAutomation[p10];
end;

function u2.IsActionActive(p12, p13) -- Line: 129
    -- upvalues: unlockedActionsForCount (copy), PrestigeHandler (copy), u2 (copy)
    if unlockedActionsForCount(PrestigeHandler.GetCount(p12))[p13] then
        return u2.IsActionEnabled(p12, p13);
    end;

    return false;
end;

local function buildState(p14) -- Line: 138
    -- upvalues: unlockedActionsForCount (copy), PrestigeHandler (copy), u2 (copy)
    local v15 = unlockedActionsForCount(PrestigeHandler.GetCount(p14));
    local v16 = {};
    local v17 = {};

    for i in pairs(v15) do
        table.insert(v16, i);
        v17[i] = u2.IsActionEnabled(p14, i);
    end;

    return v16, v17;
end;

function u2.PushState(p18) -- Line: 153
    -- upvalues: buildState (copy), PrestigeHandler (copy), Packets (copy)
    local v19, v20 = buildState(p18);
    print(("[PrestigeAutomation] PushState %s | prestiges=%d | unlocked=[%s]"):format(p18.Name, PrestigeHandler.GetCount(p18), table.concat(v19, ", ")));
    Packets.AutoActionStateChanged.sendTo({
        Unlocked = v19,
        Enabled = v20
    }, p18);
end;

function u2.Init() -- Line: 160
    -- upvalues: RunService (copy), PrestigeAutomationConfig (copy), Players (copy), u2 (copy), RebirthHandler (copy)
    local u21 = 0;
    RunService.Heartbeat:Connect(function(p22) -- Line: 163
        -- upvalues: u21 (ref), PrestigeAutomationConfig (ref), Players (ref), u2 (ref), RebirthHandler (ref)
        u21 = u21 + p22;

        if u21 < PrestigeAutomationConfig.TickInterval then
            return;
        end;

        u21 = 0;

        for _, v in ipairs(Players:GetPlayers()) do
            if u2.IsActionActive(v, "Rebirth") and RebirthHandler.CalculateGain(v) > 0 then
                RebirthHandler.ProcessRebirth(v);
            end;
        end;
    end);
end;

Requests.GetAutoActionState:OnInvoke(function(p23) -- Line: 186
    -- upvalues: DataHandler (copy), buildState (copy), PrestigeHandler (copy)
    local v24 = os.clock() + 60;

    while not DataHandler.GetProfile(p23) and os.clock() < v24 do
        task.wait(0.1);
    end;

    local v25 = DataHandler.GetProfile(p23) ~= nil;
    local v26, v27 = buildState(p23);
    print(("[PrestigeAutomation] GetAutoActionState %s | ready=%s | prestiges=%d | unlocked=[%s]"):format(p23.Name, tostring(v25), PrestigeHandler.GetCount(p23), table.concat(v26, ", ")));

    return {
        Ready = v25,
        Unlocked = v26,
        Enabled = v27
    };
end);
Requests.SetAutoActionEnabled:OnInvoke(function(p28, p29) -- Line: 202
    -- upvalues: u2 (copy)
    local v30 = u2.SetActionEnabled(p28, p29.Action, p29.Enabled);

    return v30 == nil and {
        Enabled = false,
        Action = p29.Action
    } or {
        Action = p29.Action,
        Enabled = v30
    };
end);

return u2;