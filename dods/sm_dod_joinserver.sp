//
// SourceMod Script
//
// Developed by Misery
//
// DECEMBER 2008
//
// Description : Sound to joinserver
//
// http://thelw.forum-actif.net
//


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.1"
//char g_szWelcomeSound[] = "joinserver/dodportal/welcomka.mp3";
//char g_szWelcomeSound[] = "Welcome_Veterans.wav";
char g_szWelcomeSound[] = "czsk_veterans/welcome.mp3";

// Plugin definitions
public Plugin myinfo = 
{
	name = "sm_dod_joinserver",
	author = "Misery",
	description = "Joinserver sound",
	version = PLUGIN_VERSION,
	url = "http://thelw.forum-actif.net"
};

public void OnPluginStart()
{
	CreateConVar("sm_dod_joinserver_version", PLUGIN_VERSION, "Joinserver sound Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
}

public void OnMapStart()
{
	char downloadFile[128];
	Format(downloadFile, sizeof(downloadFile), "sound/%s", g_szWelcomeSound);
	AddFileToDownloadsTable(downloadFile);
	PrecacheSound(g_szWelcomeSound, true);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;

	EmitSoundToClient(client, g_szWelcomeSound);
}
