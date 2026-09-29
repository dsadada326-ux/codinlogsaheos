-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local Players = game:GetService("Players");
local Workspace = game:GetService("Workspace");
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules");
local Configs = Modules:WaitForChild("Configs");
local Handlers = Modules:WaitForChild("Handlers");
local Runes = Configs:WaitForChild("Runes");
local RuneLevels = require(Modules:WaitForChild("RuneLevels"));
local CurrencyConfig = require(Configs:WaitForChild("CurrencyConfig"));
local DataHandler = require(Handlers:WaitForChild("DataHandler"));
local ZoneHandler = require(Handlers:WaitForChild("ZoneHandler"));
local u1 = nil;

local function getEquipmentHandler() -- Line: 66
    -- upvalues: u1 (ref), Handlers (copy)
    if not u1 then
        u1 = require(Handlers:WaitForChild("EquipmentHandler"));
    end;

    return u1;
end;

local u2 = nil;

local function getUpgradeHandler() -- Line: 74
    -- upvalues: u2 (ref), Handlers (copy)
    if not u2 then
        u2 = require(Handlers:WaitForChild("UpgradeHandler"));
    end;

    return u2;
end;

local u3 = nil;

local function getSkillTreeHandler() -- Line: 82
    -- upvalues: u3 (ref), Handlers (copy)
    if not u3 then
        u3 = require(Handlers:WaitForChild("SkillTreeHandler"));
    end;

    return u3;
end;

local Packets = require(Modules:WaitForChild("Network"):WaitForChild("Packets"));
local Requests = require(Modules:WaitForChild("Network"):WaitForChild("Requests"));
local u4 = {};
local u5 = {};

local function getZoneConfig(p6) -- Line: 100
    -- upvalues: u5 (copy), Runes (copy)
    if u5[p6] then
        return u5[p6];
    end;

    local v7 = Runes:FindFirstChild(p6 .. "RuneConfig");

    if not v7 then
        return nil;
    end;

    local v8 = require(v7);
    u5[p6] = v8;

    return v8;
end;

local function getBulkBonus(u9, p10) -- Line: 117
    -- upvalues: u5 (copy), Runes (copy), RuneLevels (copy), u2 (ref), Handlers (copy), u1 (ref), u3 (ref)
    local v11 = 0;

    if p10.Data.Runes then
        for i, v in pairs(p10.Data.Runes) do
            local v12;

            if u5[i] then
                v12 = u5[i];
            else
                local v13 = Runes:FindFirstChild(i .. "RuneConfig");

                if v13 then
                    v12 = require(v13);
                    u5[i] = v12;
                else
                    v12 = nil;
                end;
            end;

            if v12 then
                for i2, v2 in pairs(v) do
                    local v14 = v12.Runes[i2];

                    if v14 then
                        v14 = RuneLevels.GetLevelData(v14.Levels, v2.Level);
                    end;

                    if v14 then
                        v14 = v14.Boosts.RuneBulk;
                    end;

                    if v14 then
                        v11 = v11 + v14.Value;
                    end;
                end;
            end;
        end;
    end;

    if not u2 then
        u2 = require(Handlers:WaitForChild("UpgradeHandler"));
    end;

    local v15 = u2;
    local UpgradeData = v15.GetUpgradeData("TimeBoosts", "RuneBulk");

    if UpgradeData then
        local PlayerLevel = v15.GetPlayerLevel(u9, "TimeBoosts", "RuneBulk");
        v11 = v11 + v15.CalculateValue(UpgradeData.BaseValue, UpgradeData.ValueScaling, PlayerLevel);
    end;

    local u16 = 0;
    pcall(function() -- Line: 145
        -- upvalues: u16 (ref), u1 (ref), Handlers (ref), u9 (copy)
        if not u1 then
            u1 = require(Handlers:WaitForChild("EquipmentHandler"));
        end;

        u16 = u1.GetFlatBonus(u9, "RuneBulk");
    end);
    local u17 = 0;
    pcall(function() -- Line: 151
        -- upvalues: u17 (ref), u3 (ref), Handlers (ref), u9 (copy)
        if not u3 then
            u3 = require(Handlers:WaitForChild("SkillTreeHandler"));
        end;

        u17 = u3.GetFlatBonus(u9, "RuneBulk");
    end);

    return v11 + u16 + u17;
