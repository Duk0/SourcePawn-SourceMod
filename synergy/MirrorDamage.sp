// thx Sheepdude for advice
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.2"

ConVar g_Cvar_Multiplier;
ConVar g_Cvar_SlapPlayer;
ConVar g_Cvar_Notice;

public Plugin myinfo = {
	name = "MirrorDamage",
	author = "Neatek, Duko",
	description = "Simple plugin for mirror friendlyfire",
	version = PLUGIN_VERSION,
	url = "http://www.neatek.ru/"
};

public void OnPluginStart()
{
	CreateConVar("sm_mirrordamage_version", PLUGIN_VERSION, "Version of MirrorDamage plugin", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_Cvar_Multiplier = CreateConVar("sm_mirrordamage_multiplier", "0.7", "Amount of damage to inflict to attacker, def 70%", _, true, 0.1);
	g_Cvar_SlapPlayer = CreateConVar("sm_mirrordamage_slap", "1", "Slap attacker?! or just subtraction health", _, true, 0.0, true, 1.0);
	g_Cvar_Notice = CreateConVar("sm_mirrordamage_notice", "0", "Print in chat about friendly attack", _, true, 0.0, true, 1.0);

	for (int i = 1; i <= MaxClients; i++) // updated, thx Sheepdude
	{
		if (!IsInGame(i))
			continue;

		SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void OnPluginEnd() // updated, thx Sheepdude
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsInGame(i))
			continue;

		SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

// try to check ;)
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsPlayer(victim) || !IsPlayer(attacker) || victim == attacker)
		return Plugin_Continue;

	if (GetClientTeam(victim) != GetClientTeam(attacker))
		return Plugin_Continue;

	char classname[24]; //npc_grenade_frag
	if (IsValidEdict(inflictor))
	{
		GetEdictClassname(inflictor, classname, sizeof(classname));
		if (StrEqual(classname, "npc_grenade_frag") || StrEqual(classname, "npc_manhack") || StrEqual(classname, "rpg_missile"))
			return Plugin_Continue;
	}

	if (damage <= 0 || !IsPlayerAlive(attacker))
		return Plugin_Continue;

	int health;
	if ((health = GetClientHealth(attacker)) <= 0)
		return Plugin_Continue;

	if (damage > 100.0)
		CreateTimer(0.0, SlayTimer, attacker, TIMER_FLAG_NO_MAPCHANGE); // updated, thx Sheepdude
	else
	{
		int mirrordamage = (health - RoundFloat(damage * g_Cvar_Multiplier.FloatValue));
		if (mirrordamage < 0)
			CreateTimer(0.0, SlayTimer, attacker, TIMER_FLAG_NO_MAPCHANGE); // updated, thx Sheepdude
		else 
		{
			if (!g_Cvar_SlapPlayer.BoolValue)
				SetEntityHealth(attacker, mirrordamage);
			else
				SlapPlayer(attacker, mirrordamage, true);
		}
	}

	if (g_Cvar_Notice.BoolValue)
		PrintToChatAll("%N attacked a teammate %N with: %s", attacker, victim, classname);
	else
		PrintToConsoleAll("%N attacked a teammate %N with: %s", attacker, victim, classname);

	return Plugin_Handled;
}

public Action SlayTimer(Handle timer, any data)
{
	ForcePlayerSuicide(data);
	
	return Plugin_Stop;
}

stock bool IsInGame(int client)
{
	if (IsClientConnected(client) && IsClientInGame(client))
		return true;

	return false;
}

stock bool IsPlayer(int client)
{
	if (!IsValidEdict(client))
		return false;
	
	if (client < 1 || MaxClients < client)
		return false;
	
	return true;
}
/*
stock void PrintToConsoleAll(const char[] format, any ...)
{
	char buffer[254];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintToConsole(i, buffer);
		}
	}
}
*/
