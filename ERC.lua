---@class ERC
ERC = LibStub("AceAddon-3.0"):NewAddon("ERC", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

ERC.BUTTON_HEIGHT = 25

local backdrop = {
    -- path to the background texture
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    -- path to the border texture
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    -- true to repeat the background texture to fill the frame, false to scale it
    tile = true,
    -- size (width or height) of the square repeating background tiles (in pixels)
    tileSize = 32,
    -- thickness of edge segments and square size of edge corners (in pixels)
    edgeSize = 32,
    -- distance from the edges of the frame to those of the background texture (in pixels)
    insets = {
        left = 11,
        right = 12,
        top = 12,
        bottom = 11
    }
}

local defaults = {
    profile = {
        fLVL = 90,
        mLVL = 90
    }
}

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

    ERC:RegisterMessage("ERC_INVITE", self.InviteHandler)
    ERC:RegisterMessage("ERC_UNINVITE", self.UninviteHandler)
end

function ERC:OnDisable()
    ERC:DPrint("OnDisable()")

    self.frame:UnregisterEvent("CALENDAR_ACTION_PENDING")
    self.frame:UnregisterEvent("CALENDAR_UPDATE_INVITE_LIST")
    self.frame:UnregisterEvent("GUILD_ROSTER_UPDATE")
    self.frame:UnregisterEvent("CALENDAR_UPDATE_ERROR")

    ERC:UnregisterMessage("ERC_INVITE")
    ERC:UnregisterMessage("ERC_UNINVITE")
end

function ERC:DPrint(...)
    if self.debug then
        ERC:Print(...)
    end
end

function ERC:ChatCommand(input)
    if not input or input:trim() == "" then
        ERC:DPrint("Empty command")
    end
    if input:trim() == "debug on" then
        ERC:DPrint(input)
        self.debug = true
    end
    if input:trim() == "debug off" then
        self.debug = false
        ERC:DPrint(input)
    end

end

function ERC:InviteHandler(target)
    ERC:DPrint("ERC:InviteHandler() " .. tostring(target))
    tinsert(ERC.inviteList, target)
end

function ERC:UninviteHandler(target)
    ERC:DPrint("ERC:UninviteHandler() " .. tostring(target))
    tinsert(ERC.removeList, target)
end

function ERC:FrameOnUpdate(elapsed)
    ERC.lastTimer = ERC.lastTimer + elapsed
    local canAdd = C_Calendar.CanAddEvent()
    if ERC.lastTimer > 2.0 and canAdd then
        -- One operation per tick: invite OR remove, never both.
        -- The 2s timer plus WoW's own calendar throttle handles spacing;
        -- no in_progress flag needed (it had a sync-event race that stuck the queue).
        if ERC.inviteList ~= nil and tablelength(ERC.inviteList) > 0 then
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
                local isinvited = false
                for invidx = 1, numInvites do
                    local invite_info = C_Calendar.EventGetInvite(invidx)
                    if invite_info then
                        if (Ambiguate(invite, "guild") == invite_info.name or invite == invite_info.name) and not invite_info.inviteIsMine then
                            ERC:DPrint("FrameOnUpdate() " .. invite .. " is already invited.")
                            isinvited = true
                            break
                        end
                    end
                end
                if not isinvited then
                    C_Calendar.EventInvite(invite)
                end
            end
        elseif ERC.removeList ~= nil and tablelength(ERC.removeList) > 0 then
            local rem = table.remove(ERC.removeList, 1)
            local numInvites = C_Calendar.GetNumInvites()
            for invidx = 1, numInvites do
                local invite_info = C_Calendar.EventGetInvite(invidx)
                if invite_info then
                    if (Ambiguate(rem, "guild") == invite_info.name or rem == invite_info.name) and not invite_info.inviteIsMine then
                        ERC:DPrint("FrameOnUpdate() CalendarEventRemoveInvite(" .. tostring(invidx) .. ") for " .. rem)
                        C_Calendar.EventRemoveInvite(invidx)
                        break
                    end
                end
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

function HSF_CreateButtons (self, buttonTemplate, initialOffsetX, initialOffsetY, initialPoint, initialRelative, offsetX, offsetY, point, relativePoint)
    local scrollChild = self.scrollChild;
    local button, buttonHeight, buttons;

    local parentName = self:GetName();
    local buttonName = parentName and (parentName .. "_Button") or nil;

    initialPoint = initialPoint or "TOPLEFT";
    initialRelative = initialRelative or "TOPLEFT";
    point = point or "TOPLEFT";
    relativePoint = relativePoint or "BOTTOMLEFT";
    offsetX = offsetX or 0;
    offsetY = offsetY or 0;

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
    scrollBar:SetStepsPerPage(numButtons - 2); -- one additional button was added above. Need to remove that, and one more to make the current bottom the new top (and vice versa)
    scrollBar:SetValue(0);

end

function ERC:BuildUI()
    ERC:DPrint("Building")
    self.frame:SetPoint("TOPLEFT", CalendarCreateEventFrame, "TOPRIGHT", 20, 0)
    self.frame:SetPoint("BOTTOMRIGHT", CalendarCreateEventFrame, "BOTTOMRIGHT", 400, 0)

    -- scrollframe is the mousewheel'able area where buttons will be drawn
    self.frame.scrollFrame = CreateFrame("ScrollFrame", "ERCMainFrameScrollFrame", self.frame, "HybridScrollFrameTemplate")
    self.frame.scrollFrame:SetPoint("TOPLEFT", 12, -8)
    self.frame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 8)
    self.frame.scrollFrame.stepSize = ERC.BUTTON_HEIGHT -- jump by 4 buttons on mousewheel
    self.frame.scrollFrame.update = Update
    self.frame.scrollBar = CreateFrame("Slider", "ERCMainFrameScrollFrameScrollBar", self.frame.scrollFrame, "HybridScrollBarTemplate")
    HSF_CreateButtons(self.frame.scrollFrame, "ERCMainFrameTemplate", 0, 0, "TOPLEFT", "TOPLEFT", 0, 0, "TOP", "BOTTOM")


    -- scrollbar is just to the right of the scrollframe

    --self.frame.scrollBar:SetPoint("TOPLEFT",0,-8)
    --self.frame.scrollBar:SetPoint("BOTTOMRIGHT",-30,8)

    self.frame.statusFrame = CreateFrame("Frame", "ERCMainFrameStatus", self.frame, "TooltipBorderedFrameTemplate")
    self.frame.statusFrame:SetPoint("TOPLEFT", ERCMainFrame, "BOTTOMLEFT", 0, 0)
    self.frame.statusFrame:SetPoint("BOTTOMRIGHT", ERCMainFrame, "BOTTOMRIGHT", 0, -35)
    self.frame.statusFrame.text = self.frame.statusFrame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    self.frame.statusFrame.text:SetAllPoints()
    self.frame.statusFrame.text:SetPoint("CENTER", 0, 0)
    self.frame.statusFrame.STOPBUTTON = CreateFrame("Button", "ERCMainFrameStatusSTOP", self.frame.statusFrame, "UIPanelButtonTemplate")
    self.frame.statusFrame.STOPBUTTON:SetPoint("LEFT", self.frame.statusFrame, "RIGHT", -105, 0)
    self.frame.statusFrame.STOPBUTTON:SetPoint("RIGHT", self.frame.statusFrame, "RIGHT", -15, 0)
    self.frame.statusFrame.STOPBUTTON:SetText("Cancel Tasks")
    self.frame.statusFrame.STOPBUTTON:Show()
    self.frame.statusFrame.STOPBUTTON:SetScript("OnClick", function()
        wipe(self.inviteList)
        wipe(self.removeList)
    end)
    self.frame.statusFrame.NEWEVENT = CreateFrame("Button", "ERCMainFrameStatusNEWEVENT", self.frame.statusFrame, "UIPanelButtonTemplate")
    self.frame.statusFrame.NEWEVENT:SetPoint("LEFT", self.frame.statusFrame, "LEFT", 15, 0)
    self.frame.statusFrame.NEWEVENT:SetPoint("RIGHT", self.frame.statusFrame, "LEFT", 105, 0)
    self.frame.statusFrame.NEWEVENT:SetText("New Event")
    self.frame.statusFrame.NEWEVENT:Hide()
    self.frame.statusFrame.NEWEVENT:SetScript("OnClick", function()
        local einfo = C_Calendar.GetEventInfo()
        local info = C_Calendar.GetEventIndex()
        ERC.newevent = { title = einfo.title .. "+", description = einfo.description, eventType = einfo.eventType, textureIndex = einfo.textureIndex, hour = einfo.time.hour, minute = einfo.time.minute, month = einfo.time.month, day = einfo.time.monthDay, year = einfo.time.year }
        if info.eventIndex == 0 then
            C_Calendar.AddEvent()
            C_Timer.After(4, function()
                ERC:DPrint("Creating New Event:")
                ERC:DPrint("Title: " .. ERC.newevent.title)
                ERC:DPrint("Description: " .. ERC.newevent.description)
                ERC:DPrint("eventType: " .. ERC.newevent.eventType)
                ERC:DPrint("textureIndex: " .. ERC.newevent.textureIndex)
                ERC:DPrint("calendarType: " .. einfo.calendarType)
                ERC:DPrint("weekday: " .. einfo.time.weekday)
                ERC:DPrint("month: " .. ERC.newevent.month)
                ERC:DPrint("day: " .. ERC.newevent.day)
                ERC:DPrint("year: " .. ERC.newevent.year)
                ERC:DPrint("hour: " .. ERC.newevent.hour)
                ERC:DPrint("minute: " .. ERC.newevent.minute)

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
                    if einfo.eventType == 1 or einfo.eventType == 2 then
                        C_Calendar.EventSetTextureID(ERC.newevent.textureIndex)
                    end
                    ERC.newevent = {}
                end)
            end)
        else
            ERC:DPrint("Creating New Event:")
            ERC:DPrint("Title: " .. ERC.newevent.title)
            ERC:DPrint("Description: " .. ERC.newevent.description)
            ERC:DPrint("eventType: " .. ERC.newevent.eventType)
            ERC:DPrint("textureIndex: " .. ERC.newevent.textureIndex)
            ERC:DPrint("calendarType: " .. einfo.calendarType)
            ERC:DPrint("weekday: " .. einfo.time.weekday)
            ERC:DPrint("month: " .. ERC.newevent.month)
            ERC:DPrint("day: " .. ERC.newevent.day)
            ERC:DPrint("year: " .. ERC.newevent.year)
            ERC:DPrint("hour: " .. ERC.newevent.hour)
            ERC:DPrint("minute: " .. ERC.newevent.minute)

            C_Calendar.UpdateEvent()

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
                if einfo.eventType == 1 or einfo.eventType == 2 then
                    C_Calendar.EventSetTextureID(ERC.newevent.textureIndex)
                end
                ERC.newevent = {}
            end)
        end
    end)
    self.frame.statusFrame:Hide()
    -- collapsable bits
    self.workingList = {} -- array of button content
    self.workingHeadersOpen = {} -- table indexed by header name of heads open

    self:UpdateWorkingList() -- update display
