#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION "1.0.0"

// m_lifeState values
#define	LIFE_ALIVE				0 // alive
#define	LIFE_DYING				1 // playing death animation or still falling off of a ledge waiting to hit ground
#define	LIFE_DEAD				2 // dead. lying still.
#define LIFE_RESPAWNABLE		3
#define LIFE_DISCARDBODY		4

public Plugin myinfo = {
	name = "Synergy Tools",
	author = "Duko",
	description = "Usefull tools for Synergy",
	version = VERSION,
	url = "http://group.midu.cz"
};

Handle g_hIsAlive = null;
Handle g_hIsNPC = null;
Handle g_hIsMoving = null;
Handle g_hFVisible = null;
Handle g_hFVisibleEx = null;
Handle g_hIRelationType = null;
Handle g_hIRelationPriority = null;
Handle g_hIsInAVehicle = null;
Handle g_hExitVehicle = null;
Handle g_hStartObserverMode = null;
Handle g_hSetObserverMode = null;
Handle g_hGetObserverMode = null;
Handle g_hSetObserverTarget = null;
Handle g_hGetObserverTarget = null;
Handle g_hIsValidObserverTarget = null;
Handle g_hForceObserverMode = null;
Handle g_hValidateCurrentObserverTarget = null;
Handle g_hLeaveVehicle = null;

int g_iLifeState;

StringMap g_hFormatNames = null;
StringMap g_hFormatNamesEx = null;

//ArrayList g_hKeyNames = null;

enum struct EntityInfo
{
	char ei_name[32];
	int ei_size;
	ArrayList ei_names;
	ArrayList ei_keys;
	ArrayList ei_values;
	ArrayList ei_section;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char game[32];
	GetGameFolderName(game, sizeof(game));
	if (strcmp(game, "synergy") != 0)
	{
		strcopy(error, err_max, "This plugin is only supported on Synergy");
		return APLRes_Failure;
	}

	CreateNative("Syn_IsAlive", IsAlive);
	CreateNative("Syn_IsNPC", IsNPC);
	CreateNative("Syn_IsMoving", IsMoving);
	CreateNative("Syn_FVisible", FVisible);
	CreateNative("Syn_FVisibleEx", FVisibleEx);
	CreateNative("Syn_IRelationType", IRelationType);
	CreateNative("Syn_IRelationPriority", IRelationPriority);
	CreateNative("Syn_IsInAVehicle", IsInAVehicle);
	CreateNative("Syn_ExitVehicle", ExitVehicle);
	CreateNative("Syn_StartObserverMode", StartObserverMode);
	CreateNative("Syn_SetObserverMode", SetObserverMode);
	CreateNative("Syn_GetObserverMode", GetObserverMode);
	CreateNative("Syn_SetObserverTarget", SetObserverTarget);
	CreateNative("Syn_GetObserverTarget", GetObserverTarget);
	CreateNative("Syn_IsValidObserverTarget", IsValidObserverTarget);
	CreateNative("Syn_ForceObserverMode", ForceObserverMode);
	CreateNative("Syn_ValidateCurrentObserverTarget", ValidateCurrentObserverTarget);
	CreateNative("Syn_LeaveVehicle", LeaveVehicle);
	CreateNative("Syn_IsDead", IsDead);

	CreateNative("Syn_NpcFormatedName", NpcFormatedName);
	CreateNative("Syn_NpcFormatedNameEx", NpcFormatedNameEx);

	RegPluginLibrary("syntools");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("syntools_version", VERSION, _, FCVAR_NOTIFY);

