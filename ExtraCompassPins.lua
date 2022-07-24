-- TODO
-- optional town locations - at least bank, stable
-- optional POIs

-- First, we create a namespace for our addon by declaring a top-level table that will hold everything else.
ExtraCompassPins = {}
local XCP = ExtraCompassPins
--local LMP = LibMapPins

local COLOR_WHITE = ZO_ColorDef:New("#ffffff")
local COLOR_MINT_GREEN = ZO_ColorDef:New("c8ffd2")
local COLOR_GOLD = ZO_ColorDef:New("#ffcc66")
local COLOR_TAN = ZO_ColorDef:New("#f9d286")
local COLOR_LAVENDER = ZO_ColorDef:New("#f9e6ff")
local COLOR_LIGHT_GREY = ZO_ColorDef:New("#eeeeee")
local COLOR_LIGHT_BLUE = ZO_ColorDef:New("#1010ee")

-- This isn't strictly necessary, but we'll use this string later when registering events.
-- Better to define it in a single place rather than retyping the same string.
XCP.name = "ExtraCompassPins"

XCP.defaultSettings = {
    showStables = true,
    showBanks = true,
    showRefuges = true,
    showGroupMembers = true,
    showCardinalPoints = true,
    pinRefreshms = 500,
    colourStable = COLOR_TAN,
    colourBank = COLOR_GOLD,
    colourRefuge = COLOR_LIGHT_GREY,
    colourGroupMember = COLOR_LAVENDER,
    colourGroupLeader = COLOR_GOLD,
    colourCardinalPoint = COLOR_LIGHT_BLUE
}


-- Next we create a function that will initialize our addon
function XCP.Initialize()
    XCP.settings = ZO_SavedVars:NewAccountWide("ExtraCompassPins_SV", 1, nil, XCP.defaultSettings)
    XCP.SetupSettings()

    AddColouredPin("XCP.stable", 0.1, "esoui/art/icons/servicemappins/servicepin_stable.dds", 
                XCP.servicePinCallback, XCP.settings.colourStable)
    AddColouredPin("XCP.bank", 0.1, "esoui/art/icons/servicemappins/servicepin_bank.dds", 
                XCP.servicePinCallback, XCP.settings.colourBank)
    AddColouredPin("XCP.refuge", 0.1, "esoui/art/icons/servicemappins/servicepin_fence.dds", 
                XCP.servicePinCallback, XCP.settings.colourRefuge)
    AddColouredPin("groupmember", 1.0, "esoui/art/compass/groupmember.dds", 
                XCP.groupPinCallback, XCP.settings.colourGroupMember)
    AddColouredPin("groupleader", 1.0, "esoui/art/compass/groupleader.dds", 
                XCP.groupPinCallback, XCP.settings.colourGroupLeader)
    AddColouredPin("XCP.north", 1.0, "ExtraCompassPins/textures/north.dds", 
                XCP.servicePinCallback, XCP.settings.colourCardinalPoint)
    AddColouredPin("XCP.south", 1.0, "ExtraCompassPins/textures/south.dds", 
                XCP.servicePinCallback, XCP.settings.colourCardinalPoint)
    AddColouredPin("XCP.east", 1.0, "ExtraCompassPins/textures/east.dds", 
                XCP.servicePinCallback, XCP.settings.colourCardinalPoint)
    AddColouredPin("XCP.west", 1.0, "ExtraCompassPins/textures/west.dds", 
                XCP.servicePinCallback, XCP.settings.colourCardinalPoint)

    COMPASS_PINS:RefreshPins()
end


