/*
 ----------------------------------------------------------------
 Plugin      : SaveChat 
 Author      : citkabuto
 Game        : Any Source game
 Description : Will record all player messages to a file
 ================================================================
 Date       Version  Description
 ================================================================
 23/Feb/10  1.2.1    - Fixed bug with player team id
 15/Feb/10  1.2.0    - Now records team name when using cvar
                            sm_record_detail 
 01/Feb/10  1.1.1    - Fixed bug to prevent errors when using 
                       HLSW (client index 0 is invalid)
 31/Jan/10  1.1.0    - Fixed date format on filename
                       Added ability to record player info
                       when connecting using cvar:
                            sm_record_detail (0=none,1=all:def:1)
 28/Jan/10  1.0.0    - Initial Version 
 ----------------------------------------------------------------
*/

#include <sourcemod>
#include <sdktools>
#include <geoip>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "SaveChat_1.2.1"
#define SAVECHAT_LOGPATH "/chat_logs/chat_%s.log"

ConVar g_Cvar_RecordDetail;
ConVar g_Cvar_Teams;

static char g_szChatFile[128];
File g_hFile = null;
char g_szDateCheck[21];

/*
char geoipFile[64];
int timestamp;
*/
public Plugin myinfo = 
{
	name = "SaveChat",
	author = "citkabuto",
	description = "Records player chat messages to a file",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=117116"
};

public void OnPluginStart()
{
	char date[21];
	char logFile[100];
	char dirPath[64];

	/* Register CVars */
	CreateConVar("sm_savechat_version", PLUGIN_VERSION, "Save Player Chat Messages Plugin", FCVAR_DONTRECORD|FCVAR_REPLICATED);

	g_Cvar_RecordDetail = CreateConVar("sc_record_detail", "1", "Record player Steam ID and IP address");

	g_Cvar_Teams = CreateConVar("sc_teamplay", "0", "Enambe Teamplay log");

	/* Say commands */
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_SayTeam);

	/* Format date for log filename */
	FormatTime(date, sizeof(date), "%Y%m%d", -1);

	/* Create name of logfile to use */
	Format(logFile, sizeof(logFile), SAVECHAT_LOGPATH, date);
	BuildPath(Path_SM, g_szChatFile, PLATFORM_MAX_PATH, logFile);

	BuildPath(Path_SM, dirPath, sizeof(dirPath), "/chat_logs");
	if (!DirExists(dirPath))
		CreateDirectory(dirPath, FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC|FPERM_G_READ|FPERM_G_EXEC|FPERM_O_READ|FPERM_O_EXEC);
/*
	BuildPath(Path_SM, geoipFile, sizeof(geoipFile), "/configs/geoip/GeoIP.dat");
	timestamp = GetFileTime(geoipFile, FileTime_Created);
	//timestamp = GetFileTime(geoipFile, FileTime_LastChange);
*/
}

/*
 * Capture player chat and record to file
 */
public Action Command_Say(int client, int args)
{
	if (client == 0 || IsClientInGame(client))
		LogChat(client, false);

	return Plugin_Continue;
}

/*
 * Capture player team chat and record to file
 */
public Action Command_SayTeam(int client, int args)
{
	if (client == 0 || IsClientInGame(client))
		LogChat(client, true);

	return Plugin_Continue;
}

