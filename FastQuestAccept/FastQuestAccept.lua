-- FastQuestAccept.lua

local addonName = ...

-- Lokalisierung
local L = {}
local locale = GetLocale()
if locale == "deDE" then
	L["title"]      = "Fast Quest Accept"
	L["desc"]       = "Fast Quest Accept Einstellungen"
	L["pickup"]     = "Quests automatisch annehmen"
	L["deliver"]    = "Quests automatisch abgeben"
	L["popup"]      = "Pop-up-Quests automatisch akzeptieren"
	L["bestreward"] = "Beste Quest-Belohnung automatisch wählen"
	L["norepauto"]  = "Hinweis: Ruf-Token/0-Wert-Belohnungen werden nicht automatisch gewählt."
elseif locale == "frFR" then
	L["title"]      = "Acceptation rapide de quêtes"
	L["desc"]       = "Paramètres d'acceptation rapide de quêtes"
	L["pickup"]     = "Accepter automatiquement les quêtes"
	L["deliver"]    = "Rendre automatiquement les quêtes"
	L["popup"]      = "Accepter automatiquement les quêtes pop-up"
	L["bestreward"] = "Choisir automatiquement la meilleure récompense"
	L["norepauto"]  = "Note : Les jetons de réputation / récompenses à 0 valeur ne sont pas sélectionnés automatiquement."
elseif locale == "ruRU" then
	L["title"]      = "Быстрое принятие квестов"
	L["desc"]       = "Настройки Быстрого принятия квестов"
	L["pickup"]     = "Автоматически принимать квесты"
	L["deliver"]    = "Автоматически сдавать квесты"
	L["popup"]      = "Автоматически принимать всплывающие квесты"
	L["bestreward"] = "Автоматически выбирать лучшую награду за квест"
	L["norepauto"]  = "Примечание: Токены репутации / награды с нулевой ценой не выбираются автоматически."
else
	L["title"]      = "Fast Quest Accept"
	L["desc"]       = "Fast Quest Accept Settings"
	L["pickup"]     = "Automatically pick up quests"
	L["deliver"]    = "Automatically deliver quests"
	L["popup"]      = "Automatically accept pop-up quests"
	L["bestreward"] = "Automatically choose best quest reward"
	L["norepauto"]  = "Note: Reputation tokens / 0-value rewards are not auto-selected."
end

-- Kleine Helper: AddCategory (Retail/Classic kompatibel)
local function AddCategory(panel)
	if Settings and Settings.RegisterCanvasLayoutCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(category)
		return category
	else
		InterfaceOptions_AddCategory(panel)
		return panel
	end
end

-- Standardwerte
local defaults = {
	autoPickup     = true,
	autoDeliver    = true,
	autoPopup      = true,
	autoBestReward = true,
}

-- SavedVariables: Per Character (via .toc SavedVariablesPerCharacter)
local function InitDB()
	FastQuestAcceptDB = FastQuestAcceptDB or {}
	for k, v in pairs(defaults) do
		if FastQuestAcceptDB[k] == nil then
			FastQuestAcceptDB[k] = v
		end
	end
end

-- Options UI
local function CreateOptionsPanel()
	local panel = CreateFrame("Frame", "FastQuestAcceptOptionsPanel", InterfaceOptionsFramePanelContainer)
	panel.name = L["title"]

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(L["title"])

	local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	desc:SetWidth(650)
	desc:SetJustifyH("LEFT")
	desc:SetText(L["desc"])

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -8)
	hint:SetWidth(650)
	hint:SetJustifyH("LEFT")
	hint:SetText(L["norepauto"])

	local function CreateCheckbox(label, key, yOffset)
		local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
		cb:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, yOffset)
		cb.Text:SetText(label)

		cb:SetScript("OnShow", function(self)
			self:SetChecked(FastQuestAcceptDB and FastQuestAcceptDB[key])
		end)

		cb:SetScript("OnClick", function(self)
			FastQuestAcceptDB[key] = self:GetChecked() and true or false
		end)

		return cb
	end

	CreateCheckbox(L["pickup"], "autoPickup", -10)
	CreateCheckbox(L["deliver"], "autoDeliver", -40)
	CreateCheckbox(L["popup"], "autoPopup", -70)
	CreateCheckbox(L["bestreward"], "autoBestReward", -100)

	AddCategory(panel)
