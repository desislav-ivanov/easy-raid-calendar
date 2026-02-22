---@class ERC
ERC = LibStub("AceAddon-3.0"):NewAddon("ERC", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

local modern = select(4, GetBuildInfo()) >= 100000
ERC.BUTTON_HEIGHT = 25

local backdrop = {
  bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile     = true,
  tileSize = 32,
  edgeSize = 32,
  insets   = { left = 11, right = 12, top = 12, bottom = 11 }
}

-- Standardwerte: Mindest-Level = 80, ElvUI-Skin standardmäßig aktiv
local defaults = {
  profile = {
    fLVL = 80, -- Filter Level (Mindestlevel)
    mLVL = 100, -- Maximalwert für den Slider
    elvUISkin = True, -- ElvUI-Skin per Option schaltbar
  }
}

-----------------------------------------------------------------------
-- ElvUI Skin (optional, ohne harte Abhängigkeit)
-----------------------------------------------------------------------
local function GetElvSkins()
  local E = _G.ElvUI and _G.ElvUI[1]
  if not E then return end
  local S = E:GetModule("Skins", true)
  return E, S
end

-- Standard-Style (ohne ElvUI) anwenden
function ERC:ApplyDefaultStyle()
  if not self.frame or self.frame:IsForbidden() then return end
  if BackdropTemplateMixin and self.frame.SetBackdrop then
    self.frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.95)
  end
end

function ERC:ApplyElvUISkin()
  -- Nur wenn Option aktiv
  if not (self.db and self.db.profile and self.db.profile.elvUISkin) then return end
  if self._elvApplied then return end

  local E, S = GetElvSkins()
  if not S then return end

  if self.frame and not self.frame:IsForbidden() then
    S:HandleFrame(self.frame, True, nil, 0, 0, 0, 0)
  end
  if self.frame and self.frame.scrollBar and not self.frame.scrollBar:IsForbidden() then
    S:HandleScrollBar(self.frame.scrollBar)
  end
  if self.frame and self.frame.statusFrame and not self.frame.statusFrame:IsForbidden() then
    S:HandleFrame(self.frame.statusFrame, True, nil, 0, 0, 0, 0)
    if self.frame.statusFrame.STOPBUTTON then S:HandleButton(self.frame.statusFrame.STOPBUTTON) end
    if self.frame.statusFrame.NEWEVENT  then S:HandleButton(self.frame.statusFrame.NEWEVENT)  end
  end

  self._elvApplied = true
end

local function ElvSkinButton(btn)
  -- Nur wenn Option aktiv
  local ERC = _G.ERC
  if not (ERC and ERC.db and ERC.db.profile and ERC.db.profile.elvUISkin) then return end
  local _, S = GetElvSkins()
  if not (S and btn and not btn:IsForbidden()) then return end
  if not btn._elvSkinned then
    S:HandleButton(btn)
    btn._elvSkinned = true
  end
end

-----------------------------------------------------------------------
-- Ace3 Lifecycle
-----------------------------------------------------------------------
function ERC:OnInitialize()
  ERC:DPrint("OnInitialize()")
  ERC:RegisterChatCommand("erc", "ChatCommand")
end

--CALENDAR_CLOSE_EVENT
function ERC:OnEnable()
  ERC:DPrint("OnEnable()")
  self.dummy = CreateFrame("Frame")
  self.dummy:SetScript("OnEvent", self.OnEvent)
  self.dummy:RegisterEvent("ADDON_LOADED")

  ERC:RegisterMessage("ERC_INVITE",   self.InviteHandler)
  ERC:RegisterMessage("ERC_UNINVITE", self.UninviteHandler)
  ERC:RegisterMessage("ERC_OP_RESULT", self.ResultHandler)
end

