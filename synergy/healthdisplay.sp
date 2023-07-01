
/********************************************
* 
* Health Display Version "2.12.45"
* 
*********************************************
* Description:
*********************************************
* Shows the health of an entity (as HUD text or in the Hintbox). Highly customizable. Supports multi tanks in L4D. Works for all games/mods (if not tell me and I'll add suport).
* 
*********************************************
* INSTALLATION & UPDATE:
*********************************************
*     - Installation:
*         - Download sfPlayers config extension (get the newest version here: https://forums.alliedmods.net/showthread.php?t=69167 )
*         - Unzip the file into your main mod folder (there where the other folders are, like: addons, bin, cfg, maps...)
*         - Go to the config file and check the settings: addons/sourcemod/configs/healthdisplay.conf
*         - Done.
* 
*     - Update:
*         - IF YOU UPDATE THIS PLUGING BE SURE TO DELETE THE OLD 'cfg/sourcemod/shownpchp.cfg' or 'addons/sourcemod/configs/healthdisplay.conf'	
*         - Check if the Config extension is uptodate (see/get the newest version here: https://forums.alliedmods.net/showthread.php?t=69167 )
*         - Restart the map or the server and look into the console or error log files for errors.
*         - Done.
* 
*     - Update from older Versions (1.3.13 and older):
*         - Delete <modfolder>/addons/sourcemod/plugins/shownpchp.smx
*         - Delete <modfolder>/cfg/sourcemod/shownpchp.cfg
*         - Continue by 'Update' see above...
* 
*********************************************
* Health Display Config Vars: 
*********************************************
* Note: These are named the same as the Server Console Variables (cvars) ingame.
* 
* Main console variable to enable or disable Health Display:
* Possible settings are: false=Disable Health Display, true=Enable Health Display).
sm_healthdisplay_enable = true;
*
* Where do you want to display the health info: 
* Possible is: 0=Choose Automaticly, 1=Force Hud Text (HL2DM/SourceForts), 2=Force Hint Text (CSS/L4D), 3=Force Center Text
sm_healthdisplay_hud = 0;
*
* Adds a delay, in seconds, for the menu. This means the menu will be showen after X seconds after the player spawned.
* Possible range of seconds is: 0.0 and above.
sm_healthdisplay_menu_pre_delay = 2.0;
*
* This saves the player decision if he wants to display the health of others or not.
* Possible settings are: false=players decisions will not be saved, true=players decisions will be saved.
sm_healthdisplay_save_player_setting = true;
* 
* This forces the players to have Health Display on. No menu will be showed unless the player tiggers the menu via chat comamnd: '/hpmenu'.
* Possible settings are : false=players will be asked to enable disable Health Display. true=players will not be asked.
sm_healthdisplay_force_player_on = false;
* 
* 
*********************************************
* With the following console variables you can change what the display should show:
*********************************************
* 
* Possible settings are: true=Show enemy players, false=Hide enemy players.
sm_healthdisplay_show_enemyplayers = true;
*
* Possible settings are: true=Show friendly players, false=Hide friendly players.
sm_healthdisplay_show_teammates = false;
*
* Possible settings are: true=Show NPCs (Non Player Character), false=Hide NPCs (Non Player Character).
sm_healthdisplay_show_npcs = true;
*
* 
*********************************************
* Changelog:
*********************************************
* v2.12.45 - Rewrited to use new declarations
*          - Added: NPC relationship recognition for Synergy
*
* v2.11.45 - Fixed: Issues showing players dead, when healed.
*
* v2.11.44 - Fixed: [L4D(2)] Issues with [L4D & L4D2] MultiTanks (version 1.5).
*
* v2.11.43 - Fixed: [L4D(2)] Tanks showing "(DEAD)", even when alive or just spawned.
*
* v2.10.41 - Added: Temp health in L4D to the normal health. Thank you DieTeetasse I used your code from an snippet.
* 
* v2.9.40 - Added: 3 new settings/cvars: sm_healthdisplay_menu_pre_delay, sm_healthdisplay_save_player_setting, sm_healthdisplay_force_player_on.
*         - Fixed: Some problems with the menu and hintbox (the example was overwritten).
* 
* v2.6.34 - Fixed: When the player decided to show Health Display then he won't be asked again unless he entered the trigger in to chat or console.
*         - Fixed: When "sm_healthdisplay_show_enemyplayers" is "false" the team mates health won't be showen, even when "sm_healthdisplay_show_teammates" is set to "true".
*         - Removed: sm_healthdisplay_show_entities within all config files (post & zip-file).
* 
* v2.6.30 - Added: Force Center Text option for sm_healthdisplay_hud, its 3.
* 
* v2.5.28 - Fixed: Doesn't show health trough invisible walls.
*         - Removed: sm_healthdisplay_show_entities, since it's useless.
*         - Fixed: sm_healthdisplay_show_npcs did the wrong thing.
* 
* v2.5.25 - Renamed this plugin from Show NPC HP into Show Health (this includes all cvars aswell).
*         - Fixed: [L4D2] Tank health wrong when it dies.
*         - Added: Config extension (sfPlayer) support. (new config file is at addons/sourcemod/configs/healthdisplay.conf)
*         - Added: m_healthdisplay_show_enemyplayers, m_healthdisplay_show_teammates, m_healthdisplay_show_npcs, m_healthdisplay_show_entities
* 
* v1.3.13 - Fixed: A small bug with the HudMessages.
* 
* v1.3.12 - Added: Support for L4D2 and other games.
*         - Added: Automated usage of ShowHudText or PrintHintText last is prefered by this plugin
*         - Added: Relationship Suppot, this means you can see if a NPC or Player is Friend or Foe.
* 
* v1.1.2  - First char in name is now upper case
* 
* v1.1.1  - Small bugfix for player health
* 
* v1.1.0  - First Public Release
* 
* 
* Thank you Berni, Manni, Mannis FUN House Community and SourceMod/AlliedModders-Team
* Thank you DieTeetasse for the L4D temp health snippet.
* 
* *************************************************/

