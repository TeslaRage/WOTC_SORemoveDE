class X2EventListener_RemoveDE extends X2EventListener config (RemoveDarkEvent);

var config bool bLog;
var config int ChainSpawnLimit;
var config array<name> arrBlacklistedDEs;
var config int DefaultMaxDurationDays;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateStrategyListeners());	

	return Templates;
}

static function CHEventListenerTemplate CreateStrategyListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'RemoveDarkEvent');

	Template.AddCHEvent('PostEndOfMonth', PostEndOfMonth, ELD_OnStateSubmitted, 99);
	Template.AddCHEvent('CovertAction_ModifyNarrativeParamTag', IncludeDarkEventName, ELD_Immediate, 98);
	Template.RegisterInStrategy = true;

	return Template;
}

static protected function EventListenerReturn PostEndOfMonth (Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Generate Chains for Active DE");
	SpawnRemoveDarkEvents(NewGameState);

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	return ELR_NoInterrupt;
}

static protected function EventListenerReturn IncludeDarkEventName (Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_CovertAction Action;
	local XGParamTag kTag;
	local XComGameState_ActivityChain ChainState;
	local XComGameState_Activity Activity;
	local XComGameState_DarkEvent DarkEvent;
	local StateObjectReference ChainRef, DarkEventRef;
	local XComGameStateHistory History;
	
	Action = XComGameState_CovertAction(EventSource);
	kTag = XGParamTag(EventData);
	if (Action == none || kTag == none) return ELR_NoInterrupt;	

	if (Action.GetMyTemplateName() != 'CovertAction_PrepareDark') return ELR_NoInterrupt;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_Activity', Activity)
	{		
		if (Activity.GetMyTemplateName() != 'Activity_PrepCounterGHDE') continue;
		if (Activity.PrimaryObjectRef != Action.GetReference()) continue;

		ChainRef = Activity.ChainRef;
		break;
	}

	ChainState = XComGameState_ActivityChain(History.GetGameStateForObjectID(ChainRef.ObjectID));
	if (ChainState == none) return ELR_NoInterrupt;

	foreach ChainState.ChainObjectRefs(DarkEventRef)
	{
		DarkEvent = XComGameState_DarkEvent(History.GetGameStateForObjectID(DarkEventRef.ObjectID));

		if (DarkEvent != none)
		{
			kTag.StrValue4 = DarkEvent.GetMyTemplate().DisplayName;
			break;
		}
	}	
	
	return ELR_NoInterrupt;
}

