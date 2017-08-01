#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "[ASW] Music Finder",
	author = "Duko",
	description = "Music Finder",
	version = "1.0",
	url = "http://group.midu.cz"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_searchmusic", Command_SearchMusic, "Music Finder", ADMFLAG_KICK);
}

public Action Command_SearchMusic(int client, int args)
{
	int index = -1;
	int music = 0;
	char targetname[32], defaultmusic[64];
	while ((index = FindEntityByClassname(index, "asw_jukebox")) != -1)
	{
		music++;
		GetEntPropString(index, Prop_Data, "m_iName", targetname, sizeof(targetname));
		GetEntPropString(index, Prop_Data, "m_szDefaultMusic", defaultmusic, sizeof(defaultmusic));
		PrintToConsole(client, "[MF] %3i. targetname: %12s defaultmusic: %s", music, targetname, defaultmusic);
	}
	//PrintToConsole(client, "[MF] asw_jukebox total: %i", music);

	return Plugin_Handled;
}