	Handle hGameConfig = null;
	if ((hGameConfig = LoadGameConfigFile("syntools.games")) == null)
		SetFailState("Could not find gamedata/syntools.games.txt");

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBaseEntity::IsAlive");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hIsAlive = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBaseEntity::IsNPC");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hIsNPC = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBaseEntity::IsMoving");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hIsMoving = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBaseCombatCharacter::FVisible");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hFVisible = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBaseCombatCharacter::FVisibleEx");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hFVisibleEx = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBaseCombatCharacter::IRelationType");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hIRelationType = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBaseCombatCharacter::IRelationPriority");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hIRelationPriority = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBasePlayer::IsInAVehicle");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hIsInAVehicle = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBaseCombatCharacter::ExitVehicle");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hExitVehicle = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CHL2MP_Player::StartObserverMode");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hStartObserverMode = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBasePlayer::SetObserverMode");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSetObserverMode = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBasePlayer::GetObserverMode");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hGetObserverMode = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBasePlayer::SetObserverTarget");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSetObserverTarget = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBasePlayer::GetObserverTarget");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hGetObserverTarget = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBasePlayer::IsValidObserverTarget");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hIsValidObserverTarget = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBasePlayer::ForceObserverMode");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hForceObserverMode = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBasePlayer::ValidateCurrentObserverTarget");
	g_hValidateCurrentObserverTarget = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "CBasePlayer::LeaveVehicle");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, VDECODE_FLAG_ALLOWNULL);
	g_hLeaveVehicle = EndPrepSDKCall();
	
	CloseHandle(hGameConfig);
	
	g_iLifeState = FindSendPropInfo("CAI_BaseNPC", "m_lifeState");
	if (g_iLifeState == -1)
		PrintToServer("m_lifeState offset not found!");

