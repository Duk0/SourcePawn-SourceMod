#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[ASW] Max entity info",
	author = "Duko",
	description = "Max entity info",
	version = "1.0",
	url = "http://group.midu.cz"
};

int g_iMaxEntities;

public void OnPluginStart()
{
	g_iMaxEntities = GetMaxEntities();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "asw_laser_mine", false))
	{
		int iEntityCount = GetEntityCount();
		if (g_iMaxEntities < iEntityCount + 64)
		{
			AcceptEntityInput(entity, "Kill");
			PrintToServer("[MEI] Killed entity: %i, classname: %s, iEntityCount: %i, g_iMaxEntities: %i", entity, classname, iEntityCount, g_iMaxEntities);
		}
	}
}
