(function () {
    "use strict";

    var mapInfo = Game.GetMapInfo();
    var isDuo = !!mapInfo && String(mapInfo.map_name || "").toLowerCase().indexOf("bw_duo") !== -1;
    var TEAM_IDS = isDuo ? [6, 7, 8] : [6, 7, 8, 9];
    var ATTRIBUTE_ORDER = ["strength", "agility", "intelligence", "universal"];
    var ATTRIBUTE_GRID_IDS = {
        strength: "DraftGridStrength",
        agility: "DraftGridAgility",
        intelligence: "DraftGridIntelligence",
        universal: "DraftGridUniversal"
    };
    var ATTRIBUTE_COUNT_IDS = {
        strength: "DraftCountStrength",
        agility: "DraftCountAgility",
        intelligence: "DraftCountIntelligence",
        universal: "DraftCountUniversal"
    };

    var draftPool = null;
    var pendingHero = "";
    var renderedSignature = "";
    var statusResetHandle = null;

    var draftRoot = $.GetContextPanel();
    draftRoot.SetHasClass("DraftDuoMode", isDuo);
    var heroSearch = $("#DraftHeroSearch");
    if (heroSearch) heroSearch.placeholder = $.Localize("#draft_search_placeholder");
    var draftTimerPanel = $("#DraftTimerPanel");
    if (isDuo && draftTimerPanel) {
        // Remove the timer from DraftTopBar's flow so all three team cards
        // occupy one uninterrupted, centered row.
        draftTimerPanel.SetParent(draftRoot);
        draftTimerPanel.AddClass("DraftTimerBottom");
        draftTimerPanel.hittest = false;
        draftTimerPanel.hittestchildren = false;
    }

    function localizeHero(heroName) {
        if (!heroName) return "";
        var token = "#" + heroName;
        var localized = $.Localize(token);
        if (!localized || localized === token) {
            return heroName.replace("npc_dota_hero_", "").replace(/_/g, " ").toUpperCase();
        }
        return localized;
    }

    function luaArrayValues(value) {
        if (!value) return [];
        var keys = Object.keys(value);
        keys.sort(function (a, b) { return Number(a) - Number(b); });
        var values = [];
        for (var i = 0; i < keys.length; i++) {
            if (typeof value[keys[i]] === "string") values.push(value[keys[i]]);
        }
        return values;
    }

    function getPlayerHero(playerID) {
        var info = Game.GetPlayerInfo(playerID);
        if (info && info.player_selected_hero) return String(info.player_selected_hero);
        var published = CustomNetTables.GetTableValue("random_draft", "player_" + playerID);
        return published && published.hero_name ? String(published.hero_name) : "";
    }

    function getPickedHeroes() {
        var picked = {};
        for (var t = 0; t < TEAM_IDS.length; t++) {
            var players = Game.GetPlayerIDsOnTeam(TEAM_IDS[t]) || [];
            for (var p = 0; p < players.length; p++) {
                var heroName = getPlayerHero(players[p]);
                if (heroName) picked[heroName] = true;
            }
        }
        return picked;
    }

    function getLocalHero() {
        return getPlayerHero(Game.GetLocalPlayerID());
    }

    function updatePlayerSlot(teamID, slotIndex, playerID) {
        var slot = $("#DraftPlayerSlot" + teamID + "_" + slotIndex);
        var portrait = $("#DraftTeamHero" + teamID + "_" + slotIndex);
        var emptyPortrait = $("#DraftTeamEmpty" + teamID + "_" + slotIndex);
        var playerLabel = $("#DraftTeamPlayer" + teamID + "_" + slotIndex);
        var heroLabel = $("#DraftTeamHeroName" + teamID + "_" + slotIndex);
        if (!slot || !portrait || !emptyPortrait || !playerLabel || !heroLabel) return false;

        var hasPlayer = playerID !== undefined && playerID !== null && playerID >= 0;
        var heroName = hasPlayer ? getPlayerHero(playerID) : "";
        slot.SetHasClass("DraftPlayerSlotOccupied", hasPlayer);
        slot.SetHasClass("DraftPlayerSlotHasHero", heroName.length > 0);

        if (hasPlayer) {
            playerLabel.text = Players.GetPlayerName(playerID) || $.Localize("#draft_player");
        } else {
            playerLabel.text = $.Localize("#draft_empty_team");
        }

        if (heroName) {
            portrait.heroname = heroName;
            heroLabel.text = localizeHero(heroName);
            emptyPortrait.visible = false;
        } else {
            heroLabel.text = $.Localize("#draft_waiting_pick");
            emptyPortrait.visible = true;
        }
        return heroName.length > 0;
    }

    function updateTeam(teamID) {
        var panel = $("#DraftTeam" + teamID);
        if (!panel) return;

        var players = Game.GetPlayerIDsOnTeam(teamID) || [];
        players.sort(function (a, b) { return a - b; });
        var localInfo = Game.GetLocalPlayerInfo();
        var localTeam = localInfo ? Number(localInfo.player_team_id) : -1;
        var firstHasHero = updatePlayerSlot(teamID, 1, players.length > 0 ? players[0] : -1);
        var secondHasHero = false;
        var secondSlot = $("#DraftPlayerSlot" + teamID + "_2");
        if (secondSlot) secondSlot.visible = isDuo;
        if (isDuo) secondHasHero = updatePlayerSlot(teamID, 2, players.length > 1 ? players[1] : -1);

        panel.SetHasClass("DraftLocalTeam", teamID === localTeam);
        panel.SetHasClass("DraftTeamHasPlayer", players.length > 0);
        panel.SetHasClass("DraftTeamHasHero", firstHasHero || secondHasHero);
    }

    function setStatus(text, isError) {
        var status = $("#DraftStatus");
        if (!status) return;
        status.text = text;
        status.SetHasClass("DraftStatusError", !!isError);
    }

    function resetStatusLater() {
        if (statusResetHandle) $.CancelScheduled(statusResetHandle);
        statusResetHandle = $.Schedule(2.2, function () {
            statusResetHandle = null;
            if (!getLocalHero() && !pendingHero) setStatus($.Localize("#draft_choose_hint"), false);
        });
    }

    function pickHero(heroName) {
        if (!heroName || pendingHero || getLocalHero()) return;
        if (getPickedHeroes()[heroName]) {
            setStatus($.Localize("#draft_pick_taken"), true);
            rebuildPool(true);
            resetStatusLater();
            return;
        }

        pendingHero = heroName;
        $.GetContextPanel().SetHasClass("DraftPickPending", true);
        setStatus($.Localize("#draft_locking") + " " + localizeHero(heroName), false);
        Game.EmitSound("ui_generic_button_click");
        GameEvents.SendCustomGameEventToServer("random_draft_select_hero", { hero_name: heroName });
    }

    function createHeroCard(grid, heroName) {
        var card = $.CreatePanel("Button", grid, "DraftHero_" + heroName);
        card.AddClass("DraftHeroCard");

        var portrait = $.CreatePanel("DOTAHeroImage", card, "");
        portrait.AddClass("DraftHeroPortrait");
        portrait.heroname = heroName;
        portrait.heroimagestyle = "portrait";

        var shade = $.CreatePanel("Panel", card, "");
        shade.AddClass("DraftHeroShade");

        var name = $.CreatePanel("Label", card, "");
        name.AddClass("DraftHeroName");
        name.text = localizeHero(heroName);

        card.SetPanelEvent("onactivate", function () { pickHero(heroName); });
        card.SetPanelEvent("onmouseover", function () {
            if (!pendingHero && !getLocalHero()) setStatus(localizeHero(heroName), false);
            $.DispatchEvent("DOTAShowTextTooltip", card, localizeHero(heroName));
        });
        card.SetPanelEvent("onmouseout", function () {
            $.DispatchEvent("DOTAHideTextTooltip", card);
            if (!pendingHero && !getLocalHero()) setStatus($.Localize("#draft_choose_hint"), false);
        });
    }

    function getSearchQuery() {
        var search = $("#DraftHeroSearch");
        return search ? String(search.text || "").toLowerCase().replace(/^\s+|\s+$/g, "") : "";
    }

    function matchesSearch(heroName, query) {
        if (!query) return true;
        var localized = localizeHero(heroName).toLowerCase();
        var internalName = heroName.replace("npc_dota_hero_", "").replace(/_/g, " ").toLowerCase();
        return localized.indexOf(query) !== -1 || internalName.indexOf(query) !== -1;
    }

    function buildSignature(heroes, picked, localHero, searchQuery) {
        var pickedNames = Object.keys(picked);
        pickedNames.sort();
        return heroes.join("|") + "::" + pickedNames.join("|") + "::" + localHero + "::" + searchQuery;
    }

    function rebuildPool(force) {
        draftPool = CustomNetTables.GetTableValue("random_draft", "pool") || draftPool;
        if (!draftPool || !draftPool.heroes) {
            setStatus($.Localize("#draft_loading"), false);
            return;
        }

        var heroes = luaArrayValues(draftPool.heroes);
        var attributes = draftPool.attributes || {};
        var picked = getPickedHeroes();
        var localHero = getLocalHero();
        var searchQuery = getSearchQuery();
        var signature = buildSignature(heroes, picked, localHero, searchQuery);
        if (!force && signature === renderedSignature) return;
        renderedSignature = signature;

        var groups = { strength: [], agility: [], intelligence: [], universal: [] };
        for (var i = 0; i < heroes.length; i++) {
            var heroName = heroes[i];
            if (picked[heroName]) continue;
            if (!matchesSearch(heroName, searchQuery)) continue;
            var attribute = attributes[heroName] || "universal";
            if (!groups[attribute]) attribute = "universal";
            groups[attribute].push(heroName);
        }

        var available = 0;
        for (var a = 0; a < ATTRIBUTE_ORDER.length; a++) {
            var attributeName = ATTRIBUTE_ORDER[a];
            var grid = $("#" + ATTRIBUTE_GRID_IDS[attributeName]);
            if (!grid) continue;
            grid.RemoveAndDeleteChildren();
            var groupHeroes = groups[attributeName];
            available += groupHeroes.length;
            for (var h = 0; h < groupHeroes.length; h++) createHeroCard(grid, groupHeroes[h]);
            $("#" + ATTRIBUTE_COUNT_IDS[attributeName]).text = String(groupHeroes.length);
        }

        $("#DraftAvailableCount").text = available + " " + $.Localize("#draft_available");
        $.GetContextPanel().SetHasClass("DraftLocalLocked", localHero.length > 0);
        if (localHero) {
            $("#DraftLockedHero").text = localizeHero(localHero);
            setStatus($.Localize("#draft_locked"), false);
            pendingHero = "";
            $.GetContextPanel().SetHasClass("DraftPickPending", false);
        } else if (!pendingHero) {
            setStatus($.Localize("#draft_choose_hint"), false);
        }
    }

    function updateTimer() {
        var remaining = Math.max(0, Math.ceil(Game.GetStateTransitionTime() - Game.GetGameTime()));
        var timer = $("#DraftTimerValue");
        timer.text = String(remaining);
        timer.SetHasClass("DraftTimerUrgent", remaining <= 5);
    }

    function refresh() {
        var root = $.GetContextPanel();
        var orangeTeam = $("#DraftTeam9");
        if (orangeTeam) orangeTeam.visible = !isDuo;
        var isHeroSelection = Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_HERO_SELECTION);
        root.visible = isHeroSelection;
        root.hittest = isHeroSelection;
        root.hittestchildren = isHeroSelection;
        if (!isHeroSelection) {
            $.Schedule(0.1, refresh);
            return;
        }

        for (var i = 0; i < TEAM_IDS.length; i++) updateTeam(TEAM_IDS[i]);
        updateTimer();
        rebuildPool(false);
        $.Schedule(0.1, refresh);
    }

    function onPickResult(data) {
        if (Number(data.success) === 1) {
            setStatus($.Localize("#draft_locked") + ": " + localizeHero(data.hero_name), false);
            rebuildPool(true);
            return;
        }

        pendingHero = "";
        $.GetContextPanel().SetHasClass("DraftPickPending", false);
        var reason = data.reason ? $.Localize(String(data.reason)) : $.Localize("#draft_pick_failed");
        setStatus(reason, true);
        Game.EmitSound("General.Cancel");
        rebuildPool(true);
        resetStatusLater();
    }

    CustomNetTables.SubscribeNetTableListener("random_draft", function () { rebuildPool(true); });
    GameEvents.Subscribe("random_draft_pick_result", onPickResult);
    GameEvents.Subscribe("dota_player_hero_selection_dirty", function () { rebuildPool(true); });
    GameEvents.Subscribe("dota_player_update_hero_selection", function () { rebuildPool(true); });
    refresh();
})();