function ERC:OnDisable()
  ERC:DPrint("OnDisable()")
  if self.frame then
    self.frame:UnregisterEvent("CALENDAR_ACTION_PENDING")
    self.frame:UnregisterEvent("CALENDAR_UPDATE_INVITE_LIST")
    self.frame:UnregisterEvent("GUILD_ROSTER_UPDATE")
    self.frame:UnregisterEvent("CALENDAR_UPDATE_ERROR")
  end
  ERC:UnregisterMessage("ERC_INVITE")
  ERC:UnregisterMessage("ERC_UNINVITE")
  ERC:UnregisterMessage("ERC_OP_RESULT")
end

function ERC:DPrint(...)
  if self.debug then
    ERC:Print(...)
  end
end

function ERC:ChatCommand(input)
  if not input or input:trim() == "" then
    ERC:DPrint("Empty command")
    return
  end
  if input:trim() == "debug on"  then self.debug = true;  ERC:DPrint(input) end
  if input:trim() == "debug off" then self.debug = false; ERC:DPrint(input) end
end

-----------------------------------------------------------------------
-- Messaging
-----------------------------------------------------------------------
function ERC:InviteHandler(target)
  ERC:DPrint("ERC:InviteHandler() " .. tostring(target))
  tinsert(ERC.inviteList, target)
end

function ERC:UninviteHandler(target)
  ERC:DPrint("ERC:UninviteHandler() " .. tostring(target))
  tinsert(ERC.removeList, target)
end

function ERC:ResultHandler(result)
  ERC:DPrint("ERC:ResultHandler() " .. tostring(result))
  if result == true then
    ERC.invite_in_progress = false
  end
end

-----------------------------------------------------------------------
-- OnUpdate: Worker für Einladungen / Entfernen
-----------------------------------------------------------------------
function ERC:FrameOnUpdate(elapsed)
  ERC.lastTimer = ERC.lastTimer + elapsed
  local canAdd = C_Calendar.CanAddEvent()

  if ERC.lastTimer > 2.0 and canAdd then
    if not ERC.invite_in_progress then
      -- Einladungen abarbeiten
      if ERC.inviteList and tablelength(ERC.inviteList) > 0 then
        local numInvites = C_Calendar.GetNumInvites()
        if numInvites == 100 then
          if not ERC.frame.statusFrame.NEWEVENT:IsShown() then
            ERC.frame.statusFrame.NEWEVENT:Show()
          end
        else
          if ERC.frame.statusFrame.NEWEVENT:IsShown() then
            ERC.frame.statusFrame.NEWEVENT:Hide()
          end
          local invite = table.remove(ERC.inviteList, 1)
          ERC:DPrint("FrameOnUpdate() CalendarEventInvite(" .. invite .. ")")

          local info = C_Calendar.GetEventIndex()
          if info then
            ERC:DPrint("monthOffset: " .. info.offsetMonths)
            ERC:DPrint("day: " .. info.monthDay)
            ERC:DPrint("index" .. info.eventIndex)
          end

          local isinvited = false
          for invidx = 1, numInvites do
            local invite_info = C_Calendar.EventGetInvite(invidx)
            if invite_info then
              if (Ambiguate(invite, "guild") == invite_info.name or invite == invite_info.name) and not invite_info.inviteIsMine then
                ERC:DPrint("FrameOnUpdate() " .. invite .. " is already invited.")
                isinvited = true
              end
            end
          end

          if not isinvited then
            C_Calendar.EventInvite(invite)
            self.invite_in_progress = true
          end
        end
        -- send invite
      end

      -- Entfernen abarbeiten
      if ERC.removeList and tablelength(ERC.removeList) > 0 then
        local rem = table.remove(ERC.removeList, 1)
        local numInvites = C_Calendar.GetNumInvites()
        for invidx = 1, numInvites do
          local invite_info = C_Calendar.EventGetInvite(invidx)
          if invite_info then
            ERC:DPrint("FrameOnUpdate() CalendarEventRemoveInvite(" .. tostring(invidx) .. ")")
            if (Ambiguate(rem, "guild") == invite_info.name or rem == invite_info.name) and not invite_info.inviteIsMine then
              C_Calendar.EventRemoveInvite(invidx)
            end
          end
        end
        self.invite_in_progress = true
      end
    end
    ERC.lastTimer = 0
  end

  if tablelength(ERC.inviteList) > 0 or tablelength(ERC.removeList) > 0 then
    if not ERC.frame.statusFrame:IsShown() then
      ERC.frame.statusFrame:Show()
    end
    local totaltasks = #ERC.inviteList + #ERC.removeList
    ERC.frame.statusFrame.text:SetText(string.format("Tasks pending %d", totaltasks))
  else
    if ERC.frame.statusFrame:IsShown() then
      ERC.frame.statusFrame:Hide()
    end
  end
