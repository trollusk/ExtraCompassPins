-- TODO
-- optional town locations - at least bank, stable
-- optional POIs

-- First, we create a namespace for our addon by declaring a top-level table that will hold everything else.
ExtraCompassPins = {}
XCP = ExtraCompassPins
--local LMP = LibMapPins


-- This isn't strictly necessary, but we'll use this string later when registering events.
-- Better to define it in a single place rather than retyping the same string.
XCP.name = "ExtraCompassPins"

XCP.defaultSettings = {
    showStables = true,
    showBanks = true,
    showRefuges = true,
    showGroupMembers = true,
    showGroupLeader = true,
    showCardinalPoints = true,
    pinRefreshms = 500,
    colourBank = {r=0xff, g=0xcc, b=0x66},
    colourStable = {r=0xf9, g=0xd2, b=0x86},
    colourRefuge = {r=0xee, g=0xee, b=0xee},
    colourGroupMember = {r=0xf9, g=0xe6, b=0xff},
    colourGroupLeader = {r=0xff, g=0xcc, b=0x66},
    colourCardinalPoint = {r=0x80, g=0xbf, b=0xff}
}

-- X is E-W coordinate, Z is N-S, and Y is up-down.
-- Northwest is (x=0,z=0)
local lastPlayerX = 0
local lastPlayerZ = 0

-- Next we create a function that will initialize our addon
function XCP.Initialize()

    XCP.settings = ZO_SavedVars:NewAccountWide("ExtraCompassPins_SV", 1, nil, XCP.defaultSettings)
    XCP.SetupSettings()
    -- call a function every X milliseconds. String is a unique identifier.
    -- we only need to do this if the pins denote things that are changing their position,
    -- such as players or NPCs. Otherwise the pins will not refresh/move until the player
    -- travels to a new map.
    EVENT_MANAGER:UnregisterForUpdate("ExtraCompassPins_Refresh")
    EVENT_MANAGER:RegisterForUpdate("ExtraCompassPins_Refresh", XCP.settings.pinRefreshms or 500, RefreshVolatilePins)
    -- disable with EVENT_MANAGER:UnregisterForUpdate("ExtraCompassPins_Refresh")

    AddColouredPin("XCP.stable", 0.1, "esoui/art/icons/servicemappins/servicepin_stable.dds", 
                XCP.servicePinCallback)
    AddColouredPin("XCP.bank", 0.1, "esoui/art/icons/servicemappins/servicepin_bank.dds", 
                XCP.servicePinCallback)
    AddColouredPin("XCP.refuge", 0.1, "esoui/art/icons/servicemappins/servicepin_fence.dds", 
                XCP.servicePinCallback)
    AddColouredPin("groupmember", 1.0, "esoui/art/compass/groupmember.dds", 
                XCP.groupPinCallback)
    AddColouredPin("groupleader", 1.0, "esoui/art/compass/groupleader.dds", 
                XCP.groupPinCallback)
    AddColouredPin("XCP.north", 1.0, "ExtraCompassPins/textures/north.dds", 
                XCP.cardinalPointCallback)
    AddColouredPin("XCP.south", 1.0, "ExtraCompassPins/textures/south.dds", 
                XCP.cardinalPointCallback)
    AddColouredPin("XCP.east", 1.0, "ExtraCompassPins/textures/east.dds", 
                XCP.cardinalPointCallback)
    AddColouredPin("XCP.west", 1.0, "ExtraCompassPins/textures/west.dds", 
                XCP.cardinalPointCallback)

    COMPASS_PINS:RefreshPins()
end


