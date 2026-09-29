-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local Players = game:GetService("Players");
local RunService = game:GetService("RunService");
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules");
local Configs = Modules:WaitForChild("Configs");
local Handlers = Modules:WaitForChild("Handlers");
local Upgrades = Configs:WaitForChild("Upgrades");
local AutoUpgradeConfig = require(Configs:WaitForChild("AutoUpgradeConfig"));
local DataHandler = require(Handlers:WaitForChild("DataHandler"));
local UpgradeHandler = require(Handlers:WaitForChild("UpgradeHandler"));
local PrestigeHandler = require(Handlers:WaitForChild("PrestigeHandler"));
local Packets = require(Modules:WaitForChild("Network"):WaitForChild("Packets"));
local Requests = require(Modules:WaitForChild("Network"):WaitForChild("Requests"));
local u1 = {};

local function unlockedBoardsForCount(p2) -- Line: 49
    -- upvalues: AutoUpgradeConfig (copy)
    local v3 = {};

    for i, v in pairs(AutoUpgradeConfig.UnlocksByPrestige) do
        if i <= p2 then
            for _, v2 in ipairs(v) do
                v3[v2] = true;
            end;
        end;
    end;

    return v3;
end;

function u1.GetUnlockedBoards(p4) -- Line: 61
    -- upvalues: unlockedBoardsForCount (copy), PrestigeHandler (copy)
    return unlockedBoardsForCount(PrestigeHandler.GetCount(p4));
end;

function u1.IsBoardEnabled(p5, p6) -- Line: 65
    -- upvalues: DataHandler (copy), AutoUpgradeConfig (copy)
    local Profile = DataHandler.GetProfile(p5);

    if not (Profile and Profile.Data) then
        return false;
    end;

    if type(Profile.Data.AutoUpgrade) ~= "table" then
        Profile.Data.AutoUpgrade = {};
    end;

    local v7 = Profile.Data.AutoUpgrade[p6];

    if v7 == nil then
        return AutoUpgradeConfig.DefaultEnabled;
    end;

    return v7;
end;

function u1.SetBoardEnabled(p8, p9, p10) -- Line: 84
    -- upvalues: unlockedBoardsForCount (copy), PrestigeHandler (copy), DataHandler (copy)
    if not unlockedBoardsForCount(PrestigeHandler.GetCount(p8))[p9] then
        return nil;
    end;

    local Profile = DataHandler.GetProfile(p8);

    if not (Profile and Profile.Data) then
        return nil;
    end;

    if type(Profile.Data.AutoUpgrade) ~= "table" then
        Profile.Data.AutoUpgrade = {};
    end;

    Profile.Data.AutoUpgrade[p9] = p10 and true or false;

    return Profile.Data.AutoUpgrade[p9];
end;

function u1.RunTick(p11) -- Line: 105
    -- upvalues: unlockedBoardsForCount (copy), PrestigeHandler (copy), u1 (copy), Upgrades (copy), UpgradeHandler (copy), Packets (copy)
    local v12 = unlockedBoardsForCount(PrestigeHandler.GetCount(p11));

    for i in pairs(v12) do
        if u1.IsBoardEnabled(p11, i) then
            local v13 = Upgrades:FindFirstChild(i .. "UpgradeConfig");

            if v13 then
                local v14 = require(v13);
                local v15 = i;

                for i2, v in pairs(v14) do
                    if type(v) == "table" then
                        local v16, v17 = UpgradeHandler.ProcessPurchase(p11, v15, i2);

                        if v16 then
                            Packets.UpgradePurchased.sendTo({
                                Auto = true,
                                Board = v15,
                                UpgradeId = i2,
                                NewLevel = v17
                            }, p11);
                        end;
                    end;
                end;
            end;
        end;
    end;
end;

local function buildState(p18) -- Line: 132
    -- upvalues: unlockedBoardsForCount (copy), PrestigeHandler (copy), u1 (copy)
    local v19 = unlockedBoardsForCount(PrestigeHandler.GetCount(p18));
    local v20 = {};
    local v21 = {};

    for i in pairs(v19) do
        table.insert(v20, i);
        v21[i] = u1.IsBoardEnabled(p18, i);
    end;

    return v20, v21;
end;

function u1.PushState(p22) -- Line: 147
    -- upvalues: buildState (copy), PrestigeHandler (copy), Packets (copy)
    local v23, v24 = buildState(p22);
    print(("[AutoUpgrade] PushState %s | prestiges=%d | unlocked=[%s]"):format(p22.Name, PrestigeHandler.GetCount(p22), table.concat(v23, ", ")));
    Packets.AutoUpgradeStateChanged.sendTo({
        Unlocked = v23,
        Enabled = v24
    }, p22);
end;

function u1.Init() -- Line: 154
    -- upvalues: RunService (copy), AutoUpgradeConfig (copy), Players (copy), u1 (copy)
    local u25 = 0;
    RunService.Heartbeat:Connect(function(p26) -- Line: 157
        -- upvalues: u25 (ref), AutoUpgradeConfig (ref), Players (ref), u1 (ref)
        u25 = u25 + p26;

        if u25 < AutoUpgradeConfig.TickInterval then
            return;
        end;

        u25 = 0;

        for _, v in ipairs(Players:GetPlayers()) do
            u1.RunTick(v);
        end;
    end);
end;

Requests.GetAutoUpgradeState:OnInvoke(function(p27) -- Line: 170
    -- upvalues: DataHandler (copy), buildState (copy), PrestigeHandler (copy)
    local v28 = os.clock() + 60;

    while not DataHandler.GetProfile(p27) and os.clock() < v28 do
        task.wait(0.1);
    end;

    local v29 = DataHandler.GetProfile(p27) ~= nil;
    local v30, v31 = buildState(p27);
    print(("[AutoUpgrade] GetAutoUpgradeState %s | ready=%s | prestiges=%d | unlocked=[%s]"):format(p27.Name, tostring(v29), PrestigeHandler.GetCount(p27), table.concat(v30, ", ")));

    return {
        Ready = v29,
        Unlocked = v30,
        Enabled = v31
    };
end);
Requests.SetAutoUpgradeEnabled:OnInvoke(function(p32, p33) -- Line: 188
    -- upvalues: u1 (copy)
    local v34 = u1.SetBoardEnabled(p32, p33.Board, p33.Enabled);

    return v34 == nil and {
        Enabled = false,
        Board = p33.Board
    } or {
        Board = p33.Board,
        Enabled = v34
    };
end);

return u1;