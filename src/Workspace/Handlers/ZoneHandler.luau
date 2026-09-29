-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Configs = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Configs");
local Handlers = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Handlers");
local ZoneConfig = require(Configs:WaitForChild("ZoneConfig"));
local ZoneOrderConfig = require(Configs:WaitForChild("ZoneOrderConfig"));
local DataHandler = require(Handlers:WaitForChild("DataHandler"));
local u1 = {};
local u2 = {};
local u3 = {};

for _, v in pairs(ZoneConfig) do
    for i, v2 in pairs(v) do
        u1[i] = v2;
    end;
end;

local u4 = {};

for i, v in pairs(ZoneOrderConfig) do
    local v5 = i;

    for _, v2 in ipairs(v) do
        table.insert(u2, v2);
        u3[v2] = #u2;
        u4[v2] = v5;
    end;
end;

local u6 = {};
local u7 = {};

function u6.SetEvaluateSuspended(p8, p9) -- Line: 67
    -- upvalues: u7 (copy)
    u7[p8] = p9 or nil;
end;

local function isCascadeSource(p10) -- Line: 75
    -- upvalues: u1 (copy)
    local v11 = u1[p10];
    local v12;

    if v11 == nil then
        v12 = false;
    else
        v12 = v11.Currency ~= "Prestiges";
    end;

    return v12;
end;

local function markUnlocked(p13, p14) -- Line: 80
    if p13 and p13.Data then
        if type(p13.Data.UnlockedZones) ~= "table" then
            p13.Data.UnlockedZones = {};
        end;

        p13.Data.UnlockedZones[p14] = true;
    end;
end;

local function meetsThreshold(p15, p16, p17) -- Line: 91
    if (p17 or 0) <= 0 then
        return true;
    end;

    local v18 = p15:FindFirstChild(p16 or "Money");
    local v19;

    if v18 == nil then
        v19 = false;
    else
        v19 = p17 <= v18.Value;
    end;

    return v19;
end;

local function isDirectlyUnlocked(p20, p21, p22) -- Line: 97
    -- upvalues: u1 (copy), u6 (copy)
    if p21 and (p21.Data and (p21.Data.UnlockedZones and p21.Data.UnlockedZones[p22])) then
        return true;
    end;

    local v23 = u1[p22];

    if not v23 then
        return false;
    end;

    if v23.UnlockUpgrade then
        local v24 = p21 and p21.Data and p21.Data[v23.UnlockUpgrade.Field];

        if type(v24) == "table" and v24[v23.UnlockUpgrade.Node] then
            return true;
        end;
    end;

    if v23.Cost <= 0 then
        return true;
    end;

    if v23.RequiresZone and (v23.RequiresZone ~= p22 and not u6.HasZoneUnlocked(p20, v23.RequiresZone)) then
        return false;
    end;

    if v23.Currency == "Prestiges" then
        return (p21 and (p21.Data and tonumber(p21.Data.Prestiges)) or 0) >= v23.Cost;
    end;

    local Currencies = p20:FindFirstChild("Currencies");

    if not Currencies then
        return false;
    end;

    local Currency = v23.Currency;
    local Cost = v23.Cost;
    local v25;

    if (Cost or 0) <= 0 then
        v25 = true;
    else
        local v26 = Currencies:FindFirstChild(Currency or "Money");

        if v26 == nil then
            v25 = false;
        else
            v25 = Cost <= v26.Value;
        end;
    end;

    if not v25 then
        return false;
    end;

    if v23.Conditions then
        for _, v in ipairs(v23.Conditions) do
            local Currency2 = v.Currency;
            local Cost2 = v.Cost;
            local v27;

            if (Cost2 or 0) <= 0 then
                v27 = true;
            else
                local v28 = Currencies:FindFirstChild(Currency2 or "Money");

                if v28 == nil then
                    v27 = false;
                else
                    v27 = Cost2 <= v28.Value;
                end;
            end;

            if not v27 then
                return false;
            end;
        end;
    end;

    return true;
end;

function u6.HasZoneUnlocked(p29, p30) -- Line: 150
    -- upvalues: DataHandler (copy), isDirectlyUnlocked (copy), u3 (copy), u2 (copy), u4 (copy), u1 (copy)
    local Profile = DataHandler.GetProfile(p29);

    if isDirectlyUnlocked(p29, Profile, p30) then
        if Profile and Profile.Data then
            if type(Profile.Data.UnlockedZones) ~= "table" then
                Profile.Data.UnlockedZones = {};
            end;

            Profile.Data.UnlockedZones[p30] = true;
        end;

        return true;
    end;

    local v31 = u3[p30];

    if v31 then
        for i = v31 + 1, #u2 do
            local v32;

            if u4[u2[i]] == u4[p30] then
                local v33 = u1[u2[i]];
                local v34;

                if v33 == nil then
                    v34 = false;
                else
                    v34 = v33.Currency ~= "Prestiges";
                end;

                if v34 and isDirectlyUnlocked(p29, Profile, u2[i]) then
                    if Profile and Profile.Data then
                        if type(Profile.Data.UnlockedZones) ~= "table" then
                            Profile.Data.UnlockedZones = {};
                        end;

                        Profile.Data.UnlockedZones[p30] = true;
                    end;

                    return true;
                end;

                v32 = i;
            else
                v32 = i;
            end;
        end;
    end;

    return false;
end;

function u6.EvaluateUnlocks(p35) -- Line: 172
    -- upvalues: u7 (copy), DataHandler (copy), u1 (copy), u6 (copy)
    if u7[p35] then
        return;
    end;

    local Profile = DataHandler.GetProfile(p35);

    if not Profile then
        return;
    end;

    if type(Profile.Data.UnlockedZones) ~= "table" then
        Profile.Data.UnlockedZones = {};
    end;

    for i in pairs(u1) do
        if not Profile.Data.UnlockedZones[i] then
            u6.HasZoneUnlocked(p35, i);
        end;
    end;
end;

function u6.GetAllZoneNames() -- Line: 193
    -- upvalues: u1 (copy)
    local v36 = {};

    for i in pairs(u1) do
        table.insert(v36, i);
    end;

    return v36;
end;

return u6;