stock OpenRadioMenu(int client)
{
    if(!TTT_IsClientValid(client) || !IsPlayerAlive(client)) return;
    
    Menu menu = new Menu(RadioMenu_Callback);
    menu.SetTitle("------ 快捷消息 ------");
    
    int target = GetTargetInRange(client, 150.0);
    
    char PlayerName[MAX_NAME_LENGTH];
    char MenuName[64];
    
    if(TTT_IsClientValid(target) && IsPlayerAlive(target))
    {
        GetClientName(target, PlayerName, sizeof(PlayerName));
    }
    else
    {
        Format(PlayerName, sizeof(PlayerName), "某某");
    }
    
    // 1. 是的
    menu.AddItem("yes", "是的");
    
    // 2. 不
    menu.AddItem("no", "不");
    
    // 3. 救命
    menu.AddItem("help", "救命");
    
    // 4. 我正在跟着某某
    Format(MenuName, sizeof(MenuName), "我正在跟着 %s", PlayerName);
    menu.AddItem("follow", MenuName);
    
    // 5. 某某行为可疑
    Format(MenuName, sizeof(MenuName), "%s 行为可疑", PlayerName);
    menu.AddItem("questionable", MenuName);
    
    // 6. 某某是叛徒
    Format(MenuName, sizeof(MenuName), "%s 是叛徒！", PlayerName);
    menu.AddItem("istraitor", MenuName);
    
    // 7. 还有人活着吗
    menu.AddItem("anyalive", "还有人活着吗");
    
    menu.Pagination = false;
    menu.ExitButton = true;
    menu.Display(client, 15);
}

stock RadioMenu_Callback(Menu menu, MenuAction action, int param1, int param2)
{
    if(action == MenuAction_Select)
    {
        char name[64], info[64];
        bool found = GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
        if(!found) return;
        if(IsPlayerAlive(param1))
        {
            if((StrEqual(info, "pass") || StrEqual(info, "stop")) && g_Client[param1].Role != TTT_ROLE_DETECTIVE) return;
            CPrintToChatAll("{salmon}(快捷消息)\x07%X%N{yellow} : %s", GetRoleColor(g_Client[param1].Role), param1, name);
        }
        CloseHandle(menu);
    }
}