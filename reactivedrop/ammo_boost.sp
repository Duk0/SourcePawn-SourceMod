#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "[ASW] Ammo Boost",
	author = "Duko",
	description = "Ammo Boost",
	version = "1.0",
	url = "http://group.midu.cz"
}

int g_iClip1Offset, g_iClip2Offset;

ConVar g_Cvar_MaxAsw_ag;
ConVar g_Cvar_MaxAsw_ext;
ConVar g_Cvar_MaxAsw_f;
ConVar g_Cvar_MaxAsw_medkit;
ConVar g_Cvar_MaxAsw_medself;
ConVar g_Cvar_MaxAsw_mines;
ConVar g_Cvar_MaxAsw_ml;
ConVar g_Cvar_MaxAsw_pdw;
ConVar g_Cvar_MaxAsw_p;
ConVar g_Cvar_MaxAsw_r_g;
//ConVar g_Cvar_MaxAsw_stim;
ConVar g_Cvar_MaxAsw_r;
ConVar g_Cvar_MaxAsw_sg;
ConVar g_Cvar_MaxAsw_asg;
ConVar g_Cvar_MaxAsw_ammosat;

public void OnPluginStart()
{
	g_iClip1Offset = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	g_iClip2Offset = FindSendPropInfo("CBaseCombatWeapon", "m_iClip2");

	if (g_iClip1Offset <= 0 || g_iClip2Offset <= 0)
		SetFailState("Can't find offset. Please contact the author.");

	g_Cvar_MaxAsw_ag = FindConVar("sk_max_asw_ag");
	g_Cvar_MaxAsw_ext = FindConVar("sk_max_asw_ext");
	g_Cvar_MaxAsw_f = FindConVar("sk_max_asw_f");
	g_Cvar_MaxAsw_medkit = FindConVar("sk_max_asw_medkit");
	g_Cvar_MaxAsw_medself = FindConVar("sk_max_asw_medself");
	g_Cvar_MaxAsw_mines = FindConVar("sk_max_asw_mines");
	g_Cvar_MaxAsw_ml = FindConVar("sk_max_asw_ml");
	g_Cvar_MaxAsw_pdw = FindConVar("sk_max_asw_pdw");
	g_Cvar_MaxAsw_p = FindConVar("sk_max_asw_p");
	g_Cvar_MaxAsw_r_g = FindConVar("sk_max_asw_r_g");
	g_Cvar_MaxAsw_r = FindConVar("sk_max_asw_r");
	//g_Cvar_MaxAsw_stim = FindConVar("sk_max_asw_stim");
	g_Cvar_MaxAsw_sg = FindConVar("sk_max_asw_sg");
	g_Cvar_MaxAsw_asg = FindConVar("sk_max_asw_asg");
	g_Cvar_MaxAsw_ammosat = CreateConVar("sk_max_asw_ammosat", "24");
}

