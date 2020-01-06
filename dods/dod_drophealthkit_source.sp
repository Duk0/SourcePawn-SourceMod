//////////////////////////////////////////////
//
// SourceMod Script
//
// DoD DropHealthKit Source
//
// Developed by FeuerSturm
//
// - Credits to "monkie" for the request!
//
//////////////////////////////////////////////
//
//
// USAGE:
// ======
//
//
// CVARs:
// ------
//
// dod_drophealthkit_deaddrop <1/0>		=	enable/disable dropping a healthkit on players' death
//
// dod_drophealthkit_pickuprule <0/1/2>	=	set who can pickup dropped healthkits
//											0 = everyone
//											1 = only teammates
//											2 = only enemies
//
// dod_drophealthkit_addhealth <#>		=	amount of HP to add to a player picking up a healthkit
//
// dod_drophealthkit_maxhealth <#>		=	maximum amount of healthpoints a player can reach
//
// dod_drophealthkit_lifetime <#>		=	number of seconds a dropped healthkit stays on the map
//
// dod_drophealthkit_useteamcolor <1/0>	=	use team's color of dropping player to colorize healthkit
//
//
//
//
// CHANGELOG:
// ==========
// 
// - 16 November 2008 - Version 1.0
//   Initial Release
//
// - 18 November 2008 - Version 1.1
//   New Features:
//   * maximum amount of health a player can reach
//     can now be defined
//     (see new cvar "dod_drophealthkit_maxhealth")
//   * healthkit pickup can now be limited to a group
//     of players
//     (see new cvar "dod_drophealthkit_pickuprule")
//
// - 22 November 2008 - Version 1.2
//   New Features:
//   * players can be allowed to drop their healthkit
//     while being alive (command "dropammo" that usually
//     drops an ammobox is used. So if a player has a healthkit
//     on first button press (default is [H]) player's healthkit
//     is dropped if he has one, pressing the button again will
//     drop the ammobox like usually!
//     (see new cvar "dod_drophealthkit_alivedrop")
//   * dropping healthkits on death/alive can be enabled/disabled
//     independently from each other!
//   Bugfixes:
//   * fixed invalid Handle errors
//   General Changes:
//   * renamed cvar "dod_drophealthkit_source" to
//     "dod_drophealthkit_deaddrop"
//
// - 22 January 2010 - Version 1.3
//   * removed need for DukeHacks Extension,
//     "SDK Hooks" Extension features are used
//     instead now!
//
//
// - 22 May 2011 - Version 1.4
//	by vintage
//	* print a HintText message when player say !medic or /medic or medic
// - 25 May 2011 - Version 1.5
//  * Added multilangage message
//
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.5"

public Plugin:myinfo = 
{
	name = "DoD DropHealthKit Source",
	author = "FeuerSturm",
	description = "Players drop a healthkit on death!",
	version = PLUGIN_VERSION,
	url = "http://www.dodsourceplugins.net"
}

#define MAXENTITIES 1024

new Handle:HealthKitDropTimer[MAXENTITIES+1] = INVALID_HANDLE

new String:g_HealthKit_Model[] = { "models/props_misc/ration_box01.mdl" }
new String:g_HealthKit_Sound[] = { "object/object_taken.wav" }

new g_HealthKit_Skin[4] = { 0, 0, 2, 1 }
new bool:g_HasHealthKit[MAXPLAYERS+1]
new g_HealthKitOwner[MAXENTITIES+1]

new Handle:healthkitdeaddrop = INVALID_HANDLE
new Handle:healthkitrule = INVALID_HANDLE
new Handle:healthkitdropcmd = INVALID_HANDLE
new Handle:healthkitmaxhealth = INVALID_HANDLE
new Handle:healthkithealth = INVALID_HANDLE
new Handle:healthkitliefetime = INVALID_HANDLE
new Handle:healthkitteamcolor = INVALID_HANDLE

