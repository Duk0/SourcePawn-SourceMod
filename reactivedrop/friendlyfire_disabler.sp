#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <swarmtools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION		"1.2"

ConVar g_Cvar_FriendlyFire;
bool g_bEnabled;
//bool g_bLate;

public Plugin myinfo = 
{
	name = "[ASW] Friendlyfire disabler",
	author = "FrozDark (HLModders.ru LLC)",
	description = "Friendlyfire disabler",
	version = PLUGIN_VERSION,
	url = "www.hlmod.ru"
};
/*
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, err_max)
{
	g_bLate = late;
	
	return APLRes_Success;
}
*/
public void OnPluginStart()
{
	CreateConVar("asw_ffdisabler_version", PLUGIN_VERSION, "The plugin's version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);
	g_Cvar_FriendlyFire = FindConVar("mp_friendlyfire");
	
	g_bEnabled = g_Cvar_FriendlyFire.BoolValue;
	g_Cvar_FriendlyFire.AddChangeHook(OnCvarChange);
/*	
	HookEvent("marine_selected", OnMarineSelected);
	
	if (g_bLate)
	{
		int marine;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				marine = Swarm_GetMarine(i);
				if (IsValidMarineOrSentry(marine))
					SDKHook(marine, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}
*/
}
/*
public void OnMarineSelected(Handle event, const char[] name, bool dontBroadcast)
{
	int new_marine = GetEventInt(event, "new_marine");
	int old_marine = GetEventInt(event, "old_marine");
	
	if (new_marine > 0)
		SDKHook(new_marine, SDKHook_OnTakeDamage, OnTakeDamage);
	if (old_marine > 0)
		SDKUnhook(old_marine, SDKHook_OnTakeDamage, OnTakeDamage);
}
*/

public void OnMapStart()
{
	if (!g_bEnabled && FindEntityByClassname(-1, "asw_deathmatch_mode") != -1)
		g_bEnabled = true;
	else if (g_bEnabled)
		g_bEnabled = g_Cvar_FriendlyFire.BoolValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > MaxClients)
	{
		if (strcmp(classname, "asw_marine") == 0)
		{
			SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
			//PrintToServer("[FFD] c entity: %i, classname: %s", entity, classname);
		}
	}
}

public void OnCvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bEnabled = view_as<bool>(StringToInt(newValue));
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_bEnabled)
		return Plugin_Continue;

/*	char classname[32], targetname[32];
	if (IsValidEdict(attacker))
	{
		GetEdictClassname(attacker, classname, sizeof(classname));
		GetEntPropString(attacker, Prop_Data, "m_iName", targetname, sizeof(targetname));
	}

	if (strncmp(classname, "asw_sentry_", 11) == 0)
		PrintToServer("[FFD] victim: %i, attacker: %i, inflictor: %i, classname: %s, targetname: %s", victim, attacker, inflictor, classname, targetname);*/

	if (attacker && IsValidMarineOrSentry(attacker))
		return Plugin_Stop;
		//return Plugin_Handled;
		
	return Plugin_Continue;
}

bool IsValidMarineOrSentry(int marine)
{
	if (!IsValidEdict(marine))
		return false;
	
	char classname[16];
	GetEdictClassname(marine, classname, sizeof(classname));
	
	if (strcmp(classname, "asw_marine") == 0)
		return true;

	if (strncmp(classname, "asw_sentry_top_", 15) == 0)
		return true;
	
	return false;
}
