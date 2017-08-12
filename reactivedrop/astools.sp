#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.0"

int g_hLeaderVotes = 0;
int g_hPlayerReady = 0;

ConVar g_Cvar_LockSkill;
ConVar g_Cvar_ServerCfgFix;
ConVar g_Cvar_ImmunityLvl;
ConVar g_Cvar_LeaderLvl;

bool g_bLockSkill = false;
bool g_bServerCfgFix = false;
int g_iImmunityLvl = 0;
int g_iLeaderLvl = 0;
bool g_bIgnoreLeaderBlock = false;

ConVar g_Cvar_AswSkill;
ConVar g_Cvar_MmState;
int g_iMmState = 0;

int g_iEntGameRules;

public Plugin myinfo = {
	name = "Alien Swarm Tools",
	author = "KawMAN",
	description = "Usefull tools for Alien Swarm",
	version = PLUGIN_VERSION,
	url = "http://kawman.tk/SourceMOD"
};

public void OnPluginStart()
{
	//Only for Alien Swarm
	char gamedir[PLATFORM_MAX_PATH];
	GetGameFolderName(gamedir, sizeof(gamedir));
	if (strcmp(gamedir, "swarm") != 0 && strcmp(gamedir, "reactivedrop") != 0)
		SetFailState("This plugin is only supported on Alien Swarm");
	
	//Offset
	g_hLeaderVotes = FindSendPropInfo("CASW_Game_Resource", "m_iLeaderVotes");
	g_hPlayerReady = FindSendPropInfo("CASW_Game_Resource", "m_bPlayerReady");
	if (g_hLeaderVotes <= 0 || g_hPlayerReady <= 0)
		SetFailState("* FATAL ERROR: Failed to get some offset");

	//g_iEntGameRules = _FindEntityByClassname(-1, "asw_game_resource");
	g_iEntGameRules = FindEntityByClassname(-1, "asw_game_resource");

	//Load Languages
	LoadTranslations("common.phrases");
	
	//Commands
	RegAdminCmd("sm_setleader", cmdSetLeader, ADMFLAG_GENERIC, "Set Lobby Leader");
	RegAdminCmd("sm_setready", cmdSetReady, ADMFLAG_GENERIC, "Set player Ready state");
	
	//Cvars
	g_Cvar_LockSkill = CreateConVar("sm_lock_difficulty", "0", "Lock difficulty (skill) on state, 0=Off 1-5=Lock on this state", 0, true, 0.0, true, 4.0);
	g_Cvar_ServerCfgFix = CreateConVar("sm_servercfg_fix", "0", "Execute server.cfg every map start", 0, true, 0.0, true, 1.0);
	g_Cvar_ImmunityLvl = CreateConVar("sm_as_kick_immunity", "10", "Block possibility to kick players with >= immunty lvl, 0=off");
	g_Cvar_LeaderLvl = CreateConVar("sm_disable_leadervote", "-1", "-1 -Enable Leader Vote, 0 -Diable Leader Vote, >0 -Disable if leader have immunity equal or higer than this");
	CreateConVar("sm_astools", PLUGIN_VERSION, "Alien Swarm tools version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	AutoExecConfig(true, "alienswarm_tools");
	
	g_Cvar_AswSkill = FindConVar("asw_skill");
	g_Cvar_MmState = FindConVar("mm_swarm_state");
	
	//Commands hook
	AddCommandListener(cmdClSkill, "cl_skill");
	AddCommandListener(cmdClKick, "cl_kickvote");
	AddCommandListener(cmdClLeader, "cl_leadervote");
	
	//Hooks
	g_Cvar_LockSkill.AddChangeHook(MyCVARChange);
	g_Cvar_AswSkill.AddChangeHook(MyCVARChange);
	g_Cvar_MmState.AddChangeHook(MyCVARChange);
	g_Cvar_ServerCfgFix.AddChangeHook(MyCVARChange);
	g_Cvar_ImmunityLvl.AddChangeHook(MyCVARChange);
	g_Cvar_LeaderLvl.AddChangeHook(MyCVARChange);
	
	UpdateState();
}

public void MyCVARChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int oldVal = StringToInt(oldValue);
	int newVal = StringToInt(newValue);
	if (convar == g_Cvar_LockSkill)
	{
		if (oldVal != newVal)
		{
			if (newVal >= 0 && newVal <= 5)
			{
				SetupSkill(newVal);
			}
			else
			{
				convar.SetString(oldValue);
			}
		}
	}
	else if (convar == g_Cvar_AswSkill)
	{
		if (g_bLockSkill)
		{
			g_bLockSkill = false;
			g_Cvar_AswSkill.SetString(newValue);
			g_bLockSkill = true;
		}
	}
	else if (convar == g_Cvar_MmState)
	{
		if (newValue[0] == 'i')
		{
			//ingame
			g_iMmState = 0;
		}
		else if (newValue[0] == 'b')
		{
			//birefing
			g_iMmState = 1;
		}
	}
	else if (convar == g_Cvar_ServerCfgFix)
	{
		g_bServerCfgFix = g_Cvar_ServerCfgFix.BoolValue;
	}
	else if (convar == g_Cvar_ImmunityLvl)
	{
		g_iImmunityLvl = g_Cvar_ImmunityLvl.IntValue;
	}
	else if (convar == g_Cvar_LeaderLvl)
	{
		g_iLeaderLvl = g_Cvar_LeaderLvl.IntValue;
	}
}

