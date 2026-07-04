-- TARGETED VEHICLE SCANNER - FIXED WITH DIRECT CHILD COUNT
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
                            -- Count ALL direct children in CargoVolume (this includes ore slots)
                            local childCount = #cargoVolume:GetChildren()
                            
                            -- If we have 240 children, cargo is FULL (last ore slot is 240)
                            if childCount >= 240 then
                                isFull = true
                            end
                            
                            -- Calculate estimated ore count (assuming 2 instances per ore: ore + weld)
                            local estimatedOres = math.floor(childCount / 2)
                            if estimatedOres > VEHICLE_CAPACITY then 
                                estimatedOres = VEHICLE_CAPACITY 
                            end
                            
                            cargoText = tostring(estimatedOres) .. " / " .. tostring(VEHICLE_CAPACITY) .. " [Raw: " .. tostring(childCount) .. "]"
                            return 
                        end
                    end
                    
                    -- SECONDARY CHECK: Attributes-based cargo system (fallback)
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
