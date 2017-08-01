#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Cvars Unlocker",
	author = "Duko",
	description = "Cvars Unlocker",
	version = "1.0",
	url = "http://group.midu.cz"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_unlockcvars", Command_CvarsUnlock, ADMFLAG_ROOT);
	Cvars_Unlock();
}

public Action Command_CvarsUnlock(int client, int args)
{
	Cvars_Unlock();
	return Plugin_Handled;
}

void Cvars_Unlock()
{
	char mapconfigfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapconfigfile, sizeof(mapconfigfile), "configs/cvars.cfg");

	if (!FileExists(mapconfigfile))
	{
		PrintToServer("[CvarUnlock] configs/cvars.cfg not found... file doesnt exist!");
		return;
	}

	File file = OpenFile(mapconfigfile, "rt");
	if (file == null)
	{
		LogError("Could not open file!");
		return;
	}

	int count = 0;
	char line[255];
	while (!IsEndOfFile(file))
	{
		if (!ReadFileLine(file, line, sizeof(line)))
			break;

		/* Trim comments */
		int len = strlen(line);
		bool ignoring = false;
		for (int i = 0; i < len; i++)
		{
			if (ignoring)
			{
				if (line[i] == '"')
				{
					ignoring = false;
				}
			} else {
				if (line[i] == '"')
				{
					ignoring = true;
				} else if (line[i] == ';') {
					line[i] = '\0';
					break;
				} else if (line[i] == '/'
							&& i != len - 1
							&& line[i+1] == '/')
				{
					line[i] = '\0';
					break;
				}
			}
		}

		TrimString(line);
		count++;

		if ((line[0] == '/' && line[1] == '/')
			|| (line[0] == ';' || line[0] == '\0'))
		{
			continue;
		}

		ConVar cvar = FindConVar(line);
		if (cvar != null)
		{
			int flags = GetConVarFlags(cvar);
			if (flags & FCVAR_CHEAT)
			{
				SetConVarFlags(cvar, flags & ~FCVAR_CHEAT);

				PrintToServer("[CvarUnlock] line %2i. %s", count, line);
			}
			else
			{
				PrintToServer("[CvarUnlock] line %2i. cvar %s has not FCVAR_CHEAT flag.", count, line);
			}
		}
		else
		{
			PrintToServer("[CvarUnlock] line %2i. cvar %s doesn't exist", count, line);
		}
	}

	delete file;
}