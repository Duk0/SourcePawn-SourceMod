#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>


#define PLUGIN_NAME		 	"stuck"
#define PLUGIN_AUTHOR	   	"Erreur 500"
#define PLUGIN_DESCRIPTION	"Fix stuck players"
#define PLUGIN_VERSION	  	"1.3"
#define PLUGIN_CONTACT	  	"erreur500@hotmail.fr"

int TimeLimit;
int Counter[MAXPLAYERS+1] 		= {0, ...};
int StuckCheck[MAXPLAYERS+1] 	= {0, ...};
int Countdown[MAXPLAYERS+1] 	= {0, ...};

bool isStuck[MAXPLAYERS+1];

float Step;
float RadiusSize;
float Ground_Velocity[3] = {0.0, 0.0, -300.0};

ConVar c_Limit;
ConVar c_Countdown;
ConVar c_Radius;
ConVar c_Step;


public Plugin myinfo =
{
	name		= PLUGIN_NAME,
	author	  	= PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version	 	= PLUGIN_VERSION,
	url		 	= PLUGIN_CONTACT
};

public void OnPluginStart()
{
	CreateConVar("stuck_version", PLUGIN_VERSION, "Stuck version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	c_Limit		= CreateConVar("stuck_limit", 				"1", 	"How many !stuck can a player use ? (0 = no limit)", 0, true, 0.0);
	c_Countdown	= CreateConVar("stuck_wait", 				"60", 	"Time to wait before earn new !stuck.", 0, true, 0.0);
	c_Radius	= CreateConVar("stuck_radius", 				"200", 	"Radius size to fix player position.", 0, true, 10.0);
	c_Step		= CreateConVar("stuck_step", 				"20", 	"Step between each position tested.", 0, true, 1.0);
	
	AutoExecConfig(true, "stuck");
	
	c_Countdown.AddChangeHook(CallBackCVarCountdown);
	c_Radius.AddChangeHook(CallBackCVarRadius);
	c_Step.AddChangeHook(CallBackCVarStep);
	
	TimeLimit = c_Countdown.IntValue;
	if (TimeLimit < 0)
		TimeLimit = -TimeLimit;
		
	RadiusSize = c_Radius.IntValue * 1.0;
	if (RadiusSize < 10.0)
		RadiusSize = 10.0;
		
	Step = c_Step.IntValue * 1.0;
	if (Step < 1.0)
		Step = 1.0;
	
	RegConsoleCmd("stuck", StuckCmd, "Are you stuck ?");
	RegConsoleCmd("unstuck", StuckCmd, "Are you stuck ?");
	
	CreateTimer(1.0, Timer, INVALID_HANDLE, TIMER_REPEAT);
}

public void OnMapStart() 
{
	for (int i = 1; i <= MaxClients; i++)
		Counter[i] = 0;
}

public void CallBackCVarCountdown(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	TimeLimit = StringToInt(newVal);
	if (TimeLimit < 0)
		TimeLimit = -TimeLimit;
		
	LogMessage("stuck_wait = %i", TimeLimit);
}

public void CallBackCVarRadius(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	RadiusSize = StringToInt(newVal) * 1.0;
	if (RadiusSize < 10.0)
		RadiusSize = 10.0;
	
	LogMessage("stuck_radius = %f", RadiusSize);
}

public void CallBackCVarStep(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	Step = StringToInt(newVal) * 1.0;
	if (Step < 1.0)
		Step = 1.0;
		
	LogMessage("stuck_step = %f", Step);
}

stock bool IsValidClient(int iClient)
{
	if (iClient <= 0) return false;
	if (iClient > MaxClients) return false;
	return IsClientInGame(iClient);
}

public Action Timer(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;
	
		if (Counter[i] > 0)
		{
			Countdown[i]++;
			if (Countdown[i] >= TimeLimit)
			{
				Countdown[i] = 0;
				Counter[i]--;
			}
		}
		else if (Counter[i] == 0 && Countdown[i] != 0)
			Countdown[i] = 0;
	}
	
	return Plugin_Continue;
}

