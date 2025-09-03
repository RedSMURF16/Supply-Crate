/*
*
*	Supply Crate by RedSMURF
*
*
*	Description:
*   This plugin adds a menu offering multiple crate types, each with unqiue functionality,
*   it only uses it's own crate models as custom crate animations are not supported.
*
*
*	Cvars:
*		None
*
*	Commands:
*       say /sc                     "Opens the Crates menu."
*       say_team /sc                "Opens the Crates menu."
*       say /supplycrate            "Opens the Crates menu."
*       say_team /supplycrate       "Opens the Crates menu."
*       crate_reload                "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
#endif

#if !defined MAX_AUTHID_LENGTH
    #define MAX_AUTHID_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT                 32
#define MENU_BLINK              0.1
#define MEMBER_ACTIVE_WEAPON    373
#define MEMBER_AMMO_TYPE        49

/**
 *  Crate animation sequences.
 */
#define CRATE_SEQ_IDLE          0
#define CRATE_SEQ_OPENCLOSE     1

/**
 *  Crate Bitflag sounds.
 */
#define CRATE_SOUND_PLACED      (1 << 0)
#define CRATE_SOUND_REMOVED     (1 << 1)
#define CRATE_SOUND_OPENING     (1 << 2)
#define CRATE_SOUND_EMPTY       (1 << 3)
#define CRATE_SOUND_GET         (1 << 4)
#define CRATE_SOUND_SELL        (1 << 5)

