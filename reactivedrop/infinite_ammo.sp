#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Infinite Ammo",
	author = "Duko",
	description = "Infinite Ammo",
	version = "1.0",
	url = "http://group.midu.cz"
};

ConVar g_Cvar_SMInfAmmo;
int g_iClip1Ammo, g_iClip2Ammo, g_iWeaponOwner, g_iAmmoOffset;
bool g_bIAmmoEnabled = false;
bool g_bWasCheatFlag = false;
int g_iFlags;

enum AmmoType
{
	Ammo_RailGun = 12
}

public void OnPluginStart()
{
	g_iClip1Ammo = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	g_iClip2Ammo = FindSendPropInfo("CBaseCombatWeapon", "m_iClip2");
	g_iWeaponOwner = FindSendPropInfo("CBaseCombatWeapon", "m_hOwner");
	g_iAmmoOffset = FindSendPropInfo("CASW_Marine", "m_iAmmo");

	if (g_iClip1Ammo <= 0 || g_iClip2Ammo <= 0 || g_iWeaponOwner <= 0 || g_iAmmoOffset <= 0)
		SetFailState("* FATAL ERROR: Failed to get some offset");

	g_Cvar_SMInfAmmo = CreateConVar("sm_infinite_ammo", "0", _, 0, true, 0.0, true, 2.0);
	g_Cvar_SMInfAmmo.AddChangeHook(InfiniteAmmoTest);
	
	
	g_iFlags = GetCommandFlags("asw_gimme_ammo");
	if (g_iFlags != INVALID_FCVAR_FLAGS && g_iFlags & FCVAR_CHEAT)
		g_bWasCheatFlag = true;
}

public void GiveAmmoEvent(Handle event, const char[] name, bool dontBroadcast)
{
	ServerCommand("asw_gimme_ammo");
}

public void InfiniteAmmoTest(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int new_value = StringToInt(newValue);
	if (new_value == 2)
	{
		if (g_bWasCheatFlag && g_iFlags != INVALID_FCVAR_FLAGS && g_iFlags & FCVAR_CHEAT)
			SetCommandFlags("asw_gimme_ammo", g_iFlags & ~FCVAR_CHEAT);

		HookEvent("marine_no_ammo", GiveAmmoEvent);
	}
	else
	{	
		if (StringToInt(oldValue) == 2)
		{
			UnhookEvent("marine_no_ammo", GiveAmmoEvent);

			if (g_bWasCheatFlag && g_iFlags != INVALID_FCVAR_FLAGS && g_iFlags & ~FCVAR_CHEAT)
				SetCommandFlags("asw_gimme_ammo", g_iFlags | FCVAR_CHEAT);
		}

		g_bIAmmoEnabled = view_as<bool>(new_value);
		if (g_bIAmmoEnabled)
		{
			CreateTimer(0.1, GiveAmmoLoop, _, TIMER_REPEAT);
		}
	}
}

public Action GiveAmmoLoop(Handle timer)
{
	if (!g_bIAmmoEnabled)
		return Plugin_Stop;
	
	int index = -1;
	char classname[24];
	int clippri, clipsec;
	int owner;
	while ((index = FindEntityByClassname(index, "asw_weapon_*")) != -1)
	{
		owner = GetEntDataEnt2(index, g_iWeaponOwner);
		if (owner == -1)
			continue;

		GetEdictClassname(index, classname, sizeof(classname));
		if (strcmp(classname, "asw_weapon_railgun") == 0)
		{
			if (!IsValidEdict(owner))
				continue;

			if (GetEntData(owner, g_iAmmoOffset + (view_as<int>(Ammo_RailGun) * 4)) < 10)
				SetEntData(owner, g_iAmmoOffset + (view_as<int>(Ammo_RailGun) * 4), 72);

			continue;
		}

		clippri = GetEntData(index, g_iClip1Ammo, 2);
		if (clippri != -1 && clippri < 10)
			SetEntData(index, g_iClip1Ammo, 250, 2, true);

		clipsec = GetEntData(index, g_iClip2Ammo, 2);
		if (clipsec != -1 && clipsec < 2)
			SetEntData(index, g_iClip2Ammo, 9, 2, true);
	}
	
	return Plugin_Continue;
}
