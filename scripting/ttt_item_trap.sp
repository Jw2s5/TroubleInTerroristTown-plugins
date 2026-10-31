#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] 捕兽夹",
    author = "Jw2s5",
    description = "TTT道具 - 叛徒专属捕兽夹",
    version = "1.0",
    url = ""
}

#define TRAP_MODEL_OPEN "models/murdered/traps/trap.mdl"
#define TRAP_MODEL_CLOSE "models/murdered/traps/trap_close.mdl"
#define TRAP_ICON "materials/trap/trap_texture.vmt"

#define VIEW_DISTANCE 800.0
#define TRIGGER_RADIUS 24.0
#define MAX_TRAPS 32

int g_ItemID;

int g_iTrapEntity[MAX_TRAPS];
int g_iTrapOwner[MAX_TRAPS];
bool g_bTrapTriggered[MAX_TRAPS];
int g_iTrapCount = 0;

bool g_bHasItem[MAXPLAYERS + 1];
float g_fLastPlaceTime[MAXPLAYERS + 1];
int g_iLastButtons[MAXPLAYERS + 1];

public OnConfigsExecuted()
{
    g_ItemID = TTT_RegisterShopItem("捕兽夹", ITEMTYPE_PassiveEquip, "R+E一起按放置捕兽夹", 1, TTT_ROLE_TRAITOR, -1, 1, 0);
}

public OnMapStart()
{
    PrecacheModel(TRAP_MODEL_OPEN, true);
    PrecacheModel(TRAP_MODEL_CLOSE, true);
    PrecacheModel(TRAP_ICON, true);

    PrecacheSound("physics/metal/metal_box_impact_hard1.wav", true);
    PrecacheSound("physics/metal/metal_box_impact_hard2.wav", true);
    PrecacheSound("physics/metal/metal_box_impact_hard3.wav", true);
}

public OnPluginEnd()
{
    if(g_ItemID) TTT_RemoveShopItem(g_ItemID);
    RemoveAllTraps();
}

public OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    RemoveAllTraps();

    for(int i = 1; i <= MaxClients; i++)
    {
        g_bHasItem[i] = false;
        g_fLastPlaceTime[i] = 0.0;
        g_iLastButtons[i] = 0;
    }
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    RemoveAllTraps();
    return Plugin_Continue;
}

