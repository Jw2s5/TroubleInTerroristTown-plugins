stock InitGameParams()
{
    TTT_EndAllTimer();
    IsGameEnd = false;
    IsGameStart = false;
}

public Action:StartGame(Handle Timer)
{
    tGameStart = INVALID_HANDLE;
    int MaxTraitor, MaxDetective, AlivePlayers;
    AlivePlayers = GetAliveClientCounts();

    MaxTraitor = (AlivePlayers < 4) ? 1 : AlivePlayers / 4;
    MaxDetective = (AlivePlayers < 5) ? 0 : AlivePlayers / 5;

    // ===== 叛徒池：上一局叛徒权重降低 =====
    ArrayList TraitorPool = new ArrayList();
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientValid(client) && IsPlayerAlive(client))
        {
            // 上一局叛徒加入池子时，权重减半（通过 push 两次非叛徒，push 一次叛徒来实现加权）
            if(g_iLastTraitor[client] == 0)
            {
                // 非上局叛徒，权重正常（push 3 次）
                TraitorPool.Push(client);
                TraitorPool.Push(client);
                TraitorPool.Push(client);
            }
            else
            {
                // 上局叛徒，权重降低（push 1 次）
                TraitorPool.Push(client);
            }
        }
    }

    // 记录本局选中的叛徒
    int TraitorList[MAXPLAYERS + 1];
    int TraitorCount = 0;
    ArrayList SelectedTraitors = new ArrayList();

    for(int i = 0; i < MaxTraitor && TraitorPool.Length > 0; i++)
    {
        int randindex = GetRandomInt(0, TraitorPool.Length - 1);
        int randclient = TraitorPool.Get(randindex);

        // 检查是否已经选中过这个玩家
        bool alreadySelected = false;
        for(int j = 0; j < SelectedTraitors.Length; j++)
        {
            if(SelectedTraitors.Get(j) == randclient)
            {
                alreadySelected = true;
                break;
            }
        }

        if(alreadySelected)
        {
            TraitorPool.Erase(randindex);
            i--;
            continue;
        }

        SetClientRole(randclient, TTT_ROLE_TRAITOR);
        TraitorList[TraitorCount++] = randclient;
        SelectedTraitors.Push(randclient);

        // 从池子里移除这个玩家的所有实例
        for(int j = TraitorPool.Length - 1; j >= 0; j--)
        {
            if(TraitorPool.Get(j) == randclient)
            {
                TraitorPool.Erase(j);
            }
        }
    }
    CloseHandle(TraitorPool);
    CloseHandle(SelectedTraitors);

    // ===== 侦探池：上一局侦探权重降低 =====
    ArrayList DetectivePool = new ArrayList();
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientValid(client) && IsPlayerAlive(client) && g_Client[client].Role == TTT_ROLE_NONE)
        {
            if(g_iLastDetective[client] == 0)
            {
                // 非上局侦探，权重正常
                DetectivePool.Push(client);
                DetectivePool.Push(client);
                DetectivePool.Push(client);
            }
            else
            {
                // 上局侦探，权重降低
                DetectivePool.Push(client);
            }
        }
    }

    int DetectiveList[MAXPLAYERS + 1];
    int DetectiveCount = 0;
    ArrayList SelectedDetectives = new ArrayList();

    for(int i = 0; i < MaxDetective && DetectivePool.Length > 0; i++)
    {
        int randindex = GetRandomInt(0, DetectivePool.Length - 1);
        int randclient = DetectivePool.Get(randindex);

        bool alreadySelected = false;
        for(int j = 0; j < SelectedDetectives.Length; j++)
        {
            if(SelectedDetectives.Get(j) == randclient)
            {
                alreadySelected = true;
                break;
            }
        }

        if(alreadySelected)
        {
            DetectivePool.Erase(randindex);
            i--;
            continue;
        }

        SetClientRole(randclient, TTT_ROLE_DETECTIVE);
        DetectiveList[DetectiveCount++] = randclient;
        SelectedDetectives.Push(randclient);

        for(int j = DetectivePool.Length - 1; j >= 0; j--)
        {
            if(DetectivePool.Get(j) == randclient)
            {
                DetectivePool.Erase(j);
            }
        }
    }
    CloseHandle(DetectivePool);
    CloseHandle(SelectedDetectives);

    // ===== 剩下的为平民 =====
    for(int client = 1; client <= MaxClients; client++)
    {
        if(g_Client[client].Role == TTT_ROLE_NONE && IsClientValid(client) && IsPlayerAlive(client))
        {
            SetClientRole(client, TTT_ROLE_INNOCENT);
        }
    }

    // ===== 记录本局叛徒和侦探（供下一局排除） =====
    for(int i = 1; i <= MaxClients; i++)
    {
        g_iLastTraitor[i] = 0;
        g_iLastDetective[i] = 0;
    }
    for(int i = 0; i < TraitorCount; i++)
    {
        g_iLastTraitor[TraitorList[i]] = 1;
    }
    for(int i = 0; i < DetectiveCount; i++)
    {
        g_iLastDetective[DetectiveList[i]] = 1;
    }

    // 游戏开始后，所有活着的人血量设为100
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientValid(i) && IsPlayerAlive(i))
        {
            SetEntityHealth(i, 100);
        }
    }

    RoleNumsUpdate();
    StartRoundTimeCountdown();
    StartTraitorTimeCountdown();
    StartPlayGameMusic();
    PrintCenterTextAll("游戏开始！");
    IsGameStart = true;
}

