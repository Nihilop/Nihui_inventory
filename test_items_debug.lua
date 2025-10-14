-- Test script to debug item loading
local addonName, ns = ...

-- Wait for PLAYER_LOGIN to test
local testFrame = CreateFrame("Frame")
testFrame:RegisterEvent("PLAYER_LOGIN")
testFrame:SetScript("OnEvent", function(self, event)
    -- Wait 2 seconds for everything to load
    C_Timer.After(2, function()
        print("|cffff0000=== NIHUI IV DEBUG TEST ===|r")

        -- Test 1: Check if components are loaded
        print("Components loaded:", ns.Components and "YES" or "NO")
        print("Items component:", ns.Components and ns.Components.Items and "YES" or "NO")
        print("Constants component:", ns.Components and ns.Components.Constants and "YES" or "NO")

        -- Test 2: Get constants
        if ns.Components and ns.Components.Constants then
            local const = ns.Components.Constants.Get()
            print("Constants.Get() returned:", const and "YES" or "NO")

            if const and const.BACKPACK_BAGS then
                print("BACKPACK_BAGS:")
                for bagID in pairs(const.BACKPACK_BAGS) do
                    print("  Bag", bagID, "- slots:", C_Container.GetContainerNumSlots(bagID))
                end
            end
        end

        -- Test 3: Try to get items
        if ns.Components and ns.Components.Items then
            print("\nTrying GetBackpackItems...")
            local items = ns.Components.Items.GetBackpackItems()

            if items then
                local count = 0
                local nonEmptyCount = 0
                for slotKey, itemData in pairs(items) do
                    count = count + 1
                    if not itemData.isEmpty then
                        nonEmptyCount = nonEmptyCount + 1
                        print(string.format("  Item %s: %s (ID: %s)",
                            slotKey,
                            itemData.itemName or "Unknown",
                            tostring(itemData.itemID)))
                    end
                end
                print(string.format("Total slots: %d, Items: %d, Empty: %d", count, nonEmptyCount, count - nonEmptyCount))
            else
                print("GetBackpackItems returned NIL!")
            end
        end

        print("|cffff0000=== END DEBUG TEST ===|r")
    end)
end)