// 99% of this function is copied from XComGameState_ActivityChainSpawner::SpawnCounterDarkEvents
static function SpawnRemoveDarkEvents (XComGameState NewGameState)
{
	local X2StrategyElementTemplateManager TemplateManager;
	local XComGameState_HeadquartersAlien AlienHQ;
	
	local array<StateObjectReference> ChainObjectRefs;
	local XComGameState_DarkEvent DarkEventState;
	local StateObjectReference DarkEventRef, SelectedRegion;
	local array<StateObjectReference> DarkEventRefs, RegionRefs;

	local array<XComGameState_ActivityChain> SpawnedChains;
	local XComGameState_ActivityChain ChainState;
	local X2ActivityChainTemplate ChainTemplate;

	local int SecondsDelay, SecondsDuration, WindowDuration, SecondsChainDelay;
	local XComGameState_Activity_Wait WaitActivity;
	local int i;

	if (!IsFactionInfluenceHighEnough())
	{
		`LOG("No faction with high enough influence to Remove Dark Event. Aborting.", default.bLog, 'SORemoveDE');		
		return;
	}

	AlienHQ = class'UIUtilities_Strategy'.static.GetAlienHQ();
	TemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	ChainTemplate = X2ActivityChainTemplate(TemplateManager.FindStrategyElementTemplate('ActivityChain_CounterGHDE'));

	// Step 1: spawn the chains

	RegionRefs = class'XComGameState_ActivityChainSpawner'.static.GetContactedRegions();
	DarkEventRefs = AlienHQ.ActiveDarkEvents; //ChosenDarkEvents;

	`LOG("Initial Active Events:" @ DarkEventRefs.Length, default.bLog, 'SORemoveDE');	
	
	for (i = 0; i < DarkEventRefs.Length; i++)
	{
		DarkEventRef = DarkEventRefs[i];
		DarkEventState = XComGameState_DarkEvent(`XCOMHISTORY.GetGameStateForObjectID(DarkEventRef.ObjectID));
				
		`LOG("Evaluating:" @ DarkEventState.GetMyTemplateName(), default.bLog, 'SORemoveDE');

		if (DarkEventState == none)
		{
			DarkEventRefs.Remove(i, 1);
			i--;
			`LOG("Removed" @ DarkEventRef.ObjectID @ "DarkEventState is None", default.bLog, 'SORemoveDE');
			continue;
		}

		// // Chosen DEs cannot be removed
		// This might be too rough for a GH Lite mod considering the Chosen might have initiated e.g. Close Black Market
		// And player is nowhere near to defeating the chosen. GG.
		// if (DarkEventState.bChosenActionEvent)
		// {
		// 	DarkEventRefs.Remove(i, 1);
		// 	i--;
		// 	`LOG("Removed" @ DarkEventState.GetMyTemplateName() @ "because Chosen DE cannot be removed", default.bLog, 'SORemoveDE');
		// 	continue;
		// }

		if (DoesActiveRemoveDEChainExist('ActivityChain_CounterGHDE', DarkEventRef))
		{
            DarkEventRefs.Remove(i, 1);
			i--;
			`LOG("Removed" @ DarkEventState.GetMyTemplateName() @ "because an existing Remove DE chain for the same dark event exists", default.bLog, 'SORemoveDE');			
			continue;
		}

		if (IsModLoaded('GrimHorizonFix'))
		{
			if (class'GrimHorizonFix_HeadquartersAlien'.default.ExcludedDarkEvents.Find(DarkEventState.GetMyTemplateName()) != INDEX_NONE)
			{
				DarkEventRefs.Remove(i, 1);
				i--;
				`LOG("Removed" @ DarkEventState.GetMyTemplateName() @ "because according to Grim Horizon Fix, its not a permanent event", default.bLog, 'SORemoveDE');				
				continue;
			}
		}		
		
		if (class'X2StrategyGameRulesetDataStructures'.static.DifferenceInDays(`STRATEGYRULES.GameTime, DarkEventState.StartDateTime) < DarkEventState.GetMyTemplate().MaxDurationDays 
				&& DarkEventState.GetMyTemplate().MaxDurationDays > 0)
		{			
			DarkEventRefs.Remove(i, 1);
			i--;
			`LOG("Removed" @ DarkEventState.GetMyTemplateName() @ "because we want the player to suffer for a bit before allowing deactivation via chain", default.bLog, 'SORemoveDE');				
			continue;
		}
		else if (class'X2StrategyGameRulesetDataStructures'.static.DifferenceInDays(`STRATEGYRULES.GameTime, DarkEventState.StartDateTime) < default.DefaultMaxDurationDays)
		{
			DarkEventRefs.Remove(i, 1);
			i--;
			`LOG("Removed" @ DarkEventState.GetMyTemplateName() @ "because we want the player to suffer for a bit before allowing deactivation via chain (0 MaxDurationDays)", default.bLog, 'SORemoveDE');				
			continue;
		}
		
		`LOG("Cleared:" @ DarkEventState.GetMyTemplateName(), default.bLog, 'SORemoveDE');		
	}
	
	`LOG("Loop Begins!", default.bLog, 'SORemoveDE');
		
	while (DarkEventRefs.Length > 0 && RegionRefs.Length > 0 && SpawnedChains.Length < default.ChainSpawnLimit)
	{
		`LOG("Regions:" @ RegionRefs.Length, default.bLog, 'SORemoveDE');
		`LOG("Events:" @ DarkEventRefs.Length, default.bLog, 'SORemoveDE');
		`LOG("Spawns:" @ SpawnedChains.Length, default.bLog, 'SORemoveDE');		

		DarkEventRef = DarkEventRefs[`SYNC_RAND_STATIC(DarkEventRefs.Length)];
		DarkEventRefs.RemoveItem(DarkEventRef);

		DarkEventState = XComGameState_DarkEvent(`XCOMHISTORY.GetGameStateForObjectID(DarkEventRef.ObjectID));
				
		`LOG("Spawning:" @ DarkEventState.GetMyTemplateName(), default.bLog, 'SORemoveDE');	

		ChainObjectRefs.Length = 0;
		ChainObjectRefs.AddItem(DarkEventRef);

		SelectedRegion = RegionRefs[`SYNC_RAND_STATIC(RegionRefs.Length)];
		RegionRefs.RemoveItem(SelectedRegion);

		if (default.arrBlacklistedDEs.Find(DarkEventState.GetMyTemplateName()) == INDEX_NONE)
		{
			ChainState = ChainTemplate.CreateInstanceFromTemplate(NewGameState, ChainObjectRefs);
			ChainState.PrimaryRegionRef = SelectedRegion;
			ChainState.SecondaryRegionRef = SelectedRegion;
			ChainState.StartNextStage(NewGameState);
			
			SpawnedChains.AddItem(ChainState);
		}
		else
		{
			// Doing this here so that you cannot cheese: Put in the ignore list all the DE you don't want to remove right now, and you'll be guaranteed to get the option to remove the ones you do
			// This feature is meant as convenience instead of having too many chains you going to ignore anyway
			`LOG(DarkEventState.GetMyTemplateName() @ "is in the pool but blacklisted from having a chain", default.bLog, 'SORemoveDE');	
		}
	}
	
	`LOG("Regions:" @ RegionRefs.Length, default.bLog, 'SORemoveDE');
	`LOG("Events:" @ DarkEventRefs.Length, default.bLog, 'SORemoveDE');
	`LOG("Spawns:" @ SpawnedChains.Length, default.bLog, 'SORemoveDE');
	
	`LOG("Loop Broken!", default.bLog, 'SORemoveDE');	

	// If we didn't manage to make any chains, don't bother with the timing
	if (SpawnedChains.Length == 0) return;

	// Step 2: spread them randomly over the beginning of the month

	GetCounterDarkEventPeriodStartAndDuration(SecondsDelay, SecondsDuration);
	WindowDuration = SecondsDuration / SpawnedChains.Length;
	SpawnedChains = SortChainsRandomly(SpawnedChains);

	foreach SpawnedChains(ChainState, i)
	{
		WaitActivity = XComGameState_Activity_Wait(ChainState.GetActivityAtIndex(0));
		// No need to call NewGameState.ModifyStateObject here as the object was just created above

		if (WaitActivity == none)
		{
			`RedScreen("SORemoveDE: Remove DE chain should start with XComGameState_Activity_Wait so that it can be delayed by the spawner");
			continue;
		}

		SecondsChainDelay =
			SecondsDelay + // The global delay for all counter DE chains
			i * WindowDuration + // Account for previous chains
			`SYNC_RAND_STATIC(WindowDuration); // Pop somewhere randomly within our window

		WaitActivity.ProgressAt = `STRATEGYRULES.GameTime;
		class'X2StrategyGameRulesetDataStructures'.static.AddTime(WaitActivity.ProgressAt, SecondsChainDelay);
	}
}

// Copied from XComGameState_ActivityChainSpawner::GetCounterDarkEventPeriodStartAndDuration because the original function is protected.
static function GetCounterDarkEventPeriodStartAndDuration (out int SecondsDelay, out int SecondsDuration)
{
	local int Min, Max;

	Min = class'X2StrategyElement_DefaultActivities'.default.MinDarkEventWaitDays;
	Max = class'X2StrategyElement_DefaultActivities'.default.MaxDarkEventWaitDays;

	// Make sure that the values are sensible
	if (Min < 0) Min = 0;
	if (Max < Min) Max = Min; // This will probably won't work properly -.-

	// Convert to seconds
	Min *= 86400;
	Max *= 86400;

	// Return
	SecondsDelay = Min;
	SecondsDuration = Max - Min;
}

// Copied from XComGameState_ActivityChainSpawner::SortChainsRandomly because the original function is protected.
static function array<XComGameState_ActivityChain> SortChainsRandomly (array<XComGameState_ActivityChain> Chains)
{
	local array<XComGameState_ActivityChain> Result;
	local XComGameState_ActivityChain Chain;

	while (Chains.Length > 0)
	{
		Chain = Chains[`SYNC_RAND_STATIC(Chains.Length)];

		Chains.RemoveItem(Chain);
		Result.AddItem(Chain);
	}

	return Result;
}

// Copied and repurposed from X2StrategyElement_DefaultActivityChains::DoesActiveChainExist
static function bool DoesActiveRemoveDEChainExist (name TemplateName, StateObjectReference DarkEventRef)
{
	local XComGameState_ActivityChain ChainState;
	local StateObjectReference Ref;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_ActivityChain', ChainState)
	{		
		if (ChainState.GetMyTemplateName() == TemplateName && !ChainState.bEnded)
		{
			foreach ChainState.ChainObjectRefs(Ref)
			{
				if (Ref.ObjectID == DarkEventRef.ObjectID) return true;
			}			
		}
	}

	return false;
}

static function bool IsModLoaded(name DLCName)
{
    local XComOnlineEventMgr    EventManager;
    local int                   Index;

    EventManager = `ONLINEEVENTMGR;

    for(Index = EventManager.GetNumDLC() - 1; Index >= 0; Index--)  
    {
        if(EventManager.GetDLCNames(Index) == DLCName)  
        {
            return true;
        }
    }
    return false;
}

static function bool IsFactionInfluenceHighEnough()
{
	local XComGameState_ResistanceFaction FactionState;	

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_ResistanceFaction', FactionState)
	{
		if (FactionState.bMetXCom && FactionState.GetInfluence() >= class'X2StrategyElement_RDEActivityChains'.default.INFLUENCE_LEVEL)
		{			
			return true;		
		}
	}
	
	return false;
}