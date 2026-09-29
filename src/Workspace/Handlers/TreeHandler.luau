-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules");
local Configs = Modules:WaitForChild("Configs");
local Handlers = Modules:WaitForChild("Handlers");
local TreeConfig = require(Configs:WaitForChild("TreeConfig"));
local DataHandler = require(Handlers:WaitForChild("DataHandler"));
local ZoneHandler = require(Handlers:WaitForChild("ZoneHandler"));
local Packets = require(Modules:WaitForChild("Network"):WaitForChild("Packets"));
local Requests = require(Modules:WaitForChild("Network"):WaitForChild("Requests"));
local u1 = {};
local u2 = {};

local function dprint(...) -- Line: 53
    print("[Tree/server]", ...);
end;

for i, v in pairs(TreeConfig) do
    if type(v) == "table" and v.Cost ~= nil then
        u1[i] = v;
    end;
end;

u2.Nodes = u1;

function u2.GetNodeZone(p3) -- Line: 73
    -- upvalues: u1 (copy), TreeConfig (copy)
    local v4 = u1[p3];

    return v4 and v4.ZoneName or TreeConfig.ZoneName;
end;

local v5 = {};
local u6 = {};

for i in pairs(u1) do
    local v7 = u1[i];
    local v8 = v7 and v7.ZoneName or TreeConfig.ZoneName;

    if v8 and not v5[v8] then
        v5[v8] = true;
        table.insert(u6, v8);
    end;
end;

table.sort(u6);

local function ownedTable(p9) -- Line: 93
    -- upvalues: DataHandler (copy)
    local Profile = DataHandler.GetProfile(p9);

    if not (Profile and Profile.Data) then
        return nil;
    end;

    if type(Profile.Data.TreeUpgrades) ~= "table" then
        Profile.Data.TreeUpgrades = {};
    end;

    return Profile.Data.TreeUpgrades;
end;

function u2.IsOwned(p10, p11) -- Line: 104
    -- upvalues: ownedTable (copy)
    local v12 = ownedTable(p10);
    local v13;

    if v12 == nil then
        v13 = false;
    else
        v13 = v12[p11] == true;
    end;

    return v13;
end;

function u2.PrereqsMet(p14, p15) -- Line: 109
    -- upvalues: u1 (copy), u2 (copy)
    local v16 = u1[p15];

    if not v16 then
        return false;
    end;

    for _, v in ipairs(v16.Requires or {}) do
        if not u2.IsOwned(p14, v) then
            return false;
        end;
    end;

    return true;
end;

function u2.IsZoneUnlocked(p17, p18) -- Line: 122
    -- upvalues: ZoneHandler (copy), TreeConfig (copy)
    return ZoneHandler.HasZoneUnlocked(p17, p18 or TreeConfig.ZoneName);
end;

local function unlockedZoneList(p19) -- Line: 126
    -- upvalues: u6 (copy), u2 (copy)
    local v20 = {};

    for _, v in ipairs(u6) do
        if u2.IsZoneUnlocked(p19, v) then
            table.insert(v20, v);
        end;
    end;

    return v20;
end;

function u2.CanBuy(p21, p22) -- Line: 136
    -- upvalues: u1 (copy), dprint (copy), u2 (copy), TreeConfig (copy)
    local v23 = u1[p22];

    if not v23 then
        dprint(p21.Name, tostring(p22), "reject: no config for this node id");

        return false;
    end;

    if u2.IsOwned(p21, p22) then
        dprint(p21.Name, p22, "reject: already owned");

        return false;
    end;

    local v24 = u1[p22];

    if not u2.IsZoneUnlocked(p21, v24 and v24.ZoneName or TreeConfig.ZoneName) then
        local v25 = u1[p22];
        dprint(p21.Name, p22, "reject: gate zone \'" .. tostring(v25 and v25.ZoneName or TreeConfig.ZoneName) .. "\' not unlocked");

        return false;
    end;

    if not u2.PrereqsMet(p21, p22) then
        dprint(p21.Name, p22, "reject: prerequisites not owned (" .. table.concat(v23.Requires or {}, ", ") .. ")");

        return false;
    end;

    local Currencies = p21:FindFirstChild("Currencies");

    if Currencies then
        Currencies = Currencies:FindFirstChild(v23.Currency);
    end;

    if not Currencies then
        dprint(p21.Name, p22, "reject: no \'" .. tostring(v23.Currency) .. "\' currency stat");

        return false;
    end;

    if Currencies.Value >= v23.Cost then
        return true;
    end;

    dprint(p21.Name, p22, ("reject: cost - have %s %s, need %s"):format(tostring(Currencies.Value), tostring(v23.Currency), (tostring(v23.Cost))));

    return false;
