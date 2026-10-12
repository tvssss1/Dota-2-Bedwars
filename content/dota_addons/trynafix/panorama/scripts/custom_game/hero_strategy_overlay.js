(function () {
    "use strict";

    var TEAM_IDS = [6, 7, 8, 9];
    var NATIVE_VISUAL_IDS = [
        "PreGameBackgroundImage",
        "PregameBGStatic",
        "PregameBG",
        "NemesticeBG",
        "MainContents",
        "TeamPicker",
        "HeroPickViewStrategy",
        "BacktoHeroGrid",
        "HeaderCaptainsMode",
        "Header",
        "ConnectingLabelContainer",
        "SpectateHeroSelection",
        "BottomPanelsContainer"
    ];
    var catalog = [];
    var shopCards = {};
    var inventorySignature = "";
    var pendingPurchase = false;
    var purchaseTimeout = null;
    var nativeVisualStates = {};

    function localizeHero(heroName) {
        if (!heroName) return "";
        var token = "#" + heroName;
        var localized = $.Localize(token);
        if (!localized || localized === token) {
            return heroName.replace("npc_dota_hero_", "").replace(/_/g, " ").toUpperCase();
        }
        return localized;
    }

    function localizeItem(itemName) {
        var token = "#DOTA_Tooltip_ability_" + itemName;
        var localized = $.Localize(token);
        if (!localized || localized === token) {
            return itemName.replace("item_", "").replace(/_/g, " ").toUpperCase();
        }
        return localized;
    }

    function orderedValues(value) {
        if (!value) return [];
        var keys = Object.keys(value);
        keys.sort(function (a, b) { return Number(a) - Number(b); });
        var values = [];
        for (var i = 0; i < keys.length; i++) values.push(value[keys[i]]);
        return values;
    }

    function getPublishedTeam(teamID) {
        return CustomNetTables.GetTableValue("random_draft", "team_" + teamID) || null;
    }

    function getPlayerHero(playerID) {
        var info = Game.GetPlayerInfo(playerID);
        return info && info.player_selected_hero ? String(info.player_selected_hero) : "";
    }

    function updateTeam(teamID) {
        var panel = $("#StrategyTeam" + teamID);
        var portrait = $("#StrategyHero" + teamID);
        var emptyPortrait = $("#StrategyEmpty" + teamID);
        var playerLabel = $("#StrategyPlayer" + teamID);
        var heroLabel = $("#StrategyHeroName" + teamID);
        if (!panel || !portrait || !emptyPortrait || !playerLabel || !heroLabel) return;

        var players = Game.GetPlayerIDsOnTeam(teamID) || [];
        var published = getPublishedTeam(teamID);
        var playerID = published && Number(published.player_id) >= 0 ?
            Number(published.player_id) : (players.length > 0 ? players[0] : -1);
        var heroName = published && published.hero_name ? String(published.hero_name) :
            (playerID >= 0 ? getPlayerHero(playerID) : "");
        var localInfo = Game.GetLocalPlayerInfo();
        var localTeam = localInfo ? Number(localInfo.player_team_id) : -1;

        panel.SetHasClass("StrategyLocalTeam", teamID === localTeam);
        panel.SetHasClass("StrategyTeamHasHero", heroName.length > 0);
        playerLabel.text = playerID >= 0 ?
            (Players.GetPlayerName(playerID) || $.Localize("#draft_player")) :
            $.Localize("#draft_empty_team");

        if (heroName) {
            portrait.heroname = heroName;
            heroLabel.text = localizeHero(heroName);
            emptyPortrait.visible = false;
        } else {
            heroLabel.text = $.Localize("#draft_waiting_pick");
            emptyPortrait.visible = true;
        }
    }

    function updateLocalHero() {
        var playerID = Game.GetLocalPlayerID();
        var heroName = getPlayerHero(playerID);
        var portrait = $("#StrategyLocalHeroPortrait");
        var empty = $("#StrategyLocalHeroEmpty");
        var heroLabel = $("#StrategyLocalHeroName");
        var playerLabel = $("#StrategyLocalPlayerName");
        if (playerLabel) playerLabel.text = Players.GetPlayerName(playerID) || "";
        if (!portrait || !empty || !heroLabel) return;

        if (heroName) {
            portrait.heroname = heroName;
            portrait.visible = true;
            empty.visible = false;
            heroLabel.text = localizeHero(heroName);
        } else {
            portrait.visible = false;
            empty.visible = true;
            heroLabel.text = $.Localize("#strategy_waiting_hero");
        }
    }

    function getUiRoot() {
        var panel = $.GetContextPanel();
        while (panel && panel.GetParent()) panel = panel.GetParent();
        return panel;
    }

    function setNativePreGameHidden(hidden) {
        if (hidden) {
            var uiRoot = getUiRoot();
            if (!uiRoot) return;
            var preGame = uiRoot.FindChildTraverse("PreGame");
            if (!preGame) return;
            for (var i = 0; i < NATIVE_VISUAL_IDS.length; i++) {
                var id = NATIVE_VISUAL_IDS[i];
                var panel = preGame.FindChildTraverse(id);
                if (!panel) continue;
                var state = nativeVisualStates[id];
                if (!state || !state.panel || !state.panel.IsValid() || state.panel !== panel) {
                    state = {
                        panel: panel,
                        visibility: panel.style.visibility,
                        hittest: panel.hittest,
                        hittestchildren: panel.hittestchildren
                    };
                    nativeVisualStates[id] = state;
                }
                panel.style.visibility = "collapse";
                panel.hittest = false;
                panel.hittestchildren = false;
            }
        } else {
            var ids = Object.keys(nativeVisualStates);
            for (var j = 0; j < ids.length; j++) {
                var saved = nativeVisualStates[ids[j]];
                if (saved.panel && saved.panel.IsValid()) {
                    saved.panel.style.visibility = saved.visibility;
                    saved.panel.hittest = saved.hittest;
                    saved.panel.hittestchildren = saved.hittestchildren;
                }
            }
            nativeVisualStates = {};
        }
    }

    function setStatus(message, isError) {
        var status = $("#StrategyShopStatus");
        if (!status) return;
        status.text = message;
        status.SetHasClass("StrategyShopStatusError", !!isError);
    }

    function buyItem(itemName) {
        if (pendingPurchase || !Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME)) return;
        pendingPurchase = true;
        setStatus($.Localize("#strategy_shop_buying") + " " + localizeItem(itemName), false);
        $.DispatchEvent("DOTAPreGamePurchaseItem", itemName);
        updateShopAvailability();

        if (purchaseTimeout) $.CancelScheduled(purchaseTimeout);
        purchaseTimeout = $.Schedule(0.15, function () {
            purchaseTimeout = null;
            pendingPurchase = false;
            setStatus(localizeItem(itemName) + " " + $.Localize("#strategy_shop_requested"), false);
            updateShopAvailability();
            rebuildInventory(true);
        });
    }

    function createShopCard(parent, entry) {
        var itemName = String(entry.item_name || "");
        if (!itemName) return;

        var card = $.CreatePanel("Button", parent, "StrategyItem_" + itemName);
        card.AddClass("StrategyItemCard");
        var iconFrame = $.CreatePanel("Panel", card, "");
        iconFrame.AddClass("StrategyItemIconFrame");
        var icon = $.CreatePanel("DOTAItemImage", iconFrame, "");
        icon.AddClass("StrategyItemIcon");
        icon.itemname = itemName;

        var itemNameLabel = $.CreatePanel("Label", card, "");
        itemNameLabel.AddClass("StrategyItemName");
        itemNameLabel.text = localizeItem(itemName);

        var bottom = $.CreatePanel("Panel", card, "");
        bottom.AddClass("StrategyItemBottom");
        bottom.style.flowChildren = "right";
        var price = $.CreatePanel("Label", bottom, "");
        price.AddClass("StrategyItemPrice");
        price.text = Number(entry.cost) > 0 ? String(entry.cost) : $.Localize("#strategy_free");
        card.SetPanelEvent("onactivate", function () { buyItem(itemName); });
        card.SetPanelEvent("onmouseover", function () {
            $.DispatchEvent("DOTAShowAbilityTooltip", card, itemName);
        });
        card.SetPanelEvent("onmouseout", function () {
            $.DispatchEvent("DOTAHideAbilityTooltip", card);
        });
        shopCards[itemName] = { panel: card, entry: entry };
    }

    function loadCatalog() {
        var data = CustomNetTables.GetTableValue("strategy_shop", "catalog");
        if (!data || !data.items) return;
        var nextCatalog = orderedValues(data.items);
        var signatureParts = [];
        for (var i = 0; i < nextCatalog.length; i++) {
            signatureParts.push(String(nextCatalog[i].item_name) + ":" + String(nextCatalog[i].cost));
        }
        var signature = signatureParts.join("|");
        var oldParts = [];
        for (var j = 0; j < catalog.length; j++) {
            oldParts.push(String(catalog[j].item_name) + ":" + String(catalog[j].cost));
        }
        if (signature === oldParts.join("|")) return;

        catalog = nextCatalog;
        shopCards = {};
        var grid = $("#StrategyShopGrid");
        if (!grid) return;
        grid.RemoveAndDeleteChildren();
        for (var index = 0; index < catalog.length; index++) createShopCard(grid, catalog[index]);
        updateShopAvailability();
    }

    function updateShopAvailability() {
        var playerID = Game.GetLocalPlayerID();
        var gold = Players.GetGold ? Math.max(0, Number(Players.GetGold(playerID)) || 0) : 0;
        var heroReady = getPlayerHero(playerID).length > 0;
        var active = Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME);
        var goldLabel = $("#StrategyGoldValue");
        if (goldLabel) goldLabel.text = String(gold);

        var names = Object.keys(shopCards);
        for (var i = 0; i < names.length; i++) {
            var itemName = names[i];
            var cardData = shopCards[itemName];
            var entry = cardData.entry;
            var cost = Number(entry.cost) || 0;
            var affordable = gold >= cost;
            cardData.panel.enabled = active && heroReady && affordable && !pendingPurchase;
            cardData.panel.SetHasClass("StrategyItemUnaffordable", !affordable);
            cardData.panel.SetHasClass("StrategyItemPending", pendingPurchase);
        }
    }

    function readInventory() {
        var inventory = {};
        if (!Players.GetPlayerHeroEntityIndex || !Entities.GetItemInSlot) return inventory;
        var heroEntity = Players.GetPlayerHeroEntityIndex(Game.GetLocalPlayerID());
        if (heroEntity === -1 || heroEntity === undefined) return inventory;
        for (var slot = 0; slot < 9; slot++) {
            var itemEntity = Entities.GetItemInSlot(heroEntity, slot);
            if (itemEntity !== -1 && itemEntity !== undefined && itemEntity !== null) {
                var itemName = Abilities.GetAbilityName(itemEntity);
                if (!itemName) continue;
                var charges = 0;
                if (typeof Items !== "undefined" && Items.GetCurrentCharges) {
                    charges = Items.GetCurrentCharges(itemEntity) || 0;
                } else if (Abilities.GetCurrentCharges) {
                    charges = Abilities.GetCurrentCharges(itemEntity) || 0;
                }
                inventory[String(slot + 1)] = {
                    item_name: itemName,
                    charges: charges
                };
            }
        }
        return inventory;
    }

    function inventoryKey(inventory) {
        var parts = [];
        for (var slot = 1; slot <= 9; slot++) {
            var item = inventory ? inventory[String(slot)] : null;
            parts.push(item ? String(item.item_name) + ":" + String(item.charges || 0) : "-");
        }
        return parts.join("|");
    }

    function rebuildInventory(force) {
        var inventory = readInventory();
        var signature = inventoryKey(inventory);
        if (!force && signature === inventorySignature) return;
        inventorySignature = signature;
        var grid = $("#StrategyInventoryGrid");
        if (!grid) return;
        grid.RemoveAndDeleteChildren();

        for (var slot = 1; slot <= 9; slot++) {
            var slotPanel = $.CreatePanel("Panel", grid, "StrategyInventorySlot" + slot);
            slotPanel.AddClass("StrategyInventorySlot");
            var item = inventory[String(slot)];
            if (item && item.item_name) {
                slotPanel.AddClass("StrategyInventoryOccupied");
                var icon = $.CreatePanel("DOTAItemImage", slotPanel, "");
                icon.AddClass("StrategyInventoryIcon");
                icon.itemname = String(item.item_name);
                var charges = Number(item.charges) || 0;
                if (charges > 0) {
                    var chargesLabel = $.CreatePanel("Label", slotPanel, "");
                    chargesLabel.AddClass("StrategyInventoryCharges");
                    chargesLabel.text = String(charges);
                }
                (function (panel, itemName, slotIndex) {
                    panel.SetPanelEvent("onmouseover", function () {
                        $.DispatchEvent("DOTAShowAbilityTooltip", panel, itemName);
                    });
                    panel.SetPanelEvent("onmouseout", function () {
                        $.DispatchEvent("DOTAHideAbilityTooltip", panel);
                    });
                    panel.SetPanelEvent("oncontextmenu", function () {
                        $.DispatchEvent("DOTAPreGameSellItem", slotIndex);
                        $.Schedule(0.1, function () { rebuildInventory(true); });
                    });
                })(slotPanel, String(item.item_name), slot - 1);
            } else {
                var empty = $.CreatePanel("Label", slotPanel, "");
                empty.AddClass("StrategyInventoryEmpty");
                empty.text = String(slot);
            }
        }
    }

    function refresh() {
        var root = $.GetContextPanel();
        var active = Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME);
        root.visible = active;
        root.hittest = false;
        root.hittestchildren = active;
        setNativePreGameHidden(active);
        if (!active) {
            $.Schedule(0.1, refresh);
            return;
        }

        for (var i = 0; i < TEAM_IDS.length; i++) updateTeam(TEAM_IDS[i]);
        updateLocalHero();
        loadCatalog();
        updateShopAvailability();
        rebuildInventory(false);

        var remaining = Math.max(0, Math.ceil(Game.GetStateTransitionTime() - Game.GetGameTime()));
        var timer = $("#StrategyTimerValue");
        if (timer) {
            timer.text = String(remaining);
            timer.SetHasClass("StrategyTimerUrgent", remaining <= 5);
        }

        $.Schedule(0.1, refresh);
    }

    CustomNetTables.SubscribeNetTableListener("random_draft", function () {
        for (var i = 0; i < TEAM_IDS.length; i++) updateTeam(TEAM_IDS[i]);
    });
    CustomNetTables.SubscribeNetTableListener("strategy_shop", function (tableName, key) {
        if (key === "catalog") loadCatalog();
    });
    refresh();
})();
