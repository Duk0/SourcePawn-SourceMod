/*
 * Custom Votes
 * Written by chundo (chundo@mefightclub.com)
 *
 * Allows new votes to be created from configuration files.  Other plugins
 * can drop config files in configs/customvotes/ to automatically have their
 * votes created.
 *
 * Licensed under the GPL version 2 or above
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "0.6.9"
#define INVALID_VOTE -1
#define MAX_VOTES 64

enum CVoteType {
	CVoteType_Confirm,
	CVoteType_List,
	CVoteType_OnOff,
	CVoteType_Chat
}

enum CVoteApprove {
	CVoteApprove_None,
	CVoteApprove_Sender,
	CVoteApprove_Admin
}

enum CVoteParamType {
	CVoteParamType_MapCycle,
	CVoteParamType_MapList,
	CVoteParamType_Player,
	CVoteParamType_GroupPlayer,
	CVoteParamType_Group,
	CVoteParamType_OnOff,
	CVoteParamType_YesNo,
	CVoteParamType_List
}

enum struct CVote {
	char name[32];
	char title[128];
	char admin[32];
	char trigger[32];
	char triggernotice[128];
	int triggercount;
	int triggerpercent;
	CVoteApprove approve;
	int triggerexpires;
	int percent;
	int abspercent;
	int votes;
	int delay;
	int triggerdelay;
	int mapdelay;
	char target[32];
	char execute[128];
	CVoteType type;
	int options;
	DataPack optiondata;
	int numparams;
	CVoteParamType paramtypes[10];
	DataPack paramdata[10];
	int paramoptions[10];
}

enum struct CVoteStatus {
	int voteindex;
	DataPack params;
	DataPack paramdata; // Store player names in case of disconnect
	int paramct;
	int clientvotes[MAXPLAYERS+1];
	int clienttriggers[MAXPLAYERS+1];
	int clientnostatus[MAXPLAYERS+1];
	int clienttimestamps[MAXPLAYERS+1];
	int targets[MAXPLAYERS+1];
	int targetct;
	int sender;
	char name[32];
}

enum struct CVoteTempParams {
	char name[32];
	bool triggered;
	DataPack params;
	int paramct;
}

// Hopefully this stock menu stuff will be in core soon
enum StockMenuType {
	StockMenuType_MapCycle,
	StockMenuType_MapList,
	StockMenuType_Player,
	StockMenuType_GroupPlayer,
	StockMenuType_Group,
	StockMenuType_OnOff,
	StockMenuType_YesNo
}

// CVars
ConVar sm_cvote_showstatus;
ConVar sm_cvote_resetonmapchange;
ConVar sm_cvote_triggers;
ConVar sm_cvote_mapdelay;
ConVar sm_cvote_triggerdelay;
ConVar sm_cvote_executedelay;
ConVar sm_cvote_minpercent;
ConVar sm_cvote_minvotes;
ConVar sm_cvote_adminonly;
ConVar sm_vote_delay;

// Vote lookup tables
ArrayList g_voteArray = null;
char g_voteNames[MAX_VOTES][32];
char g_voteTriggers[MAX_VOTES][32];

// Vote status tables
ArrayList g_voteStatus = null;
CVoteStatus g_activeVoteStatus;
int g_activeVoteStatusIdx = -1;
int g_confirmMenus = 0;

// Votes currently being built via menus
CVoteTempParams g_clientTempParams[MAXPLAYERS+1];

// Menu pointers
TopMenu g_topMenu;
TopMenu g_adminMenuHandle;

// Timestamps for delay calculations
int g_voteLastInitiated[MAX_VOTES];
int g_lastVoteTime = 0;
int g_mapStartTime = 0;

// Config parsing state
int g_configLevel = 0;
char g_configSection[32];
int g_configParam = -1;
int g_configParamsUsed = 0;
CVote g_configVote;

bool g_chat_triggers = true;


public Plugin myinfo = {
	name = "Custom Votes",
	author = "chundo, Duko",
	description = "Allow addition of custom votes with configuration files",
	version = PLUGIN_VERSION,
	url = "http://www.mefightclub.com"
};

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	LoadTranslations("customvotes.phrases");

	CreateConVar("sm_cvote_version", PLUGIN_VERSION, "Custom votes version", FCVAR_SPONLY|FCVAR_NOTIFY);
	sm_cvote_showstatus = CreateConVar("sm_cvote_showstatus", "1", "Show vote status. 0 = none, 1 = in side panel anonymously, 2 = in chat anonymously, 3 = in chat with player names.");
	sm_cvote_resetonmapchange = CreateConVar("sm_cvote_resetonmapchange", "1", "Reset all votes on map change.");
	sm_cvote_triggers = CreateConVar("sm_cvote_triggers", "1", "Allow in-chat vote triggers.");
	sm_cvote_triggerdelay = CreateConVar("sm_cvote_triggerdelay", "60", "Default delay between non-admin initiated votes.");
	sm_cvote_executedelay = CreateConVar("sm_cvote_executedelay", "3.0", "Default delay before executing a command after a successful vote.");
	sm_cvote_mapdelay = CreateConVar("sm_cvote_mapdelay", "0", "Default delay after maps starts before players can initiate votes.");
	sm_cvote_minpercent = CreateConVar("sm_cvote_minpercent", "60", "Minimum percentage of votes the winner must receive to be considered the winner.");
	sm_cvote_minvotes = CreateConVar("sm_cvote_minvotes", "0", "Minimum number of votes the winner must receive to be considered the winner.");
	sm_cvote_adminonly = CreateConVar("sm_cvote_adminonly", "0", "Only admins can initiate votes (except chat votes.)");
	sm_vote_delay = FindConVar("sm_vote_delay");

	RegAdminCmd("sm_cvote", Command_CustomVote, ADMFLAG_GENERIC, "Initiate a vote, or list available votes", "customvotes");
	RegAdminCmd("sm_cvote_reload", Command_ReloadConfig, ADMFLAG_GENERIC, "Reload vote configuration", "customvotes");
	RegConsoleCmd("sm_votemenu", Command_VoteMenu, "List available votes");

	RegAdminCmd("sm_ban_auto", Command_BanAuto, ADMFLAG_GENERIC, "Ban a user by Steam ID or IP (auto-detected)", "customvotes");

	// Loaded late, OnAdminMenuReady already fired
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		g_topMenu = topmenu;
	
	for (int i = 0; i < sizeof(g_voteLastInitiated); ++i)
		g_voteLastInitiated[i] = 0;
	g_voteStatus = new ArrayList(sizeof(g_activeVoteStatus));

	//HookEvent("player_say", Event_PlayerChat, EventHookMode_Post);
//	RegConsoleCmd("say", Command_PlayerChat);
//	RegConsoleCmd("say_team", Command_PlayerChat);
	AddCommandListener(Command_PlayerChat, "say");
	AddCommandListener(Command_PlayerChat, "say_team");

	sm_cvote_triggers.AddChangeHook(Change_Triggers);

	AutoExecConfig(true);
}

public void OnAdminMenuReady(Handle topmenu)
{
	// Called twice
	if (view_as<TopMenu>(topmenu) == g_topMenu)
		return;

	// Save handle to prevent duplicate calls
	g_topMenu = view_as<TopMenu>(topmenu);

	// Add votes to admin menu
	if (g_voteArray != null) {
		CVote cvote;
		for (int i = 0; i < g_voteArray.Length; ++i) {
			g_voteArray.GetArray(i, cvote);
			AddVoteToMenu(view_as<TopMenu>(topmenu), cvote);
		}
	}
}

public void AddVoteToMenu(TopMenu topmenu, CVote cvote)
{
	if (cvote.type == CVoteType_Chat)
		return;

	// Add votes to admin menu
	TopMenuObject voting_commands = FindTopMenuCategory(topmenu, ADMINMENU_VOTINGCOMMANDS);
	if (voting_commands != INVALID_TOPMENUOBJECT) {
		char menu_id[38];
		Format(menu_id, sizeof(menu_id), "cvote_%s", cvote.name);
		AddToTopMenu(topmenu,
			menu_id,
			TopMenuObject_Item,
			CVote_AdminMenuHandler,
			voting_commands,
			"sm_cvote",
			ADMFLAG_VOTE,
			cvote.name);
	}
}

public void Change_Triggers(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
		g_chat_triggers = false;
		//UnhookEvent("player_say", Event_PlayerChat, EventHookMode_Post);
	else
		g_chat_triggers = true;
		//HookEvent("player_say", Event_PlayerChat, EventHookMode_Post);
}

public void OnClientDisconnect(int client)
{
	CVoteStatus tstatus;
	CVote cvote;
	for (int i = 0; i < g_voteStatus.Length; ++i) {
		g_voteStatus.GetArray(i, tstatus);
		g_voteArray.GetArray(tstatus.voteindex, cvote);
		if (tstatus.clienttriggers[client] > -1) {
			tstatus.clienttriggers[client] = -1;
			g_voteStatus.SetArray(i, tstatus);
		}
	}
	RemoveExpiredStatuses();
}

public void OnMapStart()
{
	g_mapStartTime = GetTime();
	// Clean up memory
	ClearCurrentVote();
	for (int i = 1; i <= MaxClients; ++i)
		ClearTempParams(i);
	if (sm_cvote_resetonmapchange.BoolValue)
		g_voteStatus.Clear();
	else
		RemoveExpiredStatuses();
	if (!LoadConfigFiles())
		LogError("%T", "Plugin configuration error", LANG_SERVER);
}

public void CVote_AdminMenuHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	char votename[32];
	topmenu.GetInfoString(object_id, votename, sizeof(votename));
	int idx = InArray(votename, g_voteNames, sizeof(g_voteNames));
	if (idx > -1) {
		CVote selvote;
		g_voteArray.GetArray(idx, selvote);
		if (action == TopMenuAction_DisplayOption) {
			char votetitle[128];
			char voteparams[10][32];
			CVoteParamType voteparamtypes[10];
			int voteparamct = 0;
			voteparamct = selvote.numparams;
			for (int k = 0; k < selvote.numparams; ++k) {
				voteparamtypes[k] = CVoteParamType_List;
				switch (selvote.paramtypes[k]) {
					case CVoteParamType_MapCycle: {
						strcopy(voteparams[k], 32, "<map>");
					}
					case CVoteParamType_Player: {
						strcopy(voteparams[k], 32, "<player>");
					}
					case CVoteParamType_GroupPlayer: {
						strcopy(voteparams[k], 32, "<group/player>");
					}
					case CVoteParamType_Group: {
						strcopy(voteparams[k], 32, "<group>");
					}
					case CVoteParamType_OnOff: {
						strcopy(voteparams[k], 32, "<on/off>");
					}
					case CVoteParamType_YesNo: {
						strcopy(voteparams[k], 32, "<yes/no>");
					}
					case CVoteParamType_List: {
						strcopy(voteparams[k], 32, "<value>");
					}
				}
			}
			ProcessTemplateString(votetitle, sizeof(votetitle), selvote.title);
			ReplaceParams(votetitle, sizeof(votetitle), voteparams, voteparamct, voteparamtypes, true);
			strcopy(buffer, maxlength, votetitle);
		} else if (action == TopMenuAction_SelectOption) {
			char vparams[1][1];
			g_adminMenuHandle = topmenu;
			CVote_DoVote(param, votename, vparams, 0);
		} else if (action == TopMenuAction_DrawOption) {
			char errormsg[128];
			if (CanInitiateVote(param, selvote.admin))
				buffer[0] = !IsVoteAllowed(param, idx, false, errormsg, sizeof(errormsg)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
			else
				buffer[0] = ITEMDRAW_IGNORE;
		}
	}
}

/***************************
 ** CONFIGURATION PARSING **
 ***************************/

