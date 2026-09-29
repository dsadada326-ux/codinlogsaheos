-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local SoundService = game:GetService("SoundService");
local RunService = game:GetService("RunService");
local Players = game:GetService("Players");
local Workspace = game:GetService("Workspace");
local UserInputService = game:GetService("UserInputService");
local init = require(ReplicatedStorage.Shared.Packages.ripple.src.init);
local DataClient = require(script.Parent.DataClient);
local ClickConfig = require(ReplicatedStorage.Shared.Config.ClickConfig);
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig);
local MenuManager = require(ReplicatedStorage.Shared.Config.MenuManager);
local v1 = {};
local u2 = nil;
local u3 = nil;
local u4 = nil;
local u5 = nil;
local u6 = nil;
local u7 = nil;
local u8 = nil;
local u9 = nil;
local u10 = nil;
local u11 = nil;
local u12 = nil;
local u13 = nil;
local u14 = nil;
local u15 = nil;
local u16 = nil;
local u17 = nil;
local u18 = nil;
local u19 = nil;
local u20 = nil;
local u21 = nil;
local u22 = nil;
local u23 = nil;
local u24 = nil;
local u25 = nil;
local u26 = nil;
local u27 = nil;
local u28 = nil;
local u29 = 70;
local u30 = nil;
local u31 = nil;
local u32 = nil;
local u33 = nil;
local u34 = nil;
local u35 = nil;
local u36 = nil;
local u37 = nil;
local u38 = nil;
local u39 = nil;
local u40 = nil;
local u41 = {};
local u42 = {};
local u43 = nil;
local u44 = false;
local u45 = 0;
local u46 = 0;
local u47 = 0;
local u48 = 0;

