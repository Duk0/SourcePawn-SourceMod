/*
 * vim: set ai et ts=4 sw=4 :

Cvarlist (default value):
	sm_sound_enable					1	  Turns Sounds On/Off
	sm_sound_warn					3	  Number of sounds to warn person at
	sm_sound_limit				   	5	  Maximum sounds per person
	sm_sound_admin_limit			0	  Maximum sounds per admin
	sm_sound_admin_warn				0		Number of sounds to warn admin at
	sm_sound_announce				0	  Turns on announcements when a sound is played
	sm_sound_sentence				0	  When set, will trigger sounds if keyword is embedded in a sentence
	sm_sound_logging				0	  When set, will log sounds that are played
	sm_join_exit					0	  Play sounds when someone joins or exits the game
	sm_join_spawn					1	  Wait until the player spawns before playing the join sound
	sm_specific_join_exit			0	  Play sounds when a specific STEAM ID joins or exits the game
	sm_time_between_sounds		   	4.5		Time between each sound trigger, 0.0 to disable checking
	sm_time_between_admin_sounds	4.5		Time between each sound trigger (for admins), 0.0 to disable checking
	sm_sound_showmenu				1	  Turns the Public Sound Menu on(1) or off(0)
	sm_saysounds_volume			  	1.0		Global/Default Volume setting for Say Sounds (0.0 <= x <= 1.0).
	sm_saysoundhe_interrupt_sound	1	  If set, interrupt the current sound when a new start
	sm_saysoundhe_filter_if_dead	 0	  If set, alive players do not hear sounds triggered by dead players
	sm_saysoundhe_download_threshold -1	 If set, sets the number of sounds that are downloaded per map.
	sm_saysoundhe_sound_threshold	0	  If set, sets the number of sounds that are precached on map start (in SetupSound).
	sm_saysoundhe_sound_max		  -1	 If set, set max number of sounds that can be used on a map.
	sm_saysoundhe_track_disconnects  1	  If set, stores sound counts when clients leave and loads them when they join.
	
Admin Commands:
	sm_sound_ban <user>		 Bans a player from using sounds
	sm_sound_unban <user>		 Unbans a player os they can play sounds
	sm_sound_reset <all|user>	 Resets sound quota for user, or everyone if all
	sm_admin_sounds 		 Display a menu of all admin sounds to play
	!adminsounds 			 When used in chat will present a menu of all admin sound to play.
	!allsounds			 When used in chat will present a menu of all sounds to play.
	
User Commands:
	sm_sound_menu 			 Display a menu of all sounds (trigger words) to play
	sm_sound_list  			 Print all trigger words to the console
	!sounds  			 When used in chat turns sounds on/off for that client
	!soundlist  			 When used in chat will print all the trigger words to the console (Now displays menu)
	!soundmenu  			 When used in chat will present a menu to choose a sound to play.
	!stop	 			 When used in chat will per-user stop any sound currently playing by this plug-in

*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#undef REQUIRE_EXTENSIONS
#include <tf2_stocks>
#define REQUIRE_EXTENSIONS

// *** Sound Info Library ***
#include <soundlib>

#undef REQUIRE_PLUGIN
#include <adminmenu>

// BEIGN MOD BY LAMDACORE
// extra memory usability for a lot of sounds.
// Uncomment the next line (w/#pragma) to add additional memory
//#pragma dynamic 65536 
#pragma dynamic 131072
// END MOD BY LAMDACORE


#define PLUGIN_VERSION "4.0.9"
#define USE_SOUND_EVENT

//*****************************************************************
//	------------------------------------------------------------- *
//			*** Defines for checkClientCookies ***				  *
//	------------------------------------------------------------- *
//*****************************************************************
#define CHK_CHATMSG		1
#define CHK_SAYSOUNDS	2
#define CHK_EVENTS		3
#define CHK_KARAOKE		4
#define CHK_BANNED		5
#define CHK_GREETED		6

//*****************************************************************
//	------------------------------------------------------------- *
//			*** Define countdown sounds for karaoke ***			  *
//	------------------------------------------------------------- *
//*****************************************************************
#define TF2_ATTENTION	"vo/announcer_attention.wav"
#define TF2_20_SECONDS	"vo/announcer_begins_20sec.wav"
#define TF2_10_SECONDS	"vo/announcer_begins_10sec.wav"
#define TF2_5_SECONDS	"vo/announcer_begins_5sec.wav"
#define TF2_4_SECONDS	"vo/announcer_begins_4sec.wav"
#define TF2_3_SECONDS	"vo/announcer_begins_3sec.wav"
#define TF2_2_SECONDS	"vo/announcer_begins_2sec.wav"
#define TF2_1_SECOND	"vo/announcer_begins_1sec.wav"

#define HL2_ATTENTION	"npc/overwatch/radiovoice/attention.wav"
#define HL2_10_SECONDS	"npc/overwatch/cityvoice/fcitadel_10sectosingularity.wav"
#define HL2_5_SECONDS	"npc/overwatch/radiovoice/five.wav"
#define HL2_4_SECONDS	"npc/overwatch/radiovoice/four.wav"
#define HL2_3_SECONDS	"npc/overwatch/radiovoice/three.wav"
#define HL2_2_SECONDS	"npc/overwatch/radiovoice/two.wav"
#define HL2_1_SECOND	"npc/overwatch/radiovoice/one.wav"

enum sound_types { normal_sounds, admin_sounds, karaoke_sounds, all_sounds };

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Cvar Handles ***						  *
//	------------------------------------------------------------- *
//*****************************************************************
ConVar cvarsaysoundversion;
ConVar cvarsoundenable;
ConVar cvarsoundlimit;
ConVar cvarsoundlimitFlags;
ConVar cvarsoundFlags;
ConVar cvarsoundFlagsLimit;
ConVar cvarsoundwarn;
ConVar cvarjoinexit;
ConVar cvarjoinspawn;
ConVar cvarspecificjoinexit;
ConVar cvartimebetween;
ConVar cvartimebetweenFlags;
ConVar cvaradmintime;
ConVar cvaradminwarn;
ConVar cvaradminlimit;
ConVar cvarannounce;
ConVar cvaradult;
ConVar cvarsentence;
ConVar cvarlogging;
ConVar cvarplayifclsndoff;
ConVar cvarkaraokedelay;
ConVar cvarvolume; // mod by Woody
ConVar cvarsoundlimitround;
ConVar cvarexcludelastsound;
ConVar cvarblocktrigger;
ConVar cvarinterruptsound;
ConVar cvarfilterifdead;
ConVar cvarTrackDisconnects;
ConVar cvarStopFlags;
ConVar cvarMenuSettingsFlags;
#if defined USE_SOUND_EVENT
ConVar g_hMapvoteDuration;
#endif
//####FernFerret####/
ConVar cvarshowsoundmenu;
//##################/
KeyValues listfile					= null;
Handle hAdminMenu				= null;
StringMap g_hSoundCountTrie			= null;
char soundlistfile[PLATFORM_MAX_PATH] = "";

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Client Peferences ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
//Handle g_ssgeneral_cookie = INVALID_HANDLE;	// Cookie for storing clints general saysound setting (ON/OFF)
Handle g_sssaysound_cookie		= INVALID_HANDLE;	// Cookie for storing clints saysound setting (ON/OFF)
Handle g_ssevents_cookie		= INVALID_HANDLE;	// Cookie for storing clients eventsound setting (ON/OFF)
Handle g_sschatmsg_cookie		= INVALID_HANDLE;	// Cookie for storing clients chat message setting (ON/OFF)
Handle g_sskaraoke_cookie		= INVALID_HANDLE; // Cookie for storing clients karaoke setting (ON/OFF)
Handle g_ssban_cookie			= INVALID_HANDLE;		// Cookie for storing if client is banned from using saysiunds
Handle g_ssgreeted_cookie		= INVALID_HANDLE;	// Cookie for storing if we've played the welcome sound to the client
//Handle g_dbClientprefs			= INVALID_HANDLE;	// Handle for the clientprefs SQLite DB

//*****************************************************************
//	------------------------------------------------------------- *
//						*** Variables ***						  *
//	------------------------------------------------------------- *
//*****************************************************************
//int restrict_playing_sounds[MAXPLAYERS+1];
//int SndOn[MAXPLAYERS+1];
int SndCount[MAXPLAYERS+1];
char SndPlaying[MAXPLAYERS+1][PLATFORM_MAX_PATH];
//float LastSound[MAXPLAYERS+1];
bool firstSpawn[MAXPLAYERS+1];
//bool greeted[MAXPLAYERS+1];
float globalLastSound = 0.0;
float globalLastAdminSound = 0.0;
char LastPlayedSound[PLATFORM_MAX_PATH+1];
bool hearalive = true;
bool gb_csgo = false;

// Variables for karaoke
KeyValues karaokeFile = null;
Handle karaokeTimer = INVALID_HANDLE;
float karaokeStartTime = 0.0;

// Variables to enable/disable advertisments plugin during karaoke
ConVar cvaradvertisements;
bool advertisements_enabled = false;

// Some event variable
//bool TF2waiting = false;
//int g_BroadcastAudioTeam;
//	Kill Event: If someone kills a few clients with a crit
//				make sure he won't get spammed with the corresponding sound
bool g_bPlayedEvent2Client[MAXPLAYERS+1] = {false, ...};

int g_LastSoundCount = 0;

//*****************************************************************
//	------------------------------------------------------------- *
//						*** Plugin Info ***						  *
//	------------------------------------------------------------- *
//*****************************************************************
public Plugin myinfo = 
{
	name = "Say Sounds (including Hybrid Edition)",
	author = "Hell Phoenix|Naris|FernFerret|Uberman|psychonic|edgecom|woody|Miraculix|gH0sTy|Duko",
	description = "Say Sounds and Action Sounds packaged into one neat plugin! Welcome to the new day of SaySounds Hybrid!",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=82220"
};

//*****************************************************************
//	------------------------------------------------------------- *
//				*** Inculding seperate files ***				  *
//	------------------------------------------------------------- *
//*****************************************************************
#include "saysounds/gametype.sp"
#include "saysounds/resourcemanager.sp"
#include "saysounds/checks.sp"
#include "saysounds/menu.sp"

//*****************************************************************
//	------------------------------------------------------------- *
//						*** Plugin Start ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
public void OnPluginStart()
{
	if (GetGameType() == l4d2 || GetGameType() == l4d)
		SetFailState("The Left 4 Dead series is not supported!");

	// ***Load Translations **
	LoadTranslations("common.phrases");
	LoadTranslations("saysoundhe.phrases");

	// *** Creating the Cvars ***
	cvarsaysoundversion = CreateConVar("sm_saysounds_hybrid_version", PLUGIN_VERSION, "Say Sounds Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	cvarsoundenable = CreateConVar("sm_saysoundhe_enable","1","Turns Sounds On/Off");
	// Client limit cvars
	cvarsoundwarn = CreateConVar("sm_saysoundhe_sound_warn","3","Number of sounds to warn person at (0 for no warnings)");
	cvarsoundlimit = CreateConVar("sm_saysoundhe_sound_limit","5","Maximum sounds per person (0 for unlimited)");
	cvarsoundlimitFlags = CreateConVar("sm_saysoundhe_sound_flags","","User flags that will result in unlimited sounds");
	cvarsoundFlags = CreateConVar("sm_saysoundhe_flags","","Flag(s) that will have a seperate sound limit");
	cvarsoundFlagsLimit = CreateConVar("sm_saysoundhe_flags_limit","5","Maximum sounds per person with the corresponding flag (0 for unlimited)");
	// Join cvars
	cvarjoinexit = CreateConVar("sm_saysoundhe_join_exit","0","Play sounds when someone joins or exits the game");
	cvarjoinspawn = CreateConVar("sm_saysoundhe_join_spawn","1","Wait until the player spawns before playing the join sound");
	cvarspecificjoinexit = CreateConVar("sm_saysoundhe_specific_join_exit","1","Play sounds when specific steam ID joins or exits the game");
	// Anti-Spam cavrs
	cvartimebetween = CreateConVar("sm_saysoundhe_time_between_sounds","4.5","Time between each sound trigger, 0.0 to disable checking");
	cvartimebetweenFlags = CreateConVar("sm_saysoundhe_time_between_flags","","User flags to bypass the Time between sounds check");
	// Admin limit cvars
	cvaradmintime = CreateConVar("sm_saysoundhe_time_between_admin_sounds","4.5","Time between each admin sound trigger, 0.0 to disable checking for admin sounds \nSet to -1 to completely bypass the soundspam protection for admins");
	cvaradminwarn = CreateConVar("sm_saysoundhe_sound_admin_warn","0","Number of sounds to warn admin at (0 for no warnings)");
	cvaradminlimit = CreateConVar("sm_saysoundhe_sound_admin_limit","0","Maximum sounds per admin (0 for unlimited)");
	//
	cvarsoundlimitround = CreateConVar("sm_saysoundhe_limit_sound_per_round", "0", "If set, sm_saysoundhe_sound_limit is the limit per round instead of per map");
	//
	cvarannounce = CreateConVar("sm_saysoundhe_sound_announce","1","Turns on announcements when a sound is played");
	cvaradult = CreateConVar("sm_saysoundhe_adult_announce","0","Announce played adult sounds? | 0 = off 1 = on");
	cvarsentence = CreateConVar("sm_saysoundhe_sound_sentence","0","When set, will trigger sounds if keyword is embedded in a sentence");
	cvarlogging = CreateConVar("sm_saysoundhe_sound_logging","0","When set, will log sounds that are played");
	cvarvolume = CreateConVar("sm_saysoundhe_saysounds_volume","1.0","Volume setting for Say Sounds (0.0 <= x <= 1.0)",0,true,0.0,true,1.0); // mod by Woody
	cvarplayifclsndoff = CreateConVar("sm_saysoundhe_play_cl_snd_off","0","When set, allows clients that have turned their sounds off to trigger sounds (0=off | 1=on)");
	cvarkaraokedelay = CreateConVar("sm_saysoundhe_karaoke_delay","15.0","Delay before playing a Karaoke song");
	cvarexcludelastsound = CreateConVar("sm_saysoundhe_excl_last_sound", "0", "If set, don't allow to play a sound that was recently played");
	cvarblocktrigger = CreateConVar("sm_saysoundhe_block_trigger", "0", "If set, block the sound trigger to be displayed in the chat window");
	cvarinterruptsound = CreateConVar("sm_saysoundhe_interrupt_sound", "0", "If set, interrupt the current sound when a new start");
	cvarfilterifdead = CreateConVar("sm_saysoundhe_filter_if_dead", "0", "If set, alive players do not hear sounds triggered by dead players");
	cvarTrackDisconnects = CreateConVar("sm_saysoundhe_track_disconnects", "1", "If set, stores sound counts when clients leave and loads them when they join.");
	cvarStopFlags = CreateConVar("sm_saysoundhe_stop_flags","","User flags that are allowed to stop a sound");
	cvarMenuSettingsFlags = CreateConVar("sm_saysoundhe_confmenu_flags","","User flags that are allowed to access the configuration menu");

#if !defined _ResourceManager_included
	cvarDownloadThreshold = CreateConVar("sm_saysoundhe_download_threshold", "-1", "Number of sounds to download per map start (-1=unlimited).");
	cvarSoundThreshold = CreateConVar("sm_saysoundhe_sound_threshold", "0", "Number of sounds to precache on map start (-1=unlimited).");
	cvarSoundLimitMap	 = CreateConVar("sm_saysoundhe_sound_max", "-1", "Maximum number of sounds to allow (-1=unlimited).");
#endif

	//####FernFerret####//
	// This is the Variable that will enable or disable the sound menu to public users, Admin users will always have
	// access to their menus, From the admin menu it is a toggle variable
	cvarshowsoundmenu = CreateConVar("sm_saysoundhe_showmenu","1","1 To show menu to users, 0 to hide menu from users (admins excluded)");
	//##################//

	//##### Clientprefs #####
	// for storing clients sound settings
	g_sssaysound_cookie = RegClientCookie("saysoundsplay", "Play Say Sounds", CookieAccess_Protected);
	g_ssevents_cookie = RegClientCookie("saysoundsevent", "Play Action sounds", CookieAccess_Protected);
	g_sschatmsg_cookie = RegClientCookie("saysoundschatmsg", "Display Chat messages", CookieAccess_Protected);
	g_sskaraoke_cookie = RegClientCookie("saysoundskaraoke", "Play Karaoke music", CookieAccess_Protected);
	g_ssban_cookie = RegClientCookie("saysoundsban", "Banned From Say Sounds", CookieAccess_Protected);
	g_ssgreeted_cookie = RegClientCookie("saysoundsgreeted", "Join sound Cache", CookieAccess_Protected);
	SetCookieMenuItem(SaysoundClientPref, 0, "Say Sounds Preferences");
	//SetCookiePrefabMenu(g_sssaysound_cookie, CookieMenu_OnOff, "Saysounds ON/OFF");
	//#######################

	// #### Handle Enabling/Disabling of Say Sounds ###
	HookConVarChange(cvarsoundenable, EnableChanged);

	RegAdminCmd("sm_sound_ban", Command_Sound_Ban, ADMFLAG_BAN, "sm_sound_ban <user> : Bans a player from using sounds");
	RegAdminCmd("sm_sound_unban", Command_Sound_Unban, ADMFLAG_BAN, "sm_sound_unban <user> : Unbans a player from using sounds");
	RegAdminCmd("sm_sound_reset", Command_Sound_Reset, ADMFLAG_GENERIC, "sm_sound_reset <user | all> : Resets sound quota for user, or everyone if all");
	RegAdminCmd("sm_admin_sounds", Command_Admin_Sounds,ADMFLAG_GENERIC, "Display a menu of Admin sounds to play");
	RegAdminCmd("sm_karaoke", Command_Karaoke, ADMFLAG_GENERIC, "Display a menu of Karaoke songs to play");
	//####FernFerret####/
	// This is the admin command that shows all sounds, it is currently set to show to a GENERIC ADMIN
	RegAdminCmd("sm_all_sounds", Command_All_Sounds, ADMFLAG_GENERIC,"Display a menu of ALL sounds to play");
	//##################/

	RegConsoleCmd("sm_sound_list", Command_Sound_List, "List available sounds to console");
	RegConsoleCmd("sm_sound_menu", Command_Sound_Menu, "Display a menu of sounds to play");
	//RegConsoleCmd("say", Command_Say);
	AddCommandListener(Command_Say, "say");
	//RegConsoleCmd("say2", Command_InsurgencySay);
	AddCommandListener(Command_Say, "say2");
	//RegConsoleCmd("say_team", Command_Say);
	AddCommandListener(Command_Say, "say_team");
	
	// *** Execute the config file ***
	AutoExecConfig(true, "sm_saysounds");

	//*****************************************************************
	//	------------------------------------------------------------- *
	//						*** Hooking Events ***					  *
	//	------------------------------------------------------------- *
	//*****************************************************************
	if(cvarsoundenable.BoolValue) 
	{
#if defined USE_SOUND_EVENT
		HookEvent("player_death", Event_Kill);
#endif
		HookEvent("player_disconnect", Event_Disconnect, EventHookMode_Pre);
		HookEventEx("player_spawn",PlayerSpawn);

		if (GetGameType() == tf2)
		{
			LogMessage("[Say Sounds] Detected Team Fortress 2");
			HookEvent("player_builtobject", Event_Build);
			HookEvent("teamplay_round_start", Event_RoundStart);
			//HookEvent("teamplay_round_active", Event_SetupStart);
#if defined USE_SOUND_EVENT
			HookEvent("teamplay_flag_event", Event_Flag);
			HookEvent("player_chargedeployed", Event_UberCharge);
			HookEvent("teamplay_setup_finished", Event_SetupEnd);
			//HookEvent("teamplay_waiting_begins", Event_WaitingStart);
			//HookEvent("teamplay_waiting_ends", Event_WaitingEnd);
			HookEvent("teamplay_broadcast_audio", OnAudioBroadcast, EventHookMode_Pre);
#endif
		}
		else if (GetGameType() == dod)
		{
			LogMessage("[Say Sounds] Detected Day of Defeat");
			HookEvent("dod_round_start", Event_RoundStart);
			//HookEvent("dod_round_win", Event_RoundWin);
#if defined USE_SOUND_EVENT
			HookEvent("player_hurt", Event_Hurt);
			HookEvent("dod_broadcast_audio", OnAudioBroadcast, EventHookMode_Pre);
#endif
		}
		else if (GetGameType() == zps)
		{
			LogMessage("[Say Sounds] Detected Zombie Panic:Source");
			HookEvent("game_round_restart", Event_RoundStart);
		}
		else if (GetGameType() == cstrike)
		{
			LogMessage("[Say Sounds] Detected Counter Strike");
			HookEvent("round_start", Event_RoundStart);
#if defined USE_SOUND_EVENT
			HookEvent("round_end", Event_RoundEnd);
#endif
		}
		else if (GetGameType() == hl2mp)
		{
			LogMessage("[Say Sounds] Detected Half-Life 2 Deathmatch");
			HookEvent("teamplay_round_start",Event_RoundStart);
		}
		else if (GetGameType() == csgo)
		{
			LogMessage("[Say Sounds] Detected Counter-Strike: Global Offensive");
			HookEvent("round_start", Event_RoundStart);
			gb_csgo = true;
		}
		else if (GetGameType() == other_game)
		{
			LogMessage("[Say Sounds] No specific game detected");
			HookEvent("round_start", Event_RoundStart);
		}

		// if there are no limits, there is no need to save counts
		if (cvarTrackDisconnects.BoolValue &&
			(cvarsoundlimit.IntValue > 0 ||
			 cvaradminlimit.IntValue > 0 ||
			 cvarsoundFlagsLimit.IntValue > 0))
		{
			g_hSoundCountTrie = new StringMap();
		}
	}

	//*****************************************************************
	//	------------------------------------------------------------- *
	//				*** Account for late loading ***				  *
	//	------------------------------------------------------------- *
	//*****************************************************************
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
		OnAdminMenuReady(topmenu);

	// *** Update the Plugin Version cvar ***
	cvarsaysoundversion.SetString(PLUGIN_VERSION, true, true);
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Un/Hooking Events ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
public void EnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int intNewValue = StringToInt(newValue);
	int intOldValue = StringToInt(oldValue);

	if (intNewValue == 1 && intOldValue == 0) 
	{
		LogMessage("[Say Sounds] Enabled, Hooking Events");
		
		AddCommandListener(Command_Say, "say");
		AddCommandListener(Command_Say, "say2");
		AddCommandListener(Command_Say, "say_team");

#if defined USE_SOUND_EVENT
		HookEvent("player_death", Event_Kill);
#endif
		HookEvent("player_disconnect", Event_Disconnect, EventHookMode_Pre);
		HookEventEx("player_spawn",PlayerSpawn);

		if (GetGameType() == tf2)
		{
			LogMessage("[Say Sounds] Detected Team Fortress 2");
			HookEvent("player_builtobject", Event_Build);
			HookEvent("teamplay_round_start", Event_RoundStart);
			//HookEvent("teamplay_round_active", Event_SetupStart);
#if defined USE_SOUND_EVENT
			HookEvent("teamplay_flag_event", Event_Flag);
			HookEvent("player_chargedeployed", Event_UberCharge);
			HookEvent("teamplay_setup_finished", Event_SetupEnd);
			//HookEvent("teamplay_waiting_begins", Event_WaitingStart);
			//HookEvent("teamplay_waiting_ends", Event_WaitingEnd);
			HookEvent("teamplay_broadcast_audio", OnAudioBroadcast, EventHookMode_Pre);
#endif
		}
		else if (GetGameType() == dod)
		{
			LogMessage("[Say Sounds] Detected Day of Defeat");
			HookEvent("dod_round_start", Event_RoundStart);
			//HookEvent("dod_round_win", Event_RoundWin);
#if defined USE_SOUND_EVENT
			HookEvent("player_hurt", Event_Hurt);
			HookEvent("dod_broadcast_audio", OnAudioBroadcast, EventHookMode_Pre);
#endif
		}
		else if (GetGameType() == zps)
		{
			LogMessage("[Say Sounds] Detected Zombie Panic:Source");
			HookEvent("game_round_restart", Event_RoundStart);
		}
		else if (GetGameType() == cstrike)
		{
			LogMessage("[Say Sounds] Detected Counter Strike");
			HookEvent("round_start", Event_RoundStart);
#if defined USE_SOUND_EVENT
			HookEvent("round_end", Event_RoundEnd);
#endif
		}
		else if (GetGameType() == hl2mp)
		{
			LogMessage("[Say Sounds] Detected Half-Life 2 Deathmatch");
			HookEvent("teamplay_round_start",Event_RoundStart);
		}
		else if (GetGameType() == csgo)
		{
			LogMessage("[Say Sounds] Detected Counter-Strike: Global Offensive");
			HookEvent("round_start", Event_RoundStart);
			gb_csgo = true;
		}
		else if (GetGameType() == other_game)
		{
			LogMessage("[Say Sounds] No specific game detected");
			HookEvent("round_start", Event_RoundStart);
		}

		ClearSoundCountTrie();
	}
	else if (intNewValue == 0 && intOldValue == 1) 
	{
		LogMessage("[Say Sounds] Disabled, Unhooking Events");
		
		RemoveCommandListener(Command_Say, "say");
		RemoveCommandListener(Command_Say, "say2");
		RemoveCommandListener(Command_Say, "say_team");

#if defined USE_SOUND_EVENT
		UnhookEvent("player_death", Event_Kill);
#endif
		UnhookEvent("player_disconnect", Event_Disconnect, EventHookMode_Pre);
		UnhookEvent("player_spawn",PlayerSpawn);

		if (GetGameType() == tf2)
		{
			UnhookEvent("player_builtobject", Event_Build);
			UnhookEvent("teamplay_round_start", Event_RoundStart);
#if defined USE_SOUND_EVENT
			UnhookEvent("teamplay_flag_event", Event_Flag);
			UnhookEvent("player_chargedeployed", Event_UberCharge);
			//HookEvent("teamplay_round_active", Event_SetupStart);
			UnhookEvent("teamplay_setup_finished", Event_SetupEnd);
			//UnhookEvent("teamplay_waiting_begins", Event_WaitingStart);
			//UnhookEvent("teamplay_waiting_ends", Event_WaitingEnd);
			UnhookEvent("teamplay_broadcast_audio", OnAudioBroadcast, EventHookMode_Pre);
#endif
		}
		else if (GetGameType() == dod)
		{
			UnhookEvent("dod_round_start", Event_RoundStart);
#if defined USE_SOUND_EVENT
			UnhookEvent("player_hurt", Event_Hurt);
			//UnhookEvent("dod_round_win", Event_RoundWin);
			UnhookEvent("dod_broadcast_audio", OnAudioBroadcast, EventHookMode_Pre);
#endif
		}
		else if (GetGameType() == zps)
		{
			UnhookEvent("game_round_restart", Event_RoundStart);
		}
		else if (GetGameType() == cstrike)
		{
			UnhookEvent("round_start", Event_RoundStart);
#if defined USE_SOUND_EVENT
			UnhookEvent("round_end", Event_RoundEnd);
#endif
		}
		else if (GetGameType() == hl2mp)
		{
			UnhookEvent("teamplay_round_start",Event_RoundStart);
		}
		else if (GetGameType() == csgo)
		{
			UnhookEvent("round_start", Event_RoundStart);
		}
		else if (GetGameType() == other_game)
		{
			UnhookEvent("round_start", Event_RoundStart);
		}
	}
}

//*****************************************************************
//	------------------------------------------------------------- *
//						*** Plugin End ***					 	  *
//	------------------------------------------------------------- *
//*****************************************************************
public void OnPluginEnd()
{
	if (listfile != null)
	{
		delete listfile;
		listfile = null;
	}

	if (karaokeFile != null)
	{
		delete karaokeFile;
		karaokeFile = null;
	}
}

//*****************************************************************
//	------------------------------------------------------------- *
//						  *** Map Start ***						  *
//	------------------------------------------------------------- *
//*****************************************************************
public void OnMapStart()
{
	LastPlayedSound[0] = '\0';
	globalLastSound = 0.0;
	globalLastAdminSound = 0.0;

	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		SndCount[i] = 0;
		//LastSound[i] = 0.0;
	}

	ClearSoundCountTrie();

	#if !defined _ResourceManager_included
		g_iDownloadThreshold = cvarDownloadThreshold.IntValue;
		g_iSoundThreshold	= cvarSoundThreshold.IntValue;
		g_iSoundLimit		= cvarSoundLimitMap.IntValue;

		// Setup trie to keep track of precached sounds
		if (g_soundTrie == null)
			g_soundTrie = new StringMap();
		else
			g_soundTrie.Clear();
	#endif

	/* Delay precaching the karaoke countdown sounds
		 * until they are actually used.
		 *
	if (GetGameType() == tf2) {
		PrecacheSound(TF2_ATTENTION, true);
		PrecacheSound(TF2_20_SECONDS, true);
		PrecacheSound(TF2_10_SECONDS, true);
		PrecacheSound(TF2_5_SECONDS, true);
		PrecacheSound(TF2_4_SECONDS, true);
		PrecacheSound(TF2_3_SECONDS, true);
		PrecacheSound(TF2_2_SECONDS, true);
		PrecacheSound(TF2_1_SECOND, true);
	} else {
		PrecacheSound(HL2_ATTENTION, true);
		PrecacheSound(HL2_10_SECONDS, true);
		PrecacheSound(HL2_5_SECONDS, true);
		PrecacheSound(HL2_4_SECONDS, true);
		PrecacheSound(HL2_3_SECONDS, true);
		PrecacheSound(HL2_2_SECONDS, true);
		PrecacheSound(HL2_1_SECOND, true);
	}
	*/
}

