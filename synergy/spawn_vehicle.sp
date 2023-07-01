/*
* 
* Spawns a vehicle in synergy where someone is looking
* 
* sm_spawnvehicle <name of person to spawn at> <vehicle type>
* 
* Changelog								
* ------------		
* 1.0									
*  - Initial Release			
* 
* 		
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
//#include <syntools>

#define MAPLENGTH 64

public Plugin myinfo = 
{
	name = "Spawn a vehicle",
	author = "Duko",
	description = "Spawns a vehicle where someone is looking in Synergy",
	version = "1.2",
	url = "http://group.midu.cz"
};

ArrayList g_Maplist = null;
int g_Maplist_Serial = -1;

StringMap g_hVehicles = null;

enum struct Vehicle
{
	char classname[32];
	char model[32];
	char vehiclescript[48];
	bool setuser;
}

ConVar g_Cvar_VehicleMap;
ConVar g_Cvar_VehicleSpawnTime;
bool g_bIsVehicleMap = false;
bool g_bIsPuzzleMap = false;
bool g_bAllowJalopy = false;
float g_flLastUsed[MAXPLAYERS+1] = {0.0, ...};
int g_iCollisionGroup;

public void OnPluginStart()
{
	g_Maplist = new ArrayList(ByteCountToCells(MAPLENGTH));

	char mapListPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapListPath, sizeof(mapListPath), "configs/novehicle_maps.txt");
	SetMapListCompatBind("novehiclemaps", mapListPath);

	LoadMapList();

	RegAdminCmd("sm_spawnvehicle", Command_SpawnVehicle, ADMFLAG_KICK, "Spawn a vehicle");
	RegAdminCmd("sm_vehiclegun", Command_AirboatGunToggle, ADMFLAG_KICK, "Toggle airboat gun");
	RegAdminCmd("sm_remove_vehicles", Command_RemoveVehicles, ADMFLAG_KICK, "Remove vehicles");
	RegAdminCmd("sm_testvehicle", Command_TestVehicle, ADMFLAG_KICK, "Test a vehicle");

	RegConsoleCmd("sm_vehicle", Command_VehicleMenu, "Vehicle menu");
	RegConsoleCmd("sm_car", Command_VehicleMenu, "Vehicle menu");
	
	g_Cvar_VehicleMap = CreateConVar("sm_vehicle_map", "0");
	g_Cvar_VehicleSpawnTime = CreateConVar("sm_vehicle_spawntime", "1.0");

	g_iCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	if (g_iCollisionGroup == -1)
		SetFailState("Offest m_CollisionGroup not found.");

	LoadTranslations("common.phrases");


	Vehicle aValues;
	g_hVehicles = new StringMap();

	strcopy(aValues.classname, sizeof(aValues.classname), "prop_vehicle_mp");
	strcopy(aValues.model, sizeof(aValues.model), "models/vehicles/7seatvan.mdl");
	strcopy(aValues.vehiclescript, sizeof(aValues.vehiclescript), "scripts/vehicles/van.txt");
	aValues.setuser = false;
	g_hVehicles.SetArray("van", aValues, sizeof(aValues));

	strcopy(aValues.classname, sizeof(aValues.classname), "prop_vehicle_mp");
	strcopy(aValues.model, sizeof(aValues.model), "models/vehicles/8seattruck.mdl");
	strcopy(aValues.vehiclescript, sizeof(aValues.vehiclescript), "scripts/vehicles/truck.txt");
	aValues.setuser = false;
	g_hVehicles.SetArray("truck", aValues, sizeof(aValues));

	strcopy(aValues.classname, sizeof(aValues.classname), "prop_vehicle_jeep");
	strcopy(aValues.model, sizeof(aValues.model), "models/buggy.mdl");
	strcopy(aValues.vehiclescript, sizeof(aValues.vehiclescript), "scripts/vehicles/jeep_test.txt");
	aValues.setuser = true;
	g_hVehicles.SetArray("jeep", aValues, sizeof(aValues));

	strcopy(aValues.classname, sizeof(aValues.classname), "prop_vehicle_airboat");
	strcopy(aValues.model, sizeof(aValues.model), "models/airboat.mdl");
	strcopy(aValues.vehiclescript, sizeof(aValues.vehiclescript), "scripts/vehicles/airboat.txt");
	aValues.setuser = true;
	g_hVehicles.SetArray("airboat", aValues, sizeof(aValues));

	strcopy(aValues.classname, sizeof(aValues.classname), "prop_vehicle_jeep_episodic");
	strcopy(aValues.model, sizeof(aValues.model), "models/vehicle.mdl");
	strcopy(aValues.vehiclescript, sizeof(aValues.vehiclescript), "scripts/vehicles/jalopy.txt");
	aValues.setuser = true;
	g_hVehicles.SetArray("jalopy", aValues, sizeof(aValues));

	strcopy(aValues.classname, sizeof(aValues.classname), "prop_vehicle_airboat");
	strcopy(aValues.model, sizeof(aValues.model), "models/airboat.mdl");
	strcopy(aValues.vehiclescript, sizeof(aValues.vehiclescript), "scripts/vehicles/puzzleairboatold.txt");
	aValues.setuser = true;
	g_hVehicles.SetArray("puzzleairboat", aValues, sizeof(aValues));
/*
//	strcopy(aValues.classname, sizeof(aValues.classname), "prop_vehicle_jeep_elite");
	strcopy(aValues.classname, sizeof(aValues.classname), "prop_vehicle_mp");
	strcopy(aValues.model, sizeof(aValues.model), "models/vehicles/buggy_elite.mdl");
	strcopy(aValues.vehiclescript, sizeof(aValues.vehiclescript), "scripts/vehicles/jeep_elite.txt");
	aValues.setuser = false;
	g_hVehicles.SetArray("jeepelite", aValues, sizeof(aValues));
*/
//	strcopy(aValues.classname, sizeof(aValues.classname), "prop_vehicle_jeep");
	strcopy(aValues.classname, sizeof(aValues.classname), "prop_vehicle_mp");
	strcopy(aValues.model, sizeof(aValues.model), "models/vehicles/buggy_p2.mdl");
	strcopy(aValues.vehiclescript, sizeof(aValues.vehiclescript), "scripts/vehicles/jeep_test.txt");
	aValues.setuser = false;
	g_hVehicles.SetArray("jeep2p", aValues, sizeof(aValues));
}

