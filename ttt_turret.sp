#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <vphysics>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] 哨界机枪",
    author = "Jw2s5",
    description = "TTT道具 - 叛徒专属哨界机枪",
    version = "1.0",
    url = ""
}

#define TURRET_MODEL      "models/combine_turrets/floor_turret.mdl"

#define TURRET_DAMAGE     7.0
#define TURRET_RANGE      600.0
#define TURRET_FIRE_RATE  0.15
#define TURRET_ANGLE      18.0

#define SND_ALARM         "ttt/alarm.mp3"
#define SND_SHOOT_1       "ttt/shoot1.mp3"
#define SND_SHOOT_2       "ttt/shoot2.mp3"
#define SND_SHOOT_3       "ttt/shoot3.mp3"

#define SND_MODEL_ACTIVE  "npc/turret_floor/active.wav"
#define SND_MODEL_DEPLOY  "npc/turret_floor/deploy.wav"
#define SND_MODEL_RETRACT "npc/turret_floor/retract.wav"
#define SND_MODEL_DIE     "npc/turret_floor/die.wav"

#define SOUND_REPEAT      5

int g_ItemID;

int g_iTurretEntity[MAXPLAYERS + 1];
bool g_bTurretActive[MAXPLAYERS + 1];
bool g_bHasTurret[MAXPLAYERS + 1];

Handle g_hFireTimer[MAXPLAYERS + 1];
Handle g_hSoundTimer[MAXPLAYERS + 1];
int g_iSoundPhase[MAXPLAYERS + 1];
int g_iSoundCount[MAXPLAYERS + 1];
float g_fTurretAngle[MAXPLAYERS + 1][3];

public OnConfigsExecuted()
{
    g_ItemID = TTT_RegisterShopItem("哨界机枪", ITEMTYPE_ActiveEquip, "放置自动攻击前方玩家的哨界机枪", 1, TTT_ROLE_TRAITOR, -1, 1, 0);
}

public OnMapStart()
{
    PrecacheModel(TURRET_MODEL, true);

    PrecacheSound(SND_ALARM, true);
    PrecacheSound(SND_SHOOT_1, true);
    PrecacheSound(SND_SHOOT_2, true);
    PrecacheSound(SND_SHOOT_3, true);

    PrecacheSound(SND_MODEL_ACTIVE, true);
    PrecacheSound(SND_MODEL_DEPLOY, true);
    PrecacheSound(SND_MODEL_RETRACT, true);
    PrecacheSound(SND_MODEL_DIE, true);
    PrecacheSound("npc/turret_floor/shoot1.wav", true);
    PrecacheSound("npc/turret_floor/shoot2.wav", true);
    PrecacheSound("npc/turret_floor/shoot3.wav", true);

}

public OnPluginEnd()
{
    if(g_ItemID) TTT_RemoveShopItem(g_ItemID);
    RemoveAllTurrets();
}

public OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    RemoveAllTurrets();

    for(int i = 1; i <= MaxClients; i++)
    {
        g_bHasTurret[i] = false;
        g_bTurretActive[i] = false;
        g_iTurretEntity[i] = -1;
        g_hFireTimer[i] = INVALID_HANDLE;
        g_hSoundTimer[i] = INVALID_HANDLE;
        g_fTurretAngle[i][0] = 0.0;
        g_fTurretAngle[i][1] = 0.0;
        g_fTurretAngle[i][2] = 0.0;
    }
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    RemoveAllTurrets();
    return Plugin_Continue;
}

