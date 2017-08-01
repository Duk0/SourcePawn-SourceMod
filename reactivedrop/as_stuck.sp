#include <sourcemod>
#include <sdktools>
#include <swarmtools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "[ASW] Stuck",
	author = "Duko",
	description = "Stuck",
	version = "1.0",
	url = "http://group.midu.cz"
};

ConVar g_Cvar_StuckWaitTime;
//ConVar g_Cvar_MarineCollision;

float g_stucklastused[MAXPLAYERS + 1] = {0.0, ...};
int g_newmarine[MAXPLAYERS + 1] = {0, ...};

public void OnPluginStart()
{
	RegConsoleCmd("sm_stuck", Command_Stuck);
	g_Cvar_StuckWaitTime = CreateConVar("sm_stuck_delay", "5", "Time to wait until Player can use stuck again.", 0, true, 0.2, true, 120.0);
//	g_Cvar_MarineCollision = FindConVar("asw_marine_collision");
	HookEvent("marine_selected", OnMarineSelected);
}

public void OnMarineSelected(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int new_marine = GetEventInt(event, "new_marine");
	if (client > 0 && new_marine > 0)
		g_newmarine[client] = new_marine;
}

public void OnClientPutInServer(int client)
{
	g_newmarine[client] = 0;
}

public Action Command_Stuck(int client, int args)
{
/*	if (g_Cvar_MarineCollision.IntValue == 1)
		return Plugin_Handled;*/

/*
	int marine = Swarm_GetMarine(client);
	if (marine == -1)
	{
		PrintToChat(client, "[STUCK] Your marine not found.");
		return Plugin_Handled;
	}
*/

	int marine = g_newmarine[client];
	if (!IsValidEntity(marine) || marine == 0)
	{
		PrintToChat(client, "[STUCK] Your marine not found. Invalid index of marine: %i", marine);
		return Plugin_Handled;
	}
	if (Swarm_GetClientOfMarine(marine) != client)
	{
		PrintToChat(client, "[STUCK] Your marine not found.");
		return Plugin_Handled;
	}

	float curtime = GetTickedTime();
	float elapsedtime = curtime - g_stucklastused[client];
	float minfrequency = g_Cvar_StuckWaitTime.FloatValue;
	if (elapsedtime < minfrequency)
	{
		PrintToChat(client, "[STUCK] You must wait %.1f seconds.", minfrequency - elapsedtime);
		return Plugin_Handled;
	}

	g_stucklastused[client] = curtime;

	int index = -1;
	int count = -1;
	int entmarine[8] = {0, ...};
	while ((index = FindEntityByClassname(index, "asw_marine")) != -1)
	{
		if (index == marine)
			continue;

		count++;
		entmarine[count] = index;
	}

	int entity = -1;
	if (count == -1)
	{
		PrintToChat(client, "[STUCK] Prd.");
		return Plugin_Handled;
	}
	else if (count == 0)
		entity = entmarine[0];
	else
		entity = entmarine[GetRandomInt(0, count)];

	if (entity == -1)
		return Plugin_Handled;

	float origin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	TeleportEntity(marine, origin, NULL_VECTOR, NULL_VECTOR);

	//PrintToChat(client,"[STUCK] marine: %i, count: %i, entity: %i, origin: %.0f %.0f %.0f", marine, count, entity, origin[0], origin[1], origin[2]);

	return Plugin_Handled;
}