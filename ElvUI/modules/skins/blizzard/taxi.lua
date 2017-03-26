local E, L, V, P, G = unpack(select(2, ...));
local S = E:GetModule("Skins");

local function LoadSkin()
	if(E.private.skins.blizzard.enable ~= true or E.private.skins.blizzard.taxi ~= true) then return; end

	TaxiFrame:StripTextures();
	TaxiFrame:CreateBackdrop("Transparent");

	TaxiRouteMap:CreateBackdrop("Default");

	S:HandleCloseButton(TaxiFrame.CloseButton)
end

S:AddCallback("Taxi", LoadSkin);