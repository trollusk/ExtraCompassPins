-- TODO
-- optional town locations - at least bank, stable
-- optional POIs

-- First, we create a namespace for our addon by declaring a top-level table that will hold everything else.
ExtraCompassPins = {}
local XCP = ExtraCompassPins

-- This isn't strictly necessary, but we'll use this string later when registering events.
-- Better to define it in a single place rather than retyping the same string.
XCP.name = "ExtraCompassPins"

XCP.defaultSettings = {
    showStables = true,
    showBanks = true,
    showRefuges = true,
    showGroupMembers = true
}

-- Next we create a function that will initialize our addon
function XCP.Initialize()
  XCP.settings = ZO_SavedVars:NewAccountWide("ExtraCompassPins_SV", 1, nil, XCP.defaultSettings)
  XCP.SetupSettings()

  -- ...but we don't have anything to initialize yet. We'll come back to this.
  COMPASS_PINS:AddCustomPin("XCP.stable", function() XCP.pinCallback() end, 
    { maxDistance = 0.1, 
      texture = "esoui/art/icons/servicemappins/servicepin_stable.dds" })
  COMPASS_PINS:AddCustomPin("XCP.bank", function() XCP.pinCallback() end, 
    { maxDistance = 0.1, 
      texture = "esoui/art/icons/servicemappins/servicepin_bank.dds" })
  COMPASS_PINS:AddCustomPin("XCP.refuge", function() XCP.pinCallback() end, 
    { maxDistance = 0.1, 
      texture = "esoui/art/icons/servicemappins/servicepin_fence.dds" })
  COMPASS_PINS:AddCustomPin("groupmember", function() XCP.pinCallback() end, 
    { maxDistance = 1.0, 
      texture = "esoui/art/mappins/UI-WorldMapGroupPip.dds" })
  COMPASS_PINS:AddCustomPin("groupleader", function() XCP.pinCallback() end, 
    { maxDistance = 1.0, texture = "esoui/art/compass/groupleader.dds",
      sizeCallback = function(pin, angle, normAngle, normDistance) end,
      additionalLayout = {
            -- "decorator" function, called on each pin after it's created
            function (pin, angle, normAngle, normDistance)
                -- r,g,b,a
                --pin:SetColor(0,1,1,1)
            end,
            -- cleanup function, must undo any special decoration such as colours
            function (pin)
                --pin:SetColor(1,1,1,1)
            end
      }
    })
    COMPASS_PINS:RefreshPins()
end


function XCP.SetupSettings()
	local LAM2 = LibAddonMenu2
	if not LAM2 then
		return
	end

	local panelData = {
		type = "panel",
		name = "Extra Compass Pins",
		displayName = "Extra Compass Pins",
		author = "@trollusk",
		version = "1.0",
		registerForDefaults = true,
	}
	LAM2:RegisterAddonPanel(XCP.name, panelData)

	local optionsTable = {
		{
			type = "checkbox",
			name = "Group members",
			tooltip = "Show group members on the compass.",
			getFunc = function()
				return XCP.settings.showGroupMembers
			end,
			setFunc = function(value)
				XCP.settings.showGroupMembers = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showGroupMembers
		},
		{
			type = "checkbox",
			name = "Stables",
			tooltip = "Show stables on the compass.",
			getFunc = function()
				return XCP.settings.showStables
			end,
			setFunc = function(value)
				XCP.settings.showStables = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showStables
		},
		{
			type = "checkbox",
			name = "Banks",
			tooltip = "Show banks on the compass.",
			getFunc = function()
				return XCP.settings.showBanks
			end,
			setFunc = function(value)
				XCP.settings.showBanks = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showBanks
		},
		{
			type = "checkbox",
			name = "Outlaw Refuges",
			tooltip = "Show outlaw refuges on the compass.",
			getFunc = function()
				return XCP.settings.showRefuges
			end,
			setFunc = function(value)
				XCP.settings.showRefuges = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showRefuges
		}
	}
	LAM2:RegisterOptionControls(XCP.name, optionsTable)
