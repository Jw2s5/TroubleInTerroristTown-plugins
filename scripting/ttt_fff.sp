#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <morecolors>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin myinfo = {
    name = "[TTT] 三连F确认叛徒",
    author = "Jw2s5",
    description = "按3下F键确认叛徒，准星范围检测，距离750",
    version = "1.0",
    url = ""
};

int g_iFPressCount[MAXPLAYERS + 1];
float g_fFirstPressTime[MAXPLAYERS + 1];

#define PRESS_WINDOW 0.5
#define CONFIRM_DISTANCE 1450.0
#define AIM_DOT 0.6

public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        ResetPlayerData(i);
    }
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    return Plugin_Continue;
}

public void OnMapStart()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        ResetPlayerData(i);
    }
}

public void OnClientPutInServer(int client)
{
    ResetPlayerData(client);
}

public void OnClientDisconnect(int client)
{
    ResetPlayerData(client);
}

void ResetPlayerData(int client)
{
    g_iFPressCount[client] = 0;
    g_fFirstPressTime[client] = 0.0;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if(!TTT_IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Continue;
    
    if(TTT_GetClientRole(client) == TTT_ROLE_TRAITOR)
        return Plugin_Continue;
    
    int totalRole = TTT_GetRoleNums(TTT_ROLE_INNOCENT) + TTT_GetRoleNums(TTT_ROLE_DETECTIVE) + TTT_GetRoleNums(TTT_ROLE_TRAITOR);
    if(totalRole == 0)
        return Plugin_Continue;
    
    if(impulse == 100)
    {
        float currentTime = GetGameTime();
        
        if(g_iFPressCount[client] == 0)
        {
            g_fFirstPressTime[client] = currentTime;
            g_iFPressCount[client] = 1;
            return Plugin_Continue;
        }
        
        if(currentTime - g_fFirstPressTime[client] > PRESS_WINDOW)
        {
            g_iFPressCount[client] = 0;
            g_fFirstPressTime[client] = 0.0;
            return Plugin_Continue;
        }
        
        g_iFPressCount[client]++;
        
        if(g_iFPressCount[client] >= 3)
        {
            ConfirmTraitor(client);
            ResetPlayerData(client);
            impulse = 0;
            return Plugin_Changed;
        }
    }
    
    return Plugin_Continue;
}

void ConfirmTraitor(int client)
{
    int target = GetTargetInCrosshair(client);
    
    if(target == -1 || !TTT_IsClientValid(target) || !IsPlayerAlive(target))
        return;
    
    if(target == client)
        return;
    
    if(TTT_GetClientRole(client) == TTT_ROLE_INNOCENT && TTT_GetClientRole(target) == TTT_ROLE_DETECTIVE)
        return;
    
    char targetName[MAX_NAME_LENGTH];
    GetClientName(target, targetName, sizeof(targetName));
    
    CPrintToChatAll("{purple}%N {green}确认 {red}%s {green}是 {red}叛徒！！！", client, targetName);
}

int GetTargetInCrosshair(int client)
{
    float eyePos[3], eyeAngles[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAngles);

    float direction[3];
    GetAngleVectors(eyeAngles, direction, NULL_VECTOR, NULL_VECTOR);

    int bestTarget = -1;
    float bestDot = AIM_DOT;

    for(int i = 1; i <= MaxClients; i++)
    {
        if(!TTT_IsClientValid(i) || i == client || !IsPlayerAlive(i))
            continue;

        float targetPos[3];
        GetClientAbsOrigin(i, targetPos);
        targetPos[2] += 40.0;   // 胸部

        float toTarget[3];
        SubtractVectors(targetPos, eyePos, toTarget);
        float distance = GetVectorLength(toTarget);

        if(distance > CONFIRM_DISTANCE)
            continue;

        NormalizeVector(toTarget, toTarget);
        float dot = GetVectorDotProduct(direction, toTarget);

        if(dot < AIM_DOT)
            continue;

        // ===== 射线检查：从眼睛到目标，中间有没有墙 =====
        Handle trace = TR_TraceRayFilterEx(eyePos, targetPos, MASK_SHOT, RayType_EndPoint, TraceFilter_Confirm, client);
        int hitEnt = TR_GetEntityIndex(trace);
        delete trace;

        // 命中墙（0）说明被挡住，跳过
        if(hitEnt == 0)
            continue;

        // 命中其他玩家（挡路的），跳过
        if(hitEnt > 0 && hitEnt <= MaxClients && hitEnt != i)
            continue;
        // =================================================

        if(dot > bestDot)
        {
            bestDot = dot;
            bestTarget = i;
        }
    }

    return bestTarget;
}

public bool TraceFilter_Confirm(int entity, int contentsMask, any data)
{
    if(entity == data) return false;   // 忽略自己
    return true;
}