end

function ERC:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local arg1 = ...
        if arg1 == "Blizzard_Calendar" then
            ERC.frame = CreateFrame("Frame", "ERCMainFrame", CalendarCreateEventFrame, BackdropTemplateMixin and "BackdropTemplate")
            ERC.frame:SetBackdrop(backdrop)
            ERC.frame:SetBackdropColor(0, 0, 0, 0.95)
            ERC.lastTimer = 0
            ERC.eventcreator = false
            ERC.inviteList = {}
            ERC.removeList = {}
            ERC.debug = false
            ERC.db = LibStub("AceDB-3.0"):New("ERCDB", defaults, true)
            ERC.options = {
                name = "General",
                type = "group",
                args = {
                    filterLVL = {
                        name = "Filter Level",
                        desc = "Minimum Level to conisider for events",
                        type = "range",
                        min = 1,
                        max = defaults.profile.mLVL,
                        step = 1,
                        set = function(info, val)
                            ERC.db.profile.fLVL = val
                        end,
                        get = function(info)
                            return ERC.db.profile.fLVL
                        end,
                    }
                }
            }
            LibStub("AceConfig-3.0"):RegisterOptionsTable("ERCOptions", ERC.options);
            ERC.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ERCOptions", "Easy Raid Calendar");

            ERC:BuildUI()

            ERC.frame:SetScript("OnEvent", ERC.OnEvent)
            ERC.frame:SetScript("OnUpdate", ERC.FrameOnUpdate)

            ERC.frame:RegisterEvent("CALENDAR_ACTION_PENDING")
            ERC.frame:RegisterEvent("CALENDAR_UPDATE_INVITE_LIST")
            ERC.frame:RegisterEvent("GUILD_ROSTER_UPDATE")
            ERC.frame:RegisterEvent("CALENDAR_UPDATE_ERROR")
        end
    end
    if event == "CALENDAR_ACTION_PENDING" then
        local arg1 = ...
        if arg1 == false then
            ERC:DPrint("OnEvent() CALENDAR_ACTION_PENDING .. Loaded")
            local info = C_Calendar.GetEventIndex()
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
        local arg1 = ...
        if arg1 == true then
            ERC:DPrint("OnEvent() GUILD_ROSTER_UPDATE (CHANGE)")
            ERC:UpdateWorkingList()
        else
            ERC:DPrint("OnEvent() GUILD_ROSTER_UPDATE (On/Off)")
        end
    end
    if event == "CALENDAR_UPDATE_INVITE_LIST" then
        ERC:DPrint("OnEvent() CALENDAR_UPDATE_INVITE_LIST")
        ERC:UpdateWorkingList()
    end
    if event == "CALENDAR_UPDATE_ERROR" then
        ERC:DPrint("OnEvent() CALENDAR_UPDATE_ERROR")
        ERC:UpdateWorkingList()
    end