//*****************************************************************
//	------------------------------------------------------------- *
//						  *** Map End ***						  *
//	------------------------------------------------------------- *
//*****************************************************************
public void OnMapEnd()
{
	/*if (g_dbClientprefs != INVALID_HANDLE)
	{
		CloseHandle(g_dbClientprefs);
		g_dbClientprefs = INVALID_HANDLE;
	}*/

	if (g_hSoundCountTrie != null)
	{
		delete g_hSoundCountTrie;
		g_hSoundCountTrie = null;
	}

	if (listfile != null)
	{
		delete listfile;
		listfile = null;
	}

	if (karaokeFile != null)
	{
		delete karaokeFile;
		karaokeFile = null;
	}

	if (karaokeTimer != INVALID_HANDLE)
	{
		KillTimer(karaokeTimer);
		karaokeTimer = INVALID_HANDLE;
	}

#if !defined _ResourceManager_included
	if (g_iPrevDownloadIndex >= g_iSoundCount ||
		g_iDownloadCount < g_iDownloadThreshold)
	{
		g_iPrevDownloadIndex = 0;
	}

	g_iDownloadCount	 = 0;
	g_iSoundCount		= 0;
#endif
}

public void OnConfigsExecuted()
{
	CreateTimer(0.1, Load_Sounds, _, TIMER_FLAG_NO_MAPCHANGE);
}

