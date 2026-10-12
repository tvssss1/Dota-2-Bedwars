if StrategyShop == nil then StrategyShop = {} end

-- Keep this list aligned with the map's existing "pregame" shop block in
-- scripts/vscripts/shops/BW_Solo_shops.txt. Purchases themselves are
-- handled by Dota's DOTAPreGamePurchaseItem event on the client; this service
-- only publishes authoritative, patch-current prices for the custom UI.
StrategyShop.CATALOG = {
    "item_faerie_fire",
    "item_enchanted_mango",
    "item_ward_observer",
    "item_ward_sentry",
    "item_branches",
    "item_gauntlets",
    "item_slippers",
    "item_mantle",
    "item_ring_of_protection",
    "item_quelling_blade",
    "item_orb_of_venom",
    "item_wind_lace",
    "item_sobi_mask",
    "item_ring_of_regen",
    "item_boots",
    "item_gloves",
    "item_crown",
    "item_wraith_band",
    "item_null_talisman",
    "item_bracer",
    "item_blades_of_attack"
}

function StrategyShop:Init()
    local items = {}
    for index, itemName in ipairs(self.CATALOG) do
        items[tostring(index)] = {
            item_name = itemName,
            cost = math.max(0, GetItemCost(itemName) or 0)
        }
    end
    CustomNetTables:SetTableValue("strategy_shop", "catalog", { items=items })
end

return StrategyShop
