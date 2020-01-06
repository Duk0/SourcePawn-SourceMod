#define PLUGIN_VERSION "1.2"

native TMSSwapTeams()
native TMSMessage(client, const String:message[])
native TMSHintMessage(client, const String:hintmessage[])
native TMSCenterMessage(client, const String:centermessage[])
native TMSChangeToTeam(client, newteam)
native TMSKick(client, const String:kickreason[])
native TMSBan(client, bantime, const String:banreason[])
native TMSSound(client, const String:soundsample[])
native TMSMixTeams()
native TMSAdminTeam(adminteam)
native TMSSlay(client, slayfx = 0)
native TMSRegAddon(const String:AddonBuffer[])
native TMSGetClientSpawnArea(client, spawnarea)
native TMSIsWhiteListed(client, const String:feature[])
native TMSIsBlackListed(client, const String:feature[])

#define EVEN 		0
#define UNASSIGNED 	0
#define RANDOM 		0
#define SPEC 		1
#define ALLIES 		2
#define AXIS 		3
#define ALL 		4

#define CLASS_RIFLEMAN 	0
#define CLASS_ASSAULT 	1
#define CLASS_SUPPORT 	2
#define CLASS_SNIPER 	3
#define CLASS_MG	4
#define CLASS_ROCKET 	5