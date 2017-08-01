#include <sourcemod>
#include <sdkhooks>
#include <swarmtools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1.4"

ConVar g_Cvar_AllowClients;
ConVar g_Cvar_Announce;
bool g_bState[MAXPLAYERS+1] = {false, ...};

public Plugin myinfo =
{
	name = "[SWARM] Deluxe Godmod",
	author = "DarthNinja",
	description = "Enables GodMode on clients - Alien Swarm version",
	version = PLUGIN_VERSION,
	url = "DarthNinja.com"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_god", Command_God, "sm_god [#userid|name] [0/1] - Toggles God mod on player(s)");
	RegConsoleCmd("sm_mortal", Command_Mortal, "sm_mortal [#userid|name] - Makes specified players mortal");

	CreateConVar("sm_godmode_swarm_version", PLUGIN_VERSION, "Plugin Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_Cvar_AllowClients = CreateConVar("sm_godmode_clients", "0", "Set to 1 to allow clients to set Godmode on themselves", 0, true, 0.0, true, 1.0);
	g_Cvar_Announce = CreateConVar("sm_godmode_announce", "1", "Tell players if an admin gives/removes their Godmode", 0, true, 0.0, true, 1.0);

//	HookEvent("marine_infested", FaceFuckerFix, EventHookMode_Post);
	HookEvent("marine_selected", OnMarineSelected, EventHookMode_Post);
	HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);
	
	LoadTranslations("common.phrases");
} 

public void FaceFuckerFix(Handle event, const char[] name, bool dontBroadcast)
{
	int marine = GetEventInt(event, "entindex");
	if (Swarm_IsMarineInfested(marine) && g_bState[Swarm_GetClientOfMarine(marine)])
		Swarm_CureMarineInfestation(marine);
		
//	PrintToServer("[SG] marine: %i", marine);

/*	if (marine <= 0)
		return;

	int client = Swarm_GetClientOfMarine(marine);
	
	if (client <= 0 || client > MaxClients)
		return;
	
	 //add g_bState check
	if (!g_bState[client])
		return;

	if (Swarm_IsMarineInfested(marine))
		Swarm_CureMarineInfestation(marine);*/

	//CreateTimer(0.2, CureTimer, EntIndexToEntRef(marine), TIMER_FLAG_NO_MAPCHANGE);
	
	//PrintToServer("[SG] marine: %i, client: %i", marine, client);
}
/*
public Action CureTimer(Handle timer, any ref)
{
	int marine = EntRefToEntIndex(ref);

	if (marine == INVALID_ENT_REFERENCE)
		return Plugin_Stop;

	if (marine <= 0 || !IsValidEdict(marine))
		return Plugin_Stop;
	
	if (Swarm_IsMarineInfested(marine))
		Swarm_CureMarineInfestation(marine);
		
	//PrintToServer("[SG] marine: %i", marine);
	
	return Plugin_Stop;
}
*/
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
/*	if (attacker == -1)
		return Plugin_Continue;*/

	int client = Swarm_GetClientOfMarine(victim);
	if (client <= 0 || client > MaxClients)
		return Plugin_Continue;
	
	if (g_bState[client]) //just for safety
	{
		if (Swarm_IsMarineInfested(victim))
		{
			Swarm_CureMarineInfestation(victim);
			//return Plugin_Continue;
		}

		/*damage = 0.0;
		damagetype = DMG_CRUSH;
		return Plugin_Changed;*/
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Command_God(int client, int args)
{
	if (args != 0 && args != 1 && args != 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_god [#userid|name] [0/1]");
		return Plugin_Handled;
	}

	bool isAdmin = CheckCommandAccess(client, "sm_slay", ADMFLAG_SLAY);

	if (!isAdmin && !g_Cvar_AllowClients.BoolValue)
	{
		ReplyToCommand(client, "[SM] You are not authorized to use this command");
		return Plugin_Handled;
	}

	if (args == 0)
	{
		int RAMIREZ = Swarm_GetMarine(client);
		
/*		if (RAMIREZ == -1)
		{
			ReplyToCommand(client, "Unable to get your Marine's Entity!\n Godmode not enabled!");
			return Plugin_Handled;
		}*/
		
		if (!g_bState[client]) //Mortal
		{
			ReplyToCommand(client,"\x01[SM] \x04God Mode on");
			g_bState[client] = true;
			
			if (RAMIREZ != -1)
				SDKHook(RAMIREZ, SDKHook_OnTakeDamage, OnTakeDamage);
		}
		else // GodMode on
		{
			ReplyToCommand(client,"\x01[SM] \x04God Mode off");
			g_bState[client] = false;
			
			if (RAMIREZ != -1)
				SDKUnhook(RAMIREZ, SDKHook_OnTakeDamage, OnTakeDamage);
		}
		return Plugin_Handled;
	}

	if (!isAdmin)
	{
		ReplyToCommand(client, "[SM] You are not authorized to target other players");
		return Plugin_Handled;
	}

	if (args == 2)
	{
		char target[32];
		char arg2[32];

		GetCmdArg(1, target, sizeof(target));
		GetCmdArg(2, arg2, sizeof(arg2));

		int toggle = StringToInt(arg2);

		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;

		if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
			{
				ReplyToTargetError(client, target_count);
				return Plugin_Handled;
			}

		bool chat = g_Cvar_Announce.BoolValue;

		if (toggle == 1)
		{
			ShowActivity2(client, "\x04[SM] ","\x01Enabled God Mode on \x05%s", target_name);
		}
		else if (toggle == 0)
		{
			ShowActivity2(client, "\x04[SM] ","\x01Disabled God Mode on \x05%s", target_name);
		}

		int RAMIREZ;
		for (int i = 0; i < target_count; i++)
		{
			RAMIREZ = Swarm_GetMarine(target_list[i]);
			
			if (toggle == 1) //Turn on godmode
			{
				if (chat)
					PrintToChat(target_list[i],"\x04[SM] \x01An admin has given you \x05God Mode\x01!");

				LogAction(client, target_list[i], "%L enabled godmode on %L", client, target_list[i]);
				g_bState[target_list[i]] = true;

				if (RAMIREZ == -1)
				{
					ReplyToCommand(client, "Unable to get %N's Marine Entity!\n Godmode not enabled!", target_list[i]);
					continue;
				}

				SDKHook(RAMIREZ, SDKHook_OnTakeDamage, OnTakeDamage);
			}
			else if (toggle == 0) //Turn off godmode
			{
				if (chat)
					PrintToChat(target_list[i],"\x04[SM] \x01An admin has removed your \x05God Mode\x01!");

				LogAction(client, target_list[i], "%L disabled godmode on %L", client, target_list[i]);
				g_bState[target_list[i]] = false;

				if (RAMIREZ == -1)
				{
					ReplyToCommand(client, "Unable to get %N's Marine Entity!\n Godmode not enabled!", target_list[i]);
					continue;
				}

				SDKUnhook(RAMIREZ, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}

	if (args == 1)
	{
		char target[32];

		GetCmdArg(1, target, sizeof(target));

		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;

		if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
			{
				ReplyToTargetError(client, target_count);
				return Plugin_Handled;
			}

		bool chat = g_Cvar_Announce.BoolValue;

		ShowActivity2(client, "\x04[SM] ","\x01Toggled God Mode on \x05%s", target_name);

		int RAMIREZ;
		for (int i = 0; i < target_count; i++)
		{
			RAMIREZ = Swarm_GetMarine(target_list[i]);
			
			if (!g_bState[target_list[i]]) // -> Turn on godmode
			{
				if (chat)
					PrintToChat(target_list[i],"\x04[SM] \x01An admin has given you \x05God Mode\x01!");

				LogAction(client, target_list[i], "%L enabled godmode on %L", client, target_list[i]);
				g_bState[target_list[i]] = true;

				if (RAMIREZ == -1)
				{
					ReplyToCommand(client, "Unable to get %N's Marine Entity!\n Godmode not enabled!", target_list[i]);
					continue;
				}

				SDKHook(RAMIREZ, SDKHook_OnTakeDamage, OnTakeDamage);
			}
			else //Turn off godmode
			{
				if (chat)
					PrintToChat(target_list[i],"\x04[SM] \x01An admin has removed your \x05God Mode\x01!");

				LogAction(client, target_list[i], "%L disabled godmode on %L", client, target_list[i]);
				g_bState[target_list[i]] = false;

				if (RAMIREZ == -1)
				{
					ReplyToCommand(client, "Unable to get %N's Marine Entity!\n Godmode not enabled!", target_list[i]);
					continue;
				}

				SDKUnhook(RAMIREZ, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}

	return Plugin_Handled;
}


public Action Command_Mortal(int client, int args)
{
	if (args != 0 && args != 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_mortal [#userid|name]");
		return Plugin_Handled;
	}

	bool isAdmin = CheckCommandAccess(client, "sm_slay", ADMFLAG_SLAY);

	if (args == 0)
	{
		int RAMIREZ = Swarm_GetMarine(client);
		
		ReplyToCommand(client,"\x01[SM] \x04You are now mortal!");
		g_bState[client] = false;
		
		if (RAMIREZ != -1)
			SDKUnhook(RAMIREZ, SDKHook_OnTakeDamage, OnTakeDamage);

		return Plugin_Handled;
	}

	if (!isAdmin)
	{
		ReplyToCommand(client, "[SM] You are not authorized to target other players");
		return Plugin_Handled;
	}


	if (args == 1)
	{
		char target[32];
		GetCmdArg(1, target, sizeof(target));

		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;

		if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
			{
				ReplyToTargetError(client, target_count);
				return Plugin_Handled;
			}

		bool chat = g_Cvar_Announce.BoolValue;

		ShowActivity2(client, "\x04[SM] ","\x01Made \x05%s\x01 mortal", target_name);

		int RAMIREZ;
		for (int i = 0; i < target_count; i++)
		{
			RAMIREZ = Swarm_GetMarine(target_list[i]);
			if (g_bState[target_list[i]]) //Not mortal
			{
				if (chat)
					PrintToChat(target_list[i],"\x04[SM] \x01An admin has made you \x05Mortal\x01!");

				LogAction(client, target_list[i], "%L made %L mortal", client, target_list[i]);
				g_bState[target_list[i]] = false;

				if (RAMIREZ == -1)
					continue;

				SDKUnhook(RAMIREZ, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}
	return Plugin_Handled;
}
/*
public OnEntityCreated(entity, const char[] classname)
{
	if (entity > MaxClients && strcmp(classname, "asw_marine") == 0)
	{
		int iClient = Swarm_GetClientOfMarine(entity);
		if (iClient > 0 && iClient <= MaxClients && g_bState[iClient])
		{
			SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		}
		
		PrintToServer("[SG] entity: %i, classname: %s, iClient: %i", entity, classname, iClient);
	}
}
*/
public void OnMarineSelected(Handle event, const char[] name, bool dontBroadcast)
{
	int new_marine = GetEventInt(event, "new_marine");
	if (new_marine <= 0)
		return;

	int client = Swarm_GetClientOfMarine(new_marine);

	if (client <= 0 || client > MaxClients)
		return;

	if (g_bState[client])
	{
		SDKHook(new_marine, SDKHook_OnTakeDamage, OnTakeDamage);
		
		int old_marine = GetEventInt(event, "old_marine");
		
		if (old_marine <= 0)
			return;
		
		SDKUnhook(old_marine, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	
//	PrintToServer("[SG] new_marine: %i, old_marine %i, iClient: %i", new_marine, old_marine, iClient);
}

public void OnPlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client <= 0)
		return;

	if (g_bState[client])
		g_bState[client] = false;
}
