-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Handlers = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Handlers");
local UpgradeHandler = require(Handlers:WaitForChild("UpgradeHandler"));
local GamepassHandler = require(Handlers:WaitForChild("GamepassHandler"));
local SettingsHandler = require(Handlers:WaitForChild("SettingsHandler"));
local RuneHandler = require(Handlers:WaitForChild("RuneHandler"));
local PrestigeHandler = require(Handlers:WaitForChild("PrestigeHandler"));
local TreeHandler = require(Handlers:WaitForChild("TreeHandler"));
local EquipmentHandler = require(Handlers:WaitForChild("EquipmentHandler"));
local Packets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Packets"));
local u1 = {};
local u2 = {
    Starter = {
        BaseReward = 1
    },
    Second = {
        BaseReward = 5
    }
};

function u1.ProcessClick(p3, p4) -- Line: 44
    -- upvalues: u2 (copy), UpgradeHandler (copy), GamepassHandler (copy), RuneHandler (copy), PrestigeHandler (copy), TreeHandler (copy), EquipmentHandler (copy), SettingsHandler (copy), Packets (copy)
    local v5 = u2[p4];

    if not v5 then
        return;
    end;

    local Currencies = p3:FindFirstChild("Currencies");

    if not Currencies then
        return;
    end;

    local Money = Currencies:FindFirstChild("Money");

    if Money then
        local BaseReward = v5.BaseReward;
        local UpgradeData = UpgradeHandler.GetUpgradeData("Starter", "MoneyMultiplier");

        if UpgradeData then
            local PlayerLevel = UpgradeHandler.GetPlayerLevel(p3, "Starter", "MoneyMultiplier");
            local v6 = UpgradeHandler.CalculateValue(UpgradeData.BaseValue, UpgradeData.ValueScaling, PlayerLevel);
            local UpgradeData2 = UpgradeHandler.GetUpgradeData("Starter", "MoneyMultiplier2");
            local v7;

            if UpgradeData2 then
                local PlayerLevel2 = UpgradeHandler.GetPlayerLevel(p3, "Starter", "MoneyMultiplier2");
                v7 = UpgradeHandler.CalculateValue(UpgradeData2.BaseValue, UpgradeData2.ValueScaling, PlayerLevel2);
            else
                v7 = 1;
            end;

            local UpgradeData3 = UpgradeHandler.GetUpgradeData("RebirthBoosts", "RebirthMoneyMultiplier");
            local v8;

            if UpgradeData3 then
                local PlayerLevel2 = UpgradeHandler.GetPlayerLevel(p3, "RebirthBoosts", "RebirthMoneyMultiplier");
                v8 = UpgradeHandler.CalculateValue(UpgradeData3.BaseValue, UpgradeData3.ValueScaling, PlayerLevel2);
            else
                v8 = 1;
            end;

            local UpgradeData4 = UpgradeHandler.GetUpgradeData("Gems", "MoneyMultiplier");
            local v9;

            if UpgradeData4 then
                local PlayerLevel2 = UpgradeHandler.GetPlayerLevel(p3, "Gems", "MoneyMultiplier");
                v9 = UpgradeHandler.CalculateValue(UpgradeData4.BaseValue, UpgradeData4.ValueScaling, PlayerLevel2);
            else
                v9 = 1;
            end;

            local Multiplier = GamepassHandler.GetMultiplier(p3, "Money");
            local CurrencyMultiplier = RuneHandler.GetCurrencyMultiplier(p3, "Money");
            local CurrencyMultiplier2 = PrestigeHandler.GetCurrencyMultiplier(p3, "Money");
            local CurrencyMultiplier3 = TreeHandler.GetCurrencyMultiplier(p3, "Money");
            local Multiplier2 = EquipmentHandler.GetMultiplier(p3, "Money");
            BaseReward = BaseReward * v6 * v7 * v8 * Multiplier * v9 * CurrencyMultiplier * CurrencyMultiplier2 * CurrencyMultiplier3 * Multiplier2;
        end;

        local UpgradeData2 = UpgradeHandler.GetUpgradeData("Starter", "CritChance");
        local UpgradeData3 = UpgradeHandler.GetUpgradeData("Starter", "CritMultiplier");

        if UpgradeData2 and UpgradeData3 then
            local PlayerLevel = UpgradeHandler.GetPlayerLevel(p3, "Starter", "CritChance");
            local PlayerLevel2 = UpgradeHandler.GetPlayerLevel(p3, "Starter", "CritMultiplier");
            local v10 = UpgradeHandler.CalculateValue(UpgradeData2.BaseValue, UpgradeData2.ValueScaling, PlayerLevel);
            local v11 = UpgradeHandler.CalculateValue(UpgradeData3.BaseValue, UpgradeData3.ValueScaling, PlayerLevel2);
            local UpgradeData4 = UpgradeHandler.GetUpgradeData("RebirthBoosts", "RebirthCritMultiplier");
            local v12;

            if UpgradeData4 then
                local PlayerLevel3 = UpgradeHandler.GetPlayerLevel(p3, "RebirthBoosts", "RebirthCritMultiplier");
                v12 = UpgradeHandler.CalculateValue(UpgradeData4.BaseValue, UpgradeData4.ValueScaling, PlayerLevel3);
            else
                v12 = 1;
            end;

            local v13 = v11 * v12;

            if math.random(1, 100) <= v10 then
                BaseReward = BaseReward * v13;
            end;
        end;

        Money.Value = Money.Value + BaseReward;

        if SettingsHandler.GetSetting(p3, "VfxEnabled") then
            Packets.PlayButtonVfx.sendTo({
                ZoneId = p4
            }, p3);
        end;
    end;
end;

Packets.ButtonClick.listen(function(p14, p15) -- Line: 124
    -- upvalues: u1 (copy)
    if p15 then
        u1.ProcessClick(p15, p14.ZoneId);
    end;
end);

return u1;