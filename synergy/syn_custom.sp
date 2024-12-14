#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

//#define MAPLENGTH 64
//#define RESETEMPTY
//#define CLEANSPAWN

public Plugin myinfo = 
{
	name = "Synergy Custom",
	author = "Duko",
	description = "Synergy Custom",
	version = "1.1",
	url = "http://group.midu.cz"
};

//bool g_bIsVehicleMap = false;
int g_iCount;
//ArrayList g_Maplist = null;
//int g_Maplist_Serial = -1;
ConVar g_Cvar_FallDamage;
ConVar g_Cvar_InfiniteAuxPower;
//ConVar g_Cvar_SaveDisable;
ConVar g_Cvar_ItemRespawnTime;
ConVar g_Cvar_SkBattery;
ConVar g_Cvar_SkHealthkit;
//ConVar g_Cvar_VehicleMap;
ConVar g_Cvar_NextLevel;
//new Handle:g_SkHealthvial = INVALID_HANDLE
//new Handle:g_Itemlist = INVALID_HANDLE
//new Handle:g_ItemTrie = INVALID_HANDLE
//new bool:g_bInKickVote = false
bool g_bFirstVote = false;
int g_iTypeVote = 0;
bool g_bMapLoaded = false;
int g_iCollisionGroup;
//bool g_bInvisAlyxFix = false;
char g_szSteamAuthId[MAXPLAYERS+1][32];
char g_szServerIP[24];

#if defined CLEANSPAWN
char fakemodel[PLATFORM_MAX_PATH] = "models/props_junk/popcan01a.mdl";
#endif