stock TTT_EndRound(int team)
{
    if(!IsGameEnd)
    {
        StopAllSound();
        IsGameEnd = true;

        // 获取所有叛徒名单（只显示名字，不显示死亡状态）
        char traitorList[256];
        char playerName[MAX_NAME_LENGTH];
        int count = 0;
        for(int i = 1; i <= MaxClients; i++)
        {
            if(IsClientValid(i) && g_Client[i].Role == TTT_ROLE_TRAITOR)
            {
                GetClientName(i, playerName, sizeof(playerName));
                if(count > 0)
                {
                    StrCat(traitorList, sizeof(traitorList), ", ");
                }
                StrCat(traitorList, sizeof(traitorList), playerName);
                count++;
            }
        }

        if(team == TTT_TEAM_INNOCENTS)
        {
            PrintCenterTextAll(" 平民 胜出！");
            CS_TerminateRound(16.0, CSRoundEnd_CTWin, true);
            PlaySoundToAll(innocent_win_sound);
            InnocentWin++;
            AddTeamFrags(TTT_TEAM_INNOCENTS, 1);

            if(count > 0)
            {
                CPrintToChatAll("{green}[TTT]{default}本局叛徒: {red}%s", traitorList);
            }
        }
        else if(team == TTT_TEAM_TRAITORS)
        {
            PrintCenterTextAll(" 叛徒 胜出！");
            CS_TerminateRound(16.0, CSRoundEnd_TerroristWin, true);
            PlaySoundToAll(traitor_win_sound);
            TraitorWin++;
            AddTeamFrags(TTT_TEAM_TRAITORS, 1);

            if(count > 0)
            {
                CPrintToChatAll("{red}[TTT]{default}叛徒: {red}%s", traitorList);
            }
        }
        else
        {
            CS_TerminateRound(0.0, CSRoundEnd_Draw, true);
            ClearTeamFrags(TTT_TEAM_ALL);
        }
    }
}

public Action:CS_OnTerminateRound(&Float:delay, &CSRoundEndReason:reason)
{
    if((reason == CSRoundEnd_GameStart && !IsGameStart))
    {
        return Plugin_Continue;
    }
    CheckWinConditions();
    return Plugin_Handled;
}

stock CheckWinConditions()
{
    if(IsGameStart && !IsGameEnd && !IsRequiredToPlay)
    {
        RoleNumsUpdate();
        if(!TraitorNums)
        {
            TTT_EndRound(TTT_TEAM_INNOCENTS);
        }
        else if(!DetectiveNums && !InnocentNums)
        {
            TTT_EndRound(TTT_TEAM_TRAITORS);
        }
    }
}

// ============================================================
// 直接根据 自定义角色数据 + 真实连接状态 判断胜负
// 不依赖引擎 IsPlayerAlive / IsClientInGame 的延迟刷新
// 用于玩家断开后（OnClientDisconnect 延迟 0.1 秒调用）
// ============================================================
stock void CheckWinConditionsDirect()
{
    if(!IsGameStart || IsGameEnd || IsRequiredToPlay)
        return;

    int aliveTraitors  = 0;
    int aliveInnocents = 0;   // 含侦探

    for(int client = 1; client <= MaxClients; client++)
    {
        // 1. 已断开的玩家立即排除（比 IsClientInGame 更早失效）
        if(!IsClientConnected(client))
            continue;
        if(IsClientSourceTV(client))
            continue;
        if(!IsClientInGame(client))
            continue;

        // 2. 角色已被清空（OnClientDisconnect 里清成 NONE）的不算
        int role = g_Client[client].Role;
        if(role == TTT_ROLE_NONE)
            continue;

        // 3. 必须真正活着（IsReallyAlive 已包含 IsPlayerAlive）
        if(!IsReallyAlive(client))
            continue;

        if(role == TTT_ROLE_TRAITOR)
            aliveTraitors++;
        else if(role == TTT_ROLE_INNOCENT || role == TTT_ROLE_DETECTIVE)
            aliveInnocents++;
    }

    if(aliveTraitors == 0)
    {
        TTT_EndRound(TTT_TEAM_INNOCENTS);
    }
    else if(aliveInnocents == 0)
    {
        TTT_EndRound(TTT_TEAM_TRAITORS);
    }
}

public Action:CheckGameCondition(Handle Timer)
{
    // ===== 计算真实玩家数（排除 SourceTV） =====
    int realPlayers = 0;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientValid(i) && !IsClientSourceTV(i))
            realPlayers++;
    }
    // ==========================================

    if(realPlayers < ttt_gamestart_require.IntValue)
    {
        for(int i = 1;i <= MaxClients;i++)
        {
            if(IsClientValid(i) && !IsClientSourceTV(i) && !IsPlayerAlive(i))
            {
                CS_SwitchTeam(i, CS_TEAM_T);
                CS_RespawnPlayer(i);
                ResetPlayer(i);
            }
            InitPlayerRole(i);
        }
        TTT_EndAllTimer();
        PrintHintTextToAll("等待玩家进入游戏");
        if(IsGameStart)
        {
            StopPlayGameMusic();
        }
        IsGameStart = false;
        IsGameEnd = false;
        IsRequiredToPlay = true;
    }
    else
    {
        if(IsRequiredToPlay)
        {
            TTT_EndRound(TTT_TEAM_ALL);
        }
        IsRequiredToPlay = false;

        if(IsGameStart && !IsGameEnd)
        {
            CheckTraitorsLeft();
        }
    }
}