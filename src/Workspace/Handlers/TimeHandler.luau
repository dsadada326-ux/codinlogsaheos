-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local Players = game:GetService("Players");
local RunService = game:GetService("RunService");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Workspace = game:GetService("Workspace");
local Handlers = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Handlers");
local UpgradeHandler = require(Handlers:WaitForChild("UpgradeHandler"));
local ZoneHandler = require(Handlers:WaitForChild("ZoneHandler"));
local GamepassHandler = require(Handlers:WaitForChild("GamepassHandler"));
local SettingsHandler = require(Handlers:WaitForChild("SettingsHandler"));
local RuneHandler = require(Handlers:WaitForChild("RuneHandler"));
local PrestigeHandler = require(Handlers:WaitForChild("PrestigeHandler"));
local TreeHandler = require(Handlers:WaitForChild("TreeHandler"));
local EquipmentHandler = require(Handlers:WaitForChild("EquipmentHandler"));
local PrestigeAutomationHandler = require(Handlers:WaitForChild("PrestigeAutomationHandler"));
local Packets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Packets"));
local Zones = Workspace:WaitForChild("Islands"):WaitForChild("Island1"):WaitForChild("Zones");
local v1 = {};
local u2 = {};

function v1.Init() -- Line: 72
    -- upvalues: RunService (copy), Zones (copy), Players (copy), ZoneHandler (copy), UpgradeHandler (copy), GamepassHandler (copy), PrestigeAutomationHandler (copy), u2 (copy), RuneHandler (copy), PrestigeHandler (copy), TreeHandler (copy), EquipmentHandler (copy), SettingsHandler (copy), Packets (copy)
    RunService.Heartbeat:Connect(function() -- Line: 73
        -- upvalues: Zones (ref), Players (ref), ZoneHandler (ref), UpgradeHandler (ref), GamepassHandler (ref), PrestigeAutomationHandler (ref), u2 (ref), RuneHandler (ref), PrestigeHandler (ref), TreeHandler (ref), EquipmentHandler (ref), SettingsHandler (ref), Packets (ref)
        local os_clock_ret = os.clock();
        local Time = Zones:FindFirstChild("Time");

        if Time then
            Time = Time:FindFirstChild("Hitbox");
        end;

        for _, v in ipairs(Players:GetPlayers()) do
            if ZoneHandler.HasZoneUnlocked(v, "Time") then
                local v3 = UpgradeHandler.GetPlayerLevel(v, "Time", "AutoTime") >= 1 or GamepassHandler.HasPass(v, "AutoTime") or PrestigeAutomationHandler.IsActionActive(v, "Time");
                local v4;

                if v3 or not Time then
                    v4 = v;
                else
                    local Character = v.Character;

                    if Character then
                        local v5 = Time.Size / 2;
                        v4 = v;

                        for _, v2 in ipairs({ "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }) do
                            local v6 = Character:FindFirstChild(v2);

                            if v6 then
                                local v7 = Time.CFrame:ToObjectSpace(v6.CFrame);

                                if math.abs(v7.X) <= v5.X and (math.abs(v7.Y) <= v5.Y and math.abs(v7.Z) <= v5.Z) then
                                    v3 = true;
                                    break;
                                end;
                            end;
                        end;
                    else
                        v4 = v;
                    end;
                end;

                if v3 then
                    local PlayerLevel = UpgradeHandler.GetPlayerLevel(v4, "Time", "TimeSpeed");

                    if UpgradeHandler.CalculateValue(1, -0.1, PlayerLevel) <= os_clock_ret - (u2[v4] or 0) then
                        u2[v4] = os_clock_ret;
                        local PlayerLevel2 = UpgradeHandler.GetPlayerLevel(v4, "Time", "TimeMultiplier");
                        local v8 = UpgradeHandler.CalculateValue(1, 1, PlayerLevel2);
                        local Multiplier = GamepassHandler.GetMultiplier(v4, "Time");
                        local PlayerLevel3 = UpgradeHandler.GetPlayerLevel(v4, "Gems", "TimeMultiplier");
                        local UpgradeData = UpgradeHandler.GetUpgradeData("Gems", "TimeMultiplier");
                        local v9 = UpgradeData and UpgradeHandler.CalculateValue(UpgradeData.BaseValue, UpgradeData.ValueScaling, PlayerLevel3) or 1;
                        local CurrencyMultiplier = RuneHandler.GetCurrencyMultiplier(v4, "Time");
                        local CurrencyMultiplier2 = PrestigeHandler.GetCurrencyMultiplier(v4, "Time");
                        local CurrencyMultiplier3 = TreeHandler.GetCurrencyMultiplier(v4, "Time");
                        local Multiplier2 = EquipmentHandler.GetMultiplier(v4, "Time");
                        local v10 = v8 * Multiplier * v9 * CurrencyMultiplier * CurrencyMultiplier2 * CurrencyMultiplier3 * Multiplier2;
                        local Currencies = v4:FindFirstChild("Currencies");

                        if Currencies then
                            Currencies = Currencies:FindFirstChild("Time");
                        end;

                        if Currencies then
                            Currencies.Value = Currencies.Value + v10;
                        end;

                        if SettingsHandler.GetSetting(v4, "VfxEnabled") then
                            Packets.PlayTimeButtonVfx.sendTo(nil, v4);
                        end;
                    end;
                end;
            end;
        end;
    end);
    Players.PlayerRemoving:Connect(function(p11) -- Line: 151
        -- upvalues: u2 (ref)
        u2[p11] = nil;
    end);
end;

return v1;