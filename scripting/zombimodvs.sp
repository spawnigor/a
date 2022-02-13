
/*
// TODO:
1) Her zombi sınıfına özel hasar statusu (kimisi kör edecek kimisi slowlatacak)
-Scout vuruşlarında kör edecek 5 saniyelik + slowness. (Tek Vuruşunda) HitOnce(attacker)++, attacker öldüğünde vurduğu sayıları 0'a çek.
-Sniper vuruşlarında kör edecek 3 saniyelik + Jarate efekti verecek HitOnce + slowness.
-Pyro vuruşlarında oyuncu yanma efekti olacak 1 saniyelik +slowness
-Soldier vuruşlarında slowness verilecek + slowness
-Sentry knockbackını azaltabiliriz ya da 1 level yapabiliriz
-- Zombiler damage yerse slowness olacak

2)Boss zombi seçiminde ve özelliklerinde yeni şeyler (HasBosZombieReleased?)
-Regen olmayacak
-Boss zombi seçildiğinde insan takımına Fade gönderelim.
-Boss zombi seçimini düzelt. (Her bir insana vuruşta  ya da damage yiyince +1 boss queue puanı ekleme sistemi)
-No Knockback


4)Enable consumable items for zombies like bad milk jarate etc
-Scoutun milk vb türleri aktif hale getirilebilir
-Soldierin botu vb aktif hale getirilebilir.

5)Set boss hp to 1.5k, give speedboost with quickfix uber no knockback thing

6)Let the sandman balls do more damage
Sandman ballsı editleyelim.


14)Medic should start with at least 40% of uber
-Yaparız


16)Mark the humans with mini crit (fan o war effect) when zombies hit humans
-Yapılabilir.


23)Zombies should jump longer than humans
-OnSpawn if zombie

*/
#pragma semicolon 1
#pragma tabsize 0
#define DEBUG
#define TIMER_FLAG_NO_MAPCHANGE (1<<1)   

#define FFADE_IN            (0x0001)        // 0'ı' geçme
#define FFADE_OUT           (0x0002)        // Fade out 
#define FFADE_MODULATE      (0x0004)        // Modulate 
#define FFADE_STAYOUT       (0x0008)        // Durationu engeller kalıcı olmasını sağlar
#define FFADE_PURGE         (0x0010)        // Yenisi ile değiştir

#define PLUGIN_AUTHOR "Devil"
#define PLUGIN_VERSION "1.11" //Private version ++
#define PLAYERBUILTOBJECT_ID_DISPENSER 0
#define PLAYERBUILTOBJECT_ID_TELENT    1
#define PLAYERBUILTOBJECT_ID_TELEXIT   2
#define PLAYERBUILTOBJECT_ID_SENTRY    3

#define TF_CLASS_DEMOMAN		4
#define TF_CLASS_ENGINEER		9
#define TF_CLASS_HEAVY			6
#define TF_CLASS_MEDIC			5
#define TF_CLASS_PYRO				7
#define TF_CLASS_SCOUT			1
#define TF_CLASS_SNIPER			2
#define TF_CLASS_SOLDIER		3
#define TF_CLASS_SPY				8
#define TF_CLASS_UNKNOWN		0

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <clientprefs>
#include <steamtools>

static String:KVPath[PLATFORM_MAX_PATH];
//ConVars
new Handle:zm_tDalgasuresi = INVALID_HANDLE;
new Handle:zm_tHazirliksuresi = INVALID_HANDLE;
new Handle:zm_hTekvurus = INVALID_HANDLE;
new Handle:MusicCookie;
new Handle:zm_hBossZombi = INVALID_HANDLE;
new Handle:zm_hBossZombiInterval = INVALID_HANDLE;
new Handle:zm_enable = INVALID_HANDLE;
new Handle:zm_hOnlyZMaps = INVALID_HANDLE;
new Handle:zm_HealthRegenEnable = INVALID_HANDLE;
//new Handle:zm_HealthRegenMiktar = INVALID_HANDLE;
new Handle:zm_HealthRegenTick = INVALID_HANDLE;
//new Handle:zm_StatusAyari = INVALID_HANDLE;
//Timer Handles
new Handle:g_hTimer = INVALID_HANDLE;
new Handle:g_hSTimer = INVALID_HANDLE;
new Handle:g_hAdvert = INVALID_HANDLE;
new Handle:g_hAdvert2 = INVALID_HANDLE;
new Handle:g_hAdvert3 = INVALID_HANDLE;
new Handle:g_hAdvert4 = INVALID_HANDLE;
//Global Bools
new bool:g_bOyun;
new bool:getrand = false;
new bool:g_bOnlyZMaps;
new bool:g_bEnabled;
//Global Integers
new g_iSetupCount;
new g_iDalgaSuresi;
new bool:g_bKazanan;
new g_maxHealth[10] =  { 0, 125, 125, 200, 175, 150, 300, 175, 125, 125 };
new g_iMapPrefixType = 0;
new Handle:clientRegenTime[MAXPLAYERS + 1];
new MaxHealth[MAXPLAYERS];


new bool:g_iVaultKullanicilar[MAXPLAYERS + 1];
new g_iSebep; //1 Disabled , 2 sadece zm (onlyzm)  
new bool:g_iNonPreBoss[MAXPLAYERS + 1];
new bool:g_bNotHurt[MAXPLAYERS + 1] = true;
new bool:g_bZombiEscape = false;
new bool:g_bBossZombi[MAXPLAYERS + 1];
//new g_iSpeedTimer[MAXPLAYERS + 1];

new Handle:clientBuffTimerRemoval[MAXPLAYERS + 1];
new g_iZomTeamIndex;
new g_iHumTeamIndex;
/*
            CURRENT REMOVED WEAPONS
            1)Rocket Jumper
            2)Sticky Jumper
            3)GunBoats
            4)Natascha
            5)Cloak & Dagger
            6)Disguise Kit For spies
*/

