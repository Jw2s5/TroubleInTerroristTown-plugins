#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <morecolors>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin myinfo = {
    name = "[TTT] 击杀日志与投诉记录",
    author = "Jw2s5",
    description = "记录击杀日志，包含环境伤害，并提供死亡投诉菜单",
    version = "1.4",
    url = ""
};

Handle g_hLogFile = INVALID_HANDLE;
char g_sLogDate[32];

enum struct DamageRecord {
    int Attacker;
    int Damage;
}

ArrayList g_aDamageList[MAXPLAYERS + 1];
char g_sLastDeathLine[MAXPLAYERS + 1][512];

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    
    CreateTimer(60.0, Timer_CheckLogDate, _, TIMER_REPEAT);
    UpdateLogFile();
    
    RegConsoleCmd("sm_ttt_log", Command_ViewLog);

    for (int i = 1; i <= MaxClients; i++) {
        g_aDamageList[i] = new ArrayList(sizeof(DamageRecord));
        g_sLastDeathLine[i][0] = '\0';
    }
}

public void OnMapStart()
{
    UpdateLogFile();
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if (g_aDamageList[i] != null) g_aDamageList[i].Clear();
        g_sLastDeathLine[i][0] = '\0';
    }
    return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
    if (g_aDamageList[client] != null) g_aDamageList[client].Clear();
    g_sLastDeathLine[client][0] = '\0';
}

public Action Timer_CheckLogDate(Handle timer)
{
    UpdateLogFile();
    return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int dmgHealth = event.GetInt("dmg_health");

    if (victim <= 0 || victim > MaxClients) return Plugin_Continue;
    if (victim == attacker) return Plugin_Continue;
    if (g_aDamageList[victim] == null) return Plugin_Continue;

    DamageRecord record;
    bool found = false;
    for (int i = 0; i < g_aDamageList[victim].Length; i++)
    {
        g_aDamageList[victim].GetArray(i, record, sizeof(record));
        if (record.Attacker == attacker)
        {
            record.Damage += dmgHealth;
            g_aDamageList[victim].SetArray(i, record, sizeof(record));
            found = true;
            break;
        }
    }

    if (!found)
    {
        record.Attacker = attacker;
        record.Damage = dmgHealth;
        g_aDamageList[victim].PushArray(record, sizeof(record));
    }

    return Plugin_Continue;
}

// ========== 日志与投诉 ==========

void GetLogPath(char[] buffer, int maxLen)
{
    char sDate[32];
    FormatTime(sDate, sizeof(sDate), "%Y-%m-%d");
    BuildPath(Path_SM, buffer, maxLen, "logs/ttt/ttt_%s.txt", sDate);
}

void UpdateLogFile()
{
    if(g_hLogFile != INVALID_HANDLE) { CloseHandle(g_hLogFile); g_hLogFile = INVALID_HANDLE; }
    char sDate[32]; FormatTime(sDate, sizeof(sDate), "%Y-%m-%d");
    char sLogPath[256]; GetLogPath(sLogPath, sizeof(sLogPath));
    if(StrEqual(g_sLogDate, sDate) && FileExists(sLogPath)) {
        g_hLogFile = OpenFile(sLogPath, "a");
        if(g_hLogFile != INVALID_HANDLE) return;
    }
    strcopy(g_sLogDate, sizeof(g_sLogDate), sDate);
    char dirPath[256]; BuildPath(Path_SM, dirPath, sizeof(dirPath), "logs/ttt");
    if(!DirExists(dirPath)) CreateDirectory(dirPath, 511);
    g_hLogFile = OpenFile(sLogPath, "a");
    if(g_hLogFile == INVALID_HANDLE) LogError("[TTT日志] 无法创建日志文件: %s", sLogPath);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    char weapon[32];
    GetEventString(event, "weapon", weapon, sizeof(weapon));

    // 1. 处理击杀日志
    if(TTT_IsClientValid(victim))
    {
        char sTime[32];
        FormatTime(sTime, sizeof(sTime), "%H:%M:%S");
        
        char sVictimName[MAX_NAME_LENGTH], sVictimSteamID[32], sVictimRole[16];
        GetClientName(victim, sVictimName, sizeof(sVictimName));
        GetClientAuthId(victim, AuthId_Steam2, sVictimSteamID, sizeof(sVictimSteamID));
        GetRoleName(TTT_GetClientRole(victim), sVictimRole, sizeof(sVictimRole));

        if(TTT_IsClientValid(attacker) && victim != attacker)
        {
            char sAttackerName[MAX_NAME_LENGTH], sAttackerSteamID[32], sAttackerRole[16];
            GetClientName(attacker, sAttackerName, sizeof(sAttackerName));
            GetClientAuthId(attacker, AuthId_Steam2, sAttackerSteamID, sizeof(sAttackerSteamID));
            GetRoleName(TTT_GetClientRole(attacker), sAttackerRole, sizeof(sAttackerRole));
            
            Format(g_sLastDeathLine[victim], 512, "[%s] %s(%s)[%s] 被 %s(%s)[%s] 的 %s 击杀",
                sTime, sAttackerName, sAttackerSteamID, sAttackerRole,
                sVictimName, sVictimSteamID, sVictimRole, weapon);
        }
        else
        {
            // 环境死亡或自杀
            char sWeaponName[64];
            if (StrEqual(weapon, "world") || StrEqual(weapon, "worldspawn")) {
                Format(sWeaponName, sizeof(sWeaponName), "环境伤害");
            } else if (StrEqual(weapon, "fall") || StrEqual(weapon, "falldamage")) {
                Format(sWeaponName, sizeof(sWeaponName), "摔伤");
            } else {
                Format(sWeaponName, sizeof(sWeaponName), "%s", weapon);
            }

            Format(g_sLastDeathLine[victim], 512, "[%s] %s(%s)[%s] 因 %s 死亡",
                sTime, sVictimName, sVictimSteamID, sVictimRole, sWeaponName);
        }

        if(g_hLogFile != INVALID_HANDLE)
        {
            WriteFileLine(g_hLogFile, "%s\n", g_sLastDeathLine[victim]);
            FlushFile(g_hLogFile);
        }
    }

    // 2. 弹出投诉菜单
    if (TTT_IsClientValid(victim) && !IsFakeClient(victim) && g_aDamageList[victim] != null && g_aDamageList[victim].Length > 0)
    {
        DataPack dp = new DataPack();
        dp.WriteCell(victim);
        RequestFrame(Frame_ShowComplaintMenu, dp);
    }
    
    return Plugin_Continue;
}

