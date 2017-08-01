/*
	Simple Plugin to tell a user where another user is connected from
	usage:
		sm_location <name|#userid> -- Gets a single player's locaton
		sm_locations -- Gets everyones' location
		
	By: The-/<iller
	www.RightToRule.com
	aim/xfire:rtrkiller
	
	Changelog:
	0.1 > First Version
	0.2 > Update for new GeoIP functions, NEED >r1300
	0.3 > Fixed running cmds through rcon, added respond with server ip for bots
	0.4 > added connect annouce and prevent it from crashing server when a player 
		disconnects while entering (NOT RELEASED)
	0.5 > Menus added	
	
	Things to come:
	Make Suggestions
*/


#include <sourcemod>
#include <geoip>

#pragma semicolon 1
#pragma newdecls required

//char NetIP[32];
ConVar g_Cvar_LocationInMenu;
#define PLUGIN_VERSION "0.5"

public Plugin myinfo =
{
	name = "Get Location",
	author = "The-Killer",
	description = "Retrives geoip locations and displays to console",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	//maxplayers = GetMaxClients();
	RegConsoleCmd("sm_location", Command_Location);
	RegConsoleCmd("sm_locations", Command_Locations);
	CreateConVar("sm_getlocation_version", PLUGIN_VERSION, "Get Location Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_Cvar_LocationInMenu = CreateConVar("sm_getlocation_inmenu","0", "Display Locations in 1)menu[Default] or 0)console", FCVAR_SPONLY, true, 0.0, true, 1.0);

	//Get Server ip for bots location
/*
	new pieces[4];
	new longip = GetConVarInt(FindConVar("hostip"));
	
	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;

	Format(NetIP, sizeof(NetIP), "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]);
*/
}

public Action Command_Location(int client, int args)
{
	//Check for empty command and provide usage if needed
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_location <name|#userid>");
		return Plugin_Handled;	
	}
	
	//Get our target
	char Player[64];
	GetCmdArg(1, Player, sizeof(Player));
	
	bool isml;
	int clients[MAXPLAYERS+1];
	char foundClients[MAX_TARGET_LENGTH];
	int NumClients = ProcessTargetString(Player, client, clients, MAXPLAYERS+1, COMMAND_FILTER_NO_BOTS, foundClients, sizeof(foundClients), isml);

	if (NumClients < 1)
	{
		ReplyToTargetError(client, NumClients);
		return Plugin_Handled;
	}

	int FoundPlayer;
	for (int nc = 0; nc < NumClients; nc++)
	{
		FoundPlayer = clients[nc];

		if (IsFakeClient(FoundPlayer))
			continue;

		char ip[24];
		char country[48];

		//Get Return/GeoIP Data
		GetClientIP(FoundPlayer, ip,  sizeof(ip));
		if (strncmp(ip, "10.", 3) == 0 || strncmp(ip, "192.168.", 8) == 0)
			Format(country, sizeof(country), "Slovakia");
		else
			GeoipCountry(ip, country, sizeof(country));
		
		//Tell them where the target client is connected from
		if (client == 0)
			PrintToServer("%N is connected from %s", FoundPlayer, country);
		else
			PrintToConsole(client, "%N is connected from %s", FoundPlayer, country);
	}
	//Return normally
	return Plugin_Handled;	
}

public Action Command_Locations(int client, int args)
{
	//Declare GeoIP/Return data
	char ip[24];
	char country[48];

	if (!g_Cvar_LocationInMenu.BoolValue || client == 0)
	{
		if (client == 0) 
		{
			PrintToServer("Player locations list:");
		}
		else
		{
			//Tell them the requested info is in console
			PrintToChat(client, "Read Console for Info");
			
			//PrintToConsole(client, " ");
			PrintToConsole(client, "\nPlayer locations list:");
		}

		//Loop through all players and print out a list to the client
		for (int i = 1; i <= MaxClients; i++)
		{
			//Check for client connected
			if (!IsClientInGame(i))
				continue;
				
			if (IsFakeClient(i))
				continue;

			//Get Return/GeoIP Data
			GetClientIP(i, ip, sizeof(ip));
			if (strncmp(ip, "10.", 3) == 0 || strncmp(ip, "192.168.", 8) == 0)
				Format(country, sizeof(country), "Slovakia");
			else
				GeoipCountry(ip, country, sizeof(country));
				
			//Tell them where the target client is connected from
			if (client == 0) PrintToServer("%N is connected from %s", i, country);
			else PrintToConsole(client, "%N is connected from %s", i, country);
		}
	}
	else
	{
		//Declare Menu Junk
		Menu menu = new Menu(LocationsMenuHandler);
		char StrLoc[64];
		char place[10];
		
		menu.SetTitle("Player Locations List");
		//Loop through all players and print out a list to the client
		for (int i = 1; i <= MaxClients; i++)
		{
			//Check for client connected
			if (!IsClientInGame(i))
				continue;
	
			if (IsFakeClient(i))
				continue;

			//Get Return/GeoIP Data
			GetClientIP(i, ip, sizeof(ip));
			if (strncmp(ip, "10.", 3) == 0 || strncmp(ip, "192.168.", 8) == 0)
				Format(country, sizeof(country), "Slovakia");
			else
				GeoipCountry(ip, country, sizeof(country));

				
			//Tell them where the target client is connected from
			Format(StrLoc,sizeof(StrLoc), "%N       %s", i, country);
			IntToString(i, place, sizeof(place));
			menu.AddItem(place, StrLoc);
		}
		menu.ExitButton = true;
		menu.Display(client, 20);
	}
	
	//Return normally
	return Plugin_Handled;	
}

public int LocationsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{ 
	/* If the menu has ended, destroy it */
	if (action == MenuAction_End)
		delete menu;
}