bool LoadConfigFiles()
{
	if (g_voteArray == null)
		g_voteArray = new ArrayList(sizeof(g_configVote));

	char vd[PLATFORM_MAX_PATH];
	bool success = true;

	BuildPath(Path_SM, vd, sizeof(vd), "configs/customvotes");
	DirectoryListing vdh = OpenDirectory(vd);

	// Search Path_SM/configs/customvotes for CFG files
	if (vdh != null) {
		char vf[PLATFORM_MAX_PATH];
		FileType vft;
		while (vdh.GetNext(vf, sizeof(vf), vft)) {
			if (vft == FileType_File && strlen(vf) > 4 && strcmp(".cfg", vf[strlen(vf)-4]) == 0) {
				char vfp[PLATFORM_MAX_PATH];
				strcopy(vfp, sizeof(vfp), vd);
				StrCat(vfp, sizeof(vfp), "/");
				StrCat(vfp, sizeof(vfp), vf);
				success = success && ParseConfigFile(vfp);
			}
		}
		delete vdh;
	} else {
		LogError("%T (%s).", "Directory does not exist", LANG_SERVER, vd);
	}
	return success;
}

bool ParseConfigFile(const char[] file)
{
	SMCParser parser = new SMCParser();

	parser.OnEnterSection = Config_NewSection;
	parser.OnKeyValue = Config_KeyValue;
	parser.OnLeaveSection = Config_EndSection;
	parser.OnEnd = Config_End;

	int line = 0;
	int col = 0;
	char error[128];
	SMCError result = parser.ParseFile(file, line, col);

	if (result != SMCError_Okay) {
		parser.GetErrorString(result, error, sizeof(error));
		LogError("%s on line %d, col %d of %s", error, line, col, file);
	}
	
	delete parser;

	return (result == SMCError_Okay);
}

