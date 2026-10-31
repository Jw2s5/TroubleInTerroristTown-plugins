stock StartPlayGameMusic()
{
    int current = g_iMusicIndex;
    g_iMusicIndex = (g_iMusicIndex + 1) % sizeof(MusicList);

    tGameMusic = CreateTimer(MusicList[current].MUSIC_LENGTH, PlayGameMusic, current, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    PlayGameMusic(INVALID_HANDLE, current);
}

stock Action:PlayGameMusic(Handle Timer, any sound_id)
{
    StopPlayGameMusic();
    PlayingMusic = sound_id;
    for(int i = 1;i <= MaxClients;i++)
    {
        if(IsClientValid(i) && (0 <= sound_id < sizeof(MusicList)))
            EmitSoundToClient(i, MusicList[sound_id].MUSIC_NAME, SOUND_FROM_PLAYER, 8, _, _, 0.5);
    }
}

stock StopPlayGameMusic()
{
    if(PlayingMusic != -1)
    {
        for (new x = 1; x <= MaxClients; x++)
        {
            if (!IsClientValid(x))
                continue;

            StopSound(x, 8, MusicList[PlayingMusic].MUSIC_NAME);
        }
        PlayingMusic = -1;
    }
}

stock StopAllSound()
{
    TTT_EndTimer(tGameMusic);
    StopPlayGameMusic();
    for (new x = 1; x <= MaxClients; x++)
    {
        if (!IsClientValid(x))
            continue;
        StopSound(x, 8, innocent_win_sound);
        StopSound(x, 8, traitor_win_sound);
    }
}

stock PlaySoundToAll(const String:sound[])
{
    for (new x = 1; x <= MaxClients; x++)
    {
        if (!IsClientValid(x))
            continue;
        EmitSoundToClient(x, sound, SOUND_FROM_PLAYER, 8, _, _, 1.0);
    }
}

stock PlayDeadSound(client)
{
    char DeadSound[64];
    Format(DeadSound, sizeof(DeadSound), "ttt/die/die%d.mp3", GetRandomInt(1, DeadSoundNums));
    EmitSoundToAll(DeadSound, client, SNDCHAN_BODY);
}