//public void OnClientPostAdminCheck(int client)
public void OnClientPutInServer(int client)
{
	/* Only record player detail if CVAR set */
	if (!g_Cvar_RecordDetail.BoolValue)
		return;

	if (IsFakeClient(client)) 
		return;

	char msg[2048];
	char time[21];
	char country[3];
	char playerName[32];
	char steamID[128];
	char playerIP[50];

	GetClientName(client, playerName, sizeof(playerName));
	GetClientAuthId(client, view_as<AuthIdType>(AuthId_Steam2), steamID, sizeof(steamID));

	/* Get 2 digit country code for current player */
	if (!GetClientIP(client, playerIP, sizeof(playerIP), true))
	{
		Format(country, sizeof(country), "??");
	} 
	else 
	{
		if (!GeoipCode2(playerIP, country)) 
			Format(country, sizeof(country), "??");
	}

	FormatTime(time, sizeof(time), "%H:%M:%S", -1);
	//Format(msg, sizeof(msg), "[%s] [%s] %-35N *** has joined (%s | %s)", time, country, client, steamID, playerIP);

	Format(msg, sizeof(msg), "[%s] [%s] %s *** has joined (%s | %s)", time, country, playerName, steamID, playerIP);

	SaveMessage(msg);
/*
	if (StrEqual(country, "??"))
	{
		if (timestamp != GetFileTime(geoipFile, FileTime_Created))
		{
			
		}
	}
*/
}

/*
 * Extract all relevant information and format 
 */
void LogChat(int client, bool teamchat)
{
	char msg[2048];
	char time[21];
	char text[1024];
	char country[3];
	char playerName[32];
	char playerIP[50];
	char teamName[20];

	char date[21];
	FormatTime(date, sizeof(date), "%Y%m%d", -1);
	if (!StrEqual(date, g_szDateCheck))
	{
		char logFile[100];
		Format(logFile, sizeof(logFile), SAVECHAT_LOGPATH, date);
		BuildPath(Path_SM, g_szChatFile, PLATFORM_MAX_PATH, logFile);
	}

	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	ReplaceString(text, sizeof(text), "%", "%%");

	if (client == 0)
	{
		/* Don't try and obtain client country/team if this is a console message */
		Format(playerName, sizeof(playerName), "Console");
		Format(country, sizeof(country), "##");
		Format(teamName, sizeof(teamName), "");
	}
	else
	{
		GetClientName(client, playerName, sizeof(playerName));

		/* Get 2 digit country code for current player */
		if (!GetClientIP(client, playerIP, sizeof(playerIP), true))
		{
			Format(country, sizeof(country), "??");
		}
		else
		{
			if (!GeoipCode2(playerIP, country))
				Format(country, sizeof(country), "??");
		}
	}
	FormatTime(time, sizeof(time), "%H:%M:%S", -1);

	if (g_Cvar_Teams.BoolValue)
	{
		GetTeamName(GetClientTeam(client), teamName, sizeof(teamName));

		Format(msg, sizeof(msg), "[%s] [%s] [%-11s] %s :%s %s",
			time,
			country,
			teamName,
			playerName,
			teamchat ? " (TEAM)" : "",
			text);
	}
	else
	{
		Format(msg, sizeof(msg), "[%s] [%s] %s :%s %s",
			time,
			country,
			playerName,
			teamchat ? " (TEAM)" : "",
			text);
	}

	SaveMessage(msg);
}

/*
 * Log a map transition
 */
public void OnMapStart()
{
	char map[128];
	char msg[1024];
	char date[21];
	char time[21];
	char logFile[100];

	GetCurrentMap(map, sizeof(map));

	/* The date may have rolled over, so update the logfile name here */
	FormatTime(date, sizeof(date), "%Y%m%d", -1);
	Format(logFile, sizeof(logFile), SAVECHAT_LOGPATH, date);
	BuildPath(Path_SM, g_szChatFile, PLATFORM_MAX_PATH, logFile);

	Format(g_szDateCheck, sizeof(g_szDateCheck), date);

	FormatTime(time, sizeof(time), "%d/%m/%Y %H:%M:%S", -1);
	Format(msg, sizeof(msg), "[%s] --- NEW MAP STARTED: %s ---", time, map);

	SaveMessage("--=================================================================--");
	SaveMessage(msg);
	SaveMessage("--=================================================================--");
}

/*
 * Log the message to file
 */
void SaveMessage(const char[] message)
{
	g_hFile = OpenFile(g_szChatFile, "a");  /* Append */
	if (g_hFile != null)
	{
		WriteFileLine(g_hFile, message);
		delete g_hFile;
	}
}

