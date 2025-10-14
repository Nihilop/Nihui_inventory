-- test_components.lua - Test each component loading
local addonName, ns = ...

print("|cff00ff00[Nihui IV]|r Testing component loads...")

-- Test constants
local success, err = pcall(function()
    if ns.Components and ns.Components.Constants then
        print("|cff00ff00[Nihui IV]|r Constants loaded OK")
    else
        print("|cffff0000[Nihui IV]|r Constants FAILED - namespace missing")
    end
end)

if not success then
    print("|cffff0000[Nihui IV] Constants error:|r " .. tostring(err))
end