/*	g_hKeyNames = new ArrayList(32);
	char keynames[7][] = { "cavernbreed", "citizentype", "skin", "damagetype", "damagefilter", "name", "Value" };
	for (int i = 0; i < sizeof(keynames); i++)
		g_hKeyNames.PushString(keynames[i]);*/

	KeyValues kv = new KeyValues("EntityInfo");
	if (kv.ImportFromFile("resource/entityinfo.txt"))
	{
		g_hFormatNames = new StringMap();

		char section[32], subsection[32], value[64];
	
		kv.Rewind();
		kv.GotoFirstSubKey();
		
		do
		{
			kv.GetSectionName(section, sizeof(section));
			kv.GetString("Name", value, sizeof(value), "");
			
			if (value[0] == '\0')
				continue;

			g_hFormatNames.SetString(section, value);

		} while (kv.GotoNextKey());
		
		g_hFormatNamesEx = new StringMap();
		StringMap hLinks = new StringMap();
		EntityInfo aValues;
		EntityInfo bValues;
		char keynames[7][] = { "cavernbreed", "citizentype", "skin", "damagetype", "damagefilter", "name", "Value" };
		
		strcopy(aValues.ei_name, sizeof(aValues.ei_name), "Antlion Grub");
		g_hFormatNamesEx.SetArray("npc_antlion_grub", aValues, sizeof(aValues));

		strcopy(aValues.ei_name, sizeof(aValues.ei_name), "Dr. Wallace Breen");
		g_hFormatNamesEx.SetArray("npc_breen", aValues, sizeof(aValues));

		strcopy(aValues.ei_name, sizeof(aValues.ei_name), "Combine Camera");
		g_hFormatNamesEx.SetArray("npc_combine_camera", aValues, sizeof(aValues));

		strcopy(aValues.ei_name, sizeof(aValues.ei_name), "The Fisherman");
		g_hFormatNamesEx.SetArray("npc_fisherman", aValues, sizeof(aValues));

		strcopy(aValues.ei_name, sizeof(aValues.ei_name), "The G-Man");
		g_hFormatNamesEx.SetArray("npc_gman", aValues, sizeof(aValues));

//		strcopy(aValues.ei_name, sizeof(aValues.ei_name), "Father Grigori");
//		g_hFormatNamesEx.SetArray("npc_monk", aValues, sizeof(aValues));

		strcopy(aValues.ei_name, sizeof(aValues.ei_name), "Combine Ground Turret");
		g_hFormatNamesEx.SetArray("npc_turret_ground", aValues, sizeof(aValues));

		kv.Rewind();
		kv.GotoFirstSubKey();

		do
		{
			kv.GetSectionName(section, sizeof(section));
			if (!StrEqual(section, "combine_mine") && strncmp(section, "npc_", 4) != 0 && strncmp(section, "monster_", 8) != 0 && !StrEqual(section, "prop_vehicle_apc"))
				continue;

			kv.GetString("Name", value, sizeof(value), "");
			if (value[0] == '\0')
			{
				if (kv.JumpToKey("SubType"))
				{
					PrintToServer("Section %s", section);
					
					if (kv.JumpToKey("1"))
					{
						if (kv.JumpToKey("Link"))
						{
							kv.GetString("Classname", value, sizeof(value), "");
							if (value[0] != '\0')
							{
								hLinks.SetString(section, value);

								PrintToServer("Link Classname: %s", value);
							}
							
							kv.GoBack();
						}
						
						kv.GoBack();
					}
					
					kv.GoBack();
				}
			
				continue;
			}

			PrintToServer("Section %s: %s", section, value);
			
			aValues = bValues;
				
			strcopy(aValues.ei_name, sizeof(aValues.ei_name), value);
				
			if (kv.JumpToKey("SubType"))
			{
				int count = 1;
				char countBuffer[3] = "1";
					
				while (kv.JumpToKey(countBuffer))
				{
					kv.GetSectionName(subsection, sizeof(subsection));
					kv.GetString("Name", value, sizeof(value), "");	
					if (value[0] != '\0')
					{
						PrintToServer("SubType %s: %s", subsection, value);

						if (count == 1)
							aValues.ei_names = new ArrayList(32);
										
						aValues.ei_names.PushString(value);
					}

					if (kv.JumpToKey("Diff"))
					{
						kv.GetString("Model", value, sizeof(value), "");
						if (value[0] != '\0')
						{
							if (count == 1)
							{
								aValues.ei_keys = new ArrayList(32);
								aValues.ei_values = new ArrayList(64);
							}

							aValues.ei_keys.PushString("Model");
							aValues.ei_values.PushString(value);

							PrintToServer("Diff Model: %s", value);
						}
						
						if (kv.GotoFirstSubKey())
						{
							kv.GetSectionName(subsection, sizeof(subsection));	

							for (int i = 0; i < sizeof(keynames); i++)
							{
								kv.GetString(keynames[i], value, sizeof(value), "");

								if (value[0] != '\0')
								{
									if (count == 1)
									{
										aValues.ei_section = new ArrayList(32);
										aValues.ei_keys = new ArrayList(32);
										aValues.ei_values = new ArrayList(64);
									}

									aValues.ei_section.PushString(subsection);
									aValues.ei_keys.PushString(keynames[i]);
									aValues.ei_values.PushString(value);
									PrintToServer("subsection: %s, %s: %s", subsection, keynames[i], value);
								}
							}
							
							kv.GoBack();
						}
						
						kv.GoBack();
					}

					aValues.ei_size = count;

					count++;
				//	Format(countBuffer, sizeof(countBuffer), "%i", count);
					IntToString(count, countBuffer, sizeof(countBuffer));
					
					kv.GoBack();
				}

				kv.GoBack();
			}

			g_hFormatNamesEx.SetArray(section, aValues, sizeof(aValues));
	
		} while (kv.GotoNextKey());

		if (hLinks != null && hLinks.Size > 0)
		{
			StringMapSnapshot hTrieSnapshot = hLinks.Snapshot();
			
			char szKey[32];
			int iSize = hTrieSnapshot.Length;
			for (int i = 0; i < iSize; i++)
			{
				hTrieSnapshot.GetKey(i, szKey, sizeof(szKey));
				
				if (!hLinks.GetString(szKey, value, sizeof(value)))
					continue;
				
				if (!g_hFormatNamesEx.GetArray(value, aValues, sizeof(aValues)))
					continue;

				g_hFormatNamesEx.SetArray(szKey, aValues, sizeof(aValues));
			}

			delete hTrieSnapshot;
		}
	}
	
	delete kv;
}

public int IsAlive(Handle plugin, int numParams)
{
	if (g_hIsAlive == null)
		ThrowNativeError(SP_ERROR_NATIVE, "IsAlive function not found");
	
	int entity = GetNativeCell(1);
	if (entity == 0 || !IsValidEntity(entity))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %d is invalid", entity);
	
	return SDKCall(g_hIsAlive, entity);
}