end;

function u2.ProcessBuy(p26, p27) -- Line: 170
    -- upvalues: u2 (copy), ownedTable (copy), u1 (copy)
    if not u2.CanBuy(p26, p27) then
        return false;
    end;

    local v28 = ownedTable(p26);

    if not v28 then
        return false;
    end;

    local v29 = u1[p27];
    local Currencies = p26:FindFirstChild("Currencies");

    if Currencies then
        Currencies = Currencies:FindFirstChild(v29.Currency);
    end;

    if not Currencies then
        return false;
    end;

    Currencies.Value = Currencies.Value - v29.Cost;
    v28[p27] = true;

    return true;
end;

function u2.GetCurrencyMultiplier(p30, p31) -- Line: 193
    -- upvalues: ownedTable (copy), u1 (copy)
    local v32 = ownedTable(p30);

    if not v32 then
        return 1;
    end;

    local v33 = 1;

    for i, v in pairs(v32) do
        if v then
            local v34 = u1[i];
            local v35 = v34 and v34.Multipliers and v34.Multipliers[p31];

            if v35 then
                v33 = v33 * v35;
            end;
        end;
    end;

    return v33;
end;

local function ownedList(p36) -- Line: 212
    -- upvalues: ownedTable (copy), u1 (copy)
    local v37 = ownedTable(p36);
    local v38 = {};

    if v37 then
        for i, v in pairs(v37) do
            if v and u1[i] then
                table.insert(v38, i);
            end;
        end;
    end;

    return v38;
end;

function u2.PushState(p39) -- Line: 225
    -- upvalues: Packets (copy), u2 (copy), ownedList (copy), unlockedZoneList (copy)
    Packets.TreeStateChanged.sendTo({
        ZoneUnlocked = u2.IsZoneUnlocked(p39),
        Owned = ownedList(p39),
        UnlockedZones = unlockedZoneList(p39)
    }, p39);
end;

Requests.GetTreeState:OnInvoke(function(p40) -- Line: 233
    -- upvalues: DataHandler (copy), u2 (copy), ownedList (copy), unlockedZoneList (copy), dprint (copy)
    local v41 = os.clock() + 60;

    while not DataHandler.GetProfile(p40) and os.clock() < v41 do
        task.wait(0.1);
    end;

    local v42 = DataHandler.GetProfile(p40) ~= nil;
    local v43 = u2.IsZoneUnlocked(p40);
    local v44 = ownedList(p40);
    local v45 = unlockedZoneList(p40);
    dprint(("GetTreeState %s | ready=%s zoneUnlocked=%s zones=[%s] owned=[%s]"):format(p40.Name, tostring(v42), tostring(v43), table.concat(v45, ", "), table.concat(v44, ", ")));

    return {
        Ready = v42,
        ZoneUnlocked = v43,
        Owned = v44,
        UnlockedZones = v45
    };
end);

local function pushZoneUnlockDelta(p46) -- Line: 252
    -- upvalues: DataHandler (copy), ZoneHandler (copy), Packets (copy)
    local Profile = DataHandler.GetProfile(p46);

    if not (Profile and Profile.Data) then
        return;
    end;

    local v47 = {};

    for i, v in pairs(Profile.Data.UnlockedZones or {}) do
        if v then
            v47[i] = true;
        end;
    end;

    ZoneHandler.EvaluateUnlocks(p46);
    local v48 = {};
    local v49 = false;

    for i, v in pairs(Profile.Data.UnlockedZones or {}) do
        if v and not v47[i] then
            v48[i] = true;
            v49 = true;
        end;
    end;

    if v49 then
        Packets.UpdateUnlockedZones.sendTo({
            Zones = v48
        }, p46);
    end;
end;

Requests.BuyTreeUpgrade:OnInvoke(function(p50, p51) -- Line: 277
    -- upvalues: u2 (copy), pushZoneUnlockDelta (copy), dprint (copy), ownedList (copy)
    local success, result = pcall(u2.ProcessBuy, p50, p51.Node);

    if not success then
        warn("[Tree/server] ProcessBuy errored for \'" .. tostring(p51.Node) .. "\': " .. tostring(result));
        result = false;
    end;

    if result then
        pushZoneUnlockDelta(p50);
    end;

    dprint(("BuyTreeUpgrade %s | node=%s -> success=%s"):format(p50.Name, tostring(p51.Node), (tostring(result))));

    return {
        Success = result == true,
        Owned = ownedList(p50)
    };
end);

return u2;