local function playEffects() -- Line: 80
    -- upvalues: u19 (ref), u20 (ref), u18 (ref), SoundService (copy)
    if #u19 > 0 then
        local v49 = u19[math.random(1, #u19)];
        local v50 = v49:GetAttribute("EmitCount") or 10;
        v49:Emit((math.random(math.round(v50 / 2), (math.round(v50 * 2)))));
    end;

    if u20 then
        u20:Emit(1);
    end;

    if #u18 > 0 then
        SoundService:PlayLocalSound(u18[math.random(1, #u18)]);
    end;
end;

local function getRemotePressState(p51: userdata) -- Line: 98
    -- upvalues: u41 (copy), init (copy)
    local v52 = u41[p51];

    if v52 and (v52.button.Parent and v52.base.Parent) then
        return v52;
    end;

    local Button = p51:FindFirstChild("Button");
    local u53;

    if Button then
        u53 = Button:FindFirstChild("Button");
    else
        u53 = Button;
    end;

    local u54;

    if Button then
        u54 = Button:FindFirstChild("Base");
    else
        u54 = Button;
    end;

    if not (u53 and (u53:IsA("BasePart") and (u54 and u54:IsA("BasePart")))) then
        return nil;
    end;

    local Size = u53.Size;
    local Size2 = u54.Size;
    local CFrame2 = u54.CFrame;
    local u55 = CFrame2:ToObjectSpace(u53.CFrame);
    local v56 = init.createSpring(0, {
        dampingRatio = 0.3,
        frequency = 2
    });
    local v57 = {};
    local Emitattachment = Button:FindFirstChild("Emitattachment");
    local Emitattachment2 = Button:FindFirstChild("Emitattachment2");

    if Emitattachment2 then
        for _, v in ipairs({ "stars", "Stars2", "Specs", "lines", "Rays" }) do
            local v58 = Emitattachment2:FindFirstChild(v);

            if v58 and v58:IsA("ParticleEmitter") then
                table.insert(v57, v58);
            end;
        end;
    end;

    if Emitattachment then
        Emitattachment = Emitattachment:FindFirstChild("CirclePop");
    end;

    if Emitattachment and not Emitattachment:IsA("ParticleEmitter") then
        Emitattachment = nil;
    end;

    local v59 = {
        button = u53,
        base = u54,
        spring = v56,
        emitterPool = v57,
        circlePop = Emitattachment
    };
    u41[p51] = v59;
    v56:onChange(function(p60) -- Line: 136
        -- upvalues: u53 (copy), u54 (copy), Size (copy), CFrame2 (copy), u55 (copy), Size2 (copy)
        if not (u53.Parent and u54.Parent) then
            return;
        end;

        local math_max_ret = math.max(1 - p60 * 0.02, 0.2);
        local math_max_ret2 = math.max(1 + p60 * 0.015, 0.2);
        local v61 = Size.Y * math_max_ret;
        u53.Size = Vector3.new(Size.X * math_max_ret2, v61, Size.Z * math_max_ret2);
        u53.CFrame = CFrame2 * u55 * CFrame.new(0, (v61 - Size.Y) / 2 - p60 * 0.9, 0);
        u54.Size = Vector3.new(Size2.X * math_max_ret2, Size2.Y, Size2.Z * math_max_ret2);
    end);
    v56:start();

    return v59;
end;

local function animateRemotePress(p62, p63) -- Line: 150
    -- upvalues: Players (copy), Workspace (copy), getRemotePressState (copy)
    if type(p62) ~= "number" or p62 == Players.LocalPlayer.UserId then
        return;
    end;

    if typeof(p63) ~= "Instance" or not p63:IsDescendantOf(Workspace) then
        return;
    end;

    if p63:GetAttribute("OwnerUserId") ~= p62 then
        return;
    end;

    local v64 = getRemotePressState(p63);

    if not v64 then
        return;
    end;

    v64.spring:impulse(100);

    if #v64.emitterPool > 0 then
        local v65 = v64.emitterPool[math.random(1, #v64.emitterPool)];
        local v66 = v65:GetAttribute("EmitCount") or 10;
        v65:Emit(math.random(math.round(v66 / 2), (math.round(v66 * 2))));
    end;

    if v64.circlePop then
        v64.circlePop:Emit(1);
    end;
end;

local function updateCounterText(p67: number) -- Line: 166
    -- upvalues: u45 (ref), u10 (ref), u11 (ref)
    u45 = p67;
    local v68 = "x" .. p67;

    if u10 then
        u10.Text = v68;
    end;

    if u11 then
        u11.Text = v68;
    end;
end;

local function bindFovCamera() -- Line: 173
    -- upvalues: u28 (ref), Workspace (copy), u29 (ref), u27 (ref)
    u28 = Workspace.CurrentCamera;

    if u28 then
        u29 = u28.FieldOfView;
    end;

    if u27 then
        u27:setPosition(0);
        u27:setVelocity(0);
    end;
end;

local function pulseFov() -- Line: 182
end;

local function click(p69: boolean?, p70: boolean?) -- Line: 192
    -- upvalues: u44 (ref), ClickConfig (copy), Players (copy), u46 (ref), u25 (ref), u45 (ref), u10 (ref), u11 (ref), u26 (ref), playEffects (copy), u37 (ref), u38 (ref), u2 (ref)
    if not u44 then
        return;
    end;

    local os_clock_ret = os.clock();

    if (ClickConfig.getMinClickInterval(Players.LocalPlayer) or 0.16666666666666666) > os_clock_ret - u46 then
        return;
    end;

    u46 = os_clock_ret;

    if p69 == nil and true or p69 then
        u25:impulse(100);
        local v71 = u45 + 1;
        u45 = v71;
        local v72 = "x" .. v71;

        if u10 then
            u10.Text = v72;
        end;

        if u11 then
            u11.Text = v72;
        end;

        u26:impulse(100);
        playEffects();
    end;

    if u37 then
        u37:Fire();
    end;

    if u38 and u2 then
        u38:FireServer(u2);
    end;
end;

local function onManualClick() -- Line: 229
    -- upvalues: MenuManager (copy), u47 (ref), click (copy)
    if MenuManager.getCurrent() ~= nil then
        return;
    end;

    u47 = os.clock();
    click(true, true);
end;

local function isFastAutoActive() -- Line: 237
    -- upvalues: Players (copy), Workspace (copy)
    local v73 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));
    local v74;

    if v73 == nil then
        v74 = false;
    else
        v74 = Workspace:GetServerTimeNow() < v73;
    end;

    return v74;
end;

local function autoClickerLevel() -- Line: 242
    -- upvalues: u36 (ref)
    if not u36 then
        return 0;
    end;

    local v75 = u36.Upgrades() or {};
    local v76 = tonumber(v75.AutoClicker) or 0;
    local math_floor_ret = math.floor(v76);

    return math.max(0, math_floor_ret);
end;

local function isAutoToggleEnabled() -- Line: 248
    -- upvalues: u36 (ref)
    if not u36 then
        return true;
    end;

    local AutoClickerEnabled = u36.AutoClickerEnabled;

    return AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
end;

local function isNormalAutoActive() -- Line: 254
    -- upvalues: u36 (ref)
    local v77 = false;
    local v78;

    if u36 then
        local v79 = u36.Upgrades() or {};
        local v80 = tonumber(v79.AutoClicker) or 0;
        local math_floor_ret = math.floor(v80);
        v78 = math.max(0, math_floor_ret);
    else
        v78 = 0;
    end;

    if v78 > 0 then
        if not u36 then
            return true;
        end;

        local AutoClickerEnabled = u36.AutoClickerEnabled;
        v77 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
    end;

    return v77;
end;

local function isAutoclickerEnabled() -- Line: 258
    -- upvalues: u36 (ref), Players (copy), Workspace (copy)
    local v81 = false;
    local v82;

    if u36 then
        local v83 = u36.Upgrades() or {};
        local v84 = tonumber(v83.AutoClicker) or 0;
        local math_floor_ret = math.floor(v84);
        v82 = math.max(0, math_floor_ret);
    else
        v82 = 0;
    end;

    if v82 > 0 then
        if u36 then
            local AutoClickerEnabled = u36.AutoClickerEnabled;
            v81 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
        else
            v81 = true;
        end;
    end;

    if not v81 then
        local v85 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

        if v85 == nil then
            v81 = false;
        else
            v81 = Workspace:GetServerTimeNow() < v85;
        end;
    end;

    return v81;
end;

local function currentAutoInterval() -- Line: 264
    -- upvalues: Players (copy), Workspace (copy), u36 (ref), ClickConfig (copy), UpgradeConfig (copy)
    local v86 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));
    local v87;

    if v86 == nil then
        v87 = false;
    else
        v87 = Workspace:GetServerTimeNow() < v86;
    end;

    if v87 then
        return 0.08333333333333333;
    end;

    local v88;

    if u36 then
        local v89 = u36.Upgrades() or {};
        local v90 = tonumber(v89.AutoClicker) or 0;
        local math_floor_ret = math.floor(v90);
        v88 = math.max(0, math_floor_ret);
    else
        v88 = 0;
    end;

    if v88 <= 0 then
        return 2;
    end;

    local MinClickInterval = ClickConfig.getMinClickInterval(Players.LocalPlayer);

    return math.max(MinClickInterval, UpgradeConfig.getDisplayValue("AutoClicker", v88));
end;

local u91 = false;

local function ensureAutoclickerLoop() -- Line: 275
    -- upvalues: u91 (ref), u36 (ref), Players (copy), Workspace (copy), u32 (ref), u47 (ref), u48 (ref), ClickConfig (copy), UpgradeConfig (copy), click (copy), u33 (ref)
    if u91 then
        return;
    end;

    u91 = true;
    task.spawn(function() -- Line: 278
        -- upvalues: u36 (ref), Players (ref), Workspace (ref), u32 (ref), u47 (ref), u48 (ref), ClickConfig (ref), UpgradeConfig (ref), click (ref), u91 (ref), u33 (ref)
        while true do
            local v92 = false;
            local v93;

            if u36 then
                local v94 = u36.Upgrades() or {};
                local v95 = tonumber(v94.AutoClicker) or 0;
                local math_floor_ret = math.floor(v95);
                v93 = math.max(0, math_floor_ret);
            else
                v93 = 0;
            end;

            if v93 > 0 then
                if u36 then
                    local AutoClickerEnabled = u36.AutoClickerEnabled;
                    v92 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
                else
                    v92 = true;
                end;
            end;

            if not v92 then
                local v96 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                if v96 == nil then
                    v92 = false;
                else
                    v92 = Workspace:GetServerTimeNow() < v96;
                end;
            end;

            if not v92 then
                u91 = false;

                if u32 then
                    u32.Visible = false;
                end;

                if u33 then
                    u33.Rotation = 20;
                end;

                return;
            end;

            local v97 = false;
            local v98;

            if u36 then
                local v99 = u36.Upgrades() or {};
                local v100 = tonumber(v99.AutoClicker) or 0;
                local math_floor_ret = math.floor(v100);
                v98 = math.max(0, math_floor_ret);
            else
                v98 = 0;
            end;

            if v98 > 0 then
                if u36 then
                    local AutoClickerEnabled = u36.AutoClickerEnabled;
                    v97 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
                else
                    v97 = true;
                end;
            end;

            if not v97 then
                local v101 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                if v101 == nil then
                    v97 = false;
                else
                    v97 = Workspace:GetServerTimeNow() < v101;
                end;
            end;

            if u32 then
                u32.Visible = v97;
            end;

            local os_clock_ret = os.clock();
            local v102 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));
            local v103;

            if v102 == nil then
                v103 = false;
            else
                v103 = Workspace:GetServerTimeNow() < v102;
            end;

            local v104;

            if v103 then
                v104 = 0.08333333333333333;
            else
                local v105;

                if u36 then
                    local v106 = u36.Upgrades() or {};
                    local v107 = tonumber(v106.AutoClicker) or 0;
                    local math_floor_ret = math.floor(v107);
                    v105 = math.max(0, math_floor_ret);
                else
                    v105 = 0;
                end;

                if v105 <= 0 then
                    v104 = 2;
                else
                    local MinClickInterval = ClickConfig.getMinClickInterval(Players.LocalPlayer);
                    v104 = math.max(MinClickInterval, UpgradeConfig.getDisplayValue("AutoClicker", v105));
                end;
            end;

            if os_clock_ret - u47 >= 1 and v104 <= os_clock_ret - u48 then
                u48 = os_clock_ret;
                click(true);
            end;

            task.wait(0.1);
        end;
    end);
end;

local function applyClickerState() -- Line: 298
    -- upvalues: u36 (ref), Players (copy), Workspace (copy), u32 (ref), u91 (ref), u47 (ref), u48 (ref), ClickConfig (copy), UpgradeConfig (copy), click (copy), u33 (ref)
    local v108 = false;
    local v109;

    if u36 then
        local v110 = u36.Upgrades() or {};
        local v111 = tonumber(v110.AutoClicker) or 0;
        local math_floor_ret = math.floor(v111);
        v109 = math.max(0, math_floor_ret);
    else
        v109 = 0;
    end;

    if v109 > 0 then
        if u36 then
            local AutoClickerEnabled = u36.AutoClickerEnabled;
            v108 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
        else
            v108 = true;
        end;
    end;

    if not v108 then
        local v112 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

        if v112 == nil then
            v108 = false;
        else
            v108 = Workspace:GetServerTimeNow() < v112;
        end;
    end;

    if not v108 then
        if u32 then
            u32.Visible = false;
        end;

        if u33 then
            u33.Rotation = 20;
        end;

        return;
    end;

    if u32 then
        u32.Visible = true;
    end;

    if u91 then
        return;
    end;

    u91 = true;
    task.spawn(function() -- Line: 278
        -- upvalues: u36 (ref), Players (ref), Workspace (ref), u32 (ref), u47 (ref), u48 (ref), ClickConfig (ref), UpgradeConfig (ref), click (ref), u91 (ref), u33 (ref)
        while true do
            local v113 = false;
            local v114;

            if u36 then
                local v115 = u36.Upgrades() or {};
                local v116 = tonumber(v115.AutoClicker) or 0;
                local math_floor_ret = math.floor(v116);
                v114 = math.max(0, math_floor_ret);
            else
                v114 = 0;
            end;

            if v114 > 0 then
                if u36 then
                    local AutoClickerEnabled = u36.AutoClickerEnabled;
                    v113 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
                else
                    v113 = true;
                end;
            end;

            if not v113 then
                local v117 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                if v117 == nil then
                    v113 = false;
                else
                    v113 = Workspace:GetServerTimeNow() < v117;
                end;
            end;

            if not v113 then
                u91 = false;

                if u32 then
                    u32.Visible = false;
                end;

                if u33 then
                    u33.Rotation = 20;
                end;

                return;
            end;

            local v118 = false;
            local v119;

            if u36 then
                local v120 = u36.Upgrades() or {};
                local v121 = tonumber(v120.AutoClicker) or 0;
                local math_floor_ret = math.floor(v121);
                v119 = math.max(0, math_floor_ret);
            else
                v119 = 0;
            end;

            if v119 > 0 then
                if u36 then
                    local AutoClickerEnabled = u36.AutoClickerEnabled;
                    v118 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
                else
                    v118 = true;
                end;
            end;

            if not v118 then
                local v122 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                if v122 == nil then
                    v118 = false;
                else
                    v118 = Workspace:GetServerTimeNow() < v122;
                end;
            end;

            if u32 then
                u32.Visible = v118;
            end;

            local os_clock_ret = os.clock();
            local v123 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));
            local v124;

            if v123 == nil then
                v124 = false;
            else
                v124 = Workspace:GetServerTimeNow() < v123;
            end;

            local v125;

            if v124 then
                v125 = 0.08333333333333333;
            else
                local v126;

                if u36 then
                    local v127 = u36.Upgrades() or {};
                    local v128 = tonumber(v127.AutoClicker) or 0;
                    local math_floor_ret = math.floor(v128);
                    v126 = math.max(0, math_floor_ret);
                else
                    v126 = 0;
                end;

                if v126 <= 0 then
                    v125 = 2;
                else
                    local MinClickInterval = ClickConfig.getMinClickInterval(Players.LocalPlayer);
                    v125 = math.max(MinClickInterval, UpgradeConfig.getDisplayValue("AutoClicker", v126));
                end;
            end;

            if os_clock_ret - u47 >= 1 and v125 <= os_clock_ret - u48 then
                u48 = os_clock_ret;
                click(true);
            end;

            task.wait(0.1);
        end;
    end);