new const PLUGIN_VERSION[]          = "1.0"
new const Float:DELAY_ON_CONNECT    = 1.0
new const ERROR_FILE[]              = "SupplyCrate_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_CRATE
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_CAPACITY,
    SETTING_DEFAULT_RATE,

    Float:SETTING_MINS_LONG[3],
    Float:SETTING_MAXS_LONG[3],
    Float:SETTING_MINS_WIDE[3],
    Float:SETTING_MAXS_WIDE[3],
    SETTING_SOUND_PLACED[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_REMOVED[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_OPENING[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_EMPTY[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_GET[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_SELL[MAX_RESOURCE_PATH_LENGTH],

    bool:SETTING_CRATE_LOAD,
    Float:SETTING_CRATE_RANGE,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET_MIN,
    Float:SETTING_OFFSET_MAX,
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    SETTING_GHOST_ALPHA,
    Float:SETTING_GHOST_FREQ,
    bool:SETTING_REQUIRE_EMPTY
}

enum _:CRATE
{
    CRATE_ID,
    CRATE_ITEM,
    CRATE_NAME[MAX_VALUE_LENGTH],
    CRATE_MODEL[MAX_RESOURCE_PATH_LENGTH],
    CRATE_CLASS,
    CRATE_MODE,
    CRATE_RATE,
    CRATE_CAPACITY,
    CRATE_SOUND_FLAGS,
    Float:CRATE_FACTOR,
    Float:CRATE_COOLDOWN,
    Float:CRATE_FRAMERATE,
    Float:CRATE_ORIGIN[3],
    Float:CRATE_ANGLES[3],
    Float:CRATE_NEXT_USE,
    Float:CRATE_NEXT_SOUND
}

enum _:PLAYER_DATA
{
    PDATA_NAME[MAX_VALUE_LENGTH],
    PDATA_AUTHID[MAX_AUTHID_LENGTH],
    PDATA_ADMIN_FLAGS,
    PDATA_CRATE_GHOST,
    PDATA_CRATE_MENU,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET
}

enum
{
    CLASS_AMMO,
    CLASS_GRENADES,
    CLASS_MARKET
}

enum
{
    SOUND_PLACED,
    SOUND_REMOVED,
    SOUND_OPENING,
    SOUND_EMPTY,
    SOUND_GET,
    SOUND_SELL
}

enum
{
    AMMO_VEST,
    AMMO_ONLY,
    AMMO_VESTHELM,
    VEST_ONLY,
    VESTHELM_ONLY
}

enum
{
    GRENADES_FB,
    GRENADES_HE,
    GRENADES_SG,
    GRENADES_HE_FB,
    GRENADES_HE_SG,
    GRENADES_FB_SG,
    GRENADES_ALL
}

enum
{
    RATE_VERYSLOW = -2,
    RATE_SLOW,
    RATE_NORMAL,
    RATE_FAST,
    RATE_VERYFAST
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_REMOVE,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_REMOVE,
    ROOT_SAVE
}

enum
{
    DEL_NEXT,
    DEL_BACK,
    DEL_REMOVE
}

enum
{
    ROTATE_RIGHT,
    ROTATE_LEFT,
    ROTATE_PLACE
}

enum _:TASK_MENU
{
    TASK_ID,
    TASK_TYPE
}

new Float:g_fDirections[][] =
{
    {1.0, 0.0, 0.0},
    {-1.0, 0.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, -1.0, 0.0},
    {0.0, 0.0, 1.0},
    {0.0, 0.0, -1.0}
}

new const g_iWeaponMaxBP[] =
{
    0,      52,     0,    90,     0,    32,     0,   100,    90,     1,
    120,   100,   100,    90,    90,    90,   100,   120,    30,   120,
    200,    32,    90,   120,    90,     0,    35,    90,    90,     0,
    100
}

new const g_iWeaponMarket[] =
{
    0,     600,  2200,  2750,   300,  3000,     0,  1400,  3500,   300,
    800,   750,  1700,  4200,  2000,  2250,   500,   400,  4750,  1500,
    5750, 1700,  3100,  1250,  5000,   200,   650,  2500,  3500,     0,
    2350
}

new g_szMenuHandler[][MAX_VALUE_LENGTH] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerRemove",
    "menuHandlerRotate"
}

new g_szCN[][MAX_VALUE_LENGTH] =
{
    "SC_Ammo",
    "SC_Grenades",
    "SC_Market"
}

new Array:g_aCrate,
    Array:g_aCrateConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    g_szFileName[MAX_RESOURCE_PATH_LENGTH],
    bool:g_bFileWasRead = false,
    g_iCrate,
    g_iCrateConfig,
    g_iAmmoPickup

public plugin_init()
{
    register_plugin("Ammo Crate", PLUGIN_VERSION, "RedSMURF")

    register_clcmd("say /sc",               "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /sc",          "cmdMenu", ADMIN_RCON)
    register_clcmd("say /supplycrate",      "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /supplycrate", "cmdMenu", ADMIN_RCON)
    register_concmd("crate_reload", "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")

    register_dictionary("SupplyCrate.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    RegisterHam(Ham_Spawn, "info_target", "fwdSpawn", 1)
    RegisterHam(Ham_Think, "info_target", "fwdThink", 1)
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink", 0)

    register_logevent("eventRoundStart", 2, "1=Round_Start")
    set_task(g_eSettings[SETTING_GHOST_FREQ], "crateGhost", .flags = "b")

    g_iAmmoPickup = get_user_msgid("AmmoPickup")

    if ( g_eSettings[SETTING_CRATE_LOAD] )
        loadData()
}

public plugin_precache()
{
    g_aCrate       = ArrayCreate(CRATE)
    g_aCrateConfig = ArrayCreate(CRATE)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aCrate)
    ArrayDestroy(g_aCrateConfig)
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    new iArg[TASK_MENU]
    iArg[TASK_ID]   = id
    iArg[TASK_TYPE] = MENU_ROOT

    set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))

    return PLUGIN_HANDLED
}

public cmdReload(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ReadFile()
    console_print(id, "The configuration file has been reloaded successfully !")

    return PLUGIN_HANDLED
}

public client_command(id)
{
    if ( !g_ePlayerData[id][PDATA_CRATE_GHOST] )
        return PLUGIN_CONTINUE

    new szCmd[16]
    read_argv(0, szCmd, charsmax(szCmd))

    if ( contain(szCmd, "weapon_") != -1
    || equal(szCmd, "invnext")
    || equal(szCmd, "invprev")
    || equal(szCmd, "lastinv") )
        return PLUGIN_HANDLED

    return PLUGIN_CONTINUE
}

public eventRoundStart()
{
    if ( !g_iCrate )
        return PLUGIN_HANDLED

    new eCrate[CRATE],
        eCrateConfig[CRATE]

    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        ArrayGetArray(g_aCrateConfig, eCrate[CRATE_ITEM], eCrateConfig)

        eCrate[CRATE_CAPACITY] = eCrateConfig[CRATE_CAPACITY]
        ArraySetArray(g_aCrate, i, eCrate)
    }

    return PLUGIN_HANDLED
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        new iPlayers[MAX_PLAYERS], iNum
        get_players(iPlayers, iNum, "ch")

        for ( new i = 0; i < iNum; i ++ )
            UpdateData(iPlayers[i])

        ArrayClear(g_aCrateConfig)
        g_iCrateConfig = 0
    }

    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/SupplyCrate.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[MAX_FILE_CELL_SIZE],
        szKey[MAX_VALUE_LENGTH],
        szValue[MAX_RESOURCE_PATH_LENGTH],
        eCrate[CRATE], iSection = SECTION_NONE, iLine

    while( !feof(iFile) )
    {
        iLine ++
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax(szData), "[", "")
                    replace(szData, charsmax(szData), "]", "")
                    trim(szData)

                    if ( equali(szData, "Main Settings") )
                    {
                        iSection = SECTION_MAIN_SETTINGS
                    }
                    else
                    {
                        if ( g_iCrateConfig )
                            cratePush(eCrate)

                        copy(eCrate[CRATE_NAME], charsmax(eCrate[CRATE_NAME]), szData)
                        eCrate[CRATE_MODEL][0]    = EOS
                        eCrate[CRATE_CLASS]       = 0
                        eCrate[CRATE_MODE]        = 0
                        eCrate[CRATE_RATE]        = 0
                        eCrate[CRATE_CAPACITY]    = 0
                        eCrate[CRATE_SOUND_FLAGS] = 0
                        eCrate[CRATE_FACTOR]      = 1.0
                        eCrate[CRATE_COOLDOWN]    = 2.2
                        eCrate[CRATE_FRAMERATE]   = 1.0

                        iSection = SECTION_CRATE
                        g_iCrateConfig ++
                    }
                }
                else
                {
                    LogConfigError(iLine, "Unclosed section name: %s", szData)
                    iSection = SECTION_NONE
                }
            }
            default:
            {
                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                        trim(szKey)
                        trim(szValue)

                        if ( equali(szKey, "SETTING_DEFAULT_MODEL") )
                        {
                            copy(g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]), szValue)
                            if ( !g_bFileWasRead ) precache_model(g_eSettings[SETTING_DEFAULT_MODEL])
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_CAPACITY") )
                        {
                            g_eSettings[SETTING_DEFAULT_CAPACITY] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_RATE") )
                        {
                            g_eSettings[SETTING_DEFAULT_RATE] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_MINS_LONG") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS_LONG][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS_LONG][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MINS_LONG][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_MAXS_LONG") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS_LONG][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS_LONG][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MAXS_LONG][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_MINS_WIDE") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS_WIDE][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS_WIDE][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MINS_WIDE][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_MAXS_WIDE") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS_WIDE][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS_WIDE][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MAXS_WIDE][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_PLACED") )
                        {
                            copy(g_eSettings[SETTING_SOUND_PLACED], charsmax(g_eSettings[SETTING_SOUND_PLACED]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_PLACED])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_REMOVED") )
                        {
                            copy(g_eSettings[SETTING_SOUND_REMOVED], charsmax(g_eSettings[SETTING_SOUND_REMOVED]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_REMOVED])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_OPENING") )
                        {
                            copy( g_eSettings[SETTING_SOUND_OPENING], charsmax(g_eSettings[SETTING_SOUND_OPENING]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_OPENING])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_EMPTY") )
                        {
                            copy(g_eSettings[SETTING_SOUND_EMPTY], charsmax(g_eSettings[SETTING_SOUND_EMPTY]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_EMPTY])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_GET") )
                        {
                            copy(g_eSettings[SETTING_SOUND_GET], charsmax(g_eSettings[SETTING_SOUND_GET]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_GET])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_SELL") )
                        {
                            copy(g_eSettings[SETTING_SOUND_SELL], charsmax(g_eSettings[SETTING_SOUND_SELL]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_SELL])
                        }
                        else if ( equali(szKey, "SETTING_CRATE_LOAD") )
                        {
                            g_eSettings[SETTING_CRATE_LOAD] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_CRATE_RANGE") )
                        {
                            g_eSettings[SETTING_CRATE_RANGE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                        {
                            g_eSettings[SETTING_OFFSET_BASE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MIN") )
                        {
                            g_eSettings[SETTING_OFFSET_MIN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MAX") )
                        {
                            g_eSettings[SETTING_OFFSET_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                        {
                            g_eSettings[SETTING_OFFSET_STEP] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_FREQ") )
                        {
                            g_eSettings[SETTING_OFFSET_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                        {
                            g_eSettings[SETTING_GHOST_ALPHA] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_FREQ") )
                        {
                            g_eSettings[SETTING_GHOST_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_REQUIRE_EMPTY") )
                        {
                            g_eSettings[SETTING_REQUIRE_EMPTY] = bool:str_to_num(szValue)
                        }
                    }
                    case SECTION_CRATE:
                    {
                        strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                        trim(szKey)
                        trim(szValue)

                        if ( equali(szKey, "CRATE_MODEL") )
                        {
                            copy( eCrate[CRATE_MODEL], charsmax(eCrate[CRATE_MODEL]), szValue)
                            if ( !equali(g_eSettings[SETTING_DEFAULT_MODEL], szValue) && !g_bFileWasRead )
                                precache_model(szValue)
                        }
                        else if ( equali(szKey, "CRATE_CLASS") )
                        {
                            eCrate[CRATE_CLASS] = str_to_num(szValue)
                            eCrate[CRATE_CLASS] = clamp(eCrate[CRATE_CLASS], CLASS_AMMO, CLASS_MARKET)
                        }
                        else if ( equali(szKey, "CRATE_MODE") )
                        {
                            eCrate[CRATE_MODE] = str_to_num(szValue)
                            switch( eCrate[CRATE_CLASS] )
                            {
                                case CLASS_AMMO:     { eCrate[CRATE_MODE] = clamp(eCrate[CRATE_MODE], AMMO_ONLY, VESTHELM_ONLY); }
                                case CLASS_GRENADES: { eCrate[CRATE_MODE] = clamp(eCrate[CRATE_MODE], GRENADES_HE, GRENADES_ALL); }
                            }
                        }
                        else if ( equali(szKey, "CRATE_RATE") )
                        {
                            eCrate[CRATE_RATE] = str_to_num(szValue)
                            eCrate[CRATE_RATE] = clamp(eCrate[CRATE_RATE], RATE_VERYSLOW, RATE_VERYFAST)

                            switch( eCrate[CRATE_RATE] )
                            {
                                case RATE_VERYSLOW: { eCrate[CRATE_COOLDOWN] = 10.0; eCrate[CRATE_FRAMERATE] = 0.25; }
                                case RATE_SLOW:     { eCrate[CRATE_COOLDOWN] = 5.0;  eCrate[CRATE_FRAMERATE] = 0.52; }
                                case RATE_NORMAL:   { eCrate[CRATE_COOLDOWN] = 2.5;  eCrate[CRATE_FRAMERATE] = 1.0; }
                                case RATE_FAST:     { eCrate[CRATE_COOLDOWN] = 1.5;  eCrate[CRATE_FRAMERATE] = 1.52; }
                                case RATE_VERYFAST: { eCrate[CRATE_COOLDOWN] = 0.75; eCrate[CRATE_FRAMERATE] = 2.72; }
                            }
                        }
                        else if ( equali(szKey, "CRATE_CAPACITY") )
                        {
                            eCrate[CRATE_CAPACITY] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "CRATE_SOUND_FLAGS") )
                        {
                            eCrate[CRATE_SOUND_FLAGS] = read_flags(szValue)
                            eCrate[CRATE_SOUND_FLAGS] &= 63
                        }
                        else if ( equali(szKey, "CRATE_FACTOR") )
                        {
                            eCrate[CRATE_FACTOR] = str_to_float(szValue)
                        }
                    }
                }
            }
        }
    }

    if ( g_iCrateConfig )
        cratePush(eCrate)
    else
        set_fail_state("No crates were found in the configuration file.")

    g_bFileWasRead = true
    fclose(iFile)
}

public client_authorized(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    get_user_authid(id, g_ePlayerData[id][PDATA_AUTHID], charsmax(g_ePlayerData[][PDATA_AUTHID]))

    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public UpdateData(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    g_ePlayerData[id][PDATA_ADMIN_FLAGS] = get_user_flags(id)

    g_ePlayerData[id][PDATA_OFFSET]      = g_eSettings[SETTING_OFFSET_BASE]
    g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
    g_ePlayerData[id][PDATA_CRATE_MENU]  = 0
}

public crateMenu(iArg[TASK_MENU])
{
    new szTitle[64],
        id, iType, iMenu

    id    = iArg[TASK_ID]
    iType = iArg[TASK_TYPE]
    formatex( szTitle, charsmax(szTitle), "%L", id, "CRATE_MENU_TITLE")
    iMenu = menu_create(szTitle, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   menuRoot(id, iMenu)
        case MENU_CREATE: menuCreate(iMenu)
        case MENU_REMOVE: menuRemove(id, iMenu)
        case MENU_ROTATE: menuRotate(id, iMenu)
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

public menuRoot(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_SAVE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new iArg[TASK_MENU]
    iArg[TASK_ID] = id

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iCrate >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_LIMIT")
            }
            else
            {
                iArg[TASK_TYPE] = MENU_CREATE
                set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iCrate )
            {
                client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_NO_CRATE")
            }
            else
            {
                iArg[TASK_TYPE] = MENU_REMOVE
                set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(iMenu)
{
    new eCrate[CRATE],
        szItem[64]

    for ( new i = 0; i < g_iCrateConfig; i ++ )
    {
        ArrayGetArray(g_aCrateConfig, i, eCrate)

        copy(szItem, charsmax(szItem), eCrate[CRATE_NAME])
        menu_additem(iMenu, szItem)
    }
}

public menuHandlerCreate(id, menu, item)
{
    if ( item == MENU_EXIT
    || !is_user_alive(id) )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new iArg[TASK_MENU]

    iArg[TASK_ID] = id
    iArg[TASK_TYPE] = MENU_ROTATE
    set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))

    crateCreate(id, item, true)
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64],
        eCrate[CRATE], iIndex

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_DEL_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_DEL_BACK")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_DEL_REMOVE")
    menu_additem(iMenu, szItem)

    iIndex = g_ePlayerData[id][PDATA_CRATE_MENU]
    ArrayGetArray(g_aCrate, iIndex, eCrate)

    if ( pev_valid(eCrate[CRATE_ID]) )
        crateSetGlow(eCrate[CRATE_ID], true)
}

public menuHandlerRemove(id, menu, item)
{
    new iArg[TASK_MENU],
        eCrate[CRATE], iIndex

    iIndex = g_ePlayerData[id][PDATA_CRATE_MENU]
    ArrayGetArray(g_aCrate, iIndex, eCrate)

    iArg[TASK_ID] = id

    if ( pev_valid(eCrate[CRATE_ID]) )
        crateSetGlow(eCrate[CRATE_ID], false)

    switch( item )
    {
        case DEL_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] >= g_iCrate - 1 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CRATE_MENU]++

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case DEL_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = g_iCrate - 1
            else
                g_ePlayerData[id][PDATA_CRATE_MENU]--

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case DEL_REMOVE:
        {
            crateRemove(eCrate, iIndex)
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        default:
        {
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRotate(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROTATE_RIGHT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROTATE_LEFT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROTATE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRotate(id, menu, item)
{
    new iArg[TASK_MENU],
        eCrate[CRATE]

    iArg[TASK_ID] = id

    switch( item )
    {
        case ROTATE_RIGHT:
        {
            crateFind(g_ePlayerData[id][PDATA_CRATE_GHOST], eCrate)

            eCrate[CRATE_ANGLES][1] -= 90.0
            if ( eCrate[CRATE_ANGLES][1] < -180.0 ) eCrate[CRATE_ANGLES][1] += 360.0

            set_pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            crateUpdate(eCrate)

            iArg[TASK_TYPE] = MENU_ROTATE
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case ROTATE_LEFT:
        {
            crateFind(g_ePlayerData[id][PDATA_CRATE_GHOST], eCrate)

            eCrate[CRATE_ANGLES][1] += 90.0
            if ( eCrate[CRATE_ANGLES][1] > 180.0 ) eCrate[CRATE_ANGLES][1] -= 360.0

            set_pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            crateUpdate(eCrate)

            iArg[TASK_TYPE] = MENU_ROTATE
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case ROTATE_PLACE:
        {
            if ( crateTrace(id) )
            {
                crateFind(g_ePlayerData[id][PDATA_CRATE_GHOST], eCrate)
                crateSetBox(eCrate)
                crateSetSequence(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)

                pev(eCrate[CRATE_ID], pev_origin, eCrate[CRATE_ORIGIN])
                crateUpdate(eCrate)

                g_ePlayerData[id][PDATA_OFFSET]      = g_eSettings[SETTING_OFFSET_BASE]
                g_ePlayerData[id][PDATA_CRATE_GHOST] = 0

                if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_PLACED )
                    crateSetSound(eCrate[CRATE_ID], SOUND_PLACED, false)
            }
        }
        default:
        {
            crateKill(g_ePlayerData[id][PDATA_CRATE_GHOST])
            g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public crateGhost()
{
    new iPlayers[MAX_PLAYERS], iNum, id,
        iGhost

    get_players(iPlayers, iNum, "ach")
    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]
        iGhost = g_ePlayerData[id][PDATA_CRATE_GHOST]

        if ( !iGhost )
            continue

        if ( crateTrace(id) )
            set_rendering(iGhost, kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
        else
            set_rendering(iGhost, kRenderFxNone, 255, 255, 255, kRenderTransAlpha, g_eSettings[SETTING_GHOST_ALPHA])
    }
}

public crateCreate(id, iItem, bool:bPlayer)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

    if ( !pev_valid(iEnt) )
        return

    new eCrate[CRATE],
        iClass

    ArrayGetArray(g_aCrateConfig, iItem, eCrate)
    eCrate[CRATE_ID]   = iEnt
    eCrate[CRATE_ITEM] = iItem
    if ( bPlayer )
        g_ePlayerData[id][PDATA_CRATE_GHOST] = eCrate[CRATE_ID]

    iClass = eCrate[CRATE_CLASS]
    set_pev(iEnt, pev_classname, g_szCN[iClass])
    engfunc(EngFunc_SetModel, iEnt, eCrate[CRATE_MODEL])

    ArrayPushArray(g_aCrate, eCrate)
    g_iCrate++

    dllfunc(DLLFunc_Spawn, iEnt)
}

public crateRemove(eCrate[CRATE], iItem)
{
    crateKill(eCrate[CRATE_ID])

    ArrayDeleteItem(g_aCrate, iItem)
    g_iCrate--

    if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_REMOVED )
        crateSetSound(eCrate[CRATE_ID], SOUND_REMOVED, false)
}

public saveData(id)
{
    new eCrate[CRATE],
        szFile[64], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_SupplyCrate.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "item = %d^n", eCrate[CRATE_ITEM])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eCrate[CRATE_ORIGIN][0], eCrate[CRATE_ORIGIN][1], eCrate[CRATE_ORIGIN][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n^n",
        eCrate[CRATE_ANGLES][0], eCrate[CRATE_ANGLES][1], eCrate[CRATE_ANGLES][2])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_SAVED")
    fclose(iFile)

    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[64], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], iItem,
        eCrate[CRATE], iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_SupplyCrate.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
    {
        console_print(0, "%L %L", 0, "CRATE_CHAT_TAG", 0, "CRATE_CHAT_NO_DATA")
        return PLUGIN_HANDLED
    }

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
            {
                crateCreate(0, iItem, false)
                ArrayGetArray(g_aCrate, iCount, eCrate)
                crateSetBox(eCrate)
                crateSetSequence(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)

                switch( eCrate[CRATE_RATE] )
                {
                    case RATE_VERYSLOW: { eCrate[CRATE_COOLDOWN] = 10.0; eCrate[CRATE_FRAMERATE] = 0.25; }
                    case RATE_SLOW:     { eCrate[CRATE_COOLDOWN] = 5.0;  eCrate[CRATE_FRAMERATE] = 0.52; }
                    case RATE_NORMAL:   { eCrate[CRATE_COOLDOWN] = 2.5;  eCrate[CRATE_FRAMERATE] = 1.0; }
                    case RATE_FAST:     { eCrate[CRATE_COOLDOWN] = 1.5;  eCrate[CRATE_FRAMERATE] = 1.52; }
                    case RATE_VERYFAST: { eCrate[CRATE_COOLDOWN] = 0.75; eCrate[CRATE_FRAMERATE] = 2.72; }
                }

                set_pev(eCrate[CRATE_ID], pev_origin, fOrigin)
                set_pev(eCrate[CRATE_ID], pev_angles, fAngles)
                xs_vec_copy(fOrigin, eCrate[CRATE_ORIGIN])
                xs_vec_copy(fAngles, eCrate[CRATE_ANGLES])
                ArraySetArray(g_aCrate, iCount, eCrate)
            }

            iCount++
        }
        else
        {
            strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
            trim(szKey)
            trim(szValue)

            switch( szKey[0] )
            {
                case 'i':
                {
                    iItem = str_to_num(szValue)
                }
                case 'o':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[1] = str_to_float(szKey)
                    fOrigin[2] = str_to_float(szValue)
                }
                case 'a':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fAngles[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fAngles[1] = str_to_float(szKey)
                    fAngles[2] = str_to_float(szValue)
                }
            }
        }
    }

    if ( iCount != -1 )
    {
        crateCreate(0, iItem, false)
        ArrayGetArray(g_aCrate, iCount, eCrate)
        crateSetBox(eCrate)
        crateSetSequence(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)

        switch( eCrate[CRATE_RATE] )
        {
            case RATE_VERYSLOW: { eCrate[CRATE_COOLDOWN] = 10.0; eCrate[CRATE_FRAMERATE] = 0.25; }
            case RATE_SLOW:     { eCrate[CRATE_COOLDOWN] = 5.0;  eCrate[CRATE_FRAMERATE] = 0.52; }
            case RATE_NORMAL:   { eCrate[CRATE_COOLDOWN] = 2.5;  eCrate[CRATE_FRAMERATE] = 1.0; }
            case RATE_FAST:     { eCrate[CRATE_COOLDOWN] = 1.5;  eCrate[CRATE_FRAMERATE] = 1.52; }
            case RATE_VERYFAST: { eCrate[CRATE_COOLDOWN] = 0.75; eCrate[CRATE_FRAMERATE] = 2.72; }
        }

        set_pev(eCrate[CRATE_ID], pev_angles, fAngles)
        set_pev(eCrate[CRATE_ID], pev_origin, fOrigin)
        xs_vec_copy(fOrigin, eCrate[CRATE_ORIGIN])
        xs_vec_copy(fAngles, eCrate[CRATE_ANGLES])
        ArraySetArray(g_aCrate, iCount, eCrate)
    }

    fclose(iFile)
    return PLUGIN_HANDLED
}

public fwdSpawn(iEnt)
{
    if ( !isCrate(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
    set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)

    return HAM_IGNORED
}

public fwdThink(iEnt)
{
    if ( !isCrate(iEnt)
    || pev(iEnt, pev_sequence) == CRATE_SEQ_IDLE)
    {
        set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)
        return HAM_IGNORED
    }

    new eCrate[CRATE]
    crateFind(iEnt, eCrate)

    if (get_gametime() > eCrate[CRATE_NEXT_USE])
    {
        crateSetSequence(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)
        crateUpdate(eCrate)
    }

    set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)
    return HAM_IGNORED
}

public fwdUpdateClientData(id, iSendWeapons, iHandle)
{
    if ( g_ePlayerData[id][PDATA_CRATE_GHOST] )
    {
        set_cd(iHandle, CD_WeaponAnim, 0)
        set_cd(iHandle, CD_flNextAttack, get_gametime() + 0.1)
    }

    return FMRES_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    crateKill(g_ePlayerData[id][PDATA_CRATE_GHOST])
    return HAM_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    new iButton
    iButton = pev(id, pev_button)

    if ( g_ePlayerData[id][PDATA_CRATE_GHOST] )
    {
        if ( get_gametime() > g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
        }

        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }
    else
    {
        new eCrate[CRATE],
            iEnt

        iEnt = crateUse(id)

        if ( iEnt && crateFind(iEnt, eCrate) )
        {
            if ( get_gametime() > eCrate[CRATE_NEXT_USE] )
                crateSupply(id, eCrate)

            iButton &= ~IN_USE
            set_pev(id, pev_button, iButton)
        }
    }

    return HAM_IGNORED
}

public bool:crateTrace(id)
{
    new Float:fOrigin[3],
        Float:fViewAngles[3],
        Float:fViewOfs[3],
        Float:fForward[3],
        Float:fEnd[3],
        iTr, Float:fFraction

    pev(id, pev_origin, fOrigin)
    pev(id, pev_v_angle, fViewAngles)
    pev(id, pev_view_ofs, fViewOfs)
    xs_vec_add(fOrigin , fViewOfs, fOrigin)

    engfunc(EngFunc_AngleVectors, fViewAngles, fForward, NULL_VECTOR, NULL_VECTOR)
    xs_vec_mul_scalar(fForward, g_ePlayerData[id][PDATA_OFFSET], fEnd)
    xs_vec_add(fEnd, fOrigin, fEnd)

    engfunc(EngFunc_TraceLine, fOrigin, fEnd, IGNORE_MONSTERS, id, iTr)
    get_tr2(iTr, TR_flFraction, fFraction)
    get_tr2(iTr, TR_vecEndPos, fOrigin)

    crateSetGround(fOrigin)
    crateSetOffset(fOrigin)

    set_pev(g_ePlayerData[id][PDATA_CRATE_GHOST], pev_origin, fOrigin)

    return crateRadius(fOrigin)
}

public crateUse(id)
{
    if ( !(pev(id, pev_button) & IN_USE) )
        return 0

    new Float:fOrigin[3],
        Float:fViewAngles[3],
        Float:fViewOfs[3],
        Float:fForward[3],
        Float:fEnd[3],
        iTr, iEnt = -1

    pev(id, pev_origin, fOrigin)
    pev(id, pev_v_angle, fViewAngles)
    pev(id, pev_view_ofs, fViewOfs)
    xs_vec_add(fOrigin ,fViewOfs, fOrigin)

    engfunc(EngFunc_AngleVectors, fViewAngles, fForward, NULL_VECTOR, NULL_VECTOR)
    xs_vec_mul_scalar(fForward, g_eSettings[SETTING_CRATE_RANGE], fEnd)
    xs_vec_add(fEnd, fOrigin, fEnd)

    engfunc(EngFunc_TraceLine, fOrigin, fEnd, IGNORE_MONSTERS, id, iTr)
    get_tr2(iTr, TR_vecEndPos, fEnd)

    while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fEnd, 30.0)) )
    {
        if ( !pev_valid(iEnt) )
            continue

        if ( isCrate(iEnt) )
            return iEnt
    }

    return 0
}

public crateSupply(id, eCrate[CRATE])
{
    if ( eCrate[CRATE_CAPACITY] > 0 )
    {
        switch( eCrate[CRATE_CLASS] )
        {
            case CLASS_AMMO:     crateSupplyAmmo(id, eCrate)
            case CLASS_GRENADES: crateSupplyGrenades(id, eCrate)
            case CLASS_MARKET:   crateSupplyMarket(id, eCrate)
        }
    }
    else
    {
        if ( get_gametime() > eCrate[CRATE_NEXT_SOUND]
        && eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_EMPTY )
        {
            eCrate[CRATE_NEXT_SOUND] = get_gametime() + 1.0
            crateSetSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
            crateUpdate(eCrate)
        }
    }
}

crateSupplyAmmo(id, eCrate[CRATE])
{
    new iWeapon, iClip, iAmmo
    iWeapon = cs_get_user_weapon(id, iClip, iAmmo)

    if ( isGun(iWeapon)
    && (!g_eSettings[SETTING_REQUIRE_EMPTY] || !isAmmoFull(iWeapon, iAmmo)) )
    {
        switch( eCrate[CRATE_MODE] )
        {
            case AMMO_ONLY:     { cs_set_user_bpammo(id, iWeapon, g_iWeaponMaxBP[iWeapon]); ammoPickup(id, g_iWeaponMaxBP[iWeapon] - iAmmo); }
            case AMMO_VEST:     { cs_set_user_bpammo(id, iWeapon, g_iWeaponMaxBP[iWeapon]); cs_set_user_armor(id, 100, CS_ARMOR_KEVLAR); ammoPickup(id, g_iWeaponMaxBP[iWeapon] - iAmmo); }
            case AMMO_VESTHELM: { cs_set_user_bpammo(id, iWeapon, g_iWeaponMaxBP[iWeapon]); cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM); ammoPickup(id, g_iWeaponMaxBP[iWeapon] - iAmmo); }
            case VEST_ONLY:     { cs_set_user_armor(id, 100, CS_ARMOR_KEVLAR); }
            case VESTHELM_ONLY: { cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM); }
        }

        eCrate[CRATE_CAPACITY] -= 1
        eCrate[CRATE_NEXT_USE] = get_gametime() + eCrate[CRATE_COOLDOWN]
        crateSetSequence(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])

        if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_GET )
            crateSetSound(eCrate[CRATE_ID], SOUND_GET, false)

        if (!iClip)
            client_cmd(id, "+attack; wait; -attack;")
    }
    else
    {
        if ( get_gametime() > eCrate[CRATE_NEXT_SOUND]
        && eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_EMPTY )
        {
            eCrate[CRATE_NEXT_SOUND] = get_gametime() + 1.0
            crateSetSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
        }
    }
    crateUpdate(eCrate)
}

crateSupplyGrenades(id, eCrate[CRATE])
{
    if ( !g_eSettings[SETTING_REQUIRE_EMPTY] || !hasGrenades(id) )
    {
        switch( eCrate[CRATE_MODE] )
        {
            case GRENADES_HE:    { give_item(id, "weapon_hegrenade"); }
            case GRENADES_FB:    { give_item(id, "weapon_flashbang"); give_item(id, "weapon_flashbang"); }
            case GRENADES_SG:    { give_item(id, "weapon_smokegrenade"); }
            case GRENADES_HE_FB: { give_item(id, "weapon_hegrenade"); give_item(id, "weapon_flashbang"); give_item(id, "weapon_flashbang"); }
            case GRENADES_HE_SG: { give_item(id, "weapon_hegrenade"); give_item(id, "weapon_smokegrenade"); }
            case GRENADES_FB_SG: { give_item(id, "weapon_flashbang"); give_item(id, "weapon_flashbang"); give_item(id, "weapon_smokegrenade"); }
            case GRENADES_ALL:   { give_item(id, "weapon_hegrenade"); give_item(id, "weapon_flashbang"); give_item(id, "weapon_flashbang"); give_item(id, "weapon_smokegrenade"); }
        }

        eCrate[CRATE_CAPACITY] -= 1
        eCrate[CRATE_NEXT_USE] = get_gametime() + eCrate[CRATE_COOLDOWN]
        crateSetSequence(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])

        if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_GET )
            crateSetSound(eCrate[CRATE_ID], SOUND_GET, false)
    }
    else
    {
        if ( get_gametime() > eCrate[CRATE_NEXT_SOUND]
        && eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_EMPTY )
        {
            eCrate[CRATE_NEXT_SOUND] = get_gametime() + 1.0
            crateSetSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
        }
    }

    crateUpdate(eCrate)
}

crateSupplyMarket(id, eCrate[CRATE])
{
    new iWeapon
    iWeapon = get_user_weapon(id)

    if ( canSell(iWeapon) )
    {
        crateSell(id, iWeapon, eCrate)
        eCrate[CRATE_CAPACITY] -= 1
        eCrate[CRATE_NEXT_USE] = get_gametime() + eCrate[CRATE_COOLDOWN]
        crateSetSequence(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])

        if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_SELL )
            crateSetSound(eCrate[CRATE_ID], SOUND_SELL, false)
    }
    else
    {
        if ( get_gametime() > eCrate[CRATE_NEXT_SOUND]
        && eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_EMPTY )
        {
            eCrate[CRATE_NEXT_SOUND] = get_gametime() + 1.0
            crateSetSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
        }
    }

    crateUpdate(eCrate)
}

stock crateSetGround(Float:fStart[3])
{
    new Float:fEnd[3],
        iTr

    xs_vec_sub(fStart, Float:{ 0.0, 0.0, 9999.9 }, fEnd)

    engfunc(EngFunc_TraceLine, fStart, fEnd, IGNORE_MONSTERS, 0, iTr)
    get_tr2(iTr, TR_vecEndPos, fStart)
}

stock crateSetOffset(Float:fStart[3])
{
    new Float:fEnd[3],
        Float:fNormal[3],
        Float:fCurrentDiff,
        iTr

    for ( new i = 0; i < 6; i ++ )
    {
        xs_vec_mul_scalar(g_fDirections[i], 9999.9, fEnd)

        engfunc(EngFunc_TraceLine, fStart, fEnd, IGNORE_MONSTERS, 0, iTr)
        get_tr2(iTr, TR_vecEndPos, fEnd)

        fCurrentDiff = xs_vec_distance(fStart, fEnd)

        if ( fCurrentDiff < 18.0 )
        {
            get_tr2(iTr, TR_vecPlaneNormal, fNormal)
            xs_vec_mul_scalar(fNormal, 18.0 - fCurrentDiff, fEnd)
            xs_vec_add(fStart, fEnd, fStart)
        }
    }
}

stock crateSetBox(eCrate[CRATE])
{
    new Float:fMins[3],
        Float:fMaxs[3]

    set_pev(eCrate[CRATE_ID], pev_solid, SOLID_BBOX)
    set_pev(eCrate[CRATE_ID], pev_movetype, MOVETYPE_FLY)

    switch( eCrate[CRATE_ANGLES][1] )
    {
        case 0.0, 180.0, -180.0 : { xs_vec_copy(g_eSettings[SETTING_MINS_LONG], fMins); xs_vec_copy(g_eSettings[SETTING_MAXS_LONG], fMaxs); }
        case 90.0, -90.0 :        { xs_vec_copy(g_eSettings[SETTING_MINS_WIDE], fMins); xs_vec_copy(g_eSettings[SETTING_MAXS_WIDE], fMaxs); }
    }

    engfunc(EngFunc_SetSize, eCrate[CRATE_ID], fMins, fMaxs)
    set_rendering(eCrate[CRATE_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

stock crateSetSequence(iEnt, iSequence, Float:fFrameRate)
{
    set_pev(iEnt, pev_sequence, iSequence)
    set_pev(iEnt, pev_frame, 0.0)
    set_pev(iEnt, pev_framerate, fFrameRate)
    set_pev(iEnt, pev_animtime, get_gametime())
}

stock crateSetGlow(iEnt, bool:bGlow)
{
    if ( bGlow ) set_rendering(iEnt, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 52)
    else         set_rendering(iEnt, kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

stock crateSetSound(iEnt, iSound, bool:bPlayer)
{
    new szSample[64]

    switch( iSound )
    {
        case SOUND_PLACED:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_PLACED])
        case SOUND_REMOVED: copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_REMOVED])
        case SOUND_OPENING: copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_OPENING])
        case SOUND_EMPTY:   copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_EMPTY])
        case SOUND_GET:     copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_GET])
        case SOUND_SELL:    copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_SELL])
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, CHAN_ITEM, szSample, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