public SMCResult Config_NewSection(SMCParser parser, const char[] section, bool quotes)
{
	g_configLevel++;
	switch (g_configLevel) {
		case 2: {
			g_configParamsUsed = 0;
			ResetVoteCache(g_configVote);
			strcopy(g_configVote.name, 32, section);
		}
		case 3: {
			strcopy(g_configSection, sizeof(g_configSection), section);
			if (strcmp(g_configSection, "options", false) == 0)
				g_configVote.optiondata = new DataPack();
		}
		case 4: {
			int pidx = StringToInt(section) - 1;
			if (pidx < 10) {
				g_configParam = pidx;
				g_configVote.paramtypes[pidx] = CVoteParamType_List;
				g_configVote.paramdata[pidx] = new DataPack();
				g_configVote.numparams = Max(g_configVote.numparams, pidx + 1);
			}
		}
	}
	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(SMCParser parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	switch (g_configLevel) {
		case 2: {
			if(strcmp(key, "title", false) == 0) {
				strcopy(g_configVote.title, sizeof(g_configVote.title), value);
				g_configParamsUsed = Max(g_configParamsUsed, GetParamCount(g_configVote.title));
			} else if(strcmp(key, "admin", false) == 0)
				strcopy(g_configVote.admin, sizeof(g_configVote.admin), value);
			else if(strcmp(key, "trigger", false) == 0)
				// Backwards compatibility with 0.4
				strcopy(g_configVote.trigger, sizeof(g_configVote.trigger), value);
			else if(strcmp(key, "target", false) == 0)
				strcopy(g_configVote.target, sizeof(g_configVote.target), value);
			else if(strcmp(key, "execute", false) == 0)
				strcopy(g_configVote.execute, sizeof(g_configVote.execute), value);
			else if(strcmp(key, "command", false) == 0)
				strcopy(g_configVote.execute, sizeof(g_configVote.execute), value);
			else if(strcmp(key, "cmd", false) == 0)
				strcopy(g_configVote.execute, sizeof(g_configVote.execute), value);
			else if(strcmp(key, "delay", false) == 0)
				g_configVote.delay = StringToInt(value);
			else if(strcmp(key, "playerdelay", false) == 0)
				// Backwards compatibility with 0.4
				g_configVote.triggerdelay = StringToInt(value);
			else if(strcmp(key, "mapdelay", false) == 0)
				g_configVote.mapdelay = StringToInt(value);
			else if(strcmp(key, "percent", false) == 0)
				g_configVote.percent = StringToInt(value);
			else if(strcmp(key, "abspercent", false) == 0)
				g_configVote.abspercent = StringToInt(value);
			else if(strcmp(key, "votes", false) == 0)
				g_configVote.votes = StringToInt(value);
			else if(strcmp(key, "approve", false) == 0) {
				if (strcmp(value, "sender") == 0) {
					g_configVote.approve = CVoteApprove_Sender;
				} else if (strcmp(value, "admins") == 0) {
					g_configVote.approve = CVoteApprove_Admin;
				} else {
					g_configVote.approve = CVoteApprove_None;
				}
			} else if(strcmp(key, "type", false) == 0) {
				if (strcmp(value, "confirm") == 0) {
					g_configVote.type = CVoteType_Confirm;
				} else if (strcmp(value, "chat") == 0) {
					g_configVote.type = CVoteType_Chat;
				} else if (strcmp(value, "onoff") == 0) {
					g_configVote.type = CVoteType_OnOff;
				} else {
					// Default to list
					g_configVote.type = CVoteType_List;
				}
			}
		}
		case 3: {
			if (strcmp(g_configSection, "options", false) == 0) {
				g_configVote.optiondata.WriteString(key);
				g_configParamsUsed = Max(g_configParamsUsed, GetParamCount(key));
				g_configVote.optiondata.WriteString(value);
				g_configParamsUsed = Max(g_configParamsUsed, GetParamCount(value));
				g_configVote.options++;
			} else if (strcmp(g_configSection, "params", false) == 0) {
				int pidx = StringToInt(key) - 1;
				if (pidx < 10) {
					if (strcmp(value, "mapcycle", false) == 0) {
						g_configVote.paramtypes[pidx] = CVoteParamType_MapCycle;
					} else if (strcmp(value, "maplist", false) == 0) {
						g_configVote.paramtypes[pidx] = CVoteParamType_MapList;
					} else if (strcmp(value, "player", false) == 0) {
						g_configVote.paramtypes[pidx] = CVoteParamType_Player;
					} else if (strcmp(value, "groupplayer", false) == 0) {
						g_configVote.paramtypes[pidx] = CVoteParamType_GroupPlayer;
					} else if (strcmp(value, "group", false) == 0) {
						g_configVote.paramtypes[pidx] = CVoteParamType_Group;
					} else if (strcmp(value, "onoff", false) == 0) {
						g_configVote.paramtypes[pidx] = CVoteParamType_OnOff;
					} else if (strcmp(value, "yesno", false) == 0) {
						g_configVote.paramtypes[pidx] = CVoteParamType_YesNo;
					}
					g_configVote.numparams = Max(g_configVote.numparams, pidx + 1);
				}
			} else if (strcmp(g_configSection, "trigger", false) == 0) {
				if(strcmp(key, "command", false) == 0)
					strcopy(g_configVote.trigger, sizeof(g_configVote.trigger), value);
				else if(strcmp(key, "notice", false) == 0)
					strcopy(g_configVote.triggernotice, sizeof(g_configVote.triggernotice), value);
				else if(strcmp(key, "percent", false) == 0)
					g_configVote.triggerpercent = StringToInt(value);
				else if(strcmp(key, "count", false) == 0)
					g_configVote.triggercount = StringToInt(value);
				else if(strcmp(key, "delay", false) == 0)
					g_configVote.triggerdelay = StringToInt(value);
				else if(strcmp(key, "expires", false) == 0)
					g_configVote.triggerexpires = StringToInt(value);
			}
		}
		case 4: {
			if (g_configParam > -1 && g_configVote.paramdata[g_configParam] != null) {
				g_configVote.paramdata[g_configParam].WriteString(key);
				g_configVote.paramdata[g_configParam].WriteString(value);
				g_configVote.paramoptions[g_configParam]++;
			}
		}
	}
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(SMCParser parser)
{
	switch (g_configLevel) {
		case 2: {
			if (g_configParamsUsed != g_configVote.numparams)
				LogMessage("Warning: vote definition for \"%s\" defines %d parameters but only uses %d.", g_configVote.name, g_configVote.numparams, g_configParamsUsed);
				
			int tidx = InArray(g_configVote.name, g_voteNames, sizeof(g_voteNames));
			if (tidx == -1) {
				int idx = g_voteArray.PushArray(g_configVote);
				if (idx < MAX_VOTES) {
					strcopy(g_voteNames[idx], 32, g_configVote.name);
					strcopy(g_voteTriggers[idx], 32, g_configVote.trigger);
					if (g_topMenu != null)
						AddVoteToMenu(g_topMenu, g_configVote);
				} else {
					LogError("Reached maximum vote limit. Please increase MAX_VOTES and recompile.");
				}
			}
		}
		case 3: {
			if (strcmp(g_configSection, "options", false) == 0)
				g_configVote.optiondata.Reset();
		}
		case 4: {
			if (g_configParam > -1) {
				g_configVote.paramdata[g_configParam].Reset();
				g_configParam = -1;
			}
		}
	}
	g_configLevel--;
	return SMCParse_Continue;
}

public void Config_End(SMCParser parser, bool halted, bool failed)
{
	if (failed)
		SetFailState("%T", "Plugin configuration error", LANG_SERVER);
}

/************************
 ** COMMANDS AND HOOKS **
 ************************/

public Action Command_VoteMenu(int client, int args) {
	if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
		PrintVotesToConsole(client);
	else
		PrintVotesToMenu(client);
	return Plugin_Handled;
}

public Action Command_ReloadConfig(int client, int args)
{
	int exct = g_voteArray.Length;
	g_voteArray.Clear();
	for (int i = 0; i < MAX_VOTES; ++i)
	{
		g_voteNames[i][0] = '\0';
		g_voteTriggers[i][0] = '\0';
	}

	if (!LoadConfigFiles())
		LogError("%T", "Plugin configuration error", LANG_SERVER);
	else {
		int newvotect = g_voteArray.Length - exct;
		if (newvotect > 0)
			ReplyToCommand(client, "[SM] Loaded %d new votes", newvotect);
		else if (newvotect < 0)
			ReplyToCommand(client, "[SM] Removed %d votes. Currently loaded %d votes", newvotect * -1, newvotect + exct);
		else
			ReplyToCommand(client, "[SM] %d votes found", newvotect + exct);
	}

	return Plugin_Handled;
}

public Action Command_CustomVote(int client, int args)
{
	if (args == 0)
		return Command_VoteMenu(client, args);

	if (GetRealClientCount(true) < 1)
	{
		ReplyToCommand(client, "You cannot start a vote with no players in game");
		return Plugin_Handled;
	}

	char votename[32];
	GetCmdArg(1, votename, sizeof(votename));

	char vparams[10][64];
	for (int i = 2; i <= args; ++i)
		GetCmdArg(i, vparams[i-2], 64);

	CVote_DoVote(client, votename, vparams, args-1);

	return Plugin_Handled;
}

public Action Command_BanAuto(int client, int args)
{
	if (args == 0)
		ReplyToCommand(client, "[SM] Usage: sm_ban_auto <steamid|ip> <time> [reason]");

	char banid[32];
	char bantime[8] = "30";
	char reason[8];

	GetCmdArg(1, banid, sizeof(banid));
	if (args > 1)
		GetCmdArg(2, bantime, sizeof(bantime));
	if (args > 2)
		GetCmdArg(3, reason, sizeof(reason));

	int bantimeint = StringToInt(bantime);

	int ididx = 0;
	int btarget = 0;
	bool bansuccess = false;
	int btargets[MAXPLAYERS];
	char btargetdesc[64];
	bool tn_is_ml;

	if (ProcessTargetString(banid, client, btargets, MaxClients, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_MULTI, btargetdesc, sizeof(btargetdesc), tn_is_ml) > 0) {
		btarget = btargets[0];
		bansuccess = BanClient(btarget, bantimeint, BANFLAG_AUTO, reason, "sm_ban_auto");
	} else {
		if (banid[0] == '#')
			ididx++;
		if (strncmp(banid[ididx], "STEAM_0:", 8) == 0) {
			bansuccess = BanIdentity(banid[ididx], bantimeint, BANFLAG_AUTHID, reason, "sm_ban_auto");
		} else {
			// TODO: Check for correct IP format - skipped for now because I don't
			// want to worry about IPv6 compatibility, BanIdentity should just return
			// false if it is an invalid IP.
			bansuccess = BanIdentity(banid[ididx], bantimeint, BANFLAG_IP, reason, "sm_ban_auto");
		}
	}

	if (bansuccess) {
		LogAction(client, btarget, "\"%L\" added ban (minutes \"%d\") (ip \"%s\") (reason \"%s\")",
			client, bantimeint, banid[ididx], reason);
		ReplyToCommand(client, "[SM] %s", "Ban added");
	}
	
	return Plugin_Handled;
}
/*
public Action Event_PlayerChat(Event event, const char[] eventname, bool dontBroadcast)
{
	char saytext[191];
	char votetrigger[32];
	char vparams[10][64];
	int pidx = 0;
	int vidx = 0;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidEntity(client)) {
		event.GetString("text", saytext, sizeof(saytext));
		int idx = BreakString(saytext, votetrigger, sizeof(votetrigger));

		if (strlen(votetrigger) > 0) {
			if ((vidx = InArray(votetrigger, g_voteTriggers, g_voteArray.Length) > -1) {
				if (idx > -1)
					while((idx = BreakString(saytext[idx], vparams[pidx++], 64)) > -1 && pidx <= 10) { }
				SetCmdReplySource(SM_REPLY_TO_CHAT);
				CVote_DoVote(client, g_voteNames[vidx], vparams, pidx, true);
			}
		}
	}
}
*/
//public Action Command_PlayerChat(int client, int args)
public Action Command_PlayerChat(int client, const char[] command, int argc)
{
	if (client != 0 && g_chat_triggers && IsClientInGame(client))
	{
		char saytext[192];
		char votetrigger[32];
		char vparams[10][64];
		int pidx = 0;
		int vidx = 0;
		GetCmdArgString(saytext, sizeof(saytext));
		StripQuotes(saytext);
		int idx = BreakString(saytext, votetrigger, sizeof(votetrigger));

		if (strlen(votetrigger) > 0) 
		{
			if ((vidx = InArray(votetrigger, g_voteTriggers, g_voteArray.Length)) > -1)
			{
				if (idx > -1)
				{
					while (idx < sizeof(saytext) && (idx = BreakString(saytext[idx], vparams[pidx++], 64)) > -1)
					{
						if (pidx >= 9)
							break;
					}
				}

				SetCmdReplySource(SM_REPLY_TO_CHAT);
				CVote_DoVote(client, g_voteNames[vidx], vparams, pidx, true);
			}
		}
	}

	return Plugin_Continue;
}

/**********************
 ** VOTING FUNCTIONS **
 **********************/

void CVote_DoVote(int client, const char[] votename, const char[][] vparams, int vparamct, bool fromtrigger=false)
{
	int voteidx = InArray(votename, g_voteNames, g_voteArray.Length);
	CVote cvote;
	if (voteidx > -1) {
		g_voteArray.GetArray(voteidx, cvote);
	} else {
		if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
			ReplyToCommand(client, "[SM] %t", "See console for output");
		PrintVotesToConsole(client);
		return;
	}

	if (!CanInitiateVote(client, cvote.admin) && !fromtrigger) {
		ReplyToCommand(client, "[SM] %t", "No Access");
		return;
	}

	char errormsg[128];
	if (!IsVoteAllowed(client, voteidx, fromtrigger, errormsg, sizeof(errormsg))) {
		ReplyToCommand(client, "[SM] %s", errormsg);
		return;
	}

	if (vparamct < cvote.numparams) {
		if (client == 0) {
			PrintToServer("[SM] %T", "Vote Requires Parameters", LANG_SERVER, cvote.numparams);
			ClearCurrentVote();
		} else {
			// Reset client temp params
			g_clientTempParams[client].triggered = fromtrigger;
			strcopy(g_clientTempParams[client].name, 128, votename);
			g_clientTempParams[client].paramct = vparamct;
			g_clientTempParams[client].params = new DataPack();
			for (int i = 0; i < vparamct; ++i)
				g_clientTempParams[client].params.WriteString(vparams[i]);
			g_clientTempParams[client].params.Reset();

			Menu parammenu = null;
			switch (cvote.paramtypes[vparamct]) {
				case CVoteParamType_MapCycle: {
					char mapcycle[32];
					Format(mapcycle, sizeof(mapcycle), "sm_cvote %s", votename);
					parammenu = CreateStockMenu(StockMenuType_MapCycle, CVote_AddParamMenuHandler, client, mapcycle);
					if (parammenu.ItemCount == 0)
						ReplyToCommand(client, "[SM] %s", "No maps were found.");
				}
				case CVoteParamType_MapList: {
					parammenu = CreateStockMenu(StockMenuType_MapList, CVote_AddParamMenuHandler, client);
					if (parammenu.ItemCount == 0)
						ReplyToCommand(client, "[SM] %s", "No maps were found.");
				}
				case CVoteParamType_Player: {
					parammenu = CreateStockMenu(StockMenuType_Player, CVote_AddParamMenuHandler, client);
					AddDisconnectedPlayers(parammenu, votename, vparamct);
					if (parammenu.ItemCount == 0)
						ReplyToCommand(client, "[SM] %s", "No players can be targeted.");
				}
				case CVoteParamType_GroupPlayer: {
					parammenu = CreateStockMenu(StockMenuType_GroupPlayer, CVote_AddParamMenuHandler, client);
					AddDisconnectedPlayers(parammenu, votename, vparamct);
					if (parammenu.ItemCount == 0)
						ReplyToCommand(client, "[SM] %s", "No players can be targeted.");
				}
				case CVoteParamType_Group: {
					parammenu = CreateStockMenu(StockMenuType_Group, CVote_AddParamMenuHandler, client);
					if (parammenu.ItemCount == 0)
						ReplyToCommand(client, "[SM] %s", "No players can be targeted.");
				}
				case CVoteParamType_OnOff: {
					parammenu = CreateStockMenu(StockMenuType_OnOff, CVote_AddParamMenuHandler, client);
				}
				case CVoteParamType_YesNo: {
					parammenu = CreateStockMenu(StockMenuType_YesNo, CVote_AddParamMenuHandler, client);
				}
				case CVoteParamType_List: {
					char value[64];
					char desc[128];
					parammenu = new Menu(CVote_AddParamMenuHandler);
					for (int i = 0; i < cvote.paramoptions[vparamct]; ++i) {
						cvote.paramdata[vparamct].ReadString(value, sizeof(value));
						cvote.paramdata[vparamct].ReadString(desc, sizeof(desc));
						parammenu.AddItem(value, desc, ITEMDRAW_DEFAULT);
					}
					cvote.paramdata[vparamct].Reset();
				}
			}
			if (parammenu.ItemCount > 0 && parammenu != null) {
				if (g_adminMenuHandle != null)
					parammenu.ExitBackButton = true;
				parammenu.Display(client, MENU_TIME_FOREVER);
			} else {
				ClearCurrentVote();
			}
		}
		return;
	}

	for (int i = 0; i < vparamct; ++i) {
		switch (cvote.paramtypes[i]) {
			case CVoteParamType_Player: {
				if (!CheckClientTarget(vparams[i], client, true)) {
					ReplyToCommand(client, "[SM] %t", "No matching client");
					CVote_DoVote(client, votename, vparams, i, fromtrigger);
					return;
				}
			}
			case CVoteParamType_GroupPlayer: {
				if (!CheckClientTarget(vparams[i], client, false)) {
					ReplyToCommand(client, "[SM] %t", "No matching client");
					CVote_DoVote(client, votename, vparams, i, fromtrigger);
					return;
				}
			}
			case CVoteParamType_Group: {
				if (!CheckClientTarget(vparams[i], client, false)) {
					ReplyToCommand(client, "[SM] %t", "No matching client");
					CVote_DoVote(client, votename, vparams, i, fromtrigger);
					return;
				}
			}
			case CVoteParamType_MapCycle: {
				if (!IsMapValid(vparams[i])) {
					ReplyToCommand(client, "[SM] %t", "Map was not found", vparams[i]);
					CVote_DoVote(client, votename, vparams, i, fromtrigger);
					return;
				}
			}
			case CVoteParamType_MapList: {
				if (!SynIsMapValid(vparams[i])) {
					ReplyToCommand(client, "[SM] %t", "Map was not found", vparams[i]);
					CVote_DoVote(client, votename, vparams, i, fromtrigger);
					return;
				}
			}
		}
	}

	char votetitle[128];
	ProcessTemplateString(votetitle, sizeof(votetitle), cvote.title);
	ReplaceParams(votetitle, sizeof(votetitle), vparams, vparamct, cvote.paramtypes, true);

	int statusidx = GetStatusIndex(voteidx, client, vparams, vparamct);
	if (statusidx == INVALID_VOTE)
		statusidx = CreateStatus(voteidx, client, vparams, vparamct);
	if (statusidx == INVALID_VOTE)
		return;
	CVoteStatus tstatus;
	g_voteStatus.GetArray(statusidx, tstatus);

	int tcount = cvote.triggercount;
	int tpercent = cvote.triggerpercent;
	if (cvote.type == CVoteType_Chat) {
		tcount = Max(cvote.votes, tcount);
		tpercent = Max(51, Max(cvote.percent, tpercent));

		// Abort vote if vote target string does not include this client
		if (InArrayInt(client, tstatus.targets, tstatus.targetct) == -1) {
			ReplyToCommand(client, "[SM] You are not allowed to vote.");
			return;
		}
	}
	int votect = 0;
	int players = 0;
	tstatus.clienttriggers[client] = 1;
	tstatus.clienttimestamps[client] = GetTime();
	g_voteStatus.SetArray(statusidx, tstatus);
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			players++;
		if (tstatus.clienttriggers[i] > -1)
			votect++;
	}
	tcount = Max(RoundToCeil((float(tpercent) / float(100)) * float(players)), tcount);
	if (fromtrigger) {
		char playername[64];
		char tnotice[128];
		GetClientName(client, playername, sizeof(playername));
		if (strlen(cvote.triggernotice) == 0) {
			strcopy(tnotice, sizeof(tnotice), votetitle);
		} else {
			ProcessTemplateString(tnotice, sizeof(tnotice), cvote.triggernotice);
			ReplaceParams(tnotice, sizeof(tnotice), vparams, vparamct, cvote.paramtypes, true);
		}
		ReplaceString(tnotice, sizeof(tnotice), "%u", playername);
		PrintToChatAll("[SM] %s [%d/%d votes]", tnotice, votect, tcount);
		if (votect < tcount)
			return;
	}

	ClearTempParams(client);
	g_lastVoteTime = GetTime();
	g_voteLastInitiated[voteidx] = g_lastVoteTime;

	// Chat votes are a special case
	if (cvote.type == CVoteType_Chat) {
		int votepct = RoundToCeil((float(votect) / float(players)) * float(100));
		PrintToChatAll("[SM] %T", "Won The Vote", LANG_SERVER, votepct, votect);
		LogAction(0, -1, "Vote succeeded with %d%% of the vote (%d votes)", votepct, votect);

		char execcommand[128] = "";
		ProcessTemplateString(execcommand, sizeof(execcommand), cvote.execute);
		ReplaceParams(execcommand, sizeof(execcommand), vparams, vparamct, cvote.paramtypes);
		if (strlen(execcommand) > 0) {
			DataPack strpack = new DataPack();
			strpack.WriteString(execcommand);
			CreateTimer(sm_cvote_executedelay.FloatValue, Timer_ExecuteCommand, strpack, TIMER_FLAG_NO_MAPCHANGE);
		/*	CreateDataTimer(sm_cvote_executedelay.FloatValue, Timer_ExecuteCommand, strpack, TIMER_FLAG_NO_MAPCHANGE);
			strpack.WriteString(execcommand);*/
		}
	} else {
		g_activeVoteStatusIdx = statusidx;
		g_voteStatus.GetArray(g_activeVoteStatusIdx, g_activeVoteStatus);

		char key[64];
		char value[128];

		char label[128];
		Menu vm = new Menu(CVote_MenuHandler);

		vm.SetTitle(votetitle);
		vm.ExitButton = false;

		switch (cvote.type) {
			case CVoteType_List: {
				if (cvote.options > 0) {
					for (int i = 0; i < cvote.options; ++i) {
						cvote.optiondata.ReadString(key, sizeof(key));
						ReplaceParams(key, sizeof(key), vparams, vparamct, cvote.paramtypes);
						cvote.optiondata.ReadString(value, sizeof(value));
						ReplaceParams(value, sizeof(value), vparams, vparamct, cvote.paramtypes, true);
						vm.AddItem(key, value, ITEMDRAW_DEFAULT);
					}
					cvote.optiondata.Reset();
				}
			}
			case CVoteType_Confirm: {
				Format(label, sizeof(label), "%T", "Yes", LANG_SERVER);
				vm.AddItem("1", label, ITEMDRAW_DEFAULT);
				Format(label, sizeof(label), "%T", "No", LANG_SERVER);
				vm.AddItem("0", label, ITEMDRAW_DEFAULT);
			}
			case CVoteType_OnOff: {
				Format(label, sizeof(label), "%T", "On", LANG_SERVER);
				vm.AddItem("1", label, ITEMDRAW_DEFAULT);
				Format(label, sizeof(label), "%T", "Off", LANG_SERVER);
				vm.AddItem("0", label, ITEMDRAW_DEFAULT);
			}
		}

		LogAction(client, -1, "%L initiated a %s vote", client, cvote.name);
		ShowActivity(client, "%t", "Initiated a vote");
		vm.VoteResultCallback = CVote_VoteHandler;
		vm.DisplayVote(g_activeVoteStatus.targets, g_activeVoteStatus.targetct, 30);
	}
}

public int CVote_AddParamMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Select) {
		char vparams[10][64];
		DataPack parampack = g_clientTempParams[param1].params;
		int i = 0;
		for (i = 0; i < g_clientTempParams[param1].paramct; ++i)
			parampack.ReadString(vparams[i], 64);
		delete parampack;
		menu.GetItem(param2, vparams[i++], 64);
		CVote_DoVote(param1, g_clientTempParams[param1].name, vparams, i, g_clientTempParams[param1].triggered);
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && g_adminMenuHandle != null)
			RedisplayAdminMenu(g_adminMenuHandle, param1);
		ClearCurrentVote();
	}
	
	return 0;
}