public void OnPluginStart()
{
/*	g_Maplist = new ArrayList(ByteCountToCells(MAPLENGTH));

	char mapListPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapListPath, sizeof(mapListPath), "configs/novehicle_maps.txt");
	SetMapListCompatBind("novehiclemaps", mapListPath);

	LoadMapList();*/
	
	GetServerIp(g_szServerIP, sizeof(g_szServerIP));
	
//	RegConsoleCmd("sm_fix", Command_Fix, "Fix invisible npc");
	
	AddCommandListener(Cmd_VoteStart, "vote_start");

	g_Cvar_FallDamage = FindConVar("mp_falldamage");
	if (g_Cvar_FallDamage == null)
	{
		LogMessage("[SYNCUS] Unable to find cvar mp_falldamage");
	}

	g_Cvar_InfiniteAuxPower = FindConVar("sv_infinite_aux_power");
	if (g_Cvar_InfiniteAuxPower == null)
	{
		LogMessage("[SYNCUS] Unable to find cvar sv_infinite_aux_power");
	}
/*
	g_Cvar_SaveDisable = FindConVar("mp_save_disable");
	if (g_Cvar_SaveDisable == null)
	{
		LogMessage("[SYNCUS] Unable to find cvar mp_save_disable");
	}
*/
	g_Cvar_ItemRespawnTime = FindConVar("sv_hl2mp_item_respawn_time");
	g_Cvar_SkBattery = FindConVar("sk_battery");
	g_Cvar_SkHealthkit = FindConVar("sk_healthkit");
//	g_SkHealthvial = FindConVar("sk_healthvial");

//	g_Cvar_VehicleMap = FindConVar("sm_vehicle_map");
	g_Cvar_NextLevel = FindConVar("nextlevel");
	
	g_iCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");

	HookEventEx("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
	HookEventEx("vote_start", Event_VoteStart, EventHookMode_Post);
	HookEventEx("vote_cast", Event_VoteCast, EventHookMode_Post);
//	HookEventEx("vote_end", Event_VoteEnd, EventHookMode_Post);
//	HookEventEx("player_info", Event_PlayerInfo, EventHookMode_Post);
//	HookEventEx("player_changename", Event_PlayerChangeName, EventHookMode_Post);
	HookEventEx("intermission_time", Event_GameEnd, EventHookMode_Post);

/*	g_Itemlist = CreateArray(32);
	PushArrayString(g_Itemlist, "item_ammo_357");
	PushArrayString(g_Itemlist, "item_ammo_357_large");
	PushArrayString(g_Itemlist, "item_ammo_ar2");
	PushArrayString(g_Itemlist, "item_ammo_ar2_large");
	PushArrayString(g_Itemlist, "item_ammo_crossbow");
	PushArrayString(g_Itemlist, "item_ammo_pistol");
	PushArrayString(g_Itemlist, "item_ammo_pistol_large");
	PushArrayString(g_Itemlist, "item_ammo_smg1");
	PushArrayString(g_Itemlist, "item_ammo_smg1_large");
	PushArrayString(g_Itemlist, "item_battery");
	PushArrayString(g_Itemlist, "item_box_buckshot");
	PushArrayString(g_Itemlist, "item_healthkit");
	PushArrayString(g_Itemlist, "item_healthvial");*/

/*	g_ItemTrie = CreateTrie();
	SetTrieValue(g_ItemTrie, "item_ammo_357_large", 20.0);
	SetTrieValue(g_ItemTrie, "item_ammo_crossbow", 6.0);
	SetTrieValue(g_ItemTrie, "item_ammo_smg1", 45.0);
	SetTrieValue(g_ItemTrie, "item_box_buckshot", 20.0);*/

	HookEntityOutput("item_ammo_357_large", "OnPlayerTouch", PlayerTouchOutputHook);
	HookEntityOutput("item_ammo_357", "OnPlayerTouch", PlayerTouchOutputHook);
//	HookEntityOutput("item_ammo_ar2", "OnPlayerTouch", PlayerTouchOutputHook);
	HookEntityOutput("item_ammo_crossbow", "OnPlayerTouch", PlayerTouchOutputHook);
	HookEntityOutput("item_ammo_pistol", "OnPlayerTouch", PlayerTouchOutputHook);
	HookEntityOutput("item_ammo_smg1", "OnPlayerTouch", PlayerTouchOutputHook);
	HookEntityOutput("item_battery", "OnPlayerTouch", PlayerTouchOutputHook);
	HookEntityOutput("item_box_buckshot", "OnPlayerTouch", PlayerTouchOutputHook);
	HookEntityOutput("item_healthkit", "OnPlayerTouch", PlayerTouchOutputHook);
//	HookEntityOutput("item_healthvial", "OnPlayerTouch", PlayerTouchOutputHook);

	HookEntityOutput("item_ammo_drop", "OnPlayerTouch", PlayerTouchItemDrop);
//	HookEntityOutput("item_ammo_pack", "OnPlayerTouch", PlayerTouchItemDrop);
	HookEntityOutput("item_health_drop", "OnPlayerTouch", PlayerTouchItemDrop);

//	HookEntityOutput("info_vehicle_spawn", "OnSpawnVehicle", SpawnVehicleOutputHook);
	HookEntityOutput("npc_turret_floor", "OnPhysGunPickup", OnPhysGunOutputHook);
	HookEntityOutput("npc_turret_floor", "OnPhysGunDrop", OnPhysGunOutputHook);
	
	LoadTranslations("basetriggers.phrases");
}
/*
public Action Command_Fix(int client, int args)
{
//	ClientCommand(client, "disconnect;wait 100;map syn syn_deadsimple;wait 1000;disconnect;wait 100;connect %s", g_szServerIP);
	ClientCommand(client, "disconnect;wait 100;map hl2 background05;wait 1000;disconnect;wait 100;connect %s", g_szServerIP);
	return Plugin_Handled;
}
*/
public Action Cmd_VoteStart(int client, const char[] command, int argc)
{
	if (client == 0)
		return Plugin_Continue;

	if (argc < 1)
		return Plugin_Continue;
		
	char arg[8];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (!StrEqual(arg, "kick", false))
		return Plugin_Continue;

	//PrintToConsole(client, "vote_start kick");
	ClientCommand(client, "playgamesound vo/citadel/br_no.wav");

	return Plugin_Stop;
}

/*
public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client > 0)
	{
		char reason[64];
		event.GetString("reason", reason, sizeof(reason));
		PrintToChatAll("Player %N has left the game (%s)", client, reason);

//		int index = -1;
//		while ((index = FindEntityByClassname(index, "npc_grenade_frag")) != -1)
//		{
//			int owner = GetEntPropEnt(index, Prop_Data, "m_hOwnerEntity");
//			if (owner == -1 || owner == client)
//			{
//				AcceptEntityInput(index, "Kill");
				//PrintToServer("[SYNCUS] Kill frag: %N - owner %d", client, owner);
//				LogMessage("[SYNCUS] Kill frag: %N - owner %d", client, owner);
//			}
//		}
	}
}*/

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0)
		return;

