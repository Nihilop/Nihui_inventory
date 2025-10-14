-- components/events.lua - Event bus system (pure logic, no layout)
-- Extracted from BetterBags - handles event registration, messaging, and bucketing
local addonName, ns = ...

ns.Components = ns.Components or {}
ns.Components.Events = {}

-- Internal state
local eventFrame = CreateFrame("Frame")
local messageCallbacks = {} -- {eventName = {callbacks}}
local eventCallbacks = {} -- {eventName = {callbacks}}
local bucketTimers = {} -- {eventName = timer}
local bucketCallbacks = {} -- {eventName = {callbacks}}
local eventArguments = {} -- {eventName = arguments}

-- Register callback for internal addon message
-- @param messageName - Name of the message
-- @param callback - Function to call when message fires
function ns.Components.Events.RegisterMessage(messageName, callback)
    if not messageCallbacks[messageName] then
        messageCallbacks[messageName] = {}
    end

    table.insert(messageCallbacks[messageName], callback)
end

-- Register callback for WoW event
-- @param eventName - Name of WoW event (e.g., "BAG_UPDATE")
-- @param callback - Function to call when event fires
function ns.Components.Events.RegisterEvent(eventName, callback)
    if not eventCallbacks[eventName] then
        eventCallbacks[eventName] = {}

        -- Register WoW event
        eventFrame:RegisterEvent(eventName)
    end

    table.insert(eventCallbacks[eventName], callback)
end

-- Register multiple events/messages at once
-- @param events - Table {eventName = callback}
-- @param messages - Table {messageName = callback}
function ns.Components.Events.RegisterMap(events, messages)
    if events then
        for eventName, callback in pairs(events) do
            ns.Components.Events.RegisterEvent(eventName, callback)
        end
    end

    if messages then
        for messageName, callback in pairs(messages) do
            ns.Components.Events.RegisterMessage(messageName, callback)
        end
    end
end

-- Send internal message to all registered callbacks
-- @param messageName - Name of the message
-- @param ... - Arguments to pass to callbacks
function ns.Components.Events.SendMessage(messageName, ...)
    local callbacks = messageCallbacks[messageName]
    if not callbacks then return end

    for _, callback in ipairs(callbacks) do
        xpcall(callback, geterrorhandler(), ...)
    end
end

-- Send message after a delay (next frame)
-- @param messageName - Name of the message
-- @param ... - Arguments to pass to callbacks
function ns.Components.Events.SendMessageLater(messageName, ...)
    local args = {...}
    C_Timer.After(0, function()
        ns.Components.Events.SendMessage(messageName, unpack(args))
    end)
end

-- Register bucketed event (debounced - fires once after 0.2s of no events)
-- @param eventName - Name of WoW event
-- @param callback - Function to call after bucket delay
function ns.Components.Events.BucketEvent(eventName, callback)
    local bucketFunction = function()
        for _, cb in pairs(bucketCallbacks[eventName]) do
            xpcall(cb, geterrorhandler())
        end
        bucketTimers[eventName] = nil
    end

    if not bucketCallbacks[eventName] then
        bucketCallbacks[eventName] = {}

        -- Register event that will trigger bucket
        ns.Components.Events.RegisterEvent(eventName, function()
            if bucketTimers[eventName] then
                bucketTimers[eventName]:Cancel()
            end
            bucketTimers[eventName] = C_Timer.NewTimer(0.2, bucketFunction)
        end)
    end

    table.insert(bucketCallbacks[eventName], callback)
end