public int CVote_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_VoteCancel) {
		CVote cvote;
		g_voteArray.GetArray(g_activeVoteStatus.voteindex, cvote);
		int client = (param1 > -1 ? param1 : 0);
		LogAction(client, -1, "%L cancelled the %s vote", client, cvote.name);
		ShowActivity(client, "%t", "Cancelled Vote");
		ClearCurrentVote();
	} else if (action == MenuAction_Select) {
		char itemval[64];
		char itemname[128];
		int style = 0;
		menu.GetItem(param2, itemval, sizeof(itemval), style, itemname, sizeof(itemname));
		switch (sm_cvote_showstatus.IntValue) {
			case 1: {
				g_activeVoteStatus.clientvotes[param1] = param2;
				CVote_UpdateStatusPanel(menu);
			}
			case 2: {
				for (int i = 0; i < g_activeVoteStatus.targetct; ++i)
					PrintToChat(g_activeVoteStatus.targets[i], "[SM] %t", "Vote Select Anonymous", itemname);
			}
			case 3: {
				char playername[64] = "";
				GetClientName(param1, playername, sizeof(playername));
				for (int i = 0; i < g_activeVoteStatus.targetct; ++i)
					PrintToChat(g_activeVoteStatus.targets[i], "[SM] %t", "Vote Select", playername, itemname);
			}
		}
	}

	return 0;
}