end

-----------------------------------------------------------------------
-- HybridScrollFrame Button-Erzeugung
-----------------------------------------------------------------------
function HSF_CreateButtons (self, buttonTemplate, initialOffsetX, initialOffsetY, initialPoint, initialRelative, offsetX, offsetY, point, relativePoint)
  local scrollChild = self.scrollChild;
  local button, buttonHeight, buttons, numButtons;
  local parentName = self:GetName();
  local buttonName = parentName and (parentName .. "_Button") or nil;

  initialPoint    = initialPoint or "TOPLEFT";
  initialRelative = initialRelative or "TOPLEFT";
  point           = point or "TOPLEFT";
  relativePoint   = relativePoint or "BOTTOMLEFT";
  offsetX         = offsetX or 0;
  offsetY         = offsetY or 0;

  if (self.buttons) then
    buttons = self.buttons;
    buttonHeight = buttons[1]:GetHeight();
  else
    button = CreateFrame("BUTTON", buttonName and (buttonName .. "1_") or nil, scrollChild, buttonTemplate);
    buttonHeight = button:GetHeight();
    button:SetPoint(initialPoint, scrollChild, initialRelative, initialOffsetX, initialOffsetY);
    buttons = {}
    tinsert(buttons, button);
  end

  self.buttonHeight = math.ceil(buttonHeight) - offsetY;
  local numButtons = math.ceil(self:GetHeight() / buttonHeight) + 1;

  for i = #buttons + 1, numButtons do
    button = CreateFrame("BUTTON", buttonName and (buttonName .. i .. "_") or nil, scrollChild, buttonTemplate);
    button:SetPoint(point, buttons[i - 1], relativePoint, offsetX, offsetY);
    tinsert(buttons, button);
  end

  scrollChild:SetWidth(self:GetWidth())
  scrollChild:SetHeight(numButtons * buttonHeight);
  self:SetVerticalScroll(0);
  self:UpdateScrollChildRect();
  self.buttons = buttons;

  local scrollBar = self.scrollBar;
  scrollBar:SetMinMaxValues(0, numButtons * buttonHeight)
  scrollBar.buttonHeight = buttonHeight;
  scrollBar:SetValueStep(buttonHeight);
  scrollBar:SetStepsPerPage(numButtons - 2);
  scrollBar:SetValue(0);
end