//*****************************************************************
//	------------------------------------------------------------- *
//						  *** Map Vote ***						  *
//	------------------------------------------------------------- *
//*****************************************************************
#if defined USE_SOUND_EVENT
public void OnMapVoteStarted()
{
	g_hMapvoteDuration	= FindConVar("sm_mapvote_voteduration");
	
	if (g_hMapvoteDuration != null)
		CreateTimer(g_hMapvoteDuration.FloatValue, TimerMapvoteEnd);
	else
		LogError("ConVar sm_mapvote_voteduration not found!");
	
	runSoundEvent(null, "mapvote", "start", 0, 0, -1);
}

public Action TimerMapvoteEnd(Handle timer)
{
	runSoundEvent(null, "mapvote", "end", 0, 0, -1);
	
	return Plugin_Stop;
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Waiting for Players ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
public void TF2_OnWaitingForPlayersStart()
{
	runSoundEvent(null, "wait4players", "start", 0, 0, -1);
}

public void TF2_OnWaitingForPlayersEnd()
{
	runSoundEvent(null, "wait4players", "end", 0, 0, -1);
}
#endif
//*****************************************************************
//	------------------------------------------------------------- *
//				*** Load the Sounds from the Config ***			  *
//	------------------------------------------------------------- *
//*****************************************************************
public Action Load_Sounds(Handle timer)
{
	// precache sounds, loop through sounds
	BuildPath(Path_SM,soundlistfile,sizeof(soundlistfile),"configs/saysounds.cfg");
	if(!FileExists(soundlistfile))
	{
		SetFailState("saysounds.cfg not parsed...file doesnt exist!");
	}
	else
	{
		if (listfile != null)
			delete listfile;

		listfile = new KeyValues("soundlist");
		listfile.ImportFromFile(soundlistfile);
		listfile.Rewind();
		if (listfile.GotoFirstSubKey())
		{
			do
			{
				if (listfile.GetNum("enable", 1))
				{
					char filelocation[PLATFORM_MAX_PATH+1];
					char file[8];
					int count = listfile.GetNum("count", 1);
					int download = listfile.GetNum("download", 1);
					bool force = view_as<bool>(listfile.GetNum("force", 0));
					bool precache = view_as<bool>(listfile.GetNum("precache", 0));
					bool preload = view_as<bool>(listfile.GetNum("preload", 0));
					for (int i = 0; i <= count; i++)
					{
						if (i)
							Format(file, sizeof(file), "file%d", i);
						else
							strcopy(file, sizeof(file), "file");

						filelocation[0] = '\0';
						listfile.GetString(file, filelocation, sizeof(filelocation), "");
						if (filelocation[0] != '\0')
							SetupSound(filelocation, force, download, precache, preload);
					}
				}
			} while (listfile.GotoNextKey());
		}
		else
			SetFailState("saysounds.cfg not parsed...No subkeys found!");
	}
	return Plugin_Handled;
}

//*****************************************************************
//	------------------------------------------------------------- *
//						*** UNSORTED ***						  *
//	------------------------------------------------------------- *
//*****************************************************************
void ResetClientSoundCount()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		SndCount[i] = 0;
	}

	ClearSoundCountTrie();
}