end;

local function waitForAssignedPlot() -- Line: 308
    -- upvalues: Players (copy)
    local LocalPlayer = Players.LocalPlayer;
    local NewMap = workspace:WaitForChild("NewMap", 30);

    if not NewMap then
        return nil;
    end;

    local v129 = os.clock() + 30;

    while os.clock() < v129 do
        local v130 = tonumber(LocalPlayer:GetAttribute("PlotId"));

        if v130 then
            v130 = NewMap:FindFirstChild("Plot" .. v130);
        end;

        if v130 and v130:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return v130;
        end;

        task.wait(0.1);
    end;

    return nil;
end;

local function getPlotCounterLabels(p131: userdata) -- Line: 324
    local Button = p131:FindFirstChild("Button");

    if Button then
        Button = Button:FindFirstChild("Counter");
    end;

    if Button then
        Button = Button:FindFirstChild("SurfaceGui");
    end;

    if Button then
        Button = Button:FindFirstChild("Frame");
    end;

    local v132;

    if Button then
        v132 = Button:FindFirstChild("TextLabel");
    else
        v132 = Button;
    end;

    if Button then
        Button = Button:FindFirstChild("DropShadow");
    end;

    if not (v132 and v132:IsA("TextLabel")) then
        v132 = nil;
    end;

    if Button and Button:IsA("TextLabel") then
        return v132, Button;
    end;

    return v132, nil;
