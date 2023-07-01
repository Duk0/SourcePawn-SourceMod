//*****************************************************************
//	------------------------------------------------------------- *
//						*** Checking stuff ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
bool HasClientFlags(const char[] flags, int client)
{
	int len = strlen(flags);
	
	if (len == 0)
		return false;
	
	AdminFlag flag;
	
	for (int i = 0; i < len; i++)
	{
		if (!FindFlagByChar(flags[i], flag))
		{
			LogError("Ivalid flag detected: %c", flags[i]);
		}
		else if ((GetUserFlagBits(client) & FlagToBit(flag)))// || (GetUserFlagBits(client) & ADMFLAG_ROOT))
			return true;
	}
	return false;
}

public bool IsGameSound(const char[] file)
{
	if (!strncmp(file, "ambient", 7) ||
		!strncmp(file, "beams", 5) ||
		!strncmp(file, "buttons", 7) ||
		!strncmp(file, "coach", 5) ||
		!strncmp(file, "combined", 8) ||
		!strncmp(file, "commentary", 10) ||
		!strncmp(file, "common", 6) ||
		!strncmp(file, "doors", 5) ||
		!strncmp(file, "friends", 7) ||
		!strncmp(file, "hl1", 3) ||
		!strncmp(file, "items", 5) ||
		!strncmp(file, "midi", 4) ||
		!strncmp(file, "misc", 4) ||
		!strncmp(file, "music", 5) ||
		!strncmp(file, "npc", 3) ||
		!strncmp(file, "physics", 7) ||
		!strncmp(file, "pl_hoodoo", 9) ||
		!strncmp(file, "plats", 5) ||
		!strncmp(file, "player", 6) ||
		!strncmp(file, "resource", 8) ||
		!strncmp(file, "replay", 6) ||
		!strncmp(file, "test", 4) ||
		!strncmp(file, "ui", 2) ||
		!strncmp(file, "vehicles", 8) ||
		!strncmp(file, "vo", 2) ||
		!strncmp(file, "weapons", 7))
		return true;
	else
		return false;
}

public bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || IsFakeClient(client) || IsClientReplay(client) || IsClientSourceTV(client))
		return false;

	return IsClientInGame(client);
}

public bool IsDeadClient(int client)
{
	if (IsValidClient(client) && !IsPlayerAlive(client))
		return true;

	return false;
}

public bool HearSound(int client)
{	
	if (IsPlayerAlive(client) && !hearalive)
		return false;
	else
		return true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		hAdminMenu = INVALID_HANDLE;
}

bool checkSamplingRate(const char[] filelocation)
{
	Handle h_Soundfile = OpenSoundFile(filelocation, true);
	int samplerate;
	if (h_Soundfile != INVALID_HANDLE)
		samplerate = GetSoundSamplingRate(h_Soundfile);
	else
	{
		LogError("<checkSamplingRate> INVALID_HANDLE for file \"%s\" ", filelocation);
		CloseHandle(h_Soundfile);
		return false;
	}
	CloseHandle(h_Soundfile);

	if (samplerate > 44100)
	{
		LogError("Invalid sample rate (\%d Hz) for file \"%s\", sample rate should not be above 44100 Hz", samplerate, filelocation);
		return false;
	}
	return true;
}
//*****************************************************************
//	------------------------------------------------------------- *
//				*** Checking Client Preferences ***				  *
//	------------------------------------------------------------- *
//*****************************************************************
bool checkClientCookies(int iClient, int iCase)
{
	char cookie[4];

	switch (iCase)
	{
		case CHK_CHATMSG:	/* Chat message */
		{
			GetClientCookie(iClient, g_sschatmsg_cookie, cookie, sizeof(cookie));
			if (StrEqual(cookie, "1"))
				return true;
			else if(StrEqual(cookie, "0"))
				return false;
			else
			{
				// Set cookie if client connects the first time
				SetClientCookie(iClient, g_sschatmsg_cookie, "1");
				return true;
			}
		}
		case CHK_SAYSOUNDS:	/* Say sounds */
		{
			GetClientCookie(iClient, g_sssaysound_cookie, cookie, sizeof(cookie));
			// Switching form on/off, yes/no to 1/0 but for the old cookies we'll have to check both
			if (StrEqual(cookie, "on") || StrEqual(cookie, "1"))
				return true;
			else if(StrEqual(cookie, "off") || StrEqual(cookie, "0"))
				return false;
			else
			{
				// Set cookie if client connects the first time
				SetClientCookie(iClient, g_sssaysound_cookie, "1");
				return true;
			}
		}
		case CHK_EVENTS:	/* Event Sounds */
		{
			GetClientCookie(iClient, g_ssevents_cookie, cookie, sizeof(cookie));
			if (StrEqual(cookie, "1"))
				return true;
			else if(StrEqual(cookie, "0"))
				return false;
			else
			{
				// Set cookie if client connects the first time
				SetClientCookie(iClient, g_ssevents_cookie, "1");
				return true;
			}
		}
		case CHK_KARAOKE:	/* Karaoke */
		{
			GetClientCookie(iClient, g_sskaraoke_cookie, cookie, sizeof(cookie));
			if (StrEqual(cookie, "1"))
				return true;
			else if(StrEqual(cookie, "0"))
				return false;
			else
			{
				// Set cookie if client connects the first time
				SetClientCookie(iClient, g_sskaraoke_cookie, "1");
				return true;
			}
		}
		case CHK_BANNED:	/* Banned */
		{
			GetClientCookie(iClient, g_ssban_cookie, cookie, sizeof(cookie));
			// Switching form on/off, yes/no to 1/0 but for the old cookies we'll have to check both
			if (StrEqual(cookie, "on") || StrEqual(cookie, "1"))
				return true;
			else if(StrEqual(cookie, "off") || StrEqual(cookie, "0"))
				return false;
			else
			{
				// Set cookie if client connects the first time
				SetClientCookie(iClient, g_ssban_cookie, "0");
				return false;
			}
		}
		case CHK_GREETED:	/* Greeted */
		{
			GetClientCookie(iClient, g_ssgreeted_cookie, cookie, sizeof(cookie));
			// Switching form on/off, yes/no to 1/0 but for the old cookies we'll have to check both
			if (StrEqual(cookie, "yes") || StrEqual(cookie, "1")) {
				return true;
			} else if(StrEqual(cookie, "no") || StrEqual(cookie, "0")) {
				return false;
			} else {
				// Set cookie if client connects the first time
				SetClientCookie(iClient, g_ssgreeted_cookie, "0");
				return false;
			}
		}
/*		default:
		{
			return true;
		}*/
	}
	return true;
}