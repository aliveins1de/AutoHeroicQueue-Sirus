-- AutoHeroicQueue
-- При входе в игру автоматически выставляет в дропдауне "Тип" сохранённый выбор.
-- /ahq - открыть окно выбора нужного варианта из списка (сохраняется навсегда).

AutoHeroicQueueDB = AutoHeroicQueueDB or {}

local AHQ = CreateFrame("Frame")
AHQ:RegisterEvent("PLAYER_ENTERING_WORLD")

local DEBUG = false

local function Debug(msg)
    if DEBUG then
        print("|cff33ff99[AutoHeroicQueue]|r " .. msg)
    end
end

-- Собирает список всех вариантов, которые показываются в дропдауне "Тип"
-- (те же условия, что использует сама Blizzard в LFDQueueFrameTypeDropDown_Initialize)
local function GetAllTypeOptions()
    local options = {}

    for i = 1, GetNumRandomDungeons() do
        local id, name = GetLFGRandomDungeonInfo(i)
        if id then
            local _, _, minLevel, maxLevel, _, _, _, expansionLevel = GetLFGDungeonInfo(id)
            local myLevel = UnitLevel("player")
            local isDisplayable = myLevel >= minLevel and myLevel <= maxLevel and EXPANSION_LEVEL >= expansionLevel
            if isDisplayable then
                table.insert(options, { id = id, name = name })
            end
        end
    end

    return options
end

local function ApplySavedType()
    if not LFDQueueFrame then
        return
    end
    if not AutoHeroicQueueDB.selectedDungeonID then
        Debug("Сохранённого выбора нет (похоже, SavedVariables не записались с прошлой сессии). Набери /ahq и выбери заново.")
        return
    end
    if not IsLFGDungeonJoinable(AutoHeroicQueueDB.selectedDungeonID) then
        Debug("Сохранённый выбор ('" .. tostring(AutoHeroicQueueDB.selectedDungeonName) .. "') сейчас недоступен, пропуск.")
        return
    end
    LFDQueueFrame_SetType(AutoHeroicQueueDB.selectedDungeonID)
    Debug("Тип очереди выставлен: " .. tostring(AutoHeroicQueueDB.selectedDungeonName))
end

AHQ:SetScript("OnEvent", function(self, event, ...)
    local waitFrame = CreateFrame("Frame")
    local elapsedTotal = 0
    waitFrame:SetScript("OnUpdate", function(self, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal >= 3 then
            self:SetScript("OnUpdate", nil)
            ApplySavedType()
        end
    end)
end)

if LFDParentFrame then
    LFDParentFrame:HookScript("OnShow", function()
        ApplySavedType()
    end)
end

----------------------------------------------------------------
-- UI выбора подземелья
----------------------------------------------------------------

local function SelectDungeon(id, name)
    AutoHeroicQueueDB.selectedDungeonID = id
    AutoHeroicQueueDB.selectedDungeonName = name
    Debug("Сохранён выбор: " .. name)
    ApplySavedType()
    if AutoHeroicQueueConfigFrame then
        AutoHeroicQueueConfigFrame:Hide()
    end
end

-- Возвращает объект E из ElvUI, если он загружен, иначе nil
local function GetElvUI()
    if _G.ElvUI then
        local E = unpack(_G.ElvUI)
        return E
    end
    return nil
end

local function BuildConfigFrame()
    if AutoHeroicQueueConfigFrame then
        return AutoHeroicQueueConfigFrame
    end

    local options = GetAllTypeOptions()
    local E = GetElvUI()
    local S = E and E:GetModule("Skins")

    local PADDING = 16
    local BUTTON_HEIGHT = 24
    local BUTTON_GAP = 4
    local FRAME_WIDTH = 320

    local frame = CreateFrame("Frame", "AutoHeroicQueueConfigFrame", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetPoint("CENTER")

    local numOptions = #options
    local height = 78 + numOptions * (BUTTON_HEIGHT + BUTTON_GAP)
    frame:SetSize(FRAME_WIDTH, height)

    if S then
        -- Скиним основной фрейм под ElvUI (второй аргумент true = стандартная тёмная подложка)
        S:HandleFrame(frame, true)
    else
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -PADDING)
    title:SetText("AutoHeroicQueue")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -2, -2)
    if S then
        S:HandleCloseButton(closeButton)
    end

    local current = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    current:SetPoint("TOP", title, "BOTTOM", 0, -6)
    current:SetTextColor(0.2, 1, 0.4)
    current:SetText(AutoHeroicQueueDB.selectedDungeonName and
        ("Выбрано: " .. AutoHeroicQueueDB.selectedDungeonName) or
        "Пока ничего не выбрано")
    frame.currentText = current

    local buttonWidth = FRAME_WIDTH - PADDING * 2
    local lastButton
    for _, option in ipairs(options) do
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(buttonWidth, BUTTON_HEIGHT)
        btn:SetText(option.name)
        if lastButton then
            btn:SetPoint("TOP", lastButton, "BOTTOM", 0, -BUTTON_GAP)
        else
            btn:SetPoint("TOP", current, "BOTTOM", 0, -14)
        end
        btn:SetScript("OnClick", function()
            SelectDungeon(option.id, option.name)
        end)

        if S then
            S:HandleButton(btn)
        end

        -- Подсвечиваем текущий выбранный вариант зелёным
        if AutoHeroicQueueDB.selectedDungeonID == option.id then
            local textObj = btn:GetFontString()
            if textObj then
                textObj:SetTextColor(0.2, 1, 0.4)
            end
        end

        lastButton = btn
    end

    frame:Hide() -- фрейм по умолчанию создаётся видимым, прячем сразу после сборки
    return frame
end

local function ToggleConfigFrame()
    if AutoHeroicQueueConfigFrame and AutoHeroicQueueConfigFrame:IsShown() then
        AutoHeroicQueueConfigFrame:Hide()
        return
    end

    -- Пересобираем окно заново при каждом открытии, чтобы подсветка
    -- текущего выбора всегда была актуальной.
    if AutoHeroicQueueConfigFrame then
        AutoHeroicQueueConfigFrame:Hide()
        AutoHeroicQueueConfigFrame:SetParent(nil)
        AutoHeroicQueueConfigFrame = nil
    end

    local frame = BuildConfigFrame()
    frame:Show()
end

SLASH_AUTOHEROICQUEUE1 = "/ahq"
SlashCmdList["AUTOHEROICQUEUE"] = function()
    ToggleConfigFrame()
end

Debug("Аддон загружен. /ahq - открыть меню выбора подземелья.")