/****************************************************************
P R E C O M P I L E R   D E F I N I T I O N S
*****************************************************************/

// enforce semicolons after each code statement
#pragma semicolon 1
#pragma newdecls required

/****************************************************************
I N C L U D E S
*****************************************************************/

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <syntools>

/****************************************************************
P L U G I N   C O N S T A N T S
*****************************************************************/

#define PLUGIN_VERSION 				"2.12.45"
#define HUD_INTERVALL 				0.02

#define MAX_SHOWSTRING_LENGTH 		128
#define MAX_RELATIONSHIP_LENGTH 	64
#define MAX_HEALTH_LENGTH 			32
#define MAX_CLASSNAME_LENGTH		32
#define MAX_ENTITIES 				2048
#define MAX_RELATIONSHIPS 			256

#define MAX_HEALTH_VALUE			999999999

#define TRACE_FILTER				(MASK_SHOT)

#define HINTBOX_BLANK				"."

#define REPORT_DEAD 				"DEAD"
#define REPORT_DESTROYED 			"DESTROYED"
#define RELATIONSHIP_NONE 			"None"
#define RELATIONSHIP_ENEMY 			"Enemy"
#define RELATIONSHIP_FRIEND 		"Friend"
#define RELATIONSHIP_NEUTRAL 		"Neutral"
#define UNKNOWN						"Unknown"

/*****************************************************************
P L U G I N   I N F O
*****************************************************************/

public Plugin myinfo = 
{
	name = "Health Display",
	author = "Chanz, Duko",
	description = "Shows the Health Points of Players, NPCs and other entities with health (ex. bearkables)",
	version = PLUGIN_VERSION,
	url = "www.mannisfunhouse.eu / https://forums.alliedmods.net/showthread.php?p=1108211"
};

/*****************************************************************
G L O B A L   V A R S
*****************************************************************/
//convars
ConVar g_cvar_version;
ConVar g_cvar_enable;
ConVar g_cvar_show_teammates;
//ConVar g_cvar_show_enemyplayers;
ConVar g_cvar_show_npcs;
ConVar g_cvar_hud;
ConVar g_cvar_menu_delay;
ConVar g_cvar_save_player;
ConVar g_cvar_force_player_on;

/*
int g_iOldHealth[MAX_ENTITIES] = {MAX_HEALTH_VALUE, ...};;
*/
bool g_bClearedDisplay[MAXPLAYERS+1] = {false, ...};
bool g_bDontOverRideHealthDisplay[MAXPLAYERS+1] = {false, ...};
float g_iUpdateHintTimeout[MAXPLAYERS+1];
char g_szOldShowString[MAXPLAYERS+1][MAX_SHOWSTRING_LENGTH];


//Client Settings:
Handle cookie_Enable				= INVALID_HANDLE;
Handle cookie_AskedForEnable		= INVALID_HANDLE;

bool g_bAskedForEnable[MAXPLAYERS+1] = {false,...};
bool g_bClientShowDisplay[MAXPLAYERS+1] = {true,...};

float g_flHudXPosition = -1.0;
float g_flHudYPosition = 0.55;

enum Colors
{
	Red,
	Green,
	Yellow,
	White
}

/*****************************************************************
F O R W A R D   P U B L I C S
*****************************************************************/