function AddColouredPin(pintype, maxDist, texture, callback)
    COMPASS_PINS:AddCustomPin(pintype, callback, 
    { 
      maxDistance = maxDist, 
      texture = texture,
      additionalLayout = {
            -- "decorator" function, called on each pin after it's created
            function (pin, angle, normAngle, normDistance)
                -- r,g,b,a
                if pin and pin.pinTag then 
                    red = pin.pinTag.r
                    green = pin.pinTag.g
                    blue = pin.pinTag.b
                    if red>1 then red = red/255.0 end
                    if green>1 then green = green/255.0 end
                    if blue>1 then blue = blue/255.0 end
                    pin:GetNamedChild("Background"):SetColor(red, green, blue, 1)
                    if pintype=="XCP.north" or pintype=="XCP.south" or pintype=="XCP.east" or pintype=="XCP.west" then
                        pin:GetNamedChild("Background"):SetDrawTier(DT_HIGH)
                        pin:GetNamedChild("Background"):SetDrawLayer(DL_OVERLAY)
                    end
                end
            end,
            -- cleanup function, must undo any special decoration such as colours
            function (pin)
                -- reset colour to white
                if pin and red then 
                    pin:GetNamedChild("Background"):SetColor(1,1,1, 1) 
                end
            end
      }})
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
        ---------------------------- group members ----------------------------------
		[1] = {
			type = "checkbox",
			name = "Group members",
			tooltip = "Show group members on the compass.",
            width = "half",
			getFunc = function()
				return XCP.settings.showGroupMembers
			end,
			setFunc = function(value)
				XCP.settings.showGroupMembers = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showGroupMembers
		},
        [2] = {
            type = "colorpicker",
            name = "Group Member icon",
            tooltip = "Colour of group member compass pins.",
            width = "half",
			getFunc = function()
				c = XCP.settings.colourGroupMember
                return c.r, c.g, c.b
			end,
			setFunc = function(red, green, blue, alpha)
				XCP.settings.colourGroupMember = {r=red, g=green, b=blue}
                AddColouredPin("groupmember", 1.0, "esoui/art/compass/groupmember.dds", 
                        XCP.groupPinCallback)
                COMPASS_PINS:RefreshPins("groupmember")
			end,
			default = XCP.defaultSettings.colourGroupMember.r, XCP.defaultSettings.colourGroupMember.g, 
                      XCP.defaultSettings.colourGroupMember.b
        },
        ---------------------------- group leader ----------------------------------
		[3] = {
			type = "checkbox",
			name = "Group leader",
			tooltip = "Show group leader on the compass.",
            width = "half",
			getFunc = function()
				return XCP.settings.showGroupLeader
			end,
			setFunc = function(value)
				XCP.settings.showGroupLeader = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showGroupLeader
		},
        [4] = {
            type = "colorpicker",
            name = "Group Leader icon",
            tooltip = "Colour of group leader compass pin.",
            width = "half",
			getFunc = function()
				c = XCP.settings.colourGroupLeader
                return c.r, c.g, c.b
			end,
			setFunc = function(red, green, blue, alpha)
				XCP.settings.colourGroupLeader = {r=red, g=green, b=blue}
                AddColouredPin("groupleader", 1.0, "esoui/art/compass/groupleader.dds", 
                        XCP.groupPinCallback)
                COMPASS_PINS:RefreshPins("groupleader")
			end,
			default = XCP.defaultSettings.colourGroupLeader.r, XCP.defaultSettings.colourGroupLeader.g, 
                      XCP.defaultSettings.colourGroupLeader.b
        },
        ---------------------------- stable ----------------------------------
		[5] = {
			type = "checkbox",
			name = "Stables",
			tooltip = "Show stables on the compass.",
            width = "half",
			getFunc = function()
				return XCP.settings.showStables
			end,
			setFunc = function(value)
				XCP.settings.showStables = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showStables
		},
        [6] = {
            type = "colorpicker",
            name = "Stable icon",
            tooltip = "Colour of stable compass pin.",
            width = "half",
			getFunc = function()
				c = XCP.settings.colourStable
                return c.r, c.g, c.b
			end,
			setFunc = function(red, green, blue, alpha)
				XCP.settings.colourStable = {r=red, g=green, b=blue}
                AddColouredPin("XCP.stable", 0.1, "esoui/art/icons/servicemappins/servicepin_stable.dds", 
                        XCP.servicePinCallback)
                COMPASS_PINS:RefreshPins("XCP.stable")
			end,
			default = XCP.defaultSettings.colourGroupLeader.r, XCP.defaultSettings.colourGroupLeader.g, 
                      XCP.defaultSettings.colourGroupLeader.b
        },
        ---------------------------- bank ----------------------------------
		[7] = {
			type = "checkbox",
			name = "Banks",
			tooltip = "Show banks on the compass.",
            width = "half",
			getFunc = function()
				return XCP.settings.showBanks
			end,
			setFunc = function(value)
				XCP.settings.showBanks = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showBanks
		},
        [8] = {
            type = "colorpicker",
            name = "Bank icon",
            tooltip = "Colour of bank compass pin.",
            width = "half",
			getFunc = function()
				c = XCP.settings.colourBank
                return c.r, c.g, c.b
			end,
			setFunc = function(red, green, blue, alpha)
				XCP.settings.colourBank = {r=red, g=green, b=blue}
                AddColouredPin("XCP.bank", 0.1, "esoui/art/icons/servicemappins/servicepin_bank.dds", 
                        XCP.servicePinCallback)
                COMPASS_PINS:RefreshPins("XCP.bank")
			end,
			default = XCP.defaultSettings.colourBank.r, XCP.defaultSettings.colourBank.g, 
                      XCP.defaultSettings.colourBank.b
        },
        ---------------------------- refuge ----------------------------------
		[9] = {
			type = "checkbox",
			name = "Outlaw Refuges",
			tooltip = "Show outlaw refuges on the compass.",
            width = "half",
			getFunc = function()
				return XCP.settings.showRefuges
			end,
			setFunc = function(value)
				XCP.settings.showRefuges = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showRefuges
		},
        [10] = {
            type = "colorpicker",
            name = "Outlaw Refuge icon",
            tooltip = "Colour of outlaw refuge compass pin.",
            width = "half",
			getFunc = function()
				c = XCP.settings.colourRefuge
                return c.r, c.g, c.b
			end,
			setFunc = function(red, green, blue, alpha)
				XCP.settings.colourRefuge = {r=red, g=green, b=blue}
                AddColouredPin("XCP.refuge", 0.1, "esoui/art/icons/servicemappins/servicepin_fence.dds", 
                        XCP.servicePinCallback)
                COMPASS_PINS:RefreshPins("XCP.refuge")
			end,
			default = XCP.defaultSettings.colourRefuge.r, XCP.defaultSettings.colourRefuge.g, 
                      XCP.defaultSettings.colourRefuge.b
        },
        ---------------------------- refuge ----------------------------------
		[11] = {
			type = "checkbox",
			name = "Cardinal points",
			tooltip = "Show cardinal points (N/S/W/E) on the compass.",
            width = "half",
			getFunc = function()
				return XCP.settings.showCardinalPoints
			end,
			setFunc = function(value)
				XCP.settings.showCardinalPoints = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showCardinalPoints
		},
        [12] = {
            type = "colorpicker",
            name = "Cardinal point icon",
            tooltip = "Colour of compass pins for the cardinal points (N/S/W/E).",
            width = "half",
			getFunc = function()
				c = XCP.settings.colourCardinalPoint
                return c.r, c.g, c.b
			end,
			setFunc = function(red, green, blue, alpha)
				XCP.settings.colourCardinalPoint = {r=red, g=green, b=blue}
                AddColouredPin("XCP.north", 0.1, "ExtraCompassPins/textures/north.dds", XCP.cardinalPointCallback)
                AddColouredPin("XCP.south", 0.1, "ExtraCompassPins/textures/south.dds", XCP.cardinalPointCallback)
                AddColouredPin("XCP.east", 0.1, "ExtraCompassPins/textures/east.dds", XCP.cardinalPointCallback)
                AddColouredPin("XCP.west", 0.1, "ExtraCompassPins/textures/west.dds", XCP.cardinalPointCallback)
                COMPASS_PINS:RefreshPins("XCP.north")
			end,
			default = XCP.defaultSettings.colourCardinalPoint.r, XCP.defaultSettings.colourCardinalPoint.g, 
                      XCP.defaultSettings.colourCardinalPoint.b
        },
		[13] = {
			type = "slider",
			name = "Group Pin Refresh Interval (ms)",
			tooltip = "How often to refresh the group member pins, in milliseconds.",
            min = 100,
            max = 5000,
            step = 100,
			getFunc = function()
				return XCP.settings.pinRefreshms
			end,
			setFunc = function(value)
				XCP.settings.pinRefreshms = value
                EVENT_MANAGER:UnregisterForUpdate("ExtraCompassPins_Refresh")
                EVENT_MANAGER:RegisterForUpdate("ExtraCompassPins_Refresh", XCP.settings.pinRefreshms, RefreshVolatilePins)
			end,
			default = XCP.defaultSettings.pinRefreshms
		}
	}
	LAM2:RegisterOptionControls(XCP.name, optionsTable)
