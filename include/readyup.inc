/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#if defined  _readyup_included_
 #endinput
#endif
#define _readyup_included_

enum ReadyTeam
{
	ReadyTeam_Invalid,
	ReadyTeam_Admin,
	ReadyTeam_Survivor,
	ReadyTeam_Infected,
	
	ReadyTeam_SIZE
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

stock const char DisruptReason[disruptType_SIZE][] = 
{
	"Player marked unready",
	"Player switched team",
	"Player disconnected",
	"Admin aborted"
};

// Ready Mode enum
enum ReadyMode
{
	ReadyMode_Disable = 0,
	ReadyMode_PlayerReady = 1,
	ReadyMode_TeamReady,
	ReadyMode_AutoStart,
	
	ReadyMode_SIZE
};

/**
 * @brief Called before readyup initiates.
 */
forward void OnReadyUpInitiatePre();

/**
 * @brief Called when readyup is initiated.
 */
forward void OnReadyUpInitiate();

/**
 * @brief Called before the live countdown begins.
 */
forward void OnRoundLiveCountdownPre();

/**
 * @brief Called when the live countdown has beginned.
 */
forward void OnRoundLiveCountdown();

/**
 * @brief Called when the live countdown ticks.
 *
 * @param countdown		Remaining time for countdown.
 */
forward void OnRoundLiveCountdownTick(int countdown);

/**
 * @brief Called before the live countdown ends and the round goes live.
 */
forward void OnRoundIsLivePre();

/**
 * @brief Called when the live countdown has ended and the round went live.
 */
forward void OnRoundIsLive();

/**
 * @brief Called when a readyup phase has ended.
 * @remarks This forward is guaranteed to be called when readyup is reset or cancelled (map ends).
 * @remarks If the round is bound to go live, this forward will be called before "OnRoundIsLive".
 */
forward void OnReadyUpFinished();

/**
 * @brief Called when readyup checks if the game can go live.
 *
 * @return Action		Plugin_Handled to use your own value, Plugin_Continue otherwise.
 */
forward Action OnCheckFullReady(bool &retVal);

/**
 * @brief Called when the live countdown is cancelled
 *
 * @param client		Player cancelled the countdown
 * @param reason		The reason for cancel
 */
forward void OnReadyCountdownCancelled(int client, const char[] reason);

/**
 * @brief Called when the live countdown is cancelled
 *
 * @param client		Player cancelled the countdown
 * @param type			The reason type for cancel
 */
forward void OnReadyCountdownCancelled2(int client, DisruptType type);

/**
 * @brief Called when a admin forces the readyup to countdown to live.
 */
forward void OnAdminForceStart(int client);

/**
 * @brief Called when a player marks ready.
 */
forward void OnPlayerReady(int client);

/**
 * @brief Called when a player marks unready.
 */
forward void OnPlayerUnready(int client);

/**
 * @brief Called when a client marks a team ready.
 * @remarks "OnPlayerReady" won't be called.
 */
forward void OnTeamReady(ReadyTeam team, int client);

/**
 * @brief Called when a client marks a team unready.
 * @remarks "OnPlayerUnready" won't be called.
 */
forward void OnTeamUnready(ReadyTeam team, int client);

/**
 * @brief Called when the countdown for auto-start begins.
 */
forward void OnAutoStartCountdown();

/**
 * @brief Called when the countdown for auto-start ticks.
 *
 * @param countdown		Remaining time for countdown.
 */
forward void OnAutoStartCountdownTick(int countdown);

/**
 * @brief Called when readyup checks if the auto-start can proceed.
 */
forward bool OnCheckAutoStart(bool &retVal);






/**
 * @brief Returns the index of a item in the footer array.
 * @remarks Does not have to be exact. The footer only needs to contain the input, does not need to match.
 *
 * @param index			Index of string
 * @param buffer		Where to store result
 * @param maxlength		Max length of buffer
 * @return				String at specified index
 */
native int GetFooterStringAtIndex(int index, char[] buffer, int maxlength);

/**
 * @brief Returns the index of a item in the footer array.
 * @remarks Does not have to be exact. The footer only needs to contain the input, does not need to match.
 *
 * @param string		String to search for
 * @return				Int index of string
 */
native int FindIndexOfFooterString(const char[] string);

/**
 * @brief Edits a footer string on the ready-up panel at the specified index.
 *
 * @param index			Index of string to edit
 * @param string		String to add to the footer
 * @return				True if the string was added, false otherwise
 */
native bool EditFooterStringAtIndex(int index, const char[] string);

/**
 * @brief Adds the string to the bottom of the ready-up panel.
 * @remarks String must be <=65 characters including the null byte.
 * @remarks String will be entirely added or not added, no truncation.
 *
 * @param footer		String to add to the footer
 * @return				Int Index of string in footer.
 */
native int AddStringToReadyFooter(const char[] footer);

/**
 * @brief Whether or not the game is currently waiting for players to ready up.
 *
 * @return				True if the game is currently in the ready-up phase.
 */
native bool IsInReady();

/**
 * @brief Whether or not the readyup is counting down to live.
 *
 * @return				True if the readyup is counting down to live.
 */
native bool IsInLiveCountdown();

/**
 * @brief Whether or not the player is currently ready.
 * @remarks Always return false if not in "ReadyMode_PlayerReady".
 *
 * @param client		Client to check.
 * @return				True if the player is ready.
 */
#pragma deprecated Use IsPlayerReady instead.
native bool IsReady(int client);

/**
 * @brief Whether or not the player is currently ready.
 * @remarks Always return false if not in "ReadyMode_PlayerReady".
 *
 * @param client		Client to check.
 * @return				True if the player is ready.
 */
native bool IsPlayerReady(int client);

/**
 * @brief Whether or not the team is currently ready.
 * @remarks Always return false if not in "ReadyMode_TeamReady".
 *
 * @param team			Client to check.
 * @return				True if the team is ready.
 */
native bool IsTeamReady(ReadyTeam team);

/**
 * @brief Toggle ready panel of one target or all clients.
 * @remarks Always return false if currently not in ready-up phase.
 *
 * @return          True if no target if specified, or previous ready panel state of target.
 */
native bool ToggleReadyPanel(bool show, int target = 0);

/**
 * @brief Start a custom ready up controlled via forwards.
 * @remarks Forwards with the same name are privately called.
 *
 * @param mode      Ready mode preferred to use.
 * @return          True if success, false if ready up is currently in progress or invalid mode.
 */
native bool StartCustomReadyUp(ReadyMode mode);

public SharedPlugin __pl_readyup =
{
	name = "readyup",
	file = "readyup.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_readyup_SetNTVOptional()
{
	MarkNativeAsOptional("GetFooterStringAtIndex");
	MarkNativeAsOptional("FindIndexOfFooterString");
	MarkNativeAsOptional("EditFooterStringAtIndex");
	MarkNativeAsOptional("AddStringToReadyFooter");
	MarkNativeAsOptional("IsInReady");
	MarkNativeAsOptional("IsInLiveCountdown");
	MarkNativeAsOptional("IsReady");
	MarkNativeAsOptional("IsPlayerReady");
	MarkNativeAsOptional("IsTeamReady");
	MarkNativeAsOptional("ToggleReadyPanel");
	MarkNativeAsOptional("StartCustomReadyUp");
}
#endif