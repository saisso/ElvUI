local E, L, V, P, G = unpack(select(2, ...));
local M = E:NewModule("WorldMap", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0");
E.WorldMap = M;

local find = string.find;

local CreateFrame = CreateFrame;
local InCombatLockdown = InCombatLockdown;
local GetPlayerMapPosition = GetPlayerMapPosition;
local GetCursorPosition = GetCursorPosition;
local PLAYER = PLAYER;
local MOUSE_LABEL = MOUSE_LABEL;
local WORLDMAP_FULLMAP_SIZE = WORLDMAP_FULLMAP_SIZE;
local WORLDMAP_QUESTLIST_SIZE = WORLDMAP_QUESTLIST_SIZE;
local WORLDMAP_WINDOWED_SIZE = WORLDMAP_WINDOWED_SIZE;

local INVERTED_POINTS = {
	["TOPLEFT"] = "BOTTOMLEFT",
	["TOPRIGHT"] = "BOTTOMRIGHT",
	["BOTTOMLEFT"] = "TOPLEFT",
	["BOTTOMRIGHT"] = "TOPRIGHT",
	["TOP"] = "BOTTOM",
	["BOTTOM"] = "TOP"
};

function SetUIPanelAttribute(frame, name, value)
	local info = UIPanelWindows[frame:GetName()];
	if(not info) then
		return;
	end

	if(not frame:GetAttribute("UIPanelLayout-defined")) then
		frame:SetAttribute("UIPanelLayout-defined", true);
		for name,value in pairs(info) do
			frame:SetAttribute("UIPanelLayout-"..name, value);
		end
	end

	frame:SetAttribute("UIPanelLayout-"..name, value);
end

function M:SetLargeWorldMap()
	if(InCombatLockdown()) then return; end

	WorldMapFrame:SetParent(E.UIParent);
	WorldMapFrame:EnableKeyboard(false);
	WorldMapFrame:SetScale(1);
	WorldMapFrame:EnableMouse(false);
	WorldMapTooltip:SetFrameStrata("TOOLTIP");
	WorldMapCompareTooltip1:SetFrameStrata("TOOLTIP");
	WorldMapCompareTooltip2:SetFrameStrata("TOOLTIP");

	if(WorldMapFrame:GetAttribute('UIPanelLayout-area') ~= 'center') then
		SetUIPanelAttribute(WorldMapFrame, "area", "center");
	end

	if(WorldMapFrame:GetAttribute('UIPanelLayout-allowOtherPanels') ~= true) then
		SetUIPanelAttribute(WorldMapFrame, "allowOtherPanels", true);
	end

	WorldMapFrameSizeUpButton:Hide();
	WorldMapFrameSizeDownButton:Show();
end

function M:SetSmallWorldMap()
	if(InCombatLockdown()) then return; end

	WorldMapFrameSizeUpButton:Show();
	WorldMapFrameSizeDownButton:Hide();
end

function M:PLAYER_REGEN_ENABLED()
	WorldMapFrameSizeDownButton:Enable();
	WorldMapFrameSizeUpButton:Enable();
end

function M:PLAYER_REGEN_DISABLED()
	WorldMapFrameSizeDownButton:Disable();
	WorldMapFrameSizeUpButton:Disable();
end

function M:UpdateCoords()
	if(not WorldMapFrame:IsShown()) then return; end
	local x, y = GetPlayerMapPosition("player");
	x = E:Round(100 * x, 2);
	y = E:Round(100 * y, 2);

	if(x ~= 0 and y ~= 0) then
		CoordsHolder.playerCoords:SetText(PLAYER..":   "..x..", "..y);
	else
		CoordsHolder.playerCoords:SetText("");
	end

	local scale = WorldMapDetailFrame:GetEffectiveScale();
	local width = WorldMapDetailFrame:GetWidth();
	local height = WorldMapDetailFrame:GetHeight();
	local centerX, centerY = WorldMapDetailFrame:GetCenter();
	local x, y = GetCursorPosition();
	local adjustedX = (x / scale - (centerX - (width/2))) / width;
	local adjustedY = (centerY + (height/2) - y / scale) / height;

	if(adjustedX >= 0 and adjustedY >= 0 and adjustedX <= 1 and adjustedY <= 1) then
		adjustedX = E:Round(100 * adjustedX, 2);
		adjustedY = E:Round(100 * adjustedY, 2);
		CoordsHolder.mouseCoords:SetText(MOUSE_LABEL..":   "..adjustedX..", "..adjustedY);
	else
		CoordsHolder.mouseCoords:SetText("");
	end
end

function M:PositionCoords()
	local db = E.global.general.WorldMapCoordinates;
	local position = db.position;
	local xOffset = db.xOffset;
	local yOffset = db.yOffset;

	local x, y = 5, 5;
	if(find(position, "RIGHT")) then x = -5; end
	if(find(position, "TOP")) then y = -5; end

	CoordsHolder.playerCoords:ClearAllPoints();
	CoordsHolder.playerCoords:Point(position, WorldMapDetailFrame, position, x + xOffset, y + yOffset);
	CoordsHolder.mouseCoords:ClearAllPoints();
	CoordsHolder.mouseCoords:Point(position, CoordsHolder.playerCoords, INVERTED_POINTS[position], 0, y);
end

function M:Initialize()
	if(E.global.general.WorldMapCoordinates.enable) then
		local coordsHolder = CreateFrame("Frame", "CoordsHolder", WorldMapFrame);
		coordsHolder:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 1);
		coordsHolder:SetFrameStrata(WorldMapDetailFrame:GetFrameStrata());
		coordsHolder.playerCoords = coordsHolder:CreateFontString(nil, "OVERLAY");
		coordsHolder.mouseCoords = coordsHolder:CreateFontString(nil, "OVERLAY");
		coordsHolder.playerCoords:SetTextColor(1, 1 ,0);
		coordsHolder.mouseCoords:SetTextColor(1, 1 ,0);
		coordsHolder.playerCoords:SetFontObject(NumberFontNormal);
		coordsHolder.mouseCoords:SetFontObject(NumberFontNormal);
		coordsHolder.playerCoords:SetPoint("BOTTOMLEFT", WorldMapDetailFrame, "BOTTOMLEFT", 5, 5);
		coordsHolder.playerCoords:SetText(PLAYER .. ":   0, 0");
		coordsHolder.mouseCoords:SetPoint("BOTTOMLEFT", coordsHolder.playerCoords, "TOPLEFT", 0, 5);
		coordsHolder.mouseCoords:SetText(MOUSE_LABEL .. ":   0, 0");

		self:ScheduleRepeatingTimer("UpdateCoords", 0.05);
		self:PositionCoords();
	end

	if(E.global.general.smallerWorldMap) then
		BlackoutWorld:SetTexture(nil);
		WorldMapBlobFrame.Show = E.noop;
		WorldMapBlobFrame.Hide = E.noop;
		self:SecureHook("WorldMap_ToggleSizeDown", "SetSmallWorldMap");
		self:SecureHook("WorldMap_ToggleSizeUp", "SetLargeWorldMap");
		self:RegisterEvent("PLAYER_REGEN_ENABLED");
		self:RegisterEvent("PLAYER_REGEN_DISABLED");

		if(WORLDMAP_SETTINGS.size == WORLDMAP_FULLMAP_SIZE) then
			WorldMap_ToggleSizeDown();
		elseif(WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE) then
			self:SetSmallWorldMap();
		elseif(WORLDMAP_SETTINGS.size == WORLDMAP_QUESTLIST_SIZE) then
			WorldMap_ToggleSizeDown();
		end

		DropDownList1:HookScript("OnShow", function()
			if(DropDownList1:GetScale() ~= UIParent:GetScale()) then
				DropDownList1:SetScale(UIParent:GetScale());
			end
		end);
	end
end

E:RegisterInitialModule(M:GetName());