stock bool:crateRadius(Float:fOrigin[3])
{
    new iEnt = -1

    while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, 20.0)) )
    {
        if ( !pev_valid(iEnt)
        || pev(iEnt, pev_solid) <= SOLID_TRIGGER
        || (pev(iEnt, pev_solid) == SOLID_BSP && pev(iEnt, pev_takedamage) == DAMAGE_NO) )
            continue

        return false
    }

    return true
}

stock crateSell(id, iWeapon, eCrate[CRATE])
{
    new iMoney,
        iActiveWeapon

    iMoney = cs_get_user_money(id)
    iMoney += floatround(g_iWeaponMarket[iWeapon] * eCrate[CRATE_FACTOR])

    iActiveWeapon = get_pdata_cbase(id, MEMBER_ACTIVE_WEAPON)

    ExecuteHam(Ham_Weapon_RetireWeapon, iActiveWeapon)
    ExecuteHam(Ham_RemovePlayerItem, id, iActiveWeapon)
    user_has_weapon(id, iWeapon, 0)
    ExecuteHam(Ham_Item_Kill, iActiveWeapon)

    cs_set_user_money(id, iMoney, 1)
}

stock ammoPickup(id, iAmount)
{
    new iActiveWeapon,
        iAmmoType

    iActiveWeapon = get_pdata_cbase(id, MEMBER_ACTIVE_WEAPON)
    iAmmoType = get_pdata_int(iActiveWeapon, MEMBER_AMMO_TYPE)

    message_begin(MSG_ONE_UNRELIABLE, g_iAmmoPickup, .player = id)
    write_byte(iAmmoType)
    write_byte(iAmount)
    message_end()
}

