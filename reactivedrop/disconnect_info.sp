#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "[ASW] Disconnect info",
	author = "Duko",
	description = "Disconnect info",
	version = "1.0",
	url = "http://group.midu.cz"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char szGameDir[PLATFORM_MAX_PATH];
	GetGameFolderName(szGameDir, sizeof(szGameDir));
	if (strcmp(szGameDir, "swarm") != 0 && strcmp(szGameDir, "reactivedrop") != 0)
	{
		strcopy(error, err_max, "This plugin is only supported on Alien Swarm");
		return APLRes_Failure;
	}

	return APLRes_Success;
}


public void OnPluginStart()
{
	HookEvent("player_disconnect", OnPlayerDisconnect);
}

public void OnPlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0)
		return;

	if (!IsClientConnected(client) || !IsClientInGame(client))
		return;

	char szReason[64];
	GetEventString(event, "reason", szReason, sizeof(szReason));
	PrintToChatAll("Player %N has left the game (%s)", client, szReason);
}
