var LoadingTips;

(function () {
    "use strict";

    var tips = [
        {
            title: "#loading_tip_beds_title",
            body: "#loading_tip_beds_body",
            image: "file://{images}/custom_game/recall/bed_red.png"
        },
        {
            title: "#loading_tip_convergence_title",
            body: "#loading_tip_convergence_body",
            image: "file://{images}/purple_money.png"
        },
        {
            title: "#loading_tip_currency_title",
            body: "#loading_tip_currency_body",
            image: "file://{images}/items/item_pumpkin_coin.png"
        },
        {
            title: "#loading_tip_defense_title",
            body: "#loading_tip_defense_body",
            image: "file://{images}/items/tower_kit.png"
        }
    ];
    var root = $.GetContextPanel();
    var localLoaded = false;
    var autoAdvanceHandle = null;
    var currentIndex = 0;
    var changeSerial = 0;

    function render() {
        var tip = tips[currentIndex];
        var card = $("#LoadingTipCard");
        if (localLoaded || !tip || !card) return;

        changeSerial++;
        var serial = changeSerial;
        card.RemoveClass("TipVisible");
        $.Schedule(0.05, function () {
            if (localLoaded || !card || !card.IsValid() || serial !== changeSerial) return;
            $("#LoadingTipTitle").text = $.Localize(tip.title);
            $("#LoadingTipBody").text = $.Localize(tip.body);
            $("#LoadingTipIcon").SetImage(tip.image);

            var dots = $("#LoadingTipDots");
            if (dots) {
                for (var index = 0; index < dots.GetChildCount(); index++) {
                    dots.GetChild(index).SetHasClass("Active", index === currentIndex);
                }
            }
            card.AddClass("TipVisible");
        });
    }

    function change(delta) {
        currentIndex = (currentIndex + delta + tips.length) % tips.length;
        render();
    }

    function goTo(index) {
        currentIndex = Math.max(0, Math.min(tips.length - 1, Number(index) || 0));
        render();
    }

    function createDot(parent, index) {
        var dot = $.CreatePanel("Button", parent, "LoadingTipDot" + index);
        dot.AddClass("LoadingTipDot");
        dot.SetAttributeString("tip_accessibility", $.Localize("#loading_tip_dot_accessibility"));
        dot.SetPanelEvent("onactivate", function () { goTo(index); });
        dot.SetPanelEvent("onmouseover", function () {
            $.DispatchEvent("DOTAShowTextTooltip", dot, dot.GetAttributeString("tip_accessibility", ""));
        });
        dot.SetPanelEvent("onmouseout", function () {
            $.DispatchEvent("DOTAHideTextTooltip", dot);
        });
    }

    function buildDots() {
        var dots = $("#LoadingTipDots");
        if (!dots) return;
        dots.RemoveAndDeleteChildren();
        for (var index = 0; index < tips.length; index++) {
            createDot(dots, index);
        }
    }

    function autoAdvance() {
        if (localLoaded || !root || !root.IsValid()) return;
        change(1);
        autoAdvanceHandle = $.Schedule(6.0, autoAdvance);
    }

    // The engine changes this ancestor class only once the local client has
    // loaded. GameState alone would switch early while this client is loading.
    function loadingRoot() {
        var ancestor = root;
        while (ancestor) {
            if (ancestor.BHasClass("LoadingRoot")) return ancestor;
            ancestor = ancestor.GetParent();
        }
        return null;
    }

    function countPlayers(panel, counts) {
        for (var index = 0; index < panel.GetChildCount(); index++) {
            var child = panel.GetChild(index);
            if (child.paneltype === "DOTALoadingScreenPlayer") {
                // Keep the engine-owned labels and avatar, but give the two
                // labels their own vertical column instead of absolute offsets.
                var name = child.FindChildTraverse("PlayerName");
                var status = child.FindChildTraverse("PlayerLoadingStatus");
                if (name && status && !child.FindChildTraverse("BedWarsLoadingPlayerCopy")) {
                    var copy = $.CreatePanel("Panel", child, "BedWarsLoadingPlayerCopy");
                    copy.AddClass("LoadingPlayerCopy");
                    name.SetParent(copy);
                    status.SetParent(copy);
                }
                counts.total++;
                if (child.BHasClass("player_state_fully_connected")) counts.ready++;
            } else {
                countPlayers(child, counts);
            }
        }
    }

    function updateLoadingState() {
        if (!root || !root.IsValid()) return;
        var nativeRoot = loadingRoot();
        if (nativeRoot) {
            // Hide Valve's generic tip and duplicate sidebar for this custom
            // loading screen. Keep chat and the dashboard controls available.
            nativeRoot.AddClass("HideTips");
            var sidebars = nativeRoot.FindChildrenWithClassTraverse("CustomGameLoadingSidebar");
            for (var i = 0; i < sidebars.length; i++) sidebars[i].style.visibility = "collapse";
            if ((nativeRoot.BHasClass("is_waiting_for_players") || nativeRoot.BHasClass("is_custom_game_setup")) && !localLoaded) {
                localLoaded = true;
                changeSerial++;
                root.AddClass("LocalLoaded");
                if (autoAdvanceHandle !== null) $.CancelScheduled(autoAdvanceHandle);
                autoAdvanceHandle = null;
            }
        }
        if (localLoaded) {
            var counts = { total: 0, ready: 0 };
            countPlayers($("#LoadingPlayersList"), counts);
            $("#LoadingPlayersCount").text = counts.total > 0 ?
                $.Localize("#loading_players_count") + ": " + counts.ready + " / " + counts.total :
                $.Localize("#loading_players_connecting");
        }
        $.Schedule(0.25, updateLoadingState);
    }

    LoadingTips = {
        Previous: function () { change(-1); },
        Next: function () { change(1); },
        GoTo: function (index) { goTo(index); }
    };

    updateLoadingState();
    buildDots();
    render();
    if (!localLoaded) autoAdvanceHandle = $.Schedule(6.0, autoAdvance);
})();
