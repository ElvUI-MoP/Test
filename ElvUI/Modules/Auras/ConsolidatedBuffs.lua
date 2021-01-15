local E, L, V, P, G = unpack(select(2, ...))
local A = E:GetModule("Auras")
local LSM = E.Libs.LSM

local _G = _G
local unpack = unpack
local wipe = wipe
local format = format

local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local CreateFrame = CreateFrame
local GetTime = GetTime
local GetRaidBuffTrayAuraInfo = GetRaidBuffTrayAuraInfo

local NUM_LE_RAID_BUFF_TYPES = NUM_LE_RAID_BUFF_TYPES

local Masque = E.Libs.Masque
local MasqueGroup = Masque and Masque:Group("ElvUI", "Consolidated Buffs")

local ignoreIcons = {}

A.DefaultIcons = {
	[1] = [[Interface\Icons\Spell_Magic_GreaterBlessingofKings]],	-- Stats
	[2] = [[Interface\Icons\Spell_Holy_WordFortitude]],				-- Stamina
	[3] = [[Interface\Icons\INV_Misc_Horn_02]],						-- Attack Power
	[4] = [[Interface\Icons\INV_Helmet_08]],						-- Attack Speed
	[5] = [[Interface\Icons\Spell_Holy_MagicalSentry]],				-- Spell Power
	[6] = [[Interface\Icons\Spell_Shadow_SpectralSight]],			-- Spell Haste
	[7] = [[Interface\Icons\ability_monk_prideofthetiger]],			-- Critical Strike
	[8] = [[Interface\Icons\Spell_Holy_GreaterBlessingofKings]]		-- Mastery
}

function A:UpdateConsolidatedTime(elapsed)
	if self.expiration == nil then return end

	self.expiration = self.expiration - elapsed

	if self.nextUpdate > 0 then
		self.nextUpdate = self.nextUpdate - elapsed
		return
	end

	if self.expiration <= 0 then
		self.timer:SetText("")
		self:SetScript("OnUpdate", nil)
		return
	end

	local threshold = E.db.auras.cooldown.threshold
	if not threshold then threshold = E.TimeThreshold end

	local hhmmThreshold = E.db.auras.cooldown.checkSeconds and E.db.auras.cooldown.hhmmThreshold or nil
	local mmssThreshold = E.db.auras.cooldown.checkSeconds and E.db.auras.cooldown.mmssThreshold or nil
	local textColors = E.db.auras.cooldown.useIndicatorColor and E.TimeIndicatorColors.auras or nil

	local value, id, nextUpdate, remainder = E:GetTimeInfo(self.expiration, threshold, hhmmThreshold, mmssThreshold)
	local style = E.TimeFormats[id]
	self.nextUpdate = nextUpdate

	if style then
		local which = textColors and 2 or 1

		if textColors then
			self.timer:SetFormattedText(style[which], value, textColors[id], remainder)
		else
			self.timer:SetFormattedText(style[which], value, remainder)
		end
	end

	local color = E.TimeColors.auras[id]
	if color then
		self.timer:SetTextColor(color.r, color.g, color.b)
	end
end