public void OnPluginStart()
{	
	//Cvars:
	g_cvar_version = CreateConVar("sm_healthdisplay_version", PLUGIN_VERSION, "Health Display Version", FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_cvar_enable = CreateConVar("sm_healthdisplay_enable", "1", "0=Disable Show NPC HP, 1=Enable Show NPC HP)");
	g_cvar_show_teammates = CreateConVar("sm_healthdisplay_show_teammates", "0");
//	g_cvar_show_enemyplayers = CreateConVar("sm_healthdisplay_show_enemyplayers", "1");
	g_cvar_show_npcs = CreateConVar("sm_healthdisplay_show_npcs", "1");
	g_cvar_hud = CreateConVar("sm_healthdisplay_hud", "1", "Where do you want to display the health info: 0=Choose Automaticly, 1=Force Hud Text (HL2DM/SourceForts), 2=Force Hint Text (CSS/L4D), 3=Force Center Text");
	g_cvar_menu_delay = CreateConVar("sm_healthdisplay_menu_pre_delay", "10.0", "Adds a delay for the menu. This means the menu will be showen after X seconds after the player spawned.");
	g_cvar_save_player = CreateConVar("sm_healthdisplay_save_player_setting", "1", "This saves the player decision if he wants to display the health of others or not.");
	g_cvar_force_player_on = CreateConVar("sm_healthdisplay_force_player_on", "1", "This forces the players to have Health Display on. No menu will be showed unless the player tiggers the menu via chat comamnd: '/hpmenu'.");

	AutoExecConfig(true, "healthdisplay");
	
	//Hooks:
	HookEventEx("player_spawn", Event_Spawn);
	
	//Reg Client Commands:
	RegConsoleCmd("hpmenu",			Command_AsktoDisable);
	RegConsoleCmd("health",			Command_AsktoDisable);
	RegConsoleCmd("healthmenu",		Command_AsktoDisable);
	RegConsoleCmd("healthdisplay",	Command_AsktoDisable);
	
	//Reg Admin Commands:
	RegAdminCmd("sm_debug", Command_Debug, ADMFLAG_ROOT);
	
	//RegCookie:
	cookie_Enable = RegClientCookie("HealthDisplay-Enable","HealthDisplay Enable cookie", CookieAccess_Private);
	cookie_AskedForEnable = RegClientCookie("HealthDisplay-AskedForEnable","HealthDisplay AskedForEnable cookie", CookieAccess_Private);
}

public Action Command_Debug(int client, int args)
{
	float pos[3];
	int entity = GetClientAimHullTarget(client, pos);
	
	PrintToChat(client, "[Health Display] Entity %d - pos: %fx, %fy, %fz", entity, pos[0], pos[1], pos[2]);
	
//	char arg1[64];
//	GetCmdArg(1, arg1, sizeof(arg1));
//	SetClientCookie(client, cookie_AskedForEnable, arg1);
//	LoadClientCookies(client);
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	// hax against valvefail (thx psychonic for fix)
	if (GetEngineVersion() >= Engine_CSS)
		SetConVarString(g_cvar_version, PLUGIN_VERSION);
}

public Action Command_AsktoDisable(int client, int args)
{
	AskToDisableMenu(client);
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	g_cvar_version.SetString(PLUGIN_VERSION);

	int index = -1;
	int health;
	while ((index = FindEntityByClassname(index, "npc_*")) != -1)
	{
		health = GetEntProp(index, Prop_Data, "m_iHealth", 1);
		if (health <= 0 || GetEntityMaxHealth(index))
			continue;

		SetEntProp(index, Prop_Data, "m_iMaxHealth", health);
	}

	//Start Timers:
	CreateTimer(HUD_INTERVALL, Timer_DisplayHud, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

//public OnClientConnected(int client)
public void OnClientPutInServer(int client)
{
	g_bClientShowDisplay[client] = g_cvar_force_player_on.BoolValue;
	g_bAskedForEnable[client] = false;
	g_bClearedDisplay[client] = false;
	g_iUpdateHintTimeout[client] = GetGameTime();
	strcopy(g_szOldShowString[client], MAX_SHOWSTRING_LENGTH, "");
}

bool LoadClientCookies(int client)
{
	if (!AreClientCookiesCached(client))
		return false;

	g_bClientShowDisplay[client] = LoadCookieBool(client, cookie_Enable, g_cvar_force_player_on.BoolValue);
	
	if (g_cvar_save_player.BoolValue)
		g_bAskedForEnable[client] = LoadCookieBool(client, cookie_AskedForEnable, false);
	
	return true;
}

bool LoadCookieBool(int client, Handle cookie, bool defaultValue)
{
	char buffer[64];
	GetClientCookie(client, cookie, buffer, sizeof(buffer));
	
	if (buffer[0] != '\0')
	{
		//PrintToServer("[Health Display] Loaded cookie %d with value %d for %N", cookie, StringToInt(buffer), client);
		return view_as<bool>(StringToInt(buffer));
	}
	
	return defaultValue;
}

public void OnClientCookiesCached(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return;
	
	if (!LoadClientCookies(client))
	{
		if (g_cvar_force_player_on.BoolValue && !g_bClientShowDisplay[client])
				g_bClientShowDisplay[client] = true;

		return;
	}
	
	if (g_bAskedForEnable[client])
		return;
	
	if (g_cvar_force_player_on.BoolValue)
	{
		//PrintToServer("[Health Display] force player on is true -> return");
		return;
	}
	
	//PrintToServer("[Health Display] Activated the menu via OnClientCookiesCached for %N, but with a delay of: %f seconds", client, g_cvar_menu_delay.FloatValue);
	CreateTimer(g_cvar_menu_delay.FloatValue, Timer_AskToDisableMenuDelay, client, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_Spawn(Event event, const char[] name, bool broadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return;
	
	if (!LoadClientCookies(client))
		return;
	
	if (g_bAskedForEnable[client])
		return;

	if (g_cvar_force_player_on.BoolValue)
	{
		//PrintToServer("[Health Display] force player on is true -> return");
		return;
	}
	
	//PrintToServer("[Health Display] Activated the menu via Event_Spawn for %N, but with a delay of: %f seconds", client, g_cvar_menu_delay.FloatValue);
	CreateTimer(g_cvar_menu_delay.FloatValue, Timer_AskToDisableMenuDelay, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_AskToDisableMenuDelay(Handle timer, any client)
{
	AskToDisableMenu(client);
	return Plugin_Continue;
}

stock void AskToDisableMenu(int client)
{
	if (!g_cvar_enable.BoolValue)
		return;
	
	g_bDontOverRideHealthDisplay[client] = true;
	
	switch (g_cvar_hud.IntValue)
	{
		case 0:
		{
			SetHudTextParams(g_flHudXPosition, g_flHudYPosition, 5.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
			if (ShowHudText(client, 3, "Name: Health Display Example (100HP)\nRelationship: Press 1 or 2 please!") == -1)
				PrintHintText(client,"Name: Health Display Example (100HP)\nRelationship: Press 1 or 2");
		}
		case 3: PrintCenterText(client,"Name: Health Display Example (100HP)\nRelationship: Press 1 or 2");
		case 2: PrintHintText(client,"Name: Health Display Example (100HP)\nRelationship: Press 1 or 2");
		case 1:
		{
			SetHudTextParams(g_flHudXPosition, g_flHudYPosition, 5.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
			ShowHudText(client, 3, "Name: Health Display Example (100HP)\nRelationship: Press 1 or 2 please!");
		}
	}
	
	Menu menu = new Menu(HandleMenu);
	char display[32];
	
	menu.SetTitle("Enable the Health Display?\nTo disable it type \n'/hpmenu' (without '')\ninto chat!");
	
	strcopy(display, sizeof(display), "Yes");
	menu.AddItem("1", display);
	
	strcopy(display, sizeof(display), "No");
	menu.AddItem("2", display);
	
	menu.Display(client, 15);
}

public int HandleMenu(Menu menu, MenuAction action, int client, int param)
{
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		char info[64];
		bool found = menu.GetItem(param, info, sizeof(info));
		
		if (found)
		{	
			switch (StringToInt(info))
			{
				//MainMenu:
				case 1:
				{
					g_bClientShowDisplay[client] = true;
					SetClientCookie(client, cookie_Enable, "1");
				}
				case 2:
				{
					g_bClientShowDisplay[client] = false;
					SetClientCookie(client, cookie_Enable, "0");
					
					switch (g_cvar_hud.IntValue)
					{
						case 0:
						{
							SetHudTextParams(g_flHudXPosition, g_flHudYPosition, 5.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
							if (ShowHudText(client, 3, "Health Display Disabled!") == -1)
								PrintHintText(client,"Health Display Disabled!");
						}
						case 3: PrintCenterText(client,"Health Display Disabled!");
						case 2: PrintHintText(client,"Health Display Disabled!");
						case 1:
						{
							SetHudTextParams(g_flHudXPosition, g_flHudYPosition, 5.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
							ShowHudText(client, 3, "Health Display Disabled!");
						}
					}
				}
			}
			
			if (g_cvar_save_player.BoolValue)
			{
				SetClientCookie(client, cookie_AskedForEnable, "1");
				g_bAskedForEnable[client] = true;
			}
			
			g_bDontOverRideHealthDisplay[client] = false;
		}
	}
	else if (action == MenuAction_Cancel)
		g_bDontOverRideHealthDisplay[client] = false;
	else if (action == MenuAction_End) // If the menu has ended, destroy it
		delete menu;
	
	return 0;
}

public bool TraceFilterAllEntities(int entity, int contentsMask)
{
	if (entity != 0)
		return false;
	
	return true;
}

stock bool GetEntityName(int entity, char[] name = "", int maxlen = MAX_CLASSNAME_LENGTH)
{
	if (entity == 0)
		return false;
	
	if (IsPlayer(entity) && IsClientInGame(entity) && IsPlayerAlive(entity))
	{
		GetClientName(entity, name, maxlen);
		
		if (IsFakeClient(entity))
			Format(name, maxlen, "(BOT) %s", name);
		
		return false;
	}
	else
	{
		if (!IsValidEdict(entity))
			return false;

		if (Syn_NpcFormatedNameEx(entity, name, maxlen))
			return true;
	}
	
	return false;
}

public bool TraceEntityFilter(int entity, int contentsMask, any client)
{
	if (entity == client)
		return false;
	
	if (IsPlayer(entity))
	{
/*
		if (!g_cvar_show_enemyplayers.BoolValue)
		{
			if (GetClientTeam(client) != GetClientTeam(entity))
				return false;
		}
*/		
		if (!g_cvar_show_teammates.BoolValue)
		{
			/*if (GetClientTeam(client) == GetClientTeam(entity))
				return false;*/
			if (Syn_IsInAVehicle(entity))
				return false;
			
			return true;
		}
	}
	else
	{
		if (IsNpc(entity))
		{
			if (!g_cvar_show_npcs.BoolValue)	
				return false;
		}
		else
		{
			if (IsValidEdict(entity))
			{
				char classname[MAX_CLASSNAME_LENGTH];
				GetEdictClassname(entity, classname, sizeof(classname));
				if (StrEqual(classname, "func_brush"))
					return false;
				if (StrEqual(classname, "func_vehicleclip"))
					return false;
				if (StrEqual(classname, "prop_vehicle_airboat"))
					return false;
				if (StrEqual(classname, "prop_vehicle_mp"))
					return false;
				if (StrEqual(classname, "prop_vehicle_prisoner_pod"))
					return false;
				if (StrEqual(classname, "weapon_striderbuster"))
					return false;
			}

			return true;
		}
	}
	
	return GetEntityName(entity);
}

bool IsNpc(int entity)
{
	if (!IsValidEdict(entity))
		return false;
	
/*	char classname[MAX_CLASSNAME_LENGTH];
	GetEdictClassname(entity, classname, sizeof(classname));
		
	if (StrContains(classname, "npc_", false) == 0) {
		return true;
	}*/

	return Syn_IsNPC(entity);
}

int GetClientAimHullTarget(int client, float resultPos[3])
{
	//Hull trace calculation by berni all credits for this goes to him!
	if (client < 1)
		return -1;
	
	float vAngles[3], vOrigin[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, TRACE_FILTER, RayType_Infinite, TraceFilterAllEntities);
	
	float pos[3];
	TR_GetEndPosition(pos, trace);
	
	CloseHandle(trace);
	
	float vecMins[3] = {-1.0, -1.0, -1.0}, vecMaxs[3] = {1.0, 1.0, 1.0};
	//GetEntPropVector(entity, Prop_Send, "m_vecMins", m_vecMins);
	//GetEntPropVector(entity, Prop_Send, "m_vecMaxs", m_vecMaxs);
	
	trace = TR_TraceHullFilterEx(vOrigin, pos, vecMins, vecMaxs, TRACE_FILTER, TraceEntityFilter, client);
	
	TR_GetEndPosition(resultPos, trace);

	if (TR_DidHit(trace))
	{
		int entity = TR_GetEntityIndex(trace);
		
		CloseHandle(trace);
		
		return entity;
	}
	
	CloseHandle(trace);
	
	return -1;
}

public Action Timer_DisplayHud(Handle timer)
{
	int aimTarget;
	float pos[3];
	
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
			continue;

		if (!g_bClientShowDisplay[client])
			continue;
			
		aimTarget = GetClientAimHullTarget(client, pos);
		if (aimTarget <= MaxClients)
			continue;

/*		if (!Syn_IsAlive(aimTarget))
			continue;*/
			
/*		if (Syn_IsDead(aimTarget))
			continue;*/
			
		ShowHPInfo(client, aimTarget);
	}
	
	return Plugin_Continue;
}

public void ShowHPInfo(int client, int target)
{
	if (!g_cvar_enable.BoolValue)
		return;
	
	if (g_bDontOverRideHealthDisplay[client])
		return;
	
	char targetname[MAX_TARGET_LENGTH];
	bool success = GetEntityName(target, targetname, sizeof(targetname));
	
	if (success)
	{
		// Don't show dead
		if (HasEntProp(target, Prop_Data, "m_lifeState") && GetEntProp(target, Prop_Data, "m_lifeState") == 2)
			return;

		if (StrEqual(targetname, "Strider", false) && HasEntProp(target, Prop_Data, "m_hCine") && GetEntPropEnt(target, Prop_Data, "m_hCine") != -1)
		{
			// Don't show if m_scriptState = SCRIPT_POST_IDLE
			if (HasEntProp(target, Prop_Data, "m_scriptState") && GetEntProp(target, Prop_Data, "m_scriptState") == 2)
				return;
		}

		char health[MAX_HEALTH_LENGTH];
		GetEntityHealthString(target, health);
		
		char relationship[MAX_RELATIONSHIP_LENGTH] = RELATIONSHIP_NONE;
		Colors color = GetEntityRelationship(client, target, relationship, sizeof(relationship));
		
		switch (g_cvar_hud.IntValue)
		{
			case 0:
			{	
				int rgba[4];
				switch (color)
				{
					case Red: rgba = {255, 20, 20, 255};
					case Green: rgba = {20, 255, 20, 255};
					case Yellow: rgba = {255, 255, 20, 255};
					case White: rgba = {255, 255, 255, 255};
				}

				SetHudTextParams(g_flHudXPosition, g_flHudYPosition, HUD_INTERVALL + 0.2, rgba[0], rgba[1], rgba[2], rgba[3], 0, 0.0, 0.0, 0.0);
				if (ShowHudText(client, 3, "%s: %s (%s)", relationship, targetname, health) == -1)
				{	
					char showstring[MAX_SHOWSTRING_LENGTH];
					g_bClearedDisplay[client] = false;
					Format(showstring, MAX_SHOWSTRING_LENGTH,  "%s: %s (%s)", relationship, targetname, health);
					
					if (!StrEqual(showstring, g_szOldShowString[client], false) || ((GetGameTime() - g_iUpdateHintTimeout[client]) > 4.0))
					{	
						PrintHintText(client,showstring);
						strcopy(g_szOldShowString[client], MAX_SHOWSTRING_LENGTH, showstring);
						g_iUpdateHintTimeout[client] = GetGameTime();
					}
				}
			}
			case 3:
			{
				if (StrEqual(relationship, RELATIONSHIP_NONE, true))
					PrintCenterText(client, "%s (%s)", targetname, health);
				else
				{
					PrintCenterText(client, "%s: %s (%s)", relationship, targetname, health);

/*					int rgba[4];
					switch (color)
					{
						case Red: rgba = {255, 20, 20, 255};
						case Green: rgba = {20, 255, 20, 255};
						case Yellow: rgba = {255, 255, 20, 255};
						case White: rgba = {255, 255, 255, 255};
					}

					int rgb;
					rgb |= ((rgba[0] & 0xFF) << 16);
					rgb |= ((rgba[1] & 0xFF) << 8 );
					rgb |= ((rgba[2] & 0xFF) << 0 );
					
					PrintCenterText(client, "<font color='#%06X'>%s: %s (%s)</font>", rgb, relationship, targetname, health);*/
				}
			}
			case 2: 
			{
				char showstring[MAX_SHOWSTRING_LENGTH];
				g_bClearedDisplay[client] = false;
				Format(showstring,MAX_SHOWSTRING_LENGTH, "%s (%s)\nRelationship: %s", targetname, health, relationship);
				
				if (!StrEqual(showstring, g_szOldShowString[client], false) || ((GetGameTime() - g_iUpdateHintTimeout[client]) > 4.0))
				{	
					PrintHintText(client, showstring);
					strcopy(g_szOldShowString[client], MAX_SHOWSTRING_LENGTH, showstring);
					g_iUpdateHintTimeout[client] = GetGameTime();
				}
			}
			case 1:
			{	
				int rgba[4];
				switch (color)
				{
					case Red: rgba = {255, 0, 0, 255};
					case Green: rgba = {0, 255, 0, 255};
					case Yellow: rgba = {255, 255, 0, 255};
					case White: rgba = {255, 255, 255, 255};
				}
				//Handle hHudSync = CreateHudSynchronizer();
				//SetHudTextParams(g_flHudXPosition, g_flHudYPosition, HUD_INTERVALL + 0.2, rgba[0], rgba[1], rgba[2], rgba[3], 0, 0.0, 0.0, 0.0);
				SetHudTextParamsEx(g_flHudXPosition, g_flHudYPosition, HUD_INTERVALL + 0.2, rgba, {0,0,0,255}, 0, 0.0, 0.0, 0.0);
				//ShowHudText(client, 3, "%s (%s)\nRelationship: %s", targetname, health, relationship);
				ShowHudText(client, 3, "%s: %s (%s)", relationship, targetname, health);
				//PrintToChat(client,"%s (%s)\nRelationship: %s", targetname, health, relationship);
				
				//ClearSyncHud(client, hHudSync);
				//ShowSyncHudText(client, hHudSync, "%s: %s (%s)", relationship, targetname, health);
				//SendMsg_HudMsg(client, 3, g_flHudXPosition, g_flHudYPosition, HUD_INTERVALL + 0.2, rgba, _, 0, 0.0, 0.0, 0.0, "TEST AOIUSAIOUSAOIUSAIOU");
			}
			default: return;
		}
	}
	else if (!g_bClearedDisplay[client])
	{
		g_bClearedDisplay[client] = true;
		
		switch (g_cvar_hud.IntValue)
		{
			case 0:
			{
				if (ShowHudText(client, 3, " ") == -1)
					PrintHintText(client, HINTBOX_BLANK);
			}
			case 2: PrintHintText(client, HINTBOX_BLANK);
		}
		
		strcopy(g_szOldShowString[client], sizeof(g_szOldShowString[]), HINTBOX_BLANK);
	}
}

stock void UpperFirstCharInString(char[] string)
{
	string[0] = CharToUpper(string[0]);
}

stock bool IsPlayer(int client)
{
	if (!IsValidEdict(client))
		return false;
	
	if ((client < 1) || (MaxClients < client))
		return false;
	
	return true;
}

stock int GetEntityHealth(int entity)
{
	int health = 0;
	
	if (IsPlayer(entity))
	{
		health = GetClientHealth(entity);
	}
	else
	{
		health = GetEntProp(entity, Prop_Data, "m_iHealth", 1);
		
		//if (health <= 1)
		if (health < 1)
			health = 0;
	}
	
//	g_iOldHealth[entity] = health;
	return health;
}

stock int GetEntityMaxHealth(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_iMaxHealth", 1);
}

stock int GetEntityHealthString(int entity, char health[MAX_HEALTH_LENGTH])
{
	int iHealth = GetEntityHealth(entity);
	
	if (iHealth < 1)
	{	
		if (IsPlayer(entity) || IsNpc(entity))
			strcopy(health, MAX_HEALTH_LENGTH, REPORT_DEAD);
		else
		{
			//strcopy(health, MAX_HEALTH_LENGTH, "!!");
			strcopy(health, MAX_HEALTH_LENGTH, REPORT_DESTROYED);
		}
	}
	else
	{
		//Format(health, MAX_HEALTH_LENGTH, "%i HP", iHealth);
		int iMaxHealth = GetEntityMaxHealth(entity);
		if (!iMaxHealth)
		{
			SetEntProp(entity, Prop_Data, "m_iMaxHealth", iHealth);
			iMaxHealth = iHealth;
		}

		Format(health, MAX_HEALTH_LENGTH, "%i%%", RoundToCeil((float(iHealth) / float(iMaxHealth)) * float(100)));
	}
	
	return iHealth;
}

stock Colors GetEntityRelationship(int client, int entity, char[] relationship, int maxlen)
{
	if (IsPlayer(entity))
	{
		
		int playerTeam = GetClientTeam(entity);
		int clientTeam = GetClientTeam(client);
		
		if (playerTeam == clientTeam)
			strcopy(relationship, maxlen, RELATIONSHIP_FRIEND);
		else 
			strcopy(relationship, maxlen, RELATIONSHIP_ENEMY);
	}
	else if (IsNpc(entity))
	{
		//strcopy(relationship, maxlen, RELATIONSHIP_NONE);
		
		Disposition_t disposition = Syn_IRelationType(entity, client);

/*		if (disposition == D_HT)
		{
			char classname[MAX_CLASSNAME_LENGTH];
			GetEdictClassname(entity, classname, sizeof(classname));
			if (StrEqual(classname, "npc_antlion"))
			{
				if (IsPlayer(GetEntPropEnt(entity, Prop_Data, "m_hFollowTarget")))
					disposition = D_NU;
			}
		}
*/
		if (disposition == D_HT || disposition == D_FR)
		{
			strcopy(relationship, maxlen, RELATIONSHIP_ENEMY);
			return Red;
		}
		else if (disposition == D_LI)
		{
			strcopy(relationship, maxlen, RELATIONSHIP_FRIEND);
			return Green;
		}
		else if (disposition == D_NU)
		{
			strcopy(relationship, maxlen, RELATIONSHIP_NEUTRAL);
			return Yellow;
		}
		else
		{
			strcopy(relationship, maxlen, UNKNOWN);
			return White;
		}
	}
	else
	{
		if (entity > 0 && IsValidEdict(entity))
		{
			char classname[MAX_CLASSNAME_LENGTH];
			GetEdictClassname(entity, classname, sizeof(classname));
			if (StrEqual(classname, "combine_mine"))
			{
				if (GetEntProp(entity, Prop_Data, "m_bPlacedByPlayer"))
				{
					strcopy(relationship, maxlen, RELATIONSHIP_FRIEND);
					return Green;
				}
				else if (!GetEntProp(entity, Prop_Data, "m_bHeldByPhysgun") && GetEntProp(entity, Prop_Data, "m_iMineState"))
				{
					strcopy(relationship, maxlen, RELATIONSHIP_ENEMY);
					return Red;
				}
			}

			if (StrEqual(classname, "prop_vehicle_apc"))
			{
				if (IsPlayer(GetEntPropEnt(entity, Prop_Data, "m_hRocketTarget")))
				{
					strcopy(relationship, maxlen, RELATIONSHIP_ENEMY);
					return Red;
				}
			}
		}

		strcopy(relationship, maxlen, RELATIONSHIP_NEUTRAL);
		return Yellow;
	}
	
	if (relationship[0] == '\0')
		strcopy(relationship, maxlen, RELATIONSHIP_NONE);

	return White;
}

stock void GetFileName(char[] path_or_file, char[] name, int maxlen, bool stripExtension = true)
{
	char[] path = new char[strlen(path_or_file) + 1];
	strcopy(path, strlen(path_or_file) + 1, path_or_file);
	
	int pos = FindCharInString(path, '/', true);
	
	if (pos == -1)	
		pos = 0;
	else
		pos++;
	
	if (stripExtension && path[pos] != '\0')
	{
		strcopy(name, maxlen, path[pos]);
		
		char[] extension = new char[maxlen];
		GetFileExtension(path[pos], extension, maxlen, false);
		
		if (extension[0] != '\0')	
			ReplaceString(name, maxlen, extension, "", false);
	}
}

stock void Entity_GetModel(int entity, char[] buffer, int size)
{
	GetEntPropString(entity, Prop_Data, "m_ModelName", buffer, size);
}

stock void GetFileExtension(char[] path_or_file, char[] extension, int maxlen, bool removeDot = true)
{
	char[] path = new char[strlen(path_or_file)+1];
	strcopy(path, strlen(path_or_file) + 1, path_or_file);
	
	int pos = FindCharInString(path, '.', true);
	
	if (pos == -1)
		return;
	else
	{
		if (removeDot)
			pos++;
	}
	
	if (path[pos] != '\0')
		strcopy(extension, maxlen, path[pos]);
}
/*
stock void ConfigArrayToStringAdt(Handle Setting, ArrayList adtArray)
{
	char buffer[PLATFORM_MAX_PATH];
	int length = ConfigSettingLength(Setting);
	
	for (int i = 0; i < length; i++)
	{
		ConfigSettingGetStringElement(Setting, i, buffer, sizeof(buffer));
		adtArray.PushString(buffer);
		//PrintToServer("Debug: %s", buffer);
	}
}
*/
/*
// "HudMsg" message
stock void SendMsg_HudMsg(int client, int channel, float x, float y,
					float holdtime, int color1[4], int color2[4]={0,0,0,0},
					int effect = 0, float fxtime=6.0, float fadein=0.1,
					float fadeout=0.2, const char[] szMsg)
{
	BfWrite hBf;
	if (!client)
		hBf = view_as<BfWrite>(StartMessageAll("HudMsg"));
	else hBf = view_as<BfWrite>(StartMessageOne("HudMsg", client));
	if (hBf != null)
	{
		hBf.WriteByte(channel); //channel
		hBf.WriteFloat(x); // x ( -1 = center )
		hBf.WriteFloat(y); // y ( -1 = center )
		// second color
		hBf.WriteByte(color1[0]); //r1
		hBf.WriteByte(color1[1]); //g1
		hBf.WriteByte(color1[2]); //b1
		hBf.WriteByte(color1[3]); //a1 // transparent?
		// init color
		hBf.WriteByte(color2[0]); //r2
		hBf.WriteByte(color2[1]); //g2
		hBf.WriteByte(color2[2]); //b2
		hBf.WriteByte(color2[3]); //a2
		hBf.WriteByte(effect); //effect (0 is fade in/fade out; 1 is flickery credits; 2 is write out)
		hBf.WriteFloat(fadein); //fadeinTime (message fade in time - per character in effect 2)
		hBf.WriteFloat(fadeout); //fadeoutTime
		hBf.WriteFloat(holdtime); //holdtime
		hBf.WriteFloat(fxtime); //fxtime (effect type(2) used)
		hBf.WriteString(szMsg); //Message
		EndMessage();
	}
}
*/
/*
stock int FindEntityByClassname2(int startEnt, const char[] classname)
{
	// If startEnt isn't valid shifting it back to the nearest valid one
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;

	return FindEntityByClassname(startEnt, classname);
}
*/
