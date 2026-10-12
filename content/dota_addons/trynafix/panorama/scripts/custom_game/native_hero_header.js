(function () {
    "use strict";

    // Reuse Valve's DOTAHudHeroPickingPlayer controls. No replacement panels
    // are created: occupied seats keep their native player binding, portrait,
    // tooltip, PlayerName label and click handling; unused seats use the
    // remaining native controls as permanent empty placeholders.
    var root = $.GetContextPanel();
    var colors = { 6: "#e45a60", 7: "#58a8ef", 8: "#62c378", 9: "#ee9949" };

    // CLOCK POSITION: change only these four numbers.
    var HERO_PICK_TIMER_X = -325;
    var HERO_PICK_TIMER_Y = 900;
    var STRATEGY_TIMER_X = 50;
    var STRATEGY_TIMER_Y = 900;

    // Space between the two blue teammate panels in Duo mode.
    var DUO_CENTER_GAP = 0;

    var nativeState = null;
    var refreshPending = false;
    var refreshRunning = false;

    function hudRoot() {
        var panel = root;
        while (panel && panel.GetParent()) panel = panel.GetParent();
        return panel;
    }

    function firstChild(panel, ids) {
        if (!panel) return null;
        for (var index = 0; index < ids.length; index++) {
            var child = panel.FindChildTraverse(ids[index]);
            if (child) return child;
        }
        return null;
    }

    function slotIndex(panel) {
        if (!panel || !panel.BHasClass) return -1;
        for (var index = 0; index < 10; index++) {
            if (panel.BHasClass("Slot" + index)) return index;
        }
        return -1;
    }

    function playerCards(container) {
        var result = [];
        function walk(panel) {
            for (var index = 0; index < panel.GetChildCount(); index++) {
                var child = panel.GetChild(index);
                if (slotIndex(child) >= 0 || child.paneltype === "DOTAHudHeroPickingPlayer") {
                    result.push(child);
                } else if (child.GetChildCount() > 0) {
                    walk(child);
                }
            }
        }
        if (container) walk(container);
        result.sort(function (a, b) { return slotIndex(a) - slotIndex(b); });
        return result;
    }

    function firstNonPlayerChild(container) {
        if (!container) return null;
        for (var index = 0; index < container.GetChildCount(); index++) {
            var child = container.GetChild(index);
            if (slotIndex(child) < 0 && child.paneltype !== "DOTAHudHeroPickingPlayer") return child;
        }
        return null;
    }

    function validPanel(panel) {
        return !!panel && panel.IsValid();
    }

    function savedStyle(value, fallback) {
        return value === undefined || value === null || value === "" ? fallback : value;
    }

    function requiredCardCount() {
        return isDuo() ? 6 : 4;
    }

    function stateIsCurrent(state) {
        if (!state || !validPanel(state.header) || !validPanel(state.left) ||
            !validPanel(state.right) || !validPanel(state.timer) ||
            !validPanel(state.clock) || !validPanel(state.subtitle)) return false;

        var ui = hudRoot();
        if (!ui) return false;
        if (ui.FindChildTraverse("RadiantTeamPlayers") !== state.left) return false;
        if (ui.FindChildTraverse("DireTeamPlayers") !== state.right) return false;
        if (state.header.FindChildTraverse("HeaderCenter") !== state.timer) return false;
        var clockParent = state.clock.GetParent();
        var subtitleParent = state.subtitle.GetParent();
        if (clockParent !== state.timer && clockParent !== state.headerParent) return false;
        if (subtitleParent !== state.timer && subtitleParent !== state.headerParent) return false;
        if (state.left.GetParent() !== state.header || state.right.GetParent() !== state.header) return false;

        var currentCards = playerCards(state.left).concat(playerCards(state.right));
        if (currentCards.length !== state.allCards.length || currentCards.length < requiredCardCount()) return false;
        for (var index = 0; index < state.allCards.length; index++) {
            if (!validPanel(state.allCards[index]) || currentCards.indexOf(state.allCards[index]) === -1) return false;
        }
        return true;
    }

    function captureNative() {
        if (nativeState) {
            if (stateIsCurrent(nativeState)) return nativeState;
            restore();
        }

        // Valve's DOTAHudPreGame has no id. Its actual current child ids are
        // Header, RadiantTeamPlayers and DireTeamPlayers.
        var ui = hudRoot();
        if (!ui) return null;
        var left = ui.FindChildTraverse("RadiantTeamPlayers");
        var header = left ? left.GetParent() : null;
        if (!header || header.id !== "Header") return null;
        var right = header.FindChildTraverse("DireTeamPlayers");
        var timer = header.FindChildTraverse("HeaderCenter");
        var clock = timer ? timer.FindChildTraverse("ClockLabel") : null;
        var subtitle = timer ? timer.FindChildTraverse("HeaderSubtitle") : null;
        if (!left || !right || !timer || !clock || !subtitle ||
            right.GetParent() !== header || timer.GetParent() !== header) return null;

        var leftCards = playerCards(left);
        var rightCards = playerCards(right);
        var allCards = leftCards.concat(rightCards);
        allCards.sort(function (a, b) { return slotIndex(a) - slotIndex(b); });
        if (allCards.length < requiredCardCount()) return null;

        var originalParents = [];
        for (var index = 0; index < allCards.length; index++) {
            originalParents.push({ card: allCards[index], parent: allCards[index].GetParent() });
        }

        var timerParent = timer ? timer.GetParent() : null;
        var timerNextSibling = null;
        if (timer && timerParent) {
            for (var childIndex = 0; childIndex < timerParent.GetChildCount() - 1; childIndex++) {
                if (timerParent.GetChild(childIndex) === timer) {
                    timerNextSibling = timerParent.GetChild(childIndex + 1);
                    break;
                }
            }
        }
        var headerParent = header.GetParent();

        nativeState = {
            header: header,
            left: left,
            right: right,
            timer: timer,
            allCards: allCards,
            originalParents: originalParents,
            headerVisibility: header.style.visibility,
            headerOverflow: header.style.overflow,
            headerOpacity: header.style.opacity,
            headerTransform: header.style.transform,
            headerZIndex: header.style.zIndex,
            headerTransitionDelay: header.style.transitionDelay,
            headerTransitionDuration: header.style.transitionDuration,
            leftVisibility: left.style.visibility,
            rightVisibility: right.style.visibility,
            leftFlow: left.style.flowChildren,
            rightFlow: right.style.flowChildren,
            timerParent: timerParent,
            timerNextSibling: timerNextSibling,
            headerParent: headerParent,
            headerParentOverflow: headerParent ? headerParent.style.overflow : "",
            clock: clock,
            clockParent: clock.GetParent(),
            clockTransform: clock.style.transform,
            clockWidth: clock.style.width,
            clockMarginTop: clock.style.marginTop,
            clockZIndex: clock.style.zIndex,
            clockVisibility: clock.style.visibility,
            clockOpacity: clock.style.opacity,
            clockHorizontalAlign: clock.style.horizontalAlign,
            clockVerticalAlign: clock.style.verticalAlign,
            clockTransitionDuration: clock.style.transitionDuration,
            subtitle: subtitle,
            subtitleParent: subtitle.GetParent(),
            subtitleTransform: subtitle.style.transform,
            subtitleWidth: subtitle.style.width,
            subtitleMarginTop: subtitle.style.marginTop,
            subtitleZIndex: subtitle.style.zIndex,
            subtitleVisibility: subtitle.style.visibility,
            subtitleOpacity: subtitle.style.opacity,
            subtitleHorizontalAlign: subtitle.style.horizontalAlign,
            subtitleVerticalAlign: subtitle.style.verticalAlign,
            subtitleTransitionDuration: subtitle.style.transitionDuration,
            timerTransform: timer ? timer.style.transform : "",
            timerWidth: timer ? timer.style.width : "",
            timerZIndex: timer ? timer.style.zIndex : "",
            timerVisibility: timer ? timer.style.visibility : "",
            timerOpacity: timer ? timer.style.opacity : "",
            timerHorizontalAlign: timer ? timer.style.horizontalAlign : "",
            timerVerticalAlign: timer ? timer.style.verticalAlign : "",
            timerTransitionDelay: timer ? timer.style.transitionDelay : "",
            timerTransitionDuration: timer ? timer.style.transitionDuration : ""
        };
        return nativeState;
    }

    function isDuo() {
        var info = Game.GetMapInfo ? Game.GetMapInfo() : null;
        return !!info && String(info.map_name || "").toLowerCase().indexOf("bw_duo") !== -1;
    }

    function teamPlayers(teamID) {
        var ids = (Game.GetPlayerIDsOnTeam(teamID) || []).slice();
        var localPlayerID = Game.GetLocalPlayerID();
        if (localPlayerID >= 0 && Players.GetTeam(localPlayerID) === teamID && ids.indexOf(localPlayerID) === -1) {
            ids.push(localPlayerID);
        }
        ids.sort(function (a, b) { return a - b; });
        return ids;
    }

    function makeSeats(specifications) {
        var seats = [];
        for (var groupIndex = 0; groupIndex < specifications.length; groupIndex++) {
            var group = specifications[groupIndex];
            var ids = teamPlayers(group.team);
            var playerOffset = group.playerOffset || 0;
            for (var seatIndex = 0; seatIndex < group.slots; seatIndex++) {
                var playerIndex = playerOffset + seatIndex;
                seats.push({
                    team: group.team,
                    playerID: ids[playerIndex] === undefined ? -1 : ids[playerIndex],
                    startsTeam: groupIndex > 0 && seatIndex === 0,
                    card: null
                });
            }
        }
        return seats;
    }

    function assignNativeCards(seats, cards) {
        var bySlot = {};
        var used = {};
        for (var cardIndex = 0; cardIndex < cards.length; cardIndex++) {
            bySlot[slotIndex(cards[cardIndex])] = cards[cardIndex];
        }

        // First reserve the control natively bound to every occupied player.
        // This preserves Valve's clickable nickname and player popup.
        for (var seatIndex = 0; seatIndex < seats.length; seatIndex++) {
            var playerID = seats[seatIndex].playerID;
            var occupiedCard = playerID >= 0 ? bySlot[playerID] : null;
            if (occupiedCard && !used[slotIndex(occupiedCard)]) {
                seats[seatIndex].card = occupiedCard;
                used[slotIndex(occupiedCard)] = true;
            }
        }

        // Give every empty/unmatched seat a real unused Valve panel.
        for (var emptyIndex = 0; emptyIndex < seats.length; emptyIndex++) {
            if (seats[emptyIndex].card) continue;
            for (var availableIndex = 0; availableIndex < cards.length; availableIndex++) {
                var availableSlot = slotIndex(cards[availableIndex]);
                if (!used[availableSlot]) {
                    seats[emptyIndex].card = cards[availableIndex];
                    used[availableSlot] = true;
                    break;
                }
            }
        }
    }

    function hideCard(card) {
        if (!card || !card.IsValid()) return;
        card.style.visibility = "collapse";
        card.style.opacity = "0";
    }

    function playerHeroName(playerID) {
        if (playerID === undefined || playerID === null || playerID < 0) return "";
        var heroName = Players.GetPlayerSelectedHero(playerID) || "";
        if (heroName) return String(heroName);
        var info = Game.GetPlayerInfo(playerID);
        if (info && info.player_selected_hero) return String(info.player_selected_hero);
        var published = CustomNetTables.GetTableValue("random_draft", "player_" + playerID);
        return published && published.hero_name ? String(published.hero_name) : "";
    }

    function makePlayerNameInteractive(playerName, playerID) {
        if (!playerName || playerID < 0) return;
        var info = Game.GetPlayerInfo(playerID);
        var steamID = info && info.player_steamid ? String(info.player_steamid) : "";
        var fallbackName = Players.GetPlayerName(playerID) || ("Player " + (playerID + 1));

        playerName.hittest = true;
        playerName.SetPanelEvent("onmouseover", function () {
            playerName.style.color = "#ffffff";
            if (steamID && steamID !== "0") {
                $.DispatchEvent("DOTAShowProfileCardTooltip", playerName, steamID, false);
            } else {
                $.DispatchEvent("DOTAShowTextTooltip", playerName, fallbackName);
            }
        });
        playerName.SetPanelEvent("onmouseout", function () {
            playerName.style.color = "#c6dfff";
            $.DispatchEvent("DOTAHideProfileCardTooltip", playerName);
            $.DispatchEvent("DOTAHideTextTooltip", playerName);
        });
        playerName.SetPanelEvent("onactivate", function () {
            if (steamID && steamID !== "0") {
                $.DispatchEvent("DOTAShowPlayerContextMenu", playerName, steamID);
            }
        });
        playerName.SetPanelEvent("oncontextmenu", function () {
            if (steamID && steamID !== "0") {
                $.DispatchEvent("DOTAShowPlayerContextMenu", playerName, steamID);
            }
        });
    }

    function showCard(seat) {
        var card = seat.card;
        if (!card || !card.IsValid()) return;
        card.style.visibility = "visible";
        card.style.opacity = "1";
        card.style.transform = "translateY(0px)";
        card.style.transitionDelay = "0s";
        card.style.transitionDuration = "0s";
        card.style.marginLeft = seat.startsTeam ? "12px" : "0px";
        card.style.marginRight = "0px";
        card.hittest = true;
        card.hittestchildren = true;
        card.SetHasClass("ShowHeroName", false);

        // HeroImagePickBar is Valve's separate glow/effect layer, not the thin
        // native team strip. Keep that effect hidden. The real strip is the
        // exposed bottom edge of HeroImageContainer beneath HeroImage.
        var pickBar = firstChild(card, ["HeroImagePickBar"]);
        if (pickBar) {
            pickBar.style.visibility = "collapse";
            pickBar.style.opacity = "0";
            pickBar.style.blur = "none";
            pickBar.style.animationName = "none";
            pickBar.style.transitionDelay = "0s";
            pickBar.style.transitionDuration = "0s";
        }

        // Reparenting Valve's player controls stops its portrait binding on
        // some clients. Explicitly feed the chosen hero back into the same
        // native DOTAHeroImage control on every refresh.
        var heroName = seat.playerID >= 0 ? playerHeroName(seat.playerID) : "";
        var heroImage = firstChild(card, ["HeroImage"]);
        var heroImageContainer = firstChild(card, ["HeroImageContainer"]);
        card.SetHasClass("HeroPickNone", heroName.length === 0);
        card.SetHasClass("HeroPickTentative", false);
        if (heroImage) {
            if (heroImage.heroname !== heroName) heroImage.heroname = heroName;
            heroImage.style.visibility = "visible";
            // An empty DOTAHeroImage supplies Valve's native dark gradient.
            // Keeping it visible prevents the bright SlotN color underneath
            // from filling the entire empty player card.
            heroImage.style.opacity = "1";
        }
        if (heroImageContainer) {
            heroImageContainer.style.visibility = "visible";
            heroImageContainer.style.opacity = "1";
            heroImageContainer.style.backgroundColor = colors[seat.team];
            heroImageContainer.style.washColor = "white";
            heroImageContainer.style.animationName = "none";
            heroImageContainer.style.transitionDelay = "0s";
            heroImageContainer.style.transitionDuration = "0s";
        }

        // Keep the visible name on Valve's own acceptsinput label, and restore
        // the native profile tooltip/context menu even after reparenting.
        var playerName = firstChild(card, ["PlayerName"]);
        if (playerName && seat.playerID >= 0) {
            playerName.text = Players.GetPlayerName(seat.playerID) || ("Player " + (seat.playerID + 1));
            playerName.style.visibility = "visible";
            playerName.style.opacity = "1";
            makePlayerNameInteractive(playerName, seat.playerID);
        } else if (playerName) {
            playerName.text = "";
            playerName.style.visibility = "collapse";
        }
        var nameContainer = firstChild(card, ["NameContainer"]);
        var playerNameContainer = firstChild(card, ["PlayerNameContainer"]);
        if (nameContainer) {
            nameContainer.style.visibility = seat.playerID >= 0 ? "visible" : "collapse";
            nameContainer.style.opacity = seat.playerID >= 0 ? "1" : "0";
            nameContainer.style.transitionDelay = "0s";
            nameContainer.style.transitionDuration = "0s";
        }
        if (playerNameContainer) {
            playerNameContainer.style.visibility = seat.playerID >= 0 ? "visible" : "collapse";
            playerNameContainer.style.opacity = seat.playerID >= 0 ? "1" : "0";
        }
    }

    function placeSide(container, seats, leftSide) {
        if (!container) return;
        try {
            container.style.flowChildren = leftSide ? "left" : "right";
        } catch (error) {
            $.Msg("[Trynafix] Native hero-header flow fallback: " + error);
        }
        var anchor = firstNonPlayerChild(container);
        var ordered = leftSide ? seats.slice().reverse() : seats.slice();

        for (var index = 0; index < ordered.length; index++) {
            var card = ordered[index].card;
            if (!card || !card.IsValid()) continue;
            try {
                if (card.GetParent() !== container) card.SetParent(container);
                if (anchor && anchor.IsValid()) container.MoveChildBefore(card, anchor);
            } catch (error) {
                // A future Valve placement restriction must not abort the rest
                // of the roster and leave a single visible card again.
                $.Msg("[Trynafix] Native hero-header placement fallback: " + error);
            }
            showCard(ordered[index]);
        }
    }

    function applyRoster(native) {
        var leftSeats;
        var rightSeats;
        if (isDuo()) {
            // Center the six native panels as 3 + 3. Split the middle (blue)
            // duo across HeaderCenter so its left card uses Valve's left slant
            // and its right card uses Valve's mirrored right slant.
            leftSeats = makeSeats([
                { team: 6, slots: 2 },
                { team: 7, slots: 1, playerOffset: 0 }
            ]);
            rightSeats = makeSeats([
                { team: 7, slots: 1, playerOffset: 1 },
                { team: 8, slots: 2 }
            ]);
        } else {
            leftSeats = makeSeats([{ team: 6, slots: 1 }, { team: 7, slots: 1 }]);
            rightSeats = makeSeats([{ team: 8, slots: 1 }, { team: 9, slots: 1 }]);
        }

        var allSeats = leftSeats.concat(rightSeats);
        assignNativeCards(allSeats, native.allCards);

        // Exactly four BW_Solo or six BW_Duo panels are revealed, even if
        // every seat but the local player's is currently empty.
        for (var index = 0; index < native.allCards.length; index++) hideCard(native.allCards[index]);
        placeSide(native.left, leftSeats, true);
        placeSide(native.right, rightSeats, false);
    }

    function applyEmergencyRoster(native) {
        // Last-resort invariant: even if Valve changes a panel-placement API,
        // never leave a partial 1+5 header. Keep exactly the required number
        // of native, player-bound controls visible.
        var count = isDuo() ? 6 : 4;
        for (var index = 0; index < native.allCards.length; index++) {
            hideCard(native.allCards[index]);
        }
        for (var visible = 0; visible < count && visible < native.allCards.length; visible++) {
            native.allCards[visible].style.visibility = "visible";
            native.allCards[visible].style.opacity = "1";
            native.allCards[visible].style.transform = "translateY(0px)";
            native.allCards[visible].style.transitionDelay = "0s";
            native.allCards[visible].style.transitionDuration = "0s";
            native.allCards[visible].hittest = true;
            native.allCards[visible].hittestchildren = true;
        }
    }

    function restoreTimerOrder(native) {
        if (!native.timer || !native.timer.IsValid()) return;
        try {
            if (native.timerParent && native.timer.GetParent() !== native.timerParent) {
                native.timer.SetParent(native.timerParent);
            }
            if (native.timerParent && native.timerNextSibling && native.timerNextSibling.IsValid() &&
                native.timerNextSibling.GetParent() === native.timerParent) {
                native.timerParent.MoveChildBefore(native.timer, native.timerNextSibling);
            }
        } catch (error) {
            $.Msg("[Trynafix] Native pick-timer order fallback: " + error);
        }
    }

    function restoreTimerContents(native) {
        if (!native) return;
        try {
            if (validPanel(native.clock) && validPanel(native.clockParent) &&
                native.clock.GetParent() !== native.clockParent) {
                native.clock.SetParent(native.clockParent);
            }
            if (validPanel(native.subtitle) && validPanel(native.subtitleParent) &&
                native.subtitle.GetParent() !== native.subtitleParent) {
                native.subtitle.SetParent(native.subtitleParent);
            }
            if (validPanel(native.clock) && validPanel(native.subtitle) &&
                native.clock.GetParent() === native.subtitle.GetParent()) {
                native.clock.GetParent().MoveChildBefore(native.clock, native.subtitle);
            }
        } catch (error) {
            $.Msg("[Trynafix] Native clock-content restore fallback: " + error);
        }

        if (validPanel(native.clock)) {
            native.clock.style.transform = savedStyle(native.clockTransform, "translateX(0px) translateY(0px)");
            native.clock.style.width = savedStyle(native.clockWidth, "100%");
            native.clock.style.marginTop = savedStyle(native.clockMarginTop, "0px");
            native.clock.style.zIndex = savedStyle(native.clockZIndex, "0");
            native.clock.style.visibility = savedStyle(native.clockVisibility, "visible");
            native.clock.style.opacity = savedStyle(native.clockOpacity, "1");
            native.clock.style.horizontalAlign = savedStyle(native.clockHorizontalAlign, "left");
            native.clock.style.verticalAlign = savedStyle(native.clockVerticalAlign, "top");
            native.clock.style.transitionDuration = savedStyle(native.clockTransitionDuration, "0.4s");
        }
        if (validPanel(native.subtitle)) {
            native.subtitle.style.transform = savedStyle(native.subtitleTransform, "translateX(0px) translateY(0px)");
            native.subtitle.style.width = savedStyle(native.subtitleWidth, "100%");
            native.subtitle.style.marginTop = savedStyle(native.subtitleMarginTop, "64px");
            native.subtitle.style.zIndex = savedStyle(native.subtitleZIndex, "0");
            native.subtitle.style.visibility = savedStyle(native.subtitleVisibility, "visible");
            native.subtitle.style.opacity = savedStyle(native.subtitleOpacity, "1");
            native.subtitle.style.horizontalAlign = savedStyle(native.subtitleHorizontalAlign, "left");
            native.subtitle.style.verticalAlign = savedStyle(native.subtitleVerticalAlign, "top");
            native.subtitle.style.transitionDuration = savedStyle(native.subtitleTransitionDuration, "0.5s");
        }
    }

    function positionTimer(native) {
        if (!native.timer || !native.timer.IsValid()) return;
        restoreTimerOrder(native);
        // Keep HeaderCenter in Valve's layout so the player groups never move.
        // Move the two existing native clock panels to the full-screen pregame
        // root; this avoids Header/MainContents clipping in both pick states.
        native.header.style.overflow = "noclip";
        native.header.style.opacity = "1";
        native.header.style.transform = "translateY(0px)";
        native.header.style.transitionDelay = "0s";
        native.header.style.transitionDuration = "0s";
        if (native.headerParent) native.headerParent.style.overflow = "noclip";
        native.timer.style.transform = "translateX(0px) translateY(0px)";
        if (isDuo()) native.timer.style.width = DUO_CENTER_GAP + "px";
        native.timer.style.horizontalAlign = "center";
        native.timer.style.verticalAlign = "top";
        native.timer.style.visibility = "visible";
        native.timer.style.opacity = "1";
        native.timer.style.transitionDelay = "0s";
        native.timer.style.transitionDuration = "0s";

        if (native.headerParent && native.clock.GetParent() !== native.headerParent) {
            native.clock.SetParent(native.headerParent);
        }
        if (native.headerParent && native.subtitle.GetParent() !== native.headerParent) {
            native.subtitle.SetParent(native.headerParent);
        }

        var strategyTime = Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME);
        var timerX = strategyTime ? STRATEGY_TIMER_X : HERO_PICK_TIMER_X;
        var timerY = strategyTime ? STRATEGY_TIMER_Y : HERO_PICK_TIMER_Y;
        var timerTransform = "translateX(" + timerX + "px) translateY(" + timerY + "px)";

        native.clock.style.width = "250px";
        native.clock.style.marginTop = "0px";
        native.clock.style.horizontalAlign = "center";
        native.clock.style.verticalAlign = "top";
        native.clock.style.transform = timerTransform;
        native.clock.style.visibility = "visible";
        native.clock.style.opacity = "1";
        native.clock.style.zIndex = "1001";
        native.clock.style.transitionDuration = "0s";

        native.subtitle.style.width = "250px";
        native.subtitle.style.marginTop = "64px";
        native.subtitle.style.horizontalAlign = "center";
        native.subtitle.style.verticalAlign = "top";
        native.subtitle.style.transform = timerTransform;
        native.subtitle.style.visibility = "visible";
        native.subtitle.style.opacity = "1";
        native.subtitle.style.zIndex = "1001";
        native.subtitle.style.transitionDuration = "0s";
    }

    function restore() {
        var state = nativeState;
        nativeState = null;
        if (!state) return;

        if (validPanel(state.header)) {
            state.header.style.visibility = savedStyle(state.headerVisibility, "visible");
            state.header.style.overflow = savedStyle(state.headerOverflow, "noclip");
            state.header.style.opacity = savedStyle(state.headerOpacity, "1");
            state.header.style.transform = savedStyle(state.headerTransform, "translateY(0px)");
            state.header.style.zIndex = savedStyle(state.headerZIndex, "0");
            state.header.style.transitionDelay = savedStyle(state.headerTransitionDelay, "0s");
            state.header.style.transitionDuration = savedStyle(state.headerTransitionDuration, "0s");
        }
        if (validPanel(state.left)) {
            state.left.style.visibility = savedStyle(state.leftVisibility, "visible");
            state.left.style.flowChildren = savedStyle(state.leftFlow, "right");
        }
        if (validPanel(state.right)) {
            state.right.style.visibility = savedStyle(state.rightVisibility, "visible");
            state.right.style.flowChildren = savedStyle(state.rightFlow, "right");
        }
        if (validPanel(state.timer)) {
            restoreTimerOrder(state);
            state.timer.style.transform = savedStyle(state.timerTransform, "translateX(0px) translateY(0px)");
            state.timer.style.width = savedStyle(state.timerWidth, "250px");
            state.timer.style.zIndex = savedStyle(state.timerZIndex, "0");
            state.timer.style.visibility = savedStyle(state.timerVisibility, "visible");
            state.timer.style.opacity = savedStyle(state.timerOpacity, "1");
            state.timer.style.horizontalAlign = savedStyle(state.timerHorizontalAlign, "center");
            state.timer.style.verticalAlign = savedStyle(state.timerVerticalAlign, "top");
            state.timer.style.transitionDelay = savedStyle(state.timerTransitionDelay, "0s");
            state.timer.style.transitionDuration = savedStyle(state.timerTransitionDuration, "1s");
        }
        restoreTimerContents(state);
        if (validPanel(state.headerParent)) {
            state.headerParent.style.overflow = savedStyle(state.headerParentOverflow, "clip");
        }

        for (var index = 0; index < state.originalParents.length; index++) {
            var original = state.originalParents[index];
            var card = original.card;
            if (!card || !card.IsValid()) continue;
            try {
                if (card.GetParent() !== original.parent) card.SetParent(original.parent);
            } catch (error) {
                $.Msg("[Trynafix] Native hero-header restore fallback: " + error);
            }
            card.style.visibility = "visible";
            card.style.opacity = "1";
            card.style.marginLeft = "0px";
            card.style.marginRight = "0px";
            card.style.transform = "translateY(0px)";
        }
    }

    function scheduleRefresh(delay) {
        if (refreshPending) return;
        refreshPending = true;
        $.Schedule(delay, function () {
            refreshPending = false;
            refresh();
        });
    }

    function refresh() {
        if (refreshRunning) return;
        refreshRunning = true;
        var nextDelay = 0.03;
        var keepRunning = true;

        try {
            if (!root || !root.IsValid()) {
                keepRunning = false;
                return;
            }

            var picking = Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_HERO_SELECTION);
            var strategy = Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME);
            if (picking || strategy) {
                var native = captureNative();
                if (!native) {
                    // Valve constructs the pregame children asynchronously.
                    // Retry next frame instead of caching a partial header.
                    nextDelay = 0.016;
                } else {
                    native.header.style.visibility = "visible";
                    native.header.style.opacity = "1";
                    native.header.style.transform = "translateY(0px)";
                    native.header.style.transitionDelay = "0s";
                    native.header.style.transitionDuration = "0s";
                    native.left.style.visibility = "visible";
                    native.left.style.opacity = "1";
                    native.right.style.visibility = "visible";
                    native.right.style.opacity = "1";
                    positionTimer(native);
                    try {
                        applyRoster(native);
                    } catch (rosterError) {
                        $.Msg("[Trynafix] Native hero-header roster fallback: " + rosterError);
                        applyEmergencyRoster(native);
                    }
                }
            } else {
                var currentState = Game.GetState ? Game.GetState() : -1;
                if (currentState >= 0 && currentState < DOTA_GameState.DOTA_GAMERULES_STATE_HERO_SELECTION) {
                    // Pre-capture Valve's controls before the pick-state event
                    // so four/six panels can be shown on its very first frame.
                    if (!nativeState || !stateIsCurrent(nativeState)) captureNative();
                } else if (nativeState) {
                    restore();
                }
                nextDelay = 0.03;
            }

            if (Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS) ||
                Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_POST_GAME)) {
                if (nativeState) restore();
                keepRunning = false;
            }
        } catch (error) {
            // A single bad/stale native control must never kill all future
            // initialization attempts.
            $.Msg("[Trynafix] Native hero-header refresh retry: " + error);
            nextDelay = 0.016;
            if (nativeState && !stateIsCurrent(nativeState)) restore();
        } finally {
            refreshRunning = false;
            if (keepRunning) scheduleRefresh(nextDelay);
        }
    }

    function kickRefresh() {
        refresh();
    }

    try {
        GameEvents.Subscribe("game_rules_state_change", kickRefresh);
        GameEvents.Subscribe("dota_player_update_hero_selection", kickRefresh);
        GameEvents.Subscribe("dota_player_hero_selection_dirty", kickRefresh);
    } catch (error) {
        $.Msg("[Trynafix] Native hero-header event bootstrap fallback: " + error);
    }

    refresh();
})();