public void OnMapStart()
{
/*	char szModel[48];
	if (IsModelPrecached("models/vehicles/buggy_p2.mdl"))
	{
		for (int i = 1; i <= 20; i++)
		{
			if (i < 10)
				Format(szModel, sizeof(szModel), "models/vehicles/gibs/buggy_p2_gib0%i.mdl", i);
			else
				Format(szModel, sizeof(szModel), "models/vehicles/gibs/buggy_p2_gib%i.mdl", i);

			if (!IsModelPrecached(szModel))
				PrecacheModel(szModel, true);
		}
	}

	for (int i = 0; i < sizeof(g_szModels); i++)
	{
		strcopy(szModel, sizeof(szModel), g_szModels[i])
		if (!IsModelPrecached(szModel))
			PrecacheModel(szModel, true);
	}*/

	for (int i = 1; i <= MaxClients; i++)
		g_flLastUsed[i] = 0.0;
	
	g_bIsVehicleMap = false;
	g_bIsPuzzleMap = false;
	g_bAllowJalopy = false;
	
	if (FindEntityByClassname(-1, "info_vehicle_spawn") != -1)
		g_bIsVehicleMap = true;

	int index = -1;
	char script[48];
	while ((index = FindEntityByClassname(index, "prop_vehicle_airboat")) != -1)
	{
		if (!g_bIsVehicleMap)
			g_bIsVehicleMap = true;

		GetEntPropString(index, Prop_Data, "m_vehicleScript", script, sizeof(script));
		if (!StrEqual(script, "scripts/vehicles/puzzleairboatold.txt"))
			continue;

		g_bIsPuzzleMap = true;
		break;
	}

	if (!g_bIsVehicleMap && IsVehicleOnMap())
		g_bIsVehicleMap = true;

	if (g_hVehicles != null)
	{
		StringMapSnapshot hTrieSnapshot = g_hVehicles.Snapshot();
		
		char szKey[16];
		Vehicle aValues;
		int iSize = hTrieSnapshot.Length;
		for (int i = 0; i < iSize; i++)
		{
			hTrieSnapshot.GetKey(i, szKey, sizeof(szKey));
			g_hVehicles.GetArray(szKey, aValues, sizeof(aValues));

			if (aValues.model[0] == '\0' || !FileExists(aValues.model, true) || IsModelPrecached(aValues.model))
				continue;

			PrecacheModel(aValues.model, true);
			PrintToServer("[VEHICLE] Precache szKey: %s, model: %s", szKey, aValues.model);
		}

		delete hTrieSnapshot;
	}
}

