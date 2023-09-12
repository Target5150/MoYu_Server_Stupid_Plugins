#if defined _readyup_forward_included
 #endinput
#endif
#define _readyup_forward_included

#pragma semicolon 1
#pragma newdecls required

static Handle
	s_recipient = null;

enum struct FlexibleForward
{
	GlobalForward fw;
	char name[64];
	
	void Init(GlobalForward fw, const char[] fwName) {
		this.fw = fw;
		strcopy((this.name), sizeof((this.name)), fwName);
	}
	
	bool Start(bool undone = false) {
		if (s_recipient) {
			Function func = GetFunctionByName(s_recipient, this.name);
			if (func == INVALID_FUNCTION)
				return false;
			
			Call_StartFunction(s_recipient, func);
		} else {
			if (!this.fw.FunctionCount)
				return false;
			
			Call_StartForward(this.fw);
		}
		
		if (!undone)
			Call_Finish();
		
		return true;
	}
}

static FlexibleForward
	s_fwPreInitiate,
	s_fwInitiate,
	s_fwPreCountdown,
	s_fwCountdown,
	s_fwCountdownTick,
	s_fwPreLive,
	s_fwLive,
	s_fwFinish,
	s_fwCheckFullReady,
	s_fwCountdownCancelled,
	s_fwCountdownCancelled2,
	s_fwAdminForceStart,
	s_fwPlayerReady,
	s_fwPlayerUnready,
	s_fwTeamReady,
	s_fwTeamUnready,
	s_fwCheckAutoStart,
	s_fwAutoStartCountdown,
	s_fwAutoStartCountdownTick;

methodmap EventDispatcher {
	public static Handle GetRecipient() {
		return s_recipient;
	}
	public static void SetRecipient(Handle plugin) {
		s_recipient = plugin;
	}
	public static bool OnReadyUpInitiatePre() {
		return s_fwPreInitiate.Start(false);
	}
	public static bool OnReadyUpInitiate() {
		return s_fwInitiate.Start(false);
	}
	public static bool OnRoundLiveCountdownPre() {
		return s_fwPreCountdown.Start(false);
	}
	public static bool OnRoundLiveCountdown() {
		return s_fwCountdown.Start(false);
	}
	public static bool OnRoundLiveCountdownTick(int countdown) {
		if (s_fwCountdownTick.Start(true)) {
			Call_PushCell(countdown);
			return Call_Finish() == SP_ERROR_NONE;
		}
		return false;
	}
	public static bool OnRoundIsLivePre() {
		return s_fwPreLive.Start(false);
	}
	public static bool OnRoundIsLive() {
		return s_fwLive.Start(false);
	}
	public static bool OnReadyUpFinished() {
		return s_fwFinish.Start(false);
	}
	public static bool OnCheckFullReady(bool &retVal) {
		if (s_fwCheckFullReady.Start(true)) {
			Action result = Plugin_Continue;
			bool temp = retVal;
			Call_PushCellRef(temp);
			if (Call_Finish(result) == SP_ERROR_NONE) {
				if (result > Plugin_Continue) {
					retVal = temp;
					return true;
				}
			}
		}
		return false;
	}
	public static bool OnReadyCountdownCancelled(int client, const char[] reason) {
		if (s_fwCountdownCancelled.Start(true)) {
			Call_PushCell(client);
			Call_PushString(reason);
			return Call_Finish() == SP_ERROR_NONE;
		}
		return false;
	}
	public static bool OnReadyCountdownCancelled2(int client, DisruptType type) {
		if (s_fwCountdownCancelled2.Start(true)) {
			Call_PushCell(client);
			Call_PushCell(type);
			return Call_Finish() == SP_ERROR_NONE;
		}
		return false;
	}
	public static bool OnAdminForceStart(int client) {
		if (s_fwAdminForceStart.Start(true)) {
			Call_PushCell(client);
			return Call_Finish() == SP_ERROR_NONE;
		}
		return false;
	}
	public static bool OnPlayerReady(int client) {
		if (s_fwPlayerReady.Start(true)) {
			Call_PushCell(client);
			return Call_Finish() == SP_ERROR_NONE;
		}
		return false;
	}
	public static bool OnPlayerUnready(int client) {
		if (s_fwPlayerUnready.Start(true)) {
			Call_PushCell(client);
			return Call_Finish() == SP_ERROR_NONE;
		}
		return false;
	}
	public static bool OnTeamReady(ReadyTeam team, int client) {
		if (s_fwTeamReady.Start(true)) {
			Call_PushCell(team);
			Call_PushCell(client);
			return Call_Finish() == SP_ERROR_NONE;
		}
		return false;
	}
	public static bool OnTeamUnready(ReadyTeam team, int client) {
		if (s_fwTeamUnready.Start(true)) {
			Call_PushCell(team);
			Call_PushCell(client);
			return Call_Finish() == SP_ERROR_NONE;
		}
		return false;
	}
	public static bool OnAutoStartCountdown() {
		return s_fwAutoStartCountdown.Start(false);
	}
	public static bool OnAutoStartCountdownTick(int countdown) {
		if (s_fwAutoStartCountdownTick.Start(true)) {
			Call_PushCell(countdown);
			return Call_Finish() == SP_ERROR_NONE;
		}
		return false;
	}
	public static bool OnCheckAutoStart(bool &retVal) {
		if (s_fwCheckAutoStart.Start(true)) {
			Action result = Plugin_Continue;
			bool temp = retVal;
			Call_PushCellRef(temp);
			if (Call_Finish(result) == SP_ERROR_NONE) {
				if (result > Plugin_Continue) {
					retVal = temp;
					return true;
				}
			}
		}
		return false;
	}
}

