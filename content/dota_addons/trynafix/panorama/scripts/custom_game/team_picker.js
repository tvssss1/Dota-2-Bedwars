var TeamPicker;

(function () {
    "use strict";
    var mapInfo = Game.GetMapInfo ? Game.GetMapInfo() : null;
    var isDuo = !!mapInfo && String(mapInfo.map_name || "").toLowerCase().indexOf("bw_duo") !== -1;
    var TEAM_IDS = isDuo ? [6, 7, 8] : [6, 7, 8, 9];
    var TEAM_CAPACITY = isDuo ? 2 : 1;
    var lastLocalTeam = -1;

    function getLocalTeam() {
        var info = Game.GetLocalPlayerInfo();
        return info ? Number(info.player_team_id) : -1;
    }

    function updateTeam(teamID) {
        var card = $("#TeamCard" + teamID);
        var capacity = $("#TeamCapacity" + teamID);
        var action = $("#TeamAction" + teamID);
        if (!card || !capacity || !action) return;
        var players = Game.GetPlayerIDsOnTeam(teamID) || [];
        players.sort(function (a, b) { return a - b; });
        var selected = getLocalTeam() === teamID;
        var occupied = players.length >= TEAM_CAPACITY && !selected;
        card.SetHasClass("TrynaPickerSelected", selected);
        card.SetHasClass("TrynaPickerOccupied", occupied);
        card.SetHasClass("TrynaPickerAvailable", players.length < TEAM_CAPACITY);
        card.enabled = !occupied;
        capacity.text = players.length + " / " + TEAM_CAPACITY;
        for (var slot = 1; slot <= 2; slot++) {
            var occupant = $("#TeamOccupant" + teamID + "_" + slot);
            var avatar = $("#TeamAvatar" + teamID + "_" + slot);
            var name = $("#TeamPlayer" + teamID + "_" + slot);
            if (!occupant || !avatar || !name) continue;
            occupant.visible = slot === 1 || isDuo;
            var playerID = players.length >= slot ? players[slot - 1] : -1;
            if (playerID >= 0) {
                var info = Game.GetPlayerInfo(playerID);
                name.text = Players.GetPlayerName(playerID) || $.Localize("#team_picker_occupied");
                avatar.steamid = info ? info.player_steamid : "0";
                avatar.SetHasClass("TrynaPickerAvatarVisible", true);
            } else {
                name.text = $.Localize("#team_picker_available");
                avatar.steamid = "0";
                avatar.SetHasClass("TrynaPickerAvatarVisible", false);
            }
        }
        action.text = selected ? $.Localize("#team_picker_selected") :
            (occupied ? $.Localize("#team_picker_full") : $.Localize("#team_picker_join"));
    }

    function updateCountdown() {
        var panel = $("#TeamPickerCountdown");
        if (!panel) return;
        var timing = CustomNetTables.GetTableValue("team_selection", "countdown");
        var remaining = timing ? Math.max(0, Math.ceil(Number(timing.end_time) - Game.GetGameTime())) : 20;
        panel.text = String(remaining);
        panel.SetHasClass("TrynaPickerUrgent", remaining <= 5);
    }

    function update() {
        TEAM_IDS.forEach(updateTeam);
        updateCountdown();
        var team = getLocalTeam();
        if (team !== lastLocalTeam) {
            lastLocalTeam = team;
            $("#TeamPickerHint").text = team >= 6 && team <= 9 ?
                $.Localize("#team_picker_switch_hint") : $.Localize("#team_picker_hint");
        }
        $.Schedule(0.1, update);
    }

    function select(teamID) {
        teamID = Number(teamID);
        if (TEAM_IDS.indexOf(teamID) === -1) return;
        var players = Game.GetPlayerIDsOnTeam(teamID) || [];
        if (players.length >= TEAM_CAPACITY && getLocalTeam() !== teamID) {
            Game.EmitSound("General.Cancel");
            return;
        }
        Game.EmitSound("ui_generic_button_click");
        Game.PlayerJoinTeam(teamID);
        TEAM_IDS.forEach(updateTeam);
    }

    var orangeCard = $("#TeamCard9");
    if (orangeCard) orangeCard.visible = !isDuo;
    var pickerRoot = $.GetContextPanel();
    if (pickerRoot) pickerRoot.SetHasClass("TrynaPickerDuoMode", isDuo);
    var greenCard = $("#TeamCard8");
    if (greenCard) greenCard.SetHasClass("TrynaPickerDuoCentered", isDuo);
    TeamPicker = { Select: select };
    update();
})();
