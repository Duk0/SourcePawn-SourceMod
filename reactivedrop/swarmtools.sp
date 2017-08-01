#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define VERSION "1.2.4"

public Plugin myinfo =
{
	name = "Swarm Tools",
	author = "psychonic",
	description = "Provides extra functionality for Alien Swarm plugin developers.",
	version = VERSION,
	url = "http://www.nicholashastings.com"
};

#define MAX_MARINE_RESOURCES 5

int g_GameResourceEnt = -1;
int g_MarineResourceOffset = -1;

Handle g_hBecomeInfested = null;
Handle g_hWeaponEquip = null;
Handle g_hWeaponDrop = null;
Handle g_hSuicide = null;
Handle g_hEyeAngles = null;

char g_szSlapSounds[][] = {
	"player/pl_fallpain1.wav",
	"player/pl_fallpain3.wav",
	"player/pl_pain5.wav"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char game[32];
	GetGameFolderName(game, sizeof(game));
	if (strcmp(game, "swarm") != 0 && strcmp(game, "reactivedrop") != 0)
	{
		strcopy(error, err_max, "This plugin is only supported on Alien Swarm");
		return APLRes_Failure;
	}
	
	CreateNative("Swarm_IsGameActive", IsGameActive);
	CreateNative("Swarm_GetMarine", GetMarine);
	CreateNative("Swarm_GetMarineResFromCommander", GetMarineResFromCommander);
	CreateNative("Swarm_GetMarineResOfMarine", GetMarineResFromMarine);
	CreateNative("Swarm_StartMarineInfestation", StartMarineInfestation);
	CreateNative("Swarm_EquipMarineWeapon", EquipMarineWeapon);
	CreateNative("Swarm_DropMarineWeapon", DropMarineWeapon);
	CreateNative("Swarm_ForceMarineSuicide", ForceMarineSuicide);
	CreateNative("Swarm_SlapMarine", SlapMarine);
	CreateNative("Swarm_GetMarineEyeAngles", GetMarineEyeAngles);
	RegPluginLibrary("swarmtools");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("swarmtools_version", VERSION, _, FCVAR_NOTIFY);
	
	g_MarineResourceOffset = FindSendPropInfo("CASW_Game_Resource", "m_MarineResources");
	if (g_MarineResourceOffset == -1)
		SetFailState("Failed to find marine resource offset");
	
	Handle hGameConfig = null;
	if ((hGameConfig = LoadGameConfigFile("swarmtools.games")) == null)
		SetFailState("Could not find gamedata/swarmtools.games.txt");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "BecomeInfested");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	g_hBecomeInfested = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "WeaponEquip");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hWeaponEquip = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "WeaponDrop");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByValue, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByValue, VDECODE_FLAG_ALLOWNULL);
	g_hWeaponDrop = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "Suicide");
	g_hSuicide = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "ASWEyeAngles");
	PrepSDKCall_SetReturnInfo(SDKType_QAngle, SDKPass_ByRef);
	g_hEyeAngles = EndPrepSDKCall();
	
	CloseHandle(hGameConfig);
}

public void OnMapStart()
{
	//g_GameResourceEnt = MyFindEntityByClassname(MaxClients+1, "asw_game_resource");
	g_GameResourceEnt = FindEntityByClassname(MaxClients+1, "asw_game_resource");
}

public void OnMapEnd()
{
	g_GameResourceEnt = -1;
}
/*
static int MyFindEntityByClassname(int start, const char[] classname)
{
	int max = GetMaxEntities();
	char buffer[64];
	
	for (int i = start; i < max; i++)
	{
		if (!IsValidEdict(i))
			continue;
		
		GetEdictClassname(i, buffer, sizeof(buffer));
		if (!strcmp(buffer, classname))
		{
			return i;
		}
	}
	
	return -1;
}
*/
public int IsGameActive(Handle plugin, int numParams)
{
	return (g_GameResourceEnt != -1);
}

public int GetMarine(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client == 0 || !IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid", client);
	
	int marineResource;
	for (int i = 0; i < MAX_MARINE_RESOURCES; i++)
	{
		marineResource = GetEntDataEnt2(g_GameResourceEnt, g_MarineResourceOffset + (i*4));
		if (marineResource == -1 || !IsValidEdict(marineResource))
			continue;
		
		if (GetEntPropEnt(marineResource, Prop_Send, "m_Commander") != client)
			continue;
		
		return GetEntPropEnt(marineResource, Prop_Send, "m_MarineEntity");
	}
	
	return -1;
}

public int GetMarineResFromCommander(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client == 0 || !IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid", client);
	
	int marineResource;
	for (int i = 0; i < MAX_MARINE_RESOURCES; i++)
	{
		marineResource = GetEntDataEnt2(g_GameResourceEnt, g_MarineResourceOffset + (i*4));
		if (marineResource == -1 || !IsValidEdict(marineResource))
			continue;
		
		if (GetEntPropEnt(marineResource, Prop_Send, "m_Commander") != client)
			continue;
		
		return marineResource;
	}
	
	return -1;
}

public int GetMarineResFromMarine(Handle plugin, int numParams)
{
	int marine = GetNativeCell(1);
	if (marine == 0 || !IsValidMarine(marine))
		ThrowNativeError(SP_ERROR_NATIVE, "Marine index %d is invalid", marine);
	
	int marineResource;
	for (int i = 0; i < MAX_MARINE_RESOURCES; i++)
	{
		marineResource = GetEntDataEnt2(g_GameResourceEnt, g_MarineResourceOffset + (i*4));
		if (marineResource == -1 || !IsValidEdict(marineResource))
			continue;
		
		if (GetEntPropEnt(marineResource, Prop_Send, "m_MarineEntity") != marine)
			continue;
		
		return marineResource;
	}
	
	return -1;
}

