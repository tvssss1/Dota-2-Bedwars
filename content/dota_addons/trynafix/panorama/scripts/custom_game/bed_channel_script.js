(function () {
    let channelPanel = null;
    const bedIcons = {
        red: "file://{images}/custom_game/recall/bed_red.png",
        blue: "file://{images}/custom_game/recall/bed_blue.png",
        green: "file://{images}/custom_game/recall/bed_green.png",
        orange: "file://{images}/custom_game/recall/bed_orange.png"
    };

    function ChannelBed(data) {
        if (channelPanel) channelPanel.DeleteAsync(0);

        const createdPanel = $.CreatePanel("Panel", $.GetContextPanel(), "rootPanelOfChannel");
        channelPanel = createdPanel;
        createdPanel.hittest = false;
        createdPanel.hittestchildren = false;
        createdPanel.BLoadLayoutSnippet("BedTpChannel");
        const icon = createdPanel.FindChildTraverse("RecallIcon");
        const color = data && bedIcons[data.bed_color] ? data.bed_color : "red";
        if (icon && icon.IsValid()) icon.SetImage(bedIcons[color]);
        const anim = createdPanel.FindChildTraverse("FillBar");
        $.Schedule(0.0, function () {
            if (!createdPanel.IsValid() || channelPanel !== createdPanel) return;
            createdPanel.AddClass("IsActive");
            if (anim && anim.IsValid()) anim.AddClass("Fill");
        });
    }
    function ClosePanelChannel(){
        if (!channelPanel) return;

        channelPanel.RemoveClass("IsActive");
        channelPanel.AddClass("IsNotActive");
        channelPanel.DeleteAsync(0.25);
        channelPanel = null;
    }

    GameEvents.Subscribe("OpenChannelBed", ChannelBed);
    GameEvents.Subscribe("CloseChannelBed", ClosePanelChannel);
})();