public void OnConfigsExecuted()
{
	char map[64];
	GetCurrentMap(map, sizeof(map));

	if (NoVehicleMap(map))
		g_bIsVehicleMap = false;

	g_Cvar_VehicleMap.BoolValue = g_bIsVehicleMap;
	
	if (g_bIsVehicleMap)
		LogMessage("[VEHICLE] Is Vehicle Map");

	if (FileExists("models/vehicle.mdl", true) && FileExists("scripts/vehicles/jalopy.txt", true))
		g_bAllowJalopy = true;
}

public Action Command_TestVehicle(int client, int args)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "prop_vehicle_*")) != -1)
	{
		char szClassname[32];
		GetEntityClassname(index, szClassname, sizeof(szClassname));
		//int arraySize = GetEntPropArraySize(index, Prop_Data, "m_PassengerInfo");
		PrintToConsole(client, "[VEHICLE] index: %i, classname: %s, driver: %i", index, szClassname, Vehicle_GetDriver(index));
	}

	PrintToConsole(client, "[VEHICLE] client vehicle: %i", Client_GetVehicle(client));

	return Plugin_Handled;
}

public Action Command_SpawnVehicle(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[VEHICLE] Usage: sm_spawnvehicle <#userid|name> <vehicle>\nvehicles: airboat, jeep, jalopy, van, truck, puzzleairboat, jeepelite, jeep2p");
		return Plugin_Handled;
	}

	char name[128], vehicle[32];
	GetCmdArg(1, name, sizeof(name));
	GetCmdArg(2, vehicle, sizeof(vehicle));

	if (g_bIsPuzzleMap && StrEqual(vehicle, "airboat"))
		strcopy(vehicle, sizeof(vehicle), "puzzleairboat");

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			name,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		if (!PlayerSpawned(target_list[i]))
			continue;

		SpawnVehicle(target_list[i], vehicle);
	}

	return Plugin_Handled;
}

//bool g_bIsSpaceFree = true;

