-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local Players = game:GetService("Players");
local DataStoreService = game:GetService("DataStoreService");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Workspace = game:GetService("Workspace");
local Handlers = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Handlers");
local AbbreviationHandler = require(Handlers:WaitForChild("AbbreviationHandler"));
local PlaytimeHandler = require(Handlers:WaitForChild("PlaytimeHandler"));
local Configs = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Configs");
local CurrencyConfig = require(Configs:WaitForChild("CurrencyConfig"));
local LeaderboardConfig = require(Configs:WaitForChild("LeaderboardConfig"));
local Packets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Packets"));
local Gui = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Gui");
local LeaderboardSurfaceGuiTemplate = Gui:WaitForChild("LeaderboardSurfaceGuiTemplate");
local YourCurrencySurfaceTemplate = Gui:WaitForChild("YourCurrencySurfaceTemplate");
local Zones = Workspace:WaitForChild("Islands"):WaitForChild("Island1"):WaitForChild("Zones");
local u1 = {};
local StatNames = LeaderboardConfig.StatNames;
local u2 = {};
local u3 = {
    ["1584964472"] = false
};

local function setDualText(p4, p5) -- Line: 88
    p4.Text = p5;
    local bg = p4:FindFirstChild("bg");

    if bg and bg:IsA("TextLabel") then
        bg.Text = p5;
    end;
end;

local function getPlayerInfo(p6) -- Line: 103
    -- upvalues: u2 (copy), Players (copy)
    local u7 = tonumber(p6) or p6;

    if u2[u7] then
        return u2[u7];
    end;

    local v8 = {
        Username = "Unknown",
        DisplayName = "Unknown"
    };
    local success, result = pcall(function() -- Line: 111
        -- upvalues: Players (ref), u7 (copy)
        return Players:GetNameFromUserIdAsync(u7);
    end);

    if success then
        v8.Username = result;
        v8.DisplayName = result;
    end;

    u2[u7] = v8;

    return v8;
end;

function u1.Init() -- Line: 124
    -- upvalues: u1 (copy)
    task.spawn(function() -- Line: 125
        -- upvalues: u1 (ref)
        u1.UpdateAll();

        while task.wait(60) do
            u1.UpdateAll();
        end;
    end);
end;