end;

local function bindPlotCounter(u133: userdata) -- Line: 336
    -- upvalues: u42 (copy), getPlotCounterLabels (copy)
    if u42[u133] then
        return;
    end;

    local function update() -- Line: 341
        -- upvalues: u133 (copy), getPlotCounterLabels (ref)
        if not u133.Parent then
            return;
        end;

        local v134, v135 = getPlotCounterLabels(u133);
        local v136 = tonumber(u133:GetAttribute("ButtonClicks")) or 0;
        local math_floor_ret = math.floor(v136);
        local v137 = "x" .. math.max(0, math_floor_ret);

        if v134 then
            v134.Text = v137;
        end;

        if v135 then
            v135.Text = v137;
        end;
    end;

    u42[u133] = { u133:GetAttributeChangedSignal("ButtonClicks"):Connect(update), u133.DescendantAdded:Connect(function(p138) -- Line: 352
            -- upvalues: update (copy)
            if p138.Name == "Counter" or (p138.Name == "SurfaceGui" or (p138.Name == "Frame" or (p138.Name == "TextLabel" or p138.Name == "DropShadow"))) then
                task.defer(update);
            end;
        end) };

    if not u133.Parent then
        return;
    end;

    local v139, v140 = getPlotCounterLabels(u133);
    local v141 = tonumber(u133:GetAttribute("ButtonClicks")) or 0;
    local math_floor_ret = math.floor(v141);
    local v142 = "x" .. math.max(0, math_floor_ret);

    if v139 then
        v139.Text = v142;
    end;

    if v140 then
        v140.Text = v142;
    end;
end;

local function bindSpectatorCounters(p143: userdata) -- Line: 364
    -- upvalues: bindPlotCounter (copy), u43 (ref)
    for _, child in ipairs(p143:GetChildren()) do
        bindPlotCounter(child);
    end;

    if u43 then
        u43:Disconnect();
    end;

    u43 = p143.ChildAdded:Connect(function(p144) -- Line: 369
        -- upvalues: bindPlotCounter (ref)
        task.defer(bindPlotCounter, p144);
    end);
end;