public Action TTT_OnItemPurchase(int client, int ItemID)
{
    if(ItemID == g_ItemID)
    {
        if(g_bHasTurret[client])
        {
            CPrintToChat(client, "%s您已拥有该道具！", TTT_TAG);
            return Plugin_Handled;
        }

        g_bHasTurret[client] = true;
        CPrintToChat(client, "%s{green}哨界机枪已激活！{default}按 {yellow}F + 左键{default} 放置", TTT_TAG);
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if(!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Continue;

    static int lastButtons[MAXPLAYERS + 1];

    if(g_bHasTurret[client])
    {
        bool bFKey = (impulse == 100);
        bool bAttack = (buttons & IN_ATTACK) != 0;
        bool bLastAttack = (lastButtons[client] & IN_ATTACK) != 0;

        if(bFKey && bAttack && !bLastAttack)
        {
            PlaceTurret(client);
            buttons &= ~IN_ATTACK;
            lastButtons[client] = buttons;
            return Plugin_Changed;
        }
    }

    bool bUse = (buttons & IN_USE) != 0;
    bool bLastUse = (lastButtons[client] & IN_USE) != 0;

    if(bUse && !bLastUse)
    {
        int ent = EntRefToEntIndex(g_iTurretEntity[client]);
        if(ent > 0 && IsValidEntity(ent))
        {
            float clientPos[3], turretPos[3];
            GetClientAbsOrigin(client, clientPos);
            GetEntPropVector(ent, Prop_Send, "m_vecOrigin", turretPos);

            if(GetVectorDistance(clientPos, turretPos) <= 150.0)
            {
                if(g_bTurretActive[client])
                    StopTurret(client);
                else
                    StartTurret(client);
            }
        }
    }

    lastButtons[client] = buttons;
    return Plugin_Continue;
}

void PlaceTurret(int client)
{
    if(g_iTurretEntity[client] != -1)
    {
        int oldEnt = EntRefToEntIndex(g_iTurretEntity[client]);
        if(IsValidEntity(oldEnt))
        {
            CPrintToChat(client, "%s您已经放置过机枪了！", TTT_TAG);
            return;
        }
        g_iTurretEntity[client] = -1;
    }

    float origin[3], angles[3];
    GetClientAbsOrigin(client, origin);
    GetClientAbsAngles(client, angles);

    g_fTurretAngle[client][0] = angles[0];
    g_fTurretAngle[client][1] = angles[1];
    g_fTurretAngle[client][2] = angles[2];

    int ent = CreateEntityByName("prop_physics_override");
    if(ent == -1)
        return;

    DispatchKeyValue(ent, "model", TURRET_MODEL);
    DispatchKeyValue(ent, "targetname", "ttt_turret");
    DispatchKeyValue(ent, "solid", "6");
    DispatchKeyValue(ent, "spawnflags", "0");

    if(!DispatchSpawn(ent))
    {
        AcceptEntityInput(ent, "Kill");
        return;
    }

    TeleportEntity(ent, origin, angles, NULL_VECTOR);

    SetEntityMoveType(ent, MOVETYPE_VPHYSICS);
    SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
    SetEntProp(ent, Prop_Data, "m_nSolidType", 6);
    SetEntProp(ent, Prop_Data, "m_takedamage", 0, 1);
    SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);

 Phys_SetMass(ent, 30.0);

    SDKHook(ent, SDKHook_SetTransmit, Hook_SetTransmit_Turret);

    g_iTurretEntity[client] = EntIndexToEntRef(ent);
    g_bHasTurret[client] = false;
    g_bTurretActive[client] = false;

    CPrintToChat(client, "%s{green}已放置哨界机枪！{default}对着它按 {yellow}E{default} 激活/取消", TTT_TAG);
}

void StartTurret(int client)
{
    if(g_bTurretActive[client])
        return;

    int ent = EntRefToEntIndex(g_iTurretEntity[client]);
    if(ent <= 0 || !IsValidEntity(ent))
        return;

    g_bTurretActive[client] = true;
    g_iSoundPhase[client] = 0;
    g_iSoundCount[client] = 0;

    EmitSoundToAll(SND_MODEL_ACTIVE, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 0.8);
    EmitSoundToAll(SND_MODEL_DEPLOY, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 0.8);

    g_hFireTimer[client] = CreateTimer(TURRET_FIRE_RATE, Timer_Fire, client, TIMER_REPEAT);

    g_hSoundTimer[client] = CreateTimer(0.5, Timer_Sound, client, TIMER_REPEAT);
    Timer_Sound(INVALID_HANDLE, client);

    CPrintToChat(client, "%s{green}激活！", TTT_TAG);
}

void StopTurret(int client)
{
    if(!g_bTurretActive[client])
        return;

    g_bTurretActive[client] = false;

    if(g_hFireTimer[client] != INVALID_HANDLE && IsValidHandle(g_hFireTimer[client]))
        KillTimer(g_hFireTimer[client]);
    g_hFireTimer[client] = INVALID_HANDLE;

    if(g_hSoundTimer[client] != INVALID_HANDLE && IsValidHandle(g_hSoundTimer[client]))
        KillTimer(g_hSoundTimer[client]);
    g_hSoundTimer[client] = INVALID_HANDLE;

    int ent = EntRefToEntIndex(g_iTurretEntity[client]);
    if(ent > 0 && IsValidEntity(ent))
    {
        EmitSoundToAll(SND_MODEL_RETRACT, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 0.8);

        StopSound(ent, SNDCHAN_AUTO, SND_SHOOT_1);
        StopSound(ent, SNDCHAN_AUTO, SND_SHOOT_2);
        StopSound(ent, SNDCHAN_AUTO, SND_SHOOT_3);
        StopSound(ent, SNDCHAN_AUTO, SND_ALARM);
    }
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!TTT_IsClientValid(i)) continue;
        StopSound(i, SNDCHAN_AUTO, SND_SHOOT_1);
        StopSound(i, SNDCHAN_AUTO, SND_SHOOT_2);
        StopSound(i, SNDCHAN_AUTO, SND_SHOOT_3);
        StopSound(i, SNDCHAN_AUTO, SND_ALARM);
    }

    if(TTT_IsClientValid(client))
        CPrintToChat(client, "%s{yellow}取消", TTT_TAG);
}

