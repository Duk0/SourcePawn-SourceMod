#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "[ASW] Speed Run Timer",
	author = "Duko",
	description = "Shows a mission timer.",
	version = "1.0",
	url = "http://group.midu.cz"
};

ConVar g_Cvar_SpeedRun;
ConVar g_Cvar_DefautEnable;
ConVar g_Cvar_ShowEveryMinute;

Handle g_hTimer = null;
bool showtimer[MAXPLAYERS+1] = {false, ...};
float g_flTimeStart;
char g_szTargetTime[8];
int g_iPrevTime;
bool g_bSpeedRunDetected = false;
bool g_bSpeedRunStarted = false;
int g_iSpeedRunTime;

public void OnPluginStart()
{
	g_Cvar_SpeedRun = CreateConVar("sm_speedruntimer", "0", "Default setting for players. 1 - timer enabled, 0 - timer disabled", 0, true, 0.0, true, 1.0);
	g_Cvar_DefautEnable = CreateConVar("sm_speedruntimer_defautenable", "1", "Show welcome message.", 0, true, 0.0, true, 1.0);
	g_Cvar_ShowEveryMinute = CreateConVar("sm_speedruntimer_everyminute", "1", "Show information in chat about every passed minute.", 0, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_timer", Command_Timmer);
	RegAdminCmd("sm_missiontimer", CmdToggleTimer, ADMFLAG_KICK, "Toggle timer for all players");
	AddCommandListener(Command_Start, "cl_start");
	
	g_Cvar_SpeedRun.AddChangeHook(SpeedRunChange);
	HookEvent("mission_success", MissionEnd_PrintResult);
	HookEvent("player_fullyjoined", OnPlayerFullyJoined);
	
	//AutoExecConfig(true, "as_speedruntimer");
}

public void OnMapStart()
{
	g_bSpeedRunDetected = false;
	g_bSpeedRunStarted = false;

	if (g_Cvar_SpeedRun.BoolValue)
		DetectSpeedRun(false);
}

public void SpeedRunChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 1)
	{
		DetectSpeedRun(true);

		if (g_Cvar_DefautEnable.BoolValue)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i))
					continue;
				
				showtimer[i] = true;
			}
		}
	}
	else
	{
		if (g_bSpeedRunStarted)
		{
			if (g_hTimer != null)
				KillTimer(g_hTimer);

			g_hTimer = null;
		}

		g_bSpeedRunDetected = false;
		g_bSpeedRunStarted = false;
	}
}

void DetectSpeedRun(bool print=false)
{
	g_iSpeedRunTime = 0;

	int ent = FindEntityByClassname(-1, "asw_gamerules");
	if (ent != -1)
	{
		g_iSpeedRunTime = GetEntProp(ent, Prop_Data, "m_iSpeedrunTime");
		if (g_iSpeedRunTime > 0)
		{
			g_flTimeStart = GetGameTime();
			g_iPrevTime = 0;
			g_bSpeedRunDetected = true;

			FormatEx(g_szTargetTime, sizeof(g_szTargetTime), "%d:%02d", g_iSpeedRunTime / 60, g_iSpeedRunTime % 60);
			//PrintToServer("[SRT] Found asw_gamerules, g_iSpeedRunTime: %s", g_szTargetTime);
			if (print)
				PrintToChatAll("Speed Run Mission is detected (Target: %s), say '!timer' to toggle timer for you.", g_szTargetTime);
		}
	}
}

public void OnMapEnd()
{
	if (g_bSpeedRunStarted)
	{
		if (g_hTimer != null)
			KillTimer(g_hTimer);

		g_hTimer = null;
	}
}

public void OnPlayerFullyJoined(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_Cvar_SpeedRun.BoolValue)
		return;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0)
		return;

	showtimer[client] = false;

	if (g_bSpeedRunDetected)
	{
		CreateTimer(2.0, WelcomePlayer, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}
/*
public void OnClientPutInServer(client)
{
	if (!g_Cvar_SpeedRun.BoolValue)
		return;

	if (g_bSpeedRunDetected)
	{
		CreateTimer(7.0, WelcomePlayer, client, TIMER_FLAG_NO_MAPCHANGE);
		showtimer[client] = false;
	}
}
*/
public Action WelcomePlayer(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		if (g_Cvar_DefautEnable.BoolValue)
			showtimer[client] = true;

		PrintToChat(client, "Speed Run Mission is detected (Target: %s), say '!timer' to toggle timer for you.", g_szTargetTime);
	}
}

