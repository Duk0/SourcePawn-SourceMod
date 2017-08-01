#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Ent Count",
	author = "Duko",
	description = "Ent Count",
	version = "1.0",
	url = "http://group.midu.cz"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_entcount", Command_EntCount, ADMFLAG_CHEATS);
}

public Action Command_EntCount(int client, int args)
{
	int index = -1, networked = 0, non_networked = 0;
	while ((index = FindEntityByClassname(index, "*")) != -1)
	{
		if (IsEntNetworkable(index))
		{
			networked++;
			continue;
		}
		
		non_networked++;
	}

	PrintToConsole(client, "[EC] Total: Networked %i, Non-networked %i", networked, non_networked);

	return Plugin_Handled;
}