end


-- called whenever the compass is refreshed
-- must recreate all pins
function XCP.pinCallback()
    -- pintype matches the string given to AddCustomPin
    -- pin.x and pin.y are normalised map coordinates (0,0 = top left, 1,1 = bottom right)
    -- pintag is a way to pass around extra info about the pins, if you need to
    if GetGroupSize() > 0 then
        -- player is grouped
        for n=1, GetGroupSize() do
            tag = GetGroupUnitTagByIndex(n)
            if IsUnitOnline(tag) and IsGroupMemberInSameWorldAsPlayer(tag) 
              and IsGroupMemberInSameInstanceAsPlayer(tag) and IsGroupMemberInSameLayerAsPlayer(tag) then
                x,y,_,inCurrentMap = GetMapPlayerPosition(tag)        -- to groupN where N=GROUP_SIZE_MAX
                if inCurrentMap then
                    pintype = "groupmember"
                    if IsUnitGroupLeader(tag) then pintype = "groupleader" end
                    COMPASS_PINS.pinManager:CreatePin( pintype, {}, x, y, GetUnitDisplayName(tag))
                    df("Created %s icon for unit '%s'", pintype, tag)
                end
            end
        end
    end

    for n=1, GetNumMapLocations() do
        if IsMapLocationVisible(n) then
            -- locName = GetMapLocation(n)
            icon,x,y = GetMapLocationIcon(n)
            if (icon and (icon ~= "")) then
                pathnames = split(icon, "/")
                filename = pathnames[table.getn(pathnames)]
                pintype = ""

                if filename == "servicepin_stable.dds" then pintype = "XCP.stable"
                elseif filename == "servicepin_bank.dds" then pintype = "XCP.bank"
                elseif filename == "servicepin_thievesguild.dds" then pintype = "XCP.refuge"
                elseif filename == "servicepin_fence.dds" then pintype = "XCP.refuge"
                end

                if pintype ~= "" then
                    df("Created town service icon: '%s'", filename)
                    COMPASS_PINS.pinManager:CreatePin( pintype, {}, x, y, "service")
                end
            end
        end
    end
    -- x,y = GetMapPlayerPosition("player")
    -- COMPASS_PINS.pinManager:CreatePin( "testpin", {}, x + 0.01, y + 0.01, "Test")
    -- df("Created pin %s at %f, %f", "testpin", x, y)
end


function RefreshVolatilePins()
    if GetGroupSize() > 0 then
        COMPASS_PINS:RefreshPins()
    end
end


-- split a string into an array of strings
-- delimiter is a single character which defines where the splits occur
-- eg split("foo-bar-baz", "-")  returns ["foo", "bar", "baz"]
function split(str, delimiter)
    result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end


-- ====================== Events ==============================

-- call a function every X milliseconds. String is a unique identifier.
-- we only need to do this if the pins denote things that are changing their position,
-- such as players or NPCs. Otherwise the pins will not refresh/move until the player
-- travels to a new map.
EVENT_MANAGER:RegisterForUpdate("ExtraCompassPins_Refresh", 500, RefreshVolatilePins)
-- disable with EVENT_MANAGER:UnregisterForUpdate("ExtraCompassPins_Refresh")

function XCP.OnAddOnLoaded(event, addonName)
  -- The event fires each time *any* addon loads - but we only care about when our own addon loads.
  if addonName == XCP.name then
    XCP.Initialize()
    -- now that we've done it, unregister the event 
    EVENT_MANAGER:UnregisterForEvent(XCP.name, EVENT_ADD_ON_LOADED) 
  end
end
 

-- Finally, we'll register our event handler function to be called when the proper event occurs.
-->This event EVENT_ADD_ON_LOADED will be called for EACH of the addns/libraries enabled, this is why there needs to be a check against the addon name
-->within your callback function! Else the very first addon loaded would run your code + all following addons too.
EVENT_MANAGER:RegisterForEvent(XCP.name, EVENT_ADD_ON_LOADED, XCP.OnAddOnLoaded)

