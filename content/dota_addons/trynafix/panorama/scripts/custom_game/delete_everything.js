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

// Ability Draft removes every hero-specific talent because those bonuses refer
// to spells the hero may no longer own. Keep the unusable native talent button
// and its drawer out of the HUD as well. The native HUD can recreate these
// panels when the selected/query unit changes, so enforce this periodically.
function HideDraftTalentUI()
{
    CollapseDotaHudElement("StatBranch");
    CollapseDotaHudElement("StatBranchDrawer");
    CollapseDotaHudElement("StatBranchContainer");
    $.Schedule(1.0, HideDraftTalentUI);
}
HideDraftTalentUI();