void CVote_UpdateStatusPanel(Menu menu)
{
	CVote cvote;
	g_voteArray.GetArray(g_activeVoteStatus.voteindex, cvote);

	char vparams[10][64];
	for (int i = 0; i < g_activeVoteStatus.paramct; ++i)
		g_activeVoteStatus.params.ReadString(vparams[i], 64);
	g_activeVoteStatus.params.Reset();

	Panel statuspanel = new Panel();

	char votetitle[128];
	char label[128];
	ProcessTemplateString(votetitle, sizeof(votetitle), cvote.title);
	ReplaceParams(votetitle, sizeof(votetitle), vparams, g_activeVoteStatus.paramct, cvote.paramtypes, true);
	statuspanel.SetTitle(votetitle);
	statuspanel.DrawText(" ");
	Format(label, sizeof(label), "%T:", "Results", LANG_SERVER);
	statuspanel.DrawText(label);

	char paneltext[128];
	char itemval[64];
	char itemname[128];
	int itemct = menu.ItemCount;
	int style = 0;
	
	int votesumm[10];
	for (int i = 1; i <= MaxClients; i++)
		if (g_activeVoteStatus.clientvotes[i] > -1)
			votesumm[g_activeVoteStatus.clientvotes[i]]++;

	for (int j = 0; j < itemct; ++j) {
		menu.GetItem(j, itemval, sizeof(itemval), style, itemname, sizeof(itemname));
		ProcessTemplateString(label, sizeof(label), itemname);
		ReplaceParams(label, sizeof(label), vparams, g_activeVoteStatus.paramct, cvote.paramtypes, true);
		Format(paneltext, sizeof(paneltext), "%s: %d", label, votesumm[j]);
		statuspanel.DrawItem(paneltext, ITEMDRAW_DEFAULT);
	}

	statuspanel.DrawText(" ");
	for (int j = itemct; j < 9; ++j)
		statuspanel.DrawItem(" ", ITEMDRAW_NOTEXT);
	statuspanel.DrawItem("Close window", ITEMDRAW_CONTROL);

	for (int i = 1; i <= MaxClients; i++)
		if (g_activeVoteStatus.clientvotes[i] > -1 && g_activeVoteStatus.clientnostatus[i] == -1)
			statuspanel.Send( i, CVote_PanelHandler, 5);

	delete statuspanel;
}

public int CVote_PanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select) {
		if (param2 == 10)
			g_activeVoteStatus.clientnostatus[param1] = 1;
		// Workaround breaking weapon selection
		if (param2 <= 5)
			ClientCommand(param1, "slot%d", param2);
	}

	return 0;
}

public void CVote_VoteHandler(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	CVote cvote;
	g_voteArray.GetArray(g_activeVoteStatus.voteindex, cvote);

	char vparams[10][64];
	for (int i = 0; i < g_activeVoteStatus.paramct; ++i)
		g_activeVoteStatus.params.ReadString(vparams[i], 64);
	g_activeVoteStatus.params.Reset();

	char execcommand[128] = "";
	char value[64];
	char description[128];
	int style;
	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], value, sizeof(value), style, description, sizeof(description));

	// See if top vote meets winning criteria
	int winvotes = item_info[0][VOTEINFO_ITEM_VOTES];
	int winpercent = RoundToFloor((float(winvotes) / float(num_votes)) * float(100));
	int playerpercent = RoundToFloor((float(winvotes) / float(GetRealClientCount(true))) * float(100));
	if (winpercent < cvote.percent) {
		PrintToChatAll("[SM] %T", "Not Enough Vote Percentage", LANG_SERVER, cvote.percent, winpercent);
	} else if (playerpercent < cvote.abspercent) {
		PrintToChatAll("[SM] %T", "Not Enough Vote Percentage", LANG_SERVER, cvote.abspercent, playerpercent);
	} else if (winvotes < cvote.votes) {
		PrintToChatAll("[SM] %T", "Not Enough Votes", LANG_SERVER, cvote.votes, winvotes);
	} else {
		PrintToChatAll("[SM] %T", "Option Won The Vote", LANG_SERVER, description, winpercent, winvotes);
		LogAction(0, -1, "\"%s\" (%s) won with %d%% of the vote (%d votes)", description, value, winpercent, winvotes);

		for (int cl = 1; cl < MaxClients; cl++)
		{
			if (IsClientInGame(cl))
				ClientCommand(cl, "playgamesound #ambient/alarms/warningbell1.wav");
		}

		// Don't need to take action if a confirmation vote was shot down
		if (cvote.type != CVoteType_Confirm || strcmp(value, "1") == 0) {
			strcopy(vparams[g_activeVoteStatus.paramct++], 64, value);
			ProcessTemplateString(execcommand, sizeof(execcommand), cvote.execute);
			ReplaceParams(execcommand, sizeof(execcommand), vparams, g_activeVoteStatus.paramct, cvote.paramtypes);
			switch (cvote.approve) {
				case CVoteApprove_None: {
					if (strlen(execcommand) > 0) {
						ClearCurrentVote();
						DataPack strpack = new DataPack();
						strpack.WriteString(execcommand);
						CreateTimer(sm_cvote_executedelay.FloatValue, Timer_ExecuteCommand, strpack, TIMER_FLAG_NO_MAPCHANGE);
					/*	CreateDataTimer(sm_cvote_executedelay.FloatValue, Timer_ExecuteCommand, strpack, TIMER_FLAG_NO_MAPCHANGE);
						strpack.WriteString(execcommand);*/
					}
				}
				case CVoteApprove_Admin: {
					char targetdesc[128];
					int vtargets[MAXPLAYERS+1];
					int vtargetct = 0;

					if ((vtargetct = ProcessVoteTargetString(
							"@admins",
							vtargets,
							targetdesc,
							sizeof(targetdesc))) <= 0) {
						PrintToChatAll("[SM] %T %T", "No Admins Found To Approve Vote", LANG_SERVER, "Cancelled Vote", LANG_SERVER);
					} else {
						CVote_ConfirmVote(vtargets, vtargetct, execcommand, description);
					}
				}
				case CVoteApprove_Sender: {	
					int vtargets[1];
					vtargets[0] = g_activeVoteStatus.sender;
					int vtargetct = 1;
					CVote_ConfirmVote(vtargets, vtargetct, execcommand, description);
				}
			}
		}
	}
	ClearCurrentVote();
}

void CVote_ConfirmVote(int[] vtargets, int vtargetct, const char[] execcommand, const char[] description)
{
	Menu cm = new Menu(CVote_ConfirmMenuHandler);

	cm.SetTitle("%T", "Accept Vote Result", LANG_SERVER, description);
	cm.ExitButton = false;
	cm.AddItem(execcommand, "Yes", ITEMDRAW_DEFAULT);
	cm.AddItem("0", "No", ITEMDRAW_DEFAULT);

	g_confirmMenus = vtargetct;
	for (int i = 0; i < vtargetct; ++i)
		cm.Display(vtargets[i], 30);
}

public int CVote_ConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
		if (g_confirmMenus > 0) {
			if (--g_confirmMenus == 0)
				PrintToChatAll("[SM] %T %T", "No Admins Approved Vote", LANG_SERVER, "Cancelled Vote", LANG_SERVER);
		}
	} else if (action == MenuAction_Select) {
		if (g_confirmMenus > 0) {
			g_confirmMenus = 0;
			char execcommand[128];
			menu.GetItem(param2, execcommand, sizeof(execcommand));
			if (param2 == 1) {
				ShowActivity(param1, "%T", "Vote Rejected", LANG_SERVER);
				LogAction(param1, -1, "Vote rejected by %L", param1);
			} else {
				ShowActivity(param1, "%T", "Vote Accepted", LANG_SERVER);
				if (strlen(execcommand) > 0) {
					LogAction(param1, -1, "Vote approved by %L", param1);
					DataPack strpack = new DataPack();
					strpack.WriteString(execcommand);
					CreateTimer(sm_cvote_executedelay.FloatValue, Timer_ExecuteCommand, strpack, TIMER_FLAG_NO_MAPCHANGE);
				/*	CreateDataTimer(sm_cvote_executedelay.FloatValue, Timer_ExecuteCommand, strpack, TIMER_FLAG_NO_MAPCHANGE);
					strpackWriteString(execcommand);*/
				}
			}
		}
	}
	
	return 0;
}

/***********************
 ** UTILITY FUNCTIONS **
 ***********************/

public Action Timer_ExecuteCommand(Handle timer, DataPack strpack)
{
	char command[128];
	strpack.Reset();
	strpack.ReadString(command, sizeof(command));
	delete strpack;
	LogAction(0, -1, "Executing \"%s\"", command);
	ServerCommand(command);
	
	return Plugin_Stop;
}

// Get the index for an existing vote status, or create a new one and return the index
stock int GetStatusIndex(int voteidx, int vsender, const char[][] vparams, int vparamct)
{
	int ssize = g_voteStatus.Length;
	char tparam[64];
	CVoteStatus tstatus;
	bool match = false;

	for (int i = 0; i < ssize; ++i) {
		g_voteStatus.GetArray(i, tstatus);
		if (tstatus.voteindex == voteidx) {
			match = true;
			for (int j = 0; j < vparamct; ++j) {
				tstatus.params.ReadString(tparam, sizeof(tparam));
				if (strcmp(vparams[j], tparam) != 0)
					match = false;
			}
			tstatus.params.Reset();
			if (match) {
				int currtime = GetTime();
				CVote cvote;
				g_voteArray.GetArray(voteidx, cvote);
				for (int j = 1; j <= MaxClients; ++j)
					if (tstatus.clienttriggers[j] > -1 && currtime - tstatus.clienttimestamps[j] > cvote.triggerexpires)
						tstatus.clienttriggers[j] = -1;
				g_voteStatus.SetArray(i, tstatus);
				return i;
			}
		}
	}

	return INVALID_VOTE;
}