public Action reset_PlayedEvent2Client(Handle timer, any client)
{
	g_bPlayedEvent2Client[client] = false;
	
	return Plugin_Stop;
}

//*****************************************************************
//	------------------------------------------------------------- *
//						*** Event Actions ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
public Action Event_Disconnect(Event event, const char[] name, bool dontBroadcast)
{
	char SteamID[60];
	GetEventString(event, "networkid", SteamID, sizeof(SteamID));
	SetAuthIdCookie(SteamID, g_ssgreeted_cookie, "0");
	int id2Client = GetClientOfUserId(event.GetInt("userid"));

	if (g_hSoundCountTrie != null)
		g_hSoundCountTrie.SetValue(SteamID, SndCount[id2Client]);
	
	return Plugin_Continue;
}
#if defined USE_SOUND_EVENT
public Action OnAudioBroadcast(Event event, const char[] name, bool dontBroadcast)
{
	if(!cvarsoundenable.BoolValue)
		return Plugin_Continue;

	char sound[30];
	GetEventString(event, "sound", sound, sizeof(sound));

	if (GetGameType() == tf2)
	{
		int iTeam = event.GetInt("team");
		if (StrEqual(sound, "Game.Stalemate") && runSoundEvent(event,"round","Stalemate",0,0,-1))
			return Plugin_Handled;
		else if (StrEqual(sound, "Game.SuddenDeath") && runSoundEvent(event,"round","SuddenDeath",0,0,-1))
			return Plugin_Handled;
		else if (StrEqual(sound, "Game.YourTeamWon") && runSoundEvent(event,"round","won",0,0,iTeam))
			return Plugin_Handled;
		else if (StrEqual(sound, "Game.YourTeamLost") && runSoundEvent(event,"round","lost",0,0,iTeam))
			return Plugin_Handled;
	}
	else if (GetGameType() == dod)
	{
		if (StrEqual(sound, "Game.USWin") && runSoundEvent(event,"round","USWon",0,0,-1))
			return Plugin_Handled;
		else if (StrEqual(sound, "Game.GermanWin") && runSoundEvent(event,"round","GERWon",0,0,-1))
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Event_SetupEnd(Event event, const char[] name, bool dontBroadcast)
{
	runSoundEvent(event,"round","setupend",0,0,-1);
	return Plugin_Continue;
}
#endif
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
#if defined USE_SOUND_EVENT
	runSoundEvent(event,"round","start",0,0,-1);
#endif
	if (cvarsoundlimitround.BoolValue)
		ResetClientSoundCount();

	return Plugin_Continue;
}
#if defined USE_SOUND_EVENT
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	runSoundEvent(event,"round","end",0,0,-1);
	return Plugin_Continue;
}

public Action Event_UberCharge(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim   = GetClientOfUserId(event.GetInt("targetid"));
	runSoundEvent(event,"uber","uber",attacker,victim,-1);
	return Plugin_Continue;
}

public Action Event_Flag(Event event, const char[] name, bool dontBroadcast)
{
	// pick up(1), capture(2), defend(3), dropped(4)
	// Translate the Integer that is the input to a string so that users
	// can just add a string to the config file
	char flagstring[PLATFORM_MAX_PATH+1];
	int flagint;
	flagint = event.GetInt("eventtype");
	switch (flagint)
	{
		case 1:
			strcopy(flagstring,sizeof(flagstring),"flag_picked_up");
		case 2:
			strcopy(flagstring,sizeof(flagstring),"flag_captured");
		case 3:
			strcopy(flagstring,sizeof(flagstring),"flag_defended");
		case 4:
			strcopy(flagstring,sizeof(flagstring),"flag_dropped");
		default:
			strcopy(flagstring,sizeof(flagstring),"flag_captured");
	}
	runSoundEvent(event,"flag",flagstring,0,0,-1);
	return Plugin_Continue;
}

public Action Event_Kill(Event event, const char[] name, bool dontBroadcast)
{
	char wepstring[PLATFORM_MAX_PATH+1];
	// psychonic, octo, FernFerret
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim   = GetClientOfUserId(event.GetInt("userid"));

	if (attacker == victim)
	{
		runSoundEvent(event,"kill","suicide",0,victim,-1);
		return Plugin_Continue;
	}
	else
	{
		GetEventString(event, "weapon_logclassname",wepstring,PLATFORM_MAX_PATH+1);

		if (GetGameType() == tf2)
		{
			int custom_kill = event.GetInt("customkill");
			if (custom_kill == TF_CUSTOM_HEADSHOT)
			{
				runSoundEvent(event,"kill","headshot",attacker,victim,-1);
				return Plugin_Continue;
			}
			if (custom_kill == TF_CUSTOM_BACKSTAB)
			{
				runSoundEvent(event,"kill","backstab",attacker,victim,-1);
				return Plugin_Continue;
			}
			if (custom_kill == TF_CUSTOM_TELEFRAG)
			{
				runSoundEvent(event,"kill","telefrag",attacker,victim,-1);
				return Plugin_Continue;
			}
			int bits = event.GetInt("damagebits");
			if (bits & 1048576 && attacker > 0)
			{
				runSoundEvent(event,"kill","crit_kill",attacker,victim,-1);
				return Plugin_Continue;
			}
			if (bits == 16 && victim > 0)
			{
				runSoundEvent(event,"kill","hit_by_train",0,victim,-1);
				return Plugin_Continue;
			}
			if (bits == 16384 && victim > 0)
			{
				runSoundEvent(event,"kill","drowned",0,victim,-1);
				return Plugin_Continue;
			}
			if (bits & 32 && victim > 0)
			{
				runSoundEvent(event,"kill","fall",0,victim,-1);
				return Plugin_Continue;
			}

			GetEventString(event, "weapon_logclassname",wepstring,PLATFORM_MAX_PATH+1);
		}
		else if (GetGameType() == cstrike || GetGameType() == csgo)
		{
			int headshot = 0;
			headshot = GetEventBool(event, "headshot");
			if (headshot == 1)
			{
				runSoundEvent(event,"kill","headshot",attacker,victim,-1);
				return Plugin_Continue;
			}
			GetEventString(event, "weapon",wepstring,PLATFORM_MAX_PATH+1);
		}
		else
		{
			GetEventString(event, "weapon",wepstring,PLATFORM_MAX_PATH+1);
		}

		runSoundEvent(event,"kill",wepstring,attacker,victim,-1);

		return Plugin_Continue;
	}
}

