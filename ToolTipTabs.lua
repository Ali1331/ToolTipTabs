ToolTipTabs = LibStub("AceAddon-3.0"):NewAddon("ToolTipTabs")

local registryTab = {}
local registryTooltip = {}

local TOTAL_TOOLTIPS = 0
local TOTAL_TABS = 0
local BUTTON_HEIGHT = 44
local BUTTON_WIDTH = 44
local oldSetItemRef = nil
local questTabs = {}
local isDragging = false
local dragTab = nil
local dummyFrame = CreateFrame("Frame")
local db
local LBF = LibStub("LibButtonFacade", true)

local function tremovebyval(tab, val)
	for k, v in pairs(tab) do
		if v == val then
			table.remove(tab, k)
			return true
		end
	end
	return false
end

local function noBFAvailable() 
	return not LBF
end

local function disableCustom(info)
	return db.colors[info[#info-1]].choice < 3
end

local function isEnabled()
	return not db.enable
end

local function BF()
	if LBF then
		if db.BF.SkinID and LBF:GetNormalTexture(ToolTipTabs1) then
			return 1
		end
	else
		return nil
	end
end

local tabTypes = {
	item = {name = "Item", order = 1, preset = "Rarity Color",},
	spell = {name = "Spell", order = 2,},
	achievement = {name = "Achievement", order = 3, preset = "Completion Color",},
	talent = {name = "Talent", order = 4,},
	quest = {name = "Quest", order = 5, preset = "Difficulty Color",},
	enchant = {name = "Enchant", order = 6,},
	glyph = {name = "Glyph", order = 7,},
	instancelock = {name = "Instance Lock", order = 8},
	currency = {name = "Currency", order = 9},
}

local playerLevel = UnitLevel("player")
local GetQuestDifficultyColor = function(level)
	local levelDiff = level - playerLevel;
	local color;
	if ( levelDiff >= 5 ) then
		return QuestDifficultyColors["impossible"];
	elseif ( levelDiff >= 3 ) then
		return QuestDifficultyColors["verydifficult"];
	elseif ( levelDiff >= -2 ) then
		return QuestDifficultyColors["difficult"];
	elseif ( -levelDiff <= GetQuestGreenRange() ) then
		return QuestDifficultyColors["standard"];
	else
		return QuestDifficultyColors["trivial"];
	end
end

local function getIconColor(link, type)
	if db.colors[type].choice == 1 then
		if type == "achievement" then
			if select(4,strsplit(":",link)) == "1" then
				return 0, 1, 0
			end
			return 1, 0, 0
		--[[elseif type == "spell" then
			return 0,0,0
		elseif type == "enchant" then
			return 0,0,0]]
		elseif type == "quest" then
			local lvl = tonumber(select(3,strsplit(":", link)))
			if lvl == -1 then lvl = UnitLevel("player") end
			local c = GetQuestDifficultyColor(lvl)
			return c.r, c.g, c.b
		elseif type == "item" then
			local cr, cg, cb = GetItemQualityColor(select(3,GetItemInfo(link)) or 1) 
			return cr, cg, cb
		else
			if not db.BF.Colors.Normal then
				return 1, 1, 1
			else
				return db.BF.Colors.Normal[1],db.BF.Colors.Normal[2],db.BF.Colors.Normal[3]
			end
		end
	elseif db.colors[type].choice == 2 then
		if not db.BF.Colors.Normal then
			return 1, 1, 1
		else
			return db.BF.Colors.Normal[1],db.BF.Colors.Normal[2],db.BF.Colors.Normal[3]
		end
	end
	return db.colors[type].custom.r, db.colors[type].custom.g, db.colors[type].custom.b
end

local function getIcon(link, type)
	if type == "achievement" then
		return select(10,GetAchievementInfo(tonumber(link:match("^[^:]+:(%d+)"))))
	elseif type == "spell" then
		return select(3,GetSpellInfo(tonumber(link:match("^[^:]+:(%d+)"))))
	elseif type == "enchant" then
		return select(3,GetSpellInfo(tonumber(link:match("^[^:]+:(%d+)"))))	
	elseif type == "quest" then
		return "Interface\\Icons\\INV_MISC_QuestionMark"
	elseif type == "item" then
		return GetItemIcon(link)
	elseif type == "instancelock" then
		return "Interface\\Icons\\pvecurrency-justice"
	elseif type == "currency" then
		return "Interface\\Icons\\"..select(3,GetCurrencyInfo(tonumber(link:match("^[^:]+:(%d+)"))))		
	else
		return "Interface\\Icons\\Trade_Engineering"
	end
end

local function redrawTabs(tooltip)
	registryTooltip[tooltip].numTabs = 0
	local column = 0
	local row = 0
	
	for _, v in ipairs(registryTooltip[tooltip].tabList) do
		registryTooltip[tooltip].numTabs = registryTooltip[tooltip].numTabs + 1
		registryTab[v].obj:ClearAllPoints()
		registryTab[v].obj:SetPoint("TOPRIGHT", registryTooltip[tooltip].obj, "TOPLEFT", -(column*(BUTTON_WIDTH+db.hspacing))-db.xoffset, -(row*(BUTTON_HEIGHT+db.vspacing))-db.yoffset)
		if not registryTab[v].obj:IsShown() then
			registryTab[v].obj:Show()
		end
		row = row + 1
		if row == (db.columnsize) then
			row = 0
			column = column + 1
		end	
	end
end

local function recolorTab(tab)
	if not tab then return end
	if BF() then
		if registryTooltip[registryTab[tab].tooltip].currentTab == tab then
			registryTab[tab].obj.overlay:SetVertexColor(1.0, 1.0, 1.0)
			LBF:SetNormalVertexColor(registryTab[tab].obj, getIconColor(registryTab[tab].link, registryTab[tab].type))
		else
			local cr, cg, cb = getIconColor(registryTab[tab].link, registryTab[tab].type)
			registryTab[tab].obj.overlay:SetVertexColor(0.4, 0.4, 0.4)			
			LBF:SetNormalVertexColor(registryTab[tab].obj, cr*0.4, cg*0.4, cb*0.4)
		end
	else
		if registryTooltip[registryTab[tab].tooltip].currentTab == tab then
			registryTab[tab].obj.overlay:SetVertexColor(1.0, 1.0, 1.0)
		else
			registryTab[tab].obj.overlay:SetVertexColor(0.4, 0.4, 0.4)
		end
	end
end

local function findNextTab(tooltip)
	for _, v in ipairs(registryTooltip[tooltip].tabList) do
		if v ~= registryTooltip[tooltip].currentTab then
			return v
		end
	end
	return nil
end

local function switchToTab(tab)
	if not tab then return end
	local tooltip = registryTab[tab].tooltip
	local x, y = registryTooltip[tooltip].obj:GetLeft(), registryTooltip[tooltip].obj:GetTop()
	local oldTab = registryTooltip[tooltip].currentTab
	
	HideUIPanel(registryTooltip[tooltip].obj)
	ShowUIPanel(registryTooltip[tooltip].obj)
	if not registryTooltip[tooltip].obj:IsShown() then
		registryTooltip[tooltip].obj:SetOwner(UIParent, "ANCHOR_PRESERVE")
	end
	
	if tab ~= registryTooltip[tooltip].currentTab then 
		registryTooltip[tooltip].obj:SetHyperlink(registryTab[tab].link)
		registryTooltip[tooltip].currentTab = tab
	end
	
	if not registryTooltip[tooltip].obj:IsShown() then
		registryTooltip[tooltip].obj:SetHyperlink(registryTab[tab].link)
	end
	
	redrawTabs(tooltip)
	recolorTab(tab)
	recolorTab(oldTab)
	if x and y then
		registryTooltip[tooltip].obj:ClearAllPoints()
		registryTooltip[tooltip].obj:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	end
end

local function clearTooltip(tooltip)
	registryTooltip[tooltip].obj.cleared(registryTooltip[tooltip].obj)
	for _, v in ipairs(registryTooltip[tooltip].tabList) do
		registryTab[v].obj:Hide()
		registryTab[v].link = nil
		if questTabs[v] then 
			questTabs[v] = nil 
		end	
	end
	registryTooltip[tooltip].tabList = {}
	registryTooltip[tooltip].currentTab = nil
	registryTooltip[tooltip].numTabs = 0
	HideUIPanel(registryTooltip[tooltip].obj)
end

local function closeTab(tooltip, tab)
	if registryTooltip[tooltip].currentTab == tab then
		switchToTab(findNextTab(tooltip))
	end
	registryTab[tab].obj:Hide()
	registryTab[tab].link = nil
	if questTabs[tab] then 
		questTabs[tab] = nil 
	end
	registryTooltip[tooltip].numTabs = registryTooltip[tooltip].numTabs - 1
	tremovebyval(registryTooltip[tooltip].tabList, tab)
	if registryTooltip[tooltip].numTabs == 0 then
		registryTooltip[tooltip].currentTab = nil
		HideUIPanel(registryTooltip[tooltip].obj)
		return
	end
	redrawTabs(tooltip)
end

local function closeAllTooltips()
	for i in ipairs(registryTooltip) do
		clearTooltip(i)
	end
end

local function closeCurrentTab(tooltip)
	closeTab(tooltip:GetParent().id, registryTooltip[tooltip:GetParent().id].currentTab)
end

local function newTooltip()
	TOTAL_TOOLTIPS = TOTAL_TOOLTIPS + 1
	local tooltip = CreateFrame("GameTooltip", "ItemRefTooltip"..TOTAL_TOOLTIPS, UIParent, "TTT_ItemRefTooltipTemplate")
	tooltip:SetScript("OnDragStop", tooltip.StopMovingOrSizing)
	tooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	tinsert(UISpecialFrames, tooltip:GetName())
	
	tooltip.id = TOTAL_TOOLTIPS -- lame but easier
	registryTooltip[TOTAL_TOOLTIPS] = {}
	registryTooltip[TOTAL_TOOLTIPS].numTabs = 0
	registryTooltip[TOTAL_TOOLTIPS].currentTab = nil
	registryTooltip[TOTAL_TOOLTIPS].tabList = {}
	registryTooltip[TOTAL_TOOLTIPS].obj = tooltip
	registryTooltip[TOTAL_TOOLTIPS].obj.cleared = registryTooltip[TOTAL_TOOLTIPS].obj:GetScript("OnTooltipCleared")
	registryTooltip[TOTAL_TOOLTIPS].obj.closeCurrent = CreateFrame("Button", nil, tooltip, "UIPanelCloseButton")
	registryTooltip[TOTAL_TOOLTIPS].obj.closeCurrent:SetScript("OnClick", closeCurrentTab)
	registryTooltip[TOTAL_TOOLTIPS].obj.closeCurrent:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 18, -5)
	registryTooltip[TOTAL_TOOLTIPS].obj.closeAll = CreateFrame("Button", nil, tooltip, "UIPanelCloseButton")
	registryTooltip[TOTAL_TOOLTIPS].obj.closeAll:SetScript("OnClick", closeAllTooltips)
	registryTooltip[TOTAL_TOOLTIPS].obj.closeAll:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", -5, -5)
	return TOTAL_TOOLTIPS
end

local function getTooltip()
	for i in ipairs(registryTooltip) do
		if registryTooltip[i].numTabs == 0 then
			return i
		end
	end
	return newTooltip()
end

local function isAvailableTooltip()
	for i in ipairs(registryTooltip) do
		if registryTooltip[i].numTabs == 0 then
			return true
		end
	end
	if (TOTAL_TOOLTIPS-1) < db.maxtooltips then
		return true
	end
	return false
end

local function click(tab)
	tab = tab.id
	if registryTab[tab].link then
		if IsModifiedClick("CHATLINK") then
			local edit = ChatEdit_GetActiveWindow()
			if edit and edit:IsVisible() then
				edit:Insert(registryTab[tab].text)
			end
		elseif IsModifiedClick("DRESSUP") then
			if registryTab[tab].type == "achievement" then 
				if not (AchievementFrame and AchievementFrame:IsShown()) then
					ToggleAchievementFrame()
				end
				local id = tonumber(registryTab[tab].link:match("achievement:(%d+)"))
				if not id then return end
				AchievementFrame_SelectAchievement(id)
			elseif registryTab[tab].type == "item" then
				DressUpItemLink(registryTab[tab].link)
			end
		else
			switchToTab(tab)
		end
	end
end

local function moveTabToTooltip(tab, tooltip)
	if registryTab[tab].tooltip == tooltip then return end
	
	local oldTooltip = registryTab[tab].tooltip
	
	registryTooltip[oldTooltip].numTabs = registryTooltip[oldTooltip].numTabs - 1
	tremovebyval(registryTooltip[oldTooltip].tabList, tab)
	tinsert(registryTooltip[tooltip].tabList, tab)
	
	if tab == registryTooltip[oldTooltip].currentTab then
		if registryTooltip[oldTooltip].numTabs > 0 then
			switchToTab(findNextTab(oldTooltip))
		else
			registryTooltip[oldTooltip].currentTab = nil
			HideUIPanel(registryTooltip[oldTooltip].obj)
		end	
	else
		redrawTabs(oldTooltip)
	end
	
	registryTooltip[tooltip].numTabs = registryTooltip[tooltip].numTabs + 1	
	registryTab[tab].tooltip = tooltip
	registryTab[tab].obj:SetParent(registryTooltip[tooltip].obj)
	switchToTab(tab)
end

local function dragStart(self)
	isDragging = true
	dragTab = self.id
end

local function getCursorPositionOnFrame(frame)
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	local framescale = frame:GetScale()
	x = x / framescale / scale
	y = y / framescale / scale
	return x, y
end

local function placeTooltipOnCursor(tooltip)
	tooltip:ClearAllPoints()
	local x, y = getCursorPositionOnFrame(tooltip)
	tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x+(BUTTON_WIDTH/2), y+(BUTTON_HEIGHT/2))
