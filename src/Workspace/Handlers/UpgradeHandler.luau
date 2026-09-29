-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Configs = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Configs");
local Upgrades = Configs:WaitForChild("Upgrades");
local DataHandler = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Handlers"):WaitForChild("DataHandler"));
local UpgradeProductConfig = require(Configs:WaitForChild("UpgradeProductConfig"));
local Packets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Packets"));
local Requests = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Requests"));
local u1 = {};
local u2 = {};

function u1.GetUpgradeData(p3, p4) -- Line: 51
    -- upvalues: Upgrades (copy)
    local v5 = Upgrades:FindFirstChild(p3 .. "UpgradeConfig");

    if v5 then
        return require(v5)[p4];
    end;

    return nil;
end;

function u1.GetPlayerLevel(p6, p7, p8) -- Line: 60
    -- upvalues: DataHandler (copy)
    local Profile = DataHandler.GetProfile(p6);

    if not Profile then
        return 0;
    end;

    if not Profile.Data.Upgrades[p7] then
        Profile.Data.Upgrades[p7] = {};
    end;

    return Profile.Data.Upgrades[p7][p8] or 0;
end;

function u1.ResetBoard(p9, p10) -- Line: 71
    -- upvalues: DataHandler (copy)
    local Profile = DataHandler.GetProfile(p9);

    if Profile and Profile.Data.Upgrades[p10] then
        Profile.Data.Upgrades[p10] = {};
    end;
end;

function u1.CalculateCost(p11, p12, p13) -- Line: 78
    return math.floor(p11 * p12 ^ p13);
end;

function u1.CalculateValue(p14, p15, p16) -- Line: 82
    return p14 + p15 * p16;
end;

function u1.ProcessPurchase(p17, p18, p19) -- Line: 86
    -- upvalues: DataHandler (copy), u1 (copy)
    local Profile = DataHandler.GetProfile(p17);

    if not Profile then
        return false, 0;
    end;

    local UpgradeData = u1.GetUpgradeData(p18, p19);

    if not UpgradeData then
        return false, 0;
    end;

    local PlayerLevel = u1.GetPlayerLevel(p17, p18, p19);

    if (UpgradeData.Max or 10) <= PlayerLevel then
        return false, PlayerLevel;
    end;

    if UpgradeData.Requires and u1.GetPlayerLevel(p17, p18, UpgradeData.Requires.UpgradeId) < UpgradeData.Requires.Level then
        return false, PlayerLevel;
    end;

    local v20 = u1.CalculateCost(UpgradeData.BaseCost, UpgradeData.CostScaling, PlayerLevel);
    local Currencies = p17:FindFirstChild("Currencies");

    if Currencies then
        Currencies = Currencies:FindFirstChild(UpgradeData.Currency);
    end;

    if not Currencies or v20 > Currencies.Value then
        return false, PlayerLevel;
    end;

    Currencies.Value = Currencies.Value - v20;
    Profile.Data.Upgrades[p18][p19] = PlayerLevel + 1;

    return true, PlayerLevel + 1;
end;

function u1.ProcessMaxPurchase(p21, p22, p23) -- Line: 121
    -- upvalues: DataHandler (copy), u1 (copy)
    local Profile = DataHandler.GetProfile(p21);

    if not Profile then
        return false, 0;
    end;

    local UpgradeData = u1.GetUpgradeData(p22, p23);

    if not UpgradeData then
        return false, 0;
    end;

    local PlayerLevel = u1.GetPlayerLevel(p21, p22, p23);
    local v24 = UpgradeData.Max or 10;

    if v24 <= PlayerLevel then
        return false, PlayerLevel;
    end;

    if UpgradeData.Requires and u1.GetPlayerLevel(p21, p22, UpgradeData.Requires.UpgradeId) < UpgradeData.Requires.Level then
        return false, PlayerLevel;
    end;

    local Currencies = p21:FindFirstChild("Currencies");

    if Currencies then
        Currencies = Currencies:FindFirstChild(UpgradeData.Currency);
    end;

    if not Currencies then
        return false, PlayerLevel;
    end;

    local Value = Currencies.Value;
    local v25 = PlayerLevel;
    local v26 = 0;

    while PlayerLevel < v24 do
        local v27 = u1.CalculateCost(UpgradeData.BaseCost, UpgradeData.CostScaling, PlayerLevel);

        if v26 + v27 > Value then
            break;
        end;

        v26 = v26 + v27;
        PlayerLevel = PlayerLevel + 1;
    end;

    if v25 >= PlayerLevel then
        return false, v25;
    end;

    Currencies.Value = Currencies.Value - v26;
    Profile.Data.Upgrades[p22][p23] = PlayerLevel;

    return true, PlayerLevel;