public int IsNPC(Handle plugin, int numParams)
{
	if (g_hIsNPC == null)
		ThrowNativeError(SP_ERROR_NATIVE, "IsNPC function not found");
	
	int entity = GetNativeCell(1);
	if (entity == 0 || !IsValidEntity(entity))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %d is invalid", entity);
	
	return SDKCall(g_hIsNPC, entity);
}

public int IsMoving(Handle plugin, int numParams)
{
	if (g_hIsMoving == null)
		ThrowNativeError(SP_ERROR_NATIVE, "IsMoving function not found");
	
	int entity = GetNativeCell(1);
	if (entity == 0 || !IsValidEntity(entity))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %d is invalid", entity);
	
	return SDKCall(g_hIsMoving, entity);
}

public int FVisible(Handle plugin, int numParams)
{
	if (g_hFVisible == null)
		ThrowNativeError(SP_ERROR_NATIVE, "FVisible function not found");
	
	int entity = GetNativeCell(1);
	if (entity == 0 || !IsValidEntity(entity))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %d is invalid", entity);

	int target = GetNativeCell(2);
	if (target == 0 || !IsValidEntity(target))
		ThrowNativeError(SP_ERROR_NATIVE, "Target index %d is invalid", target);

	int traceMask = GetNativeCell(3);
	//int blocker = GetNativeCell(4);
	
	return SDKCall(g_hFVisible, entity, target, traceMask, -1);
}

public int FVisibleEx(Handle plugin, int numParams)
{
	if (g_hFVisibleEx == null)
		ThrowNativeError(SP_ERROR_NATIVE, "FVisible function not found");
	
	int entity = GetNativeCell(1);
	if (entity == 0 || !IsValidEntity(entity))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %d is invalid", entity);

	float vecTarget[3];
	GetNativeArray(2, vecTarget, 3);
	int traceMask = GetNativeCell(3);
	//int blocker = GetNativeCell(4);

	return SDKCall(g_hFVisibleEx, entity, vecTarget, traceMask, -1);
}

public int IRelationType(Handle plugin, int numParams)
{
	if (g_hIRelationType == null)
		ThrowNativeError(SP_ERROR_NATIVE, "IRelationType function not found");
	
	int entity = GetNativeCell(1);
	if (entity == 0 || !IsValidEntity(entity))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %d is invalid", entity);

	int target = GetNativeCell(2);
	if (target == 0 || !IsValidEntity(target))
		ThrowNativeError(SP_ERROR_NATIVE, "Target index %d is invalid", target);
	
	return SDKCall(g_hIRelationType, entity, target);
}

public int IRelationPriority(Handle plugin, int numParams)
{
	if (g_hIRelationPriority == null)
		ThrowNativeError(SP_ERROR_NATIVE, "IRelationPriority function not found");
	
	int entity = GetNativeCell(1);
	if (entity == 0 || !IsValidEntity(entity))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %d is invalid", entity);

	int target = GetNativeCell(2);
	if (target == 0 || !IsValidEntity(target))
		ThrowNativeError(SP_ERROR_NATIVE, "Target index %d is invalid", target);
	
	return SDKCall(g_hIRelationPriority, entity, target);
}

public int IsInAVehicle(Handle plugin, int numParams)
{
	if (g_hIsInAVehicle == null)
		ThrowNativeError(SP_ERROR_NATIVE, "IsInAVehicle function not found");
	
	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Player index %d is not in game", client);

	return SDKCall(g_hIsInAVehicle, client);
}

public int ExitVehicle(Handle plugin, int numParams)
{
	if (g_hExitVehicle == null)
		ThrowNativeError(SP_ERROR_NATIVE, "ExitVehicle function not found");
	
	int entity = GetNativeCell(1);
	if (entity == 0 || !IsValidEntity(entity))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %d is invalid", entity);

	return SDKCall(g_hExitVehicle, entity);
}

public int StartObserverMode(Handle plugin, int numParams)
{
	if (g_hStartObserverMode == null)
		ThrowNativeError(SP_ERROR_NATIVE, "StartObserverMode function not found");
	
	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Player index %d is not in game", client);
	
	int mode = GetNativeCell(2);

	return SDKCall(g_hStartObserverMode, client, mode);
}