void SpawnVehicle(int client = 0, const char[] vehicle)
{
	if (!client || !PlayerSpawned(client))
		return;
	
	bool bRemove = false;
	if (StrEqual(vehicle, "remove"))
		bRemove = true;

	if (!bRemove && Client_IsInVehicle(client))
		return;

	Vehicle aValues;
	if (!bRemove && !g_hVehicles.GetArray(vehicle, aValues, sizeof(aValues)))
		return;

	if (!bRemove && !FileExists(aValues.model, true))
		return;

	if (!bRemove && !FileExists(aValues.vehiclescript, true))
		return;

	char skin[2];

	if (!bRemove && StrEqual(vehicle, "van"))
		IntToString(GetRandomInt(0, 4), skin, sizeof(skin));

	char targetname[32];
	Format(targetname, sizeof(targetname), "custom_vehicle_%i", client);


	ArrayList hPlayerVehice = new ArrayList();
	int clientvehicle;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!PlayerSpawned(i))
			continue;

		clientvehicle = Client_GetVehicle(i);
		if (clientvehicle == -1)
			continue;

		hPlayerVehice.Push(clientvehicle);
	}
	
	int index = -1;
	char vehiclename[32];
	while ((index = FindEntityByClassname(index, "prop_vehicle_*")) != -1)
	{
		GetEntPropString(index, Prop_Data, "m_iName", vehiclename, sizeof(vehiclename));
		
		if (!StrEqual(vehiclename, targetname))
			continue;

		if (hPlayerVehice.Length && hPlayerVehice.FindValue(index) != -1)
			continue;

/*		if (GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity") != client)
			continue;*/
		
		AcceptEntityInput(index, "Kill");
	}
	
	delete hPlayerVehice;

	if (bRemove)
		return;

	float eyeangles[3];
	GetClientEyeAngles(client, eyeangles);
			
	float spawnangles[3];
	spawnangles[1] = eyeangles[1] - 90.0;
	float origin[3], spawnorigin[3];
	GetClientAbsOrigin(client, origin);
	spawnorigin = origin;

	spawnorigin[0] += (180.0 * Cosine(DegToRad(eyeangles[1])));
	spawnorigin[1] += (180.0 * Sine(DegToRad(eyeangles[1])));
	spawnorigin[2] += 120.0;

//	float anglevector[3];
	float endpos[3];
	float distance = 0.0;
//	anglevector = eyeangles;
//	anglevector[0] = anglevector[2] = 0.0;
	eyeangles[0] = eyeangles[2] = 0.0;
//	GetAngleVectors(eyeangles, anglevector, NULL_VECTOR, NULL_VECTOR);
//	NormalizeVector(anglevector, anglevector);
	origin[2] += 10.0;

/*
	int ent = CreateEntityByName("trigger_once");
	if (ent != -1)
	{
		DispatchKeyValueVector(ent, "origin", spawnorigin);
		DispatchKeyValueVector(ent, "angles", spawnangles);
		DispatchKeyValue(ent, "model", aValues.model);
		DispatchKeyValue(ent, "spawnflags", "11");
	//	DispatchKeyValue(ent, "spawnflags", "1039");
		DispatchKeyValue(ent, "StartDisabled", "0");
		DispatchSpawn(ent);
		ActivateEntity(ent);

	//	float minbounds[3] = {-100.0, -100.0, -100.0};
	//	float maxbounds[3] = {100.0, 100.0, 100.0};
	//	GetEntPropVector(ent, Prop_Send, "m_vecMins", minbounds);
	//	GetEntPropVector(ent, Prop_Send, "m_vecMaxs", maxbounds);
	//	ScaleVector(minbounds, 1.1);
	//	ScaleVector(maxbounds, 1.1);
	//	SetEntPropVector(ent, Prop_Send, "m_vecMins", minbounds);
	//	SetEntPropVector(ent, Prop_Send, "m_vecMaxs", maxbounds);

		DispatchKeyValue(ent, "solid", "2");
		DispatchKeyValue(ent, "effects", "32");

	//	SetEntProp(ent, Prop_Send, "m_nSolidType", 2);

	//	int effects = GetEntProp(ent, Prop_Send, "m_fEffects");
	//	effects |= 32
	//	SetEntProp(ent, Prop_Send, "m_fEffects", effects);

		g_bIsSpaceFree = true;
		HookSingleEntityOutput(ent, "OnTrigger", OutputHook_OnStartTouch, true);
	}
*/
/*	bool bIsSpaceFree = false;
	
	if (IsValidEdict(ent) && IsValidEntity(ent))
	{
		char szClassname[16];
		if (GetEdictClassname(ent, szClassname, sizeof(szClassname)) && StrEqual(szClassname, "trigger_once"))
		{
			AcceptEntityInput(ent, "Kill");
			bIsSpaceFree = true;
		}
	}
	
	if (!bIsSpaceFree)
	{
		PrintToChat(client, "[VEHICLE] Find free space.");
		return;
	}*/
