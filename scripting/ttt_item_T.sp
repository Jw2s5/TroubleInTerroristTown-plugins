#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] T病毒注释剂",
    author = "Jw2s5, Modified",
    description = "TTT道具 - 尸变注射器",
    version = "2.0",
    url = ""
}

#define WEAPON_BASE "weapon_mp5navy"
#define WEAPON_SLOT CS_SLOT_PRIMARY
#define SOUND_INFECT "ttt/biohazard_fire.mp3"
#define SOUND_NEARBY "ttt/biohazard_detected.mp3"
#define ZOMBIE_MODEL "models/zombie/fast.mdl"
#define ZOMBIE_HIDE_MODEL "models/blackout.mdl"
#define ZOMBIE_HEALTH 1850
#define ZOMBIE_DAMAGE 10

int g_ItemID;

bool g_bInfection[MAXPLAYERS + 1];
Handle g_hInfectionTimer[MAXPLAYERS + 1];
bool g_bFrozen[MAXPLAYERS + 1];
bool g_bDeathRecorded[MAXPLAYERS + 1];
float g_fDeathPos[MAXPLAYERS + 1][3];

int g_iZombie = -1;
int g_iZombieVisual = -1;
Handle g_hAttackTimer = INVALID_HANDLE;
int g_iZombieAttackTarget = -1;

int g_iLeaderOffset = -1;
int g_iZombieAnimState = -1;

public OnConfigsExecuted()
{
    g_ItemID = TTT_RegisterShopItem("T病毒注释剂", ITEMTYPE_WEAPON, "击中目标后使其尸变成丧尸", 1, TTT_ROLE_TRAITOR, -1, 1, 0);
}

public OnMapStart()
{
    PrecacheSound(SOUND_INFECT, true);
    PrecacheSound(SOUND_NEARBY, true);
    
    char buffer[256];
    Format(buffer, sizeof(buffer), "sound/%s", SOUND_INFECT);
    AddFileToDownloadsTable(buffer);
    Format(buffer, sizeof(buffer), "sound/%s", SOUND_NEARBY);
    AddFileToDownloadsTable(buffer);
    
    // 预缓存丧尸音效
    for(int i = 1; i <= 3; i++)
    {
        char sound[64];
        Format(sound, sizeof(sound), "ttt/zombie_idle%d.mp3", i);
        PrecacheSound(sound, true);
    }
    for(int i = 1; i <= 2; i++)
    {
        char sound[64];
        Format(sound, sizeof(sound), "ttt/zombie_attack%d.wav", i);
        PrecacheSound(sound, true);
    }
    
    PrecacheModel(ZOMBIE_MODEL, true);
    PrecacheModel(ZOMBIE_HIDE_MODEL, true);
    
    g_iLeaderOffset = FindSendPropInfo("CHostage", "m_leader");
}

public OnPluginEnd()
{
    if(g_ItemID) TTT_RemoveShopItem(g_ItemID);
}

public OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_end", Event_RoundEnd);
    
    RegConsoleCmd("sm_zmxxs", Command_Zombie);
}

public Action Command_Zombie(int client, int args)
{
    if(!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Handled;
    
    StartInfection(client, client);
    return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if(!IsClientValid(client))
        return Plugin_Continue;
    
    if(!g_bInfection[client])
        return Plugin_Continue;
    
    // 冻结移动
    vel[0] = 0.0;
    vel[1] = 0.0;
    vel[2] = 0.0;
    buttons = 0;
    impulse = 0;
    
    return Plugin_Changed;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        ClearInfection(i);
    }
    RemoveZombie();
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(IsClientValid(client))
    {
        if(g_bInfection[client])
        {
            GetClientAbsOrigin(client, g_fDeathPos[client]);
            g_bDeathRecorded[client] = true;
        }
    }
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    RemoveZombie();
    return Plugin_Continue;
}

