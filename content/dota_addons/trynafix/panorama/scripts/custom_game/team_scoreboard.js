(function () {
    "use strict";

    var context = $.GetContextPanel();
    var mapInfo = Game.GetMapInfo ? Game.GetMapInfo() : null;
    var isDuo = !!mapInfo && String(mapInfo.map_name || "").toLowerCase().indexOf("bw_duo") !== -1;
    var teams = isDuo ? [6, 7, 8] : [6, 7, 8, 9];
    var bedAliveByTeam = {};
    var inspectedPlayerID = -1;
    var inspectedInventorySignature = "";
    var inspectedSlots = [0, 1, 2, 3, 4, 5, 6, 7, 8, 15, 16];
    var hiddenValvePanels = [
        "TopBarRadiantTeam",
        "TopBarDireTeam",
        "TopBarRadiantTeamContainer",
        "TopBarDireTeamContainer",
        "TopBarRadiantTeamScore",
        "TopBarDireTeamScore",
        "RadiantScore",
        "DireScore"
    ];

    function dotaHud() {
        var panel = context;
        while (panel && panel.id !== "Hud") panel = panel.GetParent();
        return panel;
    }

    function hideDefaultTeamUI() {
        var hud = dotaHud();
        if (!hud) return;
        hiddenValvePanels.forEach(function (id) {
            var panel = hud.FindChildTraverse(id);
            if (panel) panel.style.visibility = "collapse";
        });
    }

    function playersOnTeam(teamID) {
        var players = Game.GetPlayerIDsOnTeam(teamID) || [];
        players.sort(function (a, b) { return a - b; });
        return players;
    }

    function inspectPlayerHero(playerID) {
        if (playerID === undefined || playerID === null || playerID < 0) return;
        var hero = Players.GetPlayerHeroEntityIndex(playerID);
        if (hero === -1) return;
        if (inspectedPlayerID === playerID) {
            closeHeroInventory();
            return;
        }
        inspectedPlayerID = playerID;
        inspectedInventorySignature = "";
        var inspector = context.FindChildTraverse("HeroInventoryInspect");
        if (inspector) inspector.RemoveClass("Hidden");
        renderHeroInventory(true);
        Game.EmitSound("ui_generic_button_click");
    }

    function closeHeroInventory() {
        inspectedPlayerID = -1;
        inspectedInventorySignature = "";
        var inspector = context.FindChildTraverse("HeroInventoryInspect");
        if (inspector) inspector.AddClass("Hidden");
    }

    function renderHeroInventory(force) {
        if (inspectedPlayerID < 0) return;
        var hero = Players.GetPlayerHeroEntityIndex(inspectedPlayerID);
        if (hero === -1 || !Entities.IsValidEntity(hero)) {
            closeHeroInventory();
            return;
        }

        var heroName = playerHeroName(inspectedPlayerID);
        var portrait = context.FindChildTraverse("InspectHeroPortrait");
        var title = context.FindChildTraverse("InspectHeroTitle");
        if (portrait && portrait.heroname !== heroName) portrait.heroname = heroName;
        if (title) {
            var playerName = Players.GetPlayerName(inspectedPlayerID) || $.Localize("#scoreboard_inventory_title");
            var localizedHero = heroName ? $.Localize("#" + heroName) : "";
            title.text = localizedHero ? playerName + " — " + localizedHero : playerName;
        }

        var signature = [];
        var inventory = [];
        for (var i = 0; i < inspectedSlots.length; i++) {
            var itemEntity = Entities.GetItemInSlot(hero, inspectedSlots[i]);
            var itemName = itemEntity !== -1 && itemEntity !== undefined
                ? Abilities.GetAbilityName(itemEntity) : "";
            var charges = 0;
            if (itemName && typeof Items !== "undefined" && Items.GetCurrentCharges) {
                charges = Number(Items.GetCurrentCharges(itemEntity)) || 0;
            }
            inventory.push({ name: itemName, charges: charges });
            signature.push(itemName + ":" + charges);
        }
        signature = signature.join("|");
        if (!force && signature === inspectedInventorySignature) return;
        inspectedInventorySignature = signature;

        var grid = context.FindChildTraverse("InspectInventorySlots");
        if (!grid) return;
        grid.RemoveAndDeleteChildren();
        for (var slotIndex = 0; slotIndex < inspectedSlots.length; slotIndex++) {
            var slot = $.CreatePanel("Panel", grid, "InspectSlot" + inspectedSlots[slotIndex]);
            slot.AddClass("InspectInventorySlot");
            if (inspectedSlots[slotIndex] >= 15) slot.AddClass("SpecialSlot");
            var item = inventory[slotIndex];
            if (item.name) {
                var icon = $.CreatePanel("DOTAItemImage", slot, "");
                icon.AddClass("InspectInventoryIcon");
                icon.itemname = item.name;
                if (item.charges > 0) {
                    var chargeLabel = $.CreatePanel("Label", slot, "");
                    chargeLabel.AddClass("InspectInventoryCharges");
                    chargeLabel.text = String(item.charges);
                }
                (function (panel, itemName) {
                    panel.SetPanelEvent("onmouseover", function () {
                        $.DispatchEvent("DOTAShowAbilityTooltip", panel, itemName);
                    });
                    panel.SetPanelEvent("onmouseout", function () {
                        $.DispatchEvent("DOTAHideAbilityTooltip", panel);
                    });
                })(slot, item.name);
            } else {
                var empty = $.CreatePanel("Label", slot, "");
                empty.AddClass("InspectInventoryEmpty");
                empty.text = inspectedSlots[slotIndex] === 15 ? "TP" :
                    (inspectedSlots[slotIndex] === 16 ? "N" : String(inspectedSlots[slotIndex] + 1));
            }
        }
    }

    var orangeCard = context.FindChildTraverse("Team9");
    if (orangeCard) orangeCard.visible = !isDuo;

    if (isDuo) {
        var scoreboardRoot = context.FindChildTraverse("TeamScoreboardRoot");
        var blueCard = context.FindChildTraverse("Team7");
        context.AddClass("DuoScoreboard");
        if (scoreboardRoot && blueCard) {
            blueCard.SetParent(scoreboardRoot);
            blueCard.AddClass("DuoCenterTeam");
        }
    }

    teams.forEach(function (teamID) {
        var secondFrame = context.FindChildTraverse("HeroFrame" + teamID + "_2");
        if (secondFrame) secondFrame.visible = isDuo;
    });

    function playerHeroName(playerID) {
        if (playerID === undefined || playerID === null || playerID < 0) return "";
        var heroName = Players.GetPlayerSelectedHero(playerID) || "";
        if (heroName) return heroName;
        var info = Game.GetPlayerInfo(playerID);
        return info && info.player_selected_hero ? String(info.player_selected_hero) : "";
    }

    function updatePlayerSlot(teamID, slotIndex, playerID) {
        var frame = context.FindChildTraverse("HeroFrame" + teamID + "_" + slotIndex);
        var portrait = context.FindChildTraverse("Hero" + teamID + "_" + slotIndex);
        var respawnLabel = context.FindChildTraverse("Respawn" + teamID + "_" + slotIndex);
        if (!frame || !portrait || !respawnLabel) return false;

        var hasPlayer = playerID !== undefined && playerID !== null && playerID >= 0;
        var heroName = hasPlayer ? playerHeroName(playerID) : "";
        var dead = false;
        var respawnText = "";
        frame.SetHasClass("EmptySlot", heroName.length === 0);
        frame.SetHasClass("InventoryInspected", hasPlayer && inspectedPlayerID === playerID);
        frame.SetPanelEvent("onactivate", function () { inspectPlayerHero(hasPlayer ? playerID : -1); });

        if (heroName.length > 0) {
            if (portrait.heroname !== heroName) portrait.heroname = heroName;
            var playerInfo = Game.GetPlayerInfo(playerID);
            var respawnSeconds = playerInfo ? Number(playerInfo.player_respawn_seconds) : -1;
            if (respawnSeconds >= 0) {
                dead = true;
                respawnText = String(Math.floor(respawnSeconds) + 1);
            } else if (bedAliveByTeam[teamID] === false) {
                var heroEntity = Players.GetPlayerHeroEntityIndex(playerID);
                dead = heroEntity !== -1 && !Entities.IsAlive(heroEntity);
                if (dead) respawnText = "—";
            }
        }

        frame.SetHasClass("HeroDead", dead);
        respawnLabel.text = respawnText;
        return heroName.length > 0;
    }

    function updateTeam(teamID) {
        var card = context.FindChildTraverse("Team" + teamID);
        var killsLabel = context.FindChildTraverse("Kills" + teamID);
        if (!card || !killsLabel) return;

        var playerIDs = playersOnTeam(teamID);
        var kills = 0;
        playerIDs.forEach(function (playerID) {
            kills += Number(Players.GetKills(playerID)) || 0;
        });
        killsLabel.text = String(kills);

        var firstHasHero = updatePlayerSlot(teamID, 1, playerIDs.length > 0 ? playerIDs[0] : -1);
        var secondHasHero = isDuo
            ? updatePlayerSlot(teamID, 2, playerIDs.length > 1 ? playerIDs[1] : -1)
            : false;
        card.SetHasClass("Empty", !firstHasHero && !secondHasHero);
    }

    function setBedState(teamID, data) {
        teamID = Number(teamID);
        if (teams.indexOf(teamID) === -1) return;
        var bed = context.FindChildTraverse("Bed" + teamID);
        var isDead = !!data && (data.bed_alive === false || Number(data.bed_alive) === 0);
        bedAliveByTeam[teamID] = !isDead;
        if (bed) bed.SetHasClass("Dead", isDead);
    }

    function updateBed(tableName, key, data) {
        if (tableName !== "team_status") return;
        setBedState(key, data);
    }

    function updateAllBeds() {
        teams.forEach(function (teamID) {
            updateBed("team_status", String(teamID), CustomNetTables.GetTableValue("team_status", String(teamID)));
        });
    }

    function updateLoop() {
        if (!context || !context.IsValid()) return;
        hideDefaultTeamUI();
        teams.forEach(updateTeam);
        renderHeroInventory(false);
        $.Schedule(0.25, updateLoop);
    }

    CustomNetTables.SubscribeNetTableListener("team_status", updateBed);
    GameEvents.Subscribe("team_bed_state_changed", function (data) {
        if (!data) return;
        setBedState(data.team_id, data);
        if (data.bed_alive === false || Number(data.bed_alive) === 0) {
            Game.EmitSound("Trynafix.BedDestroyed");
        }
    });
    updateAllBeds();
    var inspectClose = context.FindChildTraverse("InspectClose");
    if (inspectClose) inspectClose.SetPanelEvent("onactivate", closeHeroInventory);
    updateLoop();
})();