public OnPluginStart()
{
	CreateConVar("dod_drophealthkit_version", PLUGIN_VERSION, "DoD DropHealthKit Source Version (DO NOT CHANGE!)", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY)
	SetConVarString(FindConVar("dod_drophealthkit_version"), PLUGIN_VERSION);
	healthkitdeaddrop = CreateConVar("dod_drophealthkit_deaddrop", "1", "<1/0> = enable/disable dropping a healthkit on players' death", _, true, 0.0, true, 1.0);
	healthkitrule = CreateConVar("dod_drophealthkit_pickuprule", "0", "<0/1/2> = set who can pickup dropped healthkits: 0 = everyone, 1 = only teammates, 2 = only enemies", _, true, 0.0, true, 2.0);
	healthkitdropcmd = CreateConVar("dod_drophealthkit_alivedrop", "1", "<1/0> = enable/disable allowing alive players to drop their healthkit", _, true, 0.0, true, 1.0);
	healthkithealth = CreateConVar("dod_drophealthkit_addhealth", "25", "<#> = amount of HP to add to a player picking up a healthkit", _, true, 5.0, true, 95.0);
	healthkitmaxhealth = CreateConVar("dod_drophealthkit_maxhealth", "100", "<#> = maximum amount of healthpoints a player can reach", _, true, 50.0, true, 200.0);
	healthkitliefetime = CreateConVar("dod_drophealthkit_lifetime", "30", "<#> = number of seconds a dropped healthkit stays on the map", _, true, 5.0, true, 60.0);
	healthkitteamcolor = CreateConVar("dod_drophealthkit_useteamcolor", "1", "<1/0> = use team's color of dropping player to colorize healthkit", _, true, 0.0, true, 1.0);
	LoadTranslations("dod_drophealthkit_source.phrases")
	RegAdminCmd("dropammo", cmdDropHealthKit, 0);
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	HookEvent("player_hurt", OnPlayerDeath, EventHookMode_Pre);
	HookEventEx("player_spawn", OnPlayerSpawn, EventHookMode_Post);

	AutoExecConfig(true, "dod_drophealthkit_source");
}

public Action:Command_Say( client, args )
{
	decl String:Said[ 128 ];
	
	GetCmdArgString( Said, sizeof( Said ) - 1 );
	StripQuotes( Said );
	TrimString( Said );
		
	if( StrEqual( Said, "!medic" ) || StrEqual( Said, "medic" ) || StrEqual( Said, "/medic" ) )
	{
		PrintHintText( client, "%t", "message");
	}
}


public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) > 1)
	{
		g_HasHealthKit[client] = true
	}
	return Plugin_Continue
}

public Action:cmdDropHealthKit(client, args) 
{
	if(!IsPlayerAlive(client) || !IsClientInGame(client) || !g_HasHealthKit[client] || GetConVarInt(healthkitdropcmd) == 0)
	{
		return Plugin_Continue
	}
	new Float:origin[3]
	GetClientAbsOrigin(client, origin)
	origin[2] += 40.0
	new Float:angles[3]
	GetClientEyeAngles(client, angles)
	new Float:velocity[3]
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR)
	NormalizeVector(velocity, velocity)
	ScaleVector(velocity,350.0)
	new team = GetClientTeam(client)
	new healthkit = CreateEntityByName("prop_physics_override")
	SetEntityModel(healthkit, g_HealthKit_Model)
	SetEntProp(healthkit, Prop_Send, "m_nSkin", g_HealthKit_Skin[team])
	//DispatchKeyValue(healthkit, "spawnflags", "4")
	DispatchSpawn(healthkit)
	TeleportEntity(healthkit, origin, angles, velocity)
	if(GetConVarInt(healthkitteamcolor) == 1)
	{
		SetEntityRenderColor(healthkit, team == 2 ? 0 : 150, team == 2 ? 150 : 0, 0, 50)
	}
	else
	{
		SetEntityRenderColor(healthkit, 250, 250, 0, 50)
	}
	g_HealthKitOwner[healthkit] = client
	g_HasHealthKit[client] = false
	SDKHook(healthkit, SDKHook_Touch, OnHealthKitTouched)
	HealthKitDropTimer[healthkit] = CreateTimer(GetConVarFloat(healthkitliefetime), RemoveDroppedHealthKit, healthkit, TIMER_FLAG_NO_MAPCHANGE)
	return Plugin_Handled
}


