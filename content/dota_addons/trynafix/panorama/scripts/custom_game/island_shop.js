var IslandShop = {};
(function () {
    "use strict";

    var panel = $.GetContextPanel();
    var playerID = Game.GetLocalPlayerID();
    var modal = panel.FindChildTraverse("IslandShopModal");
    var closeButton = panel.FindChildTraverse("IslandShopClose");
    var nearby = false;
    var balance = 0;
    var focusCycle = 0;

    function localize(token) { return $.Localize(token, panel); }
    function slotKey(slot) { return "slot_" + (slot < 10 ? "0" : "") + slot; }
    function sound(name) { Game.EmitSound(name); }
    function hoverSound() { sound("ui_generic_button_over"); }

    function setBalance(data) {
        balance = data && data.balance !== undefined ? Number(data.balance) : 0;
        panel.FindChildTraverse("IslandBalance").text = localize("#island_shop_balance") + ": " + balance;
    }

    function close() {
        modal.AddClass("Hidden");
        modal.hittest = false;
        modal.hittestchildren = false;
    }

    function setNearby(value) {
        nearby = !!value;
        panel.FindChildTraverse("IslandContext").text = localize(nearby ? "#island_shop_nearby" : "#island_shop_not_nearby");
    }

    function build() {
        var catalog = panel.FindChildTraverse("IslandCatalog");
        catalog.RemoveAndDeleteChildren();

        for (var slot = 1; slot <= 10; slot++) {
            var entry = CustomNetTables.GetTableValue("island_shop_catalog", slotKey(slot));
            if (!entry) continue;

            var enabled = !!entry.enabled;
            var row = $.CreatePanel("Panel", catalog, "IslandSlot_" + slot);
            row.AddClass("IslandEntry");
            row.SetHasClass("Locked", !enabled);

            var customIcon = String(entry.icon).indexOf("file://") === 0;
            var icon = $.CreatePanel(customIcon ? "Image" : "DOTAItemImage", row, "");
            icon.AddClass("IslandIcon");
            if (customIcon) icon.SetImage(entry.icon); else icon.itemname = entry.icon;

            var info = $.CreatePanel("Panel", row, "");
            info.AddClass("IslandInfo");
            var name = $.CreatePanel("Label", info, "");
            name.AddClass("IslandName");
            name.text = localize(entry.name);
            var description = $.CreatePanel("Label", info, "");
            description.AddClass("IslandDesc");
            description.text = localize(entry.description);

            if (enabled) {
                var buy = $.CreatePanel("Button", row, "");
                buy.AddClass("IslandBuy");
                // Keep the button clickable so the authoritative server can
                // explain every failed purchase instead of silently disabling it.
                buy.enabled = true;
                buy.SetPanelEvent("onmouseover", hoverSound);
                (function (button, entryID) {
                    button.SetPanelEvent("onactivate", function () {
                        sound("ui_generic_button_click");
                        button.enabled = false;
                        GameEvents.SendCustomGameEventToServer("island_shop_purchase", { entry_id: entryID });
                    });
                })(buy, entry.entry_id);
                var price = $.CreatePanel("Label", buy, "");
                price.text = localize("#island_shop_buy") + " — " + entry.price;
            } else {
                var locked = $.CreatePanel("Label", row, "");
                locked.AddClass("IslandLocked");
                locked.text = localize("#island_shop_locked");
            }
        }
    }

    function applyContext(data) {
        data = data || {};
        if (data.balance !== undefined) setBalance(data);
        setNearby(data.nearby);
        build();
    }

    function result(data) {
        applyContext(data);
        var label = panel.FindChildTraverse("IslandResult");
        label.SetHasClass("Success", !!data.success);
        label.text = localize("#island_shop_result_" + (data.code || "delivery_failed"));
        if (!data.success) {
            GameEvents.SendEventClientSide("dota_hud_error_message", {
                splitscreenplayer: 0,
                reason: "",
                message: label.text
            });
        }
        sound(data.success ? "ui_shop_buy" : "General.Cancel");
    }

    function maintainModalFocus(cycle) {
        if (cycle !== focusCycle || !modal || !modal.IsValid() || modal.BHasClass("Hidden")) return;
        modal.SetFocus();
        $.Schedule(0.1, function () { maintainModalFocus(cycle); });
    }

    function toggle() {
        var opening = modal.BHasClass("Hidden");
        var config = GameUI.CustomUIConfig();
        if (opening && config.ActiveCustomShop && config.ActiveCustomShop !== "island") {
            sound("General.Cancel");
            return;
        }
        sound("ui_generic_button_click");
        modal.SetHasClass("Hidden", !opening);
        focusCycle++;
        modal.hittest = false;
        modal.hittestchildren = opening;
        if (opening) config.ActiveCustomShop = "island";
        else if (config.ActiveCustomShop === "island") config.ActiveCustomShop = null;
        if (opening) {
            modal.SetFocus();
            (function (cycle) { $.Schedule(0.1, function () { maintainModalFocus(cycle); }); })(focusCycle);
            panel.FindChildTraverse("IslandResult").text = "";
            GameEvents.SendCustomGameEventToServer("island_shop_request_context", {});
        }
    }

    function closeFromCancel() {
        if (!modal.BHasClass("Hidden")) toggle();
    }

    IslandShop.Toggle = toggle;
    IslandShop.Close = closeFromCancel;
    panel.IslandShopToggle = toggle;
    GameUI.CustomUIConfig().IslandShopToggle = toggle;
    closeButton.SetPanelEvent("onmouseover", hoverSound);

    CustomNetTables.SubscribeNetTableListener("pumpkin_currency", function (table, key, data) {
        if (String(key) === String(playerID)) { setBalance(data); build(); }
    });
    CustomNetTables.SubscribeNetTableListener("island_shop_catalog", build);
    GameEvents.Subscribe("island_shop_proximity", applyContext);
    GameEvents.Subscribe("island_shop_context", applyContext);
    GameEvents.Subscribe("island_shop_result", result);
    GameEvents.Subscribe("pumpkin_currency_changed", function (data) { setBalance(data); build(); });

    setBalance(CustomNetTables.GetTableValue("pumpkin_currency", String(playerID)));
    setNearby(false);
    build();
    close();
    GameEvents.SendCustomGameEventToServer("island_shop_request_context", {});

})();
