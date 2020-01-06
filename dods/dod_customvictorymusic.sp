#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"1.1"

public Plugin myinfo =
{
	name = "DoD Custom Victory Music",
	author = "Duko",
	description = "Change the Round Win Music!",
	version = PLUGIN_VERSION,
	url = "http://midu.cz"
}

char g_szSoundUSWin[] = "czsk_veterans/russian.mp3";
char g_szSoundGermanWin[] = "czsk_veterans/german.mp3";

ConVar g_Cvar_VictoryMusic;

public void OnPluginStart()
{
	g_Cvar_VictoryMusic = CreateConVar("dod_victorymusic", "1", "<1/0> = enable/disable changing the victory music", _, true, 0.0, true, 1.0);
	HookEventEx("dod_broadcast_audio", OnBroadcastAudio, EventHookMode_Pre);
}

public void OnMapStart()
{
	PrecacheSound(g_szSoundUSWin);
	PrecacheSound(g_szSoundGermanWin);
	char downloadFile[192];
	Format(downloadFile, sizeof(downloadFile), "sound/%s", g_szSoundUSWin);
	AddFileToDownloadsTable(downloadFile);
	Format(downloadFile, sizeof(downloadFile), "sound/%s", g_szSoundGermanWin);
	AddFileToDownloadsTable(downloadFile);
}

public Action OnBroadcastAudio(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_Cvar_VictoryMusic.BoolValue)
		return Plugin_Continue;

	char sound[128];
	GetEventString(event, "sound", sound, sizeof(sound));

	if (strcmp(sound, "Game.USWin", true) == 0)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && !IsFakeClient(client))
			{
				EmitSoundToClient(client, g_szSoundUSWin);
				//ClientCommand(client, "playgamesound \"%s\"", g_szSoundUSWin);
			}
		}
		return Plugin_Handled;
	}
	else if (strcmp(sound, "Game.GermanWin", true) == 0)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && !IsFakeClient(client))
			{
				EmitSoundToClient(client, g_szSoundGermanWin);
				//ClientCommand(client, "playgamesound \"%s\"", g_szSoundGermanWin);
			}
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
