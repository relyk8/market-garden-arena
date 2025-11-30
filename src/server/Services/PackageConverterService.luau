local Players = game:GetService("Players")
local PackageConverterService = {}

function PackageConverterService:Init()
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            self:ConvertCharacter(character)
        end)
    end)
end

function PackageConverterService:ConvertCharacter(character)
    -- Wait for the default rig to load
    task.wait() 
    
    local jointsToWeld = {
        -- Arms
        "RightElbow", "RightWrist",
        "LeftElbow", "LeftWrist",
        -- Legs
        "RightKnee", "RightAnkle",
        "LeftKnee", "LeftAnkle",
        -- Optional: "Waist" if you want 0 torso bend
    }
    
    for _, jointName in ipairs(jointsToWeld) do
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("Motor6D") and descendant.Name == jointName then
                -- 1. Create rigid Weld
                local weld = Instance.new("Weld")
                weld.Name = jointName .. "_Rigid"
                weld.Part0 = descendant.Part0
                weld.Part1 = descendant.Part1
                weld.C0 = descendant.C0
                weld.C1 = descendant.C1
                weld.Parent = descendant.Parent
                
                -- 2. Destroy Motor (Stop Animation)
                descendant:Destroy()
            end
        end
    end
    
    print("🤖 PackageConverter: Converted " .. character.Name .. " to Rigid-R15")
end

return PackageConverterService