stock int CreateStatus(int voteidx, int vsender, const char[][] vparams, int vparamct)
{
	// No match, create a new status
	CVote cvote;
	g_voteArray.GetArray(voteidx, cvote);

	CVoteStatus vstatus;
	vstatus.voteindex = voteidx;
	vstatus.paramct = vparamct;
	for (int i = 1; i <= MaxClients; ++i) {
		vstatus.clientvotes[i] = -1;
		vstatus.clientnostatus[i] = -1;
		vstatus.clienttriggers[i] = -1;
		vstatus.clienttimestamps[i] = 0;
	}

	//char targetstr[32] = "@all";
	char targetstr[32] = "@humans";
	char targetdesc[128];
	int targetlist[MAXPLAYERS+1];

	if (strlen(cvote.target) > 0)
		strcopy(targetstr, sizeof(targetstr), cvote.target);

	vstatus.targetct = ProcessVoteTargetString(
				targetstr,
				vstatus.targets,
				targetdesc,
				sizeof(targetdesc));

	vstatus.params = new DataPack();
	vstatus.paramdata = new DataPack();
	for (int i = 0; i < vparamct; ++i) {
		vstatus.params.WriteString(vparams[i]);
		if (cvote.paramtypes[i] == CVoteParamType_Player
				|| cvote.paramtypes[i] == CVoteParamType_GroupPlayer
				|| cvote.paramtypes[i] == CVoteParamType_Group) {
			ProcessVoteTargetString(vparams[i], targetlist, targetdesc, sizeof(targetdesc));
			vstatus.paramdata.WriteString(targetdesc);
		} else {
			vstatus.paramdata.WriteString("");
		}
	}
	vstatus.params.Reset();
	vstatus.paramdata.Reset();

	vstatus.sender = vsender;

	return g_voteStatus.PushArray(vstatus);
}

stock void RemoveExpiredStatuses()
{
	CVoteStatus tstatus;
	CVote cvote;
	int currtime = GetTime();
	for (int i = 0; i < g_voteStatus.Length; ++i) {
		if (g_activeVoteStatusIdx != i) {
			g_voteStatus.GetArray(i, tstatus);
			g_voteArray.GetArray(tstatus.voteindex, cvote);
			int trigct = 0;
			for (int j = 1; j <= MaxClients; ++j) {
				if (tstatus.clienttriggers[j] > -1) {
					if (currtime - tstatus.clienttimestamps[j] <= cvote.triggerexpires)
						trigct++;
				}
			}
			// Not active and no unexpired triggers found, clean from memory
			if (trigct == 0)
				g_voteStatus.Erase(i--);
		}
	}
}

stock bool IsVoteAllowed(int client, int voteidx, bool fromtrigger, char[] errormsg, int msglen)
{
	CVote cvote;
	g_voteArray.GetArray(voteidx, cvote);

	int lang = LANG_SERVER;
	if (client > 0)
		lang = client;
		//lang = GetClientLanguage(client);

	if (IsVoteInProgress() || (g_activeVoteStatusIdx > -1 && (g_activeVoteStatusIdx != voteidx || g_activeVoteStatus.sender != client))) {
		Format(errormsg, msglen, "%T", "Vote in Progress", lang);
		return false;
	}

	int currtime = GetTime();
	int vd = CheckVoteDelay();
	vd = Max(vd, (g_mapStartTime + sm_cvote_mapdelay.IntValue) - currtime);
	vd = Max(vd, (g_mapStartTime + cvote.mapdelay) - currtime);
	vd = Max(vd, (g_lastVoteTime + sm_vote_delay.IntValue) - currtime);
	vd = Max(vd, (g_voteLastInitiated[voteidx] + cvote.delay) - currtime);
	if (fromtrigger) {
		vd = Max(vd, (g_lastVoteTime + sm_cvote_triggerdelay.IntValue) - currtime);
		vd = Max(vd, (g_voteLastInitiated[voteidx] + cvote.triggerdelay) - currtime);
	}

	if (vd > 0) {
		Format(errormsg, msglen, "%T", "Vote Delay Seconds", lang, vd);
		return false;
	}

	return true;
}

stock bool CanInitiateVote(int client, char[] command)
{
	if (strlen(command) == 0) {
		if (sm_cvote_adminonly.BoolValue)
			return ((GetUserFlagBits(client) & ADMFLAG_GENERIC) == ADMFLAG_GENERIC || (GetUserFlagBits(client) & ADMFLAG_ROOT) == ADMFLAG_ROOT);
		else
			return true;
	} else if (CheckCommandAccess(client, command, ADMFLAG_ROOT)) {
		return true;
	}
	return false;
}

stock int ProcessVoteTargetString(const char[] targetstr, int[] vtargets, char[] targetdesc, int targetdesclen, int client=0, bool nomulti=false)
{
	int maxc = MaxClients;
	int vtargetct = 0;

	if (!nomulti && strcmp(targetstr, "@admins") == 0) {
		for (int i = 1; i <= maxc; i++)
			if (IsClientInGame(i) && (GetUserFlagBits(i) & ADMFLAG_GENERIC) == ADMFLAG_GENERIC)
				vtargets[vtargetct++] = i;
		PrintToServer("%d admins", vtargetct);
		strcopy(targetdesc, targetdesclen, "admins");
	} else {
		int filter = 0;
		int skipped = 0;
		if (nomulti) 
			filter = filter|COMMAND_FILTER_NO_MULTI;
		bool tn_is_ml = false;
		vtargetct = ProcessTargetString(targetstr, 0, vtargets, maxc, filter, targetdesc, targetdesclen, tn_is_ml);
		if (client > 0) {
			AdminId aid = GetUserAdmin(client);
			AdminId tid;
			for (int i = 0; i < vtargetct; ++i) {
				tid = GetUserAdmin(vtargets[i]);
				if (tid == INVALID_ADMIN_ID
						//|| (aid == INVALID_ADMIN_ID && !GetAdminFlag(tid, Admin_Generic, Access_Effective))
						|| (aid != INVALID_ADMIN_ID && CanAdminTarget(aid, tid)))
					vtargets[i - skipped] = vtargets[i];
				else
					skipped++;
			}
			vtargetct -= skipped;
		}
	}

	return vtargetct;
}

stock int GetParamCount(const char[] expr)
{
	int idx = -1;
	int max = 0;
	int pnum = 0;
	while ((idx = IndexOf(expr, '#', idx)) > -1) {
		if (IsCharNumeric(expr[idx+1])) {
			pnum = expr[idx+1] - 48;
			if (pnum > max) max = pnum;
		}
	}
	while ((idx = IndexOf(expr, '@', idx)) > -1) {
		if (IsCharNumeric(expr[idx+1])) {
			pnum = expr[idx+1] - 48;
			if (pnum > max) max = pnum;
		}
	}
	return max;
}

stock int IndexOf(const char[] str, int chars, int offset=-1)
{
	for (int i = offset + 1; i < strlen(str); ++i)
		if (str[i] == chars)
			return i;
	return -1;
}

stock int InArrayInt(int needle, int[] haystack, int hsize)
{
	for (int i = 0; i < hsize; ++i)
		if (needle == haystack[i])
			return i;
	return -1;
}

stock int InArray(const char[] needle, const char[][] haystack, int hsize)
{
	for (int i = 0; i < hsize; ++i)
		if (strcmp(needle, haystack[i]) == 0)
			return i;
	return -1;
}

stock int Max(int first, int second)
{
	if (first > second)
		return first;
	return second;
}

stock void PrintVotesToMenu(int client)
{
	if (client == 0)
		return;

	int s = g_voteArray.Length;
	CVote tvote;
	char votetitle[128];
	char voteparams[10][64];
	char errormsg[128];
	CVoteParamType voteparamtypes[10];
	int voteparamct = 0;

	Menu menu = new Menu(CVote_VoteListMenuHandler);
	menu.SetTitle("%T:", "Available Votes", LANG_SERVER);

	for (int i = 0; i < s; ++i) {
		g_voteArray.GetArray(i, tvote);
		voteparamct = tvote.numparams;
		for (int k = 0; k < tvote.numparams; ++k) {
			voteparamtypes[k] = CVoteParamType_List;
			switch (tvote.paramtypes[k]) {
				case CVoteParamType_MapCycle: {
					strcopy(voteparams[k], 32, "<map>");
				}
				case CVoteParamType_MapList: {
					strcopy(voteparams[k], 32, "<map>");
				}
				case CVoteParamType_Player: {
					strcopy(voteparams[k], 32, "<player>");
				}
				case CVoteParamType_GroupPlayer: {
					strcopy(voteparams[k], 32, "<group/player>");
				}
				case CVoteParamType_Group: {
					strcopy(voteparams[k], 32, "<group>");
				}
				case CVoteParamType_OnOff: {
					strcopy(voteparams[k], 32, "<on/off>");
				}
				case CVoteParamType_YesNo: {
					strcopy(voteparams[k], 32, "<yes/no>");
				}
				case CVoteParamType_List: {
					strcopy(voteparams[k], 32, "<value>");
				}
			}
		}

		ProcessTemplateString(votetitle, sizeof(votetitle), tvote.title);
		ReplaceParams(votetitle, sizeof(votetitle), voteparams, voteparamct, voteparamtypes, true);

		if (CanInitiateVote(client, tvote.admin)) {
			if (IsVoteAllowed(client, i, false, errormsg, sizeof(errormsg)))
				menu.AddItem(tvote.name, votetitle, ITEMDRAW_DEFAULT);
			else
				menu.AddItem(tvote.name, votetitle, ITEMDRAW_DISABLED);
		} else if (strlen(tvote.trigger) > 0) {
			if (IsVoteAllowed(client, i, true, errormsg, sizeof(errormsg)))
				menu.AddItem(tvote.name, votetitle, ITEMDRAW_DEFAULT);
			else
				menu.AddItem(tvote.name, votetitle, ITEMDRAW_DISABLED);
		}
	}

	if (menu.ItemCount > 0)
		menu.Display(client, 60);
}