end;

function u1.RequestProductPrompt(p28, p29, p30, p31) -- Line: 178
    -- upvalues: u1 (copy), u2 (copy), UpgradeProductConfig (copy)
    if p29 == "Gems" then
        return nil;
    end;

    if not p31 then
        return nil;
    end;

    local UpgradeData = u1.GetUpgradeData(p29, p30);

    if not UpgradeData then
        return nil;
    end;

    if u1.GetPlayerLevel(p28, p29, p30) >= (UpgradeData.Max or 10) then
        return nil;
    end;

    u2[p28.UserId] = {
        Board = p29,
        Id = p30
    };

    return UpgradeProductConfig.MaxProductId;
end;

function u1.GetPendingProductPurchase(p32) -- Line: 197
    -- upvalues: u2 (copy)
    return u2[p32];
end;

function u1.ClearPendingProductPurchase(p33) -- Line: 201
    -- upvalues: u2 (copy)
    u2[p33] = nil;
end;

function u1.IsLevelProduct(p34) -- Line: 205
    -- upvalues: UpgradeProductConfig (copy)
    return p34 == UpgradeProductConfig.LevelProductId;
end;

function u1.IsMaxProduct(p35) -- Line: 209
    -- upvalues: UpgradeProductConfig (copy)
    return p35 == UpgradeProductConfig.MaxProductId;
end;

function u1.GrantLevel(p36, p37, p38) -- Line: 215
    -- upvalues: DataHandler (copy), u1 (copy)
    local Profile = DataHandler.GetProfile(p36);

    if not Profile then
        return false, 0;
    end;

    local UpgradeData = u1.GetUpgradeData(p37, p38);

    if not UpgradeData then
        return false, 0;
    end;

    local PlayerLevel = u1.GetPlayerLevel(p36, p37, p38);

    if (UpgradeData.Max or 10) <= PlayerLevel then
        return false, PlayerLevel;
    end;

    Profile.Data.Upgrades[p37][p38] = PlayerLevel + 1;

    return true, PlayerLevel + 1;
end;

function u1.GrantMaxLevel(p39, p40, p41) -- Line: 232
    -- upvalues: DataHandler (copy), u1 (copy)
    local Profile = DataHandler.GetProfile(p39);

    if not Profile then
        return false, 0;
    end;

    local UpgradeData = u1.GetUpgradeData(p40, p41);

    if not UpgradeData then
        return false, 0;
    end;

    local PlayerLevel = u1.GetPlayerLevel(p39, p40, p41);
    local v42 = UpgradeData.Max or 10;

    if v42 <= PlayerLevel then
        return false, PlayerLevel;
    end;

    Profile.Data.Upgrades[p40][p41] = v42;

    return true, v42;
end;

Requests.GetUpgradeLevels:OnInvoke(function(p43) -- Line: 247
    -- upvalues: DataHandler (copy)
    local Profile = DataHandler.GetProfile(p43);

    return {
        Levels = Profile and (Profile.Data and Profile.Data.Upgrades) or {}
    };
end);
Requests.BuyUpgrade:OnInvoke(function(p44, p45) -- Line: 253
    -- upvalues: u1 (copy), Packets (copy)
    local v46, v47 = u1.ProcessPurchase(p44, p45.Board, p45.UpgradeId);

    if v46 then
        Packets.UpgradePurchased.sendTo({
            Auto = false,
            Board = p45.Board,
            UpgradeId = p45.UpgradeId,
            NewLevel = v47
        }, p44);
    end;

    return {
        Success = v46,
        NewLevel = v47
    };
end);
Requests.BuyMaxUpgrade:OnInvoke(function(p48, p49) -- Line: 266
    -- upvalues: u1 (copy), Packets (copy)
    local v50, v51 = u1.ProcessMaxPurchase(p48, p49.Board, p49.UpgradeId);

    if v50 then
        Packets.UpgradePurchased.sendTo({
            Auto = false,
            Board = p49.Board,
            UpgradeId = p49.UpgradeId,
            NewLevel = v51
        }, p48);
    end;

    return {
        Success = v50,
        NewLevel = v51
    };
end);
Requests.PromptUpgradeProductPurchase:OnInvoke(function(p52, p53) -- Line: 279
    -- upvalues: u1 (copy)
    return {
        ProductId = u1.RequestProductPrompt(p52, p53.Board, p53.UpgradeId, p53.IsMax)
    };
end);

return u1;