public Action Command_Start(int client, const char[] command, int argc)
{
	if (g_bSpeedRunDetected && !g_bSpeedRunStarted)
	{
		float offset = 0.5;
		g_bSpeedRunStarted = true;
		g_flTimeStart = GetGameTime() + offset;
		g_iPrevTime = 0;
		g_hTimer = CreateTimer(0.9, PrintTime, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action PrintTime(Handle timer)
{
	int time = RoundToNearest(g_flTimeStart - GetGameTime() + g_iSpeedRunTime);
	if (time == g_iPrevTime)
	{
		g_iPrevTime = time;
		return Plugin_Continue;
	}

	g_iPrevTime = time;

	int mins = time / 60;
	int secs = time % 60;
	if (g_Cvar_ShowEveryMinute.BoolValue)
	{
		if (mins == 1 && secs == 0)
		{
			//PrintToChatAll("%i minute has passed!", mins);
			PrintToChatAll("%i minute left!", mins);
		}
		else if (mins > 1 && secs == 0)
		{
			//PrintToChatAll("%i minutes have passed!", mins);
			PrintToChatAll("%i minutes left!", mins);
		}
	}
/*
	if (secs < 10)
	{
		FormatEx(sTime, 32, "%d:0%d", mins, secs);
	}
	else
	{
		FormatEx(sTime, 32, "%d:%d", mins, secs);
	}
*/
	char sTime[16];
	FormatEx(sTime, sizeof(sTime), "%d:%02i", mins, secs);
	//SetHudTextParams(0.98, 1.0, 1.0, 0, 200, 255, 255, 0, 6.0, 0.1, 0.2);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (!showtimer[i])
			continue;

		PrintCenterText(i, sTime);
		//ShowHudText(i, 4, "Time: %s (Target: %s)", sTime, g_szTargetTime);
		//ShowHudText(i, -1, sTime);
	}
	//if (time > g_iSpeedRunTime)
	if (time <= 0)
	{
		//PrintToChatAll("Speed Run Failed! Your time passed over %s", g_szTargetTime);
		PrintToChatAll("Speed Run Failed! Run out of time (%s)", g_szTargetTime);
		//KillTimer(timer);
		g_hTimer = null;
		//g_bSpeedRunStarted = false;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action CmdToggleTimer(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_missiontimer <on|off>");
		return Plugin_Handled;
	}

	char strarg[4];
	GetCmdArg(1, strarg, sizeof(strarg));

	int onoff = -1;
	if (strcmp(strarg, "on") == 0)
		onoff = 1;
	else if (strcmp(strarg, "off") == 0)
		onoff = 0;

	if (onoff == -1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_missiontimer <on|off>");
		return Plugin_Handled;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (onoff == 1)
				showtimer[i] = true;
			else
				showtimer[i] = false;
		}
	}

	if (onoff == 0)
		PrintToChatAll("Admin Disabled Mission Timer for all players, say '!timer' to enable it for you.");
	else
		PrintToChatAll("Admin Enabled Mission Timer for all players, say '!timer' to disable it for you.");

	return Plugin_Handled;
}

public Action MissionEnd_PrintResult(Handle event, char[] name, bool dontBroadcast)
{
	if (g_bSpeedRunDetected && g_bSpeedRunStarted)
	{
		if (g_hTimer != null)
		{
			KillTimer(g_hTimer);
			g_hTimer = null;
		}
	}
}

public Action Command_Timmer(int client, int args)
{
	if (showtimer[client])
	{
		showtimer[client] = false;
		PrintToChat(client, "Speed Run Timer is disabled, say '!timer' to enable it for you.");
	}
	else
	{
		showtimer[client] = true;
		PrintToChat(client, "Speed Run Timer is enabled, say '!timer' to disable it for you.");
	}
	return Plugin_Handled;
}
