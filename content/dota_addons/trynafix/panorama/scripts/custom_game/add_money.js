(function () {
    var root=$.CreatePanel("Panel",$.GetContextPanel(),"MoneyRoot");
    root.BLoadLayoutSnippet("Money");
    var purpleButton=root.FindChildTraverse("PurpleMoneyButton");
    var greenButton=root.FindChildTraverse("GreenMoneyButton");
    function toggleShop(toggleName, attempt) {
        var toggle=GameUI.CustomUIConfig()[toggleName];
        if (typeof toggle === "function") toggle();
        else if ((attempt || 0) < 20) {
            $.Schedule(0.1,function(){ toggleShop(toggleName,(attempt || 0)+1); });
        } else Game.EmitSound("General.Cancel");
    }
    purpleButton.SetPanelEvent("onactivate",function(){ toggleShop("HopeShopToggle"); });
    greenButton.SetPanelEvent("onactivate",function(){ toggleShop("IslandShopToggle"); });
    function updateAltHints() {
        if (!root || !root.IsValid()) return;
        root.SetHasClass("ShowShopHints",GameUI.IsAltDown());
        $.Schedule(0.03,updateAltHints);
    }
    updateAltHints();
    $.Schedule(2.5,function(){ if(purpleButton&&purpleButton.IsValid()) purpleButton.RemoveClass("HudLoadIntro"); });
    $.Schedule(2.6,function(){ if(greenButton&&greenButton.IsValid()) greenButton.RemoveClass("HudLoadIntro"); });
    $.Schedule(3.7,function(){
        if(purpleButton&&purpleButton.IsValid()) purpleButton.RemoveClass("HudIntroAnimating");
        if(greenButton&&greenButton.IsValid()) greenButton.RemoveClass("HudIntroAnimating");
    });
    function sync(table,key,data) {
        if(String(key)!==String(Game.GetLocalPlayerID())) return;
        var label=table==="purple_currency" ? root.FindChildTraverse("PurpleMoney") :
            table==="pumpkin_currency" ? root.FindChildTraverse("GreenMoney") : null;
        if(label) label.text=String((data&&data.balance)||0);
    }
    CustomNetTables.SubscribeNetTableListener("purple_currency",sync);
    CustomNetTables.SubscribeNetTableListener("pumpkin_currency",sync);
    GameEvents.Subscribe("pumpkin_currency_changed",function(data){
        var label=root.FindChildTraverse("GreenMoney");
        if(label) label.text=String((data&&data.balance)||0);
    });
    var id=String(Game.GetLocalPlayerID());
    sync("purple_currency",id,CustomNetTables.GetTableValue("purple_currency",id));
    sync("pumpkin_currency",id,CustomNetTables.GetTableValue("pumpkin_currency",id));
})();
