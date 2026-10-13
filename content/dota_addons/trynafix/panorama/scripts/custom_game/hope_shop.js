var HopeShop = {};
(function () {
    "use strict";
    var panel=$.GetContextPanel(), playerID=Game.GetLocalPlayerID(), modal, catalog, context, balance=0, focusCycle=0;
    var order=["tower","recall","raid","repair","shield","generator_refill"];
    function L(token){ return $.Localize(token,panel); }
    function sound(name){ Game.EmitSound(name); }
    function ensureVisibleHost(){
        panel.visible=true; panel.style.visibility="visible";
        var host=panel.GetParent();
        if(host){ host.visible=true; host.style.visibility="visible"; }
    }
    function updateBalance(data){
        balance=data && data.balance!==undefined ? Number(data.balance) : 0;
        panel.FindChildTraverse("HopeModalBalance").text=L("#hope_shop_balance")+" - "+balance;
    }
    function onCurrency(table,key,data){ if(table==="purple_currency" && String(key)===String(playerID)) updateBalance(data); }
    function build(){
        catalog=panel.FindChildTraverse("HopeCatalog"); catalog.RemoveAndDeleteChildren();
        order.forEach(function(id){
            var e=CustomNetTables.GetTableValue("hope_shop_catalog",id); if(!e) return;
            var row=$.CreatePanel("Panel",catalog,"Entry_"+id); row.AddClass("ShopEntry");
            var customIcon=String(e.icon).indexOf("file://")===0;
            var icon=$.CreatePanel(customIcon?"Image":"DOTAItemImage",row,""); icon.AddClass("EntryIcon");
            icon.AddClass("EntryIcon_"+id);
            if(customIcon) icon.SetImage(e.icon); else icon.itemname=e.icon;
            var info=$.CreatePanel("Panel",row,""); info.AddClass("EntryInfo");
            var name=$.CreatePanel("Label",info,""); name.AddClass("EntryName"); name.text=L(e.name);
            var desc=$.CreatePanel("Label",info,""); desc.AddClass("EntryDesc"); desc.text=L(e.description);
            var buy=$.CreatePanel("Button",row,""); buy.AddClass("BuyButton"); buy.enabled=true; buy.SetPanelEvent("onactivate",function(){ sound("ui_generic_button_click"); buy.enabled=false; GameEvents.SendCustomGameEventToServer("hope_shop_purchase",{entry_id:id}); });
            var price=$.CreatePanel("Label",buy,""); price.text=L("#hope_shop_buy")+" — "+e.price;
        });
    }
    function applyContext(data){
        context=data||{}; updateBalance(data);
        var status=L(context.can_checkout?"#hope_shop_near_bed":"#hope_shop_no_bed");
        if(context.generator_remaining!==undefined){
            status+="  •  "+L("#hope_shop_generator_status")+" "+Number(context.generator_remaining)+"/"+Number(context.generator_capacity||6000);
        }
        panel.FindChildTraverse("HopeContext").text=status; build();
    }
    function onResult(data){
        applyContext(data); var result=panel.FindChildTraverse("HopeResult");
        result.SetHasClass("Success",!!data.success); result.text=L("#hope_shop_result_"+(data.code||"delivery_failed"));
        if(!data.success) GameEvents.SendEventClientSide("dota_hud_error_message",{splitscreenplayer:0,reason:"",message:result.text});
        sound(data.success?"ui_shop_buy":"General.Cancel");
    }
    function maintainModalFocus(cycle){
        if(cycle!==focusCycle || !modal || !modal.IsValid() || modal.BHasClass("Hidden")) return;
        modal.SetFocus();
        $.Schedule(0.1,function(){ maintainModalFocus(cycle); });
    }
    function toggle(){
        modal=panel.FindChildTraverse("HopeShopModal"); var opening=modal.BHasClass("Hidden");
        var config=GameUI.CustomUIConfig();
        if(opening && config.ActiveCustomShop && config.ActiveCustomShop!=="home"){
            sound("General.Cancel");
            return;
        }
        ensureVisibleHost();
        modal.visible=true; modal.style.visibility="visible";
        modal.SetHasClass("Hidden",!opening);
        focusCycle++;
        sound("ui_generic_button_click");
        modal.hittest=false; modal.hittestchildren=opening;
        if(opening) config.ActiveCustomShop="home";
        else if(config.ActiveCustomShop==="home") config.ActiveCustomShop=null;
        if(opening){ modal.SetFocus(); (function(cycle){ $.Schedule(0.1,function(){ maintainModalFocus(cycle); }); })(focusCycle); panel.FindChildTraverse("HopeResult").text=""; panel.FindChildTraverse("HopeContext").text=L("#hope_shop_checking"); GameEvents.SendCustomGameEventToServer("hope_shop_request_context",{}); }
    }
    function closeFromCancel(){
        modal=panel.FindChildTraverse("HopeShopModal");
        if(!modal.BHasClass("Hidden")) toggle();
    }
    HopeShop.Close=closeFromCancel;
    panel.HopeShopToggle=toggle;
    GameUI.CustomUIConfig().HopeShopToggle=toggle;
    CustomNetTables.SubscribeNetTableListener("purple_currency",onCurrency);
    GameEvents.Subscribe("hope_shop_context",applyContext); GameEvents.Subscribe("hope_shop_result",onResult);
    updateBalance(CustomNetTables.GetTableValue("purple_currency",String(playerID)));
    ensureVisibleHost();
    modal=panel.FindChildTraverse("HopeShopModal"); modal.visible=true; modal.hittest=false; modal.hittestchildren=false;
    HopeShop.Toggle=toggle;
})();
