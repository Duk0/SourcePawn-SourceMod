#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <swarmtools>

public Plugin myinfo = 
{
	name = "[ASW] Respawn",
	author = "Duko",
	description = "[ASW] Respawn",
	version = "1.1",
	url = "http://group.midu.cz"
};

ConVar g_Cvar_RespawnWaitTime;
ConVar g_Cvar_MarineServerRagdoll;
ConVar g_Cvar_AllowWaitCommand;

int g_marinecharacter[MAXPLAYERS+1] = {0, ...};
int g_playerResource[8] = {0, ...};
int g_playerCommander[8] = {0, ...};
bool g_bMissionStarted = false;
bool g_bMarineSpawned[MAXPLAYERS+1] = {false, ...};
float g_respawnlastused[MAXPLAYERS+1] = {0.0, ...};

public void OnPluginStart()
{
	RegConsoleCmd("sm_respawn", Command_Respawn);
	g_Cvar_RespawnWaitTime = CreateConVar("sm_respawn_delay", "25", "Time to wait until Player can use respawn again.", 0, true, 1.0, true, 120.0);
	g_Cvar_MarineServerRagdoll = FindConVar("asw_marine_server_ragdoll");
	g_Cvar_AllowWaitCommand = FindConVar("sv_allow_wait_command");
	HookEvent("player_fullyjoined", OnClientFullyJoined);
}

