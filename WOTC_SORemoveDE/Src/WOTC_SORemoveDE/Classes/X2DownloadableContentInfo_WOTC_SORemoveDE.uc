class X2DownloadableContentInfo_WOTC_SORemoveDE extends X2DownloadableContentInfo;

static function OnPostTemplatesCreated()
{
    local X2StrategyElementTemplateManager StratTemplateManager;    
    local X2ActivityTemplate_CovertAction ActivityTemplate_CA;
    local X2CovertActionTemplate CovertActionTemplate;

    StratTemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();    
    ActivityTemplate_CA = X2ActivityTemplate_CovertAction(StratTemplateManager.FindStrategyElementTemplate('Activity_PrepCounterGHDE'));
    CovertActionTemplate = X2CovertActionTemplate(StratTemplateManager.FindStrategyElementTemplate('CovertAction_PrepareDark'));

    if (ActivityTemplate_CA != none && CovertActionTemplate != none)
    {
        CovertActionTemplate.Rewards.Length = 0;
        CovertActionTemplate.Rewards.AddItem('Reward_Progress');
        CovertActionTemplate.bForceCreation = false;
        CovertActionTemplate.bUseRewardImage = false;
        // Set this to minimal, but the chain has its own requirement for faction influence
        // See X2EventListener_RemoveDE::IsFactionInfluenceHighEnough
        CovertActionTemplate.RequiredFactionInfluence = eFactionInfluence_Minimal;

        CovertActionTemplate.Narratives.AddItem('CovertActionNarrative_PrepareDark');

        CovertActionTemplate.bCanNeverBeRookie = true;
        CovertActionTemplate.OverworldMeshPath = "UI_3D.Overwold_Final.CovertAction";

        ActivityTemplate_CA.CovertActionName = CovertActionTemplate.DataName;
    }    
}

exec function PrintActiveDarkEventNames()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersAlien AlienHQ;
	local StateObjectReference DarkEventRef;
	local XComGameState_DarkEvent DarkEventState;

	History = `XCOMHISTORY;
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));

	foreach AlienHQ.ActiveDarkEvents(DarkEventRef)
	{
		DarkEventState = XComGameState_DarkEvent(History.GetGameStateForObjectID(DarkEventRef.ObjectID));
		`LOG(DarkEventRef.ObjectID @DarkEventState.GetMyTemplateName(), true, 'SORemoveDE');
	}
}

exec function RemoveNoneDarkEvents()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersAlien AlienHQ;	
	local XComGameState_DarkEvent DarkEventState;
	local int i;

	History = `XCOMHISTORY;
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	
	for (i = 0; i < AlienHQ.ActiveDarkEvents.Length; i++)
	{
		DarkEventState = XComGameState_DarkEvent(History.GetGameStateForObjectID(AlienHQ.ActiveDarkEvents[i].ObjectID));
		
		if (DarkEventState == none)
		{
			AlienHQ.ActiveDarkEvents.Remove(i, 1);
			i--;
		}
	}
}

exec function PrintTacticalGameplayTags_TR()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local name TacticalTag;
	local string TagList;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	TagList = "\n-------------------------------------\nACTIVE TACTICAL TAGS:";

	foreach XComHQ.TacticalGameplayTags(TacticalTag)
	{
		TagList $= "\n" $ TacticalTag;
	}

	TagList $= "\n-------------------------------------\n";
	`LOG(TagList);
}