// 显示投诉菜单
public void Frame_ShowComplaintMenu(DataPack dp)
{
    dp.Reset();
    int victim = dp.ReadCell();
    delete dp;

    if (!TTT_IsClientValid(victim)) return;
    if (g_aDamageList[victim] == null || g_aDamageList[victim].Length == 0) return;

    Menu menu = new Menu(MenuHandler_Complaint);
    menu.SetTitle("对你造成伤害的玩家：");

    DamageRecord record;
    char info[16], display[128], roleName[16], attackerName[MAX_NAME_LENGTH];

    for (int i = 0; i < g_aDamageList[victim].Length; i++)
    {
        g_aDamageList[victim].GetArray(i, record, sizeof(record));
        
        if (record.Attacker == 0) {
            // 世界伤害
            Format(roleName, sizeof(roleName), "世界");
            Format(attackerName, sizeof(attackerName), "环境伤害");
        } else if (TTT_IsClientValid(record.Attacker)) {
            // 玩家伤害
            GetClientName(record.Attacker, attackerName, sizeof(attackerName));
            GetRoleName(TTT_GetClientRole(record.Attacker), roleName, sizeof(roleName));
        } else {
            continue; // 其他无效实体跳过
        }

        Format(display, sizeof(display), "[%s] %s : %d", roleName, attackerName, record.Damage);
        IntToString(i, info, sizeof(info)); 
        menu.AddItem(info, display, ITEMDRAW_DISABLED);
    }

    menu.AddItem("close", "关闭");
    menu.AddItem("complain", "投诉该玩家");

    menu.ExitButton = false;
    menu.Display(victim, 20);
}

public int MenuHandler_Complaint(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        if (StrEqual(info, "complain")) SaveComplaint(param1);
    }
    else if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
    return 0;
}

// 保存投诉到文件
void SaveComplaint(int victim)
{
    if (!TTT_IsClientValid(victim)) return;

    char dirPath[256];
    BuildPath(Path_SM, dirPath, sizeof(dirPath), "logs/ttt");
    if(!DirExists(dirPath)) CreateDirectory(dirPath, 511);

    char sPath[256];
    BuildPath(Path_SM, sPath, sizeof(sPath), "logs/ttt/ttt_vo.txt");

    Handle hFile = OpenFile(sPath, "a");
    if (hFile == INVALID_HANDLE)
    {
        PrintToChat(victim, "%s投诉保存失败，请联系管理员。", TTT_TAG);
        return;
    }

    // 只写入那一行击杀记录，不加多余的详细列表
    if (strlen(g_sLastDeathLine[victim]) > 0)
    {
        WriteFileLine(hFile, "%s\n", g_sLastDeathLine[victim]);
    }
    
    CloseHandle(hFile);
    PrintToChat(victim, "%s投诉已成功保存", TTT_TAG);
}

// ========== 辅助函数 ==========

stock void GetRoleName(int role, char[] buffer, int maxLen)
{
    if(role == TTT_ROLE_INNOCENT) Format(buffer, maxLen, "平民");
    else if(role == TTT_ROLE_DETECTIVE) Format(buffer, maxLen, "侦探");
    else if(role == TTT_ROLE_TRAITOR) Format(buffer, maxLen, "叛徒");
    else Format(buffer, maxLen, "未知");
}

public Action Command_ViewLog(int client, int args)
{
    if(client == 0) return Plugin_Handled;
    
    char sPath[256];
    GetLogPath(sPath, sizeof(sPath));
    
    if(!FileExists(sPath))
    {
        CPrintToChat(client, "%s日志文件不存在", TTT_TAG);
        return Plugin_Handled;
    }
    
    CPrintToChat(client, "%s日志文件位置: %s", TTT_TAG, sPath);
    
    Handle hFile = OpenFile(sPath, "r");
    if(hFile == INVALID_HANDLE) return Plugin_Handled;
    
    char sLines[10][256];
    int iCount = 0;
    char sBuffer[256];
    
    while(ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
    {
        TrimString(sBuffer);
        if(strlen(sBuffer) > 0)
        {
            strcopy(sLines[iCount % 10], sizeof(sLines[]), sBuffer);
            iCount++;
        }
    }
    CloseHandle(hFile);
    
    if(iCount == 0)
    {
        CPrintToChat(client, "%s日志为空", TTT_TAG);
        return Plugin_Handled;
    }
    
    CPrintToChat(client, "%s=== 最近击杀记录 ===", TTT_TAG);
    int start = (iCount < 10) ? 0 : iCount - 10;
    for(int i = start; i < iCount; i++)
    {
        CPrintToChat(client, "%s", sLines[i % 10]);
    }
    
    return Plugin_Handled;
}