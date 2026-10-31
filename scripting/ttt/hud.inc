stock InitSyncHUDChannels()
{
    SyncHUDChannel_CrossHair = CreateHudSynchronizer();
    SyncHUDChannel_Infomation1 = CreateHudSynchronizer();
    SyncHUDChannel_Infomation2 = CreateHudSynchronizer();
    SyncHUDChannel_GameStatus = CreateHudSynchronizer();
}

stock HudOnMapStart()
{
    for(new client = 1;client <= MaxClients;client++)
    {
        TTT_EndTimer(tShowHUD[client]);
        if(IsClientValid(client))
        {
            tShowHUD[client] = CreateTimer(0.35, InitHud, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

stock HudClientInit(client)
{
    if(IsClientValid(client))
    {
        TTT_EndTimer(tShowHUD[client]);
        tShowHUD[client] = CreateTimer(0.35, InitHud, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

stock HudOnClientDisconnect(client)
{
    TTT_EndTimer(tShowHUD[client]);
    tShowHUD[client] = INVALID_HANDLE;
}

stock Action:InitHud(Handle Timer, int client)
{
    ShowPlayerInfo(client);
    ShowRoundInfo(client);
    ShowVoiceChannelInfo(client);
    ShowTraitorTeammateInfo(client);
    ShowRoundStartHUD(client);
}
stock ShowPlayerInfo(int client)
{
    int Specmode = GetEntProp(client, Prop_Send, "m_iObserverMode");
    
    if(!IsPlayerAlive(client) && IsClientObserver(client))
    {
        SetHudTextParams(-1.0, 0.2, 0.35, 255, 102, 55, 255, 0, 0.0, 0.02);
        ShowSyncHudText(client, SyncHUDChannel_Infomation1, "您死亡了！\n如果您的视角倾斜，请切换视角模式。");
    }
    
    if(!IsPlayerAlive(client) && IsClientObserver(client) && (Specmode == 4 || Specmode == 5 || Specmode == 6))
    {
        int Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        if(IsClientValid(Target) && IsPlayerAlive(Target) && Target != client)
        {
            ShowPlayerStatusHUD(client, Target);
        }
    }
    else
    {
        int iEntity = TTT_GetClientAimTarget(client, false);
        if(IsValidEntity(iEntity))
        {
            if(CanClientUseEntity(client, iEntity))
            {
                char classname[32];
                GetEntityClassname(iEntity, classname, sizeof(classname));
                if(StrEqual(classname, "ttt_fakebody"))
                {
                    if(g_Client[client].Role == TTT_ROLE_TRAITOR)
                    {
                        SetHudTextParams(-1.0, 0.44, 0.35, 255, 100, 100, 255, 2, 0.0, 0.02, 0.2);
                        ShowSyncHudText(client, SyncHUDChannel_CrossHair, "\n\n\n这是叛徒放的假尸体\n不要按E检查！");
                    }
                    else
                    {
                        SetHudTextParams(-1.0, 0.44, 0.35, 255, 255, 255, 255, 2, 0.0, 0.005, 0.2);
                        ShowSyncHudText(client, SyncHUDChannel_CrossHair, "\n\n\n这具尸体未被检查\n [E] 检查尸体");
                    }
                    return;
                }
            }
            if(CanClientUseEntity(client, iEntity) && IsEntityBody(iEntity))
            {
                if(g_aRagdoll.Length == 0) return;
                Ragdoll body;
                if(!GetRagdollArrayByEntIndex(iEntity, body))
                {
                    PrintToChat(client, "无法获取布娃娃数组");
                    return;
                }
                if(!body.Found)
                {
                    SetHudTextParams(-1.0, 0.44, 0.35, 255, 255, 255, 255, 2, 0.0, 0.005, 0.2);
                    ShowSyncHudText(client, SyncHUDChannel_CrossHair, "\n\n\n这具尸体未被检查\n [E] 公开检查\n [F] 悄悄检查");
                }
                else
                {
                    int r, g, b = 50;
                    r = (body.VictimRole == TTT_ROLE_TRAITOR) ? 255 : 50;
                    g = (body.VictimRole == TTT_ROLE_INNOCENT || body.VictimRole == TTT_ROLE_NONE) ? 255 : 50;
                    b = (body.VictimRole == TTT_ROLE_DETECTIVE) ? 255 : 50;
                    SetHudTextParams(-1.0, 0.44, 0.35, r, g, b, 255, 2, 0.0, 0.02, 0.2);
                    ShowSyncHudText(client, SyncHUDChannel_CrossHair, "\n\n\n%s的尸体\n [E] 检查尸体", body.VictimName);
                }
            }
            
            if(IsClientValid(iEntity) && IsPlayersInDistance(client, iEntity))
            {
                ShowPlayerStatusHUD(client, iEntity);
            }
            
            if(CanClientUseEntity(client, iEntity))
            {
                Call_StartForward(g_fwOnEntityInfoHUDDisplay);
                Call_PushCell(client);
                Call_PushCell(iEntity);
                Call_Finish();
            }
        }
    }
}

stock ShowRoundInfo(int client)
{
    char text[128];
    if(IsClientValid(client))
    {
        char Text_Time[3][16];
        FormatTime(Text_Time[0], sizeof(Text_Time[]), "%M:%S", GameStartTime);
        FormatTime(Text_Time[1], sizeof(Text_Time[]), "%M:%S", RoundTime);
        FormatTime(Text_Time[2], sizeof(Text_Time[]), "%M:%S", TraitorTime);
        
        if(IsPlayerAlive(client)) Format(text, sizeof(text), "您的角色 : %s\n", g_Client[client].Role == TTT_ROLE_NONE ? "未选择" : g_Client[client].Role == TTT_ROLE_INNOCENT ? "平民" : g_Client[client].Role == TTT_ROLE_DETECTIVE ? "侦探" : "叛徒");
        if(g_Client[client].Role != TTT_ROLE_TRAITOR)
        {
            if(!IsRequiredToPlay) Format(text, sizeof(text), "%s%s : %s\n", text, (!IsGameStart && !IsGameEnd) ? "开始时间" : "福利时间", IsRoundTimeExtend ? "超时" : (!IsGameStart && !IsGameEnd) ? Text_Time[0] : Text_Time[1]);
            else Format(text, sizeof(text), "%s%s : 玩家数不足%d人\n", text, "开始时间", ttt_gamestart_require.IntValue);
        }
        if(g_Client[client].Role == TTT_ROLE_TRAITOR || !IsPlayerAlive(client))
        {
            Format(text, sizeof(text), "%s%s : %s\n", text, "叛徒的时间", IsTraitorTimeExtend ? "超时" : Text_Time[2]);
        }

        if(!IsPlayerAlive(client))
        {
            Format(text, sizeof(text), "%s剩余叛徒 : %d  剩余侦探 : %d  剩余平民 : %d\n", text, TraitorNums, DetectiveNums, InnocentNums);
        }
        else
        {
            if(IsGameStart) Format(text, sizeof(text), "%s积分 : %d\n按N打开积分菜单\n", text, g_Client[client].Credits);
            if(g_Client[client].Role == TTT_ROLE_DETECTIVE && g_Client[client].DNAProcess > 0 && TTT_IsTimerRunning(g_Client[client].DNACheckCountdownTimer))
            {
                char Process[8];
                int CheckTime = ttt_dna_check_time.IntValue;
                int ProcessPercent = RoundToFloor(((CheckTime - g_Client[client].DNAProcess) / float(CheckTime)) * 10.0) / 2;
                for(int i;i < 5;i++)
                {
                    if(ProcessPercent > 0)
                    {
                        StrCat(Process, sizeof(Process), "*");
                        ProcessPercent --;
                    }
                    else StrCat(Process, sizeof(Process), "_");
                }
                Format(text, sizeof(text), "%sDNA检测进度: [%s]\n", text, Process);
            }
            if(g_Client[client].Role == TTT_ROLE_TRAITOR && g_Client[client].Leak)
            {
                Format(text, sizeof(text), "%s您的身份已暴露\n", text);
            }
        }

        int r, g, b = 50;
        if(IsPlayerAlive(client) && g_Client[client].Role != TTT_ROLE_NONE)
        {
            r = (g_Client[client].Role == TTT_ROLE_TRAITOR) ? 255 : 50;
            g = (g_Client[client].Role == TTT_ROLE_INNOCENT || g_Client[client].Role == TTT_ROLE_NONE) ? 255 : 50;
            b = (g_Client[client].Role == TTT_ROLE_DETECTIVE) ? 255 : 50;
        }
        else
        {
            r = 255, g = 255, b = 255;
        }
        SetHudTextParams(-1.0, 0.0, 0.35, r, g, b, 255, 2, 0.0, 0.02, 0.2);
        ShowSyncHudText(client, SyncHUDChannel_GameStatus, "%s", text);
    }
}

stock ShowPlayerStatusHUD(client, ent)
{
    int hp = GetClientHealth(ent);
    int r, g, b;
    if(g_Client[ent].Role == TTT_ROLE_DETECTIVE)
    {
        Format(Buffer, sizeof(Buffer), "/\\\n| |\n\\/\n%N\n身份: 侦探", ent);
        r = 0;
        g = 0;
        b = 255;
    }
    else if((g_Client[ent].Role == TTT_ROLE_TRAITOR && g_Client[client].Role == TTT_ROLE_TRAITOR) || 
    (g_Client[ent].Role == TTT_ROLE_TRAITOR && !IsPlayerAlive(client)) || (g_Client[ent].Role == TTT_ROLE_TRAITOR && IsGameEnd) || (g_Client[ent].Role == TTT_ROLE_TRAITOR && g_Client[ent].Leak))
    {
        Format(Buffer, sizeof(Buffer), "/\\\n| |\n\\/\n%N\n身份: 叛徒", ent);
        r = 255;
        g = 0;
        b = 0;
    }
    else
    {
        Format(Buffer, sizeof(Buffer), "\n\n\n%N", ent);
        r = 255;
        g = 255;
        b = 255;
    }
    if(hp >= 100)
    {
        Format(Buffer, sizeof(Buffer), "%s\n健康", Buffer);
    }
    else if(hp >= 90)
    {
        Format(Buffer, sizeof(Buffer), "%s\n轻伤", Buffer);
    }
    else if(hp >= 50)
    {
        Format(Buffer, sizeof(Buffer), "%s\n受伤", Buffer);
    }
    else if(hp >= 15)
    {
        Format(Buffer, sizeof(Buffer), "%s\n重伤", Buffer);
    }
    else
    {
        Format(Buffer, sizeof(Buffer), "%s\n濒死", Buffer);
    }
    SetHudTextParams(-1.0, 0.44, 0.35, r, g, b, 255, 0, 0.0, 0.02, 0.2);
    ShowSyncHudText(client, SyncHUDChannel_CrossHair, "%s", Buffer);
}

stock ShowVoiceChannelInfo(int client)
{
    if(IsClientValid(client) && IsPlayerAlive(client) && g_Client[client].Role == TTT_ROLE_TRAITOR)
    {
        SetHudTextParams(0.1, 0.15, 0.35, 255, 152, 5, 255);
        ShowSyncHudText(client, SyncHUDChannel_Infomation1, "当前语音频道: %s\n按下TAB + E更改频道", g_Client[client].VoiceChannel == VOICE_CHANNEL_TRAITOR ? "叛徒频道" : "公共频道");
    }
}

stock ShowTraitorTeammateInfo(int client)
{
    if(!IsClientValid(client)) return;
    
    bool bShow = false;
    
    if(g_Client[client].Role == TTT_ROLE_TRAITOR)
        bShow = true;
        
    if(IsPlayerDeadState(client))
        bShow = true;
        
    if(!bShow) return;

    char TeammateText[512];
    
    if(g_bShowDeadList[client])
    {
        Format(TeammateText, sizeof(TeammateText), "[按 E 切换名单]\n== [未发现尸体名单] ==\n");
        int count = 0;
        
        for(int i = 0; i < g_aRagdoll.Length; i++)
        {
            Ragdoll body;
            g_aRagdoll.GetArray(i, body, sizeof(body));
            
            if(IsValidEntity(EntRefToEntIndex(body.EntityRef)) && !body.Found)
            {
                Format(TeammateText, sizeof(TeammateText), "%s%s\n", TeammateText, body.VictimName);
                count++;
            }
        }
        
        if(count == 0)
        {
            StrCat(TeammateText, sizeof(TeammateText), "暂无未发现的尸体\n");
        }
    }
    else
    {
        Format(TeammateText, sizeof(TeammateText), "== [叛徒名单] ==\n");
        int count = 0;
        LoopValidClients(i)
        {
            if(g_Client[i].Role == TTT_ROLE_TRAITOR)
            {
                Format(TeammateText, sizeof(TeammateText), "%s%s%N\n", TeammateText, IsPlayerDeadState(i) ? "*死亡* " : "", i);
                count++;
            }
        }
        if(count == 0)
        {
            StrCat(TeammateText, sizeof(TeammateText), "无叛徒\n");
        }
    }

    if(TTT_HasRadarItem(client))
    {
        Format(TeammateText, sizeof(TeammateText), "%s地图雷达还剩:%d秒激活\n", TeammateText, TTT_GetRadarCountdown(client));
    }

    SetHudTextParams(0.7, 0.15, 0.35, 255, 152, 5, 255, 0, 0.0, 0.02, 0.2);
    ShowSyncHudText(client, SyncHUDChannel_Infomation2, "%s", TeammateText);
}

stock ShowRoundStartHUD(int client)
{
    if(IsClientValid(client) && IsPlayerAlive(client) && (!IsGameStart && !IsGameEnd))
    {
        SetHudTextParams(0.65, 0.15, 0.35, 255, 152, 55, 255);
        ShowSyncHudText(client, SyncHUDChannel_Infomation1, "===TTT叛徒模式===\n聊天框输入!rule查看游戏规则\n在游戏中切忌乱杀, 否则将会受到封禁!\n\n该模式目前处于半成品\n更新日期:10/24\n有建议可输入!vo反馈\n玩家Q群:852454817");
        SetHudTextParams(0.225, 0.15, 0.35, 255, 152, 55, 255);
        ShowSyncHudText(client, SyncHUDChannel_CrossHair, "===按键帮助===\nSHIFT 快捷消息\n3次F 确认叛徒\n[夜视镜按键] 打开积分菜单\nTAB 检测DNA");
    }
}