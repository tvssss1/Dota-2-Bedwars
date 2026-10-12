(function () {
    "use strict";

    var context = $.GetContextPanel();
    var offer = context.FindChildTraverse("AbilityOffer");
    var offerCards = context.FindChildTraverse("AbilityOfferCards");
    var offerTitle = context.FindChildTraverse("OfferTitle");
    var offerTimerFill = context.FindChildTraverse("AbilityOfferTimerFill");
    var nextAbilityTimer = context.FindChildTraverse("NextAbilityTimer");
    var activeOffer = null;
    var nextAbilityAt = -1;

    function localize(token) {
        return $.Localize(token, context);
    }

    function abilityName(ability) {
        var token = "#DOTA_Tooltip_ability_" + ability;
        var result = localize(token);
        return result === token ? ability.replace(/_/g, " ") : result;
    }

    function gameTime() {
        return Math.max(0, Number(Game.GetDOTATime(false, false)) || 0);
    }

    function formatDuration(seconds) {
        seconds = Math.max(0, Math.ceil(seconds));
        var minutes = Math.floor(seconds / 60);
        var remainder = seconds % 60;
        return String(minutes) + ":" + (remainder < 10 ? "0" : "") + String(remainder);
    }

    function showAbilityTooltip(panel, name) {
        if (name) $.DispatchEvent("DOTAShowAbilityTooltip", panel, name);
    }

    function hideAbilityTooltip(panel) {
        $.DispatchEvent("DOTAHideAbilityTooltip", panel);
    }

    function sendChoice(sequence, name, button) {
        if (!activeOffer || activeOffer.sequence !== sequence) return;
        offer.AddClass("Choosing");
        button.AddClass("Selected");
        GameEvents.SendCustomGameEventToServer("ability_draft_choose", {
            sequence: sequence,
            ability_name: name
        });
    }

    function createOfferCard(name, role, sequence, index, count) {
        if (!name) return;
        var button = $.CreatePanel("Button", offerCards, "AbilityOffer_" + name);
        button.AddClass("AbilityOfferCard");
        var image = $.CreatePanel("DOTAAbilityImage", button, "");
        image.AddClass("AbilityOfferImage");
        image.abilityname = name;
        image.hittest = false;

        var nameLabel = $.CreatePanel("Label", button, "");
        nameLabel.AddClass("AbilityName");
        nameLabel.text = abilityName(name);
        nameLabel.hittest = false;

        button.SetPanelEvent("onmouseover", function () {
            Game.EmitSound("ui_generic_button_over");
            showAbilityTooltip(button, name);
        });
        button.SetPanelEvent("onmouseout", function () {
            hideAbilityTooltip(button);
        });
        button.SetPanelEvent("onactivate", function () {
            Game.EmitSound("ui_generic_button_click");
            hideAbilityTooltip(button);
            sendChoice(sequence, name, button);
        });
    }

    function onOffer(data) {
        if (!data) return;
        context.visible = true;
        context.style.visibility = "visible";
        var host = context.GetParent();
        if (host) {
            host.visible = true;
            host.style.visibility = "visible";
        }
        offer.visible = true;
        offer.style.visibility = "visible";
        activeOffer = {
            sequence: Number(data.sequence),
            expiresAt: Number(data.expires_at),
            duration: Math.max(1, Number(data.duration) || 18)
        };
        offerCards.RemoveAndDeleteChildren();
        var count = Number(data.option_count) || 0;
        for (var index = 1; index <= count; index++) {
            createOfferCard(
                String(data["option_" + index] || ""),
                String(data["role_" + index] || "ultimate"),
                activeOffer.sequence,
                index,
                count
            );
        }
        var ultimate = String(data.kind || "") === "ultimate";
        offerTitle.text = localize(ultimate ? "#ability_draft_ultimate_title" : "#ability_draft_basic_title");
        offer.SetHasClass("Ultimate", ultimate);
        offer.RemoveClass("Choosing");
        offer.AddClass("Visible");
        offer.hittest = true;
        offer.hittestchildren = true;
        GameEvents.SendCustomGameEventToServer("ability_draft_offer_seen", {
            sequence: activeOffer.sequence
        });
        Game.EmitSound("Outpost.Reward");
    }

    function hideOffer() {
        activeOffer = null;
        offer.RemoveClass("Visible");
        offer.RemoveClass("Choosing");
        offer.hittest = false;
        offer.hittestchildren = false;
    }

    function updateOfferTimer() {
        if (!activeOffer) return;
        var remaining = Math.max(0, activeOffer.expiresAt - gameTime());
        offerTimerFill.style.width = Math.min(100, remaining / activeOffer.duration * 100) + "%";
        if (remaining <= 0) hideOffer();
    }

    function updateNextAbilityTimer() {
        var inGame = Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS);
        var visible = inGame && !activeOffer && nextAbilityAt >= 0;
        nextAbilityTimer.SetHasClass("Visible", visible);
        if (!visible) return;
        nextAbilityTimer.text = localize("#ability_draft_next_ability") + "  " +
            formatDuration(nextAbilityAt - gameTime());
    }

    function loop() {
        if (!context || !context.IsValid()) return;
        updateOfferTimer();
        updateNextAbilityTimer();
        $.Schedule(0.1, loop);
    }

    GameEvents.Subscribe("ability_draft_offer", onOffer);
    GameEvents.Subscribe("ability_draft_selected", function () {
        hideOffer();
        Game.EmitSound("Outpost.Reward");
    });
    GameEvents.Subscribe("ability_draft_error", function () {
        offer.RemoveClass("Choosing");
        Game.EmitSound("General.Cancel");
    });

    function onDraftState(tableName, key, data) {
        if (tableName !== "ability_draft" || String(key) !== String(Game.GetLocalPlayerID())) return;
        nextAbilityAt = data && Number(data.next_unlock_at) >= 0 ? Number(data.next_unlock_at) : -1;
        updateNextAbilityTimer();
    }

    CustomNetTables.SubscribeNetTableListener("ability_draft", onDraftState);
    var localPlayerKey = String(Game.GetLocalPlayerID());
    onDraftState("ability_draft", localPlayerKey,
        CustomNetTables.GetTableValue("ability_draft", localPlayerKey));

    function requestContext() {
        if (!context || !context.IsValid()) return;
        if (activeOffer) {
            GameEvents.SendCustomGameEventToServer("ability_draft_offer_seen", {
                sequence: activeOffer.sequence
            });
        } else {
            GameEvents.SendCustomGameEventToServer("ability_draft_request_context", {});
        }
        // Keep a lightweight heartbeat for future offers too. A one-shot
        // event can be lost while Panorama is recreated during HUD loading.
        $.Schedule(1.0, requestContext);
    }

    requestContext();
    loop();
})();