end;

local function getRollCount(p18, p19) -- Line: 159
    -- upvalues: getBulkBonus (copy)
    local v20 = 1 + getBulkBonus(p18, p19);
    local math_floor_ret = math.floor(v20);

    return math.max(1, math_floor_ret);
end;

local u21 = nil;

function u4.GetRollInfo(p22) -- Line: 170
    -- upvalues: DataHandler (copy), getBulkBonus (copy), u21 (ref)
    local Profile = DataHandler.GetProfile(p22);
    local v23;

    if Profile == nil then
        v23 = false;
    else
        v23 = Profile.Data ~= nil;
    end;

    local v24;

    if v23 then
        local v25 = 1 + getBulkBonus(p22, Profile);
        local math_floor_ret = math.floor(v25);
        v24 = math.max(1, math_floor_ret) or 1;
    else
        v24 = 1;
    end;

    return {
        RollInterval = 1,
        RollCount = v24,
        RuneLuck = v23 and u21(p22, Profile) or 0
    };
end;

u21 = function(u26, p27) -- Line: 187, Name: getLuckBonus
    -- upvalues: u5 (copy), Runes (copy), RuneLevels (copy), u1 (ref), Handlers (copy)
    local v28 = 0;

    if p27.Data.Runes then
        for i, v in pairs(p27.Data.Runes) do
            local v29;

            if u5[i] then
                v29 = u5[i];
            else
                local v30 = Runes:FindFirstChild(i .. "RuneConfig");

                if v30 then
                    v29 = require(v30);
                    u5[i] = v29;
                else
                    v29 = nil;
                end;
            end;

            if v29 then
                for i2, v2 in pairs(v) do
                    local v31 = v29.Runes[i2];

                    if v31 then
                        v31 = RuneLevels.GetLevelData(v31.Levels, v2.Level);
                    end;

                    if v31 then
                        v31 = v31.Boosts.RuneLuck;
                    end;

                    if v31 then
                        v28 = v28 + v31.Value;
                    end;
                end;
            end;
        end;
    end;

    local u32 = 0;
    pcall(function() -- Line: 208
        -- upvalues: u32 (ref), u1 (ref), Handlers (ref), u26 (copy)
        if not u1 then
            u1 = require(Handlers:WaitForChild("EquipmentHandler"));
        end;

        u32 = u1.GetFlatBonus(u26, "RuneLuck");
    end);

    return v28 + u32;
end;

function u4.GetCurrencyMultiplier(p33, p34) -- Line: 219
    -- upvalues: DataHandler (copy), u5 (copy), Runes (copy), RuneLevels (copy)
    local Profile = DataHandler.GetProfile(p33);

    if not (Profile and (Profile.Data and Profile.Data.Runes)) then
        return 1;
    end;

    local v35 = 1;

    for i, v in pairs(Profile.Data.Runes) do
        local v36;

        if u5[i] then
            v36 = u5[i];
        else
            local v37 = Runes:FindFirstChild(i .. "RuneConfig");

            if v37 then
                v36 = require(v37);
                u5[i] = v36;
            else
                v36 = nil;
            end;
        end;

        if v36 then
            for i2, v2 in pairs(v) do
                local v38 = v36.Runes[i2];

                if v38 then
                    v38 = RuneLevels.GetLevelData(v38.Levels, v2.Level);
                end;

                if v38 then
                    v38 = v38.Boosts[p34];
                end;

                if v38 then
                    v35 = v35 * v38.Value;
                end;
            end;
        end;
    end;

    return v35;
end;

function u4.GetData(p39) -- Line: 243
    -- upvalues: DataHandler (copy)
    local Profile = DataHandler.GetProfile(p39);

    if not (Profile and Profile.Data) then
        return {};
    end;

    if type(Profile.Data.Runes) ~= "table" then
        Profile.Data.Runes = {};
    end;

    return Profile.Data.Runes;