end

-- ADDON_LOADED
local f = CreateFrame("Frame", "FastQuestAcceptFrame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		InitDB()
		CreateOptionsPanel()
	end
end)

-- Helper: Sell price for quest choice item
local function GetChoiceSellPrice(i)
	local _, _, _, _, _, itemID = GetQuestItemInfo("choice", i)
	if not itemID then return 0 end
	return select(11, GetItemInfo(itemID)) or 0
end

-- =========================================================
-- ✅ NEU: Ruf/Ruhm Token zuverlässig erkennen (Tooltip-Scan)
-- =========================================================
local function TooltipHasAnyKeyword(tooltipData, keywords)
	if not tooltipData or not tooltipData.lines then return false end
	for _, line in ipairs(tooltipData.lines) do
		local txt = ((line.leftText or "") .. " " .. (line.rightText or "")):lower()
		for _, kw in ipairs(keywords) do
			if txt:find(kw, 1, true) then
				return true
			end
		end
	end
	return false
end

local REP_KEYWORDS = {
	-- de
	"ruf", "ruhm",
	-- en
	"reputation", "renown",
	-- fr
	"réputation", "renommée",
	-- ru (teilwörter, damit es flexibler ist)
	"репута", "известност",
}

local function IsReputationOrRenownChoice(i)
	local _, _, _, _, _, itemID = GetQuestItemInfo("choice", i)

	-- Wenn es kein Item ist (z.B. Währung/sonstiges), lieber NICHT auto-picken
	if not itemID then
		return true
	end

	-- Retail: TooltipInfo API
	if C_TooltipInfo and C_TooltipInfo.GetQuestRewardItem then
		local tooltipData = C_TooltipInfo.GetQuestRewardItem("choice", i)
		if TooltipHasAnyKeyword(tooltipData, REP_KEYWORDS) then
			return true
		end
	end

	return false
end

local function AllChoicesAreReputationOrRenown()
	local num = GetNumQuestChoices() or 0
	if num <= 0 then return false end
	for i = 1, num do
		if not IsReputationOrRenownChoice(i) then
			return false
		end
	end
	return true
end

-- WICHTIG: Ruf-Token/0-Wert Auswahlbelohnungen erkennen
-- Wenn es Choices gibt UND ALLE Choices 0 Vendor-Wert haben -> NICHT automatisch abschließen.
local function ChoicesAreAllZeroValue()
	local num = GetNumQuestChoices() or 0
	if num <= 0 then return false end

	for i = 1, num do
		local sellPrice = GetChoiceSellPrice(i)
		if sellPrice and sellPrice > 0 then
			return false
		end
	end
	return true
end

-- Optional: Quests die wirklich "nur Ruf" geben (keine Money/Items/Choices) nicht auto-abschließen.
local function QuestHasNoTangibleRewards()
	local numChoices = GetNumQuestChoices() or 0
	if numChoices > 0 then return false end

	local money = GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) or 0
	if money > 0 then return false end

	local numRewards = (GetNumQuestRewards and (GetNumQuestRewards() or 0)) or 0
	if numRewards > 0 then
		for i = 1, numRewards do
			local _, _, _, _, _, itemID = GetQuestItemInfo("reward", i)
			if itemID then
				return false
			end
		end
	end

	-- keine choices, kein geld, keine items -> sehr wahrscheinlich "nur ruf"
	return true
end

