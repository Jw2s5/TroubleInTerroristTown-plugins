#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <morecolors>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin myinfo = {
    name = "[TTT] 规则同意系统",
    author = "Your Name",
    description = "进服自动弹出规则菜单，只弹一次",
    version = "1.0",
    url = ""
};

bool g_bHasAgreed[MAXPLAYERS + 1];
bool g_bMenuShown[MAXPLAYERS + 1];

char g_sAgreeText[] = "我已了解游戏规则，将遵守规则进行游戏";
char g_sDisagreeTexts[6][] = {
    "我不了解游戏规则",
    "我没有看规则",
    "规则太长了我不想看",
    "我不在乎规则",
    "规则是什么？",
    "我不想遵守规则"
};

int g_iOptionOrder[MAXPLAYERS + 1][7];

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
    
    RegConsoleCmd("sm_rules", Command_ShowRules);
    RegConsoleCmd("sm_rule", Command_ShowRules);
}

public void OnClientPutInServer(int client)
{
    g_bHasAgreed[client] = false;
    g_bMenuShown[client] = false;
    GenerateRandomOrder(client);
    
    // 延迟弹出菜单
    CreateTimer(0.5, Timer_ShowAgreement, client);
}

public void OnClientDisconnect(int client)
{
    g_bHasAgreed[client] = false;
    g_bMenuShown[client] = false;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (!TTT_IsClientValid(client))
        return Plugin_Continue;
    
    // 未同意规则 → 阻止复活
    if (!g_bHasAgreed[client])
    {
        CS_SwitchTeam(client, CS_TEAM_SPECTATOR);
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action Timer_ShowAgreement(Handle timer, int client)
{
    if (!TTT_IsClientValid(client))
        return Plugin_Stop;
    
    if (g_bHasAgreed[client])
        return Plugin_Stop;
    
    // 如果已经弹过菜单，不再弹出
    if (g_bMenuShown[client])
        return Plugin_Stop;
    
    ShowAgreementMenu(client);
    
    return Plugin_Stop;
}

void ShowAgreementMenu(int client)
{
    if (!TTT_IsClientValid(client))
        return;
    
    g_bMenuShown[client] = true;
    
    Menu menu = new Menu(MenuHandler_Agreement);
    menu.SetTitle("=== 服务器规则 ===\n\n请仔细阅读以下规则：\n1. 禁止任何形式的乱杀、猜测杀、仇杀\n2. 违者封禁处理\n\n");
    
    for (int i = 0; i < 7; i++)
    {
        int idx = g_iOptionOrder[client][i];
        char itemInfo[8];
        IntToString(idx, itemInfo, sizeof(itemInfo));
        
        if (idx == 6)
            menu.AddItem(itemInfo, g_sAgreeText);
        else
            menu.AddItem(itemInfo, g_sDisagreeTexts[idx]);
    }
    
    menu.ExitButton = false;
    menu.Display(client, 0);
}

public int MenuHandler_Agreement(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int client = param1;
        char info[8];
        GetMenuItem(menu, param2, info, sizeof(info));
        
        int idx = StringToInt(info);
        
        if (idx == 6)
        {
            g_bHasAgreed[client] = true;
            CPrintToChat(client, "{green}[TTT] {default}你已同意游戏规则！");
        }
        else
        {
            KickClient(client, "你未了解游戏规则，已被踢出服务器。");
            LogAction(client, -1, "\"%L\" 被踢出: 未同意游戏规则 (选择: %s)", client, g_sDisagreeTexts[idx]);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

public Action Command_ShowRules(int client, int args)
{
    if (!TTT_IsClientValid(client))
        return Plugin_Handled;
    
    if (g_bHasAgreed[client])
        return Plugin_Handled;
    
    // 命令可以重新打开菜单，但只弹一次
    if (g_bMenuShown[client])
        return Plugin_Handled;
    
    ShowAgreementMenu(client);
    return Plugin_Handled;
}

void GenerateRandomOrder(int client)
{
    int order[7];
    for (int i = 0; i < 7; i++)
        order[i] = i;
    
    for (int i = 6; i > 0; i--)
    {
        int j = GetRandomInt(0, i);
        int temp = order[i];
        order[i] = order[j];
        order[j] = temp;
    }
    
    for (int i = 0; i < 7; i++)
        g_iOptionOrder[client][i] = order[i];
}