local function setupButton() -- Line: 376
    -- upvalues: u2 (ref), waitForAssignedPlot (copy), u3 (ref), u4 (ref), u5 (ref), u6 (ref), u7 (ref), u8 (ref), u9 (ref), u10 (ref), u11 (ref), u12 (ref), u13 (ref), u36 (ref), DataClient (copy), u45 (ref), u34 (ref), u44 (ref), Players (copy), Workspace (copy), u32 (ref), u91 (ref), u47 (ref), u48 (ref), ClickConfig (copy), UpgradeConfig (copy), click (copy), u33 (ref), u35 (ref), u17 (ref), u14 (ref), u15 (ref), u16 (ref), ReplicatedStorage (copy), u18 (ref), u19 (ref), u20 (ref), u31 (ref), u21 (ref), u22 (ref), u23 (ref), u24 (ref), u25 (ref), u26 (ref), onManualClick (copy), UserInputService (copy), MenuManager (copy), RunService (copy), applyClickerState (copy)
    u2 = waitForAssignedPlot();

    if not u2 then
        warn("[ButtonController] plot assignment never replicated - button disabled");

        return;
    end;

    u3 = u2:WaitForChild("Button", 30);

    if not u3 then
        warn("[ButtonController] assigned plot has no Button model - button disabled");

        return;
    end;

    u4 = u3:WaitForChild("Button", 10);
    u5 = u3:WaitForChild("Base", 10);
    u6 = u3:WaitForChild("Hitbox", 10);
    u7 = u3:WaitForChild("Emitattachment", 10);
    u8 = u3:WaitForChild("Emitattachment2", 10);

    if not (u4 and (u5 and (u6 and (u7 and u8)))) then
        warn("[ButtonController] Button model missing expected children - button disabled");

        return;
    end;

    u9 = u3:WaitForChild("Counter", 10);
    local v145 = u9 and u9:WaitForChild("SurfaceGui", 10);

    if v145 then
        v145 = v145:WaitForChild("Frame", 10);
    end;

    if not v145 then
        warn("[ButtonController] Counter GUI missing - button disabled");

        return;
    end;

    u10 = v145:WaitForChild("TextLabel", 10);
    u11 = v145:WaitForChild("DropShadow", 10);
    u12 = v145:WaitForChild("UIScale", 10);
    u13 = u12.Scale;
    local v146 = tonumber(u2:GetAttribute("ButtonClicks")) or 0;
    local math_floor_ret = math.floor(v146);
    local math_max_ret = math.max(0, math_floor_ret);
    u10.Text = "x" .. math_max_ret;
    u11.Text = "x" .. math_max_ret;
    task.spawn(function() -- Line: 415
        -- upvalues: u36 (ref), DataClient (ref), u45 (ref), u10 (ref), u11 (ref), u34 (ref), u44 (ref), Players (ref), Workspace (ref), u32 (ref), u91 (ref), u47 (ref), u48 (ref), ClickConfig (ref), UpgradeConfig (ref), click (ref), u33 (ref), u35 (ref)
        u36 = DataClient.get();

        if not u36 then
            return;
        end;

        local v147 = u36.TotalClicks() or 0;
        u45 = v147;
        local v148 = "x" .. v147;

        if u10 then
            u10.Text = v148;
        end;

        if u11 then
            u11.Text = v148;
        end;

        u36.TotalClicks.Changed(function(p149: number) -- Line: 420
            -- upvalues: u45 (ref), u10 (ref), u11 (ref)
            local v150 = p149 or 0;
            u45 = v150;
            local v151 = "x" .. v150;

            if u10 then
                u10.Text = v151;
            end;

            if u11 then
                u11.Text = v151;
            end;
        end);
        local AutoClicker = u36.Upgrades.AutoClicker;

        if AutoClicker then
            if u34 then
                u34:Disconnect();
            end;

            u34 = AutoClicker.Changed(function() -- Line: 426
                -- upvalues: u44 (ref), u36 (ref), Players (ref), Workspace (ref), u32 (ref), u91 (ref), u47 (ref), u48 (ref), ClickConfig (ref), UpgradeConfig (ref), click (ref), u33 (ref)
                if u44 then
                    local v152 = false;
                    local v153;

                    if u36 then
                        local v154 = u36.Upgrades() or {};
                        local v155 = tonumber(v154.AutoClicker) or 0;
                        local math_floor_ret2 = math.floor(v155);
                        v153 = math.max(0, math_floor_ret2);
                    else
                        v153 = 0;
                    end;

                    if v153 > 0 then
                        if u36 then
                            local AutoClickerEnabled = u36.AutoClickerEnabled;
                            v152 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
                        else
                            v152 = true;
                        end;
                    end;

                    if not v152 then
                        local v156 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                        if v156 == nil then
                            v152 = false;
                        else
                            v152 = Workspace:GetServerTimeNow() < v156;
                        end;
                    end;

                    if v152 then
                        if u32 then
                            u32.Visible = true;
                        end;

                        if u91 then
                            return;
                        end;

                        u91 = true;
                        task.spawn(function() -- Line: 278
                            -- upvalues: u36 (ref), Players (ref), Workspace (ref), u32 (ref), u47 (ref), u48 (ref), ClickConfig (ref), UpgradeConfig (ref), click (ref), u91 (ref), u33 (ref)
                            while true do
                                local v157 = false;
                                local v158;

                                if u36 then
                                    local v159 = u36.Upgrades() or {};
                                    local v160 = tonumber(v159.AutoClicker) or 0;
                                    local math_floor_ret2 = math.floor(v160);
                                    v158 = math.max(0, math_floor_ret2);
                                else
                                    v158 = 0;
                                end;

                                if v158 > 0 then
                                    if u36 then
                                        local AutoClickerEnabled = u36.AutoClickerEnabled;
                                        v157 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
                                    else
                                        v157 = true;
                                    end;
                                end;

                                if not v157 then
                                    local v161 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                                    if v161 == nil then
                                        v157 = false;
                                    else
                                        v157 = Workspace:GetServerTimeNow() < v161;
                                    end;
                                end;

                                if not v157 then
                                    u91 = false;

                                    if u32 then
                                        u32.Visible = false;
                                    end;

                                    if u33 then
                                        u33.Rotation = 20;
                                    end;

                                    return;
                                end;

                                local v162 = false;
                                local v163;

                                if u36 then
                                    local v164 = u36.Upgrades() or {};
                                    local v165 = tonumber(v164.AutoClicker) or 0;
                                    local math_floor_ret2 = math.floor(v165);
                                    v163 = math.max(0, math_floor_ret2);
                                else
                                    v163 = 0;
                                end;

                                if v163 > 0 then
                                    if u36 then
                                        local AutoClickerEnabled = u36.AutoClickerEnabled;
                                        v162 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
                                    else
                                        v162 = true;
                                    end;
                                end;

                                if not v162 then
                                    local v166 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                                    if v166 == nil then
                                        v162 = false;
                                    else
                                        v162 = Workspace:GetServerTimeNow() < v166;
                                    end;
                                end;

                                if u32 then
                                    u32.Visible = v162;
                                end;

                                local os_clock_ret = os.clock();
                                local v167 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));
                                local v168;

                                if v167 == nil then
                                    v168 = false;
                                else
                                    v168 = Workspace:GetServerTimeNow() < v167;
                                end;

                                local v169;

                                if v168 then
                                    v169 = 0.08333333333333333;
                                else
                                    local v170;

                                    if u36 then
                                        local v171 = u36.Upgrades() or {};
                                        local v172 = tonumber(v171.AutoClicker) or 0;
                                        local math_floor_ret2 = math.floor(v172);
                                        v170 = math.max(0, math_floor_ret2);
                                    else
                                        v170 = 0;
                                    end;

                                    if v170 <= 0 then
                                        v169 = 2;
                                    else
                                        local MinClickInterval = ClickConfig.getMinClickInterval(Players.LocalPlayer);
                                        v169 = math.max(MinClickInterval, UpgradeConfig.getDisplayValue("AutoClicker", v170));
                                    end;
                                end;

                                if os_clock_ret - u47 >= 1 and v169 <= os_clock_ret - u48 then
                                    u48 = os_clock_ret;
                                    click(true);
                                end;

                                task.wait(0.1);
                            end;
                        end);

                        return;
                    end;

                    if u32 then
                        u32.Visible = false;
                    end;

                    if u33 then
                        u33.Rotation = 20;
                    end;
                end;
            end);
        end;

        local AutoClickerEnabled = u36.AutoClickerEnabled;

        if AutoClickerEnabled then
            if u35 then
                u35:Disconnect();
            end;

            u35 = AutoClickerEnabled.Changed(function() -- Line: 433
                -- upvalues: u44 (ref), u36 (ref), Players (ref), Workspace (ref), u32 (ref), u91 (ref), u47 (ref), u48 (ref), ClickConfig (ref), UpgradeConfig (ref), click (ref), u33 (ref)
                if u44 then
                    local v173 = false;
                    local v174;

                    if u36 then
                        local v175 = u36.Upgrades() or {};
                        local v176 = tonumber(v175.AutoClicker) or 0;
                        local math_floor_ret2 = math.floor(v176);
                        v174 = math.max(0, math_floor_ret2);
                    else
                        v174 = 0;
                    end;

                    if v174 > 0 then
                        if u36 then
                            local AutoClickerEnabled2 = u36.AutoClickerEnabled;
                            v173 = AutoClickerEnabled2 == nil and true or AutoClickerEnabled2() ~= false;
                        else
                            v173 = true;
                        end;
                    end;

                    if not v173 then
                        local v177 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                        if v177 == nil then
                            v173 = false;
                        else
                            v173 = Workspace:GetServerTimeNow() < v177;
                        end;
                    end;

                    if v173 then
                        if u32 then
                            u32.Visible = true;
                        end;

                        if u91 then
                            return;
                        end;

                        u91 = true;
                        task.spawn(function() -- Line: 278
                            -- upvalues: u36 (ref), Players (ref), Workspace (ref), u32 (ref), u47 (ref), u48 (ref), ClickConfig (ref), UpgradeConfig (ref), click (ref), u91 (ref), u33 (ref)
                            while true do
                                local v178 = false;
                                local v179;

                                if u36 then
                                    local v180 = u36.Upgrades() or {};
                                    local v181 = tonumber(v180.AutoClicker) or 0;
                                    local math_floor_ret2 = math.floor(v181);
                                    v179 = math.max(0, math_floor_ret2);
                                else
                                    v179 = 0;
                                end;

                                if v179 > 0 then
                                    if u36 then
                                        local AutoClickerEnabled2 = u36.AutoClickerEnabled;
                                        v178 = AutoClickerEnabled2 == nil and true or AutoClickerEnabled2() ~= false;
                                    else
                                        v178 = true;
                                    end;
                                end;

                                if not v178 then
                                    local v182 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                                    if v182 == nil then
                                        v178 = false;
                                    else
                                        v178 = Workspace:GetServerTimeNow() < v182;
                                    end;
                                end;

                                if not v178 then
                                    u91 = false;

                                    if u32 then
                                        u32.Visible = false;
                                    end;

                                    if u33 then
                                        u33.Rotation = 20;
                                    end;

                                    return;
                                end;

                                local v183 = false;
                                local v184;

                                if u36 then
                                    local v185 = u36.Upgrades() or {};
                                    local v186 = tonumber(v185.AutoClicker) or 0;
                                    local math_floor_ret2 = math.floor(v186);
                                    v184 = math.max(0, math_floor_ret2);
                                else
                                    v184 = 0;
                                end;

                                if v184 > 0 then
                                    if u36 then
                                        local AutoClickerEnabled2 = u36.AutoClickerEnabled;
                                        v183 = AutoClickerEnabled2 == nil and true or AutoClickerEnabled2() ~= false;
                                    else
                                        v183 = true;
                                    end;
                                end;

                                if not v183 then
                                    local v187 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                                    if v187 == nil then
                                        v183 = false;
                                    else
                                        v183 = Workspace:GetServerTimeNow() < v187;
                                    end;
                                end;

                                if u32 then
                                    u32.Visible = v183;
                                end;

                                local os_clock_ret = os.clock();
                                local v188 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));
                                local v189;

                                if v188 == nil then
                                    v189 = false;
                                else
                                    v189 = Workspace:GetServerTimeNow() < v188;
                                end;

                                local v190;

                                if v189 then
                                    v190 = 0.08333333333333333;
                                else
                                    local v191;

                                    if u36 then
                                        local v192 = u36.Upgrades() or {};
                                        local v193 = tonumber(v192.AutoClicker) or 0;
                                        local math_floor_ret2 = math.floor(v193);
                                        v191 = math.max(0, math_floor_ret2);
                                    else
                                        v191 = 0;
                                    end;

                                    if v191 <= 0 then
                                        v190 = 2;
                                    else
                                        local MinClickInterval = ClickConfig.getMinClickInterval(Players.LocalPlayer);
                                        v190 = math.max(MinClickInterval, UpgradeConfig.getDisplayValue("AutoClicker", v191));
                                    end;
                                end;

                                if os_clock_ret - u47 >= 1 and v190 <= os_clock_ret - u48 then
                                    u48 = os_clock_ret;
                                    click(true);
                                end;

                                task.wait(0.1);
                            end;
                        end);

                        return;
                    end;

                    if u32 then
                        u32.Visible = false;
                    end;

                    if u33 then
                        u33.Rotation = 20;
                    end;
                end;
            end);
        end;

        if u44 then
            local v194 = false;
            local v195;

            if u36 then
                local v196 = u36.Upgrades() or {};
                local v197 = tonumber(v196.AutoClicker) or 0;
                local math_floor_ret2 = math.floor(v197);
                v195 = math.max(0, math_floor_ret2);
            else
                v195 = 0;
            end;

            if v195 > 0 then
                if u36 then
                    local AutoClickerEnabled2 = u36.AutoClickerEnabled;
                    v194 = AutoClickerEnabled2 == nil and true or AutoClickerEnabled2() ~= false;
                else
                    v194 = true;
                end;
            end;

            if not v194 then
                local v198 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                if v198 == nil then
                    v194 = false;
                else
                    v194 = Workspace:GetServerTimeNow() < v198;
                end;
            end;

            if v194 then
                if u32 then
                    u32.Visible = true;
                end;

                if u91 then
                    return;
                end;

                u91 = true;
                task.spawn(function() -- Line: 278
                    -- upvalues: u36 (ref), Players (ref), Workspace (ref), u32 (ref), u47 (ref), u48 (ref), ClickConfig (ref), UpgradeConfig (ref), click (ref), u91 (ref), u33 (ref)
                    while true do
                        local v199 = false;
                        local v200;

                        if u36 then
                            local v201 = u36.Upgrades() or {};
                            local v202 = tonumber(v201.AutoClicker) or 0;
                            local math_floor_ret2 = math.floor(v202);
                            v200 = math.max(0, math_floor_ret2);
                        else
                            v200 = 0;
                        end;

                        if v200 > 0 then
                            if u36 then
                                local AutoClickerEnabled2 = u36.AutoClickerEnabled;
                                v199 = AutoClickerEnabled2 == nil and true or AutoClickerEnabled2() ~= false;
                            else
                                v199 = true;
                            end;
                        end;

                        if not v199 then
                            local v203 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                            if v203 == nil then
                                v199 = false;
                            else
                                v199 = Workspace:GetServerTimeNow() < v203;
                            end;
                        end;

                        if not v199 then
                            u91 = false;

                            if u32 then
                                u32.Visible = false;
                            end;

                            if u33 then
                                u33.Rotation = 20;
                            end;

                            return;
                        end;

                        local v204 = false;
                        local v205;

                        if u36 then
                            local v206 = u36.Upgrades() or {};
                            local v207 = tonumber(v206.AutoClicker) or 0;
                            local math_floor_ret2 = math.floor(v207);
                            v205 = math.max(0, math_floor_ret2);
                        else
                            v205 = 0;
                        end;

                        if v205 > 0 then
                            if u36 then
                                local AutoClickerEnabled2 = u36.AutoClickerEnabled;
                                v204 = AutoClickerEnabled2 == nil and true or AutoClickerEnabled2() ~= false;
                            else
                                v204 = true;
                            end;
                        end;

                        if not v204 then
                            local v208 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                            if v208 == nil then
                                v204 = false;
                            else
                                v204 = Workspace:GetServerTimeNow() < v208;
                            end;
                        end;

                        if u32 then
                            u32.Visible = v204;
                        end;

                        local os_clock_ret = os.clock();
                        local v209 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));
                        local v210;

                        if v209 == nil then
                            v210 = false;
                        else
                            v210 = Workspace:GetServerTimeNow() < v209;
                        end;

                        local v211;

                        if v210 then
                            v211 = 0.08333333333333333;
                        else
                            local v212;

                            if u36 then
                                local v213 = u36.Upgrades() or {};
                                local v214 = tonumber(v213.AutoClicker) or 0;
                                local math_floor_ret2 = math.floor(v214);
                                v212 = math.max(0, math_floor_ret2);
                            else
                                v212 = 0;
                            end;

                            if v212 <= 0 then
                                v211 = 2;
                            else
                                local MinClickInterval = ClickConfig.getMinClickInterval(Players.LocalPlayer);
                                v211 = math.max(MinClickInterval, UpgradeConfig.getDisplayValue("AutoClicker", v212));
                            end;
                        end;

                        if os_clock_ret - u47 >= 1 and v211 <= os_clock_ret - u48 then
                            u48 = os_clock_ret;
                            click(true);
                        end;

                        task.wait(0.1);
                    end;
                end);

                return;
            end;

            if u32 then
                u32.Visible = false;
            end;

            if u33 then
                u33.Rotation = 20;
            end;
        end;
    end);
    local Position = u4.Position;
    u17 = Position;
    local v215 = u9.Position - Position;
    u14 = Vector3.new(v215.X, 0, v215.Z).Magnitude;
    u15 = u9.Position.Y;
    local Vector3_new_ret = Vector3.new(v215.X, 0, v215.Z);
    u16 = CFrame.lookAt(u9.Position, u9.Position + (Vector3_new_ret.Magnitude < 0.01 and Vector3.new(0, 0, 1) or Vector3_new_ret).Unit):ToObjectSpace(u9.CFrame);
    u18 = {};

    for _, child in ipairs(ReplicatedStorage.Shared.Sounds:GetChildren()) do
        if child:IsA("Sound") then
            table.insert(u18, child);
        end;
    end;

    u19 = {};

    for _, v in ipairs({ "stars", "Stars2", "Specs", "lines", "Rays" }) do
        local v216 = u8:FindFirstChild(v);

        if v216 then
            table.insert(u19, v216);
        end;
    end;

    u20 = u7:FindFirstChild("CirclePop");
    u31 = u4:FindFirstChild("AutoclickHand");

    if u31 then
        local Billboard = u31:FindFirstChild("Billboard");

        if Billboard then
            Billboard = Billboard:FindFirstChild("CounterRow");
        end;

        u32 = Billboard;

        if Billboard then
            Billboard = Billboard:FindFirstChild("HandIcon");
        end;

        u33 = Billboard;

        if u33 then
            u33.Rotation = 20;
        end;

        if u32 then
            u32.Visible = false;
        end;
    end;

    u21 = u4.Size;
    u22 = u5.Size;
    u23 = u5.CFrame:ToObjectSpace(u4.CFrame);
    u24 = u5.CFrame;
    u25:onChange(function(p217) -- Line: 490
        -- upvalues: u44 (ref), u21 (ref), u4 (ref), u24 (ref), u23 (ref), u5 (ref), u22 (ref), u33 (ref)
        if not u44 then
            return;
        end;

        local math_max_ret2 = math.max(1 - p217 * 0.02, 0.2);
        local math_max_ret3 = math.max(1 + p217 * 0.015, 0.2);
        local v218 = u21.Y * math_max_ret2;
        u4.Size = Vector3.new(u21.X * math_max_ret3, v218, u21.Z * math_max_ret3);
        u4.CFrame = u24 * u23 * CFrame.new(0, (v218 - u21.Y) / 2 - p217 * 0.9, 0);
        u5.Size = Vector3.new(u22.X * math_max_ret3, u22.Y, u22.Z * math_max_ret3);

        if u33 then
            u33.Rotation = math.clamp(p217 / 5.3, 0, 1) * -20 + 20;
        end;
    end);
    u26:onChange(function(p219) -- Line: 507
        -- upvalues: u44 (ref), u12 (ref), u13 (ref)
        if not u44 then
            return;
        end;

        u12.Scale = u13 * (1 + p219 / 5.3 * 0.3);
    end);
    local ClickDetector = Instance.new("ClickDetector");
    ClickDetector.MaxActivationDistance = 64;
    ClickDetector.Parent = u6;
    ClickDetector.MouseClick:Connect(onManualClick);

    if UserInputService.TouchEnabled then
        UserInputService.TouchTapInWorld:Connect(function(p220, p221: boolean) -- Line: 525
            -- upvalues: u44 (ref), Workspace (ref), u3 (ref), ClickDetector (copy), MenuManager (ref), u47 (ref), click (ref)
            if not u44 then
                return;
            end;

            if p221 then
                return;
            end;

            local CurrentCamera = Workspace.CurrentCamera;

            if not CurrentCamera then
                return;
            end;

            local v222 = CurrentCamera:ViewportPointToRay(p220.X, p220.Y);
            local RaycastParams_new_ret = RaycastParams.new();
            RaycastParams_new_ret.FilterType = Enum.RaycastFilterType.Include;
            RaycastParams_new_ret.FilterDescendantsInstances = { u3 };
            RaycastParams_new_ret.IgnoreWater = true;
            local v223 = Workspace:Raycast(v222.Origin, v222.Direction * ClickDetector.MaxActivationDistance, RaycastParams_new_ret);

            if v223 and (v223.Instance and v223.Instance:IsDescendantOf(u3)) then
                if MenuManager.getCurrent() ~= nil then
                    return;
                end;

                u47 = os.clock();
                click(true, true);
            end;
        end);
    end;

    RunService.RenderStepped:Connect(function() -- Line: 545
        -- upvalues: u44 (ref), u9 (ref), u17 (ref), Workspace (ref), u14 (ref), u15 (ref), u16 (ref)
        if not (u44 and (u9 and u17)) then
            return;
        end;

        local CurrentCamera = Workspace.CurrentCamera;

        if not CurrentCamera then
            return;
        end;

        local v224 = CurrentCamera.CFrame.Position - u17;
        local Vector3_new_ret2 = Vector3.new(v224.X, 0, v224.Z);

        if Vector3_new_ret2.Magnitude < 0.01 then
            return;
        end;

        local Unit = Vector3_new_ret2.Unit;
        local Vector3_new_ret3 = Vector3.new(u17.X + Unit.X * u14, u15, u17.Z + Unit.Z * u14);
        u9.CFrame = CFrame.lookAt(Vector3_new_ret3, Vector3_new_ret3 + Unit) * u16;
    end);
    u44 = true;
    local LocalPlayer = Players.LocalPlayer;

    if LocalPlayer then
        LocalPlayer:GetAttributeChangedSignal("FastAutoBuffUntil"):Connect(applyClickerState);
        local v225 = false;
        local v226;

        if u36 then
            local v227 = u36.Upgrades() or {};
            local v228 = tonumber(v227.AutoClicker) or 0;
            local math_floor_ret2 = math.floor(v228);
            v226 = math.max(0, math_floor_ret2);
        else
            v226 = 0;
        end;

        if v226 > 0 then
            if u36 then
                local AutoClickerEnabled = u36.AutoClickerEnabled;
                v225 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
            else
                v225 = true;
            end;
        end;

        if not v225 then
            local v229 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

            if v229 == nil then
                v225 = false;
            else
                v225 = Workspace:GetServerTimeNow() < v229;
            end;
        end;

        if v225 then
            if u32 then
                u32.Visible = true;
            end;

            if u91 then
                return;
            end;

            u91 = true;
            task.spawn(function() -- Line: 278
                -- upvalues: u36 (ref), Players (ref), Workspace (ref), u32 (ref), u47 (ref), u48 (ref), ClickConfig (ref), UpgradeConfig (ref), click (ref), u91 (ref), u33 (ref)
                while true do
                    local v230 = false;
                    local v231;

                    if u36 then
                        local v232 = u36.Upgrades() or {};
                        local v233 = tonumber(v232.AutoClicker) or 0;
                        local math_floor_ret2 = math.floor(v233);
                        v231 = math.max(0, math_floor_ret2);
                    else
                        v231 = 0;
                    end;

                    if v231 > 0 then
                        if u36 then
                            local AutoClickerEnabled = u36.AutoClickerEnabled;
                            v230 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
                        else
                            v230 = true;
                        end;
                    end;

                    if not v230 then
                        local v234 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                        if v234 == nil then
                            v230 = false;
                        else
                            v230 = Workspace:GetServerTimeNow() < v234;
                        end;
                    end;

                    if not v230 then
                        u91 = false;

                        if u32 then
                            u32.Visible = false;
                        end;

                        if u33 then
                            u33.Rotation = 20;
                        end;

                        return;
                    end;

                    local v235 = false;
                    local v236;

                    if u36 then
                        local v237 = u36.Upgrades() or {};
                        local v238 = tonumber(v237.AutoClicker) or 0;
                        local math_floor_ret2 = math.floor(v238);
                        v236 = math.max(0, math_floor_ret2);
                    else
                        v236 = 0;
                    end;

                    if v236 > 0 then
                        if u36 then
                            local AutoClickerEnabled = u36.AutoClickerEnabled;
                            v235 = AutoClickerEnabled == nil and true or AutoClickerEnabled() ~= false;
                        else
                            v235 = true;
                        end;
                    end;

                    if not v235 then
                        local v239 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));

                        if v239 == nil then
                            v235 = false;
                        else
                            v235 = Workspace:GetServerTimeNow() < v239;
                        end;
                    end;

                    if u32 then
                        u32.Visible = v235;
                    end;

                    local os_clock_ret = os.clock();
                    local v240 = tonumber(Players.LocalPlayer:GetAttribute("FastAutoBuffUntil"));
                    local v241;

                    if v240 == nil then
                        v241 = false;
                    else
                        v241 = Workspace:GetServerTimeNow() < v240;
                    end;

                    local v242;

                    if v241 then
                        v242 = 0.08333333333333333;
                    else
                        local v243;

                        if u36 then
                            local v244 = u36.Upgrades() or {};
                            local v245 = tonumber(v244.AutoClicker) or 0;
                            local math_floor_ret2 = math.floor(v245);
                            v243 = math.max(0, math_floor_ret2);
                        else
                            v243 = 0;
                        end;

                        if v243 <= 0 then
                            v242 = 2;
                        else
                            local MinClickInterval = ClickConfig.getMinClickInterval(Players.LocalPlayer);
                            v242 = math.max(MinClickInterval, UpgradeConfig.getDisplayValue("AutoClicker", v243));
                        end;
                    end;

                    if os_clock_ret - u47 >= 1 and v242 <= os_clock_ret - u48 then
                        u48 = os_clock_ret;
                        click(true);
                    end;

                    task.wait(0.1);
                end;
            end);

            return;
        end;

        if u32 then
            u32.Visible = false;
        end;

        if u33 then
            u33.Rotation = 20;
        end;
    end;