/*
	if (!g_bIsSpaceFree)
	{
		PrintToChat(client, "[VEHICLE] Find free space.");
		return;
	}
*/
	Handle hTrace = TR_TraceRayFilterEx(origin, eyeangles, MASK_SOLID, RayType_Infinite, Filter_ClientSelf, client);
	if (TR_DidHit(hTrace))
	{
		TR_GetEndPosition(endpos, hTrace);
		distance = GetVectorDistance(origin, endpos);
	}

	CloseHandle(hTrace);
	
	if (distance < 300)
	{
		PrintToChat(client, "[VEHICLE] Find more space to spawn vehicle.");
		//PrintToChat(client, "[VEHICLE] Find more space to spawn vehicle. Distance: %.1f", distance);
		return;
	}
	
	eyeangles[1] += 90.0;

	hTrace = TR_TraceRayFilterEx(origin, eyeangles, MASK_SOLID, RayType_Infinite, Filter_ClientSelf, client);
	if (TR_DidHit(hTrace))
	{
		TR_GetEndPosition(endpos, hTrace);
		distance = GetVectorDistance(origin, endpos);
	}
	
	CloseHandle(hTrace);

	if (distance < 96)
	{
		PrintToChat(client, "[VEHICLE] Find more space to spawn vehicle.");
		return;
	}

	eyeangles[1] -= 180.0;

	hTrace = TR_TraceRayFilterEx(origin, eyeangles, MASK_SOLID, RayType_Infinite, Filter_ClientSelf, client);
	if (TR_DidHit(hTrace))
	{
		TR_GetEndPosition(endpos, hTrace);
		distance = GetVectorDistance(origin, endpos);
	}
	
	CloseHandle(hTrace);

	if (distance < 96)
	{
		PrintToChat(client, "[VEHICLE] Find more space to spawn vehicle.");
		return;
	}

	int ent = CreateEntityByName(aValues.classname);
	if (ent != -1)
	{
		DispatchKeyValueVector(ent, "origin", spawnorigin);
		DispatchKeyValueVector(ent, "angles", spawnangles);
		DispatchKeyValue(ent, "targetname", targetname);
		DispatchKeyValue(ent, "model", aValues.model);
		DispatchKeyValue(ent, "vehiclescript", aValues.vehiclescript);

		if (skin[0] != '\0')
			DispatchKeyValue(ent, "skin", skin);

		DispatchSpawn(ent);
		ActivateEntity(ent);
		
		//SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);

		//TeleportEntity(ent, spawnorigin, spawnangles, NULL_VECTOR)

		if (aValues.setuser)
		{
			SetVariantInt(client);
			AcceptEntityInput(ent, "SetUser");
		}
		
	//	int block = GetEntData(ent, g_iCollisionGroup, 4);
	//	PrintToConsole(client, "[VEHICLE] %s block: %i", aValues.classname, block);
		
		//SetEntData(ent, g_iCollisionGroup, 5, 4, true);
		//HookSingleEntityOutput(ent, "PlayerOn", OutputHook_PlayerOn, true);
	}
}

public bool Filter_ClientSelf(int entity, int contentsMask, any client)
{
	if (entity != client)
		return true;

	return false;
}

public void OutputHook_PlayerOn(const char[] output, int caller, int activator, float delay)
{
	SetEntData(caller, g_iCollisionGroup, 7, 4, true);
}
/*
public void OutputHook_OnStartTouch(const char[] output, int caller, int activator, float delay)
{
//	PrintToChat(activator, "[VEHICLE] Find free space.");
	
	g_bIsSpaceFree = false;
}
*/
public Action Command_AirboatGunToggle(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[VEHICLE] Usage: sm_vehiclegun <1/0>");
		return Plugin_Handled;
	}

	char strnum[3];
	GetCmdArg(1, strnum, sizeof(strnum));
	int num = StringToInt(strnum);

	if (num != 0 && num != 1)
	{
		ReplyToCommand(client, "[VEHICLE] Usage: sm_airboatgun <1/0>");
		return Plugin_Handled;
	}

	int index = -1;

	while ((index = FindEntityByClassname(index, "prop_vehicle_airboat")) != -1)
	{
		SetVariantInt(num);
		AcceptEntityInput(index, "EnableGun");
		PrintToConsole(client, "[VEHICLE] index: %d, input: EnableGun %d", index, num);
	}

	while ((index = FindEntityByClassname(index, "prop_vehicle_jeep*")) != -1)
	{
		SetVariantInt(num);
		AcceptEntityInput(index, "EnableGun");
		PrintToConsole(client, "[VEHICLE] index: %d, input: EnableGun %d", index, num);
	}
	
	LogMessage("[VEHICLE] %N %s gun", client, (num == 1) ? "enabled" : "disabled");

	return Plugin_Handled;
}

