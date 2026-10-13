(function () {
    "use strict";

    var context = $.GetContextPanel();
    // Keep the world-space decoration in a visible custom-HUD layer. A
    // negative z-index can place the complete UI context behind the HUD.
    context.AddClass("ArcaneChestWorldLayer");
    var root = context.FindChildTraverse("ArcaneChestWorldRoot");
    var chestLabels = {};
    var generatorLabels = {};
    var localPlayerID = Game.GetLocalPlayerID();

    function createChestLabel(key) {
        var label = $.CreatePanel("Panel", root, "ArcaneChestLabel_" + key);
        label.AddClass("ArcaneChestLabel");
        label.AddClass("WorldResourceLabel");
        label.hittest = false;
        label.hittestchildren = false;

        var title = $.CreatePanel("Label", label, "");
        title.AddClass("ArcaneChestTitle");
        title.text = $.Localize("#arcane_chest_title");
        var timer = $.CreatePanel("Label", label, "");
        timer.AddClass("ArcaneChestTimer");

        chestLabels[key] = { panel: label, value: timer };
        return chestLabels[key];
    }

    function createGeneratorLabel(team) {
        var label = $.CreatePanel("Panel", root, "BaseGeneratorLabel_" + team);
        label.AddClass("BaseGeneratorLabel");
        label.AddClass("WorldResourceLabel");
        label.hittest = false;
        label.hittestchildren = false;

        var title = $.CreatePanel("Label", label, "");
        title.AddClass("BaseGeneratorTitle");
        title.text = $.Localize("#base_generator_title");
        var amount = $.CreatePanel("Label", label, "");
        amount.AddClass("BaseGeneratorAmount");

        generatorLabels[team] = { panel: label, value: amount };
        return generatorLabels[team];
    }

    function countdownText() {
        var timing = CustomNetTables.GetTableValue("arcane_chests", "timing");
        var gameTime = Math.max(0, Game.GetDOTATime(false, false));
        var nextSpawnTime = timing ? Number(timing.next_spawn_time) : 30;
        var seconds = Math.max(0, Math.ceil(nextSpawnTime - gameTime));
        return $.Localize("#arcane_chest_next") + " 00:" + (seconds < 10 ? "0" : "") + seconds;
    }

    function positionWorldLabel(entry, worldX, worldY, worldZ, worldHeightOffset) {
        var anchorZ = worldZ + (Number(worldHeightOffset) || 0);
        var screenX = Game.WorldToScreenX(worldX, worldY, anchorZ);
        var screenY = Game.WorldToScreenY(worldX, worldY, anchorZ);
        var viewportWidth = root.actuallayoutwidth || context.actuallayoutwidth;
        var viewportHeight = root.actuallayoutheight || context.actuallayoutheight;
        var onScreen = screenX >= 0 && screenY >= 0 &&
            screenX <= viewportWidth && screenY <= viewportHeight;
        entry.panel.SetHasClass("Visible", onScreen);
        if (!onScreen) return false;

        // WorldToScreen uses the same screen-space coordinate system as this
        // full-screen Panorama root. The projected marker is the bottom-center
        // anchor of the label.
        var panelWidth = entry.panel.actuallayoutwidth || 220;
        var panelHeight = entry.panel.actuallayoutheight || 40;
        var edgeMargin = 8;
        var panelX = screenX - (panelWidth / 2);
        var panelY = screenY - panelHeight;
        panelX = Math.max(edgeMargin, Math.min(viewportWidth - panelWidth - edgeMargin, panelX));
        panelY = Math.max(edgeMargin, Math.min(viewportHeight - panelHeight - edgeMargin, panelY));
        entry.panel.style.x = panelX + "px";
        entry.panel.style.y = panelY + "px";
        return true;
    }

    function update() {
        // Schedule first so a transient missing entity can never permanently stop
        // the world-panel updater during loading.
        // Track camera movement at display-frame cadence. The old 0.03 delay
        // only updated about 33 times/sec, which made the label visibly trail.
        $.Schedule(1 / 60, update);

        ["chest_1", "chest_2"].forEach(function (key) {
            var entry = chestLabels[key] || createChestLabel(key);
            var data = CustomNetTables.GetTableValue("arcane_chests", key);
            var worldX = data ? Number(data.x) : NaN;
            var worldY = data ? Number(data.y) : NaN;
            var worldZ = data ? Number(data.z) : NaN;
            var valid = data && data.unit_name === "npc_chest_default" &&
                !isNaN(worldX) && !isNaN(worldY) && !isNaN(worldZ);
            entry.panel.SetHasClass("Visible", valid);
            if (!valid) return;
            if (!positionWorldLabel(entry, worldX, worldY, worldZ, 190)) return;
            var newTimerText = countdownText();
            if (entry.value.text !== newTimerText) {
                entry.value.text = newTimerText;
            }
        });

        var localTeam = Players.GetTeam(localPlayerID);
        Object.keys(generatorLabels).forEach(function (teamKey) {
            if (Number(teamKey) !== localTeam) generatorLabels[teamKey].panel.RemoveClass("Visible");
        });
        [localTeam].forEach(function (team) {
            if (team < 6 || team > 9) return;
            var entry = generatorLabels[team] || createGeneratorLabel(team);
            // Generator entries intentionally share the middle chests' proven
            // net table so both label types have an identical data path.
            var data = CustomNetTables.GetTableValue("arcane_chests", "gold_generator_" + team);
            var worldX = data ? Number(data.x) : NaN;
            var worldY = data ? Number(data.y) : NaN;
            var worldZ = data ? Number(data.z) : NaN;
            var valid = data && !isNaN(worldX) && !isNaN(worldY) && !isNaN(worldZ);
            entry.panel.SetHasClass("Visible", valid);
            // The generator_* entities are authored as the exact label anchor,
            // so unlike chest origins they need no additional world-Z offset.
            if (!valid || !positionWorldLabel(entry, worldX, worldY, worldZ, 0)) return;

            var remaining = Math.max(0, Number(data.remaining) || 0);
            var capacity = Math.max(0, Number(data.capacity) || 6000);
            var amountText = $.Localize("#base_generator_remaining") + " " +
                remaining + " / " + capacity;
            if (entry.value.text !== amountText) entry.value.text = amountText;
        });
    }

    if (!root) {
        $.Warning("[trynafix] ArcaneChestWorldRoot was not created; chest timer UI cannot start.");
        return;
    }

    $.Msg("[trynafix] Arcane chest timer UI loaded.");
    update();
})();