end;

function v1.Init(p246) -- Line: 575
    -- upvalues: u25 (ref), init (copy), u26 (ref), u27 (ref), u28 (ref), Workspace (copy), u29 (ref), u37 (ref), ReplicatedStorage (copy), u38 (ref), u39 (ref)
    u25 = init.createSpring(0, {
        dampingRatio = 0.3,
        frequency = 2
    });
    u25:start();
    u26 = init.createSpring(0, {
        dampingRatio = 0.3,
        frequency = 2
    });
    u26:start();
    u27 = init.createSpring(0, {
        dampingRatio = 0.9,
        frequency = 5.5
    });
    u27:onChange(function(p247) -- Line: 582
        -- upvalues: u28 (ref), Workspace (ref), u29 (ref)
        local v248 = u28;

        if v248 and v248 == Workspace.CurrentCamera then
            v248.FieldOfView = math.clamp(u29 + p247, 1, 120);
        end;
    end);
    u27:start();
    u37 = ReplicatedStorage.Shared:WaitForChild("Signals"):WaitForChild("ButtonClicked");
    local Remotes = ReplicatedStorage.Shared:WaitForChild("Remotes");
    u38 = Remotes:WaitForChild("RegisterClick");
    u39 = Remotes:WaitForChild("ButtonPressVisual");
end;

function v1.Start(p249) -- Line: 595
    -- upvalues: u28 (ref), Workspace (copy), u29 (ref), u27 (ref), u30 (ref), bindFovCamera (copy), u40 (ref), u39 (ref), animateRemotePress (copy), bindSpectatorCounters (copy), setupButton (copy)
    u28 = Workspace.CurrentCamera;

    if u28 then
        u29 = u28.FieldOfView;
    end;

    if u27 then
        u27:setPosition(0);
        u27:setVelocity(0);
    end;

    if u30 then
        u30:Disconnect();
    end;

    u30 = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindFovCamera);

    if u40 then
        u40:Disconnect();
    end;

    if u39 then
        u40 = u39.OnClientEvent:Connect(animateRemotePress);
    end;

    task.spawn(function() -- Line: 605
        -- upvalues: bindSpectatorCounters (ref)
        local NewMap = workspace:WaitForChild("NewMap", 30);

        if NewMap then
            bindSpectatorCounters(NewMap);
        end;
    end);
    task.spawn(setupButton);
end;

return v1;