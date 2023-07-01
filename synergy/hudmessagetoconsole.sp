#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
	name = "Hud Message to Console",
	author = "Duko",
	description = "Hud Message to Console",
	version = "1.0",
	url = "http://group.midu.cz"
};

char g_szPrevMsg[MAXPLAYERS+1][192];

public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("HudMsg"), HookHudMsg, false); // game_text
	//HookUserMessage(GetUserMessageId("HudText"), HookHudText, false); // env_message
	//HookUserMessage(GetUserMessageId("TextMsg"), HookHudText, false); // center text
}

public Action HookHudMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int channel = msg.ReadByte(); //channel
	msg.ReadFloat(); // x ( -1 = center )
	msg.ReadFloat(); // y ( -1 = center )
	// second color
	msg.ReadByte(); //r1
	msg.ReadByte(); //g1
	msg.ReadByte(); //b1
	msg.ReadByte(); //a1 // transparent?
	// init color
	msg.ReadByte(); //r2
	msg.ReadByte(); //g2
	msg.ReadByte(); //b2
	msg.ReadByte(); //a2
	msg.ReadByte(); //effect (0 is fade in/fade out; 1 is flickery credits; 2 is write out)
	msg.ReadFloat(); //fadeinTime (message fade in time - per character in effect 2)
	msg.ReadFloat(); //fadeoutTime
	msg.ReadFloat(); //holdtime
	msg.ReadFloat(); //fxtime (effect type(2) used)

	char message[192];
	msg.ReadString(message, sizeof(message), false); //Message
	
	if (channel == 3 && playersNum == 1)
	{
		int len = strlen(message) - 1;
		if ((strncmp(message, "Enemy: ", 7) == 0 || strncmp(message, "Friend: ", 8) == 0 || strncmp(message, "Neutral: ", 9) == 0) && message[len] == ')')
			return Plugin_Continue;
	}

	int target;
	for (int i = 0; i < playersNum; i++)
	{
		target = players[i];

		if (!IsClientInGame(target))
			continue;
		
		if (StrEqual(g_szPrevMsg[target], message))
			continue;

		strcopy(g_szPrevMsg[target], sizeof(g_szPrevMsg[]), message);
		PrintToConsole(target, "[HUD-MSG]: %s", message);
	}
	
	return Plugin_Continue;
}
/*
public Action HookHudText(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	char message[192];
	msg.ReadString(message, sizeof(message), false); //Message

	for (int i = 0; i < playersNum; i++)
	{
		if (!IsClientInGame(players[i]))
			continue;

		PrintToConsole(players[i], message);	
	}
}
*/