public void OnMapStart()
{
	//g_iEntGameRules = _FindEntityByClassname(MaxClients+1, "asw_game_resource");
	g_iEntGameRules = FindEntityByClassname(MaxClients+1, "asw_game_resource");
	
	if (g_bServerCfgFix)
		ServerCommand("exec server.cfg");
}

//------------------------------------ COMMANDS ---------------------------------------//
public Action cmdSetReady(int client, int args)
{
	if (g_iMmState != 1)
	{
		ReplyToCommand(client, "Command available only when briefing or debriefing");
		return Plugin_Handled;
	}
	if (args == 0)
	{
		//Simple switch 
		if (client == 0)
		{
			ReplyToCommand(client, "Wrong Server Console syntax. sm_setready <1|0> <#userid|name|partname>");
			return Plugin_Handled;
		}
		//FakeClientCommand(client, "cl_ready");
		ClientCommand(client, "cl_ready");
	}
	else if (args >= 1 )
	{
		char StrArg[64];
		int tostate;
		GetCmdArg(1, StrArg, sizeof(StrArg));
		
		if (StrArg[0] == '1')
		{
			tostate = 1;
		}
		else if (StrArg[0] == '0')
		{
			tostate = 0;
		}
		else if (StrArg[0] == '-')
		{
			tostate = -1;
		}
		else
		{
			ReplyToCommand(client,"Wrong syntax. sm_setready [-|1|0] [#userid|name|partname]");
			return Plugin_Handled;
		}
		
		if (args == 1)
		{
			SetClientReady(client, tostate);
			return Plugin_Handled;
		}
		
		GetCmdArg(2, StrArg, sizeof(StrArg));
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		
		if ((target_count = ProcessTargetString(
				StrArg,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_CONNECTED,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		
		for (int i = 0; i < target_count; i++)
		{
			SetClientReady(target_list[i], tostate);
		}
	}
	
	return Plugin_Handled;
}

public Action cmdSetLeader(int client, int args)
{
	if (args < 0 || args > 1)
	{
		ReplyToCommand(client,"sm_setleader [#userid|name|partname]");
		return Plugin_Handled;
	}

	int val;
	if (args == 1)
	{
		char arg[65];
		GetCmdArg(1, arg, sizeof(arg));

		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		
		target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml);
		
		if (target_count!=1) {
			ReplyToCommand(client,"None or more than one match");
			return Plugin_Handled;
		}
		
		val = MakeLeader(target_list[0]);

	} 
	else if (args == 0)
	{
		val = MakeLeader(client);
	}
	
	if (val == -1)
	{
		ReplyToCommand(client, "Can't find required enitity");
	}
	else if (val == 0)
	{
		ReplyToCommand(client, "Selected player is already leader");
	}
	
	return Plugin_Handled;
}



public Action cmdClSkill(int client, const char[] command, int argc)
{
	if (g_bLockSkill)
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action cmdClKick(int client, const char[] command, int argc)
{
	if (g_iImmunityLvl <= 0)
		return Plugin_Continue;
	
	char StrArg[64];
	GetCmdArg(1, StrArg, sizeof(StrArg));
	StripQuotes(StrArg);
	int newVal = StringToInt(StrArg);
	if (newVal <= 0 || !IsClientConnected(newVal))
		return Plugin_Continue;
	//cl_kickvote -1 = unselect
	AdminId targetadm = GetUserAdmin(newVal);
	newVal = GetAdminImmunityLevel(targetadm);
	if (newVal >= g_iImmunityLvl)
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action cmdClLeader(int client, const char[] command, int argc)
{
	if (g_bIgnoreLeaderBlock)
		return Plugin_Continue;

	if (g_iLeaderLvl == 0 )
		return Plugin_Handled;

	int leader = GetEntProp(g_iEntGameRules, Prop_Send, "m_iLeaderIndex");
	if (leader != 0 && IsClientConnected(leader) && g_iLeaderLvl > 0)
	{
		AdminId targetadm = GetUserAdmin(leader);
		if (targetadm != INVALID_ADMIN_ID)
		{ 
			int newVal = GetAdminImmunityLevel(targetadm);
			if (newVal >= g_iLeaderLvl)
				return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

//------------------------------------ FUNCTIONS ---------------------------------------//
/*PrintReadyList()
{
	int ready;
	if (g_iEntGameRules == -1)
		return -2;

	for (int i = 0; i <= 7; i++)
	{
		ready = GetEntData(g_iEntGameRules, g_hPlayerReady + i,1);
		PrintToServer("READY for %d %d", i, ready);
	}
	return 1;
}
*/
int SetClientReady(int client, int tostate = -1)
{
	//g_hPlayerReady = CASW_Game_Resource::m_bPlayerReady
	if (g_iEntGameRules == -1)
		return -2;
	
	int ready = GetEntData(g_iEntGameRules, g_hPlayerReady + (client-1), 1);
	if (tostate == -1)
	{
		if (ready != 1)
		{
			SetEntData(g_iEntGameRules, g_hPlayerReady + (client-1), 1, 1, true);
			return 1;
		}
		else
		{
			SetEntData(g_iEntGameRules, g_hPlayerReady + (client-1), 0, 1, true);
			return 0;
		}
	}
	else if (tostate == 1 && ready == 0)
	{
		SetEntData(g_iEntGameRules, g_hPlayerReady + (client-1), 1, 1, true);
		return 1;
	}
	else if (tostate == 0 && ready == 1)
	{
		SetEntData(g_iEntGameRules, g_hPlayerReady + (client-1), 0, 1, true);
		return 0;
	}
	return -1;
}

void SetupSkill(int mystate = 0)
{
	//0 = Unlock, 1-5 = lock on state

	if (mystate < 0) mystate = 0;
	if (mystate > 5) mystate = 5;
	
	if (mystate == 0)
	{
		g_bLockSkill = false;
	}
	else
	{
		g_Cvar_AswSkill.IntValue = mystate;
		g_bLockSkill = true;
	}
}

int MakeLeader(int client)
{
	if (g_iEntGameRules == -1)
		return -1;
	
	if (client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return 0;
	
	int val = GetEntProp(g_iEntGameRules, Prop_Send, "m_iLeaderIndex");
	if (val == client)
		return 0;
	
	val = 0;
	for (int i = 1 ; i <= MaxClients; i++)
	{
		if (client == i)
			continue;
		if (!IsClientInGame(i))
			continue;
		if (IsFakeClient(i))
			continue;

		SetEntProp(i, Prop_Send, "m_iLeaderVoteIndex", client);
		val++;
	}
	//Slien Votes
	SetEntData(g_iEntGameRules, g_hLeaderVotes + ((client - 1) * 4), val, _, true);
	
	//Last Vote must be 'Noise'
	g_bIgnoreLeaderBlock = true;
	//FakeClientCommand(client, "cl_leadervote %i", client);
	ClientCommand(client, "cl_leadervote %i", client);
	g_bIgnoreLeaderBlock = false;
	
	SetEntProp(g_iEntGameRules, Prop_Send, "m_iLeaderIndex", client);
	return 1;
}

void UpdateState()
{
	char StrArg[64];
	int newVal = g_Cvar_LockSkill.IntValue;
	SetupSkill(newVal);
	
	GetConVarString(g_Cvar_MmState,StrArg, sizeof(StrArg));
	if (StrArg[0] == 'i')
	{
		//ingame
		g_iMmState = 0;
	}
	else if (StrArg[0] == 'b')
	{
		//briefing
		g_iMmState = 1;
	}

	g_bServerCfgFix = g_Cvar_ServerCfgFix.BoolValue;
	g_iImmunityLvl = g_Cvar_ImmunityLvl.IntValue;
	g_iLeaderLvl = g_Cvar_LeaderLvl.IntValue;
}
/*
//SourceMOD funciton not working, yet
int _FindEntityByClassname(startEnt=0, char[] classname2, bool caseSens=true) {
	char classname[64];
	int t = GetMaxEntities();
	for (int i = startEnt; i <= t;i++)
	{
		if (!IsValidEdict(i))
			continue;
		GetEdictClassname(i, classname, sizeof(classname));
		if (StrEqual(classname,classname2, caseSens))
			return i;
	}
	return -1;
}
*/