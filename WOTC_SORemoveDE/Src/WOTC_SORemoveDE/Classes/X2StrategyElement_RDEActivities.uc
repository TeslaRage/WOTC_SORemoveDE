class X2StrategyElement_RDEActivities extends X2StrategyElement_DefaultActivities;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
		
	CreateActivity_PrepCounterGHDE(Templates);

	return Templates;
}

static function CreateActivity_PrepCounterGHDE (out array<X2DataTemplate> Templates)
{
	local X2ActivityTemplate_CovertAction Activity;	
	
	`CREATE_X2TEMPLATE(class'X2ActivityTemplate_CovertAction', Activity, 'Activity_PrepCounterGHDE');
	
	Activity.AvailableSound = "Geoscape_NewResistOpsMissions";
	
	Templates.AddItem(Activity);
}