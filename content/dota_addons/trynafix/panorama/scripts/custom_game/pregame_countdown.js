(function () {
    "use strict";

    var root = $.GetContextPanel().FindChildTraverse("PregameCountdownRoot");
    var number = root.FindChildTraverse("PregameCountdownNumber");
    var caption = root.FindChildTraverse("PregameCountdownCaption");
    var hideSerial = 0;
    var localPregameStarted = false;
    var localGameStarted = false;

    function showCountdown(data) {
        var count = Number(data && data.count);
        hideSerial++;
        var serial = hideSerial;

        root.RemoveClass("Visible");
        root.RemoveClass("Go");

        if (count >= 1 && count <= 3) {
            number.text = String(count);
            caption.text = $.Localize("#pregame_countdown_caption");
            Game.EmitSound("ui_generic_button_click");
        } else {
            return;
        }

        $.Schedule(0.01, function () {
            if (serial === hideSerial && root && root.IsValid()) root.AddClass("Visible");
        });
        $.Schedule(0.8, function () {
            if (serial === hideSerial && root && root.IsValid()) root.RemoveClass("Visible");
        });
        // Keep the layout node alive. Both the server subscription and the
        // game-state fallback can still fire after the countdown completes.
    }

    GameEvents.Subscribe("pregame_countdown", showCountdown);

    // Independent client fallback: custom HUD events can be missed while a
    // player is still finishing the load screen. Watching the authoritative
    // game state guarantees that every loaded client starts its own sequence.
    function watchGameState() {
        if (!root || !root.IsValid()) return;
        var state = Game.GetState();
        if (state === 6 && !localPregameStarted) {
            localPregameStarted = true;
            [3, 2, 1].forEach(function (count, index) {
                $.Schedule(2 + index, function () {
                    if (Game.GetState() === 6) showCountdown({ count: count });
                });
            });
        }
        if (state === 7 && !localGameStarted) localGameStarted = true;
        if (state < 6) {
            localPregameStarted = false;
            localGameStarted = false;
        }
        $.Schedule(0.05, watchGameState);
    }

    watchGameState();
})();
