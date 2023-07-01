/*
* Crashed Map Recovery (c) 2009 Jonah Hirsch
* 
* 
* Loads the map the server was on before it crashed when server restarts
* 
*  
* Changelog								
* ------------		
* 1.5
*  - Messages are now logged to logs/CMR.log
*  - crashmap.txt is now generated automatically
* 1.4.3
*  - Fixed compile warnings
*  - Backs up and restores nextmap on crash + recover (test feature!)
* 1.4.2
*  - Autoconfig added. cfg/sourcemod/plugin.crashmap.cfg
* 1.4.1
*  - Added FCVAR_DONTRECORD to version cvar
* 1.4
*  - Added sm_crashmap_maxrestarts
*  - Added support for checking if the map being changed to crashes the server
* 1.3
*  - Changed method of enabling/disabling recover time to improve performance
*  - Added sm_crashmap_interval
* 1.2
*  - Added timelimit recovery
*  - Added sm_crashmap_recovertime
* 1.1
*  - Added log message when map is recoevered on restart
* 1.0									
*  - Initial Release			
* 
* 		
*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION "1.6"

//#define KEYVALUE

char g_szFileLoc[192];
char g_szLogPath[PLATFORM_MAX_PATH];
File g_hLogFile = null;

ConVar g_Cvar_CrashMapEnabled;
ConVar g_Cvar_MaxRestarts;
#if defined KEYVALUE
ConVar g_Cvar_RecoverTime;
ConVar g_Cvar_Interval;

Handle g_hTimeleftHandle = null;
#endif

bool g_bRecovered = false;
#if defined KEYVALUE
bool g_bTimelimitChanged = false;
bool g_bOverwrite = false;
bool g_bMapEnded = false;
int g_iNewTimelimit;
#endif


public Plugin myinfo = 
{
	name = "Crashed Map Recovery",
	author = "Crazydog, Duko",
	description = "Reloads map that was being played before server crash",
	version = PLUGIN_VERSION,
	url = "http://theelders.net"
};

public void OnPluginStart()
{
	CreateConVar("sm_crashmap_version", PLUGIN_VERSION, "Crashed Map Recovery Version", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_Cvar_CrashMapEnabled = CreateConVar("sm_crashmap_enabled", "1", "Enable Crashed Map Recovery? (1=yes 0=no)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_Cvar_MaxRestarts = CreateConVar("sm_crashmap_maxrestarts", "5", "How many consecutive crashes until server loads the default map", FCVAR_NOTIFY, true, 3.0);
#if defined KEYVALUE
	g_Cvar_RecoverTime = CreateConVar("sm_crashmap_recovertime", "0", "Recover timelimit? (1=yes 0=no)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_Cvar_Interval = CreateConVar("sm_crashmap_interval", "20", "Interval between timeleft updates (in seconds)", FCVAR_NOTIFY, true, 1.0);
#endif

	AutoExecConfig(true, "plugin.crashmap");

#if defined KEYVALUE
	g_Cvar_RecoverTime.AddChangeHook(TimerState);
	g_Cvar_Interval.AddChangeHook(IntervalChange);
#endif
	RegAdminCmd("sm_crashmap_save", Command_CrashMapSave, ADMFLAG_CHEATS);

#if defined KEYVALUE
	if (g_Cvar_RecoverTime.BoolValue)
	{
		g_hTimeleftHandle = CreateTimer(g_Cvar_Interval.FloatValue, SaveTimeleft, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
#endif

	BuildPath(Path_SM, g_szLogPath, PLATFORM_MAX_PATH, "/logs/CMR.log");
	if (!FileExists(g_szLogPath))
	{
		g_hLogFile = OpenFile(g_szLogPath, "a");
		if (g_hLogFile != null)
			delete g_hLogFile;
	}

	BuildPath(Path_SM, g_szFileLoc, sizeof(g_szFileLoc), "data/crashmap.txt");
	if (!FileExists(g_szFileLoc))
	{
#if defined KEYVALUE
		char validKv[] =
			"\"SavedMap\" \
			{ \
			}";

		KeyValues kv = new KeyValues("SavedMap");
		kv.ImportFromString(validKv);
		kv.ExportToFile(g_szFileLoc);
		delete kv;

/*		File dataFileHandle = OpenFile(g_szFileLoc, "a");
		dataFileHandle.WriteLine("\"SavedMap\"");
		dataFileHandle.WriteLine("{");
		dataFileHandle.WriteLine("}");
		delete dataFileHandle;*/
#endif
	}
}

public Action Command_CrashMapSave(int client, int args)
{
	char CurrentMap[256];
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));