-- Register group of events with single bucketed callback
-- Fires once after 0.2s when any event in the group fires
-- @param groupEvents - Array of WoW event names
-- @param groupMessages - Array of internal message names
-- @param callback - Function(eventData) where eventData = {{eventName, args}, ...}
function ns.Components.Events.GroupBucketEvent(groupEvents, groupMessages, callback)
    local groupKey = table.concat(groupEvents or {}, "") .. table.concat(groupMessages or {}, "")

    local bucketFunction = function()
        for _, cb in pairs(bucketCallbacks[groupKey]) do
            xpcall(cb, geterrorhandler(), eventArguments[groupKey])
        end
        eventArguments[groupKey] = {}
    end

    if not bucketCallbacks[groupKey] then
        bucketCallbacks[groupKey] = {}
        eventArguments[groupKey] = {}

        -- Register all events in group
        for _, eventName in ipairs(groupEvents or {}) do
            ns.Components.Events.RegisterEvent(eventName, function(...)
                if bucketTimers[groupKey] then
                    bucketTimers[groupKey]:Cancel()
                end

                table.insert(eventArguments[groupKey], {
                    eventName = eventName,
                    args = {...}
                })

                bucketTimers[groupKey] = C_Timer.NewTimer(0.2, bucketFunction)
            end)
        end

        -- Register all messages in group
        for _, messageName in ipairs(groupMessages or {}) do
            ns.Components.Events.RegisterMessage(messageName, function(...)
                if bucketTimers[groupKey] then
                    bucketTimers[groupKey]:Cancel()
                end

                table.insert(eventArguments[groupKey], {
                    eventName = messageName,
                    args = {...}
                })

                bucketTimers[groupKey] = C_Timer.NewTimer(0.2, bucketFunction)
            end)
        end
    end

    table.insert(bucketCallbacks[groupKey], callback)
end

-- Collect events until final event fires, then call callback with all collected data
-- @param caughtEvent - Event to collect
-- @param finalEvent - Event that triggers callback
-- @param callback - Function(caughtEvents, finalArgs) where both are {eventName, args}
function ns.Components.Events.CatchUntil(caughtEvent, finalEvent, callback)
    local caughtEvents = {}

    ns.Components.Events.RegisterEvent(caughtEvent, function(...)
        table.insert(caughtEvents, {
            eventName = caughtEvent,
            args = {...}
        })
    end)

    ns.Components.Events.RegisterEvent(finalEvent, function(...)
        local finalArgs = {
            eventName = finalEvent,
            args = {...}
        }

        callback(caughtEvents, finalArgs)
        caughtEvents = {}
    end)
end

-- Handle WoW events
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local callbacks = eventCallbacks[event]
    if not callbacks then return end

    for _, callback in ipairs(callbacks) do
        xpcall(callback, geterrorhandler(), event, ...)
    end
end)

-- Helper: Unregister event (for cleanup)
-- @param eventName - Name of WoW event
function ns.Components.Events.UnregisterEvent(eventName)
    if eventCallbacks[eventName] then
        eventFrame:UnregisterEvent(eventName)
        eventCallbacks[eventName] = nil
    end
end

-- Helper: Unregister message (for cleanup)
-- @param messageName - Name of internal message
function ns.Components.Events.UnregisterMessage(messageName)
    messageCallbacks[messageName] = nil
end

-- Cleanup all events and messages
function ns.Components.Events.UnregisterAll()
    eventFrame:UnregisterAllEvents()
    eventCallbacks = {}
    messageCallbacks = {}
    bucketTimers = {}
    bucketCallbacks = {}
    eventArguments = {}
end

-- Track bank state
local bankIsOpen = false

-- Check if bank is currently open
function ns.Components.Events.IsBankOpen()
    return bankIsOpen
end

-- Initialize bank tracking
local function InitializeBankTracking()
    -- Track bank open/close state
    ns.Components.Events.RegisterEvent("BANKFRAME_OPENED", function()
        bankIsOpen = true
    end)

    ns.Components.Events.RegisterEvent("BANKFRAME_CLOSED", function()
        bankIsOpen = false
    end)

    -- Also check for PLAYERBANKSLOTS_CHANGED as fallback (bank must be open for this to fire)
    ns.Components.Events.RegisterEvent("PLAYERBANKSLOTS_CHANGED", function()
        bankIsOpen = true
    end)
end

-- Initialize on load
InitializeBankTracking()