// ####### Day of Defeat #######
public Action Event_Hurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim   = GetClientOfUserId(event.GetInt("userid"));
	int headshot = (event.GetInt("health") == 0 && event.GetInt("hitgroup") == 1);

	if (headshot)
		runSoundEvent(event, "kill", "headshot", attacker, victim, -1);

	return Plugin_Continue;
}
#endif
// ####### TF2 #######
public Action Event_Build(Event event, const char[] name, bool dontBroadcast)
{
	char objectstr[PLATFORM_MAX_PATH+1];
	int objectint = event.GetInt("object");
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	switch(objectint)
	{
		case 0:
			strcopy(objectstr,sizeof(objectstr),"obj_dispenser");
		case 1:
			strcopy(objectstr,sizeof(objectstr),"obj_tele_in");
		case 2:
			strcopy(objectstr,sizeof(objectstr),"obj_tele_out");
		case 3:
			strcopy(objectstr,sizeof(objectstr),"obj_sentry");
		default:
			strcopy(objectstr,sizeof(objectstr),"obj_dispenser");
	}
	runSoundEvent(event,"build",objectstr,attacker,0,-1);
	return Plugin_Continue;
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Run Event Sounds ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
// Generic Sound event, this gets triggered whenever an event that is supported is triggered
public bool runSoundEvent(Event event, const char[] type, const char[] extra, const int attacker, const int victim, const int team)
{
	char action[PLATFORM_MAX_PATH+1];
	char extraparam[PLATFORM_MAX_PATH+1];
	char location[PLATFORM_MAX_PATH+1];
	char playto[PLATFORM_MAX_PATH+1];
	bool result = false;

	if (listfile == null)
		return false;

	listfile.Rewind();
	if (!listfile.GotoFirstSubKey())
		return false;

	// Do while loop that finds out what extra parameter is and plays according sound, also adds random
	do
	{
		listfile.GetString("action", action, sizeof(action), "");
		//PrintToServer("Found Subkey, trying to match (%s) with (%s)", action, type);
		if (StrEqual(action, type, false))
		{
			if (!listfile.GetNum("enable", 1))
				continue;

			//listfile.GetString("file", location, sizeof(location), "");
			// ###### Random Sound ######
			char file[8] = "file";
			int count = listfile.GetNum("count", 1);
			if (count > 1)
				Format(file, sizeof(file), "file%d", GetRandomInt(1,count));

			if (StrEqual(file, "file1"))
				listfile.GetString("file", location, sizeof(location), "");
			else
				listfile.GetString(file, location, sizeof(location), "");


			// ###### Random Sound End ######
			listfile.GetString("param", extraparam, sizeof(extraparam), action);
			if (team == -1)
				listfile.GetString("playto", playto, sizeof(playto), "all");
			else
				listfile.GetString("playto", playto, sizeof(playto), "RoundEvent");

			// Used for identifying the names of things
			//PrintToChatAll("Found Subkey, trying to match (%s) with (%s)",extra,extraparam);
			
			if (!IsGameSound(location) && !checkSamplingRate(location))
				return false;
			
			if (StrEqual(extra, extraparam, false))// && checkSamplingRate(location))
			{
				// Next section performs random calculations, all percents in decimal from 1-0
				float random = listfile.GetFloat("prob", 1.0);
				// Added error checking  for the random number
				if (random <= 0.0)
				{
					random = 0.01;
					PrintToChatAll("Your random value for (%s) is <= 0, please make it above 0",location);
				}
				else if (random > 1.0)
					random = 1.0;

				float generated = GetRandomFloat(0.0,1.0);
				// Debug line for new action sounds -- FernFerret
				//PrintToChatAll("I found action: %s",action);
				if (generated <= random)
				{
					//### Delay
					float delay = listfile.GetFloat("delay", 0.1);
					if(delay < 0.1)
						delay = 0.1;
					else if (delay > 60.0)
						delay = 60.0;

					DataPack pack;
					CreateDataTimer(delay, runSoundEventTimer, pack, TIMER_FLAG_NO_MAPCHANGE);
					pack.WriteCell(attacker);
					pack.WriteCell(victim);
					pack.WriteCell(team);
					pack.WriteString(playto);
					pack.WriteString(location);
					pack.Reset();
					//PrepareAndEmitSound(clientlist, clientcount, location);
				}
				result = true;
			}
			else
				result = false;
		}
		else
			result = false;
	} while (listfile.GotoNextKey());
	//return false;
	return result;
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Event Sound Timer ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
public Action runSoundEventTimer(Handle timer, DataPack pack)
{
	//char location[PLATFORM_MAX_PATH+1];
	// Send to all clients, will update in future to add To client/To Team/To All
	//int clientlist[MAXPLAYERS+1];
	//int looserlist[MAXPLAYERS+1];
	//int clientcount = 0;
	//int loosercount = 0;
	int attacker = pack.ReadCell();
	int victim = pack.ReadCell();
	int iTeam = pack.ReadCell();
	char playto[PLATFORM_MAX_PATH+1];
	pack.ReadString(playto, sizeof(playto));
	char location[PLATFORM_MAX_PATH+1];
	pack.ReadString(location, sizeof(location));
	//int playersconnected = GetMaxClients();

	if (StrEqual(playto, "attacker", false)) // Send to attacker
	{
		if (IsValidClient(attacker) && checkClientCookies(attacker, CHK_EVENTS) && !g_bPlayedEvent2Client[attacker])
		{
			PrepareAndEmitSoundToClient(attacker, location);
			g_bPlayedEvent2Client[attacker] = true;
			CreateTimer(2.0, reset_PlayedEvent2Client, attacker);
			//PrintToChat(attacker, "Attacker: %s", location);
		}
	}
	else if (StrEqual(playto, "victim", false)) // Send to victim
	{
		//PrintToChat(victim, "Victim: %s", location);
		if (IsValidClient(victim)&& checkClientCookies(victim, CHK_EVENTS))
		{
			PrepareAndEmitSoundToClient(victim, location);
			//PrintToChat(victim, "CL_Victim: %s", location);
		}

	}
	else if (StrEqual(playto, "both", false)) // Send to attacker & victim
	{
		if (IsValidClient(attacker) && checkClientCookies(attacker, CHK_EVENTS) && !g_bPlayedEvent2Client[attacker])
		{
			PrepareAndEmitSoundToClient(attacker, location);
			g_bPlayedEvent2Client[attacker] = true;
			CreateTimer(3.0, reset_PlayedEvent2Client, attacker);
			//PrintToChat(attacker, "Both attacker: %s", location);
		}
		if (IsValidClient(victim)&& checkClientCookies(victim, CHK_EVENTS))
		{
			PrepareAndEmitSoundToClient(victim, location);
			//PrintToChat(victim, "Both victim: %s", location);
		}

	}
	else if (StrEqual(playto, "ateam", false)) // Send to attacker team
	{
		//if (!g_bPlayedEvent2Client[attacker]){
		int aTeam = GetClientTeam(attacker);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GetClientTeam(i) == aTeam && checkClientCookies(i, CHK_EVENTS))
				//clientlist[clientcount++] = i;
				PrepareAndEmitSoundToClient(i, location);
		}
		//PrepareAndEmitSound(clientlist, clientcount, location);
		//g_bPlayedEvent2Client[attacker] = true;
		//CreateTimer(3.0, reset_PlayedEvent2Client, attacker);
		//PrintToChatAll("ATeam: %s", location);
		//}

	} else if (StrEqual(playto, "vteam", false)){ // Send to victim team

		//if (!g_bPlayedEvent2Client[victim]){
		int vTeam = GetClientTeam(victim);
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i) && GetClientTeam(i) == vTeam && checkClientCookies(i, CHK_EVENTS))
				//clientlist[clientcount++] = i;
				PrepareAndEmitSoundToClient(i, location);
		}
		//PrepareAndEmitSound(clientlist, clientcount, location);
		//g_bPlayedEvent2Client[victim] = true;
		//CreateTimer(3.0, reset_PlayedEvent2Client, victim);
		//PrintToChatAll("VTeam: %s", location);
		//}
	} else if (StrEqual(playto, "RoundEvent", false)){ // RoundEvent

		for (int i = 1; i <= MaxClients; i++)
		{
			//if(IsValidClient(i) && GetClientTeam(i) == g_BroadcastAudioTeam && checkClientCookies(i, _, _, true))
			if(IsValidClient(i)) /* && checkClientCookies(i, _, _, true)) */
			{
				if(GetClientTeam(i) == iTeam)
					PrepareAndEmitSoundToClient(i, location);
				/*if(GetClientTeam(i) != g_BroadcastAudioTeam && GetClientTeam(i) != 0)
				  PrepareAndEmitSoundToClient(i, location);*/
			}
		}
		/*PrepareAndEmitSound(clientlist, clientcount, location);
		  g_bPlayedEvent2Client[victim] = true;
		  CreateTimer(3.0, reset_PlayedEvent2Client, victim);
		  PrintToChatAll("VTeam: %s", location); */
	}
	else // Send to all clients
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && checkClientCookies(i, CHK_EVENTS))
				//clientlist[clientcount++] = i;
				PrepareAndEmitSoundToClient(i, location);
		}
		//PrepareAndEmitSound(clientlist, clientcount, location);
	}
	//pack.ReadString(location, sizeof(location));
	//PrepareAndEmitSound(clientlist, clientcount, location);
	
	return Plugin_Stop;
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Join/Exit Sounds ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
public void OnClientPostAdminCheck(int client)
{
	char auth[64];
	if (GetClientAuthId(client, AuthId_Steam3, auth, sizeof(auth)))
	{
		if (IsValidClient(client) && !cvarjoinspawn.BoolValue)
			CheckJoin(client, auth);

		if (g_hSoundCountTrie == null ||
			!g_hSoundCountTrie.GetValue(auth, SndCount[client]))
		{
			SndCount[client] = 0;
		}
	}
	else
		SndCount[client] = 0;
}

//####### Player Spawn #######
public void PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (cvarjoinspawn.BoolValue && cvarjoinexit.BoolValue)
	{
		int userid = event.GetInt("userid");
		if (userid)
		{
			int index = GetClientOfUserId(userid);
			if (index)
			{
				if (!IsFakeClient(index))
				{
					if (firstSpawn[index])
					{
						char auth[64];
						GetClientAuthId(index, AuthId_Steam3, auth, sizeof(auth));
						CheckJoin(index, auth);
						firstSpawn[index] = false;
					}
				}
			}
		}
	}
}

//####### Check Join #######
public void CheckJoin(int client, const char[] auth)
{
	/* if(listfile == null)
		return;*/

	if (cvarspecificjoinexit.BoolValue)
	{
		char filelocation[PLATFORM_MAX_PATH+1];
		listfile.Rewind();
		if (listfile.JumpToKey(auth) && !checkClientCookies(client, CHK_GREETED))
		{
			filelocation[0] = '\0';
			listfile.GetString("join", filelocation, sizeof(filelocation), "");
			if (filelocation[0] != '\0')
			{
				Send_Sound(client,filelocation, "", true, false);
				//SndCount[client] = 0;
				//greeted[client] = true;
				SetClientCookie(client, g_ssgreeted_cookie, "1");
				return;
			}
			else if (Submit_Sound(client, "", true, false))
			{
				//SndCount[client] = 0;
				//greeted[client] = true;
				SetClientCookie(client, g_ssgreeted_cookie, "1");
				return;
			}
		}
	}

	if (cvarjoinexit.BoolValue || cvarjoinspawn.BoolValue)
	{
		listfile.Rewind();
		if (listfile.JumpToKey("JoinSound") && !checkClientCookies(client, CHK_GREETED))
		{
			Submit_Sound(client, "", true, false);
			//SndCount[client] = 0;
			//greeted[client] = true;
			SetClientCookie(client, g_ssgreeted_cookie, "1");
		}
	}
}

//####### Client Connect #######
/*public OnClientConnected(client)
{
	greeted[client] = false;
}*/