end

function tablelength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

-- called from template's header button <OnClick> handler
function ERC:HeaderOnClick()
    local item = ERC.workingList[self:GetID()]
    if not item then return end
    ERC:DPrint("Header " .. self:GetID() .. " Clicked [" .. item.truename .. "]")

    -- toggle whether header expanded or not (keyed by rank index, since rank names can duplicate)
    ERC.workingHeadersOpen[item.rank] = not ERC.workingHeadersOpen[item.rank]
    ERC:UpdateWorkingList()
end

-- rankID is 1-based (matches workingList[i].rank == rankIndex + 1).
-- Match by index, not name, since WoW guild ranks can have duplicate names.
function allofrank(rankID)
    C_GuildInfo.GuildRoster()
    local numGuildMembers = GetNumGuildMembers()
    local rmmap = {}
    for z = 1, numGuildMembers do
        local name, _, rankIndex, level = GetGuildRosterInfo(z)
        if rankID == rankIndex + 1 and level >= ERC.db.profile.fLVL then
            rmmap[name] = false
        end
    end
    return rmmap
end

function ERC:HeaderOnInviteAll()
    local item = ERC.workingList[self:GetParent():GetParent():GetID()]
    if not item or not item.header then return end
    local rname = item.truename
    ERC:DPrint("Header " .. rname .. " [Invite ALL] Clicked")
    local invited = {}
    local info = C_Calendar.GetEventIndex()
    local members = allofrank(item.rank)
    local numInvites = C_Calendar.GetNumInvites()
    for invidx = 1, numInvites do
        local invite_info = C_Calendar.EventGetInvite(invidx)
        tinsert(invited, invite_info.name)
    end
    for k, v in pairs(members) do
        if tContains(invited, Ambiguate(k, "guild")) or tContains(invited, k) then
            ERC:DPrint("HeaderOnInviteAll() " .. k .. " is already invited")
        else
            ERC:DPrint("HeaderOnInviteAll() " .. k .. " inviting...")
            ERC:SendMessage("ERC_INVITE", k)
            --CalendarEventInvite(k)
        end
    end
