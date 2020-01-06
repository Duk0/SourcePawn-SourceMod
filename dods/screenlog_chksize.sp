#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define MAX_FILE_SIZE 500 // in MB 

public Plugin myinfo =
{
    name = "screenlog size checker",
    author = "Duko",
    description = "screenlog size checker",
    version = "1.1",
    url = "http://midu.cz"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_chksize", CmdCheckSize, ADMFLAG_ROOT);
}

public void OnConfigsExecuted()
{
	CheckSize();
}

public Action CmdCheckSize(int client, int args)
{
	CheckSize();
	return Plugin_Handled;
}

void CheckSize()
{
	if (FileSize("../screenlog.0") > (1048576 * MAX_FILE_SIZE))
	{
		if (FileExists("../screenlog.1.bak", false))
		{
			if (FileExists("../screenlog.2.bak", false))
			{
				DeleteFile("../screenlog.2.bak");
			}

			RenameFile("../screenlog.2.bak", "../screenlog.1.bak");
		}

		RenameFile("../screenlog.1.bak", "../screenlog.0");
	}
}