#if defined KEYVALUE
	KeyValues kv = new KeyValues("SavedMap");
	if (kv.ImportFromFile(g_szFileLoc))
		LogToFile(g_szLogPath, "[CMR] map %s load", CurrentMap);
	kv.JumpToKey("Recover", true);
	kv.SetString("map", CurrentMap);
	kv.Rewind();
	if (kv.ExportToFile(g_szFileLoc))
		LogToFile(g_szLogPath, "[CMR] map %s saved", CurrentMap);
	else
		LogToFile(g_szLogPath, "[CMR] error save with map %s to %s", CurrentMap, g_szFileLoc);

	delete kv;
#else

	//if (FileExists(g_szFileLoc)) DeleteFile(g_szFileLoc)

	File file = OpenFile(g_szFileLoc, "wt");
	if (file != null)
	{
		//char line[1];
		file.WriteLine("%s 0", CurrentMap);
		delete file;
	}
#endif

	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
#if defined KEYVALUE
	g_bMapEnded = false;

	if (!g_Cvar_RecoverTime.BoolValue)
	{
		if (g_hTimeleftHandle != null)
		{
			KillTimer(g_hTimeleftHandle);
			g_hTimeleftHandle = null;
		}
	}
#endif
	if (!g_Cvar_CrashMapEnabled.BoolValue)
		return;

#if defined KEYVALUE
	if (g_Cvar_RecoverTime.BoolValue)
	{
		float newTime = g_Cvar_Interval.FloatValue;

		if (g_hTimeleftHandle != null)
		{
			KillTimer(g_hTimeleftHandle);
			g_hTimeleftHandle = null;
		}

		g_hTimeleftHandle = CreateTimer(newTime, SaveTimeleft, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		g_bOverwrite = true;
	}
#endif
	char CurrentMap[256];
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	if (g_bRecovered)
	{
#if defined KEYVALUE
		KeyValues kv = new KeyValues("SavedMap");
		if (!kv.ImportFromFile(g_szFileLoc))
		{
			LogToFile(g_szLogPath, "[CMR] Error! KeyValues: Can't import %s file.", g_szFileLoc);
			delete kv;
			return;
		}

		kv.JumpToKey("Recover", true);
		kv.SetString("map", CurrentMap);
		kv.Rewind();
		kv.ExportToFile(g_szFileLoc);
		delete kv;
#else
		int restarts;
		File file = OpenFile(g_szFileLoc, "rt");
		if (file != null)
		{
			char line[256];
			file.ReadLine(line, sizeof(line));
			TrimString(line);

			char pieces[2][256];
			if (ExplodeString(line, " ", pieces, sizeof(pieces), sizeof(pieces[])) == 2)
			{
			//	TrimString(pieces[1]);
				restarts = StringToInt(pieces[1]);
			}

			delete file;
		}

		file = OpenFile(g_szFileLoc, "wt");
		if (file != null)
		{
			file.WriteLine("%s %i", CurrentMap, restarts);
			delete file;
		}
#endif
		return;
	}
	if (!g_bRecovered)
	{
#if defined KEYVALUE
		char MapToLoad[256], nextmap[256];
		int timeleft, restarts;
		KeyValues kv = new KeyValues("SavedMap");
		if (!kv.ImportFromFile(g_szFileLoc))
		{
			LogToFile(g_szLogPath, "[CMR] Error! KeyValues: Can't import %s file.", g_szFileLoc);
			delete kv;
			return;
		}

		kv.JumpToKey("Recover", true);
		kv.GetString("map", MapToLoad, sizeof(MapToLoad));
		restarts = kv.GetNum("restarts", 0);
		//LogToFile(g_szLogPath, "[CMR] Server restarted, restarts is %i", restarts);
		restarts++;
		//LogToFile(g_szLogPath, "[CMR] Restarts incremented, restarts is %i", restarts);
		LogToFile(g_szLogPath, "Restarts is %i", restarts);
		kv.SetNum("restarts", restarts);
		timeleft = kv.GetNum("Timeleft", 30);
		kv.GetString("Nextmap", nextmap, sizeof(nextmap));
		if (nextmap[0] != '\0')
		{
			SetNextMap(nextmap);
		}
		g_iNewTimelimit = timeleft / 60;
		g_bRecovered = true;
		if (restarts > g_Cvar_MaxRestarts.IntValue)
		{
			LogToFile(g_szLogPath, "[CMR] Error! %s is causing the server to crash. Please fix!", MapToLoad);
			kv.SetNum("restarts", 0);
			kv.Rewind();
			kv.ExportToFile(g_szFileLoc);
			delete kv;
			return;
		}
		kv.Rewind();
		kv.ExportToFile(g_szFileLoc);
		delete kv;
#else
		char MapToLoad[256];
		int restarts;
		File file = OpenFile(g_szFileLoc, "rt");
		if (file != null)
		{
			char line[256];
			file.ReadLine(line, sizeof(line));
			TrimString(line);
			//PrintToServer("[CMR] line %s", line);

			char pieces[2][256];
			if (ExplodeString(line, " ", pieces, sizeof(pieces), sizeof(pieces[])) == 2)
			{
			//	TrimString(pieces[0]);
			//	TrimString(pieces[1]);
				strcopy(MapToLoad, sizeof(MapToLoad), pieces[0]);
				restarts = StringToInt(pieces[1]);
				//PrintToServer("[CMR] pieces %s %s", pieces[0], pieces[1]);
				restarts++;
				//PrintToServer("[CMR] restarts %i", restarts);
			}

			delete file;
			
			file = OpenFile(g_szFileLoc, "wt");
		}

		g_bRecovered = true;
		if (restarts > g_Cvar_MaxRestarts.IntValue)
		{
			LogToFile(g_szLogPath, "[CMR] Error! %s is causing the server to crash. Please fix!", MapToLoad);
			if (file != null)
			{
				file.WriteLine("%s 0", CurrentMap);
				delete file;
			}
			return;
		}
		if (file != null)
		{
			file.WriteLine("%s %i", CurrentMap, restarts);
			delete file;
		}
#endif

#if defined KEYVALUE
		if (g_Cvar_RecoverTime.BoolValue)
		{
			LogToFile(g_szLogPath, "[CMR] %s loaded after server crash. Timelimit set to %i", MapToLoad, timeleft / 60);
		}
		else
		{
			LogToFile(g_szLogPath, "[CMR] %s loaded after server crash.", MapToLoad);
		}
#else
		LogToFile(g_szLogPath, "[CMR] %s loaded after server crash.", MapToLoad);
#endif
		//if(IsMapValid(MapToLoad) && !StrEqual(MapToLoad, CurrentMap))
/*		if (!StrEqual(MapToLoad, CurrentMap))
		{
			//ForceChangeLevel(MapToLoad, "Crashed Map Recovery");
			ServerCommand("changelevel %s", MapToLoad);
		}
*/	
		ServerCommand("changelevel %s", MapToLoad);

		return;
	}
}
#if defined KEYVALUE
public void OnMapEnd()
{
	g_bMapEnded = true;
}

