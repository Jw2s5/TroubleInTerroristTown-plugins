#include <sourcemod>
#include <sdktools>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] NoBlock 控制",
    author = "Jw2s5",
    description = "倒计时 noblock 1，游戏开始 noblock 0，!block2 临时开 5 秒",
    version = "1.0",
    url = ""
}

#define TEMP_NOBLOCK_TIME 5.0
#define MAX_BLOCK2_USES   2

ConVar g_cvNoBlock = null;
ConVar g_cvRequire = null;

bool g_bNoBlockOn = false;
int g_iBlock2Uses[MAXPLAYERS + 1];
Handle g_hTempNoBlockTimer = INVALID_HANDLE;

public OnPluginStart()
{
    g_cvNoBlock = FindConVar("sm_noblock");
    g_cvRequire = FindConVar("ttt_gamestart_require");

    // 每 0.5 秒检测人数/身份，切换 noblock
    CreateTimer(0.5, Timer_CheckPlayers, _, TIMER_REPEAT);

    RegConsoleCmd("sm_block2", Command_Block2, "临时开启 noblock 5 秒");
    RegConsoleCmd("sm_noblock2", Command_Block2, "临时开启 noblock 5 秒");

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

// ===== 回合开始：重置每局使用次数 =====
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        g_iBlock2Uses[i] = 0;
    }
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if(g_hTempNoBlockTimer != INVALID_HANDLE && IsValidHandle(g_hTempNoBlockTimer))
    {
        KillTimer(g_hTempNoBlockTimer);
        g_hTempNoBlockTimer = INVALID_HANDLE;
    }
    return Plugin_Continue;
}

// ===== 每 0.5 秒检测人数/身份，切换 noblock =====
public Action Timer_CheckPlayers(Handle timer)
{
    if(g_cvNoBlock == null)
        return Plugin_Continue;

    // 临时 noblock 生效中，不覆盖
    if(g_hTempNoBlockTimer != INVALID_HANDLE && IsValidHandle(g_hTempNoBlockTimer))
        return Plugin_Continue;

    int realPlayers = 0;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientValid(i) && !IsClientSourceTV(i))
            realPlayers++;
    }

    int require = g_cvRequire != null ? g_cvRequire.IntValue : 3;

    bool bShouldNoBlock;

    if(realPlayers < require)
    {
        bShouldNoBlock = true;
    }
    else
    {
        int assignedRoles = 0;
        for(int i = 1; i <= MaxClients; i++)
        {
            if(!IsClientValid(i) || IsClientSourceTV(i))
                continue;

            int role = TTT_GetClientRole(i);
            if(role != TTT_ROLE_NONE)
                assignedRoles++;
        }

        bShouldNoBlock = (assignedRoles == 0);
    }

    if(bShouldNoBlock && !g_bNoBlockOn)
    {
        g_cvNoBlock.SetInt(1);
        g_bNoBlockOn = true;
        PrintToServer("[TTT] Countdown: noblock = 1");
    }
    else if(!bShouldNoBlock && g_bNoBlockOn)
    {
        g_cvNoBlock.SetInt(0);
        g_bNoBlockOn = false;
        PrintToServer("[TTT] Game started: noblock = 0");
    }

    return Plugin_Continue;
}

// ===== !block2 临时开 noblock 5 秒 =====
public Action Command_Block2(int client, int args)
{
    if(!IsClientValid(client))
        return Plugin_Handled;

    if(g_cvNoBlock == null)
        return Plugin_Handled;

    // 准备期不需要用
    if(g_bNoBlockOn)
    {
        CPrintToChat(client, "%s{red}准备期间已开启 noblock，无需使用！", TTT_TAG);
        return Plugin_Handled;
    }

    // 检查使用次数
    if(g_iBlock2Uses[client] >= MAX_BLOCK2_USES)
    {
        CPrintToChat(client, "%s{red}本回合您已使用过 %d 次，无法再使用！", TTT_TAG, MAX_BLOCK2_USES);
        return Plugin_Handled;
    }

    // 已经有临时 noblock 在跑
    if(g_hTempNoBlockTimer != INVALID_HANDLE && IsValidHandle(g_hTempNoBlockTimer))
    {
        CPrintToChat(client, "%s{red}临时 noblock 已经在生效中！", TTT_TAG);
        return Plugin_Handled;
    }

    // 开 noblock
    g_cvNoBlock.SetInt(1);
    g_iBlock2Uses[client]++;

    CPrintToChatAll("%s{green}%N{default} 触发临时 noblock，持续 {yellow}%.0f{default} 秒（剩余 %d 次）",
        TTT_TAG, client, TEMP_NOBLOCK_TIME, MAX_BLOCK2_USES - g_iBlock2Uses[client]);

    g_hTempNoBlockTimer = CreateTimer(TEMP_NOBLOCK_TIME, Timer_DisableTempNoBlock, _, TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Handled;
}

public Action Timer_DisableTempNoBlock(Handle timer)
{
    g_hTempNoBlockTimer = INVALID_HANDLE;

    // 只有游戏进行中才关
    if(!g_bNoBlockOn && g_cvNoBlock != null)
    {
        g_cvNoBlock.SetInt(0);
        PrintToServer("[TTT] Temp noblock ended: noblock = 0");
    }

    return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
    g_iBlock2Uses[client] = 0;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}