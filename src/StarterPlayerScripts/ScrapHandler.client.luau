-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local RunService = game:GetService("RunService");
local Boosts = require(ReplicatedStorage.Modules.Boosts);
local Manager = require(game.ReplicatedStorage.Modules.Manager);
local LocalPlayer = Players.LocalPlayer;
local Features = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Features");
local CreateScrap = Features:WaitForChild("CreateScrap");
local CollectScrap = Features:WaitForChild("CollectScrap");
local ClearScraps = Features:WaitForChild("ClearScraps");
local ClearScrapsServer = Features:WaitForChild("ClearScrapsServer");
local Scrap = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("Scrap");
local SpawnZone = workspace.World.Others:WaitForChild("SpawnZone");
local Ring = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("Others"):WaitForChild("Ring");
local ClientScraps = workspace:FindFirstChild("ClientScraps");

if not ClientScraps then
    ClientScraps = Instance.new("Folder");
    ClientScraps.Name = "ClientScraps";
    ClientScraps.Parent = workspace;
end;

local u1 = {};

local function isInsideZone(p2, p3, p4) -- Line: 34
    local v5 = p3.CFrame:PointToObjectSpace(p2);
    local v6 = p3.Size / 2;
    local v7 = math.abs(v5.X) <= v6.X;
    local v8 = math.abs(v5.Z) <= v6.Z;
    local v9 = math.abs(v5.Y) <= v6.Y;

    if p4 then
        return v7 and v8;
    end;

    if v7 then
        if not v9 then
            v8 = v9;
        end;
    else
        v8 = v7;
    end;

    return v8;
end;

local function removeScrap(p10) -- Line: 49
    -- upvalues: u1 (copy)
    local v11 = u1[p10];

    if v11 and (v11.obj and v11.obj.Parent) then
        v11.obj:Destroy();
    end;

    u1[p10] = nil;
end;

local function createScrap(p12) -- Line: 61
    -- upvalues: Scrap (copy), ClientScraps (ref), Manager (copy), LocalPlayer (copy), u1 (copy)
    local v13 = Scrap:FindFirstChild(p12.Name);

    if not v13 then
        return;
    end;

    local v14 = v13:Clone();
    local v15 = p12.Rotation or {
        X = 0,
        Y = 0,
        Z = 0
    };
    v14.CFrame = CFrame.new(p12.Position) * CFrame.Angles(v15.X, v15.Y, v15.Z);
    v14.Parent = ClientScraps;

    if p12.Weight then
        v14:SetAttribute("WeightGrams", p12.Weight);
        local Bottom = v14:FindFirstChild("Bottom", true);

        if Bottom then
            local amount = Bottom:FindFirstChild("amount");

            if amount and amount:IsA("TextLabel") then
                amount.Text = Manager.Text(LocalPlayer, p12.Weight, "scrap");
            end;
        end;
    end;

    u1[p12.Id] = {
        obj = v14,
        data = p12
    };
end;

