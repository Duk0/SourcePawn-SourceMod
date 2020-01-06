#include <sourcemod>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "DoD DeadChat",
	author = "FeuerSturm",
	description = "Prints Messages of Dead Players to everyone",
	version = PLUGIN_VERSION,
	url = "http://community.dodsourceplugins.net"
}

new Handle:DoDDeadChat = INVALID_HANDLE

public OnPluginStart()
{
	DoDDeadChat = CreateConVar("dod_deadchat", "1", "<1/0> = enable/disable DeadChat", _, true, 0.0, true, 1.0)
	RegConsoleCmd("say", DeadChat)
	RegConsoleCmd("say_team", DeadChat)
}

public Action:DeadChat(client, args)
{
	if(client < 1 || !IsClientInGame(client) || IsPlayerAlive(client) || GetClientTeam(client) < 1 || GetConVarInt(DoDDeadChat) == 0)
	{
		return Plugin_Continue
	}
	decl String:SayCmd[9], String:ChatMessage[512]
	GetCmdArg(0, SayCmd, sizeof(SayCmd))
	GetCmdArgString(ChatMessage, sizeof(ChatMessage))
	if(strcmp(SayCmd, "say", true) == 0)
	{
		StripQuotes(ChatMessage)
		if(GetClientTeam(client) == 1)
		{
			PrintToChatAll("\x05*Spec* \x04%N: \x01%s", client, ChatMessage)
		}
		else
		{
			PrintToChatAll("\x05*Dead* \x04%N: \x01%s", client, ChatMessage)
		}
		return Plugin_Handled
	}
	else if(strcmp(SayCmd, "say_team", true) == 0)
	{
		new team = GetClientTeam(client)
		StripQuotes(ChatMessage)
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == team)
			{
				if(team == 1)
				{
					PrintToChat(i, "\x05*Spec* \x01(Team) \x04%N: \x01%s", client, ChatMessage)
				}
				else
				{
					PrintToChat(i, "\x05*Dead* \x01(Team) \x04%N: \x01%s", client, ChatMessage)
				}
			}
		}
		return Plugin_Handled
	}
	return Plugin_Continue
}