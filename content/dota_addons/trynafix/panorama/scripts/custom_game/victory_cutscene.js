(function () {
    "use strict";
    var root = $.GetContextPanel();
    var card = root.FindChildTraverse("VictoryCard");
    var flash = root.FindChildTraverse("VictoryFlash");
    var portrait = root.FindChildTraverse("VictoryPortrait");
    var sequence = 0;
    var shot = { distance: 1450, pitch: 62, yaw: 205, height: 110 };
    var teams = {
        6: { token: "#team_picker_red", css: "Red" },
        7: { token: "#team_picker_blue", css: "Blue" },
        8: { token: "#team_picker_green", css: "Green" },
        9: { token: "#team_picker_orange", css: "Orange" }
    };

    function later(delay, id, callback) {
        $.Schedule(delay, function () { if (id === sequence) callback(); });
    }

    function applyCamera(target, state) {
        if (target >= 0) GameUI.SetCameraTarget(target);
        GameUI.SetCameraDistance(state.distance);
        GameUI.SetCameraPitchMin(state.pitch);
        GameUI.SetCameraPitchMax(state.pitch);
        GameUI.SetCameraYaw(state.yaw);
        GameUI.SetCameraLookAtPositionHeightOffset(state.height);
    }

    function easeInOut(t) {
        return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
    }

    function glide(target, destination, duration, id) {
        var origin = { distance:shot.distance, pitch:shot.pitch, yaw:shot.yaw, height:shot.height };
        var started = Game.Time();
        function frame() {
            if (id !== sequence) return;
            var t = Math.min(1, Math.max(0, (Game.Time() - started) / duration));
            var eased = easeInOut(t);
            shot.distance = origin.distance + (destination.distance - origin.distance) * eased;
            shot.pitch = origin.pitch + (destination.pitch - origin.pitch) * eased;
            shot.yaw = origin.yaw + (destination.yaw - origin.yaw) * eased;
            shot.height = origin.height + (destination.height - origin.height) * eased;
            applyCamera(target, shot);
            if (t < 1) $.Schedule(1 / 60, frame);
        }
        frame();
    }

    function begin(data) {
        var id = ++sequence;
        var team = teams[Number(data.team_id)] || teams[6];
        var target = Number(data.hero_entindex);
        ["Red", "Blue", "Green", "Orange", "Visible", "HeroReveal", "Finale"].forEach(function (name) { root.RemoveClass(name); });
        card.RemoveClass("Shown");
        card.RemoveClass("DetailsShown");
        root.AddClass(team.css);
        root.FindChildTraverse("VictoryTeam").text = $.Localize(team.token);
        root.FindChildTraverse("VictoryHero").text = data.hero_name ? $.Localize("#" + data.hero_name) : "";
        root.FindChildTraverse("VictoryPlayer").text = String(data.player_name || "");
        if (data.hero_name) portrait.heroname = String(data.hero_name);

        shot = { distance:1520, pitch:64, yaw:195, height:125 };
        applyCamera(target, shot);
        root.AddClass("Visible");
        Game.EmitSound("Outpost.Reward");
        glide(target, { distance:920, pitch:46, yaw:275, height:105 }, 2.2, id);
        later(1.65, id, function () { root.AddClass("HeroReveal"); });
        later(2.2, id, function () {
            flash.AddClass("Burst");
            Game.EmitSound("ui_generic_button_click");
            card.AddClass("Shown");
            glide(target, { distance:650, pitch:30, yaw:335, height:95 }, 2.25, id);
        });
        later(2.4, id, function () { flash.RemoveClass("Burst"); });
        later(2.8, id, function () { card.AddClass("DetailsShown"); });
        later(4.55, id, function () { glide(target, { distance:735, pitch:36, yaw:405, height:110 }, 2.45, id); });
        later(7.05, id, function () {
            root.AddClass("Finale");
            glide(target, { distance:860, pitch:43, yaw:448, height:125 }, 2.3, id);
        });
    }

    GameEvents.Subscribe("trynafix_victory", begin);
})();
