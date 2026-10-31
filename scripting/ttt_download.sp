#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

public Plugin myinfo = {
    name = "[TTT] 下载管理器",
    author = "Jw2s5",
    description = "从configs/download.ini读取文件列表并自动预载和下载",
    version = "1.0",
    url = ""
};

ArrayList g_hFileList;

public void OnPluginStart()
{
    g_hFileList = new ArrayList(ByteCountToCells(256));
    LoadDownloadList();
    RegConsoleCmd("sm_download_reload", Command_ReloadDownload);
}

public void OnMapStart()
{
    PrecacheAllFiles();
}

public void OnPluginEnd()
{
    delete g_hFileList;
}

// ========== 读取配置文件 ==========

void LoadDownloadList()
{
    if (g_hFileList == null)
        g_hFileList = new ArrayList(ByteCountToCells(256));
    
    g_hFileList.Clear();
    
    char configPath[256];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/download.ini");
    
    if (!FileExists(configPath))
    {
        LogError("[下载管理器] 配置文件不存在: %s", configPath);
        CreateDefaultConfig(configPath);
        return;
    }
    
    File hFile = OpenFile(configPath, "r");
    if (hFile == null)
    {
        LogError("[下载管理器] 无法打开配置文件: %s", configPath);
        return;
    }
    
    char line[256];
    while (hFile.ReadLine(line, sizeof(line)))
    {
        TrimString(line);
        
        if (strlen(line) == 0 || line[0] == ';' || line[0] == '#')
            continue;
        
        // 去除BOM
        if (strlen(line) > 0 && line[0] == '\xEF' && line[1] == '\xBB' && line[2] == '\xBF')
        {
            for (int i = 0; i < strlen(line) - 2; i++)
                line[i] = line[i + 3];
            line[strlen(line) - 3] = '\0';
        }
        
        // 标准化路径
        for (int i = 0; i < strlen(line); i++)
        {
            if (line[i] == '\\')
                line[i] = '/';
        }
        
        g_hFileList.PushString(line);
    }
    
    delete hFile;
    LogMessage("[下载管理器] 已加载 %d 个文件", g_hFileList.Length);
}

// ========== 创建默认配置文件 ==========

