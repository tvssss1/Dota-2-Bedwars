function GetDotaHud()
{
    let hPanel = $.GetContextPanel();

    while ( hPanel && hPanel.id !== 'Hud')
    {
        hPanel = hPanel.GetParent();
    }

    if (!hPanel)
    {
        throw new Error('Could not find Hud root from panel with id: ' + $.GetContextPanel().id);
    }

    return hPanel;
}

function FindDotaHudElement(sId)
{
    return GetDotaHud().FindChildTraverse(sId);
}
function CollapseDotaHudElement(sId)
{
    const panel = FindDotaHudElement(sId);
    if (panel)
    {
        panel.style.visibility = "collapse";
    }
}
CollapseDotaHudElement("StickyItemSlotContainer");
CollapseDotaHudElement("inventory_tpscroll_container");
