-- TARGETED VEHICLE SCANNER
local function getVehicleCargoData()
    local isFull = false
    local cargoText = nil
    
    pcall(function()
        local vehiclesFolder = workspace:FindFirstChild("Vehicles")
        if vehiclesFolder then
            for _, vehicle in ipairs(vehiclesFolder:GetChildren()) do
                if vehicle:IsA("Model") then
                    
                    -- PRIMARY CHECK: Look for CargoVolume folder
                    local cargoVolume = vehicle:FindFirstChild("CargoVolume")
                    if cargoVolume then
                        -- Verify the CargoVolume belongs to the player
                        local ownerID = cargoVolume:GetAttribute("OwnerID") or cargoVolume:GetAttribute("Owner")
                        
                        if ownerID == player.UserId or ownerID == player.Name then
                            -- Count direct Ore instances (not intermediate weld/container objects)
                            local oreCount = 0
                            for _, item in ipairs(cargoVolume:GetChildren()) do
                                -- Count if it's an Ore or similar resource item
                                if string.find(string.lower(item.Name), "ore") or 
                                   string.find(string.lower(item.Name), "resource") or
                                   item:IsA("Model") or item:IsA("BasePart") then
                                    -- Only count top-level items (not welded subparts)
                                    if not item.Parent:FindFirstChild("Weld") or item:IsA("Model") then
                                        oreCount = oreCount + 1
                                    end
                                end
                            end
                            
                            cargoText = tostring(oreCount) .. " / " .. tostring(VEHICLE_CAPACITY)
                            if oreCount >= VEHICLE_CAPACITY then
                                isFull = true
                            end
                            return 
                        end
                    end
                    
                    -- SECONDARY CHECK: Look for attributes-based cargo system
                    local current = vehicle:GetAttribute("StoredOres") or vehicle:GetAttribute("Cargo") or vehicle:GetAttribute("OreCount")
                    local maxCap = vehicle:GetAttribute("Capacity") or vehicle:GetAttribute("MaxCapacity")
                    local vehicleOwner = vehicle:GetAttribute("OwnerID") or vehicle:GetAttribute("Owner")
                    
                    if current and maxCap and tonumber(maxCap) == VEHICLE_CAPACITY then
                        if vehicleOwner == player.UserId or vehicleOwner == player.Name then
                            cargoText = tostring(current) .. " / " .. tostring(maxCap)
                            if tonumber(current) >= tonumber(maxCap) then isFull = true end
                            return
                        end
                    end
                end
            end
        end
    end)
    
    return isFull, cargoText
end