-----------------------------------------------------------------------
-- UI-Aufbau
-----------------------------------------------------------------------
function ERC:BuildUI()
  self:DPrint("Building UI")

  self.frame:SetPoint("TOPLEFT",  CalendarCreateEventFrame, "TOPRIGHT", 20, 0)
  self.frame:SetPoint("BOTTOMRIGHT", CalendarCreateEventFrame, "BOTTOMRIGHT", 445, 0)

  -- Scrollframe
  self.frame.scrollFrame = CreateFrame("ScrollFrame", "ERCMainFrameScrollFrame", self.frame, "HybridScrollFrameTemplate")
  self.frame.scrollFrame:SetPoint("TOPLEFT", 12, -8)
  self.frame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 8)
  self.frame.scrollFrame.stepSize = ERC.BUTTON_HEIGHT
  self.frame.scrollFrame.update   = Update

  self.frame.scrollBar = CreateFrame("Slider", "ERCMainFrameScrollFrameScrollBar", self.frame.scrollFrame, "HybridScrollBarTemplate")
  HSF_CreateButtons(self.frame.scrollFrame, "ERCMainFrameTemplate", 0, 0, "TOPLEFT", "TOPLEFT", 0, 0, "TOP", "BOTTOM")

  -- Status-Frame
  self.frame.statusFrame = CreateFrame("Frame", "ERCMainFrameStatus", self.frame, "TooltipBorderedFrameTemplate")
  self.frame.statusFrame:SetPoint("TOPLEFT",     ERCMainFrame, "BOTTOMLEFT", 0, 0)
  self.frame.statusFrame:SetPoint("BOTTOMRIGHT", ERCMainFrame, "BOTTOMRIGHT", 0, -35)

  self.frame.statusFrame.text = self.frame.statusFrame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
  self.frame.statusFrame.text:SetAllPoints()
  self.frame.statusFrame.text:SetPoint("CENTER", 0, 0)

  self.frame.statusFrame.STOPBUTTON = CreateFrame("Button", "ERCMainFrameStatusSTOP", self.frame.statusFrame, "UIPanelButtonTemplate")
  self.frame.statusFrame.STOPBUTTON:SetPoint("LEFT",  self.frame.statusFrame, "RIGHT", -105, 0)
  self.frame.statusFrame.STOPBUTTON:SetPoint("RIGHT", self.frame.statusFrame, "RIGHT",  -15, 0)
  self.frame.statusFrame.STOPBUTTON:SetText("Cancel Tasks")
  self.frame.statusFrame.STOPBUTTON:Show()
  self.frame.statusFrame.STOPBUTTON:SetScript("OnClick", function()
    wipe(self.inviteList)
    wipe(self.removeList)
  end)

  self.frame.statusFrame.NEWEVENT = CreateFrame("Button", "ERCMainFrameStatusNEWEVENT", self.frame.statusFrame, "UIPanelButtonTemplate")
  self.frame.statusFrame.NEWEVENT:SetPoint("LEFT",  self.frame.statusFrame, "LEFT",  15, 0)
  self.frame.statusFrame.NEWEVENT:SetPoint("RIGHT", self.frame.statusFrame, "LEFT", 105, 0)
  self.frame.statusFrame.NEWEVENT:SetText("New Event")
  self.frame.statusFrame.NEWEVENT:Hide()

  self.frame.statusFrame.NEWEVENT:SetScript("OnClick", function()
    local einfo = C_Calendar.GetEventInfo()
    local info  = C_Calendar.GetEventIndex()
    local baseTitle = (einfo and einfo.title and einfo.title ~= "") and einfo.title or "Event"
    ERC.newevent = {
      title       = baseTitle .. "+",
      description = einfo and einfo.description or "",
      eventType   = einfo and einfo.eventType or 1,
      textureIndex= einfo and einfo.textureIndex or 1,
      hour        = einfo and einfo.time and einfo.time.hour or 20,
      minute      = einfo and einfo.time and einfo.time.minute or 0,
      month       = einfo and einfo.time and einfo.time.month or (date("*t").month),
      day         = einfo and einfo.time and einfo.time.monthDay or (date("*t").day),
      year        = einfo and einfo.time and einfo.time.year or (date("*t").year),
    }

    if info and info.eventIndex == 0 then
      C_Calendar.AddEvent()
      C_Timer.After(4, function()
        ERC:DPrint("Creating New Event:")
        ERC:DPrint("Title: " .. ERC.newevent.title)
        ERC:DPrint("Description: " .. ERC.newevent.description)
        ERC:DPrint("eventType: " .. ERC.newevent.eventType)
        ERC:DPrint("textureIndex: " .. ERC.newevent.textureIndex)
        ERC:DPrint("calendarType: " .. (einfo and einfo.calendarType or "n/a"))
        ERC:DPrint("weekday: " .. (einfo and einfo.time and einfo.time.weekday or 0))
        ERC:DPrint("month: " .. ERC.newevent.month)
        ERC:DPrint("day: " .. ERC.newevent.day)
        ERC:DPrint("year: " .. ERC.newevent.year)
        ERC:DPrint("hour: " .. ERC.newevent.hour)
        ERC:DPrint("minute: " .. ERC.newevent.minute)

        ERC.overridewipe = true
        ERC.frame.statusFrame.text:SetText("Creating Event PLEASE wait!")
        C_Calendar.CloseEvent();
        CalendarFrame_HideEventFrame();
        C_Calendar.CreatePlayerEvent();
        CalendarCreateEventFrame.mode = "create";
        CalendarCreateEventFrame.dayButton = _G["CalendarDayButton" .. ERC.newevent.day]
        CalendarFrame_ShowEventFrame(CalendarCreateEventFrame);

        C_Timer.After(3, function()
          C_Calendar.EventSetDate(ERC.newevent.month, ERC.newevent.day, ERC.newevent.year)
          C_Calendar.EventSetTime(ERC.newevent.hour, ERC.newevent.minute)
          C_Calendar.EventSetTitle(ERC.newevent.title)
          C_Calendar.EventSetDescription(ERC.newevent.description)
          C_Calendar.EventSetType(ERC.newevent.eventType)
          if ERC.newevent.eventType == 1 or ERC.newevent.eventType == 2 then
            C_Calendar.EventSetTextureID(ERC.newevent.textureIndex)
          end
          ERC.newevent = {}
        end)
        ERC.overridewipe = false
      end)
    else
      -- Bestehendes Event übernehmen/duplizieren
      ERC:DPrint("Creating New Event (update path):")
      ERC:DPrint("Title: " .. ERC.newevent.title)
      C_Calendar.UpdateEvent()
      ERC.overridewipe = true
      ERC.frame.statusFrame.text:SetText("Creating Event PLEASE wait!")
      C_Calendar.CloseEvent();
      CalendarFrame_HideEventFrame();
      C_Calendar.CreatePlayerEvent();
      CalendarCreateEventFrame.mode = "create";
      CalendarCreateEventFrame.dayButton = _G["CalendarDayButton" .. ERC.newevent.day]
      CalendarFrame_ShowEventFrame(CalendarCreateEventFrame);

      C_Timer.After(3, function()
        C_Calendar.EventSetDate(ERC.newevent.month, ERC.newevent.day, ERC.newevent.year)
        C_Calendar.EventSetTime(ERC.newevent.hour, ERC.newevent.minute)
        C_Calendar.EventSetTitle(ERC.newevent.title)
        C_Calendar.EventSetDescription(ERC.newevent.description)
        C_Calendar.EventSetType(ERC.newevent.eventType)
        if ERC.newevent.eventType == 1 or ERC.newevent.eventType == 2 then
          C_Calendar.EventSetTextureID(ERC.newevent.textureIndex)
        end
        ERC.newevent = {}
      end)
      ERC.overridewipe = false
    end
  end)

  self.frame.statusFrame:Hide()

  -- collapsable bits
  self.workingList        = {} -- array of button content
  self.workingHeadersOpen = {} -- table indexed by header name of heads open

  -- Standard-Style setzen und ggf. ElvUI anwenden
  self:ApplyDefaultStyle()
  self._elvApplied = nil
  self:ApplyElvUISkin()

  self:UpdateWorkingList() -- update display
