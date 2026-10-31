InitChatMsg()
{
    // 注释掉原本的直接注册，改用 AddCommandListener 监听
    // RegConsoleCmd("say", Say_Message); 
    RegConsoleCmd("say_team", Say_Message_Team);
    
    AddCommandListener(Listener_Say, "say");
}

// 监听 say 命令（模仿你原来的 Say_Message 逻辑）
public Action Listener_Say(int client, const char[] command, int argc)
{
    if (client > 0 && IsClientValid(client))
    {
        // 如果玩家已经死了（包括伪装死）
        if (!IsReallyAlive(client))
        {
            char message[MAX_MESSAGE_LENGTH];
            GetCmdArgString(message, sizeof(message));
            StripQuotes(message);

            // 如果是空消息或者以 / 或 ! 开头，放行
            if (strlen(message) == 0 || message[0] == '/' || message[0] == '!')
                return Plugin_Continue;

            // 直接调用原版处理逻辑（只发给死人）
            PlayerTalk(client, message, false);
            
            // 拦截，不让 AllChat 或引擎去广播
            return Plugin_Handled; 
        }
    }
    
    // 活人说话，放行给 AllChat 接管
    return Plugin_Continue;
}

// Say_Message 原封不动，只是现在由 Listener_Say 来触发
stock Action:Say_Message(int client, int args)
{
    if (args && IsClientValid(client))
    {
        char message[MAX_MESSAGE_LENGTH];
        GetCmdArg(1, message, sizeof(message));
        PlayerTalk(client, message, false);
    }
    return Plugin_Handled;
}

stock Action:Say_Message_Team(int client, int args)
{
    if (args && IsClientValid(client))
    {
        int role = g_Client[client].Role;
        if(role == TTT_ROLE_TRAITOR || role == TTT_ROLE_DETECTIVE)
        {
            char message[MAX_MESSAGE_LENGTH];
            GetCmdArg(1, message, sizeof(message));
            PlayerTalk(client, message, true);
        }
        else
        {
            CPrintToChat(client, "%s只有叛徒或侦探才可使用队内交流", TTT_TAG);
        }
    }
    return Plugin_Handled;
}

stock PlayerTalk(int client, char Message[MAX_MESSAGE_LENGTH], bool:TeamTalk)
{
    CReplaceColorCodes(Message, 0, true, sizeof(Message));

    if(TeamTalk)
    {
        int senderRole = g_Client[client].Role;
        for(int target = 1; target <= MaxClients; target++)
        {
            if(!IsClientValid(target))
                continue;

            if(g_Client[target].Role != senderRole)
                continue;

            if(senderRole == TTT_ROLE_TRAITOR)
            {
                CPrintToChat(target, "{pink}[叛徒队内消息] \x07%X%N{default} : %s", GetRoleColor(g_Client[client].Role), client, Message);
            }
            else if(senderRole == TTT_ROLE_DETECTIVE)
            {
                CPrintToChat(target, "{blue}[侦探队内消息] \x07%X%N{default} : %s", GetRoleColor(g_Client[client].Role), client, Message);
            }
        }
    }
    else
    {
        // 这里就是你原本写的逻辑，完全没变
        if(IsReallyAlive(client))
        {
            for(int target = 1; target <= MaxClients; target++)
            {
                if(!IsClientValid(target))
                    continue;

                CPrintToChat(target, "\x07%X%N{default} : %s", GetRoleColor(g_Client[client].Role), client, Message);
            }
        }
        else
        {
            // 死人说话：游戏进行中只给死人看
            for(int target = 1; target <= MaxClients; target++)
            {
                if(!IsClientValid(target))
                    continue;

                if(IsGameStart && !IsGameEnd && IsReallyAlive(target))
                    continue;

                CPrintToChat(target, "{gray}%N{default} : %s", client, Message);
            }
        }
    }

    decl String:RoleName[16];
    GetRoleName(g_Client[client].Role, RoleName, sizeof(RoleName));
    LogMessage("[%s聊天记录] %N(%s): %s", TeamTalk ? "队内" : "公共", client, RoleName, Message);
}

// ===== 语音屏蔽核心逻辑 =====
stock BlockPlayerVoice(int client)
{
    for(int receiver = 1; receiver <= MaxClients; receiver++)
    {
        if(IsClientValid(receiver))
        {
            if(IsPlayerAlive(receiver))
            {
                // 活人听不到死者的语音
                SetListenOverride(receiver, client, Listen_No);
            }
            else
            {
                // 死人能听到死者的语音
                SetListenOverride(receiver, client, Listen_Yes);
            }
            // 死者能听到所有人的语音
            SetListenOverride(client, receiver, Listen_Yes);
        }
    }
}

stock ResetPlayersVoice()
{
    for(int receiver = 1; receiver <= MaxClients; receiver++)
    {
        for(int sender = 1; sender <= MaxClients; sender++)
        {
            if(IsClientValid(receiver) && IsClientValid(sender))
            {
                g_Client[sender].VoiceChannel = VOICE_CHANNEL_PUBLIC;
                SetListenOverride(receiver, sender, Listen_Yes);
            }
        }
    }
}

stock ChangeVoiceChannel(sender)
{
    if(IsPlayerAlive(sender) && (g_Client[sender].Role == TTT_ROLE_TRAITOR || g_Client[sender].Role == TTT_ROLE_DETECTIVE))
    {
        if(g_Client[sender].VoiceChannel != VOICE_CHANNEL_TRAITOR)
        {
            g_Client[sender].VoiceChannel = VOICE_CHANNEL_TRAITOR;
            for(int receiver = 1; receiver <= MaxClients; receiver++)
            {
                if(IsClientValid(receiver))
                {
                    if(!IsPlayerAlive(receiver)) SetListenOverride(receiver, sender, Listen_Yes);
                    else
                    {
                        if(g_Client[receiver].Role == g_Client[sender].Role) SetListenOverride(receiver, sender, Listen_Yes);
                        else SetListenOverride(receiver, sender, Listen_No);
                    }
                }
            }
        }
        else
        {
            g_Client[sender].VoiceChannel = VOICE_CHANNEL_PUBLIC;
            for(int receiver = 1; receiver <= MaxClients; receiver++)
            {
                SetListenOverride(receiver, sender, Listen_Yes);
            }
        }
    }
}
// ============================