function A:UpdateReminder(event, unit)
	if event == "UNIT_AURA" and unit ~= "player" then return end

	local frame = self.frame
	local reverseStyle = E.db.auras.consolidatedBuffs.reverseStyle

	for i = 1, NUM_LE_RAID_BUFF_TYPES do
		local spellName, _, texture, duration, expirationTime = GetRaidBuffTrayAuraInfo(i)
		local button = self.frame[i]

		if spellName then
			button.duration = duration
			button.t:SetTexture(texture)

			if (duration == 0 and expirationTime == 0) or not E.db.auras.consolidatedBuffs.durations then
				local color = reverseStyle and 1 or 0.3
				button.t:SetVertexColor(color, color, color)
				button:SetScript("OnUpdate", nil)
				button.timer:SetText(nil)
				CooldownFrame_SetTimer(button.cd, 0, 0, 0)
			else
				button.expiration = expirationTime - GetTime()
				button.nextUpdate = 0
				button.t:SetVertexColor(1, 1, 1)
				CooldownFrame_SetTimer(button.cd, expirationTime - duration, duration, 1)
				button.cd:SetReverse(reverseStyle and true or false)
				button:SetScript("OnUpdate", A.UpdateConsolidatedTime)
			end
			button.spellName = spellName
		else
			CooldownFrame_SetTimer(button.cd, 0, 0, 0)
			button.spellName = nil
			local color = reverseStyle and 0.3 or 1
			button.t:SetVertexColor(color, color, color)
			button:SetScript("OnUpdate", nil)
			button.timer:SetText(nil)
			button.t:SetTexture(A.DefaultIcons[i])
		end
	end
end

local function onEnter()
	if E.db.auras.consolidatedBuffs.mouseover and E.db.auras.consolidatedBuffs.detached then
		E:UIFrameFadeIn(ElvUI_ConsolidatedBuffs, 0.2, ElvUI_ConsolidatedBuffs:GetAlpha(), E.db.auras.consolidatedBuffs.alpha)
	end
end

local function onLeave()
	if E.db.auras.consolidatedBuffs.mouseover and E.db.auras.consolidatedBuffs.detached then
		E:UIFrameFadeOut(ElvUI_ConsolidatedBuffs, 0.2, ElvUI_ConsolidatedBuffs:GetAlpha(), 0)
	end
end

function A:Button_OnEnter()
	onEnter()

	GameTooltip:Hide()
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", -3, self:GetHeight() + 2)
	GameTooltip:ClearLines()

	local parent = self:GetParent()
	local id = parent:GetID()

	if parent.spellName then
		GameTooltip:SetUnitConsolidatedBuff("player", id)
	else
		GameTooltip:AddLine(_G[format("RAID_BUFF_%d", id)])
	end

	GameTooltip:Show()
end

function A:Button_OnLeave()
	onLeave()

	GameTooltip:Hide()
end

function A:CreateButton(i)
	local button = CreateFrame("Button", "ElvUIConsolidatedBuff"..i, ElvUI_ConsolidatedBuffs)

	button.t = button:CreateTexture(nil, "OVERLAY")
	button.t:SetTexture([[Interface\Icons\INV_Misc_QuestionMark]])
	button.t:SetTexCoord(unpack(E.TexCoords))
	button.t:SetInside()

	button.cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cd:SetInside()
	button.cd.noOCC = true
	button.cd.noCooldownCount = true

	button.timer = button.cd:CreateFontString(nil, "OVERLAY")
	button.timer:Point("CENTER")

	local ButtonData = {
		FloatingBG = nil,
		Icon = button.t,
		Cooldown = button.cd,
		Flash = nil,
		Pushed = nil,
		Normal = nil,
		Disabled = nil,
		Checked = nil,
		Border = nil,
		AutoCastable = nil,
		Highlight = nil,
		HotKey = nil,
		Count = nil,
		Name = nil,
		Duration = false,
		AutoCast = nil,
	}

	if MasqueGroup and E.private.auras.masque.consolidatedBuffs then
		MasqueGroup:AddButton(button, ButtonData)
	elseif not E.private.auras.masque.consolidatedBuffs then
		button:SetTemplate()
	end

	return button
end

function A:EnableCB()
	ElvUI_ConsolidatedBuffs:Show()

	BuffFrame:RegisterUnitEvent("UNIT_AURA", "player")
	self:RegisterEvent("UNIT_AURA", "UpdateReminder")
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "UpdateReminder")
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "UpdateReminder")
	E.RegisterCallback(self, "RoleChanged", "Update_ConsolidatedBuffsSettings")

	A:UpdateReminder()
end

