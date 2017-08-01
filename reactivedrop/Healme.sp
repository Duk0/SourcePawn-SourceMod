#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#define PLUGIN_VERSION "0.3"
#include <swarmtools> 

public Plugin myinfo = 
{
    name = "[ASW] DeltaTimo's Healme",
    author = "DeltaTimo",
    description = "Allows Admins with CHEAT Flag to healme.",
    version = PLUGIN_VERSION,
    url = ""
}

public void OnPluginStart()
{
    //tank buster weapons menu cvar
	RegAdminCmd("healme", HealmeCmd, ADMFLAG_CHEATS);
	RegAdminCmd("cureinfection", CureInfectionCmd, ADMFLAG_CHEATS);
	RegAdminCmd("suicide", SuicideCmd, ADMFLAG_CHEATS);
    //plugin version
	CreateConVar("deltas_healme_version", PLUGIN_VERSION, "Tank_Buster_Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
}

public Action HealmeCmd(int client, int args)
{
	int marine = Swarm_GetMarine(client);
	if (marine == -1)
		return Plugin_Handled;

	Swarm_SetMarineHealth(marine, Swarm_GetMarineMaxHealth(marine));
	PrintToConsole(client, "You have been healed.");
	return Plugin_Handled;
}

public Action CureInfectionCmd(int client, int args)
{
	int marine = Swarm_GetMarine(client);
	if (marine == -1)
		return Plugin_Handled;

	if (Swarm_IsMarineInfested(marine))
		Swarm_CureMarineInfestation(marine);

	PrintToConsole(client, "You're infection has been cured.");
	return Plugin_Handled;
}

public Action SuicideCmd(int client, int args)
{
	int marine = Swarm_GetMarine(client);
	if (marine == -1)
		return Plugin_Handled;

	Swarm_ForceMarineSuicide(marine);
	PrintToConsole(client, "You're marine has commited suicide." );
	return Plugin_Handled;
}