void SetupForwards()
{
	s_fwPreInitiate.Init(new GlobalForward("OnReadyUpInitiatePre", ET_Ignore), "OnReadyUpInitiatePre");
	s_fwInitiate.Init(new GlobalForward("OnReadyUpInitiate", ET_Ignore), "OnReadyUpInitiate");
	s_fwPreCountdown.Init(new GlobalForward("OnRoundLiveCountdownPre", ET_Ignore), "OnRoundLiveCountdownPre");
	s_fwCountdown.Init(new GlobalForward("OnRoundLiveCountdown", ET_Ignore), "OnRoundLiveCountdown");
	s_fwCountdownTick.Init(new GlobalForward("OnRoundLiveCountdownTick", ET_Ignore, Param_Cell), "OnRoundLiveCountdownTick");
	s_fwPreLive.Init(new GlobalForward("OnRoundIsLivePre", ET_Ignore), "OnRoundIsLivePre");
	s_fwLive.Init(new GlobalForward("OnRoundIsLive", ET_Ignore), "OnRoundIsLive");
	s_fwFinish.Init(new GlobalForward("OnReadyUpFinished", ET_Ignore), "OnReadyUpFinished");
	s_fwCheckFullReady.Init(new GlobalForward("OnCheckFullReady", ET_Event, Param_CellByRef), "OnCheckFullReady");
	s_fwCountdownCancelled.Init(new GlobalForward("OnReadyCountdownCancelled", ET_Ignore, Param_Cell, Param_String), "OnReadyCountdownCancelled");
	s_fwCountdownCancelled2.Init(new GlobalForward("OnReadyCountdownCancelled2", ET_Ignore, Param_Cell, Param_Cell), "OnReadyCountdownCancelled2");
	s_fwAdminForceStart.Init(new GlobalForward("OnAdminForceStart", ET_Ignore, Param_Cell), "OnAdminForceStart");
	s_fwPlayerReady.Init(new GlobalForward("OnPlayerReady", ET_Ignore, Param_Cell), "OnPlayerReady");
	s_fwPlayerUnready.Init(new GlobalForward("OnPlayerUnready", ET_Ignore, Param_Cell), "OnPlayerUnready");
	s_fwTeamReady.Init(new GlobalForward("OnTeamReady", ET_Ignore, Param_Cell, Param_Cell), "OnTeamReady");
	s_fwTeamUnready.Init(new GlobalForward("OnTeamUnready", ET_Ignore, Param_Cell, Param_Cell), "OnTeamUnready");
	s_fwAutoStartCountdown.Init(new GlobalForward("OnAutoStartCountdown", ET_Ignore), "OnAutoStartCountdown");
	s_fwAutoStartCountdownTick.Init(new GlobalForward("OnAutoStartCountdownTick", ET_Ignore, Param_Cell), "OnAutoStartCountdownTick");
	s_fwCheckAutoStart.Init(new GlobalForward("OnCheckAutoStart", ET_Event, Param_CellByRef), "OnCheckAutoStart");
}