end


-- called whenever the compass is refreshed
-- must recreate all pins
function XCP.groupPinCallback()
    -- pintype matches the string given to AddCustomPin
    -- pin.x and pin.y are normalised map coordinates (0,0 = top left, 1,1 = bottom right)
    -- pintag is a way to pass around extra info about the pins, if you need to
    if XCP.settings.showGroupMembers and GetGroupSize() > 0 then
        -- player is grouped
        for n=1, GetGroupSize() do
            tag = GetGroupUnitTagByIndex(n)
            if (not IsUnitPlayer(tag)) and IsUnitOnline(tag) and IsGroupMemberInSameWorldAsPlayer(tag) 
              and IsGroupMemberInSameInstanceAsPlayer(tag) and IsGroupMemberInSameLayerAsPlayer(tag) then
                x,z,_,inCurrentMap = GetMapPlayerPosition(tag)        -- to groupN where N=GROUP_SIZE_MAX
                if inCurrentMap then
                    pintype = "groupmember"
                    pinColour = XCP.settings.colourGroupMember
                    if IsUnitGroupLeader(tag) then 
                        pintype = "groupleader" 
                        pinColour = XCP.settings.colourGroupLeader
                    end
                    COMPASS_PINS.pinManager:CreatePin( pintype, pinColour, x, z, GetUnitDisplayName(tag))
                end
            end
        end
    end