/*
            UNTESTED UPDATES
            
            3.09.2019
            
            1)Added Redeem Command
            2)Added MakeZombie Command
            3)Removed natascha for usage for humans
            4)Removed Cloak And Dagger for Usage for humans
            5)Added invis watch for zombies for zombies
            6)Removed Giant effect for boss zombies in order to stop stucking.
            7)Added some translations quotes but not in .phrases file.
            
*/
public Plugin:myinfo = 
{
	name = "Zombie Escape/Survival", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		Format(error, err_max, "This plug-in only works for Team Fortress 2. // Eklenti sadece Team Fortress 2 için tasarlandı.");
		return APLRes_Failure;
	}
	return APLRes_Success;
}
//Ayarların yüklenmesi.
public OnMapStart()
{
	Steam_SetGameDescription("Zombie Escape / Custom");
	PrecacheSound("npc/fast_zombie/fz_scream1.wav", true);
	PrecacheSound("npc/zombie_poison/pz_alert2.wav", true);
	zombimod();
	setuptime();
	//We are clearing the timers. That's important. DO NOT TOUCH THIS
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
	ClearTimer(g_hAdvert);
	ClearTimer(g_hAdvert2);
	ClearTimer(g_hAdvert3);
	ClearTimer(g_hAdvert4);
	KillClientTimer(_, true);
	if (GetConVarInt(zm_enable) == 1 && GetConVarInt(zm_hOnlyZMaps) == 1) {
		if (g_iMapPrefixType == 0) {
			g_bEnabled = false;
			PrintToServer("\n\n[ZM]Sadece zombi maplerinde calismaya ayarlandı bu sebebple mod kapatildi.\n\n    \n\nTekrar Acmak icin:zm_onlyzm 0 yazabilirsiniz\n\n  \n--\n Works only in z' prefixed maps for now.\n -- \n You can change this by editing zm_onlyzm 0\n'");
			g_iSebep = 2;
			ZomEnableDisable();
			
		}
		else if (g_iMapPrefixType > 0) {
			g_bEnabled = true;
			ZomEnableDisable();
		}
	}
	else if (GetConVarInt(zm_enable) == 1 && GetConVarInt(zm_hOnlyZMaps) == 0) {
		g_bEnabled = true;
		if (g_iMapPrefixType > 0) {
			g_bEnabled = true;
			ZomEnableDisable();
		}
		else if (g_iMapPrefixType == 0) {
			g_bEnabled = true;
			ZomEnableDisable();
		}
	}
	
	if (GetConVarInt(zm_enable) == 0) {
		g_bEnabled = false;
		g_iSebep = 1;
		ZomEnableDisable();
	}
	else if (GetConVarInt(zm_enable) == 1) {
		g_bEnabled = true;
		ZomEnableDisable();
	}
	logGameRuleTeamRegister();
}
public OnMapEnd()
{
	//We are clearing the timers. That's important. DO NOT TOUCH THIS
	getrand = false;
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
	ClearTimer(g_hAdvert);
	ClearTimer(g_hAdvert2);
	ClearTimer(g_hAdvert3);
	ClearTimer(g_hAdvert4);
	KillClientTimer(_, true);
}
public OnClientPutInServer(id)
{
	KayitliKullanicilar(id);
	if (g_bOyun && g_bEnabled && IsClientInGame(id)) {  //Were forcing clients to join zombie team when were in roundTime (LateJoins)
		ChangeClientTeam(id, g_iZomTeamIndex); //Move Zombie, id
		CreateTimer(1.0, ClassSelection, id, TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (!g_bOyun && g_bEnabled && IsClientInGame(id)) {  //Were forcing clients to join human team when were in setup.
		ChangeClientTeam(id, g_iHumTeamIndex);
		CreateTimer(1.0, ClassSelection, id, TIMER_FLAG_NO_MAPCHANGE);
		TF2_RespawnPlayer(id);
		TF2_SetPlayerClass(id, TFClass_Scout);
	}
	SDKHook(id, SDKHook_OnTakeDamage, OnTakeDamage);
	if (g_bEnabled) {
		SDKHook(id, SDKHook_GetMaxHealth, OnGetMaxHealth);
	}
}
public OnClientAuthorized(id) {
	if (id > 0 && IsClientInGame(id) && g_bOyun && TakimdakiOyuncular(g_iZomTeamIndex) > 0)
	{
		ChangeClientTeam(id, g_iZomTeamIndex); //Move Zombie, id
		CreateTimer(1.0, ClassSelection, id, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public OnClientPostAdminCheck(client) {
	KayitliKullanicilar(client);
}
public OnClientDisconnect(client) {
	if (clientRegenTime[client] != INVALID_HANDLE)
		KillClientTimer(client);
}
public Action:ClassSelection(Handle:timer, any:id) {
	if (id > 0 && IsClientInGame(id) && ToplamOyuncular() > 0) {
		if (g_bEnabled) {
			ShowVGUIPanel(id, TF2_GetClientTeam(id) == TFTeam_Blue ? "class_blue" : "class_red");
		} else {
			ShowVGUIPanel(id, TF2_GetClientTeam(id) == TFTeam_Red ? "class_blue" : "class_red");
		}
	} else {
		if (g_bEnabled) {
			PrintToChat(id, "%t", "pressing [,]"); //Lütfen [,] e basın! -- Please press [,]!
		}
	}
}
public OnConfigsExecuted()
{
	if (g_bEnabled) {
		for (new i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i))
				SDKHook(i, SDKHook_GetMaxHealth, OnGetMaxHealth);
		}
	}
}
public OnPluginStart()
{
	//Console Commands
	RegConsoleCmd("sm_msc", msc);
	
	RegConsoleCmd("sm_menu", zmenu);
	RegConsoleCmd("sm_help", zmenu);
	RegConsoleCmd("sm_zm", zmenu);
	RegConsoleCmd("sm_zmenu", zmenu);
	RegConsoleCmd("sm_zhelp", zmenu);
	
	RegAdminCmd("sm_redeem", redeem, ADMFLAG_SLAY);
	RegAdminCmd("sm_makeboss", makeboss, ADMFLAG_SLAY);
	//Convars
	zm_tHazirliksuresi = CreateConVar("zm_setup", "30", "Setup Timer/Hazirlik Suresi", FCVAR_NOTIFY, true, 30.0, true, 70.0);
	zm_tDalgasuresi = CreateConVar("zm_dalgasuresi", "225", "Round Timer/Setup bittikten sonraki round zamani", FCVAR_NOTIFY, true, 120.0, true, 300.0);
	zm_hTekvurus = CreateConVar("zm_tekvurus", "0", " 1 Damage to turn human to a zombie / Zombiler tek vurusta insanlari infekte edebilsin (1/0) 0 kapatir.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_hBossZombi = CreateConVar("zm_bosszombi", "1", "Activate Boss Zombie Choosing System? /Boss zombi secimi aktif edilsin mi?(0/1)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_hBossZombiInterval = CreateConVar("zm_bossinter", "20", "Boss Zombie Choosing Interval // Boss kacinci saniye gelsin // Formula = Dalga Suresi - Boss Inter (225 - 60 = 165. saniyede)", FCVAR_NOTIFY, true, 20.0, true, 80.0);
	zm_enable = CreateConVar("zm_enable", "1", "Enable The Gamemode ? / Zombi Modu Acilsin? Not:Birdahaki map degisiminde etkin olur. (0/1)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_hOnlyZMaps = CreateConVar("zm_onlyzm", "1", "Only In Z' prefixed maps / Zombi Modu sadece zombi haritalarinda olsun? (0/1)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_HealthRegenEnable = CreateConVar("zm_healthregen", "1", "Activate Health Regen? / Health Regen olsun mu? Zombiler hasar yediginde(0/1)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//zm_HealthRegenMiktar = CreateConVar("zm_hrmiktar", "20", "Amount of health to regen / Her belirlenen saniyede kaç HP artsın? (Zombilerin)", FCVAR_NOTIFY, true, 10.0, true, 30.0);
	//zm_StatusAyari = CreateConVar("zm_status", "1", "Apply Human status(debuff) on damage, Insan hasarı aktiflestir?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_HealthRegenTick = CreateConVar("zm_hrtick", "3", "Health Regen Interval/ Kaç saniyede bir canı artsın?(Zombilerin)", FCVAR_NOTIFY, true, 3.0, true, 7.0);
	//Events
	HookEvent("teamplay_round_start", OnRound);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_spawn", OnSpawn);
	HookEvent("teamplay_setup_finished", OnSetup);
	HookEvent("teamplay_point_captured", OnCaptured, EventHookMode_Post);
	HookEvent("player_hurt", HookPlayerHurt);
	HookEvent("post_inventory_application", Event_Resupply);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	//HookEvent("player_builtobject", Event_ObjectBuilt);
	//HookEvent("object_destroyed", Event_ObjectDestroyed);
	RegConsoleCmd("say", say);
	RegConsoleCmd("say_team", say);
	//ServerCommands
	ServerCommand("mp_autoteambalance 0");
	ServerCommand("mp_scrambleteams_auto 0");
	ServerCommand("mp_teams_unbalance_limit 0");
	ServerCommand("mp_respawnwavetime 0 ");
	ServerCommand("mp_disable_respawn_times 1 ");
	ServerCommand("sm_cvar mp_waitingforplayers_time 25");
	ServerCommand("sm_cvar tf_spy_invis_time 0.5"); // Locked 
	ServerCommand("sm_cvar tf_spy_invis_unstealth_time 0.75"); // Locked 
	ServerCommand("sm_cvar tf_spy_cloak_no_attack_time 1.0");
	//Preferences, Cookies
	MusicCookie = RegClientCookie("oyuncu_mzk_ayari", "Muzik Ayarı", CookieAccess_Public);
	//Hooking the client commands
	AddCommandListener(hook_JoinClass, "joinclass");
	AddCommandListener(BlockedCommands, "autoteam");
	AddCommandListener(BlockedCommandsteam, "jointeam");
	//Directories
	BuildPath(Path_SM, KVPath, sizeof(KVPath), "data/vault.txt");
	LoadTranslations("tf2zombiemodvs.phrases");
	
	//Problematic in Linux OS
	if (!FileExists(KVPath)) {
		PrintToServer("yokmus");
		new Handle:file = OpenFile(KVPath, "w");
		if (file == INVALID_HANDLE) {
			PrintToServer("dosya yaratılamadı");
			file = OpenFile(KVPath, "w");
		}
		//CloseHandle(file);
	}
}
public Action:redeem(client, args) {
	decl String:arg1[32];
	if (args != 1) {
		ReplyToCommand(client, "\x05[SM]\x01 Usage: sm_redeem <name>");
		return Plugin_Handled;
	}
	GetCmdArg(1, arg1, sizeof(arg1));
	decl String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;
	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (new i = 0; i < target_count; i++)
	{
		if (GetClientTeam(target_list[i]) == g_iZomTeamIndex) {
			ChangeClientTeam(target_list[i], g_iHumTeamIndex);
			TF2_RespawnPlayer(target_list[i]);
			TF2_SetPlayerClass(target_list[i], TFClass_Scout);
			decl String:name[MAX_NAME_LENGTH];
			GetClientName(target_list[i], name, sizeof(name));
			ShowActivity2(client, "[SM] ", "Redeemed %s!", name);
		} else {
			PrintToChat(client, "That player is already human!");
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}
public Action:makeboss(client, args) {
	decl String:arg1[32];
	if (args != 1) {
		ReplyToCommand(client, "\x05[SM]\x01 Usage: sm_makeboss <name>");
		return Plugin_Handled;
	}
	GetCmdArg(1, arg1, sizeof(arg1));
	decl String:target_name[MAX_NAME_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;
	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (int i = 0; i < target_count; i++) {
		if (GetClientTeam(target_list[i]) == g_iZomTeamIndex) {
			bosszombi(target_list[i]);
			decl String:name[MAX_NAME_LENGTH];
			GetClientName(target_list[i], name, sizeof(name));
			ShowActivity2(client, "[SM] ", "Became boss zombie %s!", name);
		} else {
			PrintToChat(client, "You can't make humans boss zombie!");
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}
public Action:OnGetMaxHealth(client, &maxhealth)
{
	if (client > 0 && client <= MaxClients)
	{
		if (GetClientTeam(client) == g_iZomTeamIndex) //Zombie, client
		{
			if (g_iMapPrefixType == 6 && !g_bBossZombi[client]) {
				maxhealth = g_maxHealth[TF2_GetPlayerClass(client)] * 10;
				return Plugin_Handled;
			} else if (g_iMapPrefixType != 6 && !g_bBossZombi[client]) {
				maxhealth = g_maxHealth[TF2_GetPlayerClass(client)] * 3; // Zombi Survival Can Formülü
				MaxHealth[client] = maxhealth;
				return Plugin_Handled;
			}
			if (g_bBossZombi[client]) {
				maxhealth = 3250;
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public OnGameFrame() {  //Do not add anything to this, can cause lag.
	new entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_sentrygun")) != -1) {
		//SetEntProp(entity, Prop_Send, "m_iUpgradeMetal", 0);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.75);
		SetEntProp(entity, Prop_Send, "m_bMiniBuilding", 1);
		//SetEntProp(entity, Prop_Send, "m_iHealth", 100);
		//SetEntProp(entity, Prop_Send, "m_iMaxHealth", 100);
	}
}
public Action:Event_Resupply(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (client > 0 && client && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == g_iZomTeamIndex) //Zombie, client
	{
		zombi(client); //Oyuncular resupply cabinete dokunduğu zaman silahlarını tekrar silmek için. (Zombilerin)
	}
	return Plugin_Continue;
}
public HookPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iUserId = GetEventInt(event, "userid");
	new client = GetClientOfUserId(iUserId);
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new damagebits = GetEventInt(event, "damagebits");
	g_bNotHurt[client] = true;
	
	if (client > 0 && damagebits & DMG_FALL) //If client took fall damage then don't
		return;
	if (client > 0 && GetEventInt(event, "death_flags") & 32) //If client equipped dead ringer and died from it then don't do anything to him/her.
		return;
	if (client > 0 && GetConVarInt(zm_hTekvurus) == 1)
		if (client != attacker && attacker && TF2_GetPlayerClass(attacker) != TFClass_Scout && GetClientTeam(attacker) == g_iZomTeamIndex) {  //Zombie, attacker
		zombi(client);
	}
	if (client > 0 && g_bZombiEscape && client != attacker && attacker && GetClientTeam(attacker) == g_iHumTeamIndex) {  //Human, attacker
		g_bNotHurt[client] = false;
		//TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
		//SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 80.0);
		//g_iSpeedTimer[client] = CreateTimer(1.0, SpeedRemoval, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	if (GetConVarInt(zm_HealthRegenEnable) == 1 && client > 0 && clientRegenTime[client] == INVALID_HANDLE && GetClientTeam(client) == g_iZomTeamIndex) {  //Zombie, client
		clientRegenTime[client] = CreateTimer(GetConVarFloat(zm_HealthRegenTick), RegenTick, client, TIMER_REPEAT);
	}
}
public Action:RegenTick(Handle:timer, any:client)
{
	new clientCurHealth = GetPlayerHealth(client);
	//new Float:size = GetEntPropFloat(client, Prop_Data, "m_flModelScale");
	if (GetClientTeam(client) == g_iZomTeamIndex && clientCurHealth < MaxHealth[client] && g_iMapPrefixType != 6 && !g_bBossZombi[client]) {  //Zombie, client
		//SetPlayerHealth(client, clientCurHealth + GetConVarInt(zm_HealthRegenMiktar));
		TF2_AddCondition(client, TFCond_HalloweenQuickHeal);
	}
	else if (GetClientTeam(client) == g_iZomTeamIndex && clientCurHealth > MaxHealth[client] && g_iMapPrefixType != 6 && !g_bBossZombi[client]) {
		//SetPlayerHealth(client, MaxHealth[client]);
		TF2_RemoveCondition(client, TFCond_HalloweenQuickHeal);
		KillClientTimer(client);
	}
}
public Action:SpeedRemoval(Handle:timer, any:client)
{
	TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
	TF2_RemoveCondition(client, TFCond_SpeedBuffAlly);
}
//This is the function that we didn'T use it. DO not remove this please.
/*
SetPlayerHealth(entity, amount, bool:maxHealth = false, bool:ResetMax = false)
{
	if (maxHealth)
		if (ResetMax)
		SetEntData(entity, FindDataMapInfo(entity, "m_iMaxHealth"), MaxHealth[entity], 4, true);
	else
		SetEntData(entity, FindDataMapInfo(entity, "m_iMaxHealth"), amount, 4, true);
	
	SetEntityHealth(entity, amount);
}
*/
GetPlayerHealth(entity, bool:maxHealth = false)
{
	if (maxHealth)
	{
		return GetEntData(entity, FindDataMapInfo(entity, "m_iMaxHealth"));
	}
	return GetEntData(entity, FindDataMapInfo(entity, "m_iHealth"));
}

KillClientTimer(client = 0, bool:all = false)
{
	if (all)
	{
		for (new i; i <= MAXPLAYERS; i++)
		{
			if (clientRegenTime[i] != INVALID_HANDLE)
			{
				KillTimer(clientRegenTime[client]);
				clientRegenTime[client] = INVALID_HANDLE;
			}
		}
		return;
	}
	KillTimer(clientRegenTime[client]);
	clientRegenTime[client] = INVALID_HANDLE;
}
public Action:OnCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
	new entity = GetClientOfUserId(GetEventInt(event, "userid"));
	g_bKazanan = true;
	new capT = GetEntProp(entity, Prop_Send, "m_iOwner");
	kazanantakim(capT); //If they capped, then we'll give them a win status.
	oyunuresetle(); //If they capped, then we'll reset the game.
}
public Action:BlockedCommands(client, const String:command[], argc)
{
	return Plugin_Handled;
}
public Action:BlockedCommandsteam(client, const String:command[], argc)
{
	if (g_bEnabled && ToplamOyuncular() > 0 && client > 0 && g_bOyun && GetClientTeam(client) > 1) //Round başladığı halde oyuncular takım değiştirmeye çalışırsa engellensin
	{
		PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Players Cant Change Team Setup");
		return Plugin_Handled; // Engellemeyi uygula
	}
	/*
	else if (g_bEnabled && IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) > 1 && !g_bOyun) {
		return Plugin_Handled;
	}
	*/
	return Plugin_Continue; // Eğer öyle bir olay yoksa da plugin çalışmaya devam edicek.
}
public Action:hook_JoinClass(client, const String:command[], argc)
{
	if (g_bEnabled && client > 0 && client <= MaxClients && g_bOyun && GetClientTeam(client) == g_iHumTeamIndex) //Human, client //Round başladığı halde oyuncular takım değiştirmeye çalışırsa engellensin
	{
		PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Players Cant Change Class Round");
		return Plugin_Handled; // Engellemeyi uygula
	}
	return Plugin_Continue; // Eğer öyle bir olay yoksa da plugin çalışmaya devam edicek.
}
public Action:OnSetup(Handle:event, const String:name[], bool:dontBroadcast)
{
	zombimod(); //Round timerin işlemesi için
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Intermission Over");
}
public Action:OnRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bOyun = false; // Setup bitmeden round başlayamaz
	if (g_iMapPrefixType != 6) {
		g_iSetupCount = GetConVarInt(zm_tHazirliksuresi); //Setup zamanlayicisinin convarın değerini alması için
		g_iDalgaSuresi = GetConVarInt(zm_tDalgasuresi); //Round zamanlayicisinin convarın değerini alması için
	} else {
		g_iSetupCount = GetConVarInt(zm_tHazirliksuresi);
		g_iDalgaSuresi = GetConVarInt(zm_tDalgasuresi) + 300;
	}
	g_bKazanan = false;
	getrand = false;
	setuptime();
	//We are clearing the timers. That's important. DO NOT TOUCH THIS
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
	ClearTimer(g_hAdvert);
	ClearTimer(g_hAdvert2);
	ClearTimer(g_hAdvert3);
	ClearTimer(g_hAdvert4);
	g_hTimer = CreateTimer(1.0, oyun1, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hSTimer = CreateTimer(1.0, hazirlik, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hAdvert = CreateTimer(200.0, yazi1, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hAdvert2 = CreateTimer(220.0, yazi2, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hAdvert3 = CreateTimer(120.0, yazi4, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hAdvert4 = CreateTimer(190.0, yazi3, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
}
public Action:Event_RoundEnd(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	//We are clearing the timers. That's important. DO NOT TOUCH THIS
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
	ClearTimer(g_hAdvert);
	ClearTimer(g_hAdvert2);
	ClearTimer(g_hAdvert3);
	ClearTimer(g_hAdvert4);
	oyunuresetle();
}
public Action:OnSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetClientTeam(client) == g_iZomTeamIndex) //Zombie, client
	{
		if (!g_bOyun && g_iSetupCount > 0 && g_iSetupCount <= GetConVarInt(zm_tHazirliksuresi))
		{
			CreateTimer(0.1, silah, client, TIMER_FLAG_NO_MAPCHANGE); //This prevents zombie team to pick up weapons while intermission.
			SetEntProp(client, Prop_Send, "m_lifeState", 2);
			ChangeClientTeam(client, g_iHumTeamIndex); //Move Human, client
			SetEntProp(client, Prop_Send, "m_lifeState", 0);
			TF2_RespawnPlayer(client);
			//CreateTimer(0.1, silah, client, TIMER_FLAG_NO_MAPCHANGE); //This prevents zombie team to pick up weapons while intermission.
			PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Player Cant Become Zombie Intermission");
		}
		else if (g_bOyun && g_iDalgaSuresi > 0 && g_iDalgaSuresi <= GetConVarInt(zm_tDalgasuresi))
		{
			SetEntityRenderColor(client, 0, 255, 0, 0);
			zombi(client);
			if (g_iMapPrefixType == 6) {
				TF2_AddCondition(client, TFCond_SpeedBuffAlly);
				clientBuffTimerRemoval[client] = CreateTimer(7.0, SpeedRemoval, client, TIMER_FLAG_NO_MAPCHANGE);
				
			}
			if (clientRegenTime[client] != INVALID_HANDLE) {
				KillClientTimer(client);
			}
		}
	} else {
		SetEntityRenderColor(client, 255, 255, 255, 0);
		if (g_iVaultKullanicilar[client]) {
			PrintToConsole(client, "Registered Vault");
		}
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Spy:
			{
				TF2_RemoveWeaponSlot(client, 3);
				new slot = GetPlayerWeaponSlot(client, 4);
				if (IsValidEntity(slot))
				{
					decl String:classname[64];
					if (GetEntityClassname(slot, classname, sizeof(classname)) && StrContains(classname, "tf_weapon", false) != -1)
					{
						switch (GetEntProp(slot, Prop_Send, "m_iItemDefinitionIndex"))
						{
							case 60: { TF2_RemoveWeaponSlot(client, 4); } //Cloak and Dagger
							default:TF2_RemoveWeaponSlot(client, slot);
						}
					}
				}
			}
			case TFClass_DemoMan: {
				new slotDemo = GetPlayerWeaponSlot(client, 1);
				if (IsValidEntity(slotDemo)) {
					decl String:classNameDemo[128];
					if (GetEntityClassname(slotDemo, classNameDemo, sizeof(classNameDemo)) && StrContains(classNameDemo, "tf_weapon", false) != -1) {
						switch (GetEntProp(slotDemo, Prop_Send, "m_iItemDefinitionIndex")) {
							case 265: { TF2_RemoveWeaponSlot(client, 1); } //Sticky Jumper
							default:TF2_RemoveWeaponSlot(client, slotDemo);
						}
					}
				}
			}
			case TFClass_Soldier: {
				new slotSoldier = GetPlayerWeaponSlot(client, 0);
				if (IsValidEntity(slotSoldier)) {
					decl String:classNameSoldier[128];
					if (GetEntityClassname(slotSoldier, classNameSoldier, sizeof(classNameSoldier)) && StrContains(classNameSoldier, "tf_weapon", false) != -1) {
						switch (GetEntProp(slotSoldier, Prop_Send, "m_iItemDefinitionIndex")) {
							case 237: { TF2_RemoveWeaponSlot(client, 0); } //Rocket Jumper
							case 133: { TF2_RemoveWeaponSlot(client, 0); } //Gunboats
							default:TF2_RemoveWeaponSlot(client, slotSoldier);
						}
					}
				}
			}
			case TFClass_Engineer:
			{
				if (sinifsayisi(TFClass_Engineer) > 2)
				{
					TF2_SetPlayerClass(client, TFClass_Scout);
					TF2_RespawnPlayer(client);
					PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC Limit:2 %t", "Engineer Limit Is Reached");
				}
			}
			case TFClass_Heavy: {
				new slotHeavy = GetPlayerWeaponSlot(client, 0);
				if (IsValidEntity(slotHeavy)) {
					decl String:classNameHeavy[128];
					if (GetEntityClassname(slotHeavy, classNameHeavy, sizeof(classNameHeavy)) && StrContains(classNameHeavy, "tf_weapon", false) != -1) {
						switch (GetEntProp(slotHeavy, Prop_Send, "m_iItemDefinitionIndex")) {
							case 41: { TF2_RemoveWeaponSlot(client, 0); } //Natascha
							default:TF2_RemoveWeaponSlot(client, slotHeavy);
						}
					}
				}
			}
		}
	}
}
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	decl Float:flPos[3];
	GetClientAbsOrigin(victim, flPos);
	if (GetEventInt(event, "death_flags") & 32) // If player gets fall damage, or died by its own
	{
		return;
	}
	if (GetClientTeam(victim) == g_iHumTeamIndex && g_bOyun) //Human, victim
	{
		zombi(victim);
		HUD(-1.0, 0.2, 6.0, 255, 0, 0, 2, "\n☠☠☠\n%N", victim);
		EmitSoundToAll("npc/fast_zombie/fz_scream1.wav", victim, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, victim, flPos, NULL_VECTOR, true, 0.0);
	}
}
//This is the setup timer.
public Action:hazirlik(Handle:timer, any:client)
{
	if (ToplamOyuncular() > 0)
	{
		g_iSetupCount--;
	}
	if (g_iSetupCount <= GetConVarInt(zm_tHazirliksuresi) && g_iSetupCount > 0)
	{
		HUD(-1.0, 0.1, 6.0, 255, 255, 255, 1, " | Setup:%02d:%02d |", g_iSetupCount / 60, g_iSetupCount % 60); //-1.0 x, 0.2 y
		HUD(0.42, 0.1, 1.0, 0, 255, 0, 5, "%d", TakimdakiOyuncular(g_iZomTeamIndex)); //0.02 x, 0.10 y
		HUD(-0.42, 0.1, 1.0, 255, 255, 255, 6, "%d", TakimdakiOyuncular(g_iHumTeamIndex)); //-0.02 x, 0.10 y
		g_iDalgaSuresi = GetConVarInt(zm_tDalgasuresi);
		g_bOyun = false;
	} else {
		g_bOyun = true;
		if (TakimdakiOyuncular(g_iZomTeamIndex) == 0 && TakimdakiOyuncular(g_iHumTeamIndex) > 9 && g_bOyun && !getrand)
			zombi(rastgelezombi()), zombi(rastgelezombi());
		else if (TakimdakiOyuncular(g_iZomTeamIndex) == 0 && TakimdakiOyuncular(g_iHumTeamIndex) < 9 && !getrand)
			zombi(rastgelezombi());
		else if (TakimdakiOyuncular(g_iZomTeamIndex) == 0 && TakimdakiOyuncular(g_iHumTeamIndex) > 20 && !getrand)
			zombi(rastgelezombi()), zombi(rastgelezombi()), zombi(rastgelezombi());
	}
}
//This is the round timer. We're doing the huge stuff here. Like setting the huds, reducing the timers, checking the win status
public Action:oyun1(Handle:timer, any:id)
{
	if (ToplamOyuncular() > 0)
	{
		g_iDalgaSuresi--;
	}
	if (g_iDalgaSuresi <= GetConVarInt(zm_tDalgasuresi) && g_iDalgaSuresi > 0 && g_bOyun)
	{
		izleyicikontrolu();
		//HUD(-1.0, 0.2, 6.0, 255, 255, 255, 1, "Round:%02d:%02d", g_iDalgaSuresi / 60, g_iDalgaSuresi % 60);
		//HUD(0.02, 0.10, 1.0, 0, 255, 0, 5, "☠Zombies☠:%d", TakimdakiOyuncular(3));
		//HUD(-0.02, 0.10, 1.0, 255, 255, 255, 6, "Humans:%d", TakimdakiOyuncular(2));
		HUD(-1.0, 0.1, 6.0, 255, 255, 255, 1, " | Round:%02d:%02d |", g_iDalgaSuresi / 60, g_iDalgaSuresi % 60); //-1.0 x, 0.2 y
		HUD(0.42, 0.1, 1.0, 0, 255, 0, 5, "%d", TakimdakiOyuncular(g_iZomTeamIndex)); //0.02 x, 0.10 y
		HUD(-0.42, 0.1, 1.0, 255, 255, 255, 6, "%d", TakimdakiOyuncular(g_iHumTeamIndex)); //-0.02 x, 0.10 y
		
		if (g_iDalgaSuresi == GetConVarInt(zm_tDalgasuresi) - 3) {
			setuptime();
		}
		else if (g_iDalgaSuresi == GetConVarInt(zm_tDalgasuresi) - GetConVarInt(zm_hBossZombiInterval) && GetConVarInt(zm_hBossZombi) == 1) {
			bosszombi(bosschoosing());
			//HUD(-1.0, 0.2, 6.0, 255, 0, 0, 2, "\n☠☠☠\nBoss Zombie Came:%N\n☠☠☠", g_iChoosen[id]);
		}
		if (TakimdakiOyuncular(g_iHumTeamIndex) == 0) //2 red 3 blue
		{
			kazanantakim(g_iZomTeamIndex);
			oyunuresetle();
		}
	}
	else if (g_iDalgaSuresi <= 0 && g_bOyun)
	{
		if (TakimdakiOyuncular(g_iHumTeamIndex) > 0)
		{
			kazanantakim(g_iHumTeamIndex);
			oyunuresetle();
		}
		else if (TakimdakiOyuncular(g_iHumTeamIndex) == 0)
		{
			kazanantakim(g_iZomTeamIndex);
			oyunuresetle();
		}
	}
	return Plugin_Handled;
}

//Zombie Choosing Core
stock rastgelezombi()
{
	//new volunteerlist;
	new oyuncular[MaxClients + 1], num;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) > 1 && TF2_GetPlayerClass(i) != TFClass_Engineer && g_bOyun && !g_iVaultKullanicilar[i])
		{
			oyuncular[num++] = i;
		}
	}
	//volunteerlist = oyuncular[GetRandomInt(0, num - 1)];
	
	return (num == 0) ? 0 : oyuncular[GetRandomInt(0, num - 1)];
}
//Choosing random bosszombie in zombie team
stock bosschoosing()
{
	//PrintToChat(client, "Twoje punkty: %i", punkty);
	new oyuncular[MAXPLAYERS + 1], num;
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == g_iZomTeamIndex && g_bOyun) {  //Zombie, i
			oyuncular[num++] = i;
		}
	}
	return (num == 0) ? 0 : oyuncular[GetRandomInt(0, num - 1)];
}
//Function to make player bosszombie
bosszombi(client)
{
	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == g_iZomTeamIndex) {  //Zombie, client
		//client = g_iChoosen[client];
		g_bBossZombi[client] = true;
		TF2_SetPlayerClass(client, TFClass_Heavy);
		TF2_RespawnPlayer(client);
		//SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.5); // This Property makes player stuck on walls.
		TF2_AddCondition(client, TFCond_BalloonHead);
		TF2_AddCondition(client, TFCond_RuneVampire);
		//TF2_AddCondition(client, TFCond_HalloweenGiant); // This condition makes player stuck on walls.
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
		SetEntityRenderColor(client, 255, 0, 0, 0);
		EmitSoundToAll("npc/zombie_poison/pz_alert2.wav");
		
		if (!g_iVaultKullanicilar[client]) {
			g_iNonPreBoss[client] = false; //Donator olmayan boss zombi seçildi
			PrintToServer("\n\n\n Donator olmayan birisi boss zombi seçildi");
		} else if (g_iVaultKullanicilar[client]) {
			g_iNonPreBoss[client] = false; // Donator olan boss zombi seçildi
			PrintToChat(client, "%t", "boss as donator");
		}
		HUD(-1.0, 0.2, 6.0, 255, 0, 0, 2, "\n☠☠☠\nBoss Zombie Came:%N\n☠☠☠", client);
	}
}
//Function to make player to zombie
zombi(client)
{
	if (client > 0 && IsClientInGame(client))
	{
		g_bBossZombi[client] = false;
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		ChangeClientTeam(client, g_iZomTeamIndex); //Move Zombie, client
		SetEntProp(client, Prop_Send, "m_lifeState", 0);
		SetEntityRenderColor(client, 0, 255, 0, 0);
		//Balancing, adding some buffs for zombies. That applys on every spawn.
		TF2_AddCondition(client, TFCond_SmallBulletResist);
		TF2_AddCondition(client, TFCond_SmallFireResist);
		TF2_AddCondition(client, TFCond_SmallBlastResist);
		//TF2_AddCondition(client, TFCond_RuneVampire); //Boss Feature, but i've added this to zombies. Looks Cool lol
		//
		
		if (g_bZombiEscape) {
			if (g_bNotHurt[client]) {
				TF2_AddCondition(client, TFCond_SpeedBuffAlly, TFCondDuration_Infinite, 0);
			} else {
				TF2_RemoveCondition(client, TFCond_SpeedBuffAlly);
			}
		}
	}
	CreateTimer(0.1, silah, client, TIMER_FLAG_NO_MAPCHANGE);
}
//Removing the weapon of zombies.
public Action:silah(Handle:timer, any:client)
{
	if (client > 0 && IsClientInGame(client))
	{
		for (new i = 0; i <= 5; i++)
		{
			if (client > 0 && i != 2 && GetClientTeam(client) == g_iZomTeamIndex) //Zombie, client
			{
				TF2_RemoveWeaponSlot(client, i);
			}
		}
		if (client > 0 && GetClientTeam(client) == g_iZomTeamIndex)
		{
			new slot2 = GetPlayerWeaponSlot(client, 2);
			//new slot4 = GetPlayerWeaponSlot(client, 4);
			if (IsValidEdict(slot2))
			{
				EquipPlayerWeapon(client, slot2);
				//EquipPlayerWeapon(client, slot4);
			}
		}
	}
}
//------


//General count of clients in specific team. iTakim to set the team that we are checking.
TakimdakiOyuncular(iTakim)
{
	new iSayi;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == iTakim)
		{
			iSayi++;
		}
	}
	return iSayi;
}
//General count of clients.
ToplamOyuncular()
{
	new iSayi2;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
		{
			iSayi2++;
		}
	}
	return iSayi2;
}
//We are creating the entity for the round game win in order to active it. And setting the entity for specific team that we typed.
kazanantakim(takim)
{
	new ent = FindEntityByClassname(-1, "team_control_point_master"); //game_round_win
	if (ent == -1) // < 1  ya da == -1
	{
		ent = CreateEntityByName("team_control_point_master");
		DispatchSpawn(ent);
	} else {
		SetVariantInt(takim);
		g_bKazanan = true;
		AcceptEntityInput(ent, "SetWinner");
	}
}
//Hud function.
HUD(Float:x, Float:y, Float:Sure, r, g, b, kanal, const String:message[], any:...)
{
	SetHudTextParams(x, y, Sure, r, g, b, 255, 0, 6.0, 0.1, 0.2);
	new String:buffer[256];
	VFormat(buffer, sizeof(buffer), message, 9);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ShowHudText(i, kanal, buffer);
		}
	}
}
//Currently non used. It will be.
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (!IsValidClient(attacker))
	{
		return Plugin_Continue;
	}
	new weaponId;
	(attacker == inflictor) ? (weaponId = ClientWeapon(attacker)) : (weaponId = inflictor); // Karsilastirma ? IfTrue : IfFalse;
	
	if (IsValidEntity(weaponId) && GetClientTeam(attacker) == g_iZomTeamIndex) //Zombie, attacker
	{  // weaponId != -1
		decl String:sWeapon[80];
		sWeapon[0] = '\0';
		GetEntityClassname(weaponId, sWeapon, 32);
		if (StrEqual(sWeapon, "tf_weapon_bat") || StrEqual(sWeapon, "tf_weapon_bat_fish") || 
			StrEqual(sWeapon, "tf_weapon_shovel") || StrEqual(sWeapon, "tf_weapon_katana") || StrEqual(sWeapon, "tf_weapon_fireaxe") || 
			StrEqual(sWeapon, "tf_weapon_bottle") || StrEqual(sWeapon, "tf_weapon_sword") || StrEqual(sWeapon, "tf_weapon_fists") || 
			StrEqual(sWeapon, "tf_weapon_wrench") || StrEqual(sWeapon, "tf_weapon_robot_arm") || StrEqual(sWeapon, "tf_weapon_bonesaw") || 
			StrEqual(sWeapon, "tf_weapon_club"))
		{
			//damage = 350.0;
			//return Plugin_Changed;
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}
setuptime()
{
	new ent1 = FindEntityByClassname(MaxClients + 1, "team_round_timer");
	if (ent1 == -1)
	{
		ent1 = CreateEntityByName("team_round_timer");
		DispatchSpawn(ent1);
	}
	CreateTimer(1.0, Timer_SetTimeSetup, ent1, TIMER_FLAG_NO_MAPCHANGE);
}
//Handling the setup timer of the map.
public Action:Timer_SetTimeSetup(Handle:timer, any:ent1)
{
	if (g_iSetupCount > 0) {
		SetVariantInt(GetConVarInt(zm_tHazirliksuresi));
		AcceptEntityInput(ent1, "SetSetupTime"); //SetTime
	}
	else if (g_iSetupCount < 0) {
		SetVariantInt(GetConVarInt(zm_tDalgasuresi));
		AcceptEntityInput(ent1, "SetTime");
		//g_iDalgaSuresi = GetEntPropFloat(ent
	}
}
//Pre checking the map prefixes.
zombimod()
{
	g_iMapPrefixType = 0;
	decl String:mapv[32];
	GetCurrentMap(mapv, sizeof(mapv));
	if (!StrContains(mapv, "zf_", false)) {
		g_iMapPrefixType = 1;
	}
	else if (!StrContains(mapv, "szf_", false)) {
		g_iMapPrefixType = 2;
	}
	else if (!StrContains(mapv, "zm_", false)) {
		g_iMapPrefixType = 3;
	}
	else if (!StrContains(mapv, "zom_", false)) {
		g_iMapPrefixType = 4;
	}
	else if (!StrContains(mapv, "zs_", false)) {
		g_iMapPrefixType = 5;
	}
	else if (!StrContains(mapv, "ze_", false)) {
		g_iMapPrefixType = 6;
		g_bZombiEscape = true;
		PrintToServer("\n\n\n\n      ZOMBIE ESCAPE MOD ON \n\n\n");
	}
	
	if (g_iMapPrefixType == 1)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['ZF']\n\n\n");
	else if (g_iMapPrefixType == 2)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['SZF']\n\n\n");
	else if (g_iMapPrefixType == 3)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['ZM']zf\n\n\n");
	else if (g_iMapPrefixType == 4)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['ZOM']\n\n\n");
	else if (g_iMapPrefixType == 5)
		PrintToServer("\n\n\n      Great :) Found Map Prefix ['ZS']\n\n\n");
	else if (g_iMapPrefixType == 6)
		PrintToServer("\n\n\n      Great :) Found Map Prefix ['ZE']\n\n\n");
	else if (g_iMapPrefixType > 0) {
		g_bOnlyZMaps = true;
		if (g_iMapPrefixType != 6) {
			g_bZombiEscape = false;
		}
	}
	else if (g_iMapPrefixType == 0) {
		g_bOnlyZMaps = false;
		PrintToServer("\n\n           ********WARNING!********     \n\n\n ***Zombie Map Recommended Current [MAPNAME] = [%s]***\n\n\n", mapv);
	}
	if (g_bOnlyZMaps) {
		//
	}
}
//We are setting the inital round timer of the map itself.
public Action:Timer_SetRoundTime(Handle:timer, any:ent1)
{
	SetVariantInt(GetConVarInt(zm_tDalgasuresi)); // 600 sec ~ 10min
	AcceptEntityInput(ent1, "SetTime");
	
}
//We are resseting the game. And calling it right before the round ends.
oyunuresetle()
{
	if (g_bKazanan)
	{
		CreateTimer(15.0, res, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}
//We are moving the clients from to human team from here. Works only in non switch team maps.
public Action:res(Handle:timer, any:id)
{
	new oyuncu[MaxClients + 1], num;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == g_iZomTeamIndex) //Zombie, i
		{
			oyuncu[num++] = i;
			SetEntProp(i, Prop_Send, "m_lifeState", 2);
			ChangeClientTeam(i, g_iHumTeamIndex); //Move Human, i
			SetEntProp(i, Prop_Send, "m_lifeState", 0);
			TF2_RespawnPlayer(i);
		}
	}
}
/*
TF2_OnWaitingForPlayersStart()
{
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsValidClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue && !g_bOyun) {
			ChangeClientTeam(i, 2);
		}
	}
}
*/
stock bool:IsValidClient(client, bool:nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}
ClientWeapon(client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}
//Checking the class count, espically engineers
sinifsayisi(siniff)
{
	new iSinifNum;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetPlayerClass(i) == siniff && GetClientTeam(i) == g_iHumTeamIndex) //Human, i
		{
			iSinifNum++;
		}
	}
	return iSinifNum;
}
//Checking players for spectating.
izleyicikontrolu()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) < 1 && g_bOyun)
		{
			ChangeClientTeam(i, g_iZomTeamIndex); //Move Zombie, i
			TF2_SetPlayerClass(i, TFClass_Scout);
			TF2_RespawnPlayer(i);
		}
	}
}
//Calculating and setting the crit shots here.
public Action:TF2_CalcIsAttackCritical(id, weapon, String:weaponname[], &bool:result)
{
	//Projectle Weapons, Humans
	if (GetClientTeam(id) == g_iHumTeamIndex && StrEqual(weaponname, "tf_weapon_compound_bow", false) || StrEqual(weaponname, "tf_weapon_sniperrifle", false) || StrEqual(weaponname, "tf_weapon_crossbow", false)) {
		result = true;
		return Plugin_Changed;
	}
	else if (GetClientTeam(id) == g_iZomTeamIndex && g_bBossZombi[id] && StrEqual(weaponname, "tf_weapon_fists", false)) // Boss
	{
		result = true;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
stock ClearTimer(&Handle:hTimer)
{
	if (hTimer != INVALID_HANDLE)
	{
		KillTimer(hTimer);
		hTimer = INVALID_HANDLE;
	}
}
ZomEnableDisable()
{
	if (!g_bEnabled) {
		PrintToServer("\n[ZM]Disabled\n");
		//UnhookEvent("teamplay_round_start", OnRound);
		//UnhookEvent("player_death", OnPlayerDeath);
		//UnhookEvent("player_spawn", OnSpawn);
		//UnhookEvent("teamplay_setup_finished", OnSetup);
		//UnhookEvent("teamplay_point_captured", OnCaptured, EventHookMode_Post);
		//UnhookEvent("player_hurt", HookPlayerHurt);
		//UnhookEvent("post_inventory_application", Event_Resupply);
		//UnhookEvent("round_end", Event_RoundEnd);
		//UnhookEvent("teamplay_round_win", Event_RoundEnd);
		if (g_iSebep == 1) {
			PrintToServer("\n\n\n                                      **********[ZM]Disabled -- S E B E P // R E A S O N**********\n\n\n");
		}
		else if (g_iSebep == 2) {
			PrintToServer("\n\n\n                                      **********[ZM]Only ZM Maps! -- S E B E P // R E A S O N**********\n\n\n");
		}
	}
}


/* // ------------------------------                                            ------------------------------
         ------------------------------ M E N U    S E C T I O N ------------------------------
         ------------------------------                                            ------------------------------
 */
public Action:zmenu(client, args)
{
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "ZF Esas Menü");
	DrawPanelItem(panel, "Yardim");
	DrawPanelItem(panel, "Tercihler");
	DrawPanelItem(panel, "Yapımcılar");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleMain, 10);
	CloseHandle(panel);
}
public panel_HandleMain(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:
			{
				Yardim(param1);
			}
			case 2:
			{
				mzkv2(param1);
			}
			case 3:Yapimcilar(param1);
			default:return;
		}
	}
}
public mzk(Handle hMuzik, MenuAction action, client, item)
{
	if (action == MenuAction_Select)
	{
		switch (item)
		{
			case 0:
			{
				MuzikAc(client);
				OyuncuMuzikAyari(client, true);
			}
			
			case 1:
			{
				MuzikDurdurma(client);
				OyuncuMuzikAyari(client, false);
			}
		}
	}
}
public Action:msc(client, args)
{
	Menu hMuzik = new Menu(mzk);
	hMuzik.SetTitle("Müzik bölmesi");
	hMuzik.AddItem("Aç", "Aç");
	hMuzik.AddItem("Kapa", "Kapa");
	hMuzik.ExitButton = false;
	hMuzik.Display(client, 20);
	
}
MuzikDurdurma(client)
{
	PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Music Stop");
}
MuzikAc(client)
{
	PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Music Open");
}
OyuncuMuzikAyari(client, bool:acik)
{
	new String:strCookie[32];
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		if (acik)
		{
			strCookie = "1";
		} else {
			strCookie = "0";
			SetClientCookie(client, MusicCookie, strCookie);
		}
	}
	return bool:StringToInt(strCookie);
}
public yrd(Handle hYardim, MenuAction action, client, item)
{
	if (action == MenuAction_Select)
	{
		switch (item)
		{
			case 0:
			{
				HakkindaK(client);
			}
			case 1:
			{
				CloseHandle(hYardim);
			}
		}
	}
}
public HakkindaK(client)
{
	new Handle:panel = CreatePanel();
	
	SetPanelTitle(panel, "ZF Hakkında");
	DrawPanelText(panel, "----------------------------------------------");
	DrawPanelText(panel, "Zombie Fortress, oyuncuları zombiler ve insanlar");
	DrawPanelText(panel, "arası ölümcül bir savaşa sokan custom moddur.");
	DrawPanelText(panel, "Insanlar bu bitmek bilmeyen salgında hayatta kalmalıdır.");
	DrawPanelText(panel, "Eğer insan infekte(ölürse) zombi olur.");
	DrawPanelText(panel, "----------------------------------------------");
	DrawPanelText(panel, "Modu Kodlayan:steamId=crackersarenoice - Deniz");
	DrawPanelItem(panel, "Yardım menüsüne geri dön.");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleOverview, 10);
	CloseHandle(panel);
}
public panel_HandleOverview(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:Yardim(param1);
			default:return;
		}
	}
}
public Yapimcilar(client)
{
	new Handle:panel = CreatePanel();
	
	SetPanelTitle(panel, "Yapimci");
	DrawPanelText(panel, "Kodlayan:steamId=crackersarenoice - Deniz");
	DrawPanelItem(panel, "Yardim Menüsüne Geri Dön");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleYapimci, 10);
	CloseHandle(panel);
}
public panel_HandleYapimci(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:Yardim(param1);
			default:return;
		}
	}
}
public mzkv2(client)
{
	new Handle:panel = CreatePanel();
	
	SetPanelTitle(panel, "Tercihler - Müzik");
	DrawPanelItem(panel, "Aç");
	DrawPanelItem(panel, "Kapa");
	DrawPanelItem(panel, "Yardım menüsüne geri dön.");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleMuzik, 10);
	CloseHandle(panel);
}
public panel_HandleMuzik(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:MuzikAc(param1), OyuncuMuzikAyari(param1, true);
			case 2:MuzikDurdurma(param1), OyuncuMuzikAyari(param1, false);
			case 3:Yardim(param1);
			default:return;
		}
	}
}
Yardim(client)
{
	Menu hYardim = new Menu(yrd);
	hYardim.SetTitle("ZF Yardım Bölmesi(bilgi)");
	hYardim.AddItem("ZF Hakkında", "ZF Hakkında");
	hYardim.AddItem("Kapat", "Kapat");
	hYardim.ExitButton = false;
	hYardim.Display(client, 20);
}
/* //------------------------------------------------------------------------------------------
         ------------------------------------------------------------------------------------------
         ------------------------------------------------------------------------------------------
*/






