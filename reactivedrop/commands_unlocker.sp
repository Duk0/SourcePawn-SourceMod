#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Commands Unlocker",
	author = "Duko",
	description = "Commands Unlocker",
	version = "1.1",
	url = "http://group.midu.cz"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_unlockcmds", Command_CmdsUnlock, ADMFLAG_ROOT);
	RegAdminCmd("sm_lockcmd", Command_CmdLock, ADMFLAG_ROOT);
	Cmds_Unlock();
}

public Action Command_CmdsUnlock(int client, int args)
{
	Cmds_Unlock();
	return Plugin_Handled;
}

public Action Command_CmdLock(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_lockcmd <cmd>");
		return Plugin_Handled;
	}

	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));

	int flags = GetCommandFlags(arg);
	if (flags != INVALID_FCVAR_FLAGS)
	{
		if (flags & FCVAR_CHEAT)
		{
			PrintToConsole(client, "[CmdLock] cmd %s already has FCVAR_CHEAT flag.", arg);
		}
		else
		{
			SetCommandFlags(arg, flags & FCVAR_CHEAT);
			PrintToConsole(client, "[CmdLock] flag FCVAR_CHEAT was set on %s command.", arg);
		}
	}
	else
	{
		PrintToConsole(client, "[CmdLock] cmd %s doesn't exist.", arg);
	}

	return Plugin_Handled;
}

void Cmds_Unlock()
{
	char mapconfigfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapconfigfile, sizeof(mapconfigfile), "configs/cmds.cfg");

	if (!FileExists(mapconfigfile))
	{
		PrintToServer("[CmdUnlock] configs/cmds.cfg not found... File does not exist!");
		return;
	}

	File file = OpenFile(mapconfigfile, "rt");
	if (file == null)
	{
		LogError("[CmdUnlock] Could not open file!");
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

		bool console = false;
		if (line[0] == '*')
		{
			strcopy(line, sizeof(line), line[1]);
			console = true;
		}

		int flags = GetCommandFlags(line);
		if (flags != INVALID_FCVAR_FLAGS)
		{
			if (flags & FCVAR_CHEAT)
			{
				SetCommandFlags(line, flags & ~FCVAR_CHEAT);

				PrintToServer("[CmdUnlock] line %2i. %s", count, line);
			}
			else
			{
				PrintToServer("[CmdUnlock] line %2i. cmd %s has not FCVAR_CHEAT flag.", count, line);
			}

			if (console)
				AddCommandListener(cmdConsoleReply, line);
			else
				AddCommandListener(cmdNonAdminBlock, line);
		}
		else
		{
			PrintToServer("[CmdUnlock] line %2i. cmd %s doesn't exist.", count, line);
		}
	}

	delete file;
}

public Action cmdConsoleReply(int client, const char[] command, int argc)
{
	if (!HasAdminAccess(client))
	{
		ReplyToCommand(client, "[SM] %t", "No Access");
		return Plugin_Handled;
	}

	if (client)
	{
		char args[64];
		GetCmdArgString(args, sizeof(args));
		DataPack data;
		CreateDataTimer(0.1, DelayedConsoleReply, data, TIMER_FLAG_NO_MAPCHANGE);
		data.WriteCell(client);
		data.WriteString(command);
		data.WriteString(args);
		data.Reset();

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action cmdNonAdminBlock(int client, const char[] command, int argc)
{
	if (!HasAdminAccess(client))
	{
		ReplyToCommand(client, "[SM] %t", "No Access");
		return Plugin_Handled;
	}
/*
	if (strcmp(command, "ent_fire") == 0)
	{
		decl String:buffer[128];
		GetCmdArgString(buffer, sizeof(buffer));

		if (StrContains(buffer, "picker", false) != -1)
		{
			if (GetClientAimTarget(client, true) != -1)
				return Plugin_Handled;
		}

		if (StrContains(buffer, "command", false) != -1)
			return Plugin_Handled;

		LogAction(client, -1, "\"%L\" cheat command (cmdline \"%s\")", client, buffer);
	}
*/
	return Plugin_Continue;
}

bool HasAdminAccess(const int client)
{
	if (client == 0)
		return true;

	int userflags = GetUserFlagBits(client);
	if (userflags & ADMFLAG_ROOT || userflags & ADMFLAG_GENERIC)
		return true;
/*
	AdminId admin = GetUserAdmin(client);
	if (admin != INVALID_ADMIN_ID)
		return true;
*/
	return false;
}

public Action DelayedConsoleReply(Handle timer, DataPack data)
{
	int client = data.ReadCell();

	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	char cmd[64], arg[64];
	data.ReadString(cmd, sizeof(cmd));
	data.ReadString(arg, sizeof(arg));

	char responseBuffer[4096];
	ServerCommandEx(responseBuffer, sizeof(responseBuffer), "%s %s", cmd, arg);
	ReplyToCommand(client, responseBuffer);

	return Plugin_Stop;
}
