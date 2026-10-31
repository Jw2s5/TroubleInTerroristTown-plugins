AddKillingKarma(int victim, int attacker)
{
    if(victim == attacker) return;
    if(IsGameStart && !IsGameEnd)
    {
        switch(g_Client[attacker].Role)
        {
            case TTT_ROLE_INNOCENT : {
                switch(g_Client[victim].Role) {
                    case TTT_ROLE_INNOCENT : {
                        g_Client[attacker].Karma -= ttt_karma_innocent_kill_innocent.IntValue;
                    }
                    case TTT_ROLE_TRAITOR : {
                        g_Client[attacker].Karma += ttt_karma_innocent_kill_traitor.IntValue;
                    }
                    case TTT_ROLE_DETECTIVE : {
                        g_Client[attacker].Karma -= ttt_karma_innocent_kill_detective.IntValue;
                    }
                }
            }
            case TTT_ROLE_TRAITOR : {
                switch(g_Client[victim].Role) {
                    case TTT_ROLE_INNOCENT : {
                        g_Client[attacker].Karma += ttt_karma_traitor_kill_innocent.IntValue;
                    }
                    case TTT_ROLE_TRAITOR : {
                        g_Client[attacker].Karma -= ttt_karma_traitor_kill_traitor.IntValue;
                    }
                    case TTT_ROLE_DETECTIVE : {
                        g_Client[attacker].Karma += ttt_karma_traitor_kill_detective.IntValue;
                    }
                }
            }
            case TTT_ROLE_DETECTIVE : {
                switch(g_Client[victim].Role) {
                    case TTT_ROLE_INNOCENT : {
                        g_Client[attacker].Karma -= ttt_karma_detective_kill_innocent.IntValue;
                    }
                    case TTT_ROLE_TRAITOR : {
                        g_Client[attacker].Karma += ttt_karma_detective_kill_traitor.IntValue;
                    }
                    case TTT_ROLE_DETECTIVE : {
                        g_Client[attacker].Karma -= ttt_karma_detective_kill_detective.IntValue;
                    }
                }
            }
        }
        CheckPlayerKarma(attacker);
    }
}

CheckPlayerKarma(int client)
{
    if(IsClientValid(client))
    {
        if(g_Client[client].Karma > ttt_karma_max.IntValue)
        {
            g_Client[client].Karma = ttt_karma_max.IntValue;
        }
        if(g_Client[client].Karma <= 0)
        {
            ServerCommand("sm_kick %N \"您因为Karma值过低而被踢出!\"", client);
        }
        // 只在游戏未开始（倒计时/准备阶段）显示Karma
if(IsGameStart)
{
    CPrintToChat(client, "%s当前Karma值: {yellow}%d", TTT_TAG, g_Client[client].Karma);
}
    }
}

RestoreKarma(int client)
{
    if(g_Client[client].Karma < ttt_karma_min.IntValue)
    {
        g_Client[client].Karma = ttt_karma_min.IntValue;
        // 恢复时显示当前Karma值
        if(!IsGameStart)
        {
            CPrintToChat(client, "%s当前Karma值: {yellow}%d", TTT_TAG, g_Client[client].Karma);
        }
    }
}