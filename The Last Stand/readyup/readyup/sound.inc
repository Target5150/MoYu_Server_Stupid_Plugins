#if defined _readyup_sound_included
 #endinput
#endif
#define _readyup_sound_included

#pragma semicolon 1
#pragma newdecls required

#define SECRET_SOUND "level/gnomeftw.wav"
#define DEFAULT_NOTIFY_SOUND "buttons/button14.wav"
#define DEFAULT_COUNTDOWN_SOUND "weapons/hegrenade/beep.wav"
#define DEFAULT_LIVE_SOUND "ui/survival_medal.wav"
#define DEFAULT_AUTOSTART_SOUND "ui/buttonrollover.wav"

#define MAX_CHUCKLE_SOUNDS 5
static const char s_chuckleSound[MAX_CHUCKLE_SOUNDS][] =
{
	"/npc/moustachio/strengthattract01.wav",
	"/npc/moustachio/strengthattract02.wav",
	"/npc/moustachio/strengthattract05.wav",
	"/npc/moustachio/strengthattract06.wav",
	"/npc/moustachio/strengthattract09.wav"
};

static char
	s_notifySound[PLATFORM_MAX_PATH],
	s_countdownSound[PLATFORM_MAX_PATH],
	s_liveSound[PLATFORM_MAX_PATH],
	s_autoStartSound[PLATFORM_MAX_PATH];

static ConVar
	l4d_ready_enable_sound, l4d_ready_notify_sound, l4d_ready_countdown_sound, l4d_ready_live_sound, l4d_ready_autostart_sound, l4d_ready_chuckle, l4d_ready_secret;

static Handle
	blockSecretSpam[MAXPLAYERS+1];

enum
{
	READY_SOUND_NOTIFY		= (1 << 0),
	READY_SOUND_COUNTDOWN 	= (1 << 1),
	READY_SOUND_LIVE		= (1 << 2),
	READY_SOUND_AUTOSTART 	= (1 << 3)
}

