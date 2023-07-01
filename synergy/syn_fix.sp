#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
//#include <sdkhooks>
#include <sdktools>

public Plugin myinfo = 
{
	name = "Synergy Fix",
	author = "Duko",
	description = "Synergy Fix",
	version = "1.1",
	url = "http://group.midu.cz"
}

ConVar g_Cvar_PlayerPush;
bool g_bCanChange = true;
int g_iAttempt = 0;

/*
public void OnMapStart()
{
	PrecacheModel("models/weapons/w_bugbait.mdl", true);
}
*/


public void OnPluginStart()
{
	HookEventEx("player_spawn", OnSpawnPlayer, EventHookMode_Post);
	
	RegConsoleCmd("stuck", Cmd_BlockStuck);
	
	RegServerCmd("changelevel", Cmd_ChangeLevelFix);
	RegServerCmd("changelevel_next", Cmd_ChangeLevelFix);
//	RegServerCmd("map", Cmd_MapFix);
	
	g_Cvar_PlayerPush = FindConVar("sv_player_push");

	if (g_Cvar_PlayerPush != null)
	{
		if (g_Cvar_PlayerPush.Flags & FCVAR_NOTIFY)
			g_Cvar_PlayerPush.Flags &= ~FCVAR_NOTIFY;

		if (g_Cvar_PlayerPush.Flags & FCVAR_REPLICATED)
			g_Cvar_PlayerPush.Flags &= ~FCVAR_REPLICATED;
			
		g_Cvar_PlayerPush.AddChangeHook(ConVarHook_PlayerPush);
	}
}