public Action Timer_Fire(Handle timer, int client)
{
    if(!g_bTurretActive[client])
        return Plugin_Stop;

    int ent = EntRefToEntIndex(g_iTurretEntity[client]);
    if(ent <= 0 || !IsValidEntity(ent))
    {
        g_bTurretActive[client] = false;
        g_hFireTimer[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    float turretPos[3], turretAng[3];
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", turretPos);
    turretPos[2] += 30.0;

    turretAng[0] = g_fTurretAngle[client][0];
    turretAng[1] = g_fTurretAngle[client][1];
    turretAng[2] = g_fTurretAngle[client][2];

    float turretFwd[3];
    GetAngleVectors(turretAng, turretFwd, NULL_VECTOR, NULL_VECTOR);

    int bestTarget = -1;
    float bestDist = TURRET_RANGE;

    for(int i = 1; i <= MaxClients; i++)
    {
        if(!TTT_IsClientValid(i) || !IsPlayerAlive(i))
            continue;

        float targetPos[3];
        GetClientAbsOrigin(i, targetPos);
        targetPos[2] += 40.0;

        float toTarget[3];
        SubtractVectors(targetPos, turretPos, toTarget);
        float dist = GetVectorLength(toTarget);

        if(dist > TURRET_RANGE)
            continue;

        NormalizeVector(toTarget, toTarget);
        float dot = GetVectorDotProduct(turretFwd, toTarget);

        float cosAngle = Cosine(DegToRad(TURRET_ANGLE));
        if(dot < cosAngle)
            continue;

        Handle trace = TR_TraceRayFilterEx(turretPos, targetPos, MASK_SHOT, RayType_EndPoint, TraceFilter_Turret, ent);
        int hitEnt = TR_GetEntityIndex(trace);
        delete trace;

        if(hitEnt != i)
            continue;

        if(dist < bestDist)
        {
            bestDist = dist;
            bestTarget = i;
        }
    }

    if(bestTarget != -1)
    {
        int r = GetRandomInt(1, 3);
        char snd[64];
        Format(snd, sizeof(snd), "npc/turret_floor/shoot%d.wav", r);
        EmitSoundToAll(snd, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 0.8);

        SDKHooks_TakeDamage(bestTarget, ent, ent, TURRET_DAMAGE, DMG_BULLET);
    }

    return Plugin_Continue;
}

public Action Timer_Sound(Handle timer, int client)
{
    if(!g_bTurretActive[client])
    {
        g_hSoundTimer[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    int ent = EntRefToEntIndex(g_iTurretEntity[client]);
    if(ent <= 0 || !IsValidEntity(ent))
    {
        g_bTurretActive[client] = false;
        g_hSoundTimer[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    char sound[64];
    sound[0] = '\0';

    if(g_iSoundPhase[client] == 0)
    {
        g_iSoundCount[client]++;
        if(g_iSoundCount[client] > SOUND_REPEAT)
        {
            g_iSoundPhase[client] = 1;
            g_iSoundCount[client] = 1;
        }
        else
        {
            int r = GetRandomInt(1, 3);
            Format(sound, sizeof(sound), "ttt/shoot%d.mp3", r);
        }
    }

    if(g_iSoundPhase[client] == 1)
    {
        g_iSoundCount[client]++;
        if(g_iSoundCount[client] > SOUND_REPEAT)
        {
            g_iSoundPhase[client] = 0;
            g_iSoundCount[client] = 1;
        }
        else
        {
            Format(sound, sizeof(sound), "%s", SND_ALARM);
        }
    }

    if(strlen(sound) > 0)
    {
        EmitSoundToAll(sound, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 0.8);
    }

    return Plugin_Continue;
}

public Action Hook_SetTransmit_Turret(int entity, int client)
{
    return Plugin_Continue;
}

public bool TraceFilter_Turret(int entity, int contentsMask, any data)
{
    if(entity == data) return false;
    return true;
}

void RemoveAllTurrets()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        StopTurret(i);

        int ent = EntRefToEntIndex(g_iTurretEntity[i]);
        if(ent > 0 && IsValidEntity(ent))
        {
            EmitSoundToAll(SND_MODEL_DIE, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 0.8);

            SDKUnhook(ent, SDKHook_SetTransmit, Hook_SetTransmit_Turret);
            AcceptEntityInput(ent, "Kill");
        }
        g_iTurretEntity[i] = -1;
        g_bHasTurret[i] = false;
        g_bTurretActive[i] = false;
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}