public int CVote_VoteListMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Select) {
		char p[1][1];
		char votename[32];
		menu.GetItem(param2, votename, sizeof(votename));

		// Fetch the vote definition
		int voteidx = InArray(votename, g_voteNames, g_voteArray.Length);
		CVote tvote;
		if (voteidx > -1) {
			g_voteArray.GetArray(voteidx, tvote);
			// Check user access
			if (CanInitiateVote(param1, tvote.admin))
				CVote_DoVote(param1, votename, p, 0);
			else if (strlen(tvote.trigger) > 0)
				CVote_DoVote(param1, votename, p, 0, true);
			else
				PrintToChat(param1, "This vote can only be initiated by an admin.");
		}
	}
	
	return 0;
}

stock void PrintVotesToConsole(int client)
{
	int s = g_voteArray.Length;
	CVote tvote;
	char votetitle[128];
	PrintToConsole(client, "Available votes:");
	for (int i = 0; i < s; ++i) {
		g_voteArray.GetArray(i, tvote);
		if (client == 0 || CanInitiateVote(client, tvote.admin)) {
			ProcessTemplateString(votetitle, sizeof(votetitle), tvote.title);
			PrintToConsole(client, "  %20s %s", tvote.name, votetitle);
		}
	}
}

stock void ProcessTemplateString(char[] dest, int destlen, const char[] source)
{
	char cvar[32];
	char[] expr = new char[destlen];
	char modifiers[10][32];
	int destidx = 0;

	int modcount = 0;
	int negate = 0;
	int start = -1;
	int end = -1;
	int firstmod = -1;

	for (int i = 0; i < strlen(source); ++i)
	{
		if (start == -1 && source[i] == '{') {
			strcopy(dest[destidx], i - end, source[end + 1]);
			destidx += i - end - 1;
			start = i;
			end = 0;
		}
		if (start ==  i-1 && source[i] == '!') negate = 1;
		if (start > -1 && source[i] == '|' && firstmod == -1) firstmod = i - start - 1 - negate;
		if (start > -1 && source[i] == '}') end = i;
		if (start > -1 && end > 0) {
			// Parse expression
			int exprsize = (end - start) - negate;
			strcopy(expr, exprsize, source[start + 1 + negate]);
			if (firstmod > -1) {
				strcopy(cvar, firstmod + 1, expr);
				modcount = ExplodeString(expr[firstmod + 1], "|", modifiers, sizeof(modifiers), 32);
			} else {
				strcopy(cvar, exprsize, expr);
				modcount = 0;
			}

			// Replace
			ConVar cvh = FindConVar(cvar);
			if (cvh != null) {
				char val[128];
				cvh.GetString(val, sizeof(val));
				if (negate) {
					if (strcmp(val, "0") == 0) strcopy(val, 2, "1");
					else strcopy(val, 2, "0");
				}
				for (int j = 0; j < modcount; ++j) {
					if (strcmp(modifiers[j], "onoff") == 0) {
						if (strcmp(val, "0") == 0) strcopy(val, 4, "off");
						else strcopy(val, 3, "on");
					} else if (strcmp(modifiers[j], "yesno") == 0) {
						if (strcmp(val, "0") == 0) strcopy(val, 4, "no");
						else strcopy(val, 3, "yes");
					} else if (strcmp(modifiers[j], "capitalize") == 0
							|| strcmp(modifiers[j], "cap") == 0) {
						val[0] = CharToUpper(val[0]);
					} else if (strcmp(modifiers[j], "upper") == 0) {
						for(int k = 0; k < strlen(val); ++k)
							val[k] = CharToUpper(val[k]);
					} else if (strcmp(modifiers[j], "lower") == 0) {
						for(int k = 0; k < strlen(val); ++k)
							val[k] = CharToLower(val[k]);
					}
				}
				strcopy(dest[destidx], destlen, val);
				destidx += strlen(val);
			}

			// Reset flags
			start = -1;
			firstmod = -1;
			negate = 0;
		}
	}
	strcopy(dest[destidx], strlen(source) - end, source[end + 1]);
}

stock void ReplaceParams(char[] source, int sourcelen, const char[][] vparams, int vparamct, CVoteParamType[] ptypes, bool pretty=false, int client=0)
{
	char token[3];
	char replace[128];
	char quoted[128];
	int vtargets[MAXPLAYERS+1];
	char targetdesc[128];
	int vtargetct;
	for (int i = 0; i < vparamct; ++i) {
		if (pretty) {
			switch(ptypes[i]) {
				case CVoteParamType_Player: {
					vtargetct = ProcessVoteTargetString(vparams[i], vtargets, targetdesc, sizeof(targetdesc), client, true);
					if (vtargetct > 0)
						strcopy(replace, sizeof(replace), targetdesc);
				}
				case CVoteParamType_GroupPlayer: {
					vtargetct = ProcessVoteTargetString(vparams[i], vtargets, targetdesc, sizeof(targetdesc), client);
					if (vtargetct > 0)
						strcopy(replace, sizeof(replace), targetdesc);
				}
				case CVoteParamType_Group: {
					vtargetct = ProcessVoteTargetString(vparams[i], vtargets, targetdesc, sizeof(targetdesc), client);
					if (vtargetct > 0)
						strcopy(replace, sizeof(replace), targetdesc);
				}
				case CVoteParamType_OnOff: {
					if (strcmp(vparams[i], "1") == 0)
						strcopy(replace, sizeof(replace), "on");
					else
						strcopy(replace, sizeof(replace), "off");
				}
				case CVoteParamType_YesNo: {
					if (strcmp(vparams[i], "1") == 0)
						strcopy(replace, sizeof(replace), "yes");
					else
						strcopy(replace, sizeof(replace), "no");
				}
				default: {
					strcopy(replace, sizeof(replace), vparams[i]);
				}
			}
			strcopy(quoted, sizeof(quoted), replace);
		} else {
			strcopy(replace, sizeof(replace), vparams[i]);
			Format(quoted, sizeof(quoted), "\"%s\"", replace);
		}
		Format(token, sizeof(token), "@%d", i + 1);
		ReplaceString(source, sourcelen, token, replace);
		Format(token, sizeof(token), "#%d", i + 1);
		ReplaceString(source, sourcelen, token, quoted);
	}
}

void ResetVoteCache(CVote cvote)
{
	strcopy(cvote.name, 32, "");
	strcopy(cvote.admin, 32, "");
	strcopy(cvote.trigger, 32, "");
	strcopy(cvote.triggernotice, 128, "");
	//strcopy(cvote.target, 32, "@all");
	strcopy(cvote.target, 32, "@humans");
	strcopy(cvote.execute, 128, "");
	cvote.triggerpercent = 0;
	cvote.triggercount = 0;
	cvote.triggerexpires = 300;
	cvote.delay = 0;
	cvote.triggerdelay = 0;
	cvote.mapdelay = 0;
	cvote.percent = sm_cvote_minpercent.IntValue;
	cvote.abspercent = 0;
	cvote.votes = sm_cvote_minvotes.IntValue;
	cvote.approve = CVoteApprove_None;
	cvote.type = CVoteType_List;
	cvote.options = 0;
	cvote.numparams = 0;
	for (int i = 0; i < 10; ++i) {
		cvote.paramoptions[i] = 0;
		cvote.paramdata[i] = null;
	}
}

void ClearTempParams(int client)
{
//	g_clientTempParams[client].voteindex = -1;
	g_clientTempParams[client].paramct = 0;
}

void ClearCurrentVote()
{
	if (g_activeVoteStatusIdx > -1) {
		g_voteStatus.Erase(g_activeVoteStatusIdx);
		g_activeVoteStatusIdx = -1;
	}
	g_adminMenuHandle = null;
}

bool CheckClientTarget(const char[] targetstr, int client, bool nomulti)
{
	int vtargets[MAXPLAYERS+1];
	char targetdesc[128];
	int vtargetct = ProcessVoteTargetString(targetstr, vtargets, targetdesc, sizeof(targetdesc), client, nomulti);
	return vtargetct > 0;
}

/*****************************************************************
 ** STOCK MENU FUNCTIONS (will hopefully be added to adminmenu) **
 *****************************************************************/

enum struct TargetGroup
{
	char groupName[32];
	char groupTarget[32];
}

TargetGroup g_targetGroups[32];
int g_targetGroupCt = -1;
int g_mapSerial = -1;
ArrayList g_mapCycle = null;
ArrayList g_mapList = null;

Menu CreateStockMenu(StockMenuType menutype, MenuHandler menuhandler, int client, const char[] mapcycle = "sm_cvote")
{
	Menu menu = new Menu(menuhandler);
	switch (menutype) {
		case StockMenuType_MapCycle: {
			if (g_mapCycle == null) {
				g_mapCycle = new ArrayList(32);
				ReadMapList(g_mapCycle, g_mapSerial, mapcycle, MAPLIST_FLAG_CLEARARRAY);
			}

			int mapcount = g_mapCycle.Length;
			char mapname[32];
			for (int i = 0; i < mapcount; ++i) {
				g_mapCycle.GetString(i, mapname, sizeof(mapname));
				menu.AddItem(mapname, mapname, ITEMDRAW_DEFAULT);
			}
		}
		case StockMenuType_MapList: {
		
			int mapcount;
			if (g_mapList == null) {
				g_mapList = new ArrayList(32);
				mapcount = LoadMapList(g_mapList);
			} else {
				mapcount = g_mapList.Length;
			}

			char mapname[32];
			for (int i = 0; i < mapcount; ++i) {
				g_mapList.GetString(i, mapname, sizeof(mapname));
				menu.AddItem(mapname, mapname, ITEMDRAW_DEFAULT);
			}
		}
		case StockMenuType_Player: {
			AddPlayerItems(menu, client);
		}
		case StockMenuType_GroupPlayer: {
			AddGroupItems(menu);
			AddPlayerItems(menu, client);
		}
		case StockMenuType_Group: {
			AddGroupItems(menu);
		}
		case StockMenuType_OnOff: {
			menu.AddItem("1", "On", ITEMDRAW_DEFAULT);
			menu.AddItem("0", "Off", ITEMDRAW_DEFAULT);
		}
		case StockMenuType_YesNo: {
			menu.AddItem("1", "Yes", ITEMDRAW_DEFAULT);
			menu.AddItem("0", "No", ITEMDRAW_DEFAULT);
		}
	}
	return menu;
}