methodmap ReadyEffect
{
	public static void Init()
	{
		static bool s_bInit = false;
		if (s_bInit)
			return;
		
		l4d_ready_enable_sound		= CreateConVar("l4d_ready_enable_sound", "14", "Enable sounds played to clients. (1 = Notify, 2 = Countdown, 4 = Live, 8 = Auto start)", FCVAR_NOTIFY, true, 0.0, true, 15.0);
		l4d_ready_notify_sound		= CreateConVar("l4d_ready_notify_sound", DEFAULT_NOTIFY_SOUND, "The sound that plays to players when they ready / unready.");	
		l4d_ready_countdown_sound	= CreateConVar("l4d_ready_countdown_sound", DEFAULT_COUNTDOWN_SOUND, "The sound that plays when a round goes on countdown");	
		l4d_ready_live_sound		= CreateConVar("l4d_ready_live_sound", DEFAULT_LIVE_SOUND, "The sound that plays when a round goes live");
		l4d_ready_autostart_sound	= CreateConVar("l4d_ready_autostart_sound", DEFAULT_AUTOSTART_SOUND, "The sound that plays when auto-start goes on countdown");
		l4d_ready_chuckle			= CreateConVar("l4d_ready_chuckle", "0", "Enable random moustachio chuckle during countdown");
		l4d_ready_secret			= CreateConVar("l4d_ready_secret", "1", "Play something good", _, true, 0.0, true, 1.0);
		
		s_bInit = true;
	}
	
	public static void Precache()
	{
		char szPath[PLATFORM_MAX_PATH];
		
		l4d_ready_notify_sound.GetString(s_notifySound, sizeof(s_notifySound));
		l4d_ready_countdown_sound.GetString(s_countdownSound, sizeof(s_countdownSound));
		l4d_ready_live_sound.GetString(s_liveSound, sizeof(s_liveSound));
		l4d_ready_autostart_sound.GetString(s_autoStartSound, sizeof(s_autoStartSound));
		
		FormatEx(szPath, sizeof(szPath), "sound/%s", s_notifySound);
		if (!FileExists(szPath, true)) {
			strcopy(s_notifySound, sizeof(s_notifySound), DEFAULT_NOTIFY_SOUND);
		}
		
		FormatEx(szPath, sizeof(szPath), "sound/%s", s_countdownSound);
		if (!FileExists(szPath, true)) {
			strcopy(s_countdownSound, sizeof(s_countdownSound), DEFAULT_COUNTDOWN_SOUND);
		}
		
		FormatEx(szPath, sizeof(szPath), "sound/%s", s_liveSound);
		if (!FileExists(szPath, true)) {
			strcopy(s_liveSound, sizeof(s_liveSound), DEFAULT_LIVE_SOUND);
		}
		
		FormatEx(szPath, sizeof(szPath), "sound/%s", s_autoStartSound);
		if (!FileExists(szPath, true)) {
			strcopy(s_autoStartSound, sizeof(s_autoStartSound), DEFAULT_AUTOSTART_SOUND);
		}
		
		PrecacheSound(SECRET_SOUND);
		PrecacheSound(s_notifySound);
		PrecacheSound(s_countdownSound);
		PrecacheSound(s_liveSound);
		PrecacheSound(s_autoStartSound);
		for (int i = 0; i < MAX_CHUCKLE_SOUNDS; i++)
		{
			PrecacheSound(s_chuckleSound[i]);
		}
	}
	
	public static void PlayLiveSound()
	{
		if (l4d_ready_enable_sound.IntValue & READY_SOUND_LIVE)
		{
			if (l4d_ready_chuckle.BoolValue)
			{
				EmitSoundToAll(s_chuckleSound[GetRandomInt(0,MAX_CHUCKLE_SOUNDS-1)], .volume = 0.5);
			}
			else { EmitSoundToAll(s_liveSound, .volume = 0.5); }
		}
	}
	
	public static void PlayCountdownSound()
	{
		if (l4d_ready_enable_sound.IntValue & READY_SOUND_COUNTDOWN)
		{
			EmitSoundToAll(s_countdownSound, .volume = 0.5);
		}
	}
	
	public static void PlayAutoStartSound()
	{
		if (l4d_ready_enable_sound.IntValue & READY_SOUND_AUTOSTART)
		{
			EmitSoundToAll(s_autoStartSound, .volume = 0.7);
		}
	}
	
	public static void PlayNotifySound(int client)
	{
		if (l4d_ready_enable_sound.IntValue & READY_SOUND_NOTIFY)
		{
			EmitSoundToClient(client, s_notifySound);
		}
	}
	
	public static void DoSecrets(int client)
	{
		if (!l4d_ready_secret.BoolValue)
			return;
		
		if (GetClientTeam(client) == L4D2Team_Survivor && !blockSecretSpam[client])
		{
			int particle = CreateEntityByName("info_particle_system");
			if (particle == -1) return;
			
			float pos[3];
			GetClientAbsOrigin(client, pos);
			
			pos[2] += 80;
			
			TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
			
			DispatchKeyValue(particle, "effect_name", "achieved");
			DispatchKeyValue(particle, "targetname", "particle");
			DispatchSpawn(particle);
			ActivateEntity(particle);
			AcceptEntityInput(particle, "start");
			
			CreateTimer(5.0, killParticle, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
			
			EmitSoundToAll(SECRET_SOUND, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
			CreateTimer(2.5, killSound);
			
			blockSecretSpam[client] = CreateTimer(5.0, SecretSpamDelay, client);
		}
		PrintCenterTextAll("\x42\x4f\x4e\x45\x53\x41\x57\x20\x49\x53\x20\x52\x45\x41\x44\x59\x21");
	}
}

static Action SecretSpamDelay(Handle timer, int client)
{
	blockSecretSpam[client] = null;
	return Plugin_Stop;
}

static Action killParticle(Handle timer, int entRef)
{
	int entity = EntRefToEntIndex(entRef);
	if (entity > 0 && IsValidEdict(entity))
	{
		RemoveEntity(entity);
	}
	return Plugin_Stop;
}

static Action killSound(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			StopSound(i, SNDCHAN_AUTO, SECRET_SOUND);
	
	return Plugin_Stop;
}
