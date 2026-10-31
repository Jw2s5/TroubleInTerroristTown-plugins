stock GetAliveClientCounts()
{
    int aliveclient;
    for(int client = 1;client <= MaxClients;client++)
    {
        if(IsClientInGame(client) && IsPlayerAlive(client))
            aliveclient++;
    }
    return aliveclient;
}

stock bool IsReallyAlive(int client)
{
    if(!IsClientValid(client)) return false;
    if(!IsPlayerAlive(client)) return false;
    
    if(GetEntProp(client, Prop_Send, "m_iHealth") == 1 && GetEntProp(client, Prop_Data, "m_iFrags") == -999)
        return false;
    
    return true;
}

stock CreateClientList(&ArrayList:Array, int Role)
{
    Array = new ArrayList();
    for (new client = 1;client <= MaxClients;client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client)) continue;
        if (g_Client[client].Role == Role) Array.Push(client);
    }
    return Array.Length;
}

stock bool:IsPlayersInDistance(client, target)
{
    float origin[2][3], distance;
    GetClientAbsOrigin(client, origin[0]);
    GetClientAbsOrigin(target, origin[1]);
    distance = GetVectorDistance(origin[0], origin[1]);
    if(distance <= ttt_show_hud_distance.FloatValue) return true;
    return false;
}

stock bool CanClientUseEntity(int client, int iEntity)
{
    if(IsClientValid(client) && IsPlayerAlive(client) && IsValidEntity(iEntity))
    {
        static float fEntityPosition[3], fMyPosition[3];
        GetClientAbsOrigin(client, fMyPosition);
        GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", fEntityPosition);
        if(GetVectorDistance(fMyPosition, fEntityPosition) <= ttt_entity_use_distance.FloatValue)
        {
            return true;
        }
    }
    return false
}

stock bool IsEntityBody(int iEntity)
{
    if(!IsValidEntity(iEntity)) return false;
    char classname[32];
    GetEntityClassname(iEntity, classname, sizeof(classname));
    return StrEqual(classname, "prop_ragdoll", false);
}

stock int GetTargetInRange(int client, float range)
{
    float clientPos[3], targetPos[3];
    GetClientAbsOrigin(client, clientPos);
    
    int bestTarget = -1;
    float bestDistance = range;
    float bestDot = -1.0;
    
    float eyePos[3];
    GetClientEyePosition(client, eyePos);
    float eyeAngles[3];
    GetClientEyeAngles(client, eyeAngles);
    float direction[3];
    GetAngleVectors(eyeAngles, direction, NULL_VECTOR, NULL_VECTOR);
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!TTT_IsClientValid(i) || i == client || !IsPlayerAlive(i))
            continue;
        
        GetClientAbsOrigin(i, targetPos);
        float distance = GetVectorDistance(clientPos, targetPos);
        
        if(distance > bestDistance)
            continue;
        
        Handle trace = TR_TraceRayFilterEx(eyePos, targetPos, MASK_SHOT, RayType_EndPoint, TraceFilter_OnlyWorld, client);
        
        if(TR_DidHit(trace))
        {
            int hitEntity = TR_GetEntityIndex(trace);
            if(hitEntity != i)
            {
                delete trace;
                continue;
            }
        }
        delete trace;
        
        float toTarget[3];
        SubtractVectors(targetPos, eyePos, toTarget);
        NormalizeVector(toTarget, toTarget);
        
        float dot = GetVectorDotProduct(direction, toTarget);
        
        if(dot > 0.1 && dot > bestDot)
        {
            bestDot = dot;
            bestTarget = i;
            bestDistance = distance;
        }
    }
    
    return bestTarget;
}

public bool TraceFilter_OnlyWorld(int entity, int contentsMask, int client)
{
    if(entity == client)
        return false;
    if(entity >= 1 && entity <= MaxClients)
        return false;
    return true;
}

stock bool IsAimingAtPlayer(int client, int target)
{
    if(!IsClientValid(client) || !IsClientValid(target))
        return false;

    float eyePos[3], eyeAngles[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAngles); // <--- 这里修复成了 GetClientEyeAngles

    Handle trace = TR_TraceRayFilterEx(eyePos, eyeAngles, MASK_SHOT, RayType_Infinite, TraceFilter_OnlyWorld, client);

    bool bHit = false;
    if(TR_DidHit(trace))
    {
        int hitEntity = TR_GetEntityIndex(trace);
        if(hitEntity == target)
        {
            bHit = true;
        }
    }
    delete trace;

    return bHit;
}

stock bool IsPlayerDeadState(int client)
{
    if(!IsClientValid(client)) return true;
    if(!IsPlayerAlive(client)) return true;
    
    for(int i = 0; i < g_aRagdoll.Length; i++)
    {
        Ragdoll body;
        g_aRagdoll.GetArray(i, body, sizeof(body));
        if(body.Victim == client && !body.Found)
        {
            return true;
        }
    }
    return false;
}