//####### Client Disconnect #######
public void OnClientDisconnect(int client)
{
	if (cvarjoinexit.BoolValue && listfile != null)
	{
		//SndCount[client] = 0;
		//LastSound[client] = 0.0;
		firstSpawn[client] = true;
		//greeted[client] = false;

		if (cvarspecificjoinexit.BoolValue)
		{
			char auth[64];
			GetClientAuthId(client, AuthId_Steam3, auth, sizeof(auth));

			char filelocation[PLATFORM_MAX_PATH+1];
			listfile.Rewind();
			if (listfile.JumpToKey(auth))
			{
				filelocation[0] = '\0';
				listfile.GetString("exit", filelocation, sizeof(filelocation), "");
				if (filelocation[0] != '\0')
				{
					Send_Sound(client,filelocation, "", false, true);
					//SndCount[client] = 0;
					return;
				}
				else if (Submit_Sound(client, "", false, true))
				{
					//SndCount[client] = 0;
					return;
				}
			}
		}

		listfile.Rewind();
		if (listfile.JumpToKey("ExitSound"))
		{
			Submit_Sound(client, "", false, true);
			//SndCount[client] = 0;
		}
	}
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (client != 0)
	{
		//SndCount[client] = 0;
		//LastSound[client] = 0.0;
		firstSpawn[client]=true;
		/*if(!cvarjoinspawn.BoolValue)
			CheckJoin(client, auth);
		  */
	}
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Say Command Handling ***				  *
//	------------------------------------------------------------- *
//*****************************************************************
//####### Command Say #######
public Action Command_Say(int client, const char[] command, int argc) {

	if (IsValidClient(client)) {

		// If sounds are not enabled, then skip this whole thing
		if (!cvarsoundenable.BoolValue)
			return Plugin_Continue;

		// player is banned from playing sounds
		if (checkClientCookies(client, CHK_BANNED))
			return Plugin_Continue;
			
		char speech[192];
		char stopFlags[26];
		stopFlags[0] = '\0';
		char confMenuFlags[26];
		confMenuFlags[0] = '\0';
		
		cvarStopFlags.GetString(stopFlags, sizeof(stopFlags));
		cvarMenuSettingsFlags.GetString(confMenuFlags, sizeof(confMenuFlags));

		
		if (GetCmdArgString(speech, sizeof(speech)) < 1)
			return Plugin_Continue;
		
		int startidx = 0;
		
		if (speech[strlen(speech)-1] == '"')
		{
			speech[strlen(speech)-1] = '\0';
			startidx = 1;
		}

		if (strcmp(command, "say2", false) == 0)
		{
			startidx += 4;
		}
		/* if (speech[0] == '"'){
			startidx = 1;
			// Strip the ending quote, if there is one
			int len = strlen(speech);
			if (speech[len-1] == '"'){
				speech[len-1] = '\0';
			}
		} */

		if (strcmp(speech[startidx],"!sounds",false) == 0 || strcmp(speech[startidx],"sounds",false) == 0){

			if (confMenuFlags[0] == '\0' || HasClientFlags(confMenuFlags, client))
				ShowClientPrefMenu(client);

			return Plugin_Handled;

		} else if (strcmp(speech[startidx],"!soundlist",false) == 0 || strcmp(speech[startidx],"soundlist",false) == 0){


			if (cvarshowsoundmenu.IntValue == 1){
				Sound_Menu(client, normal_sounds);


			} else {
				List_Sounds(client);
				//PrintToChat(client,"\x04[Say Sounds]\x01 Check your console for a list of sound triggers");
				PrintToChat(client,"\x04[Say Sounds]\x01%t", "Soundlist");
			}
			return Plugin_Handled;

		} else if (strcmp(speech[startidx],"!soundmenu",false) == 0 || strcmp(speech[startidx],"soundmenu",false) == 0){


			if (cvarshowsoundmenu.IntValue == 1) {
				Sound_Menu(client, normal_sounds);
			}
			return Plugin_Handled;
		} else if (strcmp(speech[startidx],"!adminsounds",false) == 0 || strcmp(speech[startidx],"adminsounds",false) == 0){

			AdminId aid = GetUserAdmin(client);
			if (aid == INVALID_ADMIN_ID || !GetAdminFlag(aid, Admin_Generic, Access_Effective))
				return Plugin_Handled;

			Sound_Menu(client, admin_sounds);
			return Plugin_Handled;

		} else if (strcmp(speech[startidx],"!karaoke",false) == 0 || strcmp(speech[startidx],"karaoke",false) == 0){


			Sound_Menu(client, karaoke_sounds);
			return Plugin_Handled;

		} else if (strcmp(speech[startidx],"!allsounds",false) == 0 || strcmp(speech[startidx],"allsounds",false) == 0){


			Sound_Menu(client, all_sounds);
			return Plugin_Handled;

		} else if (strcmp(speech[startidx],"!stop",false) == 0){

			if (SndPlaying[client][0] && (stopFlags[0] == '\0' || HasClientFlags(stopFlags, client)))
			{
				StopSound(client, SNDCHAN_AUTO,SndPlaying[client]);
				SndPlaying[client] = "";
			}
			return Plugin_Handled;
		}

		// If player has turned sounds off and is restricted from playing sounds, skip
		if (!cvarplayifclsndoff.BoolValue && !checkClientCookies(client, CHK_SAYSOUNDS)) 
			return Plugin_Continue;

		listfile.Rewind();
		listfile.GotoFirstSubKey();
		bool sentence = cvarsentence.BoolValue;
		bool adult;
		bool trigfound;
		char buffer[255];


		do {
			listfile.GetSectionName(buffer, sizeof(buffer));
			adult = view_as<bool>(listfile.GetNum("adult", 0));
			if ((sentence && StrContains(speech[startidx], buffer, false) >= 0) ||
				(strcmp(speech[startidx], buffer, false) == 0)) {

					Submit_Sound(client, buffer);
					trigfound = true;
					break;
			}
		} while (listfile.GotoNextKey());

		if (cvarblocktrigger.BoolValue && trigfound && !StrEqual(LastPlayedSound, buffer, false)) {
			return Plugin_Handled;
		} else if (adult && trigfound) {
			return Plugin_Handled;
		} else if (cvarannounce.BoolValue && trigfound) {	// NO chat
			return Plugin_Handled;
		} else {
			return Plugin_Continue;
		}
	}	
	return Plugin_Continue;
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Play Say Sound ***						  *
//	------------------------------------------------------------- *
//*****************************************************************
//####### Submit Sound #######
bool Submit_Sound(int client, const char[] name, bool joinsound=false, bool exitsound=false)
{
	if (listfile.GetNum("enable", 1))
	{
		char filelocation[PLATFORM_MAX_PATH+1];
		char file[8] = "file";
		int count = listfile.GetNum("count", 1);
		if (count > 1)
			Format(file, sizeof(file), "file%d", GetRandomInt(1, count));

		filelocation[0] = '\0';
		listfile.GetString(file, filelocation, sizeof(filelocation));
		if (filelocation[0] == '\0' && StrEqual(file, "file1"))
			listfile.GetString("file", filelocation, sizeof(filelocation), "");

		if (filelocation[0] != '\0')
		{
			char karaoke[PLATFORM_MAX_PATH+1];
			karaoke[0] = '\0';
			listfile.GetString("karaoke", karaoke, sizeof(karaoke));
			if (karaoke[0] != '\0')
				Load_Karaoke(client, filelocation, name, karaoke);
			else
				Send_Sound(client, filelocation, name, joinsound, exitsound);

			return true;
		}
	}
	return false;
}

//####### Send Sound #######
void Send_Sound(int client, const char[] filelocation, const char[] name, bool joinsound=false, bool exitsound=false)
{
	int tmp_joinsound;

	int adminonly = listfile.GetNum("admin", 0);
	int adultonly = listfile.GetNum("adult", 0);
	int singleonly = listfile.GetNum("single", 0);

	char txtmsg[256];
	txtmsg[0] = '\0';

	if (joinsound)
		listfile.GetString("text", txtmsg, sizeof(txtmsg));
	if (exitsound)
		listfile.GetString("etext", txtmsg, sizeof(txtmsg));
	if (!joinsound && !exitsound)
		listfile.GetString("text", txtmsg, sizeof(txtmsg));

	int actiononly = listfile.GetNum("actiononly", 0);
	
	char accflags[26];
	accflags[0] = '\0';
	
	listfile.GetString("flags", accflags, sizeof(accflags));

	if (joinsound || exitsound)
		tmp_joinsound = 1;
	else
		tmp_joinsound = 0;

	//####### DURATION #######
	// Get the handle to the soundfile
	
	int timebuf;
	int samplerate;
	
	if (!IsGameSound(filelocation)) {
		Handle h_Soundfile = INVALID_HANDLE;
		h_Soundfile = OpenSoundFile(filelocation, true);

		if (h_Soundfile != INVALID_HANDLE)
		{
			// get the sound length
			timebuf = GetSoundLength(h_Soundfile);
			// get the sample rate
			samplerate = GetSoundSamplingRate(h_Soundfile);
			// close the handle
			CloseHandle(h_Soundfile);
		}
		else
			LogError("<Send_Sound> INVALID_HANDLE for file \"%s\" ", filelocation);

		// Check the sample rate and leave a message if it's above 44.1 kHz;
		if (samplerate > 44100)
		{
			LogError("Invalid sample rate (\%d Hz) for file \"%s\", sample rate should not be above 44100 Hz", samplerate, filelocation);
			PrintToChat(client, "\x04[Say Sounds] \x01Invalid sample rate (\x04%d Hz\x01) for file \x04%s\x01, sample rate should not be above \x0444100 Hz", samplerate, filelocation);
			return;
		}
	}

	float duration = float(timebuf);

	float defVol = cvarvolume.FloatValue;
	float volume = listfile.GetFloat("volume", defVol);
	if (volume == 0.0 || volume == 1.0)
		volume = defVol; // do this check because of possibly "stupid" values in cfg file

	// ### Delay ###
	float delay = listfile.GetFloat("delay", 0.1);
	if(delay < 0.1)
		delay = 0.1;
	else if (delay > 60.0)
		delay = 60.0;

	DataPack pack;
	CreateDataTimer(delay, Play_Sound_Timer, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(client);
	pack.WriteCell(adminonly);
	pack.WriteCell(adultonly);
	pack.WriteCell(singleonly);
	pack.WriteCell(actiononly);
	pack.WriteFloat(duration);
	pack.WriteFloat(volume); // mod by Woody
	pack.WriteString(filelocation);
	pack.WriteString(name);
	pack.WriteCell(tmp_joinsound);
	pack.WriteString(txtmsg);
	pack.WriteString(accflags);
	pack.Reset();
}

	//####### Play Sound #######
void Play_Sound(const char[] filelocation, float volume)
{
	int clientlist[MAXPLAYERS+1];
	int clientcount = 0;
	//int playersconnected = GetMaxClients();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && checkClientCookies(i, CHK_SAYSOUNDS) && HearSound(i))
		{
			clientlist[clientcount++] = i;
			if (cvarinterruptsound.BoolValue)
				StopSound(i, SNDCHAN_AUTO, SndPlaying[i]);
			strcopy(SndPlaying[i], sizeof(SndPlaying[]), filelocation);
		}
	}
	if (clientcount)
		PrepareAndEmitSound(clientlist, clientcount, filelocation, .volume=volume);
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Play Sound Timer ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
public Action Play_Sound_Timer(Handle timer, DataPack pack)
{
	char filelocation[PLATFORM_MAX_PATH+1];
	char name[PLATFORM_MAX_PATH+1];
	char chatBuffer[256];
	char txtmsg[256];
	txtmsg[0] = '\0';
	char accflags[26];
	accflags[0] = '\0';
	int client = pack.ReadCell();
	int adminonly = pack.ReadCell();
	int adultonly = pack.ReadCell();
	int singleonly = pack.ReadCell();
	/* ####FernFerret#### */
	int actiononly = pack.ReadCell();
	/* ################## */
	float duration = pack.ReadFloat();
	float volume = pack.ReadFloat(); // mod by Woody
	pack.ReadString(filelocation, sizeof(filelocation));
	pack.ReadString(name , sizeof(name));
	int joinsound = pack.ReadCell();
	pack.ReadString(txtmsg , sizeof(txtmsg));
	pack.ReadString(accflags , sizeof(accflags));

	/* ####FernFerret#### */
	// Checks for Action Only sounds and messages user telling them why they can't play an action only sound
	if (IsValidClient(client))
	{
		//AdminId aid = GetUserAdmin(client);
		//isadmin = (aid != INVALID_ADMIN_ID) && GetAdminFlag(aid, Admin_Generic, Access_Effective);
		if (actiononly == 1)
		{
			//PrintToChat(client,"[Action Sounds] Sorry, this is an action sound!");
			PrintToChat(client,"\x04[Action Sounds] \x01%t", "ActionSounds");
			return Plugin_Handled;
		}
	}
	/* ################## */

	float waitTime = cvartimebetween.FloatValue;
	float adminTime = cvaradmintime.FloatValue;
	char waitTimeFlags[26];
	waitTimeFlags[0] = '\0';
	cvartimebetweenFlags.GetString(waitTimeFlags, sizeof(waitTimeFlags));

	bool isadmin = false;
	if (IsValidClient(client))
	{

		AdminId aid = GetUserAdmin(client);
		isadmin = (aid != INVALID_ADMIN_ID) && GetAdminFlag(aid, Admin_Generic, Access_Effective);
		if(adminonly && !isadmin)
		{
			//PrintToChat(client,"\x04[Say Sounds]\x01 Sorry, you are not authorized to play this sound!");
			PrintToChat(client,"\x04[Say Sounds] \x01%t", "AdminSounds");
			return Plugin_Handled;
		}
		// Has the client access to this sound
		if (accflags[0] != '\0' && !HasClientFlags(accflags, client))
		{
			PrintToChat(client,"\x04[Say Sounds] \x01%t", "NoAccess");
			return Plugin_Handled;
		}
	}

	float thetime = GetGameTime();
	//if (LastSound[client] >= thetime)
	//	Spam Sounds
	//	Only if the user is not admin or he is admin and the adminTime is not -1 for bypassing
	if (globalLastSound > 0.0)
	{
		if (waitTimeFlags[0] == '\0' || !HasClientFlags(waitTimeFlags, client))
		{
			if ((!isadmin && globalLastSound > thetime) || (isadmin && adminTime >= 0.0 && globalLastSound > thetime))
			{
				if(IsValidClient(client))
				{
					//PrintToChat(client,"\x04[Say Sounds]\x01 Please don't spam the sounds!");
					PrintToChat(client,"\x04[Say Sounds] \x01%t", "SpamSounds");
				}
				return Plugin_Handled;
			}
		}
	}


	//	float waitTime = cvartimebetween.FloatValue;
	if (waitTime > 0.0 && waitTime < duration)
		waitTime = duration;
	//else if (waitTime <= 0.0)
	//duration = waitTime;

	//	float adminTime = cvaradmintime.FloatValue;
	if (adminonly)
	{
		if (globalLastAdminSound >= thetime)
		{
			if(IsValidClient(client))
			{
				//PrintToChat(client,"\x04[Say Sounds]\x01 Please don't spam the admin sounds!");
				PrintToChat(client,"\x04[Say Sounds] \x01%t", "SpamAdminSounds");
			}
			return Plugin_Handled;
		}

		//		adminTime = cvaradmintime.FloatValue;

		if(adminTime > 0.0 && adminTime < duration)
			adminTime = duration;
	}

	if (cvarexcludelastsound.BoolValue && IsValidClient(client) && joinsound != 1 && StrEqual(LastPlayedSound, name, false))
	{
		g_LastSoundCount++;
		//PrintToChat(client, "\x04[Say Sounds]\x01 Sorry, this sound was recently played.");
	//	PrintToChat(client, "\x04[Say Sounds] \x01%t", "RecentlyPlayed");
	//	return Plugin_Handled;
	}
	else
	{
		if (g_LastSoundCount)
			g_LastSoundCount = 0;
	}

	if (g_LastSoundCount >= 3)
	{
		PrintToChat(client, "\x04[Say Sounds] \x01%t", "RecentlyPlayed");
		return Plugin_Handled;
	}

	if (cvarfilterifdead.BoolValue)
	{
		if(IsDeadClient(client))
			hearalive = false;
		else
			hearalive = true;
	}
	
	char soundFlags[26];
	soundFlags[0] = '\0';
	cvarsoundFlags.GetString(soundFlags, sizeof(soundFlags));
	
	int soundLimit;
	
	if (isadmin)
		soundLimit = cvaradminlimit.IntValue;
	else if (soundFlags[0] != '\0' && HasClientFlags(soundFlags, client))
		soundLimit = cvarsoundFlagsLimit.IntValue;
	else
		soundLimit = cvarsoundlimit.IntValue;
	
	//int soundLimit = isadmin ? cvaradminlimit.IntValue : cvarsoundlimit.IntValue;	
	
	char soundLimitFlags[26];
	soundLimitFlags[0] = '\0';
	cvarsoundlimitFlags.GetString(soundLimitFlags, sizeof(soundLimitFlags));
	
	if (soundLimit <= 0 || SndCount[client] < soundLimit)
	{
		if (joinsound == 1)
		{
			//SndCount[client] = 0;
			if (txtmsg[0] != '\0')
				//PrintToChatAll("%s", txtmsg);
				dispatchChatMessage(client, txtmsg, "");
		}
		else
		{
			if (soundLimitFlags[0] == '\0' || !HasClientFlags(soundLimitFlags, client))
				SndCount[client]++;
			//LastSound[client] = thetime + waitTime;
			globalLastSound   = thetime + waitTime;
		}
		if (adminonly)
			globalLastAdminSound = thetime + adminTime;

		if (singleonly && joinsound == 1)
		{
			if(checkClientCookies(client, CHK_SAYSOUNDS) && IsValidClient(client))
			{
				PrepareAndEmitSoundToClient(client, filelocation, .volume=volume);
				strcopy(SndPlaying[client], sizeof(SndPlaying[]), filelocation);
				if (cvarlogging.BoolValue)
				{
					LogToGame("[Say Sounds Log] %s%N  played  %s%s(%s)", isadmin ? "Admin " : "", client,
							adminonly ? "admin sound " : "", name, filelocation);
				}
			}
		}
		else
		{
			Play_Sound(filelocation, volume);
			//LastPlayedSound = name;
			strcopy(LastPlayedSound, sizeof(LastPlayedSound), name);
			if (name[0] && IsValidClient(client))
			{
				if (cvarannounce.BoolValue)
				{
					if(adultonly && cvaradult.BoolValue)
					{
						if (txtmsg[0] != '\0')
						{
							//PrintToChatAll("\x04%N\x01: %s", client , txtmsg);
							Format(chatBuffer, sizeof(chatBuffer), "\x04%N\x01: %s", client , txtmsg);
							dispatchChatMessage(client, chatBuffer, "");
						}
						else
						{
							//PrintToChatAll("%t", "PlayedAdultSound", client);
							dispatchChatMessage(client, "PlayedAdultSound", "", true);
						}
					}
					else
					{
						if (txtmsg[0] != '\0')
						{
							//PrintToChatAll("\x04%N\x01: %s", client , txtmsg);
							Format(chatBuffer, sizeof(chatBuffer), "\x04%N\x01: %s", client , txtmsg);
							dispatchChatMessage(client, chatBuffer, "");
						}
						else
						{
							//PrintToChatAll("%t", "PlayedSound", client, name);
							dispatchChatMessage(client, "PlayedSound", name, true);
						}
					}
				}
				if (cvarlogging.BoolValue)
				{
					LogToGame("[Say Sounds Log] %s%N  played  %s%s(%s)", isadmin ? "Admin " : "", client,
							adminonly ? "admin sound " : "", name, filelocation);
				}
			}
			else if (cvarlogging.BoolValue)
			{
				LogToGame("[Say Sounds Log] played %s", filelocation);
			}
		}
	}

	if(soundLimit > 0 && IsValidClient(client))
	{
		if (SndCount[client] > soundLimit)
		{
			//PrintToChat(client,"\x04[Say Sounds]\x01 Sorry, you have reached your sound quota!");
			PrintToChat(client,"\x04[Say Sounds] \x01%t", "QuotaReched");
		}
		else if (SndCount[client] == soundLimit && joinsound != 1)
		{
			//PrintToChat(client,"\x04[Say Sounds]\x01 You have no sounds left to use!");
			PrintToChat(client,"\x04[Say Sounds] \x01%t", "NoSoundsLeft");
			SndCount[client]++; // Increment so we get the sorry message next time.
		}
		else
		{
			int soundWarn = isadmin ? cvaradminwarn.IntValue : cvarsoundwarn.IntValue;	
			if (soundWarn <= 0 || SndCount[client] >= soundWarn)
			{
				if (joinsound != 1 && (soundLimitFlags[0] == '\0' || !HasClientFlags(soundLimitFlags, client)))
				{
					int numberleft = (soundLimit -  SndCount[client]);
					if (numberleft == 1)
					{
						//PrintToChat(client,"\x04[Say Sounds]\x01 You only have \x04%d \x01sound left to use!",numberleft);
						PrintToChat(client,"\x04[Say Sounds] \x01%t", "SoundLeft",numberleft);
					}
					else
					{
						//PrintToChat(client,"\x04[Say Sounds]\x01 You only have \x04%d \x01sounds left to use!",numberleft);
						PrintToChat(client,"\x04[Say Sounds] \x01%t", "SoundLeftPlural",numberleft);
					}
				}
			}
		}
	}
	return Plugin_Handled;
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Dispatch Chat Messages ***				  *
//	------------------------------------------------------------- *
//*****************************************************************
void dispatchChatMessage(int client, const char[] message, const char[] name, bool translate=false)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && checkClientCookies(i, CHK_CHATMSG))
		{
			if (translate && StrEqual(name, ""))
				PrintToChat(i, "%t", message);
			else if (translate && !StrEqual(name, ""))
				PrintToChat(i, "%t", message, client, name);
			else
				PrintToChat(i, message);
		}
	}
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** KARAOKE Handling ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
	//####### Load Karaoke #######
public void Load_Karaoke(int client, const char[] filelocation, const char[] name, const char[] karaoke)
{
	int adminonly = listfile.GetNum("admin", 1); // Karaoke sounds default to admin only
	bool isadmin = false;
	if (IsValidClient(client))
	{
		AdminId aid = GetUserAdmin(client);
		isadmin = (aid != INVALID_ADMIN_ID) && GetAdminFlag(aid, Admin_Generic, Access_Effective);
		if (adminonly && !isadmin)
		{
			//PrintToChat(client,"\x04[Say Sounds]\x01 Sorry, you are not authorized to play this sound!");
			PrintToChat(client,"\x04[Say Sounds] \x01%t", "AdminSounds");
			return;
		}
	}

	char karaokecfg[PLATFORM_MAX_PATH+1];
	BuildPath(Path_SM,karaokecfg,sizeof(karaokecfg),"configs/%s",karaoke);
	if(!FileExists(karaokecfg))
	{
		LogError("%s not parsed...file doesnt exist!", karaokecfg);
		Send_Sound(client, filelocation, name);
	}
	else
	{
		if (karaokeFile != null) {
			delete karaokeFile;
		}
		karaokeFile = new KeyValues(name);
		karaokeFile.ImportFromFile(karaokecfg);
		karaokeFile.Rewind();
		char title[128];
		title[0] = '\0';
		karaokeFile.GetSectionName(title, sizeof(title));
		if (karaokeFile.GotoFirstSubKey())
		{
			float time = cvarkaraokedelay.FloatValue;
			if (time > 0.0)
				Karaoke_Countdown(client, filelocation, title[0] ? title : name, time, true);
			else
				Karaoke_Start(client, filelocation, name);
		}
		else
		{
			LogError("%s not parsed...No subkeys found!", karaokecfg);
			Send_Sound(client, filelocation, name);
		}
	}
}

//####### Karaoke Countdown #######
void Karaoke_Countdown(int client, const char[] filelocation, const char[] name, float time, bool attention)
{
	float next = 0.0;

	char announcement[128];
	if (attention)
	{
		Show_Message("%s\nKaraoke will begin in %2.0f seconds", name, time);
		if (GetGameType() == tf2)
			strcopy(announcement, sizeof(announcement), TF2_ATTENTION);
		else
			strcopy(announcement, sizeof(announcement), HL2_ATTENTION);

		if (time >= 20.0)
			next = 20.0;
		else if (time >= 10.0)
			next = 10.0;
		else if (time > 5.0)
			next = 5.0;
		else
			next = time - 1.0;
	}
	else
	{
		if (GetGameType() == tf2)
			Format(announcement, sizeof(announcement), "vo/announcer_begins_%dsec.wav", RoundToFloor(time));
		else
		{
			if (time == 10.0)
				strcopy(announcement, sizeof(announcement), HL2_10_SECONDS);
			else if (time == 5.0)
				strcopy(announcement, sizeof(announcement), HL2_5_SECONDS);
			else if (time == 4.0)
				strcopy(announcement, sizeof(announcement), HL2_4_SECONDS);
			else if (time == 3.0)
				strcopy(announcement, sizeof(announcement), HL2_3_SECONDS);
			else if (time == 2.0)
				strcopy(announcement, sizeof(announcement), HL2_2_SECONDS);
			else if (time == 1.0)
				strcopy(announcement, sizeof(announcement), HL2_1_SECOND);
			else
				announcement[0] = '\0';
		}
		switch (time)
		{
			case 20.0: next = 10.0;
			case 10.0: next = 5.0;
			case 5.0:  next = 4.0;
			case 4.0:  next = 3.0;
			case 3.0:  next = 2.0; 
			case 2.0:  next = 1.0; 
			case 1.0:  next = 0.0; 
		}
	}

	if (time > 0.0)
	{
		if (announcement[0] != '\0')
			Play_Sound(announcement, 1.0);

		DataPack pack;
		karaokeTimer = CreateDataTimer(time - next, Karaoke_Countdown_Timer, pack, TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteCell(client);
		pack.WriteFloat(next);
		pack.WriteString(filelocation);
		pack.WriteString(name);
		pack.Reset();
	}
	else
		Karaoke_Start(client, filelocation, name);
}

//####### Karaoke Start #######
void Karaoke_Start(int client, const char[] filelocation, const char[] name)
{
	char text[3][128], timebuf[64];
	timebuf[0] = '\0';
	text[0][0] = '\0';
	text[1][0] = '\0';
	text[2][0] = '\0';

	karaokeFile.GetString("text", text[0], sizeof(text[]));
	karaokeFile.GetString("text1", text[1], sizeof(text[]));
	karaokeFile.GetString("text2", text[2], sizeof(text[]));
	karaokeFile.GetString("time", timebuf, sizeof(timebuf));

	float time = Convert_Time(timebuf);
	if (time == 0.0)
	{
		Karaoke_Message(text);
		if (karaokeFile.GotoNextKey())
		{
			text[0][0] = '\0';
			text[1][0] = '\0';
			text[2][0] = '\0';
			karaokeFile.GetString("text", text[0], sizeof(text[]));
			karaokeFile.GetString("text1", text[1], sizeof(text[]));
			karaokeFile.GetString("text2", text[2], sizeof(text[]));
			karaokeFile.GetString("time", timebuf, sizeof(timebuf));
			time = Convert_Time(timebuf);
		}
		else
		{
			delete karaokeFile;
			karaokeFile = null;
			time = 0.0;
		}
	}

	if (time > 0.0)
	{
		cvaradvertisements = FindConVar("sm_advertisements_enabled");
		if (cvaradvertisements != null)
		{
			advertisements_enabled = cvaradvertisements.BoolValue;
			cvaradvertisements.BoolValue = false;
		}

		DataPack pack;
		karaokeTimer = CreateDataTimer(time, Karaoke_Timer, pack, TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteString(text[0]);
		pack.WriteString(text[1]);
		pack.WriteString(text[2]);
		pack.Reset();
	}
	else
	{
		karaokeTimer = INVALID_HANDLE;
	}

	karaokeStartTime = GetEngineTime();
	Send_Sound(client, filelocation, name, true);
}

//####### Convert Time #######
float Convert_Time(const char[] buffer)
{
	char part[5];
	int pos = SplitString(buffer, ":", part, sizeof(part));
	if (pos == -1)
		return StringToFloat(buffer);
	else
	{
		// Convert from mm:ss to seconds
		return (StringToFloat(part)*60.0) +
				StringToFloat(buffer[pos]);
	}
}

//####### Karaoke Message #######
void Karaoke_Message(const char[][] text)
{
	//int playersconnected = GetMaxClients();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && checkClientCookies(i, CHK_KARAOKE))
		{
			int team = GetClientTeam(i) - 1;
			if (team >= 1 && text[team][0] != '\0')
				PrintCenterText(i, text[team]);
			else
				PrintCenterText(i, text[0]);
		}
	}
}

//####### Show Message #######
void Show_Message(const char[] fmt, any ...)
{
	char text[128];
	VFormat(text, sizeof(text), fmt, 2);

	//int playersconnected = GetMaxClients();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && checkClientCookies(i, CHK_KARAOKE))
			PrintCenterText(i, text);
	}
}

//####### Timer Karaoke Countdown #######
public Action Karaoke_Countdown_Timer(Handle timer, DataPack pack)
{
	char filelocation[PLATFORM_MAX_PATH+1];
	char name[PLATFORM_MAX_PATH+1];
	int client = pack.ReadCell();
	float time = pack.ReadFloat();
	pack.ReadString(filelocation , sizeof(filelocation));
	pack.ReadString(name , sizeof(name));
	Karaoke_Countdown(client, filelocation, name, time, false);
	
	return Plugin_Stop;
}

//####### Timer Karaoke #######
public Action Karaoke_Timer(Handle timer, DataPack pack)
{
	char text[3][128], timebuf[64];
	timebuf[0] = '\0';
	text[0][0] = '\0';
	text[1][0] = '\0';
	text[2][0] = '\0';

	pack.ReadString(text[0], sizeof(text[]));
	pack.ReadString(text[1], sizeof(text[]));
	pack.ReadString(text[2], sizeof(text[]));
	Karaoke_Message(text);

	if (karaokeFile != null)
	{
		if (karaokeFile.GotoNextKey())
		{
			text[0][0] = '\0';
			text[1][0] = '\0';
			text[2][0] = '\0';
			karaokeFile.GetString("text", text[0], sizeof(text[]));
			karaokeFile.GetString("text1", text[1], sizeof(text[]));
			karaokeFile.GetString("text2", text[2], sizeof(text[]));
			karaokeFile.GetString("time", timebuf, sizeof(timebuf));
			float time = Convert_Time(timebuf);
			float current_time = GetEngineTime() - karaokeStartTime;

			DataPack next_pack;
			karaokeTimer = CreateDataTimer(time - current_time, Karaoke_Timer, next_pack, TIMER_FLAG_NO_MAPCHANGE);
			next_pack.WriteString(text[0]);
			next_pack.WriteString(text[1]);
			next_pack.WriteString(text[2]);
			next_pack.Reset();
		}
		else
		{
			delete karaokeFile;
			karaokeFile = null;
			karaokeTimer = INVALID_HANDLE;
			karaokeStartTime = 0.0;

			if (cvaradvertisements != null)
			{
				cvaradvertisements.BoolValue = advertisements_enabled;
				delete cvaradvertisements;
				cvaradvertisements = null;
			}
		}
	}
	else
	{
		karaokeTimer = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Command Handling ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
//####### Command Sound Reset #######
public Action Command_Sound_Reset(int client, int args)
{
	if (args < 1)
	{
		//ReplyToCommand(client, "[Say Sounds] Usage: sm_sound_reset <user | all> : Resets sound quota for user, or everyone if all");
		ReplyToCommand(client, "\x04[Say Sounds] \x01%t", "QuotaResetUsage");
		return Plugin_Handled;
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));	

	if (strcmp(arg,"all",false) == 0 )
	{
		for (int i = 1; i <= MAXPLAYERS; i++)
			SndCount[i] = 0;

		if(client !=0)
		{
			//ReplyToCommand(client, "[Say Sounds] Quota has been reset for all players");
			ReplyToCommand(client, "\x04[Say Sounds] \x01%t", "QuotaResetAll");
		}
	}
	else
	{
		char name[64];
		bool isml;
		int clients[MAXPLAYERS+1];
		int count = ProcessTargetString(arg,client,clients,MAXPLAYERS+1,COMMAND_FILTER_NO_BOTS,name,sizeof(name),isml);
		if (count > 0)
		{
			for (int x = 0; x < count; x++)
			{
				int player = clients[x];
				if (IsPlayerAlive(player))
				{
					SndCount[player] = 0;
					char clientname[64];
					GetClientName(player,clientname,MAXPLAYERS);
					//ReplyToCommand(client, "[Say Sounds] Quota has been reset for %s", clientname);
					ReplyToCommand(client, "\x04[Say Sounds] \x01%t", "QuotaResetUser", clientname);
				}
			}
		}
		else
			ReplyToTargetError(client, count);
	}
	return Plugin_Handled;
}

//####### Command Sound Ban #######
public Action Command_Sound_Ban(int client, int args)
{
	if (args < 1)
	{
		//ReplyToCommand(client, "[Say Sounds] Usage: sm_sound_ban <user> : Bans a player from using sounds");
		ReplyToCommand(client, "\x04[Say Sounds] \x01%t", "SoundBanUsage");
		return Plugin_Handled;	
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));	

	char name[64];
	bool isml;
	int clients[MAXPLAYERS+1];
	int count = ProcessTargetString(arg,client,clients,MAXPLAYERS+1,COMMAND_FILTER_NO_BOTS,name,sizeof(name),isml);
	if (count > 0)
	{
		for (int x = 0; x < count; x++)
		{
			int player = clients[x];
			if (IsClientConnected(player) && IsClientInGame(player))
			{
				char clientname[64];
				GetClientName(player,clientname,MAXPLAYERS);
				if (checkClientCookies(player, CHK_BANNED))
				{
					//ReplyToCommand(client, "[Say Sounds] %s is already banned!", clientname);
					ReplyToCommand(client, "\x04[Say Sounds] \x01%t", "AlreadyBanned", clientname);
				}
				else
				{
					SetClientCookie(player, g_ssban_cookie, "on");
					//restrict_playing_sounds[player]=1;
					//ReplyToCommand(client,"[Say Sounds] %s has been banned!", clientname);
					ReplyToCommand(client,"\x04[Say Sounds] \x01%t", "PlayerBanned", clientname);
				}
			}
		}
	}
	else
		ReplyToTargetError(client, count);

	return Plugin_Handled;
}

//####### Command Sound Unban #######
public Action Command_Sound_Unban(int client, int args)
{
	if (args < 1)
	{
		//ReplyToCommand(client, "[Say Sounds] Usage: sm_sound_unban <user> <1|0> : Unbans a player from using sounds");
		ReplyToCommand(client, "\x04[Say Sounds] \x01%t", "SoundUnbanUsage");
		return Plugin_Handled;	
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));	

	char name[64];
	bool isml;
	int clients[MAXPLAYERS+1];
	int count = ProcessTargetString(arg,client,clients,MAXPLAYERS+1,COMMAND_FILTER_NO_BOTS,name,sizeof(name),isml);
	if (count > 0)
	{
		for (int x = 0;x < count; x++)
		{
			int player = clients[x];
			if (IsClientConnected(player) && IsClientInGame(player))
			{
				char clientname[64];
				GetClientName(player, clientname, MAXPLAYERS);
				if (!checkClientCookies(player, CHK_BANNED))
				{
					//ReplyToCommand(client,"[Say Sounds] %s is not banned!", clientname);
					ReplyToCommand(client,"\x04[Say Sounds] \x01%t", "NotBanned", clientname);
				}
				else
				{
					SetClientCookie(player, g_ssban_cookie, "off");
					//restrict_playing_sounds[player]=0;
					//ReplyToCommand(client,"[Say Sounds] %s has been unbanned!", clientname);
					ReplyToCommand(client,"\x04[Say Sounds] \x01%t", "PlayerUnbanned", clientname);
				}
			}
		}
	}
	else
		ReplyToTargetError(client, count);

	return Plugin_Handled;
}

//####### Command Sound List #######
public Action Command_Sound_List(int client, int args)
{
	List_Sounds(client);
	return Plugin_Handled;
}

//####### List Sounds #######
void List_Sounds(int client)
{
	listfile.Rewind();
	if (listfile.JumpToKey("ExitSound", false))
		listfile.GotoNextKey(true);
	else
		listfile.GotoFirstSubKey();

	char buffer[PLATFORM_MAX_PATH+1];
	do
	{
		listfile.GetSectionName(buffer, sizeof(buffer));
		PrintToConsole(client, buffer);
	} while (listfile.GotoNextKey());
}

public Action Command_Sound_Menu(int client, int args)
{
	//if (cvarshowsoundmenu.IntValue == 1)
	if (!cvarshowsoundmenu.IntValue)
	{
		AdminId aid = GetUserAdmin(client);
		if (aid == INVALID_ADMIN_ID || !GetAdminFlag(aid, Admin_Generic, Access_Effective))
			return Plugin_Handled;
		Sound_Menu(client, normal_sounds);
	}
	return Plugin_Handled;
}

public Action Command_Admin_Sounds(int client, int args)
{
	Sound_Menu(client, admin_sounds);
	return Plugin_Handled;
}

public Action Command_Karaoke(int client, int args)
{
	Sound_Menu(client, karaoke_sounds);
	return Plugin_Handled;
}

public Action Command_All_Sounds(int client, int args)
{
	Sound_Menu(client, all_sounds);
	return Plugin_Handled;
}

//*****************************************************************
//	------------------------------------------------------------- *
//					*** Clear SoundCount Trie ***				  *
//	------------------------------------------------------------- *
//*****************************************************************
void ClearSoundCountTrie()
{
	// if there are no limits, there is no need to save counts
	if (cvarTrackDisconnects.BoolValue &&
		(cvarsoundlimit.IntValue > 0 ||
		 cvaradminlimit.IntValue > 0))
	{
		if (g_hSoundCountTrie == null)
			g_hSoundCountTrie = new StringMap();
		else
			g_hSoundCountTrie.Clear();
	}
	else if (g_hSoundCountTrie != null)
	{
		delete g_hSoundCountTrie;
		g_hSoundCountTrie = null;
	}
}
