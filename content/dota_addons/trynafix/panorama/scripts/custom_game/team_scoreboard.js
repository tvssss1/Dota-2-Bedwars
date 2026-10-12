(function () {
    "use strict";

    var context = $.GetContextPanel();
    var mapInfo = Game.GetMapInfo ? Game.GetMapInfo() : null;
    var isDuo = !!mapInfo && String(mapInfo.map_name || "").toLowerCase().indexOf("bw_duo") !== -1;
    var teams = isDuo ? [6, 7, 8] : [6, 7, 8, 9];
    var bedAliveByTeam = {};
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

    function focusPlayerHero(playerID) {
        if (playerID === undefined || playerID === null || playerID < 0) return;
        var hero = Players.GetPlayerHeroEntityIndex(playerID);
        if (hero === -1) return;
        GameUI.SelectUnit(hero, false);
        GameUI.SetCameraTarget(hero);
        $.Schedule(0.15, function () { GameUI.SetCameraTarget(-1); });
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
        frame.SetPanelEvent("onactivate", function () { focusPlayerHero(hasPlayer ? playerID : -1); });

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
    updateLoop();
})();