public void OnMapStart()
{
	int index = -1;
	char classname[32];
	int cvarclips;
	//char clips[4];

	while ((index = FindEntityByClassname(index, "asw_pickup_*")) != -1)
	{
		GetEdictClassname(index, classname, sizeof(classname));
		if (strcmp(classname, "asw_pickup_autogun") == 0)
		{
			cvarclips = g_Cvar_MaxAsw_ag.IntValue / 250;
		}
		else if (strcmp(classname, "asw_pickup_fire_extinguisher") == 0)
		{
			cvarclips = g_Cvar_MaxAsw_ext.IntValue / 200;
		}
		else if (strcmp(classname, "asw_pickup_flamer") == 0)
		{
			cvarclips = g_Cvar_MaxAsw_f.IntValue / 40;
		}
		else if (strcmp(classname, "asw_pickup_mining_laser") == 0)
		{
			cvarclips = g_Cvar_MaxAsw_ml.IntValue / 50;
		}
		else if (strcmp(classname, "asw_pickup_pdw") == 0)
		{
			cvarclips = g_Cvar_MaxAsw_pdw.IntValue / 80;
		}
		else if (strcmp(classname, "asw_pickup_pistol") == 0)
		{
			cvarclips = g_Cvar_MaxAsw_p.IntValue / 24;
		}
		else if (strcmp(classname, "asw_pickup_prifle") == 0)
		{
			cvarclips = g_Cvar_MaxAsw_r.IntValue / 98;
		}
		else if (strcmp(classname, "asw_pickup_rifle") == 0)
		{
			cvarclips = g_Cvar_MaxAsw_r.IntValue / 98;
		}
		else if (strcmp(classname, "asw_pickup_shotgun") == 0)
		{
			cvarclips = g_Cvar_MaxAsw_sg.IntValue / 4;
		}
		else if (strcmp(classname, "asw_pickup_vindicator") == 0)
		{
			cvarclips = g_Cvar_MaxAsw_asg.IntValue / 14;
		}
		else
		{
			continue;
		}

		if (GetEntProp(index, Prop_Send, "m_iClips") < cvarclips)
		{
			//IntToString(cvarclips, clips, sizeof(clips));
			//DispatchKeyValue(index, "Clips", clips);
			SetEntProp(index, Prop_Send, "m_iClips", cvarclips);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > MaxClients)
	{
		if (strncmp(classname, "asw_weapon_", 11) == 0)
			CreateTimer(0.1, AmmoTimer, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action AmmoTimer(Handle timer, any ref)
{
	int weapon = EntRefToEntIndex(ref);

	if (weapon == INVALID_ENT_REFERENCE)
		return Plugin_Stop;

	if (!IsValidEdict(weapon))
		return Plugin_Stop;

	char classname[32];
	GetEdictClassname(weapon, classname, sizeof(classname));
	if (strcmp(classname, "asw_weapon_ammo_satchel") == 0)
	{
		//SetEntProp(weapon, Prop_Data, "m_iClip1", g_Cvar_MaxAsw_ammosat.IntValue);
		SetEntData(weapon, g_iClip1Offset, g_Cvar_MaxAsw_ammosat.IntValue, 1, true);
	}
	else if (strcmp(classname, "asw_weapon_heal_gun") == 0)
	{
		//SetEntProp(weapon, Prop_Data, "m_iClip1", g_Cvar_MaxAsw_medself.IntValue);
		SetEntData(weapon, g_iClip1Offset, g_Cvar_MaxAsw_medself.IntValue, 2, true);
	}
	else if (strcmp(classname, "asw_weapon_laser_mines") == 0)
	{
		//SetEntProp(weapon, Prop_Data, "m_iClip1", g_Cvar_MaxAsw_mines.IntValue);
		SetEntData(weapon, g_iClip1Offset, g_Cvar_MaxAsw_mines.IntValue, 1, true);
	}
	else if (strcmp(classname, "asw_weapon_medkit") == 0)
	{
		//SetEntProp(weapon, Prop_Data, "m_iClip1", g_Cvar_MaxAsw_medkit.IntValue);
		SetEntData(weapon, g_iClip1Offset, g_Cvar_MaxAsw_medkit.IntValue, 1, true);
	}
	else if (strcmp(classname, "asw_weapon_rifle") == 0)
	{
		//SetEntProp(weapon, Prop_Data, "m_iClip2", g_Cvar_MaxAsw_r_g.IntValue);
		SetEntData(weapon, g_iClip2Offset, g_Cvar_MaxAsw_r_g.IntValue, 1, true);
	}
	else if (strcmp(classname, "asw_weapon_prifle") == 0)
	{
		//SetEntProp(weapon, Prop_Data, "m_iClip2", g_Cvar_MaxAsw_r_g.IntValue);
		SetEntData(weapon, g_iClip2Offset, g_Cvar_MaxAsw_r_g.IntValue, 1, true);
	}
	else if (strcmp(classname, "asw_weapon_vindicator") == 0)
	{
		//SetEntProp(weapon, Prop_Data, "m_iClip2", g_Cvar_MaxAsw_r_g.IntValue);
		SetEntData(weapon, g_iClip2Offset, g_Cvar_MaxAsw_r_g.IntValue, 1, true);
	}
/*
	else if (strncmp(classname, "asw_weapon_sentry", 17) == 0)
	{
		SetEntData(weapon, g_iClip1Offset, 111, 2, true);
	}
*/
	return Plugin_Stop;
}