end

local function dragStop(self) 
	if db.multitooltip == true then
		local focus = GetMouseFocus()
		if focus then
			if registryTooltip[focus.id] and registryTooltip[focus.id].obj == focus then
				moveTabToTooltip(dragTab, focus.id)
				SetCursor("POINT_CURSOR")
			else
				if registryTooltip[registryTab[self.id].tooltip].numTabs > 1 and isAvailableTooltip() then
					local newTooltip = getTooltip()
					placeTooltipOnCursor(registryTooltip[newTooltip].obj)
					moveTabToTooltip(dragTab, newTooltip)
				else
					placeTooltipOnCursor(registryTooltip[registryTab[self.id].tooltip].obj)
				end
			end
		end
	else
		placeTooltipOnCursor(registryTooltip[registryTab[self.id].tooltip].obj)
	end
	isDragging = false
	dragTab = nil		
	SetCursor(nil)		
end

local function redrawAll()
	for i in ipairs(registryTooltip) do
		redrawTabs(i)
	end
end

local function recolorAll(type)
	for i in ipairs(registryTab) do
		if registryTab[i].link and (not type or registryTab[i].type == type) then
			recolorTab(i)
		end	
	end
end

function ToolTipTabs:AddTab(tooltip, link, type, text)
	local tab
	for i in ipairs(registryTab) do
		if not registryTab[i].link then
			tab = i
			break
		end
	end

	if tab then
		registryTab[tab].obj:SetParent(registryTooltip[tooltip].obj)
		registryTab[tab].link = link
		registryTab[tab].type = type
		registryTab[tab].text = text
		registryTab[tab].tooltip = tooltip
		registryTab[tab].obj.overlay:SetTexture(getIcon(link, type))
	else
		TOTAL_TABS = TOTAL_TABS+1
		tab = TOTAL_TABS
		registryTab[tab] = {}
		registryTab[tab].obj = CreateFrame("Button", "ToolTipTabs"..tab, registryTooltip[tooltip].obj)
		registryTab[tab].obj.id = tab
		registryTab[tab].obj:SetWidth(BUTTON_WIDTH)
		registryTab[tab].obj:SetHeight(BUTTON_HEIGHT)
		registryTab[tab].obj:SetScript("OnDragStart", dragStart)
		registryTab[tab].obj:SetScript("OnDragStop", dragStop)
		registryTab[tab].obj:RegisterForDrag("LeftButton")
		registryTab[tab].obj:SetScript("OnClick", click)
		registryTab[tab].obj:SetScale(db.scale)
		
		registryTab[tab].obj.overlay = registryTab[tab].obj:CreateTexture(nil,"ARTWORK")
		registryTab[tab].obj.overlay:SetAllPoints()
		registryTab[tab].obj.overlay:SetTexture(getIcon(link, type))
		
		if LBF then LBF:Group("ToolTipTabs", "Tabs"):AddButton(registryTab[tab].obj, {Icon=registryTab[tab].obj.overlay}) end

		registryTab[tab].link = link
		registryTab[tab].type = type
		registryTab[tab].text = text
		registryTab[tab].tooltip = tooltip	
	end
	
	registryTooltip[tooltip].numTabs = registryTooltip[tooltip].numTabs + 1
	tinsert(registryTooltip[tooltip].tabList, tab)

	if type == "quest" then 
		questTabs[tab] = true 
	end
	switchToTab(tab)
	return tab	
