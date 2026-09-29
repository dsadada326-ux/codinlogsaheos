-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Configs = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Configs");
local Handlers = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Handlers");
local RebirthConfig = require(Configs:WaitForChild("RebirthConfig"));
local UpgradeHandler = require(Handlers:WaitForChild("UpgradeHandler"));
local GamepassHandler = require(Handlers:WaitForChild("GamepassHandler"));
local RuneHandler = require(Handlers:WaitForChild("RuneHandler"));
local PrestigeHandler = require(Handlers:WaitForChild("PrestigeHandler"));
local TreeHandler = require(Handlers:WaitForChild("TreeHandler"));
local EquipmentHandler = require(Handlers:WaitForChild("EquipmentHandler"));
local Packets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Packets"));
local Requests = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Requests"));
local u4 = {
    GetGainMultiplier = function(p1) -- Line: 41, Name: GetGainMultiplier
        -- upvalues: UpgradeHandler (copy), GamepassHandler (copy), RuneHandler (copy), PrestigeHandler (copy), TreeHandler (copy), EquipmentHandler (copy)
        local PlayerLevel = UpgradeHandler.GetPlayerLevel(p1, "Gems", "RebirthsMultiplier");
        local UpgradeData = UpgradeHandler.GetUpgradeData("Gems", "RebirthsMultiplier");
        local v2 = UpgradeData and UpgradeHandler.CalculateValue(UpgradeData.BaseValue, UpgradeData.ValueScaling, PlayerLevel) or 1;
        local PlayerLevel2 = UpgradeHandler.GetPlayerLevel(p1, "TimeBoosts", "RebirthMultiplier");
        local UpgradeData2 = UpgradeHandler.GetUpgradeData("TimeBoosts", "RebirthMultiplier");
        local v3 = UpgradeData2 and UpgradeHandler.CalculateValue(UpgradeData2.BaseValue, UpgradeData2.ValueScaling, PlayerLevel2) or 1;
        local Multiplier = GamepassHandler.GetMultiplier(p1, "Rebirths");
        local CurrencyMultiplier = RuneHandler.GetCurrencyMultiplier(p1, "Rebirths");
        local CurrencyMultiplier2 = PrestigeHandler.GetCurrencyMultiplier(p1, "Rebirths");
        local CurrencyMultiplier3 = TreeHandler.GetCurrencyMultiplier(p1, "Rebirths");
        local Multiplier2 = EquipmentHandler.GetMultiplier(p1, "Rebirths");

        return v2 * v3 * Multiplier * CurrencyMultiplier * CurrencyMultiplier2 * CurrencyMultiplier3 * Multiplier2;
    end
};

function u4.CalculateGain(p5) -- Line: 59
    -- upvalues: RebirthConfig (copy), u4 (copy)
    local Currencies = p5:FindFirstChild("Currencies");

    if not Currencies then
        return 0;
    end;

    local v6 = Currencies:FindFirstChild(RebirthConfig.SourceCurrency);

    return not v6 and 0 or math.floor(v6.Value / RebirthConfig.CostPerRebirth) * u4.GetGainMultiplier(p5);
end;

function u4.ProcessRebirth(p7) -- Line: 71
    -- upvalues: u4 (copy), RebirthConfig (copy), UpgradeHandler (copy), Packets (copy)
    local v8 = u4.CalculateGain(p7);

    if v8 <= 0 then
        return false;
    end;

    local Currencies = p7:FindFirstChild("Currencies");

    if not Currencies then
        return false;
    end;

    local v9 = Currencies:FindFirstChild(RebirthConfig.RewardCurrency);

    if not v9 then
        return false;
    end;

    v9.Value = v9.Value + v8;

    for _, v in ipairs(RebirthConfig.ResetCurrencies) do
        local v10 = Currencies:FindFirstChild(v);

        if v10 then
            v10.Value = 0;
        end;
    end;

    for _, v in ipairs(RebirthConfig.ResetBoards) do
        UpgradeHandler.ResetBoard(p7, v);
    end;

    Packets.UpgradeBoardsReset.sendTo({
        Boards = RebirthConfig.ResetBoards
    }, p7);

    return true;
end;

Requests.GetRebirthGainMultiplier:OnInvoke(function(p11) -- Line: 99
    -- upvalues: u4 (copy)
    return {
        Multiplier = u4.GetGainMultiplier(p11)
    };
end);
Requests.ProcessRebirth:OnInvoke(function(p12) -- Line: 103
    -- upvalues: u4 (copy)
    return {
        Success = u4.ProcessRebirth(p12)
    };
end);

return u4;