public Action SaveTimeleft(Handle timer)
{
	if (g_bMapEnded)
		return Plugin_Continue;

	if (g_bOverwrite)
	{
		int timeleft;
		if (!GetMapTimeLeft(timeleft))
		{
			if (!GetMapTimeLimit(timeleft))
				timeleft = 30;
		}
		char nextmap[256];
		GetNextMap(nextmap, sizeof(nextmap));
		KeyValues kv = new KeyValues("SavedMap");
		kv.ImportFromFile(g_szFileLoc);
		kv.JumpToKey("Recover", true);
		kv.SetNum("Timeleft", timeleft);
		kv.SetString("Nextmap", nextmap);
		kv.Rewind();
		kv.ExportToFile(g_szFileLoc);
		delete kv;
		return Plugin_Continue;
	}
	return Plugin_Continue;
}
#endif

public void OnClientAuthorized(int client)
{
#if defined KEYVALUE
	KeyValues kv = new KeyValues("SavedMap");
	kv.ImportFromFile(g_szFileLoc);
	kv.JumpToKey("Recover", true);
	kv.SetNum("restarts", 0);
	kv.Rewind();
	kv.ExportToFile(g_szFileLoc);
	delete kv;

	if (!g_bTimelimitChanged && g_Cvar_RecoverTime.BoolValue)
	{
		ServerCommand("mp_timelimit %i", g_iNewTimelimit);
		g_bTimelimitChanged = true;
		g_bOverwrite = true;
	}
#else
	File file = OpenFile(g_szFileLoc, "wt");
	if (file != null)
	{
		char CurrentMap[256];
		GetCurrentMap(CurrentMap, sizeof(CurrentMap));
		file.WriteLine("%s 0", CurrentMap);
		delete file;
	}
#endif
}
#if defined KEYVALUE
public void TimerState(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!convar.BoolValue)
	{
		if (g_hTimeleftHandle != null)
		{
			KillTimer(g_hTimeleftHandle);
			g_hTimeleftHandle = null;
		}
	}
	if (convar.BoolValue)
	{
		float newTime = g_Cvar_Interval.FloatValue;
		g_hTimeleftHandle = CreateTimer(newTime, SaveTimeleft, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		g_bOverwrite = true;
	}
}

public void IntervalChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_hTimeleftHandle != null)
	{
		float newTime = StringToFloat(newValue);
		KillTimer(g_hTimeleftHandle);
		g_hTimeleftHandle = null;
		g_hTimeleftHandle = CreateTimer(newTime, SaveTimeleft, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}
#endif