function u1.UpdateAll() -- Line: 133
    -- upvalues: StatNames (copy), DataStoreService (copy), Players (copy), u3 (copy), Zones (copy), LeaderboardSurfaceGuiTemplate (copy), CurrencyConfig (copy), getPlayerInfo (copy), PlaytimeHandler (copy), AbbreviationHandler (copy), YourCurrencySurfaceTemplate (copy), Packets (copy)
    local v9 = {};

    for _, v in ipairs(StatNames) do
        local OrderedDataStore = DataStoreService:GetOrderedDataStore(v .. "Leaderboard_v2");
        local v10 = v;
        local u11 = 0;

        for _, v2 in ipairs(Players:GetPlayers()) do
            if not u3[tostring(v2.UserId)] then
                local Currencies = v2:FindFirstChild("Currencies");

                if Currencies then
                    local v12 = Currencies:FindFirstChild(v10);

                    if v12 then
                        local Value = v12.Value;

                        if type(Value) == "number" and Value > 0 then
                            u11 = u11 + 1;
                            task.spawn(function() -- Line: 152
                                -- upvalues: Value (copy), OrderedDataStore (copy), v2 (copy), u11 (ref)
                                local v13 = math.log10(Value) * 1000000000000;
                                local math_floor_ret = math.floor(v13);
                                pcall(function() -- Line: 154
                                    -- upvalues: OrderedDataStore (ref), v2 (ref), math_floor_ret (copy)
                                    OrderedDataStore:SetAsync(tostring(v2.UserId), math_floor_ret);
                                end);
                                u11 = u11 - 1;
                            end);
                        end;
                    end;
                end;
            end;
        end;

        local v14 = 0;

        while u11 > 0 and v14 < 100 do
            task.wait(0.1);
            v14 = v14 + 1;
        end;

        local success, result = pcall(function() -- Line: 170
            -- upvalues: OrderedDataStore (copy)
            return OrderedDataStore:GetSortedAsync(false, 50);
        end);

        if success and result then
            local CurrentPage = result:GetCurrentPage();
            local v15 = {};
            local v16 = 1;

            for _, v2 in ipairs(CurrentPage) do
                local key = v2.key;

                if not u3[tostring(key)] then
                    v15[key] = v16;
                    local v17 = {
                        UserId = tostring(key),
                        Stat = v10,
                        Rank = v16
                    };
                    table.insert(v9, v17);
                    v16 = v16 + 1;
                end;
            end;

            local Leaderboards = Zones:FindFirstChild("Leaderboards");

            if Leaderboards then
                Leaderboards = Leaderboards:FindFirstChild(v10);
            end;

            if Leaderboards then
                local SurfaceGuiPart = Leaderboards:FindFirstChild("SurfaceGuiPart");

                if SurfaceGuiPart then
                    local v18 = SurfaceGuiPart:FindFirstChild(LeaderboardSurfaceGuiTemplate.Name);

                    if not v18 then
                        v18 = LeaderboardSurfaceGuiTemplate:Clone();
                        v18.Parent = SurfaceGuiPart;
                        local CurrencyTitleLabel = v18:WaitForChild("Outside"):WaitForChild("CurrencyTitleLabel");
                        local v19;

                        if CurrencyConfig[v10] then
                            v19 = CurrencyConfig[v10].DisplayName or v10;
                        else
                            v19 = v10;
                        end;

                        CurrencyTitleLabel.Text = v19 .. " Leaderboard";
                        v18:WaitForChild("Leaderboard"):WaitForChild("Template").Visible = false;
                    end;

                    local Leaderboard = v18:WaitForChild("Leaderboard");
                    local Template = Leaderboard:WaitForChild("Template");

                    for _, child in ipairs(Leaderboard:GetChildren()) do
                        if child:IsA("Frame") and (child ~= Template and (child.Name ~= "Bottom" and child.Name ~= "Top")) then
                            child:Destroy();
                        end;
                    end;

                    local v20 = CurrencyConfig[v10] and CurrencyConfig[v10].Image;

                    for _, v2 in ipairs(CurrentPage) do
                        local key = v2.key;
                        local v21 = v15[key];

                        if v21 then
                            local value = v2.value;
                            local v22 = getPlayerInfo(key);
                            local v23 = value <= 0 and 0 or math.round(10 ^ (value / 1000000000000));
                            local v24 = v10 == "TimePlayed" and PlaytimeHandler.FormatDuration(v23) or AbbreviationHandler.Abbreviate(v23);
                            local v25 = Template:Clone();
                            v25.Name = "Rank_" .. tostring(v21);
                            v25.Visible = true;
                            local Placement = v25.Placement;
                            local v26 = "#" .. tostring(v21);
                            Placement.Text = v26;
                            local bg = Placement:FindFirstChild("bg");

                            if bg and bg:IsA("TextLabel") then
                                bg.Text = v26;
                            end;

                            local PlayerName = v25.PlayerName;
                            local DisplayName = v22.DisplayName;
                            PlayerName.Text = DisplayName;
                            local bg2 = PlayerName:FindFirstChild("bg");

                            if bg2 and bg2:IsA("TextLabel") then
                                bg2.Text = DisplayName;
                            end;

                            local UserName = v25.UserName;
                            local Username = v22.Username;
                            UserName.Text = Username;
                            local bg3 = UserName:FindFirstChild("bg");

                            if bg3 and bg3:IsA("TextLabel") then
                                bg3.Text = Username;
                            end;

                            local Title = v25:WaitForChild("Frame"):WaitForChild("Title");
                            Title.Visible = true;
                            Title.Text = v24;
                            local bg4 = Title:FindFirstChild("bg");

                            if bg4 and bg4:IsA("TextLabel") then
                                bg4.Text = v24;
                            end;

                            local Icon = Title:FindFirstChild("Icon");

                            if Icon and v20 then
                                Icon.Image = v20;
                            end;

                            v25.Parent = Leaderboard;
                            local Icon2 = v25:FindFirstChild("Icon");

                            if Icon2 then
                                local u27 = tonumber(key);
                                task.spawn(function() -- Line: 275
                                    -- upvalues: Players (ref), u27 (copy), Icon2 (copy)
                                    local success2, result2 = pcall(function() -- Line: 276
                                        -- upvalues: Players (ref), u27 (ref)
                                        return Players:GetUserThumbnailAsync(u27, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100);
                                    end);

                                    if success2 and Icon2.Parent then
                                        Icon2.Image = result2;
                                    end;
                                end);
                            end;
                        end;
                    end;

                    local YourCurrencySurfaceGuiPart = Leaderboards:FindFirstChild("YourCurrencySurfaceGuiPart");

                    if YourCurrencySurfaceGuiPart and not YourCurrencySurfaceGuiPart:FindFirstChild(YourCurrencySurfaceTemplate.Name) then
                        YourCurrencySurfaceTemplate:Clone().Parent = YourCurrencySurfaceGuiPart;
                    end;
                end;
            end;
        end;
    end;

    Packets.LeaderboardPlacementsChanged.sendToAll({
        Entries = v9
    });
end;

return u1;