-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local Players = game:GetService("Players");
local RunService = game:GetService("RunService");
local Handlers = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Handlers");
local ButtonHandler = require(Handlers:WaitForChild("ButtonHandler"));
local UpgradeHandler = require(Handlers:WaitForChild("UpgradeHandler"));
local GamepassHandler = require(Handlers:WaitForChild("GamepassHandler"));
local SettingsHandler = require(Handlers:WaitForChild("SettingsHandler"));
local v1 = {};
local u2 = {};
local u3 = nil;

function v1.Init() -- Line: 35
    -- upvalues: u3 (ref), UpgradeHandler (copy), RunService (copy), Players (copy), GamepassHandler (copy), SettingsHandler (copy), u2 (copy), ButtonHandler (copy)
    u3 = UpgradeHandler.GetUpgradeData("RebirthBoosts", "AutoClicker").Max or 10;
    RunService.Heartbeat:Connect(function() -- Line: 38
        -- upvalues: Players (ref), UpgradeHandler (ref), GamepassHandler (ref), SettingsHandler (ref), u3 (ref), u2 (ref), ButtonHandler (ref)
        local os_clock_ret = os.clock();

        for _, v in ipairs(Players:GetPlayers()) do
            local PlayerLevel = UpgradeHandler.GetPlayerLevel(v, "RebirthBoosts", "AutoClicker");
            local v4 = GamepassHandler.HasPass(v, "AutoButton");

            if (PlayerLevel > 0 and true or v4) and SettingsHandler.GetSetting(v, "AutoClickEnabled") then
                if v4 then
                    PlayerLevel = math.max(PlayerLevel, u3) or PlayerLevel;
                end;

                if UpgradeHandler.CalculateValue(1.1, -0.1, PlayerLevel) <= os_clock_ret - (u2[v] or 0) then
                    u2[v] = os_clock_ret;
                    ButtonHandler.ProcessClick(v, "Starter");
                end;
            end;
        end;
    end);
    Players.PlayerRemoving:Connect(function(p5) -- Line: 59
        -- upvalues: u2 (ref)
        u2[p5] = nil;
    end);
end;

return v1;