public Action StuckCmd(int iClient, int Args)
{
	if (!IsValidClient(iClient)) return Plugin_Handled;

	if (!IsPlayerAlive(iClient))
	{
		PrintToChat(iClient, "[!stuck] How a death can be stuck !?");
		return Plugin_Handled;
	}

	if (Client_IsInVehicle(iClient))
		return Plugin_Handled;

	if (PlayerReachChangeLevel(iClient))
		return Plugin_Handled;
	
	if (c_Limit.IntValue > 0 && Counter[iClient] >= c_Limit.IntValue)
	{
		PrintToChat(iClient, "[!stuck] Sorry, you must wait %i seconds before use this command again.", TimeLimit - Countdown[iClient]);
		return Plugin_Handled;
	}
	
	Counter[iClient]++;
	StuckCheck[iClient] = 0;
	StartStuckDetection(iClient);
	
	return Plugin_Handled;
}

stock int Client_GetVehicle(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hVehicle");
}

stock bool Client_IsInVehicle(int client)
{
	return !(Client_GetVehicle(client) == -1);
}

stock bool PlayerReachChangeLevel(int client)
{
	int flags = GetEntityFlags(client);
	if (GetEntityRenderMode(client) == RENDER_TRANSALPHA && GetEntityRenderFx(client) == RENDERFX_DISTORT &&
		flags & FL_FROZEN && flags & FL_GODMODE && flags & FL_NOTARGET)
	{
		return true;
	}

	return false;
}