end

-----------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------
function ERC:OnEvent(event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "Blizzard_Calendar" then
      ERC.frame = CreateFrame("Frame", "ERCMainFrame", CalendarCreateEventFrame, BackdropTemplateMixin and "BackdropTemplate")
      ERC.frame:SetBackdrop(backdrop)
      ERC.frame:SetBackdropColor(0, 0, 0, 0.95)

      ERC.lastTimer          = 0
      ERC.overridewipe       = false
      ERC.eventcreator       = false
      ERC.invite_in_progress = false
      ERC.inviteList         = {}
      ERC.removeList         = {}
      ERC.debug              = false

      -- Defaults (modern NICHT mehr auf 60 absenken)
      if modern then
        defaults.profile.fLVL = 80
        defaults.profile.mLVL = 100
      end

      ERC.db = LibStub("AceDB-3.0"):New("ERCDB", defaults, true)

      ERC.options = {
        name = "General",
        type = "group",
        args = {
          filterLVL = {
            name = "Filter Level",
            desc = "Minimum Level to consider for events",
            type = "range",
            min  = 1,
            max  = defaults.profile.mLVL,
            step = 1,
            set  = function(info, val) ERC.db.profile.fLVL = val; ERC:UpdateWorkingList() end,
            get  = function(info) return ERC.db.profile.fLVL end,
            order = 10,
          },
          elvSkin = {
            name = "ElvUI-Skin aktivieren",
            desc = "Wendet den ElvUI-Look auf ERC an (falls ElvUI/Skins geladen ist).",
            type = "toggle",
            width = "full",
            order = 20,
            set = function(info, val)
              ERC.db.profile.elvUISkin = val
              if val then
                ERC._elvApplied = nil
                ERC:ApplyElvUISkin()
                ERC:UpdateWorkingList()
              else
                ERC._elvApplied = nil
                ERC:ApplyDefaultStyle()
                ERC:UpdateWorkingList()
                ERC:Print("ElvUI-Skin deaktiviert. Für vollständige Rückkehr zum Standard-Look ggf. /reload.")
              end
            end,
            get = function(info) return ERC.db.profile.elvUISkin end,
          },
        }
      }

      LibStub("AceConfig-3.0"):RegisterOptionsTable("ERCOptions", ERC.options);
      ERC.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ERCOptions", "Easy Raid Calendar");

      ERC:BuildUI()

      ERC.frame:SetScript("OnEvent",  ERC.OnEvent)
      ERC.frame:SetScript("OnUpdate", ERC.FrameOnUpdate)
      ERC.frame:RegisterEvent("CALENDAR_ACTION_PENDING")
      ERC.frame:RegisterEvent("CALENDAR_UPDATE_INVITE_LIST")
      ERC.frame:RegisterEvent("GUILD_ROSTER_UPDATE")
      ERC.frame:RegisterEvent("CALENDAR_UPDATE_ERROR")
    end
  end

  if event == "CALENDAR_ACTION_PENDING" then
    local pending = ...
    if pending == false then
      ERC:DPrint("OnEvent() CALENDAR_ACTION_PENDING .. Loaded")
      local info   = C_Calendar.GetEventIndex()
      local e_info = C_Calendar.GetEventInfo();
      if e_info then
        ERC:DPrint(string.format("title: %s Type: %d", e_info.title or "[No Title]", e_info.eventType))
      end
      if info then
        ERC:DPrint(string.format("%d/%d %d", info.offsetMonths, info.monthDay, info.eventIndex))
      end
    else
      ERC:DPrint("OnEvent() CALENDAR_ACTION_PENDING .. Loading...")
    end
    ERC:UpdateWorkingList()
  end

  if event == "GUILD_ROSTER_UPDATE" then
    local changed = ...
    if changed == true then
      ERC:DPrint("OnEvent() GUILD_ROSTER_UPDATE (CHANGE)")
      ERC:UpdateWorkingList()
    else
      ERC:DPrint("OnEvent() GUILD_ROSTER_UPDATE (On/Off)")
    end
  end

  if event == "CALENDAR_UPDATE_INVITE_LIST" then
    local changed = ...
    if changed == true then
      ERC:DPrint("OnEvent() CALENDAR_UPDATE_INVITE_LIST (CHANGE)")
      --clear invite and remove lists
      if ERC.inviteList and self.overridewipe == false then
        ERC:DPrint("WIPE inviteList")
        wipe(ERC.inviteList)
      end
      if ERC.removeList and self.overridewipe == false then
        ERC:DPrint("WIPE removeList")
        wipe(ERC.removeList)
      end
    else
      ERC:DPrint("OnEvent() CALENDAR_UPDATE_INVITE_LIST (On/Off)")
      if self.invite_in_progress then
        ERC:SendMessage("ERC_OP_RESULT", true)
      end
    end
    ERC:UpdateWorkingList()
  end

  if event == "CALENDAR_UPDATE_ERROR" then
    ERC:SendMessage("ERC_OP_RESULT", false)
    ERC:UpdateWorkingList()
  end
end

-----------------------------------------------------------------------
-- Utils
-----------------------------------------------------------------------
function tablelength(T)
  local count = 0
  for _ in pairs(T) do
    count = count + 1
  end
  return count
end

-- called from template's header button <OnClick> handler
function ERC:HeaderOnClick()
  ERC:DPrint("Header " .. self:GetID() .. " Clicked [" .. ERC.workingList[self:GetID()].truename .. "]")
  local command = ERC.workingList[self:GetID()].truename
  ERC.workingHeadersOpen[command] = not ERC.workingHeadersOpen[command]
  ERC:UpdateWorkingList()
end

local function allofrank(rrank)
  C_GuildInfo.GuildRoster()
  local numGuildMembers = GetNumGuildMembers()
  local rmmap = {}
  for z = 1, numGuildMembers do
    local name, rank, rankIndex, level = GetGuildRosterInfo(z);
    if rrank == rank and level >= ERC.db.profile.fLVL then
      rmmap[name] = false
    end
  end
  return rmmap
end

function ERC:HeaderOnInviteAll()
  ERC:DPrint("Header " .. self.rank .. " [Invite ALL] Clicked")
  local invited = {}
  local members = allofrank(self.rank)
  local numInvites = C_Calendar.GetNumInvites()

  for invidx = 1, numInvites do
    local invite_info = C_Calendar.EventGetInvite(invidx)
    tinsert(invited, invite_info.name)
  end

  for k, _ in pairs(members) do
    if tContains(invited, Ambiguate(k, "guild")) or tContains(invited, k) then
      ERC:DPrint("HeaderOnInviteAll() " .. k .. " is already invited")
    else
      ERC:DPrint("HeaderOnInviteAll() " .. k .. " inviting...")
      ERC:SendMessage("ERC_INVITE", k)
    end
  end
end

function ERC:HeaderOnRemoveAll()
  ERC:DPrint("Header " .. self.rank .. " [Remove ALL] Clicked")
  local members = allofrank(self.rank)
  local numInvites = C_Calendar.GetNumInvites()

  for invidx = 1, numInvites do
    local invite_info = C_Calendar.EventGetInvite(invidx)
    ERC:DPrint("HeaderOnRemoveAll() Index:" .. invidx .. " name:" .. invite_info.name)
    if not invite_info.inviteIsMine then
      for k, _ in pairs(members) do
        if Ambiguate(k, "guild") == invite_info.name then
          ERC:DPrint("HeaderOnRemoveAll() " .. invite_info.name .. " scheduled for remove")
          ERC:SendMessage("ERC_UNINVITE", invite_info.name)
        end
      end
    end
  end
end

function ERC:DetailOnInvite()
  ERC:DPrint("Detail " .. self.target .. " [Invite] Clicked")
  ERC:SendMessage("ERC_INVITE", self.target)
end

function ERC:DetailOnRemove()
  ERC:DPrint("Detail " .. self.target .. " [Remove] Clicked")
  ERC:SendMessage("ERC_UNINVITE", self.target)
end

function ERC:UpdateWorkingList()
  ERC:DPrint("UpdateWorkingList()")
  wipe(self.workingList)
  C_GuildInfo.GuildRoster()

  local rmmap = {}
  local numGuildMembers = GetNumGuildMembers()
  for z = 1, numGuildMembers do
    local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(z);
    rmmap[rankIndex + 1] = rmmap[rankIndex + 1] or {}
    if level >= self.db.profile.fLVL then
      local color = GetClassColorObj and GetClassColorObj(classFileName) or { r = 1, g = 1, b = 1, a = 1 }
      tinsert(rmmap[rankIndex + 1], z, {
        name = name, rname = rank,
        shortname = Ambiguate(name, "guild"),
        color = color
      })
    end
  end

  for k, v in pairs(rmmap) do
    local rname   = GuildControlGetRankName(k)
    local bigname = string.format("%s (%d)", rname, tablelength(allofrank(rname)))
    tinsert(self.workingList, { rank = k, truename = rname, name = bigname, header = true, invited = false })
    if self.workingHeadersOpen[rname] then
      for i, g in pairs(v) do
        tinsert(self.workingList, { rank = k, idx = i, name = g.name, shortname = g.shortname, color = g.color, header = false, invited = false })
      end
    end
  end

  local numInvites = C_Calendar.GetNumInvites()
  for invidx = 1, numInvites do
    local invite_info = C_Calendar.EventGetInvite(invidx)
    for k, v in pairs(self.workingList) do
      if v.header == false and (v.name == invite_info.name or v.shortname == invite_info.name) then
        self.workingList[k].invited = true
      end
    end
  end

  if not self.frame or not self.frame.scrollFrame then
    return
  end

  Update()
end

-----------------------------------------------------------------------
-- Listen-Update/Renderer
-----------------------------------------------------------------------
function Update(...)
  ERC:DPrint("Update(...)")
  local self = self or ERC
  if not self.frame then return end

  local offset  = HybridScrollFrame_GetOffset(self.frame.scrollFrame)
  local buttons = self.frame.scrollFrame.buttons

  for i = 1, #buttons do
    local index  = i + offset
    local button = buttons[i]
    button:Hide()

    if index <= tablelength(self.workingList) then
      button:SetID(index)
      local item = self.workingList[index]

      if item.header then
        button.ERCHeader.text:SetText(item.name)
        button.ERCHeader.btn1:SetText("Invite All")
        button.ERCHeader.btn1.rank = item.truename
        button.ERCHeader.btn2:SetText("Remove All")
        button.ERCHeader.btn2.rank = item.truename

        if self.workingHeadersOpen[item.truename] then
          button.ERCHeader.expandIcon:SetTexCoord(0.5625, 1, 0, 0.4375) -- minus sign
        else
          button.ERCHeader.expandIcon:SetTexCoord(0, 0.4375, 0, 0.4375) -- plus sign
        end

        button.ERCDetail:Hide()
        button.ERCHeader:Show()

        -- ElvUI-Skin optional anwenden
        ElvSkinButton(button.ERCHeader.btn1)
        ElvSkinButton(button.ERCHeader.btn2)
      else
        button.ERCDetail.text:SetText(modern and item.name or item.shortname)
        button.ERCDetail.text:SetTextColor(item.color.r, item.color.g, item.color.b, item.color.a)

        if item.invited == true then
          button.ERCDetail.btn1:Disable()
          button.ERCDetail.btn2:Enable()
        else
          button.ERCDetail.btn1:Enable()
          button.ERCDetail.btn2:Disable()
        end

        button.ERCDetail.btn1:SetText("Invite")
        button.ERCDetail.btn1.target = item.name
        button.ERCDetail.btn2:SetText("Remove")
        button.ERCDetail.btn2.target = item.name

        button.ERCHeader:Hide()
        button.ERCDetail:Show()

        -- ElvUI-Skin optional anwenden
        ElvSkinButton(button.ERCDetail.btn1)
        ElvSkinButton(button.ERCDetail.btn2)
      end

      button:Show()
    end
  end

  HybridScrollFrame_Update(self.frame.scrollFrame, ERC.BUTTON_HEIGHT * #self.workingList, ERC.BUTTON_HEIGHT)

  -- Falls ElvUI vorhanden, einmalig Gesamt-Skin anwenden
  self:ApplyElvUISkin()
end
