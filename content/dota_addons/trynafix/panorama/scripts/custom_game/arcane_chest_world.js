(function () {
    "use strict";

    var context = $.GetContextPanel();
    // Keep the world-space decoration in a visible custom-HUD layer. A
    // negative z-index can place the complete UI context behind the HUD.
    context.AddClass("ArcaneChestWorldLayer");
    var root = context.FindChildTraverse("ArcaneChestWorldRoot");
    var labels = {};

    function createLabel(key) {
        var label = $.CreatePanel("Panel", root, "ArcaneChestLabel_" + key);
        label.AddClass("ArcaneChestLabel");
        label.hittest = false;
        label.hittestchildren = false;

        // A Panorama Image control loses its RGB channels in this negative
        // HUD layer and appears as a white mask. A panel background preserves
        // the full-colour texture while keeping the same layout.
        var icon = $.CreatePanel("Panel", label, "");
        icon.AddClass("ArcaneChestIcon");

        var text = $.CreatePanel("Panel", label, "");
        text.AddClass("ArcaneChestText");
        var title = $.CreatePanel("Label", text, "");
        title.AddClass("ArcaneChestTitle");
        title.text = $.Localize("#arcane_chest_title");
        var timer = $.CreatePanel("Label", text, "");
        timer.AddClass("ArcaneChestTimer");

        labels[key] = { panel: label, timer: timer };
        return labels[key];
    }

    function countdownText() {
        var timing = CustomNetTables.GetTableValue("arcane_chests", "timing");
        var gameTime = Math.max(0, Game.GetDOTATime(false, false));
        var nextSpawnTime = timing ? Number(timing.next_spawn_time) : 30;
        var seconds = Math.max(0, Math.ceil(nextSpawnTime - gameTime));
        return $.Localize("#arcane_chest_next") + " 00:" + (seconds < 10 ? "0" : "") + seconds;
    }

    function update() {
        // Schedule first so a transient missing entity can never permanently stop
        // the world-panel updater during loading.
        // Track camera movement at display-frame cadence. The old 0.03 delay
        // only updated about 33 times/sec, which made the label visibly trail.
        $.Schedule(1 / 60, update);

        ["chest_1", "chest_2"].forEach(function (key) {
            var entry = labels[key] || createLabel(key);
            var data = CustomNetTables.GetTableValue("arcane_chests", key);
            var worldX = data ? Number(data.x) : NaN;
            var worldY = data ? Number(data.y) : NaN;
            var worldZ = data ? Number(data.z) : NaN;
            var valid = data && data.unit_name === "npc_chest_default" &&
                !isNaN(worldX) && !isNaN(worldY) && !isNaN(worldZ);
            entry.panel.SetHasClass("Visible", valid);
            if (!valid) return;

            var screenX = Game.WorldToScreenX(worldX, worldY, worldZ + 190);
            var screenY = Game.WorldToScreenY(worldX, worldY, worldZ + 190);
            var scaleX = entry.panel.actualuiscale_x || root.actualuiscale_x || 1;
            var scaleY = entry.panel.actualuiscale_y || root.actualuiscale_y || 1;
            var viewportWidth = root.actuallayoutwidth || context.actuallayoutwidth;
            var viewportHeight = root.actuallayoutheight || context.actuallayoutheight;
            var onScreen = screenX >= 0 && screenY >= 0 &&
                screenX <= viewportWidth * scaleX && screenY <= viewportHeight * scaleY;
            entry.panel.SetHasClass("Visible", onScreen);
            if (!onScreen) return;

            // This is the same positioning method used by Valve's NPX world
            // hint panels. Screen coordinates are physical pixels, while
            // Panorama x/y properties use scaled layout pixels.
            var panelWidth = entry.panel.actuallayoutwidth;
            var panelHeight = entry.panel.actuallayoutheight;
            var edgeMargin = 8;
            var panelX = (screenX / scaleX) - (panelWidth / 2);
            var panelY = (screenY / scaleY) - panelHeight;

            // Keep the complete card inside the HUD viewport when the generator
            // approaches a screen edge. Previously the label could be placed at
            // a negative x/y coordinate and Panorama clipped its text and border.
            panelX = Math.max(edgeMargin, Math.min(viewportWidth - panelWidth - edgeMargin, panelX));
            panelY = Math.max(edgeMargin, Math.min(viewportHeight - panelHeight - edgeMargin, panelY));
            entry.panel.style.x = panelX + "px";
            entry.panel.style.y = panelY + "px";
            var newTimerText = countdownText();
            if (entry.timer.text !== newTimerText) {
                entry.timer.text = newTimerText;
            }
        });
    }

    if (!root) {
        $.Warning("[trynafix] ArcaneChestWorldRoot was not created; chest timer UI cannot start.");
        return;
    }

    $.Msg("[trynafix] Arcane chest timer UI loaded.");
    update();
})();
