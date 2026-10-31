#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] 毒品注射剂",
    author = "Jw2s5",
    description = "TTT海洛因",
    version = "1.0",
    url = ""
}

#define WEAPON_BASE "weapon_ump45"
#define WEAPON_SLOT CS_SLOT_PRIMARY

#define DRUG_DURATION 10.0
#define EXPLODE_RADIUS 300.0
#define EXPLODE_DAMAGE 150.0

#define CHASE_SOUND "ttt/scp/chase.wav"
#define CHASE_SOUND_RANGE 1500.0

int g_ItemID;

bool g_bDrugged[MAXPLAYERS + 1];
Handle g_hDrugTimer[MAXPLAYERS + 1];
float g_fDrugStart[MAXPLAYERS + 1];

bool g_bDeathRecorded[MAXPLAYERS + 1];
float g_fDeathPos[MAXPLAYERS + 1][3];

public OnConfigsExecuted()
{
    g_ItemID = TTT_RegisterShopItem("海洛因", ITEMTYPE_WEAPON, "击中目标后使其扭曲10秒后自爆", 1, TTT_ROLE_TRAITOR, -1, 1, 0);
}

public OnMapStart()
{
    PrecacheSound(CHASE_SOUND, true);
    
    char buffer[256];
    Format(buffer, sizeof(buffer), "sound/%s", CHASE_SOUND);
    AddFileToDownloadsTable(buffer);
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
    
    CreateTimer(0.1, Timer_DrugThink, _, TIMER_REPEAT);
    
    RegConsoleCmd("sm_drug", Command_Drug);
}

public Action Command_Drug(int client, int args)
{
    if(!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Handled;
    
    StartDrug(client, client);
    CPrintToChat(client, "%s{red}已对自己注射毒品！", TTT_TAG);
    return Plugin_Handled;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        ClearDrug(i);
    }
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(IsClientValid(client))
    {
        if(g_bDrugged[client])
        {
            GetClientAbsOrigin(client, g_fDeathPos[client]);
            g_bDeathRecorded[client] = true;
            
            for(int i = 1; i <= MaxClients; i++)
            {
                if(IsClientValid(i))
                {
                    StopSound(i, SNDCHAN_AUTO, CHASE_SOUND);
                }
            }
        }
    }
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
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
    
    StartDrug(attacker, victim);
    return Plugin_Handled;
}

void StartDrug(int attacker, int target)
{
    if(g_bDrugged[target])
        return;
    
    ClearDrug(target);
    
    g_bDrugged[target] = true;
    g_fDrugStart[target] = GetGameTime();
    g_bDeathRecorded[target] = false;
    
    CPrintToChat(target, "%s{yellow}中毒！", TTT_TAG);
    CPrintToChat(target, "%s{green}中毒！", TTT_TAG);
    CPrintToChat(target, "%s{red}你被注射了毒品！", TTT_TAG);
    
    SetEntPropFloat(target, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
    SetEntProp(target, Prop_Send, "m_iProgressBarDuration", 10);
    
    PlayChaseSound(target);
    
    g_hDrugTimer[target] = CreateTimer(DRUG_DURATION, Timer_Explode, target);
}

void PlayChaseSound(int client)
{
    if(!IsClientValid(client) || !IsPlayerAlive(client))
        return;
    
    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientValid(i) || !IsPlayerAlive(i))
            continue;
        
        float playerPos[3];
        GetClientAbsOrigin(i, playerPos);
        
        if(GetVectorDistance(clientPos, playerPos) <= CHASE_SOUND_RANGE)
        {
            EmitSoundToClient(i, CHASE_SOUND, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 1.0);
        }
    }
}

public Action Timer_Explode(Handle timer, int client)
{
    g_hDrugTimer[client] = INVALID_HANDLE;
    
    if(!IsClientValid(client))
        return Plugin_Stop;
    
    if(!g_bDrugged[client])
        return Plugin_Stop;
    
    float origin[3];
    
    if(g_bDeathRecorded[client])
    {
        origin = g_fDeathPos[client];
        g_bDeathRecorded[client] = false;
    }
    else
    {
        if(!IsPlayerAlive(client))
            return Plugin_Stop;
        
        GetClientAbsOrigin(client, origin);
        ForcePlayerSuicide(client);
    }
    
    origin[2] += 20.0;
    
    int expl = CreateEntityByName("env_explosion");
    if(expl != -1)
    {
        DispatchKeyValue(expl, "classname", "hegrenade_projectile");
        DispatchKeyValueVector(expl, "origin", origin);
        DispatchKeyValueInt(expl, "spawnflags", 6146);
        SetEntPropEnt(expl, Prop_Send, "m_hOwnerEntity", client);
        DispatchSpawn(expl);
        DispatchKeyValueInt(expl, "iMagnitude", RoundToNearest(EXPLODE_DAMAGE));
        DispatchKeyValueInt(expl, "iRadiusOverride", RoundToNearest(EXPLODE_RADIUS));
        ActivateEntity(expl);
        AcceptEntityInput(expl, "Explode");
        DispatchKeyValue(expl, "classname", "env_explosion");
        AcceptEntityInput(expl, "Kill");
    }
    
    ClearDrug(client);
    
    return Plugin_Stop;
}

public Action Timer_DrugThink(Handle timer)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientValid(i) || !g_bDrugged[i])
            continue;
        
        if(!IsPlayerAlive(i))
            continue;
        
        float ang[3];
        GetClientEyeAngles(i, ang);
        ang[1] += GetRandomFloat(-5.0, 5.0);
        ang[0] += GetRandomFloat(-2.0, 2.0);
        TeleportEntity(i, NULL_VECTOR, ang, NULL_VECTOR);
        
        float myPos[3];
        GetClientAbsOrigin(i, myPos);
        
        int target = -1;
        float targetDist = 999999.0;
        
        for(int j = 1; j <= MaxClients; j++)
        {
            if(!IsClientValid(j) || !IsPlayerAlive(j) || j == i)
                continue;
            
            int targetRole = TTT_GetClientRole(j);
            if(targetRole != TTT_ROLE_INNOCENT && targetRole != TTT_ROLE_DETECTIVE)
                continue;
            
            float targetPos[3];
            GetClientAbsOrigin(j, targetPos);
            float dist = GetVectorDistance(myPos, targetPos);
            
            if(dist < targetDist)
            {
                targetDist = dist;
                target = j;
            }
        }
        
        if(target != -1)
        {
            float targetPos[3];
            GetClientAbsOrigin(target, targetPos);
            
            float dir[3];
            MakeVectorFromPoints(myPos, targetPos, dir);
            NormalizeVector(dir, dir);
            ScaleVector(dir, 265.0);
            
            TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, dir);
        }
    }
    
    return Plugin_Continue;
}

void ClearDrug(int client)
{
    g_bDrugged[client] = false;
    g_fDrugStart[client] = 0.0;
    g_bDeathRecorded[client] = false;
    
    if(g_hDrugTimer[client] != INVALID_HANDLE && IsValidHandle(g_hDrugTimer[client]))
    {
        KillTimer(g_hDrugTimer[client]);
    }
    g_hDrugTimer[client] = INVALID_HANDLE;
    
    if(IsClientValid(client))
    {
        SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}