public void OnConfigsExecuted()
{
	if (IsVehicleOnMap())
	{
		if (g_Cvar_PlayerPush.IntValue != 0)
			g_Cvar_PlayerPush.IntValue = 0;
		
		CreateTimer(10.0, Timer_CheckPlayerPush, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	int index = -1, disabled;
	char targetname[32];
	while ((index = FindEntityByClassname(index, "info_player_equip")) != -1)
	{
		if (HasEntProp(index, Prop_Data, "m_bDisabled"))
			disabled = GetEntProp(index, Prop_Data, "m_bDisabled", 1);
		else
			disabled = -1;
			
		GetEntPropString(index, Prop_Data, "m_iName", targetname, sizeof(targetname));

		if (disabled != 0 || StrEqual(targetname, "syn56.16_spawn_weapons_fix"))
			continue;
		
		AcceptEntityInput(index, "Disable");
		DispatchKeyValue(index, "targetname", "syn56.16_spawn_weapons_fix");
		
		PrintToServer("[FIX] info_player_equip %i is Disabled", index);
	}
	
	CreateTimer(8.0, Timer_CheckInfoPlayerEquip, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	g_iAttempt = 0;

	g_bCanChange = true;
}
/*
public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;

	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch); // function Action (int client, int weapon);
//	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch); //function void (int client, int weapon);
//	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip); //function void (int client, int weapon);
//	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquip); //function void (int client, int weapon);
}

public Action OnWeaponSwitch(int client, int weapon)
{
	if (weapon <= 0 || !IsValidEntity(weapon) || !IsValidEdict(weapon))
		return Plugin_Continue;

//	AdminId aid = GetUserAdmin(client);
//	if (aid == INVALID_ADMIN_ID || !GetAdminFlag(aid, Admin_Root, Access_Effective))
	if (!GetUserFlagBits(client))
		return Plugin_Continue;

	char classname[32];
	GetEdictClassname(weapon, classname, sizeof(classname));

//	PrintToConsole(client, "[T] WeaponSwitch client: %i, weapon: %i %s", client, weapon, classname);
	PrintToChat(client, "[T] WeaponSwitch client: %i, weapon: %i %s", client, weapon, classname);
	
	return Plugin_Continue;
}
*/
public void OnSpawnPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client <= 0 || !IsClientInGame(client))
		return;

	CreateTimer(0.5, Timer_PlayerSpawn, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PlayerSpawn(Handle timer, any client)
{
	if (!IsClientInGame(client))
		return Plugin_Stop;

	int index = -1, disabled;
	char targetname[32];
	while ((index = FindEntityByClassname(index, "info_player_equip")) != -1)
	{
		if (HasEntProp(index, Prop_Data, "m_bDisabled"))
			disabled = GetEntProp(index, Prop_Data, "m_bDisabled", 1);
		else
			disabled = -1;
			
		GetEntPropString(index, Prop_Data, "m_iName", targetname, sizeof(targetname));

		if (disabled == 0 || !StrEqual(targetname, "syn56.16_spawn_weapons_fix"))
			continue;
		
		AcceptEntityInput(index, "EquipPlayer", client);
	}

	return Plugin_Stop;
}

public Action Timer_CheckPlayerPush(Handle timer)
{
	if (g_Cvar_PlayerPush.IntValue != 0)
		g_Cvar_PlayerPush.IntValue = 0;

	return Plugin_Continue;
}

public Action Timer_CheckInfoPlayerEquip(Handle timer)
{
	int index = -1, count = 0, disabled;
	char targetname[32];
	while ((index = FindEntityByClassname(index, "info_player_equip")) != -1)
	{
		if (HasEntProp(index, Prop_Data, "m_bDisabled"))
			disabled = GetEntProp(index, Prop_Data, "m_bDisabled", 1);
		else
			disabled = -1;
			
		GetEntPropString(index, Prop_Data, "m_iName", targetname, sizeof(targetname));

		if (StrEqual(targetname, "syn56.16_spawn_weapons_fix"))
			continue;

		if (disabled == 1)
		{
			count++;
			continue;
		}

		AcceptEntityInput(index, "Disable");
		DispatchKeyValue(index, "targetname", "syn56.16_spawn_weapons_fix");
		
		PrintToServer("[FIX] info_player_equip %i %s is Disabled and renamed", index, targetname);
	}
	
	if (count > 0)
		return Plugin_Continue;
	
	PrintToServer("[FIX] info_player_equip Timer_CheckInfoPlayerEquip is stoped");

	return Plugin_Stop;
}

public Action Cmd_BlockStuck(int client, int args)
{
	if (client <= 0 || !IsInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;
		
	if (Client_IsInVehicle(client))
		return Plugin_Handled;
	
	if (PlayerReachChangeLevel(client))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action Cmd_ChangeLevelFix(int args)
{
	if (args < 1)
	{
		PrintToServer("[FIX] Usage: changelevel <tag> <map>");
		return Plugin_Continue;
	}
	
	if (args == 1)
	{
		char map[64], tag[8];
		GetCmdArg(1, map, sizeof(map));
		
		char buffer[128];
		bool bExists = false;

		Format(buffer, sizeof(buffer), "../../Half-Life 2/hl2/maps/%s.bsp", map);
		
		if (FileExists(buffer, false, NULL_STRING))
		{
			strcopy(tag, sizeof(tag), "hl2");
			bExists = true;
		}

		if (!bExists)
		{
			Format(buffer, sizeof(buffer), "../../Half-Life 2/episodic/maps/%s.bsp", map);
			
			if (FileExists(buffer, false, NULL_STRING))
			{
				strcopy(tag, sizeof(tag), "ep1");
				bExists = true;
			}
		}

		if (!bExists)
		{
			Format(buffer, sizeof(buffer), "../../Half-Life 2/ep2/maps/%s.bsp", map);

			if (FileExists(buffer, false, NULL_STRING))
			{
				strcopy(tag, sizeof(tag), "ep2");
				bExists = true;
			}
		}

		if (!bExists)
		{
			Format(buffer, sizeof(buffer), "../../Half-Life 2/lostcoast/maps/%s.bsp", map);

			if (FileExists(buffer, false, NULL_STRING))
			{
				strcopy(tag, sizeof(tag), "lost");
				bExists = true;
			}
		}

		if (!bExists)
		{
			Format(buffer, sizeof(buffer), "../../MINERVA/metastasis/maps/%s.bsp", map);
		
			if (FileExists(buffer, false, NULL_STRING))
			{
				strcopy(tag, sizeof(tag), "meta");
				bExists = true;
			}
		}

		if (!bExists)
		{
			Format(buffer, sizeof(buffer), "maps/%s.bsp", map);
			
			if (FileExists(buffer, false, NULL_STRING))
			{
				strcopy(tag, sizeof(tag), "syn");
				bExists = true;
			}
		}
		
		if (!bExists)
		{
			Format(buffer, sizeof(buffer), "custom/mapy/maps/%s.bsp", map);
			
			if (FileExists(buffer, false, NULL_STRING))
			{
				strcopy(tag, sizeof(tag), "custom");
				bExists = true;
			}
		}
		
		if (!bExists && tag[0] == '\0')
		{
		//	strcopy(tag, sizeof(tag), "none");
		//	strcopy(tag, sizeof(tag), "custom");
			PrintToServer("[FIX] cmd changelevel %s %s map not found!", tag, map);
			
			return Plugin_Handled;
		}
		
		if (g_iAttempt > 3)
		{
			PrintToServer("[FIX] cmd changelevel can't chanege to %s %s", tag, map);

			return Plugin_Handled;
		}
		
		g_iAttempt++;
		
		PrintToServer("[FIX] cmd changelevel %s %s", tag, map);
		ServerCommand("changelevel %s %s", tag, map);
		return Plugin_Handled;
	}

	if (!g_bCanChange)
	{
		char arg[64];
		GetCmdArgString(arg, sizeof(arg));
		PrintToServer("[FIX] cmd changelevel arg %s blocked", arg);

		return Plugin_Handled;
	}
	
	if (g_bCanChange)
	{
		CreateTimer(2.0, Timer_ChangeLevelFix, _, TIMER_FLAG_NO_MAPCHANGE);
		g_bCanChange = false;
	}
	
/*
	char arg[64];
	GetCmdArgString(arg, sizeof(arg));
	
	PrintToServer("[FIX] args %i, arg %s", args, arg);
*/
	return Plugin_Continue;
}
/*
public Action Cmd_MapFix(int args)
{
	if (args == 1)
	{
		char map[64];
		GetCmdArg(1, map, sizeof(map));
		
		if (StrEqual(map, "syn_takeover"))
		{
			PrintToServer("[FIX] cmd map syn %s", map);
			ServerCommand("map syn %s", map);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}
*/
public Action Timer_ChangeLevelFix(Handle timer)
{
	g_bCanChange = true;
	
	return Plugin_Stop;
}

public void ConVarHook_PlayerPush(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) != 0)
	{
		if (IsVehicleOnMap())
		{
		//	convar.IntValue = 0;
			CreateTimer(2.0, Timer_CheckPlayerPush, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (impulse != 100)
		return Plugin_Continue;

	int vehicle = Client_GetVehicle(client);
	if (vehicle <= MaxClients || !IsValidEntity(vehicle))
		return Plugin_Continue;

	char classname[32];
	GetEntityClassname(vehicle, classname, sizeof(classname));

	if (strncmp(classname, "prop_vehicle_jeep", 17) != 0 && !StrEqual(classname, "prop_vehicle_mp"))
		return Plugin_Continue;
	
/*	char model[32];
	GetEntPropString(vehicle, Prop_Data, "m_ModelName", model, sizeof(model));
	
	if (!StrEqual(model, "models\\buggy.mdl") && !StrEqual(model, "models/buggy.mdl") &&
		!StrEqual(model, "models\\vehicles\\buggy_p2.mdl") && !StrEqual(model, "models/vehicles/buggy_p2.mdl"))
		return Plugin_Continue;*/

	char script[32];
	GetEntPropString(vehicle, Prop_Data, "m_vehicleScript", script, sizeof(script));

	if (!StrEqual(script, "scripts/vehicles/jeep_test.txt") && !StrEqual(script, "scripts/vehicles/jalopy.txt"))
		return Plugin_Continue;

	int driver = GetEntProp(client, Prop_Data, "m_iHideHUD");
	int running = 1;
	if (HasEntProp(vehicle, Prop_Data, "m_bIsOn"))
		running = GetEntProp(vehicle, Prop_Data, "m_bIsOn");

	if (driver == 3328 && running)
	{
		if (HasEntProp(vehicle, Prop_Data, "m_bHeadlightIsOn"))
		{
			if (GetEntProp(vehicle, Prop_Data, "m_bHeadlightIsOn"))
				SetEntProp(vehicle, Prop_Data,"m_bHeadlightIsOn", 0);
			else
				SetEntProp(vehicle, Prop_Data, "m_bHeadlightIsOn", 1);

			EmitSoundToAll("items/flashlight1.wav", vehicle, SNDCHAN_AUTO, SNDLEVEL_DISHWASHER);
		}
	}
	
	return Plugin_Continue;
}

stock int Client_GetVehicle(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hVehicle");
}

stock bool Client_IsInVehicle(int client)
{
	return !(Client_GetVehicle(client) == -1);
}

stock bool PlayerReachChangeLevel(int client)
{
	int flags = GetEntityFlags(client);
	if (GetEntityRenderMode(client) == RENDER_TRANSALPHA && GetEntityRenderFx(client) == RENDERFX_DISTORT &&
		flags & FL_FROZEN && flags & FL_GODMODE && flags & FL_NOTARGET)
	{
		return true;
	}

	return false;
}

stock bool IsVehicleOnMap()
{
	if (FindEntityByClassname(-1, "prop_vehicle_jeep*") != -1)
		return true;

	if (FindEntityByClassname(-1, "prop_vehicle_mp") != -1)
		return true;

	if (FindEntityByClassname(-1, "prop_vehicle_airboat") != -1)
		return true;

	if (FindEntityByClassname(-1, "info_vehicle_spawn") != -1)
		return true;
	
	return false;
}

stock bool IsInGame(int client)
{
	if (IsClientConnected(client) && IsClientInGame(client))
		return true;

	return false;
}
