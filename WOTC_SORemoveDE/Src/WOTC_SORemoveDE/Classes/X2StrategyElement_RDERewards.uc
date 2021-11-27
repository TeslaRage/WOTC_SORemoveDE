class X2StrategyElement_RDERewards extends X2StrategyElement_DefaultRewards;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Rewards;

	Rewards.AddItem(CreateRemoveDERewardTemplate());

	return Rewards;
}

static function X2DataTemplate CreateRemoveDERewardTemplate()
{
	local X2RewardTemplate Template;

	`CREATE_X2Reward_TEMPLATE(Template, 'Reward_RemoveDE');

    Template.GenerateRewardFn = GenerateRemoveDEReward;	
	Template.GiveRewardFn = GiveRemoveDEReward;
	Template.GetRewardStringFn = GetRemoveDERewardString;
	Template.CleanUpRewardFn = CleanUpDarkEventReward; // Thank you Xymanek!

	return Template;
}

static function GenerateRemoveDEReward(XComGameState_Reward RewardState, XComGameState NewGameState, optional float RewardScalar = 1.0, optional StateObjectReference DarkEventRef)
{
	RewardState.RewardObjectReference = DarkEventRef;
}

static function GiveRemoveDEReward(XComGameState NewGameState, XComGameState_Reward RewardState, optional StateObjectReference AuxRef, optional bool bOrder=false, optional int OrderHours=-1)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersAlien AlienHQ;
	local XComGameState_DarkEvent DarkEventState;
	local int idx;
		
	History = `XCOMHISTORY;
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	DarkEventState = XComGameState_DarkEvent(History.GetGameStateForObjectID(RewardState.RewardObjectReference.ObjectID));

	if (DarkEventState == none)
	{
		`LOG("X2StrategyElement_RDERewards::GiveRemoveDEReward: DarkEventState is None which will fail DE removal", class'X2EventListener_RemoveDE'.default.bLog, 'SORemoveDE');	
		`LOG("RewardState.RewardObjectReference.ObjectID: " $RewardState.RewardObjectReference.ObjectID, class'X2EventListener_RemoveDE'.default.bLog, 'SORemoveDE');
	}	
	
	for(idx = 0; idx < AlienHQ.ActiveDarkEvents.Length; idx++)
	{
		if(AlienHQ.ActiveDarkEvents[idx].ObjectID == DarkEventState.ObjectID)
		{
			AlienHQ.ActiveDarkEvents.Remove(idx, 1);			
            break;
		}
	}

	DarkEventState = XComGameState_DarkEvent(NewGameState.ModifyStateObject(class'XComGameState_DarkEvent', DarkEventState.ObjectID));
	DarkEventState.OnDeactivated(NewGameState);
}

static function string GetRemoveDERewardString(XComGameState_Reward RewardState)
{
	local XComGameState_DarkEvent DarkEventState;
    
    DarkEventState = XComGameState_DarkEvent(`XCOMHISTORY.GetGameStateForObjectID(RewardState.RewardObjectReference.ObjectID));

    return RewardState.GetMyTemplate().DisplayName @"'" $DarkEventState.GetMyTemplate().DisplayName $"'";
}

static protected function CleanUpDarkEventReward(XComGameState NewGameState, XComGameState_Reward RewardState)
{
	// Do literary nothing. Literary.

	// This callback prevents the default behaviour of removing RewardState.RewardObjectReference.ObjectID
	// which in this case is XCGS_DE which are supposed to live the entire campaign
}