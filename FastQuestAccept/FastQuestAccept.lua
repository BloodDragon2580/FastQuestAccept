-- FastQuestAccept.lua

local addonName = ...

-- Lokalisierung
local L = {}

local locale = GetLocale()
if locale == "deDE" then
    L["title"] = "Fast Quest Accept"
    L["desc"] = "Fast Quest Accept Einstellungen"
    L["pickup"] = "Quests automatisch annehmen"
    L["deliver"] = "Quests automatisch abgeben"
    L["popup"] = "Pop-up-Quests automatisch akzeptieren"
    L["skipnpc"] = "NPC-Dialoge überspringen (nur 1 Option)"
elseif locale == "frFR" then
    L["title"] = "Acceptation rapide de quêtes"
    L["desc"] = "Paramètres d'acceptation rapide des quêtes"
    L["pickup"] = "Accepter automatiquement les quêtes"
    L["deliver"] = "Rendre automatiquement les quêtes"
    L["popup"] = "Accepter automatiquement les quêtes pop-up"
    L["skipnpc"] = "Ignorer les PNJ avec une seule option"
else
    L["title"] = "Fast Quest Accept"
    L["desc"] = "Fast Quest Accept Settings"
    L["pickup"] = "Automatically pick up quests"
    L["deliver"] = "Automatically deliver quests"
    L["popup"] = "Automatically accept pop-up quests"
    L["skipnpc"] = "Skip NPC dialogue with one option"
end

-- Fallback für Retail-Settings-API
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
if not InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory = function(frame)
        local category, layout = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name)
        category.ID = frame.name
        Settings.RegisterAddOnCategory(category)
        return category
    end
end

-- Standardwerte
local defaults = {
    autoPickup = true,
    autoDeliver = true,
    autoPopup = true,
    autoSkipNPC = true,
}

-- Frame
local f = CreateFrame("Frame", "FastQuestAcceptFrame")
f:RegisterEvent("ADDON_LOADED")

-- Event-Handler
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- SavedVariables
        FastQuestAcceptDB = FastQuestAcceptDB or {}
        for k, v in pairs(defaults) do
            if FastQuestAcceptDB[k] == nil then
                FastQuestAcceptDB[k] = v
            end
        end

        -- Options-Panel
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

        CreateCheckbox(L["pickup"],   "autoPickup",  -16)
        CreateCheckbox(L["deliver"],  "autoDeliver", -46)
        CreateCheckbox(L["popup"],    "autoPopup",   -76)
        CreateCheckbox(L["skipnpc"],  "autoSkipNPC", -106)

        panel:Hide()
        InterfaceOptions_AddCategory(panel)

        -- Weitere Events aktivieren
        f:RegisterEvent("QUEST_DETAIL")
        f:RegisterEvent("QUEST_PROGRESS")
        f:RegisterEvent("QUEST_COMPLETE")
        f:RegisterEvent("GOSSIP_SHOW")
        f:RegisterEvent("QUEST_ACCEPT_CONFIRM")
    end

    -- Funktionalität
    if event == "QUEST_DETAIL" and FastQuestAcceptDB.autoPickup then
        AcceptQuest()

    elseif event == "QUEST_PROGRESS" and FastQuestAcceptDB.autoDeliver then
        if IsQuestCompletable() then
            CompleteQuest()
        end

    elseif event == "QUEST_COMPLETE" and FastQuestAcceptDB.autoDeliver then
        if GetNumQuestChoices() == 0 then
            GetQuestReward(1)
        elseif GetNumQuestChoices() == 1 then
            GetQuestReward(1)
        end

    elseif event == "QUEST_ACCEPT_CONFIRM" and FastQuestAcceptDB.autoPopup then
        ConfirmAcceptQuest()

    elseif event == "GOSSIP_SHOW" then
        local options = C_GossipInfo.GetOptions()

        if FastQuestAcceptDB.autoSkipNPC and #options == 1 then
            C_GossipInfo.SelectOption(options[1].gossipOptionID)
        end

        if FastQuestAcceptDB.autoPickup then
            for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
                C_GossipInfo.SelectAvailableQuest(quest.questID)
            end
        end

        if FastQuestAcceptDB.autoDeliver then
            for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
                if quest.isComplete then
                    C_GossipInfo.SelectActiveQuest(quest.questID)
                end
            end
        end
    end
end)