function AddColouredPin(pintype, maxDist, texture, callback, pinColour)
    if pinColour then
        red, green, blue = pinColour:UnpackRGBA()
        if red and red>1 then red = red/255.0 end
        if green and green>1 then green = green/255.0 end
        if blue and blue>1 then blue = blue/255.0 end
    else
        red, green, blue = 1, 1, 1
    end

    COMPASS_PINS:AddCustomPin(pintype, callback, 
    { 
      maxDistance = maxDist, 
      texture = texture,
    --   sizeCallback = function(pin, angle, normAngle, normDistance) 
    --         local BASE_ICON_SIZE = 48
    --         if normDistance < 0.05 then
    --             -- baseline icon size is 32x32
    --             -- increase size when close to icon, up to double (64x64)
    --             -- df("Size callback: pin.getnamedchild %s, SetDimension %s",
    --             --  dump(pin:GetNamedChild("Background")), dump(pin:GetNamedChild("Background").SetDimensions))
    --             dim = math.floor(BASE_ICON_SIZE + (BASE_ICON_SIZE * (0.05 - normDistance)/0.05))
    --         else
    --             dim = BASE_ICON_SIZE
    --         end
    --         --df("Sizecallback normDistance=%f, dim=%s", normDistance, dim)
    --         pin:GetNamedChild("Background"):SetDimensions(dim, dim)
    --     end,
      additionalLayout = {
            -- "decorator" function, called on each pin after it's created
            function (pin, angle, normAngle, normDistance)
                -- r,g,b,a
                if pin and red then 
                    pin:GetNamedChild("Background"):SetColor(red, green, blue, 1)
                    if pintype in {"XCP.north", "XCP.south", "XCP.east", "XCP.west"} then
                        pin:GetNamedChild("Background"):SetDrawTier("HIGH")
                        -- SetDrawLayer("OVERLAY")
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
				return XCP.settings.colourGroupMember:UnpackRGBA()
			end,
			setFunc = function(red, green, blue, alpha)
				XCP.settings.colourGroupMember = ZO_ColorDef:New(red, green, blue, alpha)
                AddColouredPin("groupmember", 1.0, "esoui/art/compass/groupmember.dds", 
                        XCP.groupPinCallback, XCP.settings.colourGroupMember)
                COMPASS_PINS:RefreshPins("groupmember")
			end,
			default = XCP.defaultSettings.colourGroupMember
        },
		[3] = {
			type = "checkbox",
			name = "Stables",
			tooltip = "Show stables on the compass.",
            -- width = "half",
			getFunc = function()
				return XCP.settings.showStables
			end,
			setFunc = function(value)
				XCP.settings.showStables = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showStables
		},
		[4] = {
			type = "checkbox",
			name = "Banks",
			tooltip = "Show banks on the compass.",
            -- width = "half",
			getFunc = function()
				return XCP.settings.showBanks
			end,
			setFunc = function(value)
				XCP.settings.showBanks = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showBanks
		},
		[5] = {
			type = "checkbox",
			name = "Outlaw Refuges",
			tooltip = "Show outlaw refuges on the compass.",
            -- width = "half",
			getFunc = function()
				return XCP.settings.showRefuges
			end,
			setFunc = function(value)
				XCP.settings.showRefuges = value
                COMPASS_PINS:RefreshPins()
			end,
			default = XCP.defaultSettings.showRefuges
		},
		[6] = {
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
end


function XCP.servicePinCallback()
    for n=1, GetNumMapLocations() do
        if IsMapLocationVisible(n) then
            -- locName = GetMapLocation(n)
            icon,x,y = GetMapLocationIcon(n)
            if (icon and (icon ~= "")) then
                pathnames = split(icon, "/")
                filename = pathnames[table.getn(pathnames)]
                pintype = ""

                if XCP.settings.showStables and filename == "servicepin_stable.dds" then 
                    pintype = "XCP.stable"
                elseif XCP.settings.showBanks and filename == "servicepin_bank.dds" then 
                    pintype = "XCP.bank"
                elseif XCP.settings.showRefuges and (filename == "servicepin_thievesguild.dds" or filename == "servicepin_fence.dds") then 
                    pintype = "XCP.refuge"
                end

                if pintype ~= "" then
                    df("Created town service icon: '%s'", filename)
                    COMPASS_PINS.pinManager:CreatePin( pintype, {}, x, y, "service")
                end
            end
        end
    end

    -- cardinal compass directions
    if XCP.settings.showCardinalPoints then
        COMPASS_PINS.pinManager:CreatePin("XCP.north", {}, 0.5, 0)
        COMPASS_PINS.pinManager:CreatePin("XCP.south", {}, 0.5, 1.0)
        COMPASS_PINS.pinManager:CreatePin("XCP.east", {}, 1.0, 0.5)
        COMPASS_PINS.pinManager:CreatePin("XCP.west", {}, 0, 0.5)
    end
end


function RefreshVolatilePins()
    if XCP.settings.showGroupMembers and GetGroupSize() > 0 then
        COMPASS_PINS:RefreshPins("groupmember")
        -- this also refreshes leader as they share the same callback function
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

-- call a function every X milliseconds. String is a unique identifier.
-- we only need to do this if the pins denote things that are changing their position,
-- such as players or NPCs. Otherwise the pins will not refresh/move until the player
-- travels to a new map.
EVENT_MANAGER:RegisterForUpdate("ExtraCompassPins_Refresh", XCP.settings.pinRefreshms or 500, RefreshVolatilePins)
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