stock bool:isCrate(iEnt)
{
    new szEnt[32]
    pev(iEnt, pev_classname, szEnt, charsmax(szEnt))

    for ( new i = 0; i < sizeof(g_szCN); i ++ )
    {
        if ( equali(szEnt, g_szCN[i]) )
            return true
    }

    return false
}

stock isGun(iWeapon)
{
    return (1 << iWeapon) & CSW_ALL_GUNS
}

stock bool:isAmmoFull(iWeapon, iAmmo)
{
    return g_iWeaponMaxBP[iWeapon] <= iAmmo
}

stock bool:hasGrenades(id)
{
    new iWeapons[32],
        iNum

    get_user_weapons(id, iWeapons, iNum)

    for ( new i = 0; i < iNum; i ++ )
    {
        if ( (1 << iWeapons[i]) & CSW_ALL_GRENADES )
            return true
    }
    return false
}

stock canSell(iWeapon)
{
    return iWeapon != CSW_KNIFE
}

stock cratePush(eCrate[CRATE])
{
    if ( !eCrate[CRATE_MODEL] )    copy(eCrate[CRATE_MODEL], charsmax(eCrate[CRATE_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
    if ( !eCrate[CRATE_CAPACITY] ) eCrate[CRATE_CAPACITY] = g_eSettings[SETTING_DEFAULT_CAPACITY]

    ArrayPushArray(g_aCrateConfig, eCrate)
}

stock crateUpdate(eCrate[CRATE])
{
    new iItem
    iItem = crateGetItem(eCrate)

    if ( iItem != -1 )
        ArraySetArray(g_aCrate, iItem, eCrate)
}

stock crateKill(iEnt)
{
    if ( pev_valid(iEnt) )
        set_pev(iEnt, pev_flags, FL_KILLME)
}

stock crateFind(iEnt, eCrate[CRATE])
{
    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        if ( eCrate[CRATE_ID] == iEnt )
            return true
    }

    return false
}

stock crateGetItem(eCrate[CRATE])
{
    new eTemp[CRATE]
    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eTemp)
        if ( eCrate[CRATE_ID] == eTemp[CRATE_ID] )
            return i
    }

    return -1
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}



