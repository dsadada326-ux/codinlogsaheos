-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local TweenService = game:GetService("TweenService");
local Players = game:GetService("Players");
local RunService = game:GetService("RunService");
local SoundService = game:GetService("SoundService");
local LocalPlayer = Players.LocalPlayer;

while not LocalPlayer do
    Players.PlayerAdded:Wait();
    LocalPlayer = Players.LocalPlayer;
end;

local function tweenObject(p1, p2, p3, p4, p5) -- Line: 12
    -- upvalues: TweenService (copy)
    local v6 = TweenService:Create(p1, TweenInfo.new(0.175, p4 or Enum.EasingStyle.Bounce, p5 or Enum.EasingDirection.Out), p2);
    v6:Play();

    return v6;
end;

local function applyButtonEffects(p7) -- Line: 19
    -- upvalues: TweenService (copy), SoundService (copy)
    if not p7:IsA("GuiButton") then
        return;
    end;

    if p7:GetAttribute("ButtonAnimation") == false then
        return;
    end;

    local UIScale = p7:FindFirstChild("UIScale");

    if not UIScale then
        UIScale = Instance.new("UIScale");
        UIScale.Name = "UIScale";
        UIScale.Scale = 1;
        UIScale.Parent = p7;
    end;

    local u8 = p7:FindFirstChild("BG") or p7:FindFirstChildWhichIsA("Frame");
    local u9, u10;

    if p7:GetAttribute("textdisplay") and u8 then
        u9 = u8:FindFirstChildWhichIsA("TextLabel");
        u9 = u9;

        if u9 then
            u10 = u9:FindFirstChildWhichIsA("TextLabel");
        end;
    else
        u9 = nil;
        u10 = nil;
    end;

    local u11 = false;

    local function setInitialFade(p12) -- Line: 49
        if not p12 then
            return;
        end;

        local v13 = p12:FindFirstChildOfClass("UIStroke");

        if v13 then
            v13.Transparency = 1;
        end;

        p12.TextTransparency = 1;
    end;

    local v14 = u9;

    if v14 then
        local v15 = v14:FindFirstChildOfClass("UIStroke");

        if v15 then
            v15.Transparency = 1;
        end;

        v14.TextTransparency = 1;
    end;

    local v16 = u10;

    if v16 then
        local v17 = v16:FindFirstChildOfClass("UIStroke");

        if v17 then
            v17.Transparency = 1;
        end;

        v16.TextTransparency = 1;
    end;

    local function tweenFade(p18, p19, p20) -- Line: 61
        -- upvalues: TweenService (ref)
        if not p18 then
            return;
        end;

        local v21 = p18:FindFirstChildOfClass("UIStroke");

        if v21 then
            TweenService:Create(v21, TweenInfo.new(0.175, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
                Transparency = p20
            }):Play();
        end;

        TweenService:Create(p18, TweenInfo.new(0.175, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
            TextTransparency = p19
        }):Play();
    end;

    p7.MouseEnter:Connect(function() -- Line: 70
        -- upvalues: u11 (ref), UIScale (ref), TweenService (ref), SoundService (ref), tweenFade (copy), u9 (ref), u10 (ref)
        u11 = true;
        TweenService:Create(UIScale, TweenInfo.new(0.175, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
            Scale = 1.05
        }):Play();
        SoundService["RBLX UI Hover 01 (SFX)"]:Play();
        tweenFade(u9, 0, 0);
        tweenFade(u10, 0, 0);
    end);
    p7.MouseLeave:Connect(function() -- Line: 78
        -- upvalues: u11 (ref), UIScale (ref), TweenService (ref), tweenFade (copy), u9 (ref), u10 (ref)
        u11 = false;
        TweenService:Create(UIScale, TweenInfo.new(0.175, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
            Scale = 1
        }):Play();
        tweenFade(u9, 1, 1);
        tweenFade(u10, 1, 1);
    end);
    p7.MouseButton1Down:Connect(function() -- Line: 85
        -- upvalues: UIScale (ref), TweenService (ref), SoundService (ref), u8 (copy)
        TweenService:Create(UIScale, TweenInfo.new(0.175, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
            Scale = 0.95
        }):Play();
        SoundService.cartoon_pop:Play();

        if u8 then
            local v22 = {
                Position = UDim2.new(0.5, 0, 0.5, 0)
            };
            TweenService:Create(u8, TweenInfo.new(0.175, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), v22):Play();
        end;
    end);
    p7.MouseButton1Up:Connect(function() -- Line: 93
        -- upvalues: u11 (ref), UIScale (ref), TweenService (ref), SoundService (ref), u8 (copy)
        TweenService:Create(UIScale, TweenInfo.new(0.175, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
            Scale = u11 and 1.05 or 1
        }):Play();
        SoundService.cartoon_pop2:Play();

        if u8 then
            local v23 = {
                Position = u11 and UDim2.new(0.5, 0, 0.44, 0) or UDim2.new(0.5, 0, 0.5, 0)
            };
            TweenService:Create(u8, TweenInfo.new(0.175, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), v23):Play();
        end;
    end);
end;

task.spawn(function(p24) -- Line: 105, Name: applyAllGuiButtons
    -- upvalues: LocalPlayer (ref), RunService (copy), applyButtonEffects (copy)
    local v25 = p24 or LocalPlayer:WaitForChild("PlayerGui");

    while not v25 do
        RunService.Heartbeat:Wait();
        v25 = LocalPlayer:FindFirstChild("PlayerGui");
    end;

    for _, descendant in ipairs(v25:GetDescendants()) do
        if descendant:IsA("GuiButton") then
            applyButtonEffects(descendant);
        end;
    end;

    v25.DescendantAdded:Connect(function(p26) -- Line: 119
        -- upvalues: applyButtonEffects (ref)
        if p26:IsA("GuiButton") then
            applyButtonEffects(p26);
        end;
    end);
end);

return true;