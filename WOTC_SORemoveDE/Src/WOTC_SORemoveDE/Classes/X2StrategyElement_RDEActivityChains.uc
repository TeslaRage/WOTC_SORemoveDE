class X2StrategyElement_RDEActivityChains extends X2StrategyElement_DefaultActivityChains config (RemoveDarkEvent);

var config EFactionInfluence INFLUENCE_LEVEL;

var localized string strRemoveDarkEventDescription;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Activites;	
	
	Activites.AddItem(CreateCounterGHDETemplate());	

	return Activites;
}

static function X2DataTemplate CreateCounterGHDETemplate()
{
	local X2ActivityChainTemplate Template;

	`CREATE_X2TEMPLATE(class'X2ActivityChainTemplate', Template, 'ActivityChain_CounterGHDE');
	
	Template.ChooseFaction = ChooseFactionBasedOnInfluence;
	Template.ChooseRegions = ChooseRandomContactedRegion;
	Template.SpawnInDeck = false;
	Template.NumInDeck = 1;
	Template.DeckReq = UseCustomSpawn;	
	Template.ChainRewards.AddItem('Reward_RemoveDE');

	Template.Stages.AddItem(ConstructPresetStage('Activity_WaitDarkEvent'));
	Template.Stages.AddItem(ConstructPresetStage('Activity_PrepCounterGHDE'));
	Template.Stages.AddItem(ConstructPresetStage('Activity_WaitGeneric'));	
	Template.Stages.AddItem(ConstructRandomStage('eActivityType_Infiltration', 'Tag_Sabotage',,, 'Reward_ChainProxy'));
	
	Template.GetOverviewDescription = RemoveDarkEventGetOverviewDescription;
	Template.GetNarrativeObjective = GetDarkEventObjective;
	Template.GenerateChainRewards = RDEGenerateChainRewards;	

	return Template;
}

static function bool UseCustomSpawn (XComGameState NewGameState)
{
	return false;
}

static function string RemoveDarkEventGetOverviewDescription (XComGameState_ActivityChain ChainState)
{
	local XComGameState_DarkEvent DarkEventState;
	local XGParamTag kTag;
	local StateObjectReference DarkEventRef;	

	foreach ChainState.ChainObjectRefs(DarkEventRef)
	{
		DarkEventState = XComGameState_DarkEvent(`XCOMHISTORY.GetGameStateForObjectID(DarkEventRef.ObjectID));
		if (DarkEventState != none)
		{
			break;
		}
	}

	`LOG("Chain is related to Dark Event: " $ DarkEventState.GetDisplayName(), class'X2EventListener_RemoveDE'.default.bLog, 'SORemoveDE');	

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = DarkEventState.GetDisplayName();

	return `XEXPAND.ExpandString(default.strRemoveDarkEventDescription);
}

// Copied and repurposed from X2ActivityChainTemplate::DefaultGenerateChainRewards
static function array<StateObjectReference> RDEGenerateChainRewards (XComGameState_ActivityChain ChainState, XComGameState NewGameState)
{
	local X2StrategyElementTemplateManager TemplateManager;
	local XComGameState_HeadquartersResistance ResHQ;
	local array<StateObjectReference> RewardRefs;
	local XComGameState_Reward RewardState;
	local X2RewardTemplate RewardTemplate;
	local name ChainReward;

	`LOG("Starting RDEGenerateChainRewards", class'X2EventListener_RemoveDE'.default.bLog, 'SORemoveDE');	

	ResHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
	TemplateManager = ChainState.GetMyTemplateManager();

	foreach ChainState.GetMyTemplate().ChainRewards(ChainReward)
	{		
		`LOG("Template has chain reward: " $ ChainReward, class'X2EventListener_RemoveDE'.default.bLog, 'SORemoveDE');
		RewardTemplate = X2RewardTemplate(TemplateManager.FindStrategyElementTemplate(ChainReward));

		if (RewardTemplate != none)
		{
			RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
			// RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), ChainState.PrimaryRegionRef); // TeslaRage Remove
			// At this point there should only be one item in ChainObjectRefs which is the DarkEventRef. See ChainObjectRefs in X2EventListener_RemoveDE
			RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), ChainState.ChainObjectRefs[0]); // TeslaRage Add
			RewardRefs.AddItem(RewardState.GetReference());
			ChainState.ChainObjectRefs.AddItem(RewardState.GetReference()); // TeslaRage Add
			`LOG("Generated chain reward: " $ ChainReward, class'X2EventListener_RemoveDE'.default.bLog, 'SORemoveDE');			
		}
	}
	
	return RewardRefs;
}

static function StateObjectReference ChooseFactionBasedOnInfluence (XComGameState_ActivityChain ChainState, XComGameState NewGameState)
{
	local XComGameState_ResistanceFaction FactionState;
	local array<StateObjectReference> FactionRefs;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_ResistanceFaction', FactionState)
	{
		if (FactionState.bMetXCom && FactionState.GetInfluence() >= default.INFLUENCE_LEVEL)
		{
			FactionRefs.AddItem(FactionState.GetReference());
		}
	}

	return FactionRefs[`SYNC_RAND_STATIC(FactionRefs.Length)];
}