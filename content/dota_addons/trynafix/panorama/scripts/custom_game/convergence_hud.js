(function () {
    "use strict";

    var context = $.GetContextPanel();
    var offer = context.FindChildTraverse("ConvergenceOffer");
    var offerCards = context.FindChildTraverse("OfferCards");
    var offerTimeoutFill = context.FindChildTraverse("OfferTimeoutFill");
    var activeOffer = null;

    var perks = {
        balloon_brigade: { ability: "convergence_perk_balloon_brigade", text: "#convergence_perk_balloon" },
        temporal_snapback: { ability: "convergence_perk_temporal_snapback", text: "#convergence_perk_snapback" },
        wild_card: { ability: "convergence_perk_wild_card", text: "#convergence_perk_wild" },
        treasure_trickster: { ability: "convergence_perk_treasure_trickster", text: "#convergence_perk_treasure" },
        holo_hustle: { ability: "convergence_perk_holo_hustle", text: "#convergence_perk_holo" },
        storm_chaser: { ability: "convergence_perk_storm_chaser", text: "#convergence_perk_storm" },
        kaiju_protocol: { ability: "convergence_perk_kaiju_protocol", text: "#convergence_perk_kaiju" },
        meteor_contract: { ability: "convergence_perk_meteor_contract", text: "#convergence_perk_meteor" }
    };

    function gameTime() {
        return Math.max(0, Number(Game.GetDOTATime(false, false)) || 0);
    }

    function createPips(parent, idPrefix) {
        var container = $.CreatePanel("Panel", parent, idPrefix);
        container.AddClass("RankPips");
        container.hittest = false;
        for (var index = 1; index <= 3; index++) {
            var pip = $.CreatePanel("Panel", container, idPrefix + "_" + index);
            pip.AddClass("RankPip");
            pip.hittest = false;
        }
        return container;
    }

    function updatePips(container, rank) {
        rank = Math.max(0, Number(rank) || 0);
        for (var index = 0; index < container.GetChildCount(); index++) {
            container.GetChild(index).SetHasClass("On", index < rank);
        }
    }

    function sendChoice(sequence, perkID, button) {
        if (!activeOffer || activeOffer.sequence !== sequence) return;
        offer.AddClass("Choosing");
        button.AddClass("Selected");
        GameEvents.SendCustomGameEventToServer("convergence_choose_perk", {
            sequence: sequence,
            perk_id: perkID
        });
    }

    function createOfferCard(perkID, rank, sequence) {
        var definition = perks[perkID];
        if (!definition) return;
        var button = $.CreatePanel("Button", offerCards, "Offer_" + perkID);
        button.AddClass("OfferCard");

        var image = $.CreatePanel("DOTAAbilityImage", button, "");
        image.AddClass("OfferAbilityImage");
        image.abilityname = definition.ability;
        image.hittest = false;

        var info = $.CreatePanel("Panel", button, "");
        info.AddClass("OfferInfo");
        info.hittest = false;

        var titleRow = $.CreatePanel("Panel", info, "");
        titleRow.AddClass("OfferTitleRow");
        titleRow.hittest = false;

        var name = $.CreatePanel("Label", titleRow, "");
        name.AddClass("OfferName");
        name.text = $.Localize(definition.text, context);
        name.hittest = false;

        var displayRank = Math.max(1, Math.min(3, Number(rank) || 1));
        createPips(titleRow, "OfferRank_" + perkID);
        updatePips(button.FindChildTraverse("OfferRank_" + perkID), displayRank);

        var description = $.CreatePanel("Label", info, "");
        description.AddClass("OfferDescription");
        description.text = $.Localize(definition.text + "_desc_" + displayRank, context);
        description.hittest = false;

        button.SetPanelEvent("onmouseover", function () {
            Game.EmitSound("ui_generic_button_over");
        });
        button.SetPanelEvent("onactivate", function () {
            Game.EmitSound("ui_generic_button_click");
            sendChoice(sequence, perkID, button);
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
            duration: Math.max(1, Number(data.duration) || 15)
        };
        offerCards.RemoveAndDeleteChildren();
        var count = Number(data.option_count) || 0;
        for (var index = 1; index <= count; index++) {
            createOfferCard(
                String(data["option_" + index] || ""),
                Number(data["rank_" + index]) || 1,
                activeOffer.sequence
            );
        }
        offer.RemoveClass("Choosing");
        offer.SetHasClass("Upgrade", String(data.mode || "") === "upgrade");
        offer.AddClass("Visible");
        offer.hittest = true;
        offer.hittestchildren = true;
        GameEvents.SendCustomGameEventToServer("convergence_offer_seen", {
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
        offerTimeoutFill.style.width = Math.min(100, remaining / activeOffer.duration * 100) + "%";
        if (remaining <= 0) hideOffer();
    }

    function loop() {
        if (!context || !context.IsValid()) return;
        updateOfferTimer();
        $.Schedule(0.1, loop);
    }

    GameEvents.Subscribe("convergence_offer", onOffer);
    GameEvents.Subscribe("convergence_perk_selected", function () {
        hideOffer();
        Game.EmitSound("Outpost.Reward");
    });

    offer.hittest = false;
    offer.hittestchildren = false;
    function requestContext() {
        if (!context || !context.IsValid()) return;
        if (activeOffer) {
            GameEvents.SendCustomGameEventToServer("convergence_offer_seen", {
                sequence: activeOffer.sequence
            });
        } else {
            GameEvents.SendCustomGameEventToServer("convergence_request_context", {});
        }
        $.Schedule(1.0, requestContext);
    }

    requestContext();
    loop();
})();
