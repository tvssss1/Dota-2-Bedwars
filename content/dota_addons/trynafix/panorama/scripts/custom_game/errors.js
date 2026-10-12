GameEvents.Subscribe("ShowError", (data) => {
    GameEvents.SendEventClientSide("dota_hud_error_message", {
        splitscreenplayer: 0,
        reason: "",
        message: data.message
    });
});