function A:DisableCB()
	ElvUI_ConsolidatedBuffs:Hide()

	if not E.private.auras.disableBlizzard then
		BuffFrame:RegisterUnitEvent("UNIT_AURA", "player")
	else
		BuffFrame:UnregisterEvent("UNIT_AURA")
	end

	self:UnregisterEvent("UNIT_AURA")
	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
	self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	E.UnregisterCallback(self, "RoleChanged", "Update_ConsolidatedBuffsSettings")
end

function A:Update_ConsolidatedBuffsSettings(isCallback)
	local frame = self.frame
	local db = E.db.auras.consolidatedBuffs

	wipe(ignoreIcons)

	if db.filter then
		if E.role == "Caster" then
			ignoreIcons[3] = true
			ignoreIcons[4] = 2
		else
			ignoreIcons[5] = 3
			ignoreIcons[6] = 4
		end
	end

	local backdropSpacing = db.backdrop and db.backdropSpacing or 0

	-- Frame
	if db.detached then
		local numButtons = db.filter and 6 or 8
		local width, height = (db.buttonSize * numButtons) + (db.buttonSpacing * (numButtons - 1)) + (backdropSpacing * 2), db.buttonSize + (backdropSpacing * 2)
		local WIDTH, HEIGHT = db.orientation == "HORIZONTAL" and width or height, db.orientation == "HORIZONTAL" and height or width

		frame:SetSize(WIDTH, HEIGHT)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", ConsolidatedBuffsMover, "CENTER")

		frame.mover:SetSize(WIDTH, HEIGHT)

		if E.private.general.minimap.enable then
			Minimap:ClearAllPoints()
			Minimap:Point("TOPRIGHT", MMHolder, "TOPRIGHT", -E.Border, -E.Border)
		end

		E:EnableMover("ConsolidatedBuffsMover")
		E.FrameLocks.ElvUI_ConsolidatedBuffs = true
	else
		frame:SetWidth(E.ConsolidatedBuffsWidth)

		if E.private.general.minimap.enable then
			Minimap:ClearAllPoints()
			ElvConfigToggle:ClearAllPoints()
			frame:ClearAllPoints()

			if db.position == "LEFT" then
				Minimap:Point("TOPRIGHT", MMHolder, "TOPRIGHT", -E.Border, -E.Border)

				ElvConfigToggle:SetPoint("TOPRIGHT", LeftMiniPanel, "TOPLEFT", E.Border - E.Spacing * 3, 0)
				ElvConfigToggle:SetPoint("BOTTOMRIGHT", LeftMiniPanel, "BOTTOMLEFT", E.Border - E.Spacing * 3, 0)

				frame:SetPoint("TOPRIGHT", Minimap.backdrop, "TOPLEFT", E.Border - E.Spacing * 3, 0)
				frame:SetPoint("BOTTOMRIGHT", Minimap.backdrop, "BOTTOMLEFT", E.Border - E.Spacing * 3, 0)
			else
				Minimap:Point("TOPLEFT", MMHolder, "TOPLEFT", E.Border, -E.Border)

				ElvConfigToggle:SetPoint("TOPLEFT", RightMiniPanel, "TOPRIGHT", -E.Border + E.Spacing * 3, 0)
				ElvConfigToggle:SetPoint("BOTTOMLEFT", RightMiniPanel, "BOTTOMRIGHT", -E.Border + E.Spacing * 3, 0)

				frame:SetPoint("TOPLEFT", Minimap.backdrop, "TOPRIGHT", -E.Border + E.Spacing * 3, 0)
				frame:SetPoint("BOTTOMLEFT", Minimap.backdrop, "BOTTOMRIGHT", -E.Border + E.Spacing * 3, 0)
			end
		end

		E:DisableMover("ConsolidatedBuffsMover")
		E.FrameLocks.ElvUI_ConsolidatedBuffs = nil
	end

	frame:SetParent(db.detached and frame.mover or Minimap)
	frame:SetFrameStrata(db.detached and db.frameStrata or "LOW")

	if db.detached and db.mouseover and not frame:IsMouseOver() then
		frame:SetAlpha(0)
	else
		frame:SetAlpha(db.detached and db.alpha or 1)
	end

	frame.backdrop:SetTemplate(db.transparent and "Transparent" or "Default")
	frame.backdrop:SetShown(db.detached and db.backdrop)

	-- Buttons
	for i = 1, NUM_LE_RAID_BUFF_TYPES do
		local button = frame[i]
		local size = db.detached and db.buttonSize or E.ConsolidatedBuffsWidth

		button:SetSize(size, size)
		button:SetShown(not ignoreIcons[i])
		button:ClearAllPoints()

		if db.detached then
			local vertical = db.orientation == "VERTICAL"
			if i == 1 then
				button:Point(vertical and "TOP" or "LEFT", frame, vertical and "TOP" or "LEFT", vertical and 0 or backdropSpacing, vertical and -backdropSpacing or 0)
			else
				button:Point(vertical and "TOP" or "LEFT", frame[ignoreIcons[i - 1] or (i - 1)], vertical and "BOTTOM" or "RIGHT", vertical and 0 or db.buttonSpacing, vertical and -db.buttonSpacing or 0)
			end
		else
			if i == 1 then
				button:Point("TOP", frame, "TOP", 0, 0)
			elseif i == 8 then
				button:Point("BOTTOM", frame, "BOTTOM", 0, 0)
			else
				button:Point("TOP", frame[ignoreIcons[i - 1] or (i - 1)], "BOTTOM", 0, E.Border - E.Spacing)
			end
		end

		local font = LSM:Fetch("font", db.font)
		button.timer:FontTemplate(font, db.fontSize, db.fontOutline)

		button.cd:SetAlpha(db.durations and 1 or 0)

		if E.private.auras.disableBlizzard then
			local buffIcon = _G[format("ConsolidatedBuffsTooltipBuff%d", i)]

			buffIcon:ClearAllPoints()
			buffIcon:SetAllPoints(frame[i])
			buffIcon:SetParent(frame[i])
			buffIcon:SetAlpha(0)
			buffIcon:SetScript("OnEnter", A.Button_OnEnter)
			buffIcon:SetScript("OnLeave", A.Button_OnLeave)
		end
	end

	-- Enable / Disable
	if not isCallback then
		if db.enable and E.private.auras.disableBlizzard and (E.private.general.minimap.enable or db.detached and not E.private.general.minimap.enable) then
			A:EnableCB()
		else
			A:DisableCB()
		end
	else
		A:UpdateReminder()
	end

	-- Masque
	if MasqueGroup and E.private.auras.masque.consolidatedBuffs and db.enable then
		MasqueGroup:ReSkin()
	end
end

function A:Construct_ConsolidatedBuffs()
	local frame = CreateFrame("Frame", "ElvUI_ConsolidatedBuffs", Minimap)
	frame:CreateBackdrop()
	frame:SetWidth(E.ConsolidatedBuffsWidth)
	frame:SetScript("OnEnter", onEnter)
	frame:SetScript("OnLeave", onLeave)
	self.frame = frame

	local holder = CreateFrame("Frame", "ConsolidatedBuffsMover", E.UIParent)
	holder:Point("TOPRIGHT", E.UIParent, "TOPRIGHT", -4, -260)
	holder:SetSize(120, 30)
	frame.mover = holder

	E:CreateMover(holder, "ConsolidatedBuffsMover", L["Consolidated Buffs"], nil, nil, nil, "ALL,GENERAL", nil, "auras,consolidatedBuffs")

	for i = 1, NUM_LE_RAID_BUFF_TYPES do
		frame[i] = self:CreateButton(i)
		frame[i]:SetID(i)
	end

	if Masque and MasqueGroup then
		A.CBMasqueGroup = MasqueGroup
	end

	A:Update_ConsolidatedBuffsSettings()
end