public Action TTT_OnItemPurchase(int client, int ItemID)
{
    if(ItemID == g_ItemID)
    {
        int before_weapon = GetPlayerWeaponSlot(client, WEAPON_SLOT);
        if(before_weapon != -1)
        {
            char classname[32];
            GetEntityClassname(before_weapon, classname, sizeof(classname));
            if(StrEqual(classname, WEAPON_BASE))
            {
                CPrintToChat(client, "%s您已拥有该武器！", TTT_TAG);
                return Plugin_Handled;
            }
            else
            {
                CS_DropWeapon(client, before_weapon, false);
            }
        }
        int wepent = GivePlayerItem(client, WEAPON_BASE);
        if(IsValidEntity(wepent))
        {
            TTT_SetWeaponClip(wepent, 1);
            TTT_SetPlayerAmmo(client, wepent, 0);
        }
    }
    return Plugin_Continue;
}

public Action TTT_OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if(IsClientValid(attacker) && g_bInfection[attacker])
        return Plugin_Handled;
    
    if(!IsClientValid(attacker) || !IsPlayerAlive(attacker))
        return Plugin_Continue;
    
    if(!IsClientValid(victim) || !IsPlayerAlive(victim))
        return Plugin_Continue;
    
    if(attacker == victim)
        return Plugin_Continue;
    
    char classname[32];
    GetClientWeapon(attacker, classname, sizeof(classname));
    if(!StrEqual(classname, WEAPON_BASE))
        return Plugin_Continue;
    
    if(damagetype & DMG_BLAST)
        return Plugin_Continue;
    
    StartInfection(attacker, victim);
    
    return Plugin_Handled;
}

void StartInfection(int attacker, int target)
{
    if(g_bInfection[target])
        return;
    
    ClearInfection(target);
    
    g_bInfection[target] = true;
    g_bFrozen[target] = true;
    
    Handle msg = StartMessageOne("Fade", target, USERMSG_RELIABLE);
    if(msg != INVALID_HANDLE)
    {
        if(GetUserMessageType() == UM_Protobuf)
        {
            PbSetInt(msg, "duration", 1500);
            PbSetInt(msg, "hold_time", 1500);
            PbSetInt(msg, "flags", 0x0002);  // FFADE_MODULATE
            PbSetColor(msg, "clr", {0, 255, 0, 255});  // 绿色
        }
        else
        {
            BfWriteShort(msg, 500);           // duration (1/10秒)
            BfWriteShort(msg, 500);           // hold_time
            BfWriteShort(msg, 0x0002);      // flags
            BfWriteByte(msg, 0);            // r
            BfWriteByte(msg, 255);          // g
            BfWriteByte(msg, 0);            // b
            BfWriteByte(msg, 255);          // a
        }
        EndMessage();
    }
    // ==========================
    
    EmitSoundToClient(target, SOUND_INFECT);
    
    float targetPos[3];
    GetClientAbsOrigin(target, targetPos);
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientValid(i) || !IsPlayerAlive(i) || i == target)
            continue;
        
        float playerPos[3];
        GetClientAbsOrigin(i, playerPos);
        
        if(GetVectorDistance(targetPos, playerPos) <= 500.0)
        {
            EmitSoundToClient(i, SOUND_NEARBY);
        }
    }
    
    CPrintToChat(target, "%s{red}你已被感染！", TTT_TAG);
    CPrintToChat(target, "%s{red}你已被感染！", TTT_TAG);
    CPrintToChat(target, "%s{red}你已被感染！", TTT_TAG);
    
    SetEntPropFloat(target, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
    SetEntProp(target, Prop_Send, "m_iProgressBarDuration", 5);
    
    g_hInfectionTimer[target] = CreateTimer(5.0, Timer_TransformToZombie, target);
}

public Action Timer_TransformToZombie(Handle timer, int client)
{
    g_hInfectionTimer[client] = INVALID_HANDLE;
    
    if(!IsClientValid(client))
        return Plugin_Stop;
    
    if(!g_bInfection[client])
        return Plugin_Stop;
    
    SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
    
    float origin[3];
    
    if(g_bDeathRecorded[client])
    {
        origin = g_fDeathPos[client];
        g_bDeathRecorded[client] = false;
    }
    else
    {
        GetClientAbsOrigin(client, origin);
        ForcePlayerSuicide(client);
    }
    
    origin[2] += 10.0;
    
    g_bFrozen[client] = false;
    
    CreateTimer(0.1, Timer_KillRagdoll, GetClientUserId(client));
    
    CreateZombie(origin);
    
    ClearInfection(client);
    
    return Plugin_Stop;
}