CreateScrap.OnClientEvent:Connect(function(p16) -- Line: 111
    -- upvalues: createScrap (copy), u1 (copy)
    if p16.CreateBatch then
        for _, v in ipairs(p16.Scraps) do
            createScrap(v);
        end;

        return;
    end;

    if p16.RemoveBatch then
        for _, v in ipairs(p16.Ids) do
            local v17 = u1[v];

            if v17 and (v17.obj and v17.obj.Parent) then
                v17.obj:Destroy();
            end;

            u1[v] = nil;
        end;

        return;
    end;

    if not p16.Remove then
        createScrap(p16);

        return;
    end;

    local Id = p16.Id;
    local v18 = u1[Id];

    if v18 and (v18.obj and v18.obj.Parent) then
        v18.obj:Destroy();
    end;

    u1[Id] = nil;
end);
local u19 = 0;
RunService.Heartbeat:Connect(function(p20) -- Line: 141
    -- upvalues: u19 (ref), LocalPlayer (copy), SpawnZone (copy), Boosts (copy), u1 (copy), CollectScrap (copy)
    u19 = u19 + p20;

    if u19 < 0.05 then
        return;
    end;

    u19 = 0;
    local Character = LocalPlayer.Character;

    if not Character then
        return;
    end;

    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart");

    if not HumanoidRootPart then
        return;
    end;

    local v21 = SpawnZone;
    local v22 = v21.CFrame:PointToObjectSpace(HumanoidRootPart.Position);
    local v23 = v21.Size / 2;
    local v24 = math.abs(v22.X) <= v23.X;
    local v25 = math.abs(v22.Z) <= v23.Z;
    local v26 = math.abs(v22.Y) <= v23.Y;

    if v24 then
        if not v26 then
            v25 = v26;
        end;
    else
        v25 = v24;
    end;

    if not v25 then
        return;
    end;

    local v27 = Boosts.Range(LocalPlayer);
    local Position = HumanoidRootPart.Position;

    for i, v in pairs(u1) do
        local obj = v.obj;

        if obj and obj.Parent then
            local Position2 = obj.Position;

            if Vector3.new(Position.X - Position2.X, 0, Position.Z - Position2.Z).Magnitude <= v27 then
                CollectScrap:FireServer(i, Position2);
            end;
        else
            u1[i] = nil;
        end;
    end;
end);
local u28 = nil;
local u29 = nil;

local function createRing() -- Line: 192
    -- upvalues: u28 (ref), Ring (copy), u29 (ref)
    if u28 then
        return;
    end;

    u28 = Ring:Clone();
    u28.Anchored = true;
    u28.CanCollide = false;
    u28.Parent = workspace;
    u29 = u28.CFrame - u28.CFrame.Position;
end;

local function removeRing() -- Line: 205
    -- upvalues: u28 (ref), u29 (ref)
    if u28 then
        u28:Destroy();
        u28 = nil;
        u29 = nil;
    end;
end;

RunService.RenderStepped:Connect(function() -- Line: 213
    -- upvalues: LocalPlayer (copy), u28 (ref), u29 (ref), SpawnZone (copy), Ring (copy), Boosts (copy)
    local Character = LocalPlayer.Character;

    if not Character then
        if u28 then
            u28:Destroy();
            u28 = nil;
            u29 = nil;
        end;

        return;
    end;

    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart");

    if not HumanoidRootPart then
        if u28 then
            u28:Destroy();
            u28 = nil;
            u29 = nil;
        end;

        return;
    end;

    local Position = HumanoidRootPart.Position;
    local v30 = SpawnZone;
    local v31 = v30.CFrame:PointToObjectSpace(Position);
    local v32 = v30.Size / 2;
    local v33 = math.abs(v31.X) <= v32.X;
    local v34 = math.abs(v31.Z) <= v32.Z;
    local v35 = math.abs(v31.Y) <= v32.Y;

    if v33 then
        if not v35 then
            v34 = v35;
        end;
    else
        v34 = v33;
    end;

    if not v34 then
        if u28 then
            u28:Destroy();
            u28 = nil;
            u29 = nil;
        end;

        return;
    end;

    if not u28 then
        u28 = Ring:Clone();
        u28.Anchored = true;
        u28.CanCollide = false;
        u28.Parent = workspace;
        u29 = u28.CFrame - u28.CFrame.Position;
    end;

    local v36 = Boosts.Range(LocalPlayer);
    u28.CFrame = CFrame.new((Vector3.new(Position.X, 1.25, Position.Z))) * u29;
    u28.Size = Vector3.new(u28.Size.X, v36 * 2, v36 * 2);
end);
ClearScraps.OnClientEvent:Connect(function() -- Line: 250
    -- upvalues: u1 (copy), ClearScrapsServer (copy)
    for i, _ in pairs(u1) do
        local v37 = u1[i];

        if v37 and (v37.obj and v37.obj.Parent) then
            v37.obj:Destroy();
        end;

        u1[i] = nil;
    end;

    ClearScrapsServer:FireServer();
end);