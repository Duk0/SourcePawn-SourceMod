#include <sourcemod>
#include <sdktools>
#include <swarmtools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[ASW] Goto",
	author = "Duko",
	description = "Goto",
	version = "1.0",
	url = "http://group.midu.cz"
};

ConVar g_Cvar_Goto;
bool g_bAllowGoto[MAXPLAYERS+1] = {true, ...};

public void OnPluginStart()
{
	g_Cvar_Goto = CreateConVar("sm_goto_enable", "1");
	RegConsoleCmd("sm_goto", Command_Goto);
	RegConsoleCmd("sm_nogoto", Command_NoGoto);
	
	LoadTranslations("common.phrases");
}

public Action Command_Goto(int client, int args)
{
	if (!g_Cvar_Goto.BoolValue)
	{
		PrintToClient(client, "[ASW] Goto Disabled!");
		return Plugin_Handled;
	}

    //Error:
	if (args < 1)
	{
		//Print:
		PrintToClient(client, "Usage: sm_goto <name>");

		//Return:
		return Plugin_Handled;
	}

	int client_marine = Swarm_GetMarine(client);
	if (!IsClientConnected(client) || !IsClientInGame(client) || client_marine <= 0)
		return Plugin_Handled;
	
	//Declare:
	int target = -1, count = 0;
	char szPartName[32], szPlayerName[32];
	
	//Initialize:
	GetCmdArg(1, szPartName, sizeof(szPartName));
	
	//Find:
	for (int i = 1; i <= MaxClients; i++)
	{
		//Connected:
		if (!IsClientConnected(i) || !IsClientInGame(i))
			continue;

		//Initialize:
		GetClientName(i, szPlayerName, sizeof(szPlayerName));

		//Save:
		if (StrContains(szPlayerName, szPartName, false) == -1)
			continue;

		target = i;
		count++;
	}
	
	//Invalid Name:
	if (target == -1)
	{
		//Print:
		PrintToClient(client, "Could not find client %s", szPartName);

		//Return:
		return Plugin_Handled;
	}

	if (client == target)
		return Plugin_Handled;

	// Name:
	if (count > 1)
	{
		//Print:
		PrintToClient(client, "[ASW] %T", "More than one client matched", LANG_SERVER);

		//Return:
		return Plugin_Handled;
	}

	int target_marine = Swarm_GetMarine(target);
	if (target_marine <= 0)
	{
		PrintToClient(client, "[ASW] The Player %N is dead", target);
		return Plugin_Handled;
	}
	
	if (!g_bAllowGoto[target] || IsFakeClient(target))
	{
		PrintToClient(client, "[ASW] The Player %N disabled goto", target);
		return Plugin_Handled;
	}

	PrintToChat(target, "[ASW] To disable/enable goto type !nogoto");

	//Teleport
	float origin[3];
	GetEntPropVector(target_marine, Prop_Send, "m_vecOrigin", origin);
	TeleportEntity(client_marine, origin, NULL_VECTOR, NULL_VECTOR);

	PrintToChat(client, "[ASW] Teleported to %N", target);

	return Plugin_Handled;
}

public Action Command_NoGoto(int client, int args)
{
	if (!g_Cvar_Goto.BoolValue)
		return Plugin_Handled;

	if (g_bAllowGoto[client])
		PrintToClient(client,"[ASW] Nobody can teleport to you now.");
	else
		PrintToClient(client,"[ASW] Players can teleport to you now.");
	
	g_bAllowGoto[client] = !g_bAllowGoto[client];
	
	return Plugin_Handled;
}

void PrintToClient(int client, const char[] format, any ...)
{
	char buffer[254];
	SetGlobalTransTarget(client);
	VFormat(buffer, sizeof(buffer), format, 3);

	if (IsChatTrigger())
		PrintToChat(client, buffer);
	else
		PrintToConsole(client, buffer);
}