public Action Timer_KillRagdoll(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if(IsClientValid(client))
    {
        int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
        if(ragdoll > 0 && IsValidEntity(ragdoll))
        {
            AcceptEntityInput(ragdoll, "Kill");
        }
    }
    return Plugin_Stop;
}

void CreateZombie(float origin[3])
{
    RemoveZombie();
    
    int zombie = CreateEntityByName("hostage_entity");
    if(zombie == -1)
        return;
    
    char entIndex[16];
    
    int visual = CreateEntityByName("prop_dynamic_ornament");
    if(visual == -1)
    {
        AcceptEntityInput(zombie, "Kill");
        return;
    }
    
    IntToString(EntIndexToEntRef(visual), entIndex, sizeof(entIndex)-1);
    
    DispatchKeyValue(zombie, "classname", "npc_zombie");
    DispatchKeyValue(zombie, "targetname", entIndex);
    DispatchKeyValue(zombie, "disableshadows", "1");
    DispatchSpawn(zombie);
    
    SetEntProp(zombie, Prop_Data, "m_iHealth", ZOMBIE_HEALTH);
    SetEntProp(zombie, Prop_Data, "m_iMaxHealth", ZOMBIE_HEALTH);
    SetEntityModel(zombie, ZOMBIE_HIDE_MODEL);
    
    DispatchKeyValue(visual, "model", ZOMBIE_MODEL);
    DispatchKeyValue(visual, "DefaultAnim", "Idle");
    DispatchKeyValue(visual, "spawnflags", "800");
    DispatchKeyValue(visual, "parent", entIndex);
    DispatchSpawn(visual);
    
    SetVariantString(entIndex);
    AcceptEntityInput(visual, "SetAttached");
    
    TeleportEntity(zombie, origin, NULL_VECTOR, NULL_VECTOR);
    
    SDKHook(zombie, SDKHook_Think, ZombieThink);
    SDKHook(zombie, SDKHook_OnTakeDamage, ZombieDamageHook);
    
    g_iZombie = EntIndexToEntRef(zombie);
    g_iZombieVisual = EntIndexToEntRef(visual);
    g_iZombieAnimState = -1;
}

public void ZombieThink(int zombie)
{
    if(!IsValidEntity(zombie))
    {
        RemoveZombie();
        return;
    }
    
    int health = GetEntProp(zombie, Prop_Data, "m_iHealth");
    if(health <= 0)
    {
        RemoveZombie();
        return;
    }
    
    if(g_hAttackTimer != INVALID_HANDLE)
        return;
    
    float zombiePos[3];
    GetEntPropVector(zombie, Prop_Data, "m_vecOrigin", zombiePos);
    
    int target = -1;
    float targetDist = 999999.0;
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientValid(i) || !IsPlayerAlive(i))
            continue;
        
        float targetPos[3];
        GetClientAbsOrigin(i, targetPos);
        float dist = GetVectorDistance(zombiePos, targetPos);
        
        if(dist < targetDist)
        {
            targetDist = dist;
            target = i;
        }
    }
    
    if(target == -1)
    {
        SetEntityMoveType(zombie, MOVETYPE_NONE);
        SetZombieAnimation("Idle", 0);
        return;
    }
    
    SetEntDataEnt2(zombie, g_iLeaderOffset, target);
    
    if(targetDist < 80.0)
    {
        SetEntityMoveType(zombie, MOVETYPE_NONE);
        SetZombieAnimation("BR2_Attack", 2);
        
        char attackSound[64];
        Format(attackSound, sizeof(attackSound), "ttt/zombie_attack%d.wav", GetRandomInt(1, 2));
        EmitSoundToAll(attackSound, zombie, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 1.0);
        
        if(IsClientValid(target) && IsPlayerAlive(target))
        {
            SDKHooks_TakeDamage(target, zombie, zombie, float(ZOMBIE_DAMAGE), DMG_SLASH);
        }
        
        g_hAttackTimer = CreateTimer(1.0, Timer_ResetAttack, EntIndexToEntRef(zombie));
    }
    else
    {
        if(GetRandomInt(0, 5) == 0)
        {
            char idleSound[64];
            Format(idleSound, sizeof(idleSound), "ttt/zombie_idle%d.wav", GetRandomInt(1, 3));
            EmitSoundToAll(idleSound, zombie, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 0.8);
        }
        
        SetEntityMoveType(zombie, MOVETYPE_STEP);
        SetZombieAnimation("walk_all", 1);
    }
}

