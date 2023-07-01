//*****************************************************************
//	------------------------------------------------------------- *
//				*** Manage precaching resources ***				  *
//	------------------------------------------------------------- *
//*****************************************************************
#tryinclude "ResourceManager"
#if !defined _ResourceManager_included
	#define DONT_DOWNLOAD	0
	#define DOWNLOAD		1
	#define ALWAYS_DOWNLOAD 2

	enum State { Unknown=0, Defined, Download, Force, Precached };

	ConVar cvarDownloadThreshold;
	ConVar cvarSoundThreshold;
	ConVar cvarSoundLimitMap;

	int g_iSoundCount			= 0;
	int g_iDownloadCount		= 0;
	int g_iRequiredCount		= 0;
	int g_iPrevDownloadIndex	= 0;
	int g_iDownloadThreshold	= -1;
	int g_iSoundThreshold		= -1;
	int g_iSoundLimit			= -1;

	// Trie to hold precache status of sounds
	StringMap g_soundTrie = null;

	stock bool PrepareSound(const char[] sound, bool force=false, bool preload=false)
	{
		State value = Unknown;
		if (!g_soundTrie.GetValue(sound, value) || value < Precached)
		{
			if (force || value >= Force || g_iSoundLimit <= 0 ||
				(g_soundTrie != null ? g_soundTrie.Size : 0) < g_iSoundLimit)
			{
				PrecacheSound(sound, preload);
				g_soundTrie.SetValue(sound, Precached);
			}
			else
				return false;
		}
		return true;
	}

	stock void SetupSound(const char[] sound, bool force=false, int download=DOWNLOAD,
					 bool precache=false, bool preload=false)
	{
		State value = Unknown;
		bool update = !g_soundTrie.GetValue(sound, value);
		if (update || value < Defined)
		{
			g_iSoundCount++;
			value  = Defined;
			update = true;
		}

		if (value < Download && download && g_iDownloadThreshold != 0)
		{
			char file[PLATFORM_MAX_PATH+1];
			Format(file, sizeof(file), "sound/%s", sound);

			if (FileExists(file))
			{
				if (download < 0)
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
					{
						// If the sound starts with one of those directories
						// assume it came with the game and doesn't need to
						// be downloaded.
						download = 0;
					}
					else
						download = 1;
				}

				if (download > 0 &&
					(download > 1 || g_iDownloadThreshold < 0 ||
					 (g_iSoundCount > g_iPrevDownloadIndex &&
					  g_iDownloadCount < g_iDownloadThreshold + g_iRequiredCount)))
				{
					AddFileToDownloadsTable(file);

					update = true;
					value  = Download;
					g_iDownloadCount++;

					if (download > 1)
						g_iRequiredCount++;

					if (download <= 1 || g_iSoundCount == g_iPrevDownloadIndex + 1)
						g_iPrevDownloadIndex = g_iSoundCount;
				}
			}
		}

		if (value < Precached && (precache || (g_iSoundThreshold > 0 &&
											   g_iSoundCount < g_iSoundThreshold)))
		{
			if (force || g_iSoundLimit <= 0 &&
				(g_soundTrie != null ? g_soundTrie.Size : 0) < g_iSoundLimit)
			{
				PrecacheSound(sound, preload);

				if (value < Precached)
				{
					value  = Precached;
					update = true;
				}
			}
		}
		else if (force && value < Force)
		{
			value  = Force;
			update = true;
		}

		if (update)
			g_soundTrie.SetValue(sound, value);
	}

	stock void PrepareAndEmitSound(const int[] clients,
					 int numClients,
					 const char[] sample,
					 int entity = SOUND_FROM_PLAYER,
					 int channel = SNDCHAN_AUTO,
					 int level = SNDLEVEL_NORMAL,
					 int flags = SND_NOFLAGS,
					 float volume = SNDVOL_NORMAL,
					 int pitch = SNDPITCH_NORMAL,
					 int speakerentity = -1,
					 const float origin[3] = NULL_VECTOR,
					 const float dir[3] = NULL_VECTOR,
					 bool updatePos = true,
					 float soundtime = 0.0)
	{
		if (PrepareSound(sample))
		{
			if (gb_csgo)
			{
				for (int i = 0; i < numClients; i++)
				{
					ClientCommand(clients[i], "play *%s", sample);
				}
			}
			else
			{
				if (volume == SNDVOL_NORMAL)
				{
					for (int i = 0; i < numClients; i++)
					{
						ClientCommand(clients[i], "playgamesound %s", sample);
					}
				}
				else
				{
					EmitSound(clients, numClients, sample, entity, channel,
							level, flags, volume, pitch, speakerentity,
							origin, dir, updatePos, soundtime);
				}
			}
		}
	}

	stock void PrepareAndEmitSoundToClient(int client,
					 const char[] sample,
					 int entity = SOUND_FROM_PLAYER,
					 int channel = SNDCHAN_AUTO,
					 int level = SNDLEVEL_NORMAL,
					 int flags = SND_NOFLAGS,
					 float volume = SNDVOL_NORMAL,
					 int pitch = SNDPITCH_NORMAL,
					 int speakerentity = -1,
					 const float origin[3] = NULL_VECTOR,
					 const float dir[3] = NULL_VECTOR,
					 bool updatePos = true,
					 float soundtime = 0.0)
	{
		if (PrepareSound(sample))
		{
			if (gb_csgo)
			{
				ClientCommand(client, "play *%s", sample);
			}
			else
			{
				if (volume == SNDVOL_NORMAL)
				{
					ClientCommand(client, "playgamesound %s", sample);
				}
				else
				{
					EmitSoundToClient(client, sample, entity, channel,
								  level, flags, volume, pitch, speakerentity,
								  origin, dir, updatePos, soundtime);
				}
			}
		}
	}
#endif
