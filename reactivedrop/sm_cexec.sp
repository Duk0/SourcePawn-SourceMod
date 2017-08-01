/*
 * ma_cexec equivalent for sourcemod
 *
 * Coded by dubbeh - www.yegods.net
 *
 */

#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0.4"

public Plugin myinfo =
{
    name = "Client Execute",
    author = "dubbeh",
    description = "Execute commands on clients for SourceMod",
    version = PLUGIN_VERSION,
    url = "http://www.yegods.net/"
};


public void OnPluginStart()
{
    CreateConVar("sm_cexec_version", PLUGIN_VERSION, "Client Exec version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    /* register the sm_cexec console command */
    RegAdminCmd("sm_cexec", ClientExec, ADMFLAG_RCON);
    LoadTranslations("common.phrases");
}

public Action ClientExec(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "sm_cexec invalid format");
		ReplyToCommand(client, "Usage: sm_cexec \"<user>\" \"<command>\"");
	}

	char szClient[MAX_NAME_LENGTH], szCommand[128];
	GetCmdArg (1, szClient, sizeof(szClient));
	GetCmdArg (2, szCommand, sizeof(szCommand));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			szClient,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	int target;
	for (int i = 0; i < target_count; i++)
	{
		target = target_list[i];
		if (IsFakeClient(target))
			FakeClientCommand(target, szCommand);
		else
			ClientCommand(target, szCommand);
	}

	return Plugin_Handled;
}

