-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Configs = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Configs");
local Handlers = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Handlers");
local SettingsConfig = require(Configs:WaitForChild("SettingsConfig"));
local DataHandler = require(Handlers:WaitForChild("DataHandler"));
local u1 = nil;

local function getEquipmentHandler() -- Line: 39
    -- upvalues: u1 (ref), Handlers (copy)
    if not u1 then
        u1 = require(Handlers:WaitForChild("EquipmentHandler"));
    end;

    return u1;
end;

local Packets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Packets"));
local Requests = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("Requests"));
local u2 = {};
local u3 = {};

function u2.OnChanged(p4) -- Line: 54
    -- upvalues: u3 (copy)
    table.insert(u3, p4);
end;

local function fireChanged(p5, p6, p7) -- Line: 58
    -- upvalues: u3 (copy)
    for _, v in ipairs(u3) do
        task.spawn(v, p5, p6, p7);
    end;
end;

local function isTextBox(p8) -- Line: 64
    -- upvalues: SettingsConfig (copy)
    local v9 = SettingsConfig[p8];
    local v10;

    if v9 == nil then
        v10 = false;
    else
        v10 = v9.Kind == "TextBox";
    end;

    return v10;
end;

function u2.GetSettings(p11) -- Line: 69
    -- upvalues: DataHandler (copy)
    local Profile = DataHandler.GetProfile(p11);

    if not (Profile and Profile.Data) then
        return nil;
    end;

    if type(Profile.Data.Settings) ~= "table" then
        Profile.Data.Settings = {};
    end;

    return Profile.Data.Settings;
end;

function u2.GetSetting(p12, p13) -- Line: 80
    -- upvalues: u2 (copy), SettingsConfig (copy)
    local Settings = u2.GetSettings(p12);

    if Settings and Settings[p13] ~= nil then
        return Settings[p13];
    end;

    local v14 = SettingsConfig[p13];

    return v14 == nil and true or v14.Default;
end;

function u2.GetNumberSettingMax(u15, p16) -- Line: 100
    -- upvalues: SettingsConfig (copy), u1 (ref), Handlers (copy)
    local v17 = SettingsConfig[p16];

    if not v17 then
        return 0;
    end;

    local v18 = v17.Max or 0;

    if p16 == "WalkSpeed" then
        local u19 = 0;
        pcall(function() -- Line: 110
            -- upvalues: u19 (ref), u1 (ref), Handlers (ref), u15 (copy)
            if not u1 then
                u1 = require(Handlers:WaitForChild("EquipmentHandler"));
            end;

            u19 = u1.GetFlatBonus(u15, "WalkSpeed");
        end);
        v18 = v18 + u19;
    end;

    return v18;
end;

function u2.ToggleSetting(p20, p21) -- Line: 119
    -- upvalues: SettingsConfig (copy), DataHandler (copy), fireChanged (copy)
    local v22 = SettingsConfig[p21];

    if v22 and v22.Kind == "TextBox" then
        return nil;
    end;

    local Profile = DataHandler.GetProfile(p20);

    if not (Profile and Profile.Data) then
        return nil;
    end;

    if type(Profile.Data.Settings) ~= "table" then
        Profile.Data.Settings = {};
    end;

    local v23 = Profile.Data.Settings[p21];
    local v24 = not (v23 == nil and (v22 == nil and true or (v22.Default or true)) or v23);
    Profile.Data.Settings[p21] = v24;
    fireChanged(p20, p21, v24);

    return v24;
end;

function u2.SetNumberSetting(p25, p26, p27) -- Line: 149
    -- upvalues: SettingsConfig (copy), DataHandler (copy), u2 (copy), fireChanged (copy)
    local v28 = SettingsConfig[p26];
    local v29;

    if v28 == nil then
        v29 = false;
    else
        v29 = v28.Kind == "TextBox";
    end;

    if not v29 then
        return nil;
    end;

    local Profile = DataHandler.GetProfile(p25);

    if not (Profile and Profile.Data) then
        return nil;
    end;

    if type(Profile.Data.Settings) ~= "table" then
        Profile.Data.Settings = {};
    end;

    local v30 = SettingsConfig[p26];
    local v31 = tonumber(Profile.Data.Settings[p26]) or (v30.Default or 0);
    local v32 = tonumber(p27);

    if not v32 or v32 ~= v32 then
        return v31;
    end;

    local v33 = v30.Min or 0;
    local NumberSettingMax = u2.GetNumberSettingMax(p25, p26);

    if NumberSettingMax < v33 then
        NumberSettingMax = v33;
    end;

    local math_clamp_ret = math.clamp(v32, v33, NumberSettingMax);
    Profile.Data.Settings[p26] = math_clamp_ret;
    fireChanged(p25, p26, math_clamp_ret);

    return math_clamp_ret;
end;

function u2.SetNumberSettingAndBroadcast(p34, p35, p36) -- Line: 189
    -- upvalues: u2 (copy), Packets (copy)
    local v37 = u2.SetNumberSetting(p34, p35, p36);

    if v37 ~= nil then
        Packets.NumberSettingChanged.sendTo({
            SettingId = p35,
            Value = v37
        }, p34);
    end;

    return v37;
end;

local function getFullSettingsSnapshot(p38) -- Line: 199
    -- upvalues: SettingsConfig (copy), u2 (copy)
    local v39 = {};
    local v40 = {};

    for i, v in pairs(SettingsConfig) do
        local Setting = u2.GetSetting(p38, i);

        if v.Kind == "TextBox" then
            v40[i] = tonumber(Setting) or (v.Default or 0);
        else
            v39[i] = Setting and true or false;
        end;
    end;

    return v39, v40;
end;

Requests.GetSettings:OnInvoke(function(p41) -- Line: 212
    -- upvalues: DataHandler (copy), getFullSettingsSnapshot (copy)
    local v42 = os.clock() + 15;

    while not DataHandler.GetProfile(p41) and os.clock() < v42 do
        task.wait(0.1);
    end;

    local v43, v44 = getFullSettingsSnapshot(p41);

    return {
        Settings = v43,
        NumberSettings = v44
    };
end);
Requests.ToggleSetting:OnInvoke(function(p45, p46) -- Line: 227
    -- upvalues: u2 (copy), Packets (copy)
    local v47 = u2.ToggleSetting(p45, p46.SettingId);

    if v47 == nil then
        return {
            Value = false
        };
    end;

    Packets.SettingToggled.sendTo({
        SettingId = p46.SettingId,
        NewValue = v47
    }, p45);

    return {
        Value = v47
    };
end);
Requests.SetNumberSetting:OnInvoke(function(p48, p49) -- Line: 237
    -- upvalues: u2 (copy)
    local v50 = u2.SetNumberSettingAndBroadcast(p48, p49.SettingId, p49.Value);

    return v50 == nil and {
        Value = 0
    } or {
        Value = v50
    };
end);

return u2;