end

function ERC:HeaderOnRemoveAll()
    local item = ERC.workingList[self:GetParent():GetParent():GetID()]
    if not item or not item.header then return end
    local rname = item.truename
    ERC:DPrint("Header " .. rname .. " [Remove ALL] Clicked")
    local info = C_Calendar.GetEventIndex()
    local members = allofrank(item.rank)
    local numInvites = C_Calendar.GetNumInvites()
    for invidx = 1, numInvites do
        local invite_info = C_Calendar.EventGetInvite(invidx)
        ERC:DPrint("HeaderOnRemoveAll() Index:" .. invidx .. " name:" .. invite_info.name)
        if not invite_info.inviteIsMine then
            -- WoW's calendar gives same-realm names stripped ("Foo") and cross-realm
            -- names full ("Foo-Realm"). Ambiguate(_, "guild") always strips, so for
            -- cross-realm invites we'd miss the match without the full-name fallback.
            for k, v in pairs(members) do
                if Ambiguate(k, "guild") == invite_info.name or k == invite_info.name then
                    ERC:DPrint("HeaderOnRemoveAll() " .. invite_info.name .. " scheduled for remove")
                    ERC:SendMessage("ERC_UNINVITE", invite_info.name)
                    break
                end
            end
        end
    end
end

function ERC:DetailOnInvite()
    local item = ERC.workingList[self:GetParent():GetParent():GetID()]
    if not item or item.header then return end
    ERC:DPrint("Detail " .. item.name .. " [Invite] Clicked")
    ERC:SendMessage("ERC_INVITE", item.name)