public void OnMapStart()
{
	if (g_Cvar_AllowWaitCommand.IntValue != 1)
		g_Cvar_AllowWaitCommand.IntValue = 1;

	g_bMissionStarted = false;
	CreateTimer(0.5, StartCheckLoop, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientFullyJoined(Handle event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, PlayerJoined, GetEventInt(event, "userid"), TIMER_FLAG_NO_MAPCHANGE);
}

public Action PlayerJoined(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (client <= 0 || !IsClientConnected(client) || !IsClientInGame(client))
		return Plugin_Stop;

	if (Swarm_GetMarine(client) == -1)
	{
		g_bMarineSpawned[client] = false;
	}
	else
	{
		g_bMarineSpawned[client] = true;
		PrintToConsole(client, "[RESPAWN] Restored...");
	}

	return Plugin_Stop;
}

public Action StartCheckLoop(Handle timer)
{
	if (g_bMissionStarted)
		return Plugin_Stop;
	
	int ent = FindEntityByClassname(-1, "asw_marine");
	if (ent != -1 && ent > MaxClients)
	{
		g_bMissionStarted = true;
		CreateTimer(1.0, SearchMarines, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action SearchMarines(Handle timer)
{
	if (g_Cvar_MarineServerRagdoll.IntValue != 1)
		g_Cvar_MarineServerRagdoll.IntValue = 1;

	int marine;
	char targetname[32];
	int character;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		marine = Swarm_GetMarine(i);
		if (marine == -1)
		{
			PrintToServer("[RESPAWN] For index %i marine was not found.", i);
			continue;
		}

		GetEntPropString(marine, Prop_Data, "m_iName", targetname, sizeof(targetname));

		character = FindMarineIndex(targetname);

		if (character == -1)
			continue;

		g_bMarineSpawned[i] = true;
		g_marinecharacter[i] = character;
		g_playerResource[character] = GetEntPropEnt(marine, Prop_Data, "m_MarineResource");
		g_playerCommander[character] = GetEntPropEnt(marine, Prop_Send, "m_Commander");
		PrintToServer("[RESPAWN] marine: %i, character: %i, g_playerResource: %i, g_playerCommander: %i", marine, character, g_playerResource[character], g_playerCommander[character]);
	}
	
	return Plugin_Stop;
}

public Action Command_Respawn(int client, int args)
{
	if (!g_bMarineSpawned[client])
	{
		PrintToChat(client, "[RESPAWN] Your marine was not spawned.");
		return Plugin_Handled;
	}

	if (Swarm_GetMarine(client) != -1)
	{
		PrintToChat(client, "[RESPAWN] Your marine is alive.");
		return Plugin_Handled;
	}

	float curtime = GetTickedTime();
	float elapsedtime = curtime - g_respawnlastused[client];
	float minfrequency = g_Cvar_RespawnWaitTime.FloatValue;

	if (elapsedtime < minfrequency)
	{
		PrintToChat(client, "[RESPAWN] You must wait %.1f seconds.", minfrequency - elapsedtime);
		return Plugin_Handled;
	}

	g_respawnlastused[client] = curtime;

	int index = -1;
	int count = -1;
	int entmarine[8] = {0, ...};
	while ((index = FindEntityByClassname(index, "asw_marine")) != -1)
	{
		count++;
		entmarine[count] = index;
	}

	int entity = -1;
	if (count == -1)
	{
		PrintToChat(client, "[RESPAWN] Must be at least one marine alive.");
		return Plugin_Handled;
	}
	else if (count == 0)
		entity = entmarine[0];
	else
		entity = entmarine[GetRandomInt(0, count)];

	if (entity == -1)
		return Plugin_Handled;

	float origin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

	int character = g_marinecharacter[client];
	int marine = CreateEntityByName("asw_marine");
	if (marine == -1)
		return Plugin_Handled;
	
	char targetname[32];

	switch (character)
	{
		case 0:
			strcopy(targetname, sizeof(targetname), "#asw_name_sarge");
		case 1:
			strcopy(targetname, sizeof(targetname), "#asw_name_wildcat");
		case 2:
			strcopy(targetname, sizeof(targetname), "#asw_name_faith");
		case 3:
			strcopy(targetname, sizeof(targetname), "#asw_name_crash");
		case 4:
			strcopy(targetname, sizeof(targetname), "#asw_name_jaeger");
		case 5:
			strcopy(targetname, sizeof(targetname), "#asw_name_wolfe");
		case 6:
			strcopy(targetname, sizeof(targetname), "#asw_name_bastille");
		case 7:
			strcopy(targetname, sizeof(targetname), "#asw_name_vegas");
	}

	SetEntPropString(marine, Prop_Data, "m_iName", targetname);
	//DispatchKeyValue(marine, "targetname", targetname);
	
	SetEntPropEnt(marine, Prop_Data, "m_MarineResource", g_playerResource[character]);
	SetEntPropEnt(g_playerResource[character], Prop_Data, "m_MarineEntity", marine);
	SetEntPropEnt(marine, Prop_Send, "m_Commander", g_playerCommander[character]);
	int body = (character % 4) + 1;
	switch (body)
	{
		case 2: body = 3;
		case 3: body = 2;
	}
	char str_body[2];
	IntToString(body, str_body, sizeof(str_body));
	DispatchKeyValue(marine, "body", str_body);
	DispatchSpawn(marine);

	TeleportEntity(marine, origin, NULL_VECTOR, NULL_VECTOR);

	//ClientCommand(client, "ASW_NextMarine");
	PrintToChat(client, "[RESPAWN] Your marine was revived.");

	while ((index = FindEntityByClassname(index, "prop_ragdoll")) != -1)
	{
		GetEntPropString(index, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (FindMarineIndex(targetname) != character)
			continue;

		AcceptEntityInput(index, "Kill");
	}

	int weapnum = 0;
	while ((index = FindEntityByClassname(index, "asw_weapon_combat_rifle")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Data, "m_hOwner") != -1)
			continue;

		GetEntPropString(index, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (FindWeaponIndex(targetname) != character)
			continue;

		weapnum++;
		if (weapnum < 2)
			continue;

		AcceptEntityInput(index, "Kill");
	}

	weapnum = 0;
	while ((index = FindEntityByClassname(index, "asw_weapon_deagle")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Data, "m_hOwner") != -1)
			continue;

		GetEntPropString(index, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (FindWeaponIndex(targetname) != character)
			continue;

		weapnum++;
		if (weapnum < 2)
			continue;

		AcceptEntityInput(index, "Kill");
	}

	weapnum = 0;
	while ((index = FindEntityByClassname(index, "asw_weapon_medkit")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Data, "m_hOwner") != -1)
			continue;

		GetEntPropString(index, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (FindWeaponIndex(targetname) != character)
			continue;

		weapnum++;
		if (weapnum < 2)
			continue;

		AcceptEntityInput(index, "Kill");
	}

	int weapon = CreateEntityByName("asw_weapon_combat_rifle");
	if (weapon != -1)
	{
		SetEntPropString(weapon, Prop_Data, "m_iName", FindWeaponName(character));
		//DispatchKeyValue(weapon, "targetname", FindWeaponName(character));
		//SetEntProp(weapon, Prop_Data, "m_iClip2", 490);

		DispatchSpawn(weapon);
		Swarm_EquipMarineWeapon(marine, weapon);
		Swarm_SetMarineAmmo(marine, SwarmAmmo_Rifle, 980);
		//Swarm_SetMarineAmmo(marine, SwarmAmmo_RifleGrenades, 5);
		Swarm_SetMarineAmmo(marine, SwarmAmmo_CRShotgun, 24);
	}

	//asw_weapon_ammo_satchel
	weapon = CreateEntityByName("asw_weapon_deagle");
	if (weapon != -1)
	{
		SetEntPropString(weapon, Prop_Data, "m_iName", FindWeaponName(character));
		//DispatchKeyValue(weapon, "targetname", targetname);
		//SetEntProp(weapon, Prop_Data, "m_iClip1", 24);

		DispatchSpawn(weapon);
		Swarm_EquipMarineWeapon(marine, weapon);
		Swarm_SetMarineAmmo(marine, SwarmAmmo_DesertDeagle, 126);
	}

	weapon = CreateEntityByName("asw_weapon_medkit");
	if (weapon != -1)
	{
		SetEntPropString(weapon, Prop_Data, "m_iName", FindWeaponName(character));
		//DispatchKeyValue(weapon, "targetname", targetname);
		//SetEntProp(weapon, Prop_Data, "m_iClip1", 24);

		DispatchSpawn(weapon);
		Swarm_EquipMarineWeapon(marine, weapon);
	}

	ClientCommand(client, "+selectmarine1;wait 10;-selectmarine1;wait 100;ASW_InvNext");

/*
	while ((index = FindEntityByClassname(index, "asw_weapon_*")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Data, "m_hOwner") != -1)
			continue;

		if (GetEntPropEnt(index, Prop_Data, "m_iClip2") == -1)
			continue;

		char targetname[32];
		GetEntPropString(index, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (FindWeaponIndex(targetname) == character)
			Swarm_EquipMarineWeapon(marine, index);
	}
*/
	return Plugin_Handled;
}

stock int FindMarineIndex(const char[] name)
{
	if (StrEqual(name, "#asw_name_sarge"))
		return 0;
	if (StrEqual(name, "#asw_name_wildcat"))
		return 1;
	if (StrEqual(name, "#asw_name_faith"))
		return 2;
	if (StrEqual(name, "#asw_name_crash"))
		return 3;
	if (StrEqual(name, "#asw_name_jaeger"))
		return 4;
	if (StrEqual(name, "#asw_name_wolfe"))
		return 5;
	if (StrEqual(name, "#asw_name_bastille"))
		return 6;
	if (StrEqual(name, "#asw_name_vegas"))
		return 7;

	return -1;
}

stock int FindWeaponIndex(const char[] name)
{
	if (StrEqual(name, "#asw_name_sarge_weapon"))
		return 0;
	if (StrEqual(name, "#asw_name_wildcat_weapon"))
		return 1;
	if (StrEqual(name, "#asw_name_faith_weapon"))
		return 2;
	if (StrEqual(name, "#asw_name_crash_weapon"))
		return 3;
	if (StrEqual(name, "#asw_name_jaeger_weapon"))
		return 4;
	if (StrEqual(name, "#asw_name_wolfe_weapon"))
		return 5;
	if (StrEqual(name, "#asw_name_bastille_weapon"))
		return 6;
	if (StrEqual(name, "#asw_name_vegas_weapon"))
		return 7;

	return -1;
}

stock char[] FindWeaponName(int character)
{
	char name[32];
	switch (character)
	{
		case 0:
			strcopy(name, sizeof(name), "#asw_name_sarge_weapon");
		case 1:
			strcopy(name, sizeof(name), "#asw_name_wildcat_weapon");
		case 2:
			strcopy(name, sizeof(name), "#asw_name_faith_weapon");
		case 3:
			strcopy(name, sizeof(name), "#asw_name_crash_weapon");
		case 4:
			strcopy(name, sizeof(name), "#asw_name_jaeger_weapon");
		case 5:
			strcopy(name, sizeof(name), "#asw_name_wolfe_weapon");
		case 6:
			strcopy(name, sizeof(name), "#asw_name_bastille_weapon");
		case 7:
			strcopy(name, sizeof(name), "#asw_name_vegas_weapon");
	}
	
/*	if (name[0] == '\0')
		strcopy(name, sizeof(name), "#error");*/
	
	return name;
}