void CreateDefaultConfig(const char[] path)
{
    File hFile = OpenFile(path, "w");
    if (hFile == null)
        return;
    
    hFile.WriteLine("; ============================================");
    hFile.WriteLine("; TTT 下载文件列表");
    hFile.WriteLine("; 每行一个文件路径");
    hFile.WriteLine("; 以 ; 或 # 开头的行为注释");
    hFile.WriteLine("; ============================================");
    hFile.WriteLine("");
    hFile.WriteLine("; ===== 音效文件 ===== ");
    hFile.WriteLine("sound/ttt/07_the_plot_thickens.mp3");
    hFile.WriteLine("sound/ttt/box15.mp3");
    hFile.WriteLine("sound/ttt/camp.mp3");
    hFile.WriteLine("sound/ttt/fuan.mp3");
    hFile.WriteLine("sound/ttt/horror2.mp3");
    hFile.WriteLine("sound/ttt/kuroi_light.mp3");
    hFile.WriteLine("sound/ttt/l2.mp3");
    hFile.WriteLine("sound/ttt/promise.mp3");
    hFile.WriteLine("sound/ttt/puzzle_snd_fix.mp3");
    hFile.WriteLine("sound/ttt/supposition.mp3");
    hFile.WriteLine("sound/ttt/suspicion.mp3");
    hFile.WriteLine("sound/ttt/themeoflaura_v2.mp3");
    hFile.WriteLine("sound/ttt/pingmin_win.mp3");
    hFile.WriteLine("sound/ttt/pantu_win.mp3");
    hFile.WriteLine("sound/ttt/shop_selected.wav");
    hFile.WriteLine("sound/ttt/body_impact_hard.wav");
    hFile.WriteLine("sound/ttt/crowbar_hitwall.wav");
    hFile.WriteLine("sound/ttt/die/die1.mp3");
    hFile.WriteLine("sound/ttt/die/die2.mp3");
    hFile.WriteLine("sound/ttt/die/die3.mp3");
    hFile.WriteLine("sound/ttt/die/die4.mp3");
    hFile.WriteLine("sound/ttt/die/die5.mp3");
    hFile.WriteLine("sound/ttt/die/die6.mp3");
    hFile.WriteLine("sound/ttt/die/die7.mp3");
    hFile.WriteLine("sound/ttt/die/die8.mp3");
    hFile.WriteLine("sound/ttt/die/die9.mp3");
    hFile.WriteLine("sound/weapons/ttt/jihad.wav");
    hFile.WriteLine("sound/weapons/ttt/rpgfire1.mp3");
    hFile.WriteLine("sound/weapons/ttt/silence_awp.wav");
    hFile.WriteLine("");
    hFile.WriteLine("; ===== 图标文件 ===== ");
    hFile.WriteLine("materials/ttt/icon/detective_icon.vmt");
    hFile.WriteLine("materials/ttt/icon/traitor_icon.vmt");
    hFile.WriteLine("materials/ttt/icon/body_call.vmt");
    hFile.WriteLine("materials/ttt/icon/dna_result.vmt");
    hFile.WriteLine("materials/ttt/icon/detective_icon.vtf");
    hFile.WriteLine("materials/ttt/icon/traitor_icon.vtf");
    hFile.WriteLine("materials/ttt/icon/body_call.vtf");
    hFile.WriteLine("materials/ttt/icon/dna_result.vtf");
    hFile.WriteLine("");
    hFile.WriteLine("; ===== 模型文件 ===== ");
    hFile.WriteLine("models/weapons/ttt/v_crowbar.mdl");
    hFile.WriteLine("models/weapons/ttt/w_crowbar.mdl");
    hFile.WriteLine("models/weapons/ttt/v_dragn_t_new.mdl");
    hFile.WriteLine("models/weapons/ttt/w_dragn_t_new.mdl");
    hFile.WriteLine("models/weapons/ttt/v_jb.mdl");
    hFile.WriteLine("models/weapons/ttt/w_jb.mdl");
    hFile.WriteLine("models/weapons/ttt/v_slient_awp.mdl");
    hFile.WriteLine("models/weapons/ttt/w_slient_awp.mdl");
    hFile.WriteLine("models/weapons/ttt/v_rpg.mdl");
    hFile.WriteLine("models/weapons/ttt/w_rocket_launcher.mdl");
    hFile.WriteLine("models/weapons/ttt/w_missile_closed.mdl");
    hFile.WriteLine("models/weapons/ttt/v_healthkit.mdl");
    hFile.WriteLine("models/weapons/ttt/v_g_deagle.mdl");
    hFile.WriteLine("models/weapons/ttt/w_g_deagle.mdl");
    hFile.WriteLine("models/weapons/ttt/v_crowbar.dx80.vtx");
    hFile.WriteLine("models/weapons/ttt/v_crowbar.dx90.vtx");
    hFile.WriteLine("models/weapons/ttt/v_crowbar.sw.vtx");
    hFile.WriteLine("models/weapons/ttt/v_crowbar.vvd");
    hFile.WriteLine("models/weapons/ttt/w_crowbar.dx80.vtx");
    hFile.WriteLine("models/weapons/ttt/w_crowbar.dx90.vtx");
    hFile.WriteLine("models/weapons/ttt/w_crowbar.sw.vtx");
    hFile.WriteLine("models/weapons/ttt/w_crowbar.vvd");
    hFile.WriteLine("models/weapons/ttt/w_crowbar.phy");
    hFile.WriteLine("");
    hFile.WriteLine("; ===== 材质文件 ===== ");
    hFile.WriteLine("materials/models/weapons/v_models/crowbar/");
    hFile.WriteLine("materials/models/weapons/v_models/dragonlord/");
    hFile.WriteLine("materials/models/weapons/v_models/jb_c4/");
    hFile.WriteLine("materials/models/weapons/w_models/jb_c4/");
    hFile.WriteLine("materials/models/weapons/v_models/slient_awp/");
    hFile.WriteLine("materials/models/weapons/w_models/slient_awp/");
    hFile.WriteLine("materials/models/weapons/v_models/g_deagle/");
    hFile.WriteLine("materials/models/weapons/w_models/g_deagle/");
    
    delete hFile;
    LogMessage("[下载管理器] 已创建默认配置文件: %s", path);
    
    LoadDownloadList();
}

// ========== 自动预载所有文件 ==========

void PrecacheAllFiles()
{
    if (g_hFileList == null || g_hFileList.Length == 0)
        return;
    
    int count = g_hFileList.Length;
    LogMessage("[下载管理器] 开始预载 %d 个文件...", count);
    
    char filePath[256];
    for (int i = 0; i < count; i++)
    {
        g_hFileList.GetString(i, filePath, sizeof(filePath));
        
        // 去除BOM
        if (strlen(filePath) > 0 && filePath[0] == '\xEF' && filePath[1] == '\xBB' && filePath[2] == '\xBF')
        {
            for (int j = 0; j < strlen(filePath) - 2; j++)
                filePath[j] = filePath[j + 3];
            filePath[strlen(filePath) - 3] = '\0';
        }
        
        if (strlen(filePath) == 0)
            continue;
        
        // 预载
        if (StrContains(filePath, "sound/") == 0)
        {
            char soundPath[256];
            strcopy(soundPath, sizeof(soundPath), filePath[6]);
            PrecacheSound(soundPath, true);
        }
        else
        {
            PrecacheModel(filePath, true);
        }
        
        // 添加到下载列表
        AddFileToDownloadsTable(filePath);
    }
    
    LogMessage("[下载管理器] 预载完成!");
}

// ========== 控制台命令 ==========

public Action Command_ReloadDownload(int client, int args)
{
    LoadDownloadList();
    PrecacheAllFiles();
    ReplyToCommand(client, "[下载管理器] 已重新加载并预载所有文件");
    return Plugin_Handled;
}