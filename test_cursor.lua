-- test_cursor.lua - Test cursor behavior for drag & drop
local addonName, ns = ...

-- Print cursor info every frame when something is being held
local testFrame = CreateFrame("Frame")
local lastCursorInfo = nil

testFrame:SetScript("OnUpdate", function(self, elapsed)
    local cursorType, cursorInfo1, cursorInfo2, cursorInfo3 = GetCursorInfo()

    if cursorType then
        -- Something is on the cursor!
        local info = string.format("Cursor: type=%s, info1=%s, info2=%s, info3=%s",
            tostring(cursorType),
            tostring(cursorInfo1),
            tostring(cursorInfo2),
            tostring(cursorInfo3))

        if info ~= lastCursorInfo then
            print("|cff9482c9[Nihui Test]|r " .. info)
            lastCursorInfo = info
        end
    elseif lastCursorInfo then
        print("|cff9482c9[Nihui Test]|r Cursor cleared!")
        lastCursorInfo = nil
    end
end)

print("|cff9482c9[Nihui Test]|r Cursor tracking enabled. Try picking up an item!")
print("|cff9482c9[Nihui Test]|r Click-hold: Click and hold on an item, then move it")
print("|cff9482c9[Nihui Test]|r The console will show what's on the cursor")