end;

local function buildWeightedPool(p40, p41) -- Line: 264
    local v42 = 0;
    local v43 = (1 / 0);
    local v44 = {};

    for _, v in pairs(p40.Runes) do
        local v45 = v.Chance or 0;

        if v45 > 0 then
            v42 = math.max(v42, v45);
            v43 = math.min(v43, v45);
        end;
    end;

    local v46 = v43 < v42 and (math.log(v42 / v43) or 0) or 0;
    local v47 = 0;

    for i, v in pairs(p40.Runes) do
        local v48 = v.Chance or 0;
        local v49;

        if v48 > 0 and v46 > 0 then
            local v50 = math.log(v42 / v48) / v46;
            v49 = math.clamp(v50, 0, 1);
        else
            v49 = 0;
        end;

        local v51 = v48 * p41 ^ v49;
        v47 = v47 + v51;
        table.insert(v44, {
            name = i,
            data = v,
            weight = v51
        });
    end;

    table.sort(v44, function(p52, p53) -- Line: 297
        return p52.name < p53.name;
    end);

    return v44, v47;
end;

local function rollFromPool(p54, p55) -- Line: 304
    if p55 <= 0 or #p54 == 0 then
        return nil, nil;
    end;

    local v56 = math.random() * p55;
    local v57 = 0;

    for _, v in ipairs(p54) do
        v57 = v57 + v.weight;

        if v56 <= v57 then
            return v.name, v.data;
        end;
    end;

    local v58 = p54[#p54];

    return v58.name, v58.data;
end;

local function grantRune(p59, p60, p61, p62) -- Line: 321
    -- upvalues: RuneLevels (copy)
    if not p59.Data.Runes[p60] then
        p59.Data.Runes[p60] = {};
    end;

    local v63 = p59.Data.Runes[p60][p61];
    local v64 = RuneLevels.Normalize(p62.Levels);

    if not v63 then
        local v65 = {
            Level = 1,
            Progress = 0
        };
        p59.Data.Runes[p60][p61] = v65;

        return v65;
    end;

    local v66 = v64[v63.Level];

    if v66 and v63.Progress < v66.Required then
        v63.Progress = v63.Progress + 1;
    end;

    if v66 and (v64[v63.Level + 1] and v63.Progress >= v66.Required) then
        v63.Progress = 0;
        v63.Level = v63.Level + 1;
    end;

    return v63;
end;

local function resolveZoneConfig(p67) -- Line: 349
    -- upvalues: Runes (copy), u5 (copy)
    if type(p67) ~= "string" then
        return nil, nil;
    end;

    local v68 = p67:lower();

    for _, child in ipairs(Runes:GetChildren()) do
        if child:IsA("ModuleScript") then
            local string_gsub_ret = string.gsub(child.Name, "RuneConfig$", "");

            if string_gsub_ret:lower() == v68 then
                if u5[string_gsub_ret] then
                    return string_gsub_ret, u5[string_gsub_ret];
                end;

                local v69 = Runes:FindFirstChild(string_gsub_ret .. "RuneConfig");

                if not v69 then
                    return string_gsub_ret, nil;
                end;

                local v70 = require(v69);
                u5[string_gsub_ret] = v70;

                return string_gsub_ret, v70;
            end;
        end;
    end;

    return nil, nil;
end;

local function resolveRuneData(p71, p72) -- Line: 365
    if type(p72) ~= "string" or type(p71.Runes) ~= "table" then
        return nil, nil;
    end;

    local v73 = p72:lower();

    for i, v in pairs(p71.Runes) do
        if i:lower() == v73 then
            return i, v;
        end;
    end;

    return nil, nil;
end;

function u4.GrantRune(p74, p75, p76, p77) -- Line: 381
    -- upvalues: DataHandler (copy), resolveZoneConfig (copy), resolveRuneData (copy), grantRune (copy), Packets (copy)
    local Profile = DataHandler.GetProfile(p74);

    if not (Profile and Profile.Data) then
        return false, "no profile loaded";
    end;

    local v78, v79 = resolveZoneConfig(p75);

    if not v79 then
        return false, "unknown rune zone: " .. tostring(p75);
    end;

    local v80, v81 = resolveRuneData(v79, p76);

    if not v81 then
        return false, "unknown rune: " .. tostring(p76);
    end;

    if type(Profile.Data.Runes) ~= "table" then
        Profile.Data.Runes = {};
    end;

    local math_floor_ret = math.floor(p77 or 1);
    local math_max_ret = math.max(math_floor_ret, 1);
    local v82 = nil;

    for i = 1, math_max_ret do
        v82 = grantRune(Profile, v78, v80, v81);
        local _ = i;
    end;

    Packets.RuneRolled.sendTo({
        ZoneName = v78,
        RuneName = v80,
        Level = v82.Level,
        Progress = v82.Progress,
        Count = math_max_ret
    }, p74);

    return true, v78, v80, v82.Level;
end;

function u4.RollForPlayer(p83, p84, p85) -- Line: 419
    -- upvalues: DataHandler (copy), resolveZoneConfig (copy), buildWeightedPool (copy), rollFromPool (copy), grantRune (copy), Packets (copy)
    local Profile = DataHandler.GetProfile(p83);

    if not (Profile and Profile.Data) then
        return false, "no profile loaded";
    end;

    local v86, v87 = resolveZoneConfig(p84);

    if not (v87 and next(v87.Runes or {})) then
        return false, "unknown rune zone: " .. tostring(p84);
    end;

    if type(Profile.Data.Runes) ~= "table" then
        Profile.Data.Runes = {};
    end;

    local v88, v89 = buildWeightedPool(v87, 1);
    local math_floor_ret = math.floor(p85 or 1);
    local v90 = {};

    for i = 1, math.max(math_floor_ret, 1) do
        local v91, v92 = rollFromPool(v88, v89);

        if v91 then
            grantRune(Profile, v86, v91, v92);
            v90[v91] = (v90[v91] or 0) + 1;
        end;

        local v93;

        if i % 2000 == 0 then
            task.wait();

            if not p83.Parent then
                break;
            end;

            v93 = i;
        else
            v93 = i;
        end;
    end;

    if p83.Parent then
        for i, v in pairs(v90) do
            local v94 = Profile.Data.Runes[v86][i];
            Packets.RuneRolled.sendTo({
                ZoneName = v86,
                RuneName = i,
                Level = v94.Level,
                Progress = v94.Progress,
                Count = v
            }, p83);
        end;
    end;

    return true, v90;
end;

local function attemptRoll(p95, p96, p97, p98) -- Line: 465
    -- upvalues: CurrencyConfig (copy), Packets (copy), u21 (ref), buildWeightedPool (copy), getBulkBonus (copy), rollFromPool (copy), grantRune (copy)
    local Currencies = p95:FindFirstChild("Currencies");

    if Currencies then
        Currencies = Currencies:FindFirstChild(p98.Currency);
    end;

    if not Currencies then
        return;
    end;

    if Currencies.Value < p98.Cost then
        local v99 = CurrencyConfig[p98.Currency];
        Packets.ShowNotification.sendTo({
            Kind = "Error",
            Text = (v99 and v99.DisplayName or p98.Currency) .. " required to roll!"
        }, p95);

        return;
    end;

    if not next(p98.Runes) then
        return;
    end;

    Currencies.Value = Currencies.Value - p98.Cost;

    if p96.Data.Currencies then
        p96.Data.Currencies[p98.Currency] = Currencies.Value;
    end;

    if type(p96.Data.Runes) ~= "table" then
        p96.Data.Runes = {};
    end;

    local v100 = 1 + u21(p95, p96);
    local v101, v102 = buildWeightedPool(p98, (math.max(v100, 0.01)));
    local v103 = 1 + getBulkBonus(p95, p96);
    local math_floor_ret = math.floor(v103);
    local v104 = {};

    for i = 1, math.max(1, math_floor_ret) do
        local v105, v106 = rollFromPool(v101, v102);
        local v107;

        if v105 then
            grantRune(p96, p97, v105, v106);
            v104[v105] = (v104[v105] or 0) + 1;
            v107 = i;
        else
            v107 = i;
        end;
    end;

    for i, v in pairs(v104) do
        local v108 = p96.Data.Runes[p97][i];
        Packets.RuneRolled.sendTo({
            ZoneName = p97,
            RuneName = i,
            Level = v108.Level,
            Progress = v108.Progress,
            Count = v
        }, p95);
    end;
end;

local u109 = {};

local function canPlayerRoll(p110, p111) -- Line: 518
    -- upvalues: u109 (copy), ZoneHandler (copy)
    local v112 = u109[p111];

    return not v112 and true or ZoneHandler.HasZoneUnlocked(p110, v112);
end;

local u113 = {};
local u114 = {};

local function startRolling(u115, u116, u117) -- Line: 527
    -- upvalues: u113 (copy), u114 (copy), u109 (copy), ZoneHandler (copy), DataHandler (copy), attemptRoll (copy)
    if not u113[u116] then
        u113[u116] = {};
    end;

    if u113[u116][u115] then
        return;
    end;

    u113[u116][u115] = true;

    if not u114[u116] then
        u114[u116] = {};
    end;

    u114[u116][u115] = task.spawn(function() -- Line: 538
        -- upvalues: u113 (ref), u116 (copy), u115 (copy), u109 (ref), ZoneHandler (ref), DataHandler (ref), attemptRoll (ref), u117 (copy)
        while u113[u116] and u113[u116][u115] do
            task.wait(1);

            if not (u113[u116] and u113[u116][u115]) then
                break;
            end;

            local v118 = u109[u116];

            if not v118 and true or ZoneHandler.HasZoneUnlocked(u115, v118) then
                local Profile = DataHandler.GetProfile(u115);

                if Profile and Profile.Data then
                    attemptRoll(u115, Profile, u116, u117);
                end;
            end;
        end;
    end);
end;

local function stopRolling(p119, p120) -- Line: 552
    -- upvalues: u113 (copy), u114 (copy)
    if not (u113[p120] and u113[p120][p119]) then
        return;
    end;

    u113[p120][p119] = nil;
    local v121 = u114[p120] and u114[p120][p119];

    if v121 then
        task.cancel(v121);
        u114[p120][p119] = nil;
    end;
end;

local function getCharacterFilter() -- Line: 563
    -- upvalues: Players (copy)
    local v122 = {};

    for _, v in ipairs(Players:GetPlayers()) do
        if v.Character then
            table.insert(v122, v.Character);
        end;
    end;

    return v122;
end;

local function getOccupyingPlayers(p123, p124) -- Line: 573
    -- upvalues: Workspace (copy), Players (copy)
    local OverlapParams_new_ret = OverlapParams.new();
    OverlapParams_new_ret.FilterType = Enum.RaycastFilterType.Include;
    OverlapParams_new_ret.FilterDescendantsInstances = p124;
    local PartsInPart = Workspace:GetPartsInPart(p123, OverlapParams_new_ret);
    local v125 = {};

    for _, v in ipairs(PartsInPart) do
        local Parent = v.Parent;

        if Parent and Parent:FindFirstChild("Humanoid") then
            local PlayerFromCharacter = Players:GetPlayerFromCharacter(Parent);

            if PlayerFromCharacter then
                v125[PlayerFromCharacter] = true;
            end;
        end;
    end;

    return v125;
end;

function u4.Init() -- Line: 595
    -- upvalues: u5 (copy), Runes (copy), u109 (copy), Workspace (copy), getCharacterFilter (copy), getOccupyingPlayers (copy), startRolling (copy), u113 (copy), u114 (copy), Players (copy)
    local u126 = {};
    local u127 = {};

    local function setupZone(u128) -- Line: 599
        -- upvalues: u5 (ref), Runes (ref), u126 (copy), u127 (copy), u109 (ref)
        if not u128:IsA("Model") then
            return;
        end;

        local Name = u128.Name;
        local v129;

        if u5[Name] then
            v129 = u5[Name];
        else
            local v130 = Runes:FindFirstChild(Name .. "RuneConfig");

            if v130 then
                v129 = require(v130);
                u5[Name] = v129;
            else
                v129 = nil;
            end;
        end;

        if not v129 then
            return;
        end;

        local Hitbox = u128:FindFirstChild("Hitbox");

        if not (Hitbox and Hitbox:IsA("BasePart")) then
            warn("[RuneHandler] " .. u128:GetFullName() .. " has no Hitbox BasePart, skipping.");

            return;
        end;

        u126[Name] = Hitbox;
        u127[Name] = {};
        u109[Name] = u128:GetAttribute("UnlockedZone");
        u128:GetAttributeChangedSignal("UnlockedZone"):Connect(function() -- Line: 615
            -- upvalues: u109 (ref), Name (copy), u128 (copy)
            u109[Name] = u128:GetAttribute("UnlockedZone");
        end);
    end;

    local Runes2 = Workspace:WaitForChild("Runes");

    for _, child in ipairs(Runes2:GetChildren()) do
        setupZone(child);
    end;

    Runes2.ChildAdded:Connect(setupZone);
    task.spawn(function() -- Line: 626
        -- upvalues: getCharacterFilter (ref), u126 (copy), u5 (ref), Runes (ref), getOccupyingPlayers (ref), u127 (copy), startRolling (ref), u113 (ref), u114 (ref)
        while true do
            task.wait(0.25);
            local v131 = getCharacterFilter();

            for i, v in pairs(u126) do
                local v132;

                if u5[i] then
                    v132 = u5[i];
                else
                    local v133 = Runes:FindFirstChild(i .. "RuneConfig");

                    if v133 then
                        v132 = require(v133);
                        u5[i] = v132;
                    else
                        v132 = nil;
                    end;
                end;

                if v132 then
                    local v134 = getOccupyingPlayers(v, v131);
                    local v135 = u127[i];
                    local v136 = i;

                    for i2 in pairs(v134) do
                        if not v135[i2] then
                            v135[i2] = true;
                            startRolling(i2, v136, v132);
                        end;
                    end;

                    for i2 in pairs(v135) do
                        if not v134[i2] then
                            v135[i2] = nil;

                            if u113[v136] then
                                if u113[v136][i2] then
                                    u113[v136][i2] = nil;
                                    local v137 = u114[v136] and u114[v136][i2];

                                    if v137 then
                                        task.cancel(v137);
                                        u114[v136][i2] = nil;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end);
    Players.PlayerRemoving:Connect(function(p138) -- Line: 656
        -- upvalues: u127 (copy), u113 (ref), u114 (ref)
        for i in pairs(u127) do
            u127[i][p138] = nil;

            if u113[i] then
                if u113[i][p138] then
                    u113[i][p138] = nil;
                    local v139 = u114[i] and u114[i][p138];

                    if v139 then
                        task.cancel(v139);
                        u114[i][p138] = nil;
                    end;
                end;
            end;
        end;
    end);
end;

Requests.GetRuneData:OnInvoke(function(p140) -- Line: 664
    -- upvalues: DataHandler (copy), u4 (copy)
    local v141 = os.clock() + 15;

    while not DataHandler.GetProfile(p140) and os.clock() < v141 do
        task.wait(0.1);
    end;

    return {
        Runes = u4.GetData(p140)
    };
end);
Requests.GetRuneRollInfo:OnInvoke(function(p142) -- Line: 678
    -- upvalues: DataHandler (copy), u4 (copy)
    local v143 = os.clock() + 15;

    while not DataHandler.GetProfile(p142) and os.clock() < v143 do
        task.wait(0.1);
    end;

    return u4.GetRollInfo(p142);
end);

return u4;