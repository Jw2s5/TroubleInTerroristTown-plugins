#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] 假尸体",
    author = "Jw2s5",
    description = "TTT道具 - 左键释放假尸体",
    version = "1.0",
    url = ""
}

#define CHEER_SOUND "cheer/cheer_1.wav"

int g_ItemID;

// 只允许存在一个假尸体
int g_iFakeBody = -1;

bool g_bHasItem[MAXPLAYERS + 1];
int g_iLastButtons[MAXPLAYERS + 1];
float g_fLastSpawnTime[MAXPLAYERS + 1];

public OnConfigsExecuted()
{
    g_ItemID = TTT_RegisterShopItem("假尸体", ITEMTYPE_PassiveEquip, "F+左键一起按释放假尸体", 1, TTT_ROLE_TRAITOR, -1, -1, 0);
}

public OnMapStart()
{
    PrecacheSound(CHEER_SOUND, true);

    char buffer[128];
    Format(buffer, sizeof(buffer), "sound/%s", CHEER_SOUND);
    AddFileToDownloadsTable(buffer);
}

public OnPluginEnd()
{
    if(g_ItemID) TTT_RemoveShopItem(g_ItemID);
    RemoveFakeBody();
}

public OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    RemoveFakeBody();

    for(int i = 1; i <= MaxClients; i++)
    {
        g_bHasItem[i] = false;
        g_iLastButtons[i] = 0;
        g_fLastSpawnTime[i] = 0.0;
    }
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    RemoveFakeBody();
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
        CPrintToChat(client, "%s{green}假尸体已激活！{default}一起按 {yellow}F{default} + {yellow}左键{default} 释放假尸体", TTT_TAG);
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if(!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Continue;

    if(g_bHasItem[client])
    {
        bool bFKey = (impulse == 100);
        bool bAttack = (buttons & IN_ATTACK) != 0;
        bool bLastAttack = (g_iLastButtons[client] & IN_ATTACK) != 0;

        if(bFKey && bAttack && !bLastAttack)
        {
            if(GetGameTime() - g_fLastSpawnTime[client] >= 1.0)
            {
                SpawnFakeBody(client);
                g_fLastSpawnTime[client] = GetGameTime();

                buttons &= ~IN_ATTACK;
                g_iLastButtons[client] = buttons;
                return Plugin_Changed;
            }
        }
    }

    static bool bLastUse[MAXPLAYERS + 1];
    bool bUse = (buttons & IN_USE) != 0;

    if(bUse && !bLastUse[client])
    {
        int body = EntRefToEntIndex(g_iFakeBody);
        if(body > 0 && IsValidEntity(body))
        {
            float clientPos[3], bodyPos[3];
            GetClientAbsOrigin(client, clientPos);
            GetEntPropVector(body, Prop_Send, "m_vecOrigin", bodyPos);

            if(GetVectorDistance(clientPos, bodyPos) <= 100.0)
            {
                float eyePos[3], eyeAngles[3];
                GetClientEyePosition(client, eyePos);
                GetClientEyeAngles(client, eyeAngles);

                Handle trace = TR_TraceRayFilterEx(eyePos, eyeAngles, MASK_SOLID, RayType_Infinite, TraceFilter_FakeBody, body);
                if(TR_DidHit(trace))
                {
                    int hitEnt = TR_GetEntityIndex(trace);
                    CloseHandle(trace);

                    if(hitEnt == body)
                    {
                        RemoveFakeBody();

                        CPrintToChat(client, "%s{green}哈哈哈哈{red}这是一个假尸体", TTT_TAG);
                        CPrintToChatAll("%s{green}哈哈哈哈 {yellow}%N{default} 中陷阱了{red}(假尸体)", TTT_TAG, client);

                        EmitSoundToClient(client, CHEER_SOUND);
                        ForcePlayerSuicide(client);
                    }
                }
                else
                {
                    CloseHandle(trace);
                }
            }
        }
    }

    bLastUse[client] = bUse;
    g_iLastButtons[client] = buttons;

    return Plugin_Continue;
}

public bool TraceFilter_FakeBody(int entity, int contentsMask, any data)
{
    if(entity == data) return true;
    if(entity == 0) return true;
    return false;
}

void SpawnFakeBody(int client)
{
    if(g_iFakeBody != -1)
    {
        int existing = EntRefToEntIndex(g_iFakeBody);
        if(IsValidEntity(existing))
        {
            CPrintToChat(client, "%s已有一个假尸体，请先移除！", TTT_TAG);
            return;
        }
        else
        {
            g_iFakeBody = -1;
        }
    }

    float bodyPos[3];
    GetClientAbsOrigin(client, bodyPos);
    bodyPos[2] += 60.0;

    float angles[3];
    GetClientAbsAngles(client, angles);

    char model[128];
    GetClientModel(client, model, sizeof(model));

    int body = CreateEntityByName("prop_ragdoll");
    if(body == -1)
        return;

    DispatchKeyValue(body, "model", model);
    DispatchKeyValue(body, "classname", "ttt_fakebody");
    DispatchKeyValue(body, "targetname", "fakebody");
    DispatchKeyValue(body, "solid", "6");
    DispatchKeyValue(body, "spawnflags", "0");
    DispatchKeyValue(body, "movetype", "6");

    if(!DispatchSpawn(body))
    {
        AcceptEntityInput(body, "Kill");
        return;
    }

    TeleportEntity(body, bodyPos, angles, NULL_VECTOR);
    ActivateEntity(body);

    SetEntityMoveType(body, MOVETYPE_VPHYSICS);

    SetEntProp(body, Prop_Data, "m_CollisionGroup", 2);
    SetEntProp(body, Prop_Data, "m_nSolidType", 6);

    SetEntProp(body, Prop_Data, "m_takedamage", 0, 1);

    g_iFakeBody = EntIndexToEntRef(body);

    g_bHasItem[client] = false;

    CPrintToChat(client, "%s{green}已释放假尸体！", TTT_TAG);
}

void RemoveFakeBody()
{
    if(g_iFakeBody != -1)
    {
        int body = EntRefToEntIndex(g_iFakeBody);
        if(IsValidEntity(body))
        {
            AcceptEntityInput(body, "Kill");
        }
        g_iFakeBody = -1;
    }
}