void StartStuckDetection(int iClient)
{
	StuckCheck[iClient]++;
	isStuck[iClient] = false;
	isStuck[iClient] = CheckIfPlayerIsStuck(iClient); // Check if player stuck in prop
	CheckIfPlayerCanMove(iClient, 0, 500.0, 0.0, 0.0);
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Stuck Detection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


stock bool CheckIfPlayerIsStuck(int iClient)
{
	float vecMin[3], vecMax[3], vecOrigin[3];
	
	GetClientMins(iClient, vecMin);
	GetClientMaxs(iClient, vecMax);
	GetClientAbsOrigin(iClient, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceEntityFilterSolid);
	return TR_DidHit();	// head in wall ?
}


public bool TraceEntityFilterSolid(int entity, int contentsMask) 
{
	return entity > 1;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									More Stuck Detection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


stock void CheckIfPlayerCanMove(int iClient, int testID, float X = 0.0, float Y = 0.0, float Z = 0.0)	// In few case there are issues with IsPlayerStuck() like clip
{
	float vecVelo[3];
	float vecOrigin[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	
	vecVelo[0] = X;
	vecVelo[1] = Y;
	vecVelo[2] = Z;
	
	SetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", vecVelo);
	
	DataPack TimerDataPack;
	CreateDataTimer(0.1, TimerWait, TimerDataPack, TIMER_FLAG_NO_MAPCHANGE);
	//DataPack TimerDataPack = new DataPack();
	//CreateTimer(0.1, TimerWait, TimerDataPack, TIMER_FLAG_NO_MAPCHANGE); 
	TimerDataPack.WriteCell(iClient);
	TimerDataPack.WriteCell(testID);
	TimerDataPack.WriteFloat(vecOrigin[0]);
	TimerDataPack.WriteFloat(vecOrigin[1]);
	TimerDataPack.WriteFloat(vecOrigin[2]);
}

public Action TimerWait(Handle timer, DataPack data)
{	
	float vecOrigin[3];
	float vecOriginAfter[3];
	
	data.Reset(false);
	int iClient 		= data.ReadCell();
	int testID 			= data.ReadCell();
	vecOrigin[0]		= data.ReadFloat();
	vecOrigin[1]		= data.ReadFloat();
	vecOrigin[2]		= data.ReadFloat();
//	delete data;

	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient)) return Plugin_Stop;
	
	GetClientAbsOrigin(iClient, vecOriginAfter);
	
	if (GetVectorDistance(vecOrigin, vecOriginAfter, false) < 10.0) // Can't move
	{
		if (testID == 0)
			CheckIfPlayerCanMove(iClient, 1, 0.0, 0.0, -500.0);	// Jump
		else if (testID == 1)
			CheckIfPlayerCanMove(iClient, 2, -500.0, 0.0, 0.0);
		else if (testID == 2)
			CheckIfPlayerCanMove(iClient, 3, 0.0, 500.0, 0.0);
		else if (testID == 3)
			CheckIfPlayerCanMove(iClient, 4, 0.0, -500.0, 0.0);
		else if (testID == 4)
			CheckIfPlayerCanMove(iClient, 5, 0.0, 0.0, 300.0);
		else
			FixPlayerPosition(iClient);
	}
	else
	{
		if (StuckCheck[iClient] < 2)
			PrintToChat(iClient, "[!stuck] Well Tried, but you are not stuck!");
		else
			PrintToChat(iClient, "[!stuck] Done!", StuckCheck[iClient]);
	}
	
	return Plugin_Stop;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Fix Position
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


void FixPlayerPosition(int iClient)
{
	if (isStuck[iClient]) // UnStuck player stuck in prop
	{
		float pos_Z = 0.1;
		
		while (pos_Z <= RadiusSize && !TryFixPosition(iClient, 10.0, pos_Z))
		{	
			pos_Z = -pos_Z;
			if (pos_Z > 0.0)
				pos_Z += Step;
		}
		
		if (!CheckIfPlayerIsStuck(iClient) && StuckCheck[iClient] < 7) // If client was stuck => new check
			StartStuckDetection(iClient);
		else
			PrintToChat(iClient, "[!stuck] Sorry, I'm not able to fix your position.");
	
	}
	else // UnStuck player stuck in clip (invisible wall)
	{
		// if it is a clip on the sky, it will try to find the ground !
		float vecOrigin[3];
		float vecAngle[3];
		
		GetClientAbsOrigin(iClient, vecOrigin);
		vecAngle[0] = 90.0;
		Handle trace = TR_TraceRayFilterEx(vecOrigin, vecAngle, MASK_SOLID, RayType_Infinite, TraceEntityFilterSolid);		
		if (!TR_DidHit(trace)) 
		{
			CloseHandle(trace);
			return;
		}
		
		TR_GetEndPosition(vecOrigin, trace);
		CloseHandle(trace);
		vecOrigin[2] += 10.0;
		TeleportEntity(iClient, vecOrigin, NULL_VECTOR, Ground_Velocity);
		
		if (StuckCheck[iClient] < 7) // If client was stuck in invisible wall => new check
			StartStuckDetection(iClient);
		else
			PrintToChat(iClient, "[!stuck] Sorry, I'm not able to fix your position.");
	}
}

bool TryFixPosition(int iClient, float Radius, float pos_Z)
{
	float DegreeAngle;
	float vecPosition[3];
	float vecOrigin[3];
	float vecAngle[3];
	
	GetClientAbsOrigin(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngle);
	vecPosition[2] = vecOrigin[2] + pos_Z;

	DegreeAngle = -180.0;
	while (DegreeAngle < 180.0)
	{
		vecPosition[0] = vecOrigin[0] + Radius * Cosine(DegreeAngle * FLOAT_PI / 180); // convert angle in radian
		vecPosition[1] = vecOrigin[1] + Radius * Sine(DegreeAngle * FLOAT_PI / 180);
		
		TeleportEntity(iClient, vecPosition, vecAngle, Ground_Velocity);
		if (!CheckIfPlayerIsStuck(iClient))
			return true;
		
		DegreeAngle += 10.0; // + 10°
	}
	
	TeleportEntity(iClient, vecOrigin, vecAngle, Ground_Velocity);
	if (Radius <= RadiusSize)
		return TryFixPosition(iClient, Radius + Step, pos_Z);
	
	return false;
}
