#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.2"


public Plugin myinfo = 
{
	name = "Cheat commands",
	author = "EHG | Duko",
	description = "Use commands requiring sv_cheats",
	version = PLUGIN_VERSION,
	url = "epichatguy@gmail.com"
};

ConVar g_Cvar_Cheats;

public void OnPluginStart()
{
//	CreateConVar("sm_cheat_version", PLUGIN_VERSION, "Cheat commands version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	RegAdminCmd("sm_cheat", Command_cheat_command, ADMFLAG_ROOT);
	
	g_Cvar_Cheats = FindConVar("sv_cheats");
}

public void OnClientPutInServer(client)
{
	if (IsFakeClient(client))
		return;

	CreateTimer(2.0, SetRconPassword, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action SetRconPassword(Handle timer, any userid)
{
	new client = GetClientOfUserId(userid);

	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (!HasRconAccess(client))
		return Plugin_Stop;

	ServerCommand("mp_disable_autokick %d", userid);

	return Plugin_Stop;
}

public Action Command_cheat_command(int client, int args)
{
	if (args < 1)
		return Plugin_Handled;

	char cmd[128];
	GetCmdArgString(cmd, sizeof(cmd));

	if (StrContains(cmd, "ent_remove", false) != -1 || StrContains(cmd, "picker", false) != -1)
	{
		if (GetClientAimTarget(client, true) != -1)
			return Plugin_Handled;
	}

	if (StrContains(cmd, "command", false) != -1)
		return Plugin_Handled;

	PerformCheatCommand(client, cmd);
	LogAction(client, -1, "\"%L\" cheat command (cmdline \"%s\")", client, cmd);
	return Plugin_Handled;
}

stock void PerformCheatCommand(int client, char[] cmd)
{
	bool enabled = g_Cvar_Cheats.BoolValue;
	int flags = g_Cvar_Cheats.Flags;
	if (!enabled)
	{
		SetConVarFlags(g_Cvar_Cheats, flags^(FCVAR_NOTIFY|FCVAR_REPLICATED));
		SetConVarBool(g_Cvar_Cheats, true);
	}
	if (client)
		FakeClientCommand(client, cmd);
	else
		ServerCommand(cmd);
	if (!enabled)
	{
		SetConVarBool(g_Cvar_Cheats, false);
		SetConVarFlags(g_Cvar_Cheats, flags);
	}
}

stock bool HasRconAccess(const int client)
{
	if (!client)
	{
		return false;
	}

	new userflags = GetUserFlagBits(client);
	if (userflags & ADMFLAG_ROOT || userflags & ADMFLAG_RCON)
		return true;

	return false;
}
