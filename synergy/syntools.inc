#if defined _syntools_included
  #endinput
#endif
#define _syntools_included

enum Disposition_t
{
	D_ER,		// Undefined - error
	D_HT,		// Hate
	D_FR,		// Fear
	D_LI,		// Like
	D_NU		// Neutral
};

// Spectator Movement modes
enum
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES
};

#define LAST_PLAYER_OBSERVERMODE	OBS_MODE_ROAMING

// Force Camera Restrictions with mp_forcecamera
enum
{
	OBS_ALLOW_ALL = 0,	// allow all modes, all targets
	OBS_ALLOW_TEAM,		// allow only own team & first person, no PIP
	OBS_ALLOW_NONE,		// don't allow any spectating after death (fixed & fade to black)

	OBS_ALLOW_NUM_MODES
};

// -----------------------------------------------------
// spatial content masks - used for spatial queries (traceline,etc.)
// -----------------------------------------------------
// everything that blocks line of sight for AI
#define MASK_BLOCKLOS				(CONTENTS_SOLID|CONTENTS_MOVEABLE|CONTENTS_MIST)
// everything that blocks line of sight for AI plus NPCs
#define MASK_BLOCKLOS_AND_NPCS		(MASK_BLOCKLOS|CONTENTS_MONSTER)
// everything that blocks line of sight for players

// UNDONE: This is untested, any moving water
#define MASK_CURRENT				(CONTENTS_CURRENT_0|CONTENTS_CURRENT_90|CONTENTS_CURRENT_180|CONTENTS_CURRENT_270|CONTENTS_CURRENT_UP|CONTENTS_CURRENT_DOWN)

// everything that blocks corpse movement
// UNDONE: Not used yet / may be deleted
#define	MASK_DEADSOLID				(CONTENTS_SOLID|CONTENTS_PLAYERCLIP|CONTENTS_WINDOW|CONTENTS_GRATE)


/**
 * Check if whether entity is Alive.
 *
 * @param entity        Entity index
 * @return              Return true if entity is Alive, false otherwise.
 * @error               Invalid entity index
 */
native bool Syn_IsAlive(int entity);

/**
 * Check if whether entity is NPC.
 *
 * @param entity        Entity index
 * @return              Return true if entity is NPC, false otherwise.
 * @error               Invalid entity index
 */
native bool Syn_IsNPC(int entity);

/**
 * Check if whether entity is moving.
 *
 * @param entity        Entity index
 * @return              Return true if entity is moving, false otherwise.
 * @error               Invalid entity index
 */
native bool Syn_IsMoving(int entity);

// Untested
native bool Syn_FVisible(int entity, int target, int traceMask = MASK_BLOCKLOS);
native bool Syn_FVisibleEx(int entity, float vecTarget[3], int traceMask = MASK_BLOCKLOS);

/**
 * Describes the relationship between two types of NPC.
 *
 * @param entity        Entity index
 * @param target        Target index
 * @return              Disposition_t
 * @error               Invalid entity index
 */
native Disposition_t Syn_IRelationType(int entity, int target);

/**
 * Describes the relationship priority between two types of NPC.
 *
 * @param entity        Entity index
 * @param target        Target index
 * @return              priority
 * @error               Invalid entity index
 */
native int Syn_IRelationPriority(int entity, int target);


native bool Syn_IsInAVehicle(int client);

// Untested
native bool Syn_ExitVehicle(int entity);

native bool Syn_StartObserverMode(int client, int mode);
native bool Syn_SetObserverMode(int client, int mode);
native int Syn_GetObserverMode(int client);
native bool Syn_SetObserverTarget(int client, int target);
native int Syn_GetObserverTarget(int client);
native bool Syn_IsValidObserverTarget(int client, int target);
native void Syn_ForceObserverMode(int client, int mode);
native void Syn_ValidateCurrentObserverTarget(int client);
native void Syn_LeaveVehicle(int client);

stock bool Syn_IsObserver(int client)
{
	return (Syn_GetObserverMode(client) != OBS_MODE_NONE); 
}

/**
 * Check if whether entity is Dead.
 *
 * @param entity        Entity index
 * @return              Return true if entity is Dead, false otherwise.
 * @error               Invalid entity index
 */
native bool Syn_IsDead(int entity);

/**
 * Get formated name from entity classname
 *
 * @param classname
 * @param formatedname	Output formated name
 * @parem maxlength     Maximum length of the buffer
 * @return              True on success
 */
native bool Syn_NpcFormatedName(const char[] classname, char[] formatedname, int maxlength);

/**
 * Get formated name from entity
 *
 * @param entity        Entity index
 * @param formatedname	Output formated name
 * @parem maxlength     Maximum length of the buffer
 * @return              True on success
 * @error               Invalid entity index
 */
native bool Syn_NpcFormatedNameEx(int entity, char[] formatedname, int maxlength);


public SharedPlugin __pl_syntools = 
{
	name = "syntools",
	file = "syntools.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_syntools_SetNTVOptional()
{
	MarkNativeAsOptional("Syn_IsAlive");
	MarkNativeAsOptional("Syn_IsNPC");
	MarkNativeAsOptional("Syn_IsMoving");
	MarkNativeAsOptional("Syn_FVisible");
	MarkNativeAsOptional("Syn_FVisibleEx");
	MarkNativeAsOptional("Syn_IRelationType");
	MarkNativeAsOptional("Syn_IRelationPriority");
	MarkNativeAsOptional("Syn_IsInAVehicle");
	MarkNativeAsOptional("Syn_ExitVehicle");
	MarkNativeAsOptional("Syn_StartObserverMode");
	MarkNativeAsOptional("Syn_SetObserverMode");
	MarkNativeAsOptional("Syn_GetObserverMode");
	MarkNativeAsOptional("Syn_GetObserverTarget");
	MarkNativeAsOptional("Syn_IsValidObserverTarget");
	MarkNativeAsOptional("Syn_ValidateCurrentObserverTarget");
	MarkNativeAsOptional("Syn_LeaveVehicle");
	MarkNativeAsOptional("Syn_IsDead");

	MarkNativeAsOptional("Syn_NpcFormatedName");
	MarkNativeAsOptional("Syn_NpcFormatedNameEx");
}
#endif
