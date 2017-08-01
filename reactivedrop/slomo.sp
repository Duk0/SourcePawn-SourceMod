#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "[ASW] Slow Motion",
	author = "Duko",
	description = "Slow Motion",
	version = "1.0",
	url = "http://group.midu.cz"
};

char commands[][] = { "ASW_PermaStim", "ASW_PermaStimStop", "asw_StartStim" };
bool g_bMusic = false;
Handle g_hMusicTimer = null;
Handle g_hSlomoTimer = null;
ConVar g_Cvar_StimTimeScale;

public void OnPluginStart()
{
	for (int i = 0; i < sizeof(commands); i++)
	{
		SetCommandFlags(commands[i], GetCommandFlags(commands[i]) & ~FCVAR_CHEAT);
	}

	AddCommandListener(cmdASWStim, "ASW_PermaStim");
	AddCommandListener(cmdASWStim, "ASW_PermaStimStop");
	AddCommandListener(cmdASWStim, "asw_StartStim");
	
	g_Cvar_StimTimeScale = FindConVar("asw_stim_time_scale");

	RegAdminCmd("sm_slomo", Command_SloMo, ADMFLAG_CHEATS);
}

public Action cmdASWStim(int client, const char[] command, int argc)
{
	if (client != 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnMapStart()
{
	if (g_bMusic)
		g_bMusic = false;

	g_hSlomoTimer = null;
	g_hMusicTimer = null;
}

public Action Command_SloMo(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_slomo <3.5-240.0> or stop");
		return Plugin_Handled;
	}

	if (g_hSlomoTimer != null)
		return Plugin_Handled;

	char strarg[6];
	GetCmdArg(1, strarg, sizeof(strarg));

	if (strcmp(strarg, "stop") == 0)
	{
		PrintToChatAll("[SLOMO] Stoping...");

		if (g_hSlomoTimer != null)
			KillTimer(g_hSlomoTimer);

		SloMoTimer(null);

		return Plugin_Handled;
	}
	else if (strcmp(strarg, "start") == 0)
	{
		ServerCommand("asw_StartStim");
		PrintToChatAll("[SLOMO] Started.");
		return Plugin_Handled;
	}
	else if (strcmp(strarg, "perma") == 0)
	{
		ServerCommand("ASW_PermaStim");
		PrintToChatAll("[SLOMO] Started: Permanent");

		g_bMusic = true;

		if (g_hMusicTimer != null)
			KillTimer(g_hMusicTimer);

		g_hMusicTimer = CreateTimer(30.0 * g_Cvar_StimTimeScale.FloatValue, MusicTimer, _, TIMER_FLAG_NO_MAPCHANGE);

		return Plugin_Handled;
	}

	//new duration = StringToInt(strarg)
	float duration = StringToFloat(strarg);

	if (duration < 3.5 || duration > 240.0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_slomo <3.5-240.0>");
		return Plugin_Handled;
	}

	//MusicTimer(null);

	ServerCommand("ASW_PermaStim");

	float timescale = g_Cvar_StimTimeScale.FloatValue;

	if (duration > 30.0)
	{
		g_bMusic = true;

		if (g_hMusicTimer != null)
			KillTimer(g_hMusicTimer);

		g_hMusicTimer = CreateTimer(30.0 * timescale, MusicTimer, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	g_hSlomoTimer = CreateTimer(duration * timescale, SloMoTimer, _, TIMER_FLAG_NO_MAPCHANGE);

	PrintToChatAll("[SLOMO] Started: %.1fs", duration);

	return Plugin_Handled;
}

public Action SloMoTimer(Handle timer)
{
	if (g_bMusic)
		g_bMusic = false;

	ServerCommand("ASW_PermaStimStop");
	g_hSlomoTimer = null;

	if (g_hMusicTimer != null)
		KillTimer(g_hMusicTimer);

	g_hMusicTimer = null;
}

public Action MusicTimer(Handle timer)
{
	if (!g_bMusic)
		return Plugin_Stop;

	float timescale = g_Cvar_StimTimeScale.FloatValue;
	switch (GetRandomInt(1, 4))
	{
		case 1:
		{
			PlayMusic("asw_song.stims");
			timescale *= 30.0;
		}
		case 2:
		{
			PlayMusic("asw_song.elevatorMusic");
			timescale *= 171.0;
		}
		case 3:
		{
			PlayMusic("asw_song.RydbergRumble");
			timescale *= 83.0;
		}
		case 4:
		{
			PlayMusic("asw_song.TimorBattle");
			timescale *= 139.0;
		}
	}
	
	g_hMusicTimer = CreateTimer(timescale, MusicTimer, _, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Stop;
}

void PlayMusic(const char[] music)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		ClientCommand(i, "playgamesound %s", music);
	}	
}