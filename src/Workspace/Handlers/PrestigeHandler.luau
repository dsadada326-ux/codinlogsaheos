-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules");
local Configs = Modules:WaitForChild("Configs");
local Handlers = Modules:WaitForChild("Handlers");
local PrestigeConfig = require(Configs:WaitForChild("PrestigeConfig"));
local ZoneConfig = require(Configs:WaitForChild("ZoneConfig"));
local ZoneOrderConfig = require(Configs:WaitForChild("ZoneOrderConfig"));
local DataHandler = require(Handlers:WaitForChild("DataHandler"));
local UpgradeHandler = require(Handlers:WaitForChild("UpgradeHandler"));
local ZoneHandler = require(Handlers:WaitForChild("ZoneHandler"));
local Packets = require(Modules:WaitForChild("Network"):WaitForChild("Packets"));
local Requests = require(Modules:WaitForChild("Network"):WaitForChild("Requests"));
local u2 = {
    GetCount = function(p1) -- Line: 53, Name: GetCount
        -- upvalues: DataHandler (copy)
        local Profile = DataHandler.GetProfile(p1);

        return Profile and (Profile.Data and tonumber(Profile.Data.Prestiges)) or 0;
    end
};

function u2.GetCurrencyMultiplier(p3, p4) -- Line: 61
    -- upvalues: u2 (copy), PrestigeConfig (copy)
    local v5 = 1;

    for i = 1, u2.GetCount(p3) do
        local v6 = PrestigeConfig.Tiers[i];
        local v7 = v6 and v6.Multipliers and v6.Multipliers[p4];
        local v8;

        if v7 then
            v5 = v5 * v7;
            v8 = i;
        else
            v8 = i;
        end;
    end;

    return v5;
end;

function u2.GetNextTier(p9) -- Line: 78
    -- upvalues: PrestigeConfig (copy), u2 (copy)
    return PrestigeConfig.Tiers[u2.GetCount(p9) + 1];
end;

function u2.GetResetZones() -- Line: 88
    -- upvalues: ZoneOrderConfig (copy), PrestigeConfig (copy), ZoneConfig (copy)
    local v10 = 0;
    local v11 = {};

    for _, v in pairs(ZoneOrderConfig) do
        for _, v2 in ipairs(v) do
            v10 = v10 + 1;
            v11[v2] = v10;
        end;
    end;

    local v12 = v11[PrestigeConfig.ResetZonesThrough];
    local v13 = {};

    for _, v in pairs(ZoneConfig) do
        for i, v2 in pairs(v) do
            if v2.Currency ~= "Prestiges" then
                local v14 = v11[i];

                if not (v12 and (v14 and v14 > v12)) then
                    table.insert(v13, i);
                end;
            end;
        end;
    end;

    return v13;
end;

function u2.CanPrestige(p15) -- Line: 117
    -- upvalues: u2 (copy), ZoneHandler (copy), PrestigeConfig (copy)
    local NextTier = u2.GetNextTier(p15);

    if not NextTier then
        return false;
    end;

    if not ZoneHandler.HasZoneUnlocked(p15, PrestigeConfig.ZoneName) then
        return false;
    end;

    local Currencies = p15:FindFirstChild("Currencies");

    if Currencies then
        Currencies = Currencies:FindFirstChild(NextTier.Currency);
    end;

    local v16;

    if Currencies == nil then
        v16 = false;
    else
        v16 = Currencies.Value >= NextTier.Cost;
    end;

    return v16;
end;

function u2.SyncLeaderstat(p17) -- Line: 138
    -- upvalues: u2 (copy)
    local leaderstats = p17:FindFirstChild("leaderstats");

    if leaderstats then
        leaderstats = leaderstats:FindFirstChild("Prestiges");
    end;

    if leaderstats then
        leaderstats.Value = u2.GetCount(p17);
    end;
end;

function u2.ProcessPrestige(p18) -- Line: 146
    -- upvalues: u2 (copy), DataHandler (copy), ZoneHandler (copy), PrestigeConfig (copy), UpgradeHandler (copy), Packets (copy)
    if not u2.CanPrestige(p18) then
        return false;
    end;

    local Profile = DataHandler.GetProfile(p18);

    if not Profile then
        return false;
    end;

    local Currencies = p18:FindFirstChild("Currencies");

    if not Currencies then
        return false;
    end;

    local NextTier = u2.GetNextTier(p18);
    local ResetZones = u2.GetResetZones();
    ZoneHandler.SetEvaluateSuspended(p18, true);

    if type(Profile.Data.UnlockedZones) ~= "table" then
        Profile.Data.UnlockedZones = {};
    end;

    for _, v in ipairs(ResetZones) do
        Profile.Data.UnlockedZones[v] = nil;
    end;

    for _, v in ipairs(PrestigeConfig.ResetCurrencies) do
        local v19 = Currencies:FindFirstChild(v);

        if v19 then
            v19.Value = 0;
        end;

        if Profile.Data.Currencies then
            Profile.Data.Currencies[v] = 0;
        end;
    end;

    for _, v in ipairs(PrestigeConfig.ResetBoards) do
        UpgradeHandler.ResetBoard(p18, v);
    end;

    Profile.Data.Prestiges = u2.GetCount(p18) + 1;
    u2.SyncLeaderstat(p18);

    for _, v in ipairs(NextTier.Unlocks or {}) do
        Profile.Data.UnlockedZones[v] = true;
    end;

    ZoneHandler.SetEvaluateSuspended(p18, false);
    ZoneHandler.EvaluateUnlocks(p18);
    Packets.UpgradeBoardsReset.sendTo({
        Boards = PrestigeConfig.ResetBoards
    }, p18);
    Packets.PrestigeApplied.sendTo({
        Count = Profile.Data.Prestiges,
        Boards = PrestigeConfig.ResetBoards,
        ResetZones = ResetZones
    }, p18);

    return true;
end;

Requests.GetPrestigeCount:OnInvoke(function(p20) -- Line: 219
    -- upvalues: u2 (copy)
    return {
        Count = u2.GetCount(p20)
    };
end);
Requests.ProcessPrestige:OnInvoke(function(p21) -- Line: 223
    -- upvalues: u2 (copy)
    return {
        Success = u2.ProcessPrestige(p21)
    };
end);

return u2;