/* // ------------------------------                                            ------------------------------
         ------------------------------ A D V E R T    S E C T I O N ------------------------------
         ------------------------------                                            ------------------------------
 */
public Action:yazi1(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCHazırlık süresi %02d:%02d (varsayılan) saniyedir.", GetConVarInt(zm_tHazirliksuresi) / 60, GetConVarInt(zm_tHazirliksuresi) % 60);
}
public Action:yazi2(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCHayatta kalmaya çalışın!");
}
public Action:yazi3(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCOyun içi müzikleri açmak veya kapatmak için [!msc] yazabilirsiniz.");
}
public Action:yazi4(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCOyun hakkında bilgi için [!menu] yazabilirsiniz.");
}
/* //------------------------------------------------------------------------------------------
         ------------------------------------------------------------------------------------------
         ------------------------------------------------------------------------------------------
*/


stock GetWeaponIndex(iWeapon)
{
	return IsValidEntity(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}

//-------------- Vault----------------------
//KAYITLI DATA

//We are saving the client data from here. To Vault file. This is for checking the client's current or future donator status.
public KayitliKullanicilar(client) {
	g_iVaultKullanicilar[client] = false; //CIZZZZ
	new Handle:DB = CreateKeyValues("VaultInfo");
	FileToKeyValues(DB, KVPath);
	new String:sClientAuth[128];
	GetClientAuthId(client, AuthId_Steam2, sClientAuth, sizeof(sClientAuth));
	PrintToServer(KVPath);
	if (KvJumpToKey(DB, sClientAuth, true)) {
		new String:name[MAX_NAME_LENGTH], String:temp_name[MAX_NAME_LENGTH], String:temp_userid[128];
		GetClientName(client, name, sizeof(name));
		KvGetString(DB, "name", temp_name, sizeof(temp_name), " ");
		KvGetString(DB, "userid", temp_userid, sizeof(temp_userid), " ");
		new donatorStatus = KvGetNum(DB, "donator");
		KvSetString(DB, "name", name);
		KvSetString(DB, "userid", sClientAuth);
		if (StrEqual(temp_userid, sClientAuth)) {  // Did we hit that player?
			if (donatorStatus == 1) {
				g_iVaultKullanicilar[client] = true;
			}
		}
		if (!g_iVaultKullanicilar[client]) {
			PrintToServer("Normal:%s", sClientAuth);
			KvSetNum(DB, "donator", 0);
		} else {
			PrintToServer("Donator:%s", sClientAuth);
		}
		KvRewind(DB);
		KeyValuesToFile(DB, KVPath);
		CloseHandle(DB);
	}
}
//Chat tags for specific players, you can remove this spot.
public Action:say(client, args)
{
	new String:argx[512];
	GetCmdArgString(argx, sizeof(argx));
	StripQuotes(argx);
	TrimString(argx);
	new String:sClientAuth[128];
	GetClientAuthId(client, AuthId_Steam2, sClientAuth, sizeof(sClientAuth));
	if (g_iVaultKullanicilar[client]) {
		if (StrEqual(sClientAuth, "STEAM_0:0:81591956", false)) {  //STEAM_0:0:81591956 Devil
			PrintToChatAll("\x0700FF00[ Developer ]\x07FFCC00%N: \x07FF0099%s", client, argx); //Özel Tag (Devil)
			return Plugin_Handled;
		}
		else if (StrEqual(sClientAuth, "STEAM_0:0:95142811", false)) {
			PrintToChatAll("\x0700FF00[ Gay Faggot ]\x07FFCC00%N: \x07FF0099%s", client, argx); //Özel Tag(Berke)
			return Plugin_Handled;
		}
		else if (StrEqual(sClientAuth, "STEAM_0:0:94605939", false)) {
			PrintToChatAll("\x0700FF00[ Superadmin ]\x07FFCC00%N: \x07FF0099%s", client, argx); //Özel Tag(Buğrahan)
			return Plugin_Handled;
		}
		return Plugin_Continue;
		//PrintToChatAll("\x0700FF00[ Donator ]\x07FFCC00%N: \x07FF0099%s", client, argx); //Kendilerine Özel Tag ayarlarız.
	} else {
		return Plugin_Continue;
	}
}
/*
--Usage for later.
	new setQueue[MAXPLAYERS + 1];
	new queuepoints[MAXPLAYERS + 1];
	new g_iActiveBoss[MAXPLAYERS + 1];
	new client = GetClientOfUserId(client);
	GetEntProp(queuepoints[client] , Prop_Data, "m_iScore");
	for (new i = 1; i <= MaxClients; i++) {
	        if (IsClientInGame(i) && GetClientTeam(i) == 3 && g_bOyun) {
			if(queuepoints[i] > 0) {
				for (new j = i; j < i; j++) {
					if(queuepoints[i] > queuepoints[j]) {
					         PrintToServer("%N", queuepoints[i]);
				                 setQueue[i] = g_iActiveBoss[i];
				                 if(g_iActiveBoss[i]) {
					                  PrintToServer("En yüksek puanla boss seçilen kişi:%N", g_iActiveBoss[i]);
			                         }
				        }
			        }
		        }
		}
         }
*/

/*
	if (StrEqual(weaponname, "tf_weapon_compound_bow", false) || StrEqual(weaponname, "tf_weapon_fists", false) || StrEqual(weaponname, "tf_weapon_crossbow", false))
	{
		result = true;
		return Plugin_Changed;
	}
*/

/*
 LOGICs
*/

logGameRuleTeamRegister() {  //Registers the Team indexes (Most likely usage for OnMapStart() )
	if (g_iMapPrefixType == 1 || g_iMapPrefixType == 2) {
		g_iZomTeamIndex = 3; //We'll set Blue team as a zombie for those maps
		g_iHumTeamIndex = 2; //We'll set Red team as a human for those maps
		PrintToServer("\nGame Rules Changed, Zombie team is Blue, Human team is Red\n");
	} //If the map is ZF or ZM 
	else if (g_iMapPrefixType == 3 || g_iMapPrefixType == 4 || g_iMapPrefixType == 5 || g_iMapPrefixType == 6) {
		g_iZomTeamIndex = 2; //We'll set Red team as a zombie for those maps
		g_iHumTeamIndex = 3; //We'll set Blue team as a zombie for those maps
		PrintToServer("\nGame Rules Changed, Zombie team is Red, Human team is Blue\n");
	} // If the map is ZM, ZS, ZOM, ZE
} 