public Action Command_VehicleMenu(int client, int args)
{
	if (!client)
		return Plugin_Handled;
	
	if (!g_bIsVehicleMap)
	{
		ReplyToCommand(client, "[VEHICLE] Vehicles are not allowed on this map.");
		return Plugin_Handled;
	}

	float curtime = GetTickedTime();
	float elapsedtime = curtime - g_flLastUsed[client];
	float minfrequency = g_Cvar_VehicleSpawnTime.FloatValue;

	if (elapsedtime < minfrequency)
	{
		ReplyToCommand(client, "[VEHICLE] Please wait another %.3f seconds before open vehicle menu.", minfrequency - elapsedtime);		
		return Plugin_Handled;
	}
	
	g_flLastUsed[client] = curtime;
	
	ShowMenu(client);

	return Plugin_Handled;
}


void ShowMenu(int client)
{
	Menu menu = new Menu(HandleMenu);
	char display[32];
	
	menu.SetTitle("Vehicles:");

	strcopy(display, sizeof(display), "Airboat");
	menu.AddItem("1", display);

	strcopy(display, sizeof(display), "1-Seat Jeep");
	menu.AddItem("2", display);

	strcopy(display, sizeof(display), "7-Seat Van");
	menu.AddItem("3", display);
	
	strcopy(display, sizeof(display), "8-Seat Truck");
	menu.AddItem("4", display);

	strcopy(display, sizeof(display), "2-Seat Jeep");
	menu.AddItem("5", display);

//	char info[2];
//	strcopy(info, sizeof(info), "6");
	if (g_bAllowJalopy)
	{
		strcopy(display, sizeof(display), "Jalopy");
		menu.AddItem("6", display);
	}

//	strcopy(display, sizeof(display), "2-Seat Elite Jeep");
//	menu.AddItem(info, display);

/*	if (FileExists("scripts/vehicles/puzzleairboatold.txt", true))
	{
		strcopy(display, sizeof(display), "Puzzle Airboat");
		menu.AddItem(info, display);

		strcopy(info, sizeof(info), "7");
	}*/

	strcopy(display, sizeof(display), "Remove");
	menu.AddItem("9", display);

	menu.Pagination = MENU_NO_PAGINATION;
	menu.ExitButton = true;

	menu.Display(client, MENU_TIME_FOREVER);
}
	
public int HandleMenu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char info[2];
		bool found = menu.GetItem(param, info, sizeof(info));
		if (found && IsClientInGame(client))
		{
			float curtime = GetTickedTime();
			float elapsedtime = curtime - g_flLastUsed[client];
			float minfrequency = g_Cvar_VehicleSpawnTime.FloatValue;

			if (elapsedtime < minfrequency)
				ReplyToCommand(client, "[VEHICLE] Please wait another %.3f seconds before spawn vehicle.", minfrequency - elapsedtime);
			else
			{
				g_flLastUsed[client] = curtime;

				SpawnVehicle(client, GetMenuVehicle(StringToInt(info)));
			}
			
			if (PlayerSpawned(client))
			{
				//menu.Display(client, MENU_TIME_FOREVER);
				ShowMenu(client);
			}
		}
	}
	else if (action == MenuAction_End)
	{
	/*	if (client > 0)
			PrintToChat(client, "client: %i, param: %i", client, param);
		else
			PrintToServer("client: %i, param: %i", client, param);*/
			
		/*if (client != 0)
			delete menu;*/
		
		delete menu;
	}
	
	return 0;
}