end

local function returnStrippedLink(link)
	local tbl = {strsplit(":", link)}
	if tbl[1] == "item" then
		if tbl[10] then -- Some links are purely item:id (Namely the emote printed when using Titanium Seal of Dalaran, the link printed is simply item:id
			if select(3, GetItemInfo(link)) ~= 7 then -- Heirloom item, keep the given level
				tbl[10] = MAX_PLAYER_LEVEL
			end
			if tonumber(tbl[8]) >= 0 then -- Has a non-negative suffixID, ignore the uniqueID
				tbl[9] = 0
			end
		else -- if the link is incomplete, fill it in!
			for i=1, 9 do
				if not tbl[i] then
					tbl[i] = 0
				end
			end
			tbl[10] = MAX_PLAYER_LEVEL
		end
	end
	link = strjoin(":", unpack(tbl))
	return link, tbl[1]
end

local function closeExtraTabs()
	local maxTabs = db.maxcolumns*db.columnsize
	for i, v in ipairs(registryTooltip) do
		if #v.tabList > maxTabs then
			switchToTab(v.tabList[1])
			for t=#v.tabList, maxTabs+1, -1 do
				registryTab[v.tabList[t]].obj:Hide()
				registryTab[v.tabList[t]].link = nil
				if questTabs[v.tabList[t]] then 
					questTabs[v.tabList[t]] = nil 
				end	
				tremove(registryTooltip[i].tabList, t)				
			end
			registryTooltip[i].numTabs = maxTabs
		end
	end
end

function ToolTipTabs:OnInitialize()
	self.options = {
		type = "group",	
		childGroups = "tab",
		get = function(info)
			return db[info[#info]]
		end,	
		args = {
			show = {
				name = "Show tooltips", type = "execute",
				guiHidden = true,
				func = function()
					for i in ipairs(registryTooltip) do
						if registryTooltip[i].numTabs > 0 then	
							switchToTab(registryTooltip[i].currentTab)
						end
					end
				end,
			},
			desc = {
				name = "ToolTipTabs adds tabbed and multi tooltip functionality to the default UI\n", type = "description", order = 1,
				fontSize = "medium",
			},
			enable = {
				name = "Enable", type = "toggle", order = 2,
				desc = "Enable/Disable this addon",
				set = function(info, v) 
					db.enable = v 
					if v == true then 
						ToolTipTabs:OnEnable() 
					elseif v == false then 
						ToolTipTabs:OnDisable() 
					end 
				end,
			},
			appearance = {
				name = "Appearance", type = "group", order = 3,
				disabled = isEnabled,
				set = function(info, valueOrR, g, b)
					if info[#info] == "custom" then
						db.colors[info[#info-1]][info[#info]].r = valueOrR
						db.colors[info[#info-1]][info[#info]].g = g
						db.colors[info[#info-1]][info[#info]].b = b
					else
						db.colors[info[#info-1]][info[#info]] = valueOrR
					end
					recolorAll(info[#info-1])
				end,
				get = function(info)
					local t = db.colors[info[#info-1]][info[#info]]
					if info[#info] == "custom" then
						return t.r, t.g, t.b
					end
					return t
				end,			
				args = {
					scale = {
						name = "Tab scale", type = "range", order = 1,
						min = 0.1, max = 2, step = 0.01, isPercent = true,
						set = function(info, v)
							db.scale = v
							for i in ipairs(registryTab) do
								registryTab[i].obj:SetScale(v)
							end
						end,
						get = function(info)
							return db.scale
						end,
					},		
					format1 = {
						name = "\n\nBorder Colors (Requires ButtonFacade)", type = "description", order = 2,
						fontSize = "medium", width = "full",
					},
				},
			},
			positioning = {
				name = "Positioning", type = "group", order = 4,
				disabled = isEnabled,
				set = function(info, v)
					self.db.profile[info[#info]] = v
					redrawAll()
				end,
				args = {
					format1 = {
						name = "The offset options allow you to alter the point on the tooltip where the tabs begin to form, by changing these values to be greater, the tabs will start further to the left and further down the side of the tooltip.\n",
						type = "description", order = 1,
						fontSize = "medium",
					},
					xoffset = {
						name = "X offset", type = "range", order = 2, 
						min = 0, max = 10, step = 1,
					},
					yoffset = {
						name = "Y offset", type = "range", order = 3,
						min = 0, max = 10, step = 1,
					},
					format2 = {
						name = "\n\nAltering the spacing values will increase the gap between the tabs themselves, this can be useful if you have a ButtonFacade skin that is overlapping or if you just like the look of tabs with more space on the sides.\n",
						type = "description", order = 4,
						fontSize = "medium",
					},				
					vspacing = {
						name = "Vertical spacing", type = "range", order = 5,
						min = 0, max = 10, step = 1,
					},
					hspacing = {
						name = "Horizontal spacing", type = "range", order = 6,
						min = 0, max = 10, step = 1,
					},					
				},
			},
			tabs = {
				name = "Tabs", type = "group", order = 5,
				disabled = isEnabled,			
				args = {
					columnsize = {
						name = "Tabs per column", type = "range", order = 1,					
						min = 1, max = 5, step = 1,				
						set = function(info, v) 
							db.columnsize = v
							closeExtraTabs()
							redrawAll() 
						end,
					},
					maxcolumns = {
						name = "Maximum columns",type = "range", order = 2,
						min = 1, max = 4, step = 1,
						set = function(info, v) 
							if v < db.maxcolumns then
								db.maxcolumns = v 						
								closeExtraTabs()
							else
								db.maxcolumns = v  
							end
						end,
					},
					format1 = {
						name = "\n\nThe options below allow you to choose the behaviour of the addon when opening a link while at the tab and tooltip limit.", type = "description", order = 3,
						width = "full", fontSize = "medium",
					},
					maxxedbehaviour = {
						type = "select", name = " ",
						order = 4, width = "full",
						values = {
							[1] = "Remove the first tab that isn't currently viewed on first tooltip",
							[2] = "Reset the first tooltip"					
						},
						set = function(info, v)
							db.maxxedbehaviour = v
						end,
					},
				},
			},
			multitooltip = {
				name = "Multi-tooltip", type = "group",	order = 6,
				disabled = isEnabled,	
				args = {
					format1 = {
						name = "If multiple tooltips is enabled in the option below instead of moving the tooltip when you drag a tab, that tab will be added to a newly created tooltip. You can also drag tabs from one tooltip to another.\n",
						type = "description", order = 1, fontSize = "medium",
					},
					multitooltip = {
						name = "Multi-Tooltip", type = "toggle", order = 2,
						desc = "Use multiple tooltips",
						set = function(info, v) 
							db.multitooltip = v 
							if v == false then 
								for i in ipairs(registryTooltip) do
									if registryTooltip[i].obj ~= ItemRefTooltip then
										clearTooltip(i)
									end
								end 
							end 
						end,
					},
					format2 = {
						name = "\nTotal number of additional tooltips allowed at any one time.\n", type = "description", order = 3, fontSize = "medium",
					},
					maxtooltips = {
						name = "Maximum additional tooltips", type = "range", order = 4,
						min = 1, max = 5, step = 1,					
						disabled = function() 
							if not db.multitooltip or not db.enable then
								return true
							else
								return false
							end
						end,
						set = function(info, v) 
							if v < db.maxtooltips then
								db.maxtooltips = v 
								for i in ipairs(registryTooltip) do
									if i > v then
										clearTooltip(i)
									end
								end
							else
								db.maxtooltips = v 
							end
						end,
					},
				},
			},
		},
	}
	for k, v in pairs(tabTypes) do
		self.options.args.appearance.args[k] = {
			name = v.name, type = "group", order = v.order+2,
			disabled = noBFAvailable,
			args = {
				choice = {
					name = "Color Type", type = "select", order = 1,
					values = {[1] = v.preset or "No Preset Available", [2] = "ButtonFacade Color", [3] = "Custom",},
				},
				custom = {
					name = "Custom Color", type = "color", order = 2,
					disabled = disableCustom,
				},
			},
		}
	end

	self.db = LibStub("AceDB-3.0"):New("ToolTipTabsDB", {
		profile = {
			enable = true,
			multitooltip = true,
			maxtooltips = 3,
			columnsize = 4,
			maxcolumns = 4,
			maxxedbehaviour = 1,
			scale = 1,
			vspacing = 0,
			hspacing = 0,
			xoffset = 0,
			yoffset = 0,
			BF = {
			},
			colors = {
				item = {
					choice = 1,
					custom = {
						r = 0.3, g = 0.3, b = 0.7,
					},
				},	
				spell = {
					choice = 2,
					custom = {
						r = 0.3, g = 0.3, b = 0.7,
					},
				},
				achievement = {
					choice = 1,
					custom = {
						r = 0.3, g = 0.3, b = 0.7,
					},
				},
				talent = {
					choice = 2,
					custom = {
						r = 0.3, g = 0.3, b = 0.7,
					},
				},
				quest = {
					choice = 1,
					custom = {
						r = 0.3, g = 0.3, b = 0.7,
					},
				},	
				enchant = {
					choice = 2,
					custom = {
						r = 0.3, g = 0.3, b = 0.7,
					},
				},
				glyph = {
					choice = 2,
					custom = {
						r = 0.3, g = 0.3, b = 0.7,
					},
				},	
				instancelock = {
					choice = 2,
					custom = {
						r = 1.0, g = 0.5, b = 0,
					},
				},
				currency = {
					choice = 3,
					custom = {
						r = 0.1, g = 1.0, b = 0.1,
					},
				},
			},
		},
	}, "Default")

	LibStub("AceConfig-3.0"):RegisterOptionsTable("ToolTipTabs", ToolTipTabs.options, {"ttt","tooltiptabs"})
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ToolTipTabs")
	
	db = ToolTipTabs.db.profile
	
	TOTAL_TOOLTIPS = 1
	ItemRefTooltip.id = TOTAL_TOOLTIPS
	registryTooltip[TOTAL_TOOLTIPS] = {}
	registryTooltip[TOTAL_TOOLTIPS].numTabs = 0
	registryTooltip[TOTAL_TOOLTIPS].currentTab = nil
	registryTooltip[TOTAL_TOOLTIPS].tabList = {}
	registryTooltip[TOTAL_TOOLTIPS].obj = ItemRefTooltip
	registryTooltip[TOTAL_TOOLTIPS].obj.cleared = registryTooltip[TOTAL_TOOLTIPS].obj:GetScript("OnTooltipCleared")
	registryTooltip[TOTAL_TOOLTIPS].obj.closeCurrent = CreateFrame("Button", nil, ItemRefTooltip, "UIPanelCloseButton")
	registryTooltip[TOTAL_TOOLTIPS].obj.closeCurrent:SetScript("OnClick", closeCurrentTab)
	registryTooltip[TOTAL_TOOLTIPS].obj.closeCurrent:SetPoint("BOTTOMLEFT", ItemRefTooltip, "TOPLEFT", 18, -5)
	registryTooltip[TOTAL_TOOLTIPS].obj.closeAll = CreateFrame("Button", nil, ItemRefTooltip, "UIPanelCloseButton")
	registryTooltip[TOTAL_TOOLTIPS].obj.closeAll:SetScript("OnClick", closeAllTooltips)
	registryTooltip[TOTAL_TOOLTIPS].obj.closeAll:SetPoint("BOTTOMLEFT", ItemRefTooltip, "TOPLEFT", -5, -5)
	
	dummyFrame:RegisterEvent("PLAYER_LEVEL_UP") 
	dummyFrame:SetScript("OnEvent", function(self, event, newLevel)
		playerLevel = newLevel
		for k in pairs(questTabs) do
			recolorTab(k)
		end
	end)
	dummyFrame:SetScript("OnUpdate", function(self, elapsed)
		if isDragging == true then
			if dragTab then
				SetCursor(registryTab[dragTab].obj.overlay:GetTexture())
			end
		end
	end)	
end

function ToolTipTabs:OnEnable()
	if LBF then
		db.BF = db.BF or {} 
		LBF:Group("ToolTipTabs", "Tabs"):Skin(db.BF.SkinID, db.BF.Gloss, db.BF.Backdrop, db.BF.Colors)
		LBF:RegisterSkinCallback("ToolTipTabs", function(_, SkinID, Gloss, Backdrop, Group, _, Colors)
			db.BF.SkinID = SkinID
			db.BF.Gloss = Gloss
			db.BF.Backdrop = Backdrop
			db.BF.Colors = Colors
			recolorAll()
		end, self)
	end	
	
	oldSetItemRef = SetItemRef
	SetItemRef = function(link, text, button, chatframe)
		if not link then return end
		if IsModifiedClick() then
			return oldSetItemRef(link, text, button, chatframe)
		end
		local type
		link, type = returnStrippedLink(link)
		if type == "trade" then
			oldSetItemRef(link, text, button, chatframe)
			if registryTooltip[ItemRefTooltip.id].numTabs > 0 and ItemRefTooltip:IsShown() then
				local oldTab = registryTooltip[ItemRefTooltip.id].currentTab
				registryTooltip[ItemRefTooltip.id].currentTab = nil
				switchToTab(oldTab)
			end
			return
		end	
		if not db.colors[type] then
			return oldSetItemRef(link, text, button, chatframe)
		end
		for i in ipairs(registryTab) do
			if registryTab[i].link == link then
				if registryTooltip[registryTab[i].tooltip].currentTab == i then
					if registryTooltip[registryTab[i].tooltip].obj:IsShown() then
						HideUIPanel(registryTooltip[registryTab[i].tooltip].obj)
					else
						switchToTab(i)
					end
				else
					switchToTab(i)
				end
				return
			end
		end
		if db.multitooltip == false then
			if registryTooltip[ItemRefTooltip.id].numTabs < db.maxcolumns*db.columnsize then
				ToolTipTabs:AddTab(ItemRefTooltip.id, link, type, text)
			else
				if db.maxxedbehaviour == 1 then
					local firstTab = findNextTab(ItemRefTooltip.id) or registryTooltip[ItemRefTooltip.id].currentTab
					registryTab[firstTab].obj.overlay:SetTexture(getIcon(link, type))
					registryTab[firstTab].link = link
					registryTab[firstTab].text = text
					registryTab[firstTab].type = type
					if type == "quest" then 
						questTabs[firstTab] = true 
					else 
						questTabs[firstTab] = nil 
					end
					switchToTab(firstTab)
				elseif db.maxxedbehaviour == 2 then
					clearTooltip(ItemRefTooltip.id)
					ToolTipTabs:AddTab(ItemRefTooltip.id, link, type, text)
				end
			end
		else
			local tooltip
			for i in ipairs(registryTooltip) do
				if registryTooltip[i].numTabs < (db.maxcolumns*db.columnsize) then
					tooltip = i
					break
				end
			end
			if tooltip then
				ToolTipTabs:AddTab(tooltip, link, type, text)
			else
				if TOTAL_TOOLTIPS < db.maxtooltips then
					ToolTipTabs:AddTab(newTooltip(), link, type, text)
				else
					if db.maxxedbehaviour == 1 then
						local firstTab = findNextTab(ItemRefTooltip.id) or registryTooltip[ItemRefTooltip.id].currentTab
						registryTab[firstTab].obj.overlay:SetTexture(getIcon(link, type))
						registryTab[firstTab].link = link
						registryTab[firstTab].text = text
						registryTab[firstTab].type = type
						if type == "quest" then 
							questTabs[firstTab] = true 
						else 
							questTabs[firstTab] = nil 
						end						
						switchToTab(firstTab)
					elseif db.maxxedbehaviour == 2 then
						clearTooltip(ItemRefTooltip.id)
						ToolTipTabs:AddTab(ItemRefTooltip.id, link, type, text)
					end
				end
			end
		end
	end	
	if ItemRefTooltip:IsShown() then
		HideUIPanel(ItemRefTooltip)
	end
	registryTooltip[ItemRefTooltip.id].obj.closeCurrent:Show()
	registryTooltip[ItemRefTooltip.id].obj.closeAll:Show()
	if not db.enable then
		self:OnDisable()
	end
end

function ToolTipTabs:OnDisable()
	for i in ipairs(registryTab) do
		if registryTab[i].link then
			registryTab[i].obj:Hide()
			registryTab[i].link = nil
			if questTabs[i] then 
				questTabs[i] = nil
			end	
		end
	end
	for i in ipairs(registryTooltip) do
		registryTooltip[i].numTabs = 0
		registryTooltip[i].currentTab = nil
		registryTooltip[i].tabList = {}
		registryTooltip[i].obj.closeAll:Hide()
		registryTooltip[i].obj.closeCurrent:Hide()
		registryTooltip[i].obj:Hide()
	end
	SetItemRef = oldSetItemRef
	oldSetItemRef = nil
end