/*	if (!IsClientConnected(client) || !IsClientInGame(client))
		return;*/

	if (!IsFakeClient(client))
		g_szSteamAuthId[client][0] = '\0';
/*
	char szReason[128];
	event.GetString("reason", szReason, sizeof(szReason));
	
//	LogMessage("Dropped %N from server (%s).", client, szReason);
	
	if (strncmp(szReason, "Additional Requirements:", 24) != 0)
		return;
	
	ReplaceString(szReason, sizeof(szReason), "\n", ", ");
	PrintToChatAll("Dropped %N from server (%s).", client, szReason);*/
}
/*
public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	LogMessage("Dropped %N from server (%s)", client, rejectmsg);

	if (strncmp(rejectmsg, "Disconnect: Additional Requirements:", 36) == 0)
	{
		char szReason[128];
		strcopy(szReason, sizeof(szReason), rejectmsg);
		ReplaceString(szReason, sizeof(szReason), "\r\n", ", ");
		PrintToChatAll("Dropped %N from server (Additional Requirements: %s)", client, szReason[36]);
	}

	return true;
}
*/
public void Event_GameEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Cvar_NextLevel == null)
		return;

	char map[PLATFORM_MAX_PATH];
	g_Cvar_NextLevel.GetString(map, sizeof(map));
	
	if (map[0] == '\0')
		return;

	PrintToChatAll("\x04%t", "Next Map", map);
}