end

function ERC:DetailOnRemove()
    local item = ERC.workingList[self:GetParent():GetParent():GetID()]
    if not item or item.header then return end
    ERC:DPrint("Detail " .. item.name .. " [Remove] Clicked")
    ERC:SendMessage("ERC_UNINVITE", item.name)
end

function ERC:UpdateWorkingList()
    ERC:DPrint("UpdateWorkingList()")
    wipe(self.workingList)
    C_GuildInfo.GuildRoster()
    --GuildRoster()
    local rmmap = {}
    local numGuildMembers, numOnline, numOnlineAndMobile = GetNumGuildMembers()
    for z = 1, numGuildMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile = GetGuildRosterInfo(z);

        if rmmap[rankIndex + 1] == nil then
            rmmap[rankIndex + 1] = {}
        end
        if level >= self.db.profile.fLVL then
            tinsert(rmmap[rankIndex + 1], { name = name, rname = rank, shortname = Ambiguate(name, "guild"), color = GetClassColorObj(classFileName) })
        end
    end
    for k, v in pairs(rmmap) do
        local rname = GuildControlGetRankName(k)
        local bigname = string.format("%s (%d)", rname, tablelength(v))
        tinsert(self.workingList, { rank = k, truename = rname, name = bigname, header = true, invited = false })
        if self.workingHeadersOpen[k] then
            for i, g in ipairs(v) do
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

function Update(...)
    ERC:DPrint("Update(...)")
    local self = self or ERC
    if not self.frame then
        return
    end
    local offset = HybridScrollFrame_GetOffset(self.frame.scrollFrame)
    local buttons = self.frame.scrollFrame.buttons
    for i = 1, #buttons do
        local index = i + offset
        local button = buttons[i]
        button:Hide()
        if index <= tablelength(self.workingList) then
            button:SetID(index)
            local item = self.workingList[index]
            if item.header then


                button.ERCHeader.text:SetText(item.name)
                button.ERCHeader.btn1:SetText("Invite All")
                button.ERCHeader.btn2:SetText("Remove All")
                if self.workingHeadersOpen[item.rank] then
                    button.ERCHeader.expandIcon:SetTexCoord(0.5625, 1, 0, 0.4375) -- minus sign
                else
                    button.ERCHeader.expandIcon:SetTexCoord(0, 0.4375, 0, 0.4375) -- plus sign
                end
                button.ERCDetail:Hide()
                button.ERCHeader:Show()
            else
                button.ERCDetail.text:SetText(item.name)
                button.ERCDetail.text:SetTextColor(item.color.r, item.color.g, item.color.b, item.color.a)
                if item.invited == true then
                    button.ERCDetail.btn1:Disable()
                    button.ERCDetail.btn2:Enable()
                else
                    button.ERCDetail.btn1:Enable()
                    button.ERCDetail.btn2:Disable()
                end
                button.ERCDetail.btn1:SetText("Invite")
                button.ERCDetail.btn2:SetText("Remove")
                button.ERCHeader:Hide()
                button.ERCDetail:Show()
            end
            button:Show()
        end
    end
    HybridScrollFrame_Update(self.frame.scrollFrame, ERC.BUTTON_HEIGHT * #self.workingList, ERC.BUTTON_HEIGHT)
end