end


function XCP.cardinalPointCallback()
    if XCP.settings.showCardinalPoints then
        x, z = GetMapPlayerPosition("player")
        if x ~= lastPlayerX or z ~= lastPlayerZ then
            COMPASS_PINS.pinManager:CreatePin("XCP.north", XCP.settings.colourCardinalPoint, x, z-0.1)
            COMPASS_PINS.pinManager:CreatePin("XCP.south", XCP.settings.colourCardinalPoint, x, z+0.1)
            COMPASS_PINS.pinManager:CreatePin("XCP.east", XCP.settings.colourCardinalPoint, x+0.1, z)
            COMPASS_PINS.pinManager:CreatePin("XCP.west", XCP.settings.colourCardinalPoint, x-0.1, z)
        end
        lastPlayerX = X
        lastPlayerZ = z
    end
end



function XCP.servicePinCallback()
    for n=1, GetNumMapLocations() do
        if IsMapLocationVisible(n) then
            -- locName = GetMapLocation(n)
            icon,x,z = GetMapLocationIcon(n)
            if (icon and (icon ~= "")) then
                pathnames = split(icon, "/")
                filename = pathnames[table.getn(pathnames)]
                pintype = ""
                pinColour = {}

                if XCP.settings.showStables and filename == "servicepin_stable.dds" then 
                    pintype = "XCP.stable"
                    pinColour = XCP.settings.colourStable
                elseif XCP.settings.showBanks and filename == "servicepin_bank.dds" then 
                    pintype = "XCP.bank"
                    pinColour = XCP.settings.colourBank
                elseif XCP.settings.showRefuges and (filename == "servicepin_thievesguild.dds" or filename == "servicepin_fence.dds") then 
                    pintype = "XCP.refuge"
                    pinColour = XCP.settings.colourRefuge
                end

                if pintype ~= "" then
                    -- pass colour as pin.pinTag
                    COMPASS_PINS.pinManager:CreatePin( pintype, pinColour, x, z, "service")
                end
            end
        end
    end
end


function RefreshVolatilePins()
    if XCP.settings.showGroupMembers and GetGroupSize() > 0 then
        COMPASS_PINS.pinManager:RemovePins("groupleader")
        COMPASS_PINS:RefreshPins("groupmember")
        -- this also refreshes leader as they share the same callback function
    end
    COMPASS_PINS.pinManager:RemovePins("XCP.north")
    COMPASS_PINS.pinManager:RemovePins("XCP.south")
    COMPASS_PINS.pinManager:RemovePins("XCP.east")
    COMPASS_PINS:RefreshPins("XCP.west")     -- recreates NSEW
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

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- ====================== Events ==============================


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