public void PlayerTouchOutputHook(const char[] output, int caller, int activator, float delay)
{
	float rtime = g_Cvar_ItemRespawnTime.FloatValue;
	if (rtime > 0.0)
	{
		CreateTimer(rtime + 0.1, Timer_SetValue, EntIndexToEntRef(caller), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_SetValue(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	
	if (entity == INVALID_ENT_REFERENCE)
		return Plugin_Stop;

	if (!IsValidEntity(entity))
		return Plugin_Stop;

/*	char classname[32];
	GetEdictClassname(entity, classname, sizeof(classname));

	if (FindStringInArray(g_Itemlist, classname) == -1)
		return Plugin_Stop;

	float flValue = GetEntPropFloat(entity, Prop_Data, "m_flValue");

	if (flValue != 0.0)
		return Plugin_Stop;

	flValue = 20.0

	if (StrEqual(classname, "item_ammo_crossbow"))
	{
		flValue = 6.0;
	}
	else if (StrEqual(classname, "item_ammo_smg1"))
	{
		flValue = 45.0;
	}
	else if (StrEqual(classname, "item_battery"))
	{
		flValue = g_Cvar_SkBattery.FloatValue;
	}*/
/*	else if (StrEqual(classname, "item_ammo_357"))
	{
		flValue = 6.0;
	}*/
	
	float flValue = GetItemMaxValue(entity);

	if (flValue == -1.0)
		return Plugin_Stop;

	if (GetEntPropFloat(entity, Prop_Data, "m_flValue") != 0.0)
		return Plugin_Stop;

	SetEntPropFloat(entity, Prop_Data, "m_flValue", flValue);

	return Plugin_Stop;
}

stock float GetItemMaxValue(int entity)
{
	char classname[32];
	GetEdictClassname(entity, classname, sizeof(classname));

	if (StrEqual(classname, "item_ammo_357_large"))
		return 20.0;
	if (StrEqual(classname, "item_ammo_357"))
		return 6.0;
/*	if (StrEqual(classname, "item_ammo_ar2"))
		return 20.0*/
	if (StrEqual(classname, "item_ammo_crossbow"))
		return 6.0;
	if (StrEqual(classname, "item_ammo_pistol"))
		return 20.0;
	if (StrEqual(classname, "item_ammo_smg1"))
		return 45.0;
	if (StrEqual(classname, "item_battery"))
		return g_Cvar_SkBattery.FloatValue;
	if (StrEqual(classname, "item_box_buckshot"))
		return 20.0;
	if (StrEqual(classname, "item_healthkit"))
		return g_Cvar_SkHealthkit.FloatValue;
/*	if (StrEqual(classname, "item_healthvial"))
		return GetConVarFloat(g_SkHealthvial);*/

//	GetTrieValue(g_ItemTrie, classname, value);

	return -1.0;
}

public void PlayerTouchItemDrop(const char[] output, int caller, int activator, float delay)
{
	AcceptEntityInput(caller, "Kill");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (g_bMapLoaded && StrEqual(classname, "item_battery"))
	{
		CreateTimer(0.1, Timer_BatteryDrop, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
		return;
	}
/*	
	if (g_bInvisAlyxFix && StrEqual(classname, "npc_alyx"))
		InvisibleAlyxFix(entity);*/
}
/*
public void OnEntityDestroyed(int entity)
{
	if (StrEqual(classname, "npc_vortigaunt"))
	
}
*/
public Action Timer_BatteryDrop(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	
	if (entity == INVALID_ENT_REFERENCE)
		return Plugin_Stop;

	if (!IsValidEntity(entity))
		return Plugin_Stop;

	if (GetEntPropFloat(entity, Prop_Data, "m_flValue") > 0.0)
		HookSingleEntityOutput(entity, "OnPlayerTouch", PlayerTouchItemDrop, true);

	return Plugin_Stop;
}

public void Event_VoteStart(Event event, const char[] name, bool dontBroadcast)
{
	int type = event.GetInt("type");

	if (type == 1)
	{
		//char token[32];
		char option[32];
		//event.GetString("token", token, sizeof(token));
		event.GetString("option", option, sizeof(option));
		//PrintToChatAll("[SYNCUS] type: %d, token: %s, option: %s", type, token, option);
		// 1 changelevel, 2 kick, 3 restore save, 4 skill
		
		PrintToTopLeftAll("Change to %s?", option);
		PrintToConsoleAll("[SYNCUS] Change to %s?", option);
	}

/*	if (type == 2)
	{
		g_bInKickVote = true;

		char token[32];
		char option[32];
		event.GetString("token", token, sizeof(token));
		event.GetString("option", option, sizeof(option));
		PrintToConsoleAll("[SYNCUS] Kick, token: %s, option: %s", token, option);
	}
	else
	{
		g_bInKickVote = false;
	}*/
	
	g_bFirstVote = false;
	g_iTypeVote = type;

	//PrintToConsoleAll("[SYNCUS] type: %d, token: %s, option: %s", type, token, option);
}

public void Event_VoteCast(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("user") + 1;

	if (!client)
		return;

//	new vote = GetEventInt(event, "vote")

	if (!g_bFirstVote)
	{
		char szTypeName[32];
		switch (g_iTypeVote)
		{
			case 1: strcopy(szTypeName, sizeof(szTypeName), "changelevel");
			case 2: strcopy(szTypeName, sizeof(szTypeName), "kick");
			case 3: strcopy(szTypeName, sizeof(szTypeName), "restore save");
			case 4: strcopy(szTypeName, sizeof(szTypeName), "skill");
		}

		//int userid = GetClientUserId(client);
		PrintToConsoleAll("[SYNCUS] Player \"%L\" started '%s' vote.", client, szTypeName);
		LogMessage("[SYNCUS] Player \"%L\" started '%s' vote.", client, szTypeName);
		g_bFirstVote = true;
	}

/*	if (g_iTypeVote == 2)
	{
		g_iAdd[client]++;
		PrintToConsoleAll("[SYNCUS] g_bKIV");
	}*/

//	PrintToConsoleAll("[SYNCUS] user: %i, vote: %i, (first %s)", user, vote, !g_bFirstVote ? "yes" : "no");

}
/*
public Event_VoteEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bInKickVote = false;
	PrintToConsoleAll("[SYNCUS] Vote end");
}
*/
/*
public Event_PlayerInfo(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:plname[32], String:networkid[32];
	GetEventString(event, "name", plname, sizeof(plname)); // player name		
	new index = GetEventInt(event, "index"); // player slot (entity index-1)
	new userid = GetEventInt(event, "userid"); // user ID on server (unique on server)
	GetEventString(event, "networkid", networkid, sizeof(networkid)); // player network (i.e steam) id
	new bool:bot = GetEventBool(event, "bot"); // true if player is a AI bot
	LogMessage("[SYNCUS] plname: %s, index: %i, userid: %i, networkid: %s, bot: %s", plname, index, userid, networkid, bot ? "yes" : "no");
}
*/
/*
public Event_PlayerChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if ( !client || !IsClientConnected(client) || IsClientInKickQueue(client) || IsFakeClient(client) )
		return;

	decl String:oldname[64], String:newname[64];
	GetEventString(event, "oldname", oldname, sizeof(oldname));
	GetEventString(event, "newname", newname, sizeof(newname));

	if (newname[0] == '\0' || IsNameWhiteSpaced(newname))
	{
		SetClientInfo(client, "name", oldname);
		LogMessage("[SYNCUS] Player change name from %s to %s", oldname, newname);
	}
		
//	PrintToConsoleAll("[SYNCUS] %i %N change name from %s to %s", client, client, oldname, newname);
}
*/
/*
public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;

//	char plname[64];
//	bool ret = GetClientName(client, plname, sizeof(plname));
//	if (!ret || plname[0] == '\0' || IsNameWhiteSpaced(plname))
//	{
//		SetClientInfo(client, "name", ".unnamed.");
//		LogMessage("[SYNCUS] Player %s has bad name", plname);
//	}

	char authid[32];
	GetClientAuthId(client, AuthId_Steam3, authid, sizeof(authid));
	if (StrEqual(authid, g_szSteamAuthId[client]))
		return;
	
	strcopy(g_szSteamAuthId[client], sizeof(g_szSteamAuthId[]), authid);
//	ClientCommand(client, "cl_customsounds 1;cl_ejectbrass 1;cl_help_msgs 0;cl_allowdownload 1;cl_allowupload 1;cl_downloadfilter all;echo ]");
	ClientCommand(client, "cl_ejectbrass 1;echo ]");
}
*/
/*
public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;

	g_szSteamAuthId[client][0] = '\0';
}
*/
/*
public SpawnVehicleOutputHook(const String:name[], caller, activator, Float:delay)
{
	CreateTimer(0.1, Timer_ResetVehicle, EntIndexToEntRef(caller), TIMER_FLAG_NO_MAPCHANGE);
}

public Action: Timer_ResetVehicle(Handle:timer, any:ref)
{
	new entity = EntRefToEntIndex(ref);
	
	if (entity == INVALID_ENT_REFERENCE)
		return Plugin_Stop;

	if (!IsValidEntity(entity))
		return Plugin_Stop;

	AcceptEntityInput(entity, "ResetEmpty");

	decl String:classname[32]
	GetEdictClassname(entity, classname, sizeof(classname));
	PrintToConsoleAll("[SYNCUS] ResetEmpty %s", classname);
	LogMessage("[SYNCUS] ResetEmpty %s", classname);

	return Plugin_Stop;
}
*/

public void OnPhysGunOutputHook(const char[] output, int caller, int activator, float delay)
{
	if (!IsValidEntity(caller))
		return;
		
	if (GetEntProp(caller, Prop_Data, "m_spawnflags") & 512 != 0)
		return;

	if (StrEqual(output, "OnPhysGunPickup"))
		AcceptEntityInput(caller, "Disable");
	else 
		AcceptEntityInput(caller, "Enable");
}

public void OnMapStart()
{
#if defined CLEANSPAWN
	if (!IsModelPrecached(fakemodel))
	{
		PrecacheModel(fakemodel, true);
	}
#endif
}

public void OnConfigsExecuted()
{
	g_bMapLoaded = true;
	//m_exectimer = CreateTimer(5.0, ExecTimer);
//	CreateTimer(5.0, ExecTimer, _, TIMER_FLAG_NO_MAPCHANGE);

	char currentMap[64];
	GetCurrentMap(currentMap, sizeof(currentMap));

#if defined CLEANSPAWN
	int index = -1;
	while ((index = FindEntityByClassname(index, "info_player_coop")) != -1)
	{
		float origin[3];
		GetEntPropVector(index, Prop_Data, "m_vecOrigin", origin);
		int ent = CreateEntityByName("trigger_push");
		if (ent != -1)
		{
			DispatchKeyValueVector(ent, "origin", origin);
			DispatchKeyValue(ent, "model", fakemodel);
			DispatchKeyValue(ent, "spawnflags", "8");
			//DispatchKeyValue(ent, "spawnflags", "1032");
			DispatchKeyValue(ent, "pushdir", "270 0 0");
			DispatchKeyValue(ent, "speed", "1000");
			DispatchSpawn(ent);
			ActivateEntity(ent);

			float minbounds[3] = {-10.0, -10.0, -10.0};
			float maxbounds[3] = {10.0, 10.0, 10.0};
			SetEntPropVector(ent, Prop_Send, "m_vecMins", minbounds);
			SetEntPropVector(ent, Prop_Send, "m_vecMaxs", maxbounds);

			DispatchKeyValue(ent, "solid", "2");
			DispatchKeyValue(ent, "effects", "32");
		}
	}
#endif
//	g_bIsVehicleMap = false;
#if defined RESETEMPTY
	int index = -1;
	while ((index = FindEntityByClassname(index, "info_vehicle_spawn")) != -1)
	{
		DispatchKeyValue(index, "OnSpawnVehicle", "!self,ResetEmpty,,0.1,1");

/*		if (!g_bIsVehicleMap)
			g_bIsVehicleMap = true;*/
	}
#else
/*	if (FindEntityByClassname(-1, "info_vehicle_spawn") != -1)
	{
		if (!g_bIsVehicleMap)
			g_bIsVehicleMap = true;
	}*/
	// replace 2 seat buggy to 1 seat
	int index = -1;
	char model[32];
	while ((index = FindEntityByClassname(index, "info_vehicle_spawn")) != -1)
	{
	//	if (!g_bIsVehicleMap)
	//		g_bIsVehicleMap = true;

		GetEntPropString(index, Prop_Data, "m_ModelName", model, sizeof(model));
		PrintToServer("[SYNCUS] info_vehicle_spawn model: %s", model);

		//ReplaceString(model, sizeof(model), "\\", "/");
	//	if (!StrEqual(model, "models/vehicles/buggy_p2.mdl"))
		if (!StrEqual(model, "models\\vehicles\\buggy_p2.mdl") && !StrEqual(model, "models/vehicles/buggy_p2.mdl"))
			continue;
		
		PrintToServer("[SYNCUS] info_vehicle_spawn replaced");

		DispatchKeyValue(index, "RespawnVehicle", "1");
		DispatchKeyValue(index, "Ownership", "1");
		DispatchKeyValue(index, "model", "models/buggy.mdl");
		DispatchKeyValue(index, "VehicleType", "1");
	}
#endif

/*	if (!g_bIsVehicleMap && IsVehicleOnMap())
	{
		g_bIsVehicleMap = true;
	}*/
	
/*	if (g_Cvar_VehicleMap != null)
		g_bIsVehicleMap = g_Cvar_VehicleMap.BoolValue;
	else
	{
		g_Cvar_VehicleMap = FindConVar("sm_vehicle_map");
		if (g_Cvar_VehicleMap != null)
			g_bIsVehicleMap = g_Cvar_VehicleMap.BoolValue;
	}*/

/*	if (NoVehicleMap(currentMap))
		g_bIsVehicleMap = false;*/

	char edtFile[64];
	Format(edtFile, sizeof(edtFile), "maps/%s.edt", currentMap);
	bool bFallDamageChanged = false, bInfiniteAuxPowerChanged = false;

	if (FileExists(edtFile, true))
	{
		KeyValues kv = new KeyValues("edtfile");
		if (kv.ImportFromFile(edtFile))
		{
			kv.JumpToKey("console", false);
			int falldamage = kv.GetNum("mp_falldamage", -10);
			int infiniteaux = kv.GetNum("sv_infinite_aux_power", -10);
			delete kv;

			if (g_Cvar_FallDamage != null && falldamage != -10)
			{
				g_Cvar_FallDamage.IntValue = falldamage;
				bFallDamageChanged = true;
				PrintToServer("[SYNCUS] mp_falldamage changed to %i.", falldamage);
			}

			if (g_Cvar_InfiniteAuxPower != null && infiniteaux != -10)
			{
				g_Cvar_InfiniteAuxPower.IntValue = infiniteaux;
				bInfiniteAuxPowerChanged = true;
				PrintToServer("[SYNCUS] sv_infinite_aux_power changed to %i.", infiniteaux);
			}
		}
	}

	if (!bFallDamageChanged && g_Cvar_FallDamage.IntValue != 1)
	{
		g_Cvar_FallDamage.IntValue = 1;
	}

	if (!bInfiniteAuxPowerChanged && g_Cvar_InfiniteAuxPower.IntValue != 0)
	{
		g_Cvar_InfiniteAuxPower.IntValue = 0;
	}

/*	g_iCount = 0

	if (StrEqual(currentMap, "d1_trainstation_01", false) || StrEqual(currentMap, "ep2_outland_11b", false))
	{
		CreateTimer(2.0, AutoSave_Game, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE)
		g_iCount += 5
	}
	else if (!StrEqual(currentMap, "d3_citadel_02", false) && !StrEqual(currentMap, "d3_breen_01", false))
		CreateTimer(4.0, AutoSave_Game, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE)*/
	

//	if (g_Cvar_SaveDisable.IntValue != 0 && strncmp(currentMap, "syn", 3) == 0)
/*	if (g_Cvar_SaveDisable.IntValue != 0 && FindEntityByClassname(-1, "player_loadsaved") != -1)
		g_Cvar_SaveDisable.IntValue = 0;*/

	// Ivisible Alyx fix
/*	g_bInvisAlyxFix = false;
	
	if (strncmp(currentMap, "ep1_citadel_", 12) == 0 || strncmp(currentMap, "ep1_c17_", 8) == 0 || strncmp(currentMap, "ep2_outland_", 12) == 0)
	{
		InvisibleAlyxFix();
		g_bInvisAlyxFix = true;
	}*/
}
/*
public Action ExecTimer(Handle timer)
{
	if (FindConVar("sm_cvote_version") != null)
	{
		char szNewFile[PLATFORM_MAX_PATH], szOldFile[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, szNewFile, sizeof(szNewFile), "configs/customvotes/disabled/car.vote.cfg");
		BuildPath(Path_SM, szOldFile, sizeof(szOldFile), "configs/customvotes/car.vote.cfg");

		if (g_bIsVehicleMap)
		{
			if (FileExists(szNewFile))
			{
				RenameFile(szOldFile, szNewFile);
				ServerCommand("sm_cvote_reload");
			}

		//	PrintToServer("[SYNCUS] Is Vehicle Map");
		}
		else
		{
			if (FileExists(szOldFile))
			{
				RenameFile(szNewFile, szOldFile);
				//ServerCommand("sm plugins reload customvotes");
				ServerCommand("sm_cvote_reload");
			}
		}
	}
}
*/
public Action AutoSave_Game(Handle timer)
{
	g_iCount++;

	if (g_iCount == 10 || AllClientsInGame())
	{
		ServerCommand("sm_syn_save");
		KillTimer(timer);
	}
	
	return Plugin_Continue;
}

public void OnMapEnd()
{
	g_bMapLoaded = false;
}

stock void InvisibleAlyxFix(int index = -1)
{
	if (g_iCollisionGroup == -1)
		return;

	if (index == -1)
		index = FindEntityByClassname(-1, "npc_alyx");

	if (index == -1 || !IsValidEdict(index))
		return;

	int block = GetEntData(index, g_iCollisionGroup, 4);
	PrintToServer("[SYNCUS] npc_alyx block: %i", block);
	
	if (block == 5)
		return;
	
	SetEntData(index, g_iCollisionGroup, 5, 4, true);
	
	PrintToServer("[SYNCUS] set no collision on npc_alyx, block was: %i", block);
}

stock bool IsNameWhiteSpaced(const char[] name)
{
	int len = strlen(name);
	if (!len)
		return false;

	int count = 0;
	for (int i = 0; i <= len; i++)
	{
		if (IsCharSpace(name[i]))
			count++;
	}

	if (len == count)
		return true;

	return false;
}

stock bool IsVehicleOnMap()
{
	if (FindEntityByClassname(-1, "prop_vehicle_jeep*") != -1)
		return true;

	if (FindEntityByClassname(-1, "prop_vehicle_mp") != -1)
		return true;

	if (FindEntityByClassname(-1, "prop_vehicle_airboat") != -1)
		return true;
	
	return false;
}

stock bool AllClientsInGame()
{
	int connected = 0, ingame = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
	//	if (IsFakeClient(i))
	//		continue
		if (IsClientConnected(i))
			connected++;
		if (IsClientInGame(i))
			ingame++;
	}

	//new connected = GetClientCount(false);
	//new ingame = GetClientCount(true);

//	if (connected == 0)
//		return false;

	if (connected == ingame)
		return true;

	return false;
}
/*
//#if !defined PrintToConsoleAll
stock void PrintToConsoleAll(const char[] format, any ...)
{
	char buffer[254];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintToConsole(i, buffer);
		}
	}
}
//#endif
*/
stock void PrintToTopLeftAll(const char[] format, any ...)
{
	char buffer[192];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

	//	SetGlobalTransTarget(i)
		VFormat(buffer, sizeof(buffer), format, 2);
		SendDialogToOne(i, buffer);
	}
}

stock void SendDialogToOne(int client, const char[] message)
{
	KeyValues kv = new KeyValues("Stuff", "title", message);
	kv.SetColor("color", 255, 255, 255, 255);
	kv.SetNum("level", 1);
	kv.SetNum("time", 30);
	
	CreateDialog(client, kv, DialogType_Msg);
	
	delete kv;
}

stock void GetServerIp(char[] ip, int size)
{
	int pieces[4];
	int longip = FindConVar("hostip").IntValue;

	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;

	char port[8];
	FindConVar("hostport").GetString(port, sizeof(port));

	Format(ip, size, "%i.%i.%i.%i:%s", pieces[0], pieces[1], pieces[2], pieces[3], port);   
}  

/*
void LoadMapList()
{
	if (ReadMapList(g_Maplist,
	g_Maplist_Serial,
	"novehiclemaps",
	MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_NO_DEFAULT)
	!= null)
	{
		LogMessage("Loaded/Updated no vehicle map list");
	}
}

stock bool NoVehicleMap(const char[] mapname)
{
	int mapIndex = g_Maplist.FindString(mapname);
	return (mapIndex > -1);
}
*/