public Action Timer_ResetAttack(Handle timer, int ref)
{
    g_hAttackTimer = INVALID_HANDLE;
    
    int zombie = EntRefToEntIndex(ref);
    if(!IsValidEntity(zombie))
        return Plugin_Stop;
    
    SetEntityMoveType(zombie, MOVETYPE_STEP);
    g_iZombieAttackTarget = -1;
    
    return Plugin_Stop;
}

void SetZombieAnimation(const char[] anim, int state)
{
    int visual = EntRefToEntIndex(g_iZombieVisual);
    if(!IsValidEntity(visual))
        return;
    
    if(g_iZombieAnimState == state)
        return;
    
    g_iZombieAnimState = state;
    
    SetVariantString(anim);
    AcceptEntityInput(visual, "SetAnimation");
}

public Action ZombieDamageHook(int zombie, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if(!IsValidEntity(zombie))
        return Plugin_Handled;
    
    int health = GetEntProp(zombie, Prop_Data, "m_iHealth") - RoundToNearest(damage);
    if(health < 0) health = 0;
    SetEntProp(zombie, Prop_Data, "m_iHealth", health);
    
    if(health <= 0)
    {
        RemoveZombie();
    }
    
    return Plugin_Handled;
}

void RemoveZombie()
{
    if(g_hAttackTimer != INVALID_HANDLE && IsValidHandle(g_hAttackTimer))
    {
        KillTimer(g_hAttackTimer);
        g_hAttackTimer = INVALID_HANDLE;
    }
    
    if(IsValidEntity(EntRefToEntIndex(g_iZombie)))
    {
        SDKUnhook(EntRefToEntIndex(g_iZombie), SDKHook_Think, ZombieThink);
        SDKUnhook(EntRefToEntIndex(g_iZombie), SDKHook_OnTakeDamage, ZombieDamageHook);
        AcceptEntityInput(EntRefToEntIndex(g_iZombie), "Kill");
    }
    
    if(IsValidEntity(EntRefToEntIndex(g_iZombieVisual)))
    {
        AcceptEntityInput(EntRefToEntIndex(g_iZombieVisual), "Kill");
    }
    
    g_iZombie = -1;
    g_iZombieVisual = -1;
    g_iZombieAnimState = -1;
    g_iZombieAttackTarget = -1;
}

void ClearInfection(int client)
{
    g_bInfection[client] = false;
    g_bFrozen[client] = false;
    g_bDeathRecorded[client] = false;
    
    if(g_hInfectionTimer[client] != INVALID_HANDLE && IsValidHandle(g_hInfectionTimer[client]))
    {
        KillTimer(g_hInfectionTimer[client]);
    }
    g_hInfectionTimer[client] = INVALID_HANDLE;
    
    if(IsClientValid(client))
    {
        SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
    }
}

int GetTargetInCrosshair(int client)
{
    float eyePos[3], eyeAngles[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAngles);
    
    float dir[3];
    GetAngleVectors(eyeAngles, dir, NULL_VECTOR, NULL_VECTOR);
    
    int bestTarget = -1;
    float bestDot = 0.9;
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientValid(i) || i == client || !IsPlayerAlive(i))
            continue;
        
        float targetPos[3];
        GetClientAbsOrigin(i, targetPos);
        targetPos[2] += 40.0;
        
        float toTarget[3];
        SubtractVectors(targetPos, eyePos, toTarget);
        float dist = GetVectorLength(toTarget);
        
        if(dist > 3000.0)
            continue;
        
        NormalizeVector(toTarget, toTarget);
        
        float dot = GetVectorDotProduct(dir, toTarget);
        
        if(dot > bestDot)
        {
            bestDot = dot;
            bestTarget = i;
        }
    }
    
    return bestTarget;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}