public OnMapStart()
{
	PrecacheModel(g_HealthKit_Model,true)
	PrecacheSound(g_HealthKit_Sound, true)
}

public Action:RemoveDroppedHealthKit(Handle:timer, any:healthkit)
{
	HealthKitDropTimer[healthkit] = INVALID_HANDLE
	if(IsValidEdict(healthkit))
	{
		RemoveEdict(healthkit)
	}
	return Plugin_Handled
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(GetClientHealth(client) > 0 || !IsClientInGame(client) || GetConVarInt(healthkitdeaddrop) == 0 || !g_HasHealthKit[client])
	{
		return Plugin_Continue
	}
	new Float:deathorigin[3]
	GetClientAbsOrigin(client, deathorigin)
	deathorigin[2] += 1.0
	new team = GetClientTeam(client)
	new healthkit = CreateEntityByName("prop_physics_override")
	SetEntityModel(healthkit, g_HealthKit_Model)
	SetEntProp(healthkit, Prop_Send, "m_nSkin", g_HealthKit_Skin[team])
	//DispatchKeyValue(healthkit, "spawnflags", "4")
	DispatchSpawn(healthkit)
	TeleportEntity(healthkit, deathorigin, NULL_VECTOR, NULL_VECTOR)
	if(GetConVarInt(healthkitteamcolor) == 1)
	{
		SetEntityRenderColor(healthkit, team == 2 ? 0 : 150, team == 2 ? 150 : 0, 0, 50)
	}
	else
	{
		SetEntityRenderColor(healthkit, 250, 250, 0, 50)
	}
	g_HealthKitOwner[healthkit] = client
	SDKHook(healthkit, SDKHook_Touch, OnHealthKitTouched)
	HealthKitDropTimer[healthkit] = CreateTimer(GetConVarFloat(healthkitliefetime), RemoveDroppedHealthKit, healthkit, TIMER_FLAG_NO_MAPCHANGE)
	return Plugin_Continue
}

public Action:OnHealthKitTouched(healthkit, client)
{
	if(client > 0 && client <= MaxClients && healthkit > 0 && IsValidEntity(client) && IsClientInGame(client) && IsPlayerAlive(client) && IsValidEdict(healthkit))
	{
		if(g_HealthKitOwner[healthkit] == client)
		{
			if(!g_HasHealthKit[client])
			{
				KillHealthKitTimer(healthkit)
				PlayPickUpSound(client)
				RemoveEdict(healthkit)
				g_HasHealthKit[client] = true
				return Plugin_Handled
			}
			return Plugin_Handled
		}
		new health = GetClientHealth(client)
		new maxhealth = GetConVarInt(healthkitmaxhealth)
		if(health >= maxhealth)
		{
			return Plugin_Handled
		}
		new pickuprule = GetConVarInt(healthkitrule)
		new clteam = GetClientTeam(client)
		new kitteam = GetEntProp(healthkit, Prop_Send, "m_nSkin")
		if((pickuprule == 1 && kitteam != g_HealthKit_Skin[clteam]) || (pickuprule == 2 && kitteam == g_HealthKit_Skin[clteam]))
		{
			return Plugin_Handled
		}
		new healthkitadd = GetConVarInt(healthkithealth)
		if(health + healthkitadd >= maxhealth)
		{
			SetEntityHealth(client, maxhealth)
		}
		else
		{
			SetEntityHealth(client, health + healthkitadd)
		}
		KillHealthKitTimer(healthkit)
		PlayPickUpSound(client)
		RemoveEdict(healthkit)
	}
	return Plugin_Handled
}

stock KillHealthKitTimer(healthkit)
{
	if(HealthKitDropTimer[healthkit] != INVALID_HANDLE)
	{
		CloseHandle(HealthKitDropTimer[healthkit])
	}
	HealthKitDropTimer[healthkit] = INVALID_HANDLE
}

stock PlayPickUpSound(client)
{
	EmitSoundToAll(g_HealthKit_Sound, client, SNDCHAN_WEAPON, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL)
	//EmitSoundToClient(client, g_HealthKit_Sound, SOUND_FROM_PLAYER, SNDCHAN_WEAPON, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL)
}
	