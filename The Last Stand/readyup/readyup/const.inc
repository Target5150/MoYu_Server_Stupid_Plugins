#if defined _readyup_const_included
 #endinput
#endif
#define _readyup_const_included

#pragma semicolon 1
#pragma newdecls required

#define TRANSLATION_READYUP "readyup.phrases"
#define TRANSLATION_READYUP_PANEL "readyup.panel.phrases"

#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})

#define L4D2Team_None       0
#define L4D2Team_Spectator  1
#define L4D2Team_Survivor   2
#define L4D2Team_Infected   3

#define DEBUG 0

// Ready Mode enum
enum ReadyMode
{
	ReadyMode_Disable = 0,
	ReadyMode_PlayerReady = 1,
	ReadyMode_TeamReady,
	ReadyMode_AutoStart,
	
	ReadyMode_SIZE
};

enum ReadyTeam
{
	ReadyTeam_Invalid,
	ReadyTeam_Admin,
	ReadyTeam_Survivor,
	ReadyTeam_Infected,
	
	ReadyTeam_SIZE
};
#define FOR_EACH_READY_TEAM(%0) \
	for (ReadyTeam %0 = ReadyTeam_Survivor; %0 < ReadyTeam_SIZE; ++%0)

enum
{
	WL_NotInWater = 0,
	WL_Feet,
	WL_Waist,
	WL_Eyes
};

// Reason enum for Countdown cancelling
enum DisruptType
{
	readyStatus,
	teamShuffle,
	playerDisconn,
	adminAbort,
	
	disruptType_SIZE
};

// FIXME: Global const array requires static keyword, then how could I share it between modules?
//static const char g_sDisruptReason[disruptType_SIZE][] = 
char g_sDisruptReason[disruptType_SIZE][] = 
{
	"Player marked unready",
	"Player switched team",
	"Player disconnected",
	"Admin aborted"
};

enum
{
	Difficulty_Easy,
	Difficulty_Normal,
	Difficulty_Hard,
	Difficulty_Expert,
	
	Difficulty_SIZE
};

char sDifficultyStrings[][] =
{
	"Easy", "Normal", "Hard", "Expert"
};