-- Helper: Best reward by vendor sell price (Choices)
-- ✅ Update: Ruf/Ruhm-Choices werden NIE automatisch gewählt
local function GetBestRewardChoiceIndex()
	local num = GetNumQuestChoices() or 0
	if num <= 0 then return nil end

	local bestIndex, bestPrice = nil, 0

	for i = 1, num do
		-- Ruf/Ruhm niemals automatisch wählen
		if not IsReputationOrRenownChoice(i) then
			local sellPrice = GetChoiceSellPrice(i)
			if sellPrice > bestPrice then
				bestPrice = sellPrice
				bestIndex = i
			end
		end
	end

	-- Wenn nichts übrig bleibt oder alles 0 Wert hat -> kein Auto-Pick
	if not bestIndex or bestPrice <= 0 then
		return nil
	end

	return bestIndex
end

-- Quest Logik
local q = CreateFrame("Frame")
q:RegisterEvent("GOSSIP_SHOW")
q:RegisterEvent("QUEST_GREETING")
q:RegisterEvent("QUEST_DETAIL")
q:RegisterEvent("QUEST_PROGRESS")
q:RegisterEvent("QUEST_COMPLETE")

q:SetScript("OnEvent", function(_, event)
	if not FastQuestAcceptDB then return end

	if event == "QUEST_DETAIL" then
		if FastQuestAcceptDB.autoPickup then
			AcceptQuest()
		end

	elseif event == "QUEST_PROGRESS" then
		if FastQuestAcceptDB.autoDeliver and IsQuestCompletable() then
			CompleteQuest()
		end

	elseif event == "QUEST_COMPLETE" then
		if not FastQuestAcceptDB.autoDeliver then return end

		-- ✅ Fix 1 (neu): Ruf/Ruhm-Choices niemals automatisch auswählen/abschließen
		if AllChoicesAreReputationOrRenown() then
			return
		end

		-- ✅ Fix 2 (alt): Ruf-Token / 0-Wert Auswahlbelohnungen niemals automatisch auswählen
		if ChoicesAreAllZeroValue() then
			return
		end

		-- ✅ Optional: "nur Ruf" Quests nicht auto-abschließen
		if QuestHasNoTangibleRewards() then
			return
		end

		local numChoices = GetNumQuestChoices() or 0

		-- Wenn es Auswahlbelohnungen gibt und "beste Belohnung" aktiv ist:
		if numChoices >= 1 and FastQuestAcceptDB.autoBestReward then
			local bestIndex = GetBestRewardChoiceIndex()
			if bestIndex then
				GetQuestReward(bestIndex)
			else
				-- kein Auto-Pick (z.B. Ruf/Ruhm oder 0 Wert) -> Spieler wählt selbst
				return
			end
		else
			-- 0 Choices: normales Auto-Abgeben (Index 1 schließt die Quest ab)
			-- 1+ Choices + autoBestReward AUS: hier NICHT auto, wenn Ruf/Ruhm dabei sein könnte
			if numChoices >= 1 then
				return
			end
			GetQuestReward(1)
		end

	elseif event == "GOSSIP_SHOW" then
		if FastQuestAcceptDB.autoPickup then
			local available = C_GossipInfo.GetAvailableQuests() or {}
			local idx = 1
			local function pickNext()
				if idx <= #available then
					C_GossipInfo.SelectAvailableQuest(available[idx].questID)
					idx = idx + 1
					C_Timer.After(0.4, pickNext)
				end
			end
			C_Timer.After(0.1, pickNext)
		end

		if FastQuestAcceptDB.autoDeliver then
			local active = C_GossipInfo.GetActiveQuests() or {}
			for _, quest in ipairs(active) do
				if quest.isComplete then
					C_GossipInfo.SelectActiveQuest(quest.questID)
				end
			end
		end

	elseif event == "QUEST_GREETING" then
		if FastQuestAcceptDB.autoDeliver then
			local numActive = GetNumActiveQuests()
			for i = 1, numActive do
				local _, isComplete = GetActiveTitle(i)
				if isComplete then
					SelectActiveQuest(i)
				end
			end
		end

		if FastQuestAcceptDB.autoPickup then
			local numAvailable = GetNumAvailableQuests()
			local index = 1
			local function pickNext()
				if index <= numAvailable then
					SelectAvailableQuest(index)
					index = index + 1
					C_Timer.After(0.4, pickNext)
				end
			end
			C_Timer.After(0.1, pickNext)
		end
	end
end)
