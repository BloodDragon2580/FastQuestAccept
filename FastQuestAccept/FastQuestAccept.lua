-- FastQuestAccept.lua

local addonName = ...

-- Lokalisierung
local L = {}
local locale = GetLocale()
if locale == "deDE" then
    L["title"]    = "Fast Quest Accept"
    L["desc"]     = "Fast Quest Accept Einstellungen"
    L["pickup"]   = "Quests automatisch annehmen"
    L["deliver"]  = "Quests automatisch abgeben"
    L["popup"]    = "Pop-up-Quests automatisch akzeptieren"
elseif locale == "frFR" then
    L["title"]    = "Acceptation rapide de quêtes"
    L["desc"]     = "Paramètres d'acceptation rapide des quêtes"
    L["pickup"]   = "Accepter automatiquement les quêtes"
    L["deliver"]  = "Rendre automatiquement les quêtes"
    L["popup"]    = "Accepter automatiquement les quêtes pop-up"
else
    L["title"]    = "Fast Quest Accept"
    L["desc"]     = "Fast Quest Accept Settings"
    L["pickup"]   = "Automatically pick up quests"
    L["deliver"]  = "Automatically deliver quests"
    L["popup"]    = "Automatically accept pop-up quests"
end

-- Fallback Retail-Settings-API
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
if not InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory = function(frame)
        local category, layout = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name)
        category.ID = frame.name
        Settings.RegisterAddOnCategory(category)
        return category
    end
end

-- Default-Einstellungen
local defaults = {
    autoPickup  = true,
    autoDeliver = true,
    autoPopup   = true,
}

-- Haupt-Frame
local f = CreateFrame("Frame", "FastQuestAcceptFrame")
f:RegisterEvent("ADDON_LOADED")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- SavedVariables init
        FastQuestAcceptDB = FastQuestAcceptDB or {}
        for k, v in pairs(defaults) do
            if FastQuestAcceptDB[k] == nil then
                FastQuestAcceptDB[k] = v
            end
        end

        -- Interface-Options
        local panel = CreateFrame("Frame", "FastQuestAcceptOptionsPanel", InterfaceOptionsFramePanelContainer)
        panel.name = L["title"]
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText(L["desc"])
        local function CreateCheckbox(label, key, yOffset)
            local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
            cb.Text:SetText(label)
            cb:SetChecked(FastQuestAcceptDB[key])
            cb:SetScript("OnClick", function(self)
                FastQuestAcceptDB[key] = self:GetChecked()
            end)
        end
        CreateCheckbox(L["pickup"],  "autoPickup",  -16)
        CreateCheckbox(L["deliver"], "autoDeliver", -46)
        CreateCheckbox(L["popup"],   "autoPopup",   -76)
        panel:Hide()
        InterfaceOptions_AddCategory(panel)

        -- Registriere Quest-Events
        f:RegisterEvent("QUEST_DETAIL")
        f:RegisterEvent("QUEST_PROGRESS")
        f:RegisterEvent("QUEST_COMPLETE")
        f:RegisterEvent("GOSSIP_SHOW")
        f:RegisterEvent("QUEST_ACCEPT_CONFIRM")
        return
    end

    -- QUEST_DETAIL: immer annehmen
    if event == "QUEST_DETAIL" and FastQuestAcceptDB.autoPickup then
        AcceptQuest()

    -- QUEST_PROGRESS: abgeben, wenn abschließbar
    elseif event == "QUEST_PROGRESS" and FastQuestAcceptDB.autoDeliver then
        if IsQuestCompletable() then
            CompleteQuest()
        end

    -- QUEST_COMPLETE: Belohnung ziehen
    elseif event == "QUEST_COMPLETE" and FastQuestAcceptDB.autoDeliver then
        local numChoices = GetNumQuestChoices()
        if numChoices == 0 or numChoices == 1 then
            GetQuestReward(1)
        end

    -- QUEST_ACCEPT_CONFIRM: Pop-ups
    elseif event == "QUEST_ACCEPT_CONFIRM" and FastQuestAcceptDB.autoPopup then
        ConfirmAcceptQuest()

    -- GOSSIP_SHOW: sequentiell abarbeiten
    elseif event == "GOSSIP_SHOW" then
        local available = C_GossipInfo.GetAvailableQuests()
        local active    = C_GossipInfo.GetActiveQuests()

        -- 1) Abgabe: wenn ≥1 complete
        if FastQuestAcceptDB.autoDeliver then
            for _, q in ipairs(active) do
                if q.isComplete then
                    C_GossipInfo.SelectActiveQuest(q.questID)
                    return
                end
            end
        end

        -- 2) Annahme: wenn ≥1 new
        if FastQuestAcceptDB.autoPickup then
            if #available > 0 then
                C_GossipInfo.SelectAvailableQuest(available[1].questID)
                return
            end
        end
    end
end)