void AddPlayerItems(Menu menu, int client)
{
	char playername[64];
	char steamid[32];
	char playerid[32];
	int vtargets[MAXPLAYERS+1];
	char targetdesc[128];
	int vtargetct;
	
	//vtargetct = ProcessVoteTargetString("@all", vtargets, targetdesc, sizeof(targetdesc), client);
	vtargetct = ProcessVoteTargetString("@humans", vtargets, targetdesc, sizeof(targetdesc), client);

	for (int i = 0; i < vtargetct; ++i) {
		if (vtargets[i] > 0 && IsClientInGame(vtargets[i])) {
			if (IsFakeClient(vtargets[i])) {
				Format(playerid, sizeof(playerid), "#%d", GetClientUserId(vtargets[i]));
			} else if (!IsClientAuthorized(vtargets[i])) {
				// Use IP address if not authorized - won't work with most commands!
				GetClientIP(vtargets[i], steamid, sizeof(steamid));
				Format(playerid, sizeof(playerid), "#%s", steamid);
			} else {
				GetClientAuthId(vtargets[i], AuthId_Steam2, steamid, sizeof(steamid));
				Format(playerid, sizeof(playerid), "#%s", steamid);
			}
			GetClientName(vtargets[i], playername, sizeof(playername));
			menu.AddItem(playername, playername, ITEMDRAW_DEFAULT);
		}
	}
}

void AddDisconnectedPlayers(Menu menu, const char[] votename, int pidx)
{
	char steamids[MAXPLAYERS*2][32];
	int sidx = 0;
	char steamid[32];
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && !IsFakeClient(i)) {
			GetClientAuthId(i, AuthId_Steam2, steamid, sizeof(steamid));
			Format(steamids[sidx++], 32, "#%s", steamid);
		}
	}
	for (int i = 0; i < g_voteStatus.Length; ++i) {
		if (strcmp(g_activeVoteStatus.name, votename) == 0) {
			char sid[32];
			char sname[64];
			char label[64];
			for (int j = 0; j <= pidx; ++j) {
				g_activeVoteStatus.params.ReadString(sid, sizeof(sid));
				g_activeVoteStatus.paramdata.ReadString(sname, sizeof(sname));
			}
			g_activeVoteStatus.params.Reset();
			g_activeVoteStatus.paramdata.Reset();
			if (InArray(sid, steamids, sizeof(steamids)) == -1) {
				Format(label, sizeof(label), "* %s", sname);
				menu.AddItem(sid, sname, ITEMDRAW_DEFAULT);
				strcopy(steamids[sidx++], 32, sid);
			}
		}
	}
}

void AddGroupItems(Menu menu)
{
	if (g_targetGroupCt == -1) {
		g_targetGroupCt = 0;
		char groupconfig[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, groupconfig, sizeof(groupconfig), "configs/adminmenu_grouping.txt");
		SMCParser parser = new SMCParser();
		//parser.OnEnterSection = gtNewSection;
		parser.OnKeyValue = gtKeyValue;
		//parser.OnLeaveSection = gtEndSection;

		int line = 0;
		parser.ParseFile(groupconfig, line);
		delete parser;
	}
	for (int i = 0; i < g_targetGroupCt; ++i)
		menu.AddItem(g_targetGroups[i].groupTarget, g_targetGroups[i].groupName, ITEMDRAW_DEFAULT);
}

public SMCResult gtKeyValue(SMCParser parser, const char[] key, const char[] value, bool keyquotes, bool valuequotes)
{
	if (g_targetGroupCt < 32) {
		strcopy(g_targetGroups[g_targetGroupCt].groupName, 32, key);
		strcopy(g_targetGroups[g_targetGroupCt++].groupTarget, 32, value);
	}
	
	return SMCParse_Continue;
}
/*
public SMCResult gtNewSection(SMCParser parser, const char[] section, bool quotes) {}
public SMCResult gtEndSection(SMCParser parser) {}
*/
/*
// DEBUG - DELETE ME
stock Action Command_AddAdmin(int client, int args)
{
	int tct = 0;
	bool ml = false;
	int maxc = MaxClients;
	int t[maxc];
	char td[32];
	char ts[32];
	GetCmdArg(1, ts, sizeof(ts));
	tct = ProcessTargetString(ts, 0, t, maxc, 0, td, sizeof(td), ml);
	for (int i = 0; i < tct; ++i)
		SetUserFlagBits(t[i], ADMFLAG_GENERIC);
}
*/
stock int GetRealClientCount(bool inGameOnly = true)
{
	int clients = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (((inGameOnly) ? IsClientInGame(i) : IsClientConnected(i)) && !IsFakeClient(i)) {
			clients++;
		}
	}
	return clients;
}

/**
 * This function is no longer supported.  It has been replaced with ReadMapList(), 
 * which uses a more unified caching and configuration mechanism.  This function also 
 * has a bug where if the cvar contents changes, the fileTime change won't be recognized.
 * 
 * Loads a specified array with maps. The maps will be either loaded from mapcyclefile, or if supplied
 * a cvar containing a file name. If the file in the cvar is bad, it will use mapcyclefile. The fileTime
 * parameter is used to store a timestamp of the file. If specified, the file will only be reloaded if it
 * has changed.
 *
 * @param array         Valid array handle, should be created with CreateArray(33) or larger. 
 * @param fileTime      Variable containing the "last changed" time of the file. Used to avoid needless reloading.
 * @param fileCvar      CVAR set to the file to be loaded. Optional.
 * @return              Number of maps loaded or 0 if in error.
 * @deprecated          Use ReadMapList() instead.
 */
stock int LoadMapList(ArrayList array, int &fileTime = 0)
{ 
	char mapPath[] = "maplist.txt";
	bool fileFound = FileExists(mapPath);
	
	if (!fileFound)
	{
		LogError("Failed to find a file to load maps from. No maps loaded.");
		array.Clear();
		
		return 0;		
	}
 
	// If the file hasn't changed, there's no reason to reload
	// all of the maps.
	int newTime =  GetFileTime(mapPath, FileTime_LastChange);
	if (fileTime == newTime)
	{
		return array.Length;
	}
	
	fileTime = newTime;
	
	array.Clear();
 
	File file = OpenFile(mapPath, "rt", false, NULL_STRING);
	if (!file) {
		LogError("Could not open file: %s", mapPath);
		return 0;
	}
 
	LogMessage("Loading maps from file: %s", mapPath);
	
	int len;
	char buffer[64];
	while (!file.EndOfFile() && file.ReadLine(buffer, sizeof(buffer)))
	{
		TrimString(buffer);
 
		if ((len = StrContains(buffer, ".bsp", false)) != -1)
		{
			buffer[len] = '\0';
		}
 
		if (buffer[0] == '\0' || !IsValidConVarChar(buffer[0]) || !SynIsMapValid(buffer))
		{
			continue;
		}
		
		if (array.FindString(buffer) != -1)
		{
			continue;
		}
 
		array.PushString(buffer);
	}
 
	file.Close();
	return array.Length;
}

stock bool SynIsMapValid(const char[] map)
{
	if (!IsMapValid(map))
	{
		char buffer[128];
		Format(buffer, sizeof(buffer), "../../Half-Life 2/episodic/maps/%s.bsp", map);
		
		if (FileExists(buffer, false, NULL_STRING))
		{
		//	strcopy(tag, sizeof(tag), "ep1");
			return true;
		}
		
		Format(buffer, sizeof(buffer), "../../Half-Life 2/ep2/maps/%s.bsp", map);

		if (FileExists(buffer, false, NULL_STRING))
		{
		//	strcopy(tag, sizeof(tag), "ep2");
			return true;
		}

		Format(buffer, sizeof(buffer), "../../Half-Life 2/lostcoast/maps/%s.bsp", map);

		if (FileExists(buffer, false, NULL_STRING))
		{
		//	strcopy(tag, sizeof(tag), "lost");
			return true;
		}
/*
		Format(buffer, sizeof(buffer), "../../Half-Life 2/hl1/maps/%s.bsp", map);

		if (FileExists(buffer, false, NULL_STRING))
		{
		//	strcopy(tag, sizeof(tag), "hl1");
			return true;
		}
*/
		Format(buffer, sizeof(buffer), "../../MINERVA/metastasis/maps/%s.bsp", map);
		
		if (FileExists(buffer, false, NULL_STRING))
		{
		//	strcopy(tag, sizeof(tag), "meta");
			return true;
		}
/*
		Format(buffer, sizeof(buffer), "../../Portal/portal/maps/%s.bsp", map);
		
		if (FileExists(buffer, false, NULL_STRING))
		{
		//	strcopy(tag, sizeof(tag), "portal");
			return true;
		}
*/
		Format(buffer, sizeof(buffer), "../../../SourceMods/DangerousWorld/maps/%s.bsp", map);
		
		if (FileExists(buffer, false, NULL_STRING))
		{
		//	strcopy(tag, sizeof(tag), "dworld");
			return true;
		}

		Format(buffer, sizeof(buffer), "../../../SourceMods/Rock 24/maps/%s.bsp", map);
		
		if (FileExists(buffer, false, NULL_STRING))
		{
		//	strcopy(tag, sizeof(tag), "rock24");
			return true;
		}

	//	strcopy(tag, sizeof(tag), "");
		return false;
	}

//	strcopy(tag, sizeof(tag), "syn");
	return true;
}