public int SetObserverMode(Handle plugin, int numParams)
{
	if (g_hSetObserverMode == null)
		ThrowNativeError(SP_ERROR_NATIVE, "SetObserverMode function not found");
	
	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Player index %d is not in game", client);
	
	int mode = GetNativeCell(2);

	return SDKCall(g_hSetObserverMode, client, mode);
}

public int GetObserverMode(Handle plugin, int numParams)
{
	if (g_hGetObserverMode == null)
		ThrowNativeError(SP_ERROR_NATIVE, "GetObserverMode function not found");
	
	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Player index %d is not in game", client);

	return SDKCall(g_hGetObserverMode, client);
}

public int SetObserverTarget(Handle plugin, int numParams)
{
	if (g_hSetObserverTarget == null)
		ThrowNativeError(SP_ERROR_NATIVE, "SetObserverTarget function not found");
	
	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Player index %d is not in game", client);

	int target = GetNativeCell(2);
	if (target == 0 || !IsValidEntity(target))
		ThrowNativeError(SP_ERROR_NATIVE, "Target index %d is invalid", target);

	return SDKCall(g_hSetObserverTarget, client, target);
}

public int GetObserverTarget(Handle plugin, int numParams)
{
	if (g_hGetObserverTarget == null)
		ThrowNativeError(SP_ERROR_NATIVE, "GetObserverTarget function not found");
	
	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Player index %d is not in game", client);

	return SDKCall(g_hGetObserverTarget, client);
}

public int IsValidObserverTarget(Handle plugin, int numParams)
{
	if (g_hIsValidObserverTarget == null)
		ThrowNativeError(SP_ERROR_NATIVE, "IsValidObserverTarget function not found");

	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Player index %d is not in game", client);

	int target = GetNativeCell(2);
	if (target == 0 || !IsValidEntity(target))
		ThrowNativeError(SP_ERROR_NATIVE, "Target index %d is invalid", target);

	return SDKCall(g_hIsValidObserverTarget, client, target);
}

public int ForceObserverMode(Handle plugin, int numParams)
{
	if (g_hForceObserverMode == null)
		ThrowNativeError(SP_ERROR_NATIVE, "ForceObserverMode function not found");

	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Player index %d is not in game", client);
		
	int mode = GetNativeCell(2);

	SDKCall(g_hForceObserverMode, client, mode);
	
	return 0;
}

public int ValidateCurrentObserverTarget(Handle plugin, int numParams)
{
	if (g_hValidateCurrentObserverTarget == null)
		ThrowNativeError(SP_ERROR_NATIVE, "ValidateCurrentObserverTarget function not found");

	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Player index %d is not in game", client);

	SDKCall(g_hValidateCurrentObserverTarget, client);
	
	return 0;
}

public int LeaveVehicle(Handle plugin, int numParams)
{
	if (g_hLeaveVehicle == null)
		ThrowNativeError(SP_ERROR_NATIVE, "LeaveVehicle function not found");

	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Player index %d is not in game", client);

	SDKCall(g_hLeaveVehicle, client, NULL_VECTOR, NULL_VECTOR);
//	SDKCall(g_hLeaveVehicle, client);

	return 0;
}

public int IsDead(Handle plugin, int numParams)
{
	if (g_iLifeState == -1)
		ThrowNativeError(SP_ERROR_NATIVE, "m_lifeState offset not found");
	
	int entity = GetNativeCell(1);
	if (entity == 0 || !IsValidEntity(entity))
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %d is invalid", entity);
	
	return GetEntData(entity, g_iLifeState, 1) == LIFE_DEAD;
}

public int NpcFormatedName(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);

	if (len <= 0)
		return false;
      
	int size = GetNativeCell(3);
	if (size < 1)
		return false;

	char[] key = new char[len + 1];
	GetNativeString(1, key, len + 1);
	
	char[] value = new char[size + 1];

	bool ret = g_hFormatNames.GetString(key, value, size);
	if (!ret)
		strcopy(value, size, key);
	
	SetNativeString(2, value, size+1, false);
	
	return ret;
}

