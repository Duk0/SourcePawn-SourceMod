#include <sourcemod>
#include <geoip>

#pragma semicolon 1
#pragma newdecls required

ConVar g_Cvar_ConnectAnnounce;

public Plugin myinfo = 
{
	name = "Geoip connect info",
	author = "Duko",
	description = "Geoip",
	version = "1.1",
	url = "http://group.midu.cz"
};

public void OnPluginStart()
{
	g_Cvar_ConnectAnnounce = CreateConVar("sm_connectannounce", "1", "Announce connections");
	HookEvent("player_fullyjoined", OnClientFullyJoined, EventHookMode_Pre);
}

public void OnClientFullyJoined(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0)
		return;

	if (dontBroadcast)
		return;

	JoinMessage(client);
	SetEventBroadcast(event, true);
}

void JoinMessage(int client)
{
	if (!g_Cvar_ConnectAnnounce.BoolValue)
		return;

	if (IsFakeClient(client))
		return;

	char ip[32];
	char authid[32];
	char country[64];
	GetClientAuthId(client, view_as<AuthIdType>(AuthId_Steam2), authid, sizeof(authid));
	GetClientIP(client, ip, sizeof(ip));

	if (GeoipCountry(ip, country, sizeof(country)) == false)
	{
		if (strncmp(ip, "10.", 3) == 0 || strncmp(ip, "192.168.", 8) == 0)
			strcopy(country, sizeof(country), "Slovakia");
		else
			strcopy(country, sizeof(country), "Unknown (We have a pirate here :P)");
	}

	if (authid[7] == ':')
	{
		PrintToChatAll("\x01\x04%N (\x01%s\x04) connected from %s", client, authid, country);
		//PrintToConsoleAll("[GEO] %N (%s) connected from %s", client, authid, country);
		PrintToServer("[GEO] %N (%s) connected from %s", client, authid, country);
	}
	else
	{
		PrintToChatAll("\x01\x04%N (\x01STEAM_ID_PENDING\x04) connected from %s", client, country);
		//PrintToConsoleAll("[GEO] %N (STEAM_ID_PENDING) connected from %s", client, country);
		PrintToServer("[GEO] %N (STEAM_ID_PENDING) connected from %s", client, country);
	}
}
