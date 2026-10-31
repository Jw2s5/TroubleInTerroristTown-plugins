#define SCOREATTRIB_DEAD (1 << 0)
InitEvents()
{
    HookEvent("round_start", Event_RoundStart_Pre, EventHookMode_Pre);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_freeze_end", Event_RoundFreezeEnd);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_spawn", Event_PlayerSpawn_Pre, EventHookMode_Pre);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_blind", Event_PlayerBlind, EventHookMode_Post);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("player_death", Event_PlayerDeath_Pre, EventHookMode_Pre);
    HookEvent("player_jump", Event_PlayerJump);
    HookEvent("weapon_fire", Event_WeaponFire);
}

public Action Event_RoundStart_Pre(Event event, const char[] name, bool dontBroadcast)
{
    StopAllSound();
    InitGameParams();
    InitRoleNums();
    BodiesOnRoundStart();
    DnaListOnRoundStart();
    MoveSpecPlayers();
    return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    TTT_EndAllTimer();
    CheckGameCondition(INVALID_HANDLE);
    
    for(int i = 1; i <= MaxClients; i++)
    {
        g_iLastTraitor[i] = 0;
    }
    
    LoopValidClients(client)
    {
        if(IsPlayerAlive(client))
        {
            ResetPlayer(client);
        }
        CPrintToChat(client, "%s当前Karma值: {yellow}%d", TTT_TAG, g_Client[client].Karma);
    }
    ResetPlayersVoice();
    InitShopItemsBuyLimit();
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientValid(i))
            continue;
        if(IsClientSourceTV(i))
            continue;
        
        SetEntProp(i, Prop_Data, "m_iFrags", 0);
        SetEntProp(i, Prop_Data, "m_iDeaths", 0);
    }

    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientValid(i) && !IsFakeClient(i))
        {
            for(int j = 0; j < 20; j++)
            {
                CPrintToChat(i, " ");
            }
            
            CPrintToChat(i, "");
            CPrintToChat(i, "");
            CPrintToChat(i, "");
            CPrintToChat(i, "");
            CPrintToChat(i, "");
            CPrintToChat(i, "{red}(demo){green}132TTT:{pink}demo下载请前往{yellow}103.85.84.40:20080/demo/");
            CPrintToChat(i, "%s当前Karma值: {yellow}%d", TTT_TAG, g_Client[i].Karma);
        }
    }
    
    return Plugin_Continue;
}

public Action Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
    InitGameStart();
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    IsGameEnd = true;
    ResetPlayersVoice();
    UpdatePlayersFrags();
    return Plugin_Continue;
}

public Action Event_PlayerSpawn_Pre(Event event, const char[] name, bool dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(IsClientValid(client) && !IsClientSourceTV(client))
    {
        CS_SwitchTeam(client, CS_TEAM_T);
        CreateTimer(0.0, Timer_RemoveHud, client);
    }
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(IsClientValid(client))
    {
        g_Client[client].SpawnCheck = true;
    }
    return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    return Plugin_Continue;
}

public Action Event_PlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast)
{
    char weapon[32];
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    bool headshot = GetEventBool(event, "headshot");
    GetEventString(event, "weapon", weapon, sizeof(weapon));
    
    CheckWinConditions();
    AddTraitorTime(victim, attacker);
    PlayDeadSound(victim);
    ClearRoleIcon(victim);
    ClearDNAIcon(INVALID_HANDLE, victim);
    BodiesOnPlayerDeath(victim, attacker, weapon, headshot);
    BlockPlayerVoice(victim);
    TellVictimAttackerRole(victim, attacker);
    HideHiddenViewModel(victim);
    AddKillingFrags(victim, attacker);
    AddKillingKarma(victim, attacker);
    AddRoleDeathCredits(victim);
    ClientCommand(victim, "spec_menu");
    
    return Plugin_Handled;
}

public Action Event_PlayerJump(Event event, const char[] name, bool dontBroadcast)
{
    return Plugin_Continue;
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    RequestFrame(InitWeaponsFireSpeed, client);
    return Plugin_Continue;
}

stock InitSDKHooks(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, DamageOnTakeDamage);
    SDKHook(client, SDKHook_TraceAttack, DamageOnTraceAttack);
    SDKHook(client, SDKHook_WeaponSwitchPost, WeaponOnWeaponSwitchPost);
    SDKHook(client, SDKHook_WeaponDrop, WeaponOnWeaponDrop);
    SDKHook(client, SDKHook_WeaponDropPost, WeaponOnWeaponDropPost);
    SDKHook(client, SDKHook_PostThinkPost, OnClientThinkPost);
}

stock UnHookSDKHooks(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, DamageOnTakeDamage);
    SDKUnhook(client, SDKHook_TraceAttack, DamageOnTraceAttack);
    SDKUnhook(client, SDKHook_WeaponSwitchPost, WeaponOnWeaponSwitchPost);
    SDKUnhook(client, SDKHook_WeaponDrop, WeaponOnWeaponDrop);
    SDKUnhook(client, SDKHook_WeaponDropPost, WeaponOnWeaponDropPost);
    SDKUnhook(client, SDKHook_PostThinkPost, OnClientThinkPost);
}

stock void CheckTraitorsLeft()
{
    int aliveTraitors = 0;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientValid(i) && IsReallyAlive(i) && g_Client[i].Role == TTT_ROLE_TRAITOR)  // ← 改成 IsReallyAlive
        {
            aliveTraitors++;
        }
    }
    
    if(aliveTraitors == 0 && IsGameStart && !IsGameEnd)
    {
        TTT_EndRound(TTT_TEAM_INNOCENTS);
    }
}