public int StartMarineInfestation(Handle plugin, int numParams)
{
	if (g_hBecomeInfested == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, "BecomeInfested function not found");
	
	int marine = GetNativeCell(1);
	if (!IsValidMarine(marine))
		ThrowNativeError(SP_ERROR_NATIVE, "Marine index %d is invalid", marine);
	
	SDKCall(g_hBecomeInfested, marine, -1);
	
	SetEntPropFloat(marine, Prop_Send, "m_fInfestedTime", view_as<float>(GetNativeCell(2)));
}

public int EquipMarineWeapon(Handle plugin, int numParams)
{
	if (g_hWeaponEquip == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, "WeaponEquip function not found");
	
	int marine = GetNativeCell(1);
	if (!IsValidMarine(marine))
		ThrowNativeError(SP_ERROR_NATIVE, "Marine index %d is invalid", marine);
	
	int weapon = GetNativeCell(2);
	if (weapon == 0 || !IsValidEdict(weapon))
		ThrowNativeError(SP_ERROR_NATIVE, "Weapon index %d is invalid", weapon);
	
	SDKCall(g_hWeaponEquip, marine, weapon);
}

public int DropMarineWeapon(Handle plugin, int numParams)
{
	if (g_hWeaponDrop == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, "WeaponDrop function not found");
	
	int marine = GetNativeCell(1);
	if (!IsValidMarine(marine))
		ThrowNativeError(SP_ERROR_NATIVE, "Marine index %d is invalid", marine);
	
	int weapon = GetNativeCell(2);
	if (weapon == 0 || !IsValidEdict(weapon))
		ThrowNativeError(SP_ERROR_NATIVE, "Weapon index %d is invalid", weapon);
	
	SDKCall(g_hWeaponDrop, marine, weapon, NULL_VECTOR, NULL_VECTOR);
}

public int ForceMarineSuicide(Handle plugin, int numParams)
{
	if (g_hSuicide == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, "Suicide function not found");
	
	int marine = GetNativeCell(1);
	if (!IsValidMarine(marine))
		ThrowNativeError(SP_ERROR_NATIVE, "Marine index %d is invalid", marine);
	
	SlayMarine(marine);
}

public int SlapMarine(Handle plugin, int numParams)
{
	int marine = GetNativeCell(1);
	if (!IsValidMarine(marine))
		ThrowNativeError(SP_ERROR_NATIVE, "Marine index %d is invalid", marine);
	
	int amount = GetNativeCell(2);
	bool bSound = view_as<bool>(GetNativeCell(3));
	
	bool bShouldSlay = false;
	int health = GetEntProp(marine, Prop_Send, "m_iHealth");
	int client = GetEntPropEnt(marine, Prop_Send, "m_Commander");
	
	if (health - amount <= 0)
	{
		SetEntProp(marine, Prop_Send, "m_iHealth", 1);
		bShouldSlay = true;
	}
	else
	{
		SetEntProp(marine, Prop_Send, "m_iHealth", health - amount);
	}
	
	float velocity[3];
	velocity[0] = GetEntPropFloat(marine, Prop_Send, "m_vecVelocity[0]");
	velocity[1] = GetEntPropFloat(marine, Prop_Send, "m_vecVelocity[1]");
	velocity[2] = GetEntPropFloat(marine, Prop_Send, "m_vecVelocity[2]");
   
	velocity[0] += ((GetURandomInt() % 180) + 50) * (((GetURandomInt() % 2) == 1) ?  -1 : 1);
	velocity[1] += ((GetURandomInt() % 180) + 50) * (((GetURandomInt() % 2) == 1) ?  -1 : 1);
	velocity[2] += GetURandomInt() % 200 + 100;
	
	TeleportEntity(marine, NULL_VECTOR, NULL_VECTOR, velocity);
	
	/* Play a random sound */
	if (bSound)
	{
   		int r = (GetURandomInt() % sizeof(g_szSlapSounds)) + 1;
   		//int r = GetRandomInt(0, sizeof(g_szSlapSounds) - 1);
		EmitSoundToClient(client, g_szSlapSounds[r]);
   	}

	/* Force suicide */
 	if (bShouldSlay)
 	{
		if (!SlayMarine(marine))
			ClientCommand(client, "kill");
 	}
}

public int GetMarineEyeAngles(Handle plugin, int numParams)
{
	if (g_hEyeAngles == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, "EyeAngles function not found");
	
	int marine = GetNativeCell(1);
	if (!IsValidMarine(marine))
		ThrowNativeError(SP_ERROR_NATIVE, "Marine index %d is invalid", marine);
	
	float angles[3];
	SDKCall(g_hEyeAngles, marine, angles);
	
	SetNativeArray(2, angles, 3);
}

bool SlayMarine(int marine)
{
	if (g_hSuicide != INVALID_HANDLE)
	{
		SDKCall(g_hSuicide, marine);
		return true;
	}
	
	return false;
}

bool IsValidMarine(int marine)
{
	if (!IsValidEdict(marine))
		return false;
	
	char classname[64];
	GetEdictClassname(marine, classname, sizeof(classname));
	
	return !(strcmp(classname, "asw_marine"));
}
