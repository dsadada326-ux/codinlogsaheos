-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local Players = game:GetService("Players");
local Handlers = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Handlers");
local DataHandler = require(Handlers:WaitForChild("DataHandler"));
local u8 = {
    FormatDuration = function(p1) -- Line: 49, Name: FormatDuration
        local v2 = tonumber(p1) or 0;
        local math_floor_ret = math.floor(v2);
        local v3 = math_floor_ret < 0 and 0 or math_floor_ret;
        local v4 = v3 // 86400;
        local v5 = v3 % 86400 // 3600;
        local v6 = v3 % 3600 // 60;
        local v7 = v3 % 60;

        if v4 > 0 then
            return string.format("%dd, %02dh, %02dm, %02ds", v4, v5, v6, v7);
        end;

        if v5 > 0 then
            return string.format("%dh, %02dm, %02ds", v5, v6, v7);
        end;

        if v6 > 0 then
            return string.format("%dm %02ds", v6, v7);
        end;

        return string.format("%02ds", v7);
    end
};

local function tick() -- Line: 71
    -- upvalues: Players (copy), DataHandler (copy), u8 (copy)
    for _, v in ipairs(Players:GetPlayers()) do
        local Profile = DataHandler.GetProfile(v);

        if Profile and Profile.Data then
            local v9 = (tonumber(Profile.Data.PlayTimeSeconds) or 0) + 1;
            Profile.Data.PlayTimeSeconds = v9;
            local leaderstats = v:FindFirstChild("leaderstats");

            if leaderstats then
                leaderstats = leaderstats:FindFirstChild("TimePlayed");
            end;

            if leaderstats then
                leaderstats.Value = u8.FormatDuration(v9);
            end;

            local Currencies = v:FindFirstChild("Currencies");

            if Currencies then
                Currencies = Currencies:FindFirstChild("TimePlayed");
            end;

            if Currencies then
                Currencies.Value = v9;
            end;
        end;
    end;
end;

function u8.Init() -- Line: 93
    -- upvalues: tick (copy)
    task.spawn(function() -- Line: 94
        -- upvalues: tick (ref)
        while true do
            task.wait(1);
            tick();
        end;
    end);
end;

return u8;