public Action TTT_OnItemPurchase(int client, int ItemID)
{
    if(ItemID == g_ItemID)
    {
        if(g_bHasItem[client])
        {
            CPrintToChat(client, "%s您已拥有该道具！", TTT_TAG);
            return Plugin_Handled;
        }

        g_bHasItem[client] = true;
        CPrintToChat(client, "%s{green}捕兽夹已激活！{default}按 {yellow}R + E{default} 释放", TTT_TAG);
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if(!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Continue;

    if(!g_bHasItem[client])
        return Plugin_Continue;

    if(TTT_GetClientRole(client) != TTT_ROLE_TRAITOR)
        return Plugin_Continue;

    bool bReload = (buttons & IN_RELOAD) != 0;
    bool bUse = (buttons & IN_USE) != 0;
    bool bLastUse = (g_iLastButtons[client] & IN_USE) != 0;

    if(bReload && bUse && !bLastUse)
    {
        int target = GetClientAimTarget(client, false);
        bool bIsBody = false;

        if(IsValidEntity(target))
        {
            char classname[32];
            GetEntityClassname(target, classname, sizeof(classname));
            if(StrEqual(classname, "prop_ragdoll"))
                bIsBody = true;
        }

        if(!bIsBody)
        {
            if(GetGameTime() - g_fLastPlaceTime[client] >= 1.0)
            {
                PlaceTrap(client);
                g_fLastPlaceTime[client] = GetGameTime();

                buttons &= ~IN_USE;
                g_iLastButtons[client] = buttons;
                return Plugin_Changed;
            }
        }
    }

    g_iLastButtons[client] = buttons;

    return Plugin_Continue;
}

void PlaceTrap(int client)
{
    if(g_iTrapCount >= MAX_TRAPS)
    {
        CPrintToChat(client, "%s捕兽夹数量已达上限！", TTT_TAG);
        return;
    }

    float origin[3], angles[3];
    GetClientAbsOrigin(client, origin);
    GetClientAbsAngles(client, angles);

    origin[2] += 2.0;
    angles[0] = 0.0;
    angles[2] = 0.0;

    int trap = CreateEntityByName("prop_dynamic_override");
    if(trap == -1)
        return;

    DispatchKeyValue(trap, "model", TRAP_MODEL_OPEN);
    DispatchKeyValue(trap, "classname", "ttt_trap");
    DispatchKeyValue(trap, "targetname", "trap");
    DispatchKeyValue(trap, "solid", "0");
    DispatchKeyValue(trap, "spawnflags", "0");
    DispatchKeyValue(trap, "disableshadows", "1");

    if(!DispatchSpawn(trap))
    {
        AcceptEntityInput(trap, "Kill");
        return;
    }

    TeleportEntity(trap, origin, angles, NULL_VECTOR);

    SetEntPropVector(trap, Prop_Send, "m_vecMins", {-10.0, -10.0, 0.0});
    SetEntPropVector(trap, Prop_Send, "m_vecMaxs", {10.0, 10.0, 8.0});
    SetEntProp(trap, Prop_Send, "m_nSolidType", 2);
    SetEntProp(trap, Prop_Send, "m_usSolidFlags", 4);

    SDKHook(trap, SDKHook_SetTransmit, Hook_SetTransmit_Trap);

    int slot = g_iTrapCount;
    g_iTrapEntity[slot] = EntIndexToEntRef(trap);
    g_iTrapOwner[slot] = client;
    g_bTrapTriggered[slot] = false;
    g_iTrapCount++;

    // ===== 关键：放置后道具失效，不能再放 =====
    g_bHasItem[client] = false;
    // =========================================

    CPrintToChat(client, "%s{green}已放置捕兽夹！", TTT_TAG);
}

public Action Hook_SetTransmit_Trap(int entity, int client)
{
    if(!IsClientValid(client))
        return Plugin_Handled;

    if(TTT_GetClientRole(client) == TTT_ROLE_TRAITOR)
        return Plugin_Continue;

    float trapPos[3], clientPos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", trapPos);
    GetClientAbsOrigin(client, clientPos);

    if(GetVectorDistance(trapPos, clientPos) <= VIEW_DISTANCE)
        return Plugin_Continue;

    return Plugin_Handled;
}

public void OnGameFrame()
{
    for(int i = 0; i < g_iTrapCount; i++)
    {
        if(g_bTrapTriggered[i])
            continue;

        int trap = EntRefToEntIndex(g_iTrapEntity[i]);
        if(!IsValidEntity(trap))
            continue;

        float trapPos[3];
        GetEntPropVector(trap, Prop_Send, "m_vecOrigin", trapPos);

        for(int client = 1; client <= MaxClients; client++)
        {
            if(!IsClientValid(client) || !IsPlayerAlive(client))
                continue;

            if(TTT_GetClientRole(client) == TTT_ROLE_TRAITOR)
                continue;

            if(IsPlayerInTrapRange(client, trapPos, trap))
            {
                TriggerTrap(i, client);
                break;
            }
        }
    }
}

bool IsPlayerInTrapRange(int client, float trapPos[3], int trap)
{
    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);

    float offsets[3] = {0.0, 15.0, 30.0};

    for(int i = 0; i < 3; i++)
    {
        float bonePos[3];
        bonePos[0] = clientPos[0];
        bonePos[1] = clientPos[1];
        bonePos[2] = clientPos[2] + offsets[i];

        if(GetVectorDistance(trapPos, bonePos) <= TRIGGER_RADIUS)
        {
            if(IsTrapVisible(trap, bonePos))
                return true;
        }
    }

    return false;
}

bool IsTrapVisible(int trap, float targetPos[3])
{
    float trapPos[3];
    GetEntPropVector(trap, Prop_Send, "m_vecOrigin", trapPos);
    trapPos[2] += 4.0;

    float endPos[3];
    endPos = targetPos;
    endPos[2] += 2.0;

    Handle trace = TR_TraceRayFilterEx(trapPos, endPos, MASK_SOLID, RayType_EndPoint, TraceFilter_Trap);

    bool bHit = TR_DidHit(trace);
    delete trace;

    return !bHit;
}

public bool TraceFilter_Trap(int entity, int contentsMask)
{
    if(entity >= 1 && entity <= MaxClients)
        return false;
    return true;
}

void TriggerTrap(int index, int victim)
{
    g_bTrapTriggered[index] = true;

    int trap = EntRefToEntIndex(g_iTrapEntity[index]);
    if(IsValidEntity(trap))
    {
        SetEntityModel(trap, TRAP_MODEL_CLOSE);

        char sound[64];
        Format(sound, sizeof(sound), "physics/metal/metal_box_impact_hard%d.wav", GetRandomInt(1, 3));
        EmitSoundToAll(sound, trap, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 1.0);
    }

    if(IsClientValid(victim) && IsPlayerAlive(victim))
    {
        int owner = g_iTrapOwner[index];
        if(IsClientValid(owner) && IsPlayerAlive(owner))
        {
            SDKHooks_TakeDamage(victim, trap, owner, 9999.0, DMG_SLASH);
        }
        else
        {
            SDKHooks_TakeDamage(victim, trap, trap, 9999.0, DMG_SLASH);
        }
        CPrintToChat(victim, "%s{red}你踩到了捕兽夹！", TTT_TAG);
    }
}

void RemoveAllTraps()
{
    for(int i = 0; i < g_iTrapCount; i++)
    {
        int trap = EntRefToEntIndex(g_iTrapEntity[i]);
        if(IsValidEntity(trap))
        {
            SDKUnhook(trap, SDKHook_SetTransmit, Hook_SetTransmit_Trap);
            AcceptEntityInput(trap, "Kill");
        }
        g_bTrapTriggered[i] = false;
    }
    g_iTrapCount = 0;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}