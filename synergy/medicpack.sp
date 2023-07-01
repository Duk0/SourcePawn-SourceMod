#include <sourcemod>

public Plugin myinfo = 
{
	name = "Medic Pack",
	author = "Duko",
	description = "Medic Pack",
	version = "1.0",
	url = "http://www.sourcemod.net"
}

int g_iHealthPack;

public void OnPluginStart()
{
	g_iHealthPack = FindSendPropInfo("CSynergyPlayer", "m_iHealthPack");

	if (g_iHealthPack == -1)
		SetFailState("Offest m_iHealthPack not found.");

	HookEventEx("player_spawn", OnSpawnPlayer, EventHookMode_Post);
}

public void OnConfigsExecuted()
{
	if (g_iHealthPack != -1)
		CreateTimer(3.0, Timer_MedicPack, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_MedicPack(Handle timer)
{
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
			continue;

		int medkitammo = GetEntData(client, g_iHealthPack, 4);
		if (medkitammo == -1 || medkitammo == 100)
			continue;
		
		if (medkitammo <= 95)
			SetEntData(client, g_iHealthPack, medkitammo + 5, 4, true);
		else
			SetEntData(client, g_iHealthPack, 100, 4, true);
    }
	
	return Plugin_Continue;
}

public void OnSpawnPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client <= 0 || !IsClientInGame(client))
		return;
	
	SetEntData(client, g_iHealthPack, 50, 4, true);
}