public int NpcFormatedNameEx(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (entity == 0)
		return false;
	
	if (!IsValidEntity(entity) || !IsValidEdict(entity))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %d is invalid", entity);
		return false;
	}
 
	int size = GetNativeCell(3);
	if (size < 1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "maxlenth < 1");
		return false;
	}

	char[] val = new char[size + 1];

	char classname[32];
	GetEdictClassname(entity, classname, sizeof(classname));
	EntityInfo aValues;
	bool ret = g_hFormatNamesEx.GetArray(classname, aValues, sizeof(aValues));
	if (!ret)
	{
		strcopy(val, size, classname);
		SetNativeString(2, val, size+1, false);
		return false;
	}
	
	//PrintToServer("aValues.ei_name = %s, aValues.ei_size = %i", aValues.ei_name, aValues.ei_size);
	
	int val_size = aValues.ei_size;
	
	if (val_size == 0)
	{
		strcopy(val, size, aValues.ei_name);
	}
	else if (val_size > 0)
	{
	/*	ArrayList hNames = aValues.ei_names;
		ArrayList hKeys = aValues.ei_keys;
		ArrayList hValues = aValues.ei_values;
		ArrayList hSection = aValues.ei_section;*/

		if (aValues.ei_names != null && aValues.ei_keys != null && aValues.ei_values != null)
		{
			char model[64], key[32], value[64], name[32], section[32];
			char targetname[64];

			//PrintToServer("hNames.Length = %i", hNames.Length);
			GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));

			for (int i = aValues.ei_keys.Length - 1; i >= 0; i--)
			{
				aValues.ei_keys.GetString(i, key, sizeof(key));
				aValues.ei_values.GetString(i, value, sizeof(value));
				
				//PrintToServer("key: %s, value: %s", key, value);

				if (StrEqual(key, "Model") && StrEqual(value, model))
				{
					aValues.ei_names.GetString(i, name, sizeof(name));
					strcopy(val, size, name);
					break;
				}
				else if (StrEqual(key, "skin") && StringToInt(value) == GetEntProp(entity, Prop_Data, "m_nSkin"))
				{
					aValues.ei_names.GetString(i, name, sizeof(name));
					strcopy(val, size, name);
					break;
				}
				else if (StrEqual(key, "citizentype") && StringToInt(value) == GetEntProp(entity, Prop_Data, "m_Type"))
				{
					aValues.ei_names.GetString(i, name, sizeof(name));
					strcopy(val, size, name);
					break;
				}
				else if (StrEqual(key, "cavernbreed") && StringToInt(value) == GetEntProp(entity, Prop_Data, "m_bCavernBreed"))
				{
					aValues.ei_names.GetString(i, name, sizeof(name));
					strcopy(val, size, name);
					break;
				}
				else if (aValues.ei_section != null && aValues.ei_section.Length)
				{
					//PrintToServer("i: %i, hSection.Length: %i", i, hSection.Length);
				
					if (i >= aValues.ei_section.Length)
						continue;
				
					aValues.ei_section.GetString(i, section, sizeof(section));
					//PrintToServer("section: %s, key: %s, value: %s", section, key, value);
					
					//PrintToServer("m_spawnflags = %i", GetEntProp(entity, Prop_Data, "m_spawnflags"));
					
					if (StrEqual(section, "spawnflags", false) && StrEqual(key, "Value") && StringToInt(value) & GetEntProp(entity, Prop_Data, "m_spawnflags") != 0)
					{
						aValues.ei_names.GetString(i, name, sizeof(name));
					//	PrintToServer("name: %s", name);
						strcopy(val, size, name);
						break;
					}
					else if (StrEqual(section, "targetname", false) && StrEqual(key, "name"))
					{
						GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));

						if (!StrEqual(value, targetname))
							continue;
					
						aValues.ei_names.GetString(i, name, sizeof(name));
						strcopy(val, size, name);
						break;
					}
				}
			}
			
/*			delete hNames;
			delete hKeys;
			delete hValues;
			
			if (hSection != null)
				delete hSection;*/
		}
		
		if (val[0] == '\0')
			strcopy(val, size, aValues.ei_name);
	}
	
	if (val[0] == '\0')
	{
		strcopy(val, size, classname);
		ret = false;
	}
	
	SetNativeString(2, val, size+1, false);
	
	return ret;
}
