-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- Decompiled with Potassium's decompiler.

local LocalPlayer = game.Players.LocalPlayer;
local Manager = require(game.ReplicatedStorage.Modules.Manager);
local Boosts = require(game:WaitForChild("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Boosts"));
LocalPlayer:WaitForChild("upgrades");

local function getDescendant(p1, p2) -- Line: 7
    for _, v in ipairs(string.split(p2, ".")) do
        if not p1:FindFirstChild(v) then
            return nil;
        end;

        p1 = p1[v];
    end;

    return p1;
end;

local function updateText() -- Line: 19
    -- upvalues: getDescendant (copy), Manager (copy), LocalPlayer (copy), Boosts (copy)
    local v3 = getDescendant(workspace, "World.Others.SpawnInfo.BillboardGui.ScrapCapacity");
    local v4 = getDescendant(workspace, "World.Others.SpawnInfo.BillboardGui.ScrapCooldown");
    local v5 = getDescendant(workspace, "World.Others.SpawnInfo.BillboardGui.BulkRespawn");

    if v3 then
        v3.Text = Manager.Text(LocalPlayer, Boosts.Capacity(LocalPlayer)) .. " Scrap Capacity";
    end;

    if v4 then
        v4.Text = Manager.Text(LocalPlayer, Boosts.Cooldown(LocalPlayer)) .. "s Cooldown";
    end;

    if v5 then
        v5.Text = Manager.Text(LocalPlayer, Boosts.BulkRespawn(LocalPlayer)) .. " Bulk Respawn";
    end;
end;

spawn(function() -- Line: 35
    -- upvalues: updateText (copy)
    while true do
        updateText();
        wait(1);
    end;
end);