char[] GetMenuVehicle(int selection)
{
	char name[16];
	switch (selection)
	{
		case 1:
		{
			if (g_bIsPuzzleMap)
				strcopy(name, sizeof(name), "puzzleairboat");
			else
				strcopy(name, sizeof(name), "airboat");
		}
		case 2: strcopy(name, sizeof(name), "jeep");
		case 3: strcopy(name, sizeof(name), "van");
		case 4: strcopy(name, sizeof(name), "truck");
		case 5: strcopy(name, sizeof(name), "jeep2p"); 
		case 6: strcopy(name, sizeof(name), "jalopy");
	//	case 7: strcopy(name, sizeof(name), "jeepelite");
		case 9: strcopy(name, sizeof(name), "remove");
	//	default: strcopy(name, sizeof(name), "");
	}
	
	return name;
}

public Action Command_RemoveVehicles(int client, int args)
{
	ArrayList hPlayerVehice = new ArrayList();
	int clientvehicle;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!PlayerSpawned(i))
			continue;

		clientvehicle = Client_GetVehicle(i);
		if (clientvehicle == -1)
			continue;

		if (AcceptEntityInput(clientvehicle, "ExitVehicle"))
		{
			PrintToChat(i, "[VEHICLE] Get out!");
			continue;
		}
		
/*		if (Syn_ExitVehicle(i))
		{
			PrintToChat(i, "[VEHICLE] Get out!");
			continue;
		}*/
		
/*		Syn_LeaveVehicle(i);
		clientvehicle = Client_GetVehicle(i);
		if (clientvehicle == -1)
		{
			PrintToChat(i, "[VEHICLE] Get out!");
			continue;
		}*/

		hPlayerVehice.Push(clientvehicle);
	}

	int index = -1;
	char vehiclename[32];
	while ((index = FindEntityByClassname(index, "prop_vehicle_*")) != -1)
	{
		GetEntPropString(index, Prop_Data, "m_iName", vehiclename, sizeof(vehiclename));
		
		if (strncmp(vehiclename, "custom_vehicle_", 15) != 0)
			continue;

		if (hPlayerVehice.Length && hPlayerVehice.FindValue(index) != -1)
			continue;
		
		AcceptEntityInput(index, "Kill");
	}
	
	delete hPlayerVehice;

	return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (strcmp(sArgs, "votecar", false) == 0 || strcmp(sArgs, "!votecar", false) == 0)
	{
		if (!g_bIsVehicleMap)
		{
			PrintToChat(client, "[VEHICLE] Vehicles are not allowed on this map.");
			return Plugin_Handled;
		}

		PrintToChat(client, "[VEHICLE] Say !car or !vehicle.");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

/*
stock FindEntityByClassname2(int startEnt, const char[] classname)
{
	// If startEnt isn't valid shifting it back to the nearest valid one
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--

	return FindEntityByClassname(startEnt, classname)
}
*/

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

stock bool PlayerSpawned(int client)
{
	if (IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))
		return true;

	return false;
}

stock int Client_GetVehicle(int client)
{
	int m_hVehicle = GetEntPropEnt(client, Prop_Send, "m_hVehicle");

	return m_hVehicle;
}

stock bool Client_IsInVehicle(int client)
{
	return !(Client_GetVehicle(client) == -1);
}

stock int Vehicle_GetDriver(int vehicle)
{
	int m_hVehicle = GetEntPropEnt(vehicle, Prop_Send, "m_hPlayer");

	return m_hVehicle;
}

stock bool Vehicle_HasDriver(int vehicle)
{
	return !(Vehicle_GetDriver(vehicle) == -1);
}

stock bool IsVehicleOnMap()
{
	if (FindEntityByClassname(-1, "prop_vehicle_jeep*") != -1)
		return true;

	if (FindEntityByClassname(-1, "prop_vehicle_mp") != -1)
		return true;
	
	return false;
}

