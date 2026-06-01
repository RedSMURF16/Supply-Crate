/*
*
*	Supply Crate by RedSMURF
*
*
*	Description:
*       This plugin adds a menu from where you can choose different crate types, it got "Ammo Crates" for supplying ammunition, "Grenades Crates" for supplying grenades, and Market Crates for selling items.
*       All crates are fully customizable with settings like Capacity, Mode, Cooldown, etc..
*       Players can interact with crates by pressing E (IN_USE) while being in the distance range set in g_eSetting[SETTING_CRATE_RANGE]
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
*       sc_reload                   "Reloads the configuration file."
*       supplycrate_reload          "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*       v2.0: Major rework with performance improvements and new mechanics,
*             Improved crate placement logic for natural alignment with ground and walls,
*             Crates might refill after a certain duration,
*             Added activation delay after round start,
*             Crates can break or explode from damage,
*             CRATE_FACTOR is used with AMMO CRATES to scale the supplied ammo.
*       v2.1: Added team-restricted crates (T, CT, Both or Disabled),
*             Added respawn chance machanics for destroyed crates,
*             Improved rendering logic
*       v2.2: Switched CRATE_MODE to Bitflags for cleaner multi-option support
*             CRATE_FACTOR is now used by grenades crates for scaling
*             Added CRATE_FACTOR_MAX for ammo crates to control maximum supply
*       v2.3: Added weapon interaction list for crates,
*             Precached busting metal sounds and gibs for maps that do not support them
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

#define MAX_ENT             32
#define MEMBER_AMMO_TYPE    49
#define TASK_ACTION         8421
#define BREAK_FLAG_METAL    2
#define CRATE_KEY           8421
#define CRATE_ARRAY_ITEM    pev_iuser1

/**
 *  Crate animation sequences.
 */
#define CRATE_SEQ_IDLE          0
#define CRATE_SEQ_OPENCLOSE     1

/**
 *  Crate Bitflag Armor.
 */
#define CRATE_FLAG_VEST         (1 << 0)
#define CRATE_FLAG_VESTHELM     (1 << 1)

/**
 *  Crate Bitflag Ammo.
 */
#define CRATE_FLAG_AMMO         (1 << 2)

/**
 *  Crate Bitflag Grenades.
 */
#define CRATE_FLAG_HE           (1 << 2)
#define CRATE_FLAG_FB1          (1 << 3)
#define CRATE_FLAG_FB2          (1 << 4)
#define CRATE_FLAG_SMOKE        (1 << 5)

new const PLUGIN_VERSION[]          = "2.3"
new const Float:DELAY_ON_CONNECT    = 1.0
new const ERROR_FILE[]              = "SupplyCrate_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_CRATE
}

enum
{
    FLAG_BREAK          = (1 << 0),
    FLAG_EXPLODE        = (1 << 1),
    FLAG_SOUND          = (1 << 2),

    FLAG_SHOW           = (1 << 3),
    FLAG_DEAD           = (1 << 4),
    FLAG_GHOST          = (1 << 5),
    FLAG_VALID          = (1 << 6),
    FLAG_SELECT         = (1 << 7)
}

enum
{
    TEAM_NONE,
    TEAM_T,
    TEAM_CT,
    TEAM_BOTH
}

enum
{
    SPAWN_NEVER,
    SPAWN_DELAY,
    SPAWN_ROUND_START
}

enum
{
    WEAPON_ALL,
    WEAPON_ONLY,
    WEAPON_EXCEPT
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_GIB[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_CLASS,
    SETTING_DEFAULT_FLAGS,
    SETTING_DEFAULT_TEAM,
    SETTING_DEFAULT_SOUND,
    SETTING_DEFAULT_MODE,
    SETTING_DEFAULT_SPAWN_MODE,
    Float:SETTING_DEFAULT_SPAWN[2],
    Float:SETTING_DEFAULT_SPAWN_CHANCE,
    Float:SETTING_DEFAULT_DELAY,
    Float:SETTING_DEFAULT_CAPACITY,
    Float:SETTING_DEFAULT_CAPACITY_MAX,
    Float:SETTING_DEFAULT_REFILL,
    Float:SETTING_DEFAULT_HEALTH,
    Float:SETTING_DEFAULT_EXPLODE_DAMAGE,
    Float:SETTING_DEFAULT_EXPLODE_RADIUS,
    Float:SETTING_MINS[3],
    Float:SETTING_MAXS[3],

    bool:SETTING_CRATE_LOAD,
    bool:SETTING_CRATE_ACTION,
    Float:SETTING_CRATE_RANGE,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET[2],
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    Float:SETTING_GHOST_FREQ,
    SETTING_GHOST_ALPHA,

    Float:SETTING_BREAK_VELO_Z[2],
    SETTING_BREAK_VELO_RANDOM[2],
    SETTING_BREAK_COUNT[2],
    SETTING_BREAK_LIFE[2],

    SETTING_SPRITE_ZEROGXPLODE,
    Array:SETTING_SOUND_METAL,
    SETTING_SOUND_PLACE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_EMPTY[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_REMOVE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_SUPPLY[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_SELL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_REFILL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_NAV[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_REMOVE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_ALERT[MAX_RESOURCE_PATH_LENGTH],

    SETTING_COLOR_ACTIVE[3],
    SETTING_COLOR_INACTIVE[3]
}

enum _:CRATE
{
    CRATE_ID,
    CRATE_ITEM,
    CRATE_STATE,
    CRATE_FLAGS,
    CRATE_NAME[MAX_VALUE_LENGTH],
    CRATE_MODEL[MAX_RESOURCE_PATH_LENGTH],
    CRATE_CLASS,
    CRATE_TEAM,
    CRATE_MODE,
    CRATE_FLAGS,
    CRATE_OCCUPIED,
    Float:CRATE_ORIGIN[3],
    Float:CRATE_ANGLES[3],
    Float:CRATE_DECAL[3],
    Float:CRATE_MINS[3],
    Float:CRATE_MAXS[3],
    Float:CRATE_COOLDOWN,
    Float:CRATE_CAPACITY,
    Float:CRATE_CAPACITY_MAX,
    Float:CRATE_FRAMERATE,
    Float:CRATE_REFILL,
    Float:CRATE_DELAY,
    Float:CRATE_HEALTH,
    CRATE_ARMOR,
    Float:CRATE_FACTOR,
    Float:CRATE_FACTOR_MAX,
    Float:CRATE_SPAWN_CHANCE,
    Float:CRATE_EXPLODE_DAMAGE,
    Float:CRATE_EXPLODE_RADIUS,
    Float:CRATE_NEXT_USE,
    Float:CRATE_NEXT_EMPTY,
    Float:CRATE_NEXT_REFILL,

    CRATE_WEAPON_MODE,
    bool:CRATE_WEAPON_LIST[31]
}

enum _:PLAYER_DATA
{
    PDATA_NAME[MAX_VALUE_LENGTH],
    PDATA_AUTHID[MAX_AUTHID_LENGTH],
    PDATA_ADMIN_FLAGS,
    PDATA_CRATE_GHOST,
    PDATA_CRATE_MENU,
    bool:PDATA_CRATE_ACTION,
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
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT,

    SOUND_PLACE,
    SOUND_EMPTY,
    SOUND_REMOVE,
    SOUND_SUPPLY,
    SOUND_SELL,
    SOUND_REFILL
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_REMOVE,
    MENU_SHOW,
    MENU_TEAM,
    MENU_SPAWN,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 4,
    ROOT_GODMODE,

    ROOT_SHOW = 7,
    ROOT_TEAM,
    ROOT_SPAWN
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    SHOW_NEXT,
    SHOW_BACK,

    SHOW_CURRENT = 3,
    SHOW_ALL_HIDE,
    SHOW_ALL_SHOW,
    SHOW_ALL_DEFAULT
}

enum
{
    TEAM_NEXT,
    TEAM_BACK,

    TEAM_CURRENT = 3,
    TEAM_ALL_NONE,
    TEAM_ALL_T,
    TEAM_ALL_CT,
    TEAM_ALL_BOTH
}

enum
{
    SPAWN_NEXT,
    SPAWN_BACK,

    SPAWN_CURRENT = 3,
    SPAWN_ALL_NEVER,
    SPAWN_ALL_DELAY,
    SPAWN_ALL_ROUND_START
}

enum
{
    ROTATE_RIGHT,
    ROTATE_LEFT,
    ROTATE_PLACE
}

new Float:g_fDirections[][] =
{
    {-1.0, 0.0, 0.0},
    {1.0, 0.0, 0.0},
    {0.0, -1.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, -1.0},
    {0.0, 0.0, 1.0}
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

new g_szMenuHandler[][] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerRemove",
    "menuHandlerShow",
    "menuHandlerTeam",
    "menuHandlerSpawn",
    "menuHandlerRotate"
}

new g_szCN[][32] =
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
    g_iAmmoPickup,
    g_iMaxPlayers

public plugin_init()
{
    register_plugin("Supply Crate", PLUGIN_VERSION, "RedSMURF")

    register_clcmd("say /sc",               "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /sc",          "cmdMenu", ADMIN_RCON)
    register_clcmd("say /supplycrate",      "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /supplycrate", "cmdMenu", ADMIN_RCON)
    register_concmd("sc_reload",            "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")
    register_concmd("supplycrate_reload",   "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")

    register_dictionary("SupplyCrate.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    register_forward(FM_AddToFullPack, "fwdAddToFullPack", 1)
    RegisterHam(Ham_Spawn, "info_target", "fwdSpawn", 1)
    RegisterHam(Ham_TakeDamage, "info_target", "fwdTakeDamage", 0)
    RegisterHam(Ham_TraceAttack, "info_target", "fwdTraceAttack", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink", 0)
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_event("HLTV", "eventHLTV", "a", "1=0", "2=0")
    register_logevent("eventRoundStart", 2, "1=Round_Start")

    g_iAmmoPickup = get_user_msgid("AmmoPickup")

    if ( g_eSettings[SETTING_CRATE_ACTION] )
        set_task(g_eSettings[SETTING_GHOST_FREQ], "crateTask", .flags = "b")

    crateInit()
    g_iMaxPlayers = get_maxplayers(s)
}

public plugin_precache()
{
    g_aCrate       = ArrayCreate(CRATE)
    g_aCrateConfig = ArrayCreate(CRATE)

    precache_model("models/metalplategibs.mdl")
    precache_sound("debris/metal1.wav")
    precache_sound("debris/metal2.wav")
    precache_sound("debris/metal3.wav")
    precache_sound("debris/bustmetal1.wav")
    precache_sound("debris/bustmetal2.wav")

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aCrate)
    ArrayDestroy(g_aCrateConfig)
}

public plugin_cfg()
{
    if ( !g_iCrate )
        return PLUGIN_CONTINUE

    new eCrate[CRATE]
    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        eCrate[CRATE_FLAGS] |= FLAG_SPAWN

        ArraySetArray(g_aCrate, i, eCrate)
        crateKill(eCrate[CRATE_ID])
    }

    return PLUGIN_CONTINUE
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    crateSound(id, SOUND_MENU_NAV)
    crateMenu(id, MENU_ROOT)

    return PLUGIN_HANDLED
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1)
    || !is_user_alive(id) )
        return PLUGIN_HANDLED

    if ( !g_eSettings[SETTING_CRATE_ACTION] )
    {
        client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_NO_ACTION")
        return PLUGIN_HANDLED
    }

    crateSound(id, SOUND_MENU_NAV)
    crateMenu(id, MENU_ROOT)

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

public eventHLTV()
{
    if ( !g_iCrate )
        return PLUGIN_CONTINUE

    new eCrate[CRATE]
    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)

        if ( eCrate[CRATE_FLAGS] & FLAG_DUMMY )
        {
            if ( eCrate[CRATE_SPAWN_CHANCE] >= random_float(0.0, 1.0) )
                eCrate[CRATE_FLAGS] |= FLAG_SPAWN
        }
        else
        {
            eCrate[CRATE_FLAGS] |= FLAG_SPAWN
        }

        ArraySetArray(g_aCrate, i, eCrate)
        crateKill(eCrate[CRATE_ID])
    }

    return PLUGIN_CONTINUE
}

public eventRoundStart()
{
    if ( !g_iCrate )
        return PLUGIN_HANDLED

    new eCrateOld[CRATE], eCrateNew[CRATE],
        iCrate

    iCrate = g_iCrate
    for ( new i = 0; i < iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrateOld)

        if ( eCrateOld[CRATE_FLAGS] & FLAG_SPAWN )
        {
            crateCreate(0, eCrateOld[CRATE_ITEM])
            ArrayGetArray(g_aCrate, g_iCrate - 1, eCrateNew)

            xs_vec_copy(eCrateOld[CRATE_ORIGIN], eCrateNew[CRATE_ORIGIN])
            xs_vec_copy(eCrateOld[CRATE_ANGLES], eCrateNew[CRATE_ANGLES])
            xs_vec_copy(eCrateOld[CRATE_DECAL], eCrateNew[CRATE_DECAL])
            set_pev(eCrateNew[CRATE_ID], pev_origin, eCrateNew[CRATE_ORIGIN])
            set_pev(eCrateNew[CRATE_ID], pev_angles, eCrateNew[CRATE_ANGLES])
            eCrateNew[CRATE_STATE] = STATE_ACTIVE

            crateSetBox(eCrateNew)
            crateSetAnim(eCrateNew)
            crateSetActive(eCrateNew)
            ArraySetArray(g_aCrate, g_iCrate - 1, eCrateNew)
        }
        else
        {
            crateDummy(eCrateOld, i)
        }
    }

    for ( new i = 0; i < iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, 0, eCrateOld)

        if ( eCrateOld[CRATE_FLAGS] & FLAG_SPAWN )
            crateRemove(0)
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
        eCrate[CRATE], iSection = SECTION_NONE, iLine, iWeapon

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
                            ArrayPushArray(g_aCrateConfig, eCrate)

                        copy(eCrate[CRATE_NAME], charsmax(eCrate[CRATE_NAME]), szData)
                        copy(eCrate[CRATE_MODEL], charsmax(eCrate[CRATE_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
                        eCrate[CRATE_CLASS]          = CLASS_AMMO
                        eCrate[CRATE_TEAM]           = TEAM_BOTH
                        eCrate[CRATE_MODE]           = CRATE_FLAG_VEST
                        eCrate[CRATE_COOLDOWN]       = 2.5
                        eCrate[CRATE_CAPACITY]       = 10.0
                        eCrate[CRATE_FRAMERATE]      = 1.0
                        eCrate[CRATE_REFILL]         = -1.0
                        eCrate[CRATE_DELAY]          = 0.0
                        eCrate[CRATE_HEALTH]         = 250.0
                        eCrate[CRATE_ARMOR]          = 100
                        eCrate[CRATE_FACTOR]         = 1.0
                        eCrate[CRATE_FACTOR_MAX]     = 1.0
                        eCrate[CRATE_SPAWN_CHANCE]   = 1.0
                        eCrate[CRATE_EXPLODE_DAMAGE] = 100.0
                        eCrate[CRATE_EXPLODE_RADIUS] = 150.0

                        eCrate[CRATE_WEAPON_MODE]    = WEAPON_ALL
                        for ( new i = 1; i <= CSW_P90; i ++ )
                            eCrate[CRATE_WEAPON_LIST][i] = false

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
                        else if ( equali(szKey, "SETTING_DEFAULT_GIB") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_DEFAULT_GIB] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_CLASS") )
                        {
                            g_eSettings[SETTING_DEFAULT_CLASS] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                        {
                            g_eSettings[SETTING_DEFAULT_FLAGS] = read_flags(szValue)
                            g_eSettings[SETTING_DEFAULT_FLAGS] &= 7
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_TEAM") )
                        {
                            g_eSettings[SETTING_DEFAULT_TEAM] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND") )
                        {
                            g_eSettings[SETTING_DEFAULT_SOUND] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_MODE") )
                        {
                            g_eSettings[SETTING_DEFAULT_MODE] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN_MODE") )
                        {
                            g_eSettings[SETTING_DEFAULT_SPAWN_MODE] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_DEFAULT_SPAWN][0] = str_to_float(szKey)
                            g_eSettings[SETTING_DEFAULT_SPAWN][1] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN_CHANCE") )
                        {
                            g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_DELAY") )
                        {
                            g_eSettings[SETTING_DEFAULT_DELAY] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_CAPACITY") )
                        {
                            g_eSettings[SETTING_DEFAULT_CAPACITY] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_CAPACITY_MAX") )
                        {
                            g_eSettings[SETTING_DEFAULT_CAPACITY_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_REFILL") )
                        {
                            g_eSettings[SETTING_DEFAULT_REFILL] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_HEALTH") )
                        {
                            g_eSettings[SETTING_DEFAULT_HEALTH] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_EXPLODE_DAMAGE") )
                        {
                            g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_EXPLODE_RADIUS") )
                        {
                            g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_MINS") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MINS][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_MAXS") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MAXS][2] = str_to_float(szValue)
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
                        else if ( equali(szKey, "SETTING_OFFSET") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_OFFSET][0] = str_to_float(szKey)
                            g_eSettings[SETTING_OFFSET][0] = str_to_float(szValue)
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
                        else if ( equali(szKey, "SETTING_BREAK_VELO_Z") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_BREAK_VELO_Z][0] = str_to_float(szKey)
                            g_eSettings[SETTING_BREAK_VELO_Z][1] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BREAK_VELO_RANDOM") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_BREAK_VELO_RANDOM][0] = str_to_num(szKey)
                            g_eSettings[SETTING_BREAK_VELO_RANDOM][1] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BREAK_COUNT") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_BREAK_COUNT][0] = str_to_num(szKey)
                            g_eSettings[SETTING_BREAK_COUNT][1] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BREAK_LIFE") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_BREAK_LIFE][0] = str_to_num(szKey)
                            g_eSettings[SETTING_BREAK_LIFE][1] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SPRITE_ZEROGXPLODE") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_SPRITE_ZEROGXPLODE] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_FREQ") )
                        {
                            g_eSettings[SETTING_GHOST_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_PLACE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_PLACE], charsmax(g_eSettings[SETTING_SOUND_PLACE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_PLACE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_EMPTY") )
                        {
                            copy(g_eSettings[SETTING_SOUND_EMPTY], charsmax(g_eSettings[SETTING_SOUND_EMPTY]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_EMPTY])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_REMOVE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_REMOVE], charsmax(g_eSettings[SETTING_SOUND_REMOVE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_REMOVE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_SUPPLY") )
                        {
                            copy(g_eSettings[SETTING_SOUND_SUPPLY], charsmax(g_eSettings[SETTING_SOUND_SUPPLY]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_SUPPLY])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_SELL") )
                        {
                            copy(g_eSettings[SETTING_SOUND_SELL], charsmax(g_eSettings[SETTING_SOUND_SELL]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_SELL])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_REFILL") )
                        {
                            copy(g_eSettings[SETTING_SOUND_REFILL], charsmax(g_eSettings[SETTING_SOUND_REFILL]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_REFILL])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_NAV") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_NAV], charsmax(g_eSettings[SETTING_SOUND_MENU_NAV]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_REMOVE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_REMOVE], charsmax(g_eSettings[SETTING_SOUND_MENU_REMOVE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_COLOR_ACTIVE") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_ACTIVE][0] = str_to_num(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_ACTIVE][1] = str_to_num(szKey)
                            g_eSettings[SETTING_COLOR_ACTIVE][2] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_COLOR_INACTIVE") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_INACTIVE][0] = str_to_num(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_INACTIVE][1] = str_to_num(szKey)
                            g_eSettings[SETTING_COLOR_INACTIVE][2] = str_to_num(szValue)
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
                        else if ( equali(szKey, "CRATE_TEAM") )
                        {
                            eCrate[CRATE_TEAM] = str_to_num(szValue)
                            eCrate[CRATE_TEAM] = clamp(eCrate[CRATE_TEAM], TEAM_NONE, TEAM_BOTH)
                        }
                        else if ( equali(szKey, "CRATE_MODE") )
                        {
                            eCrate[CRATE_MODE] = read_flags(szValue)
                            eCrate[CRATE_MODE] &= 63
                        }
                        else if ( equali(szKey, "CRATE_FLAGS") )
                        {
                            eCrate[CRATE_FLAGS] = read_flags(szValue)
                            eCrate[CRATE_FLAGS] &= 7
                        }
                        else if ( equali(szKey, "CRATE_COOLDOWN") )
                        {
                            eCrate[CRATE_COOLDOWN] = str_to_float(szValue)
                            eCrate[CRATE_COOLDOWN] = floatclamp(eCrate[CRATE_COOLDOWN], 0.5, 40.0)
                            eCrate[CRATE_FRAMERATE] = (2.15 + (eCrate[CRATE_COOLDOWN] - 0.5) / (40.0 - 0.5) * (3.25 - 2.15)) / eCrate[CRATE_COOLDOWN]
                        }
                        else if ( equali(szKey, "CRATE_CAPACITY") )
                        {
                            eCrate[CRATE_CAPACITY] = str_to_float(szValue)
                            if ( eCrate[CRATE_CAPACITY] < 0.0 ) eCrate[CRATE_CAPACITY] = 10.0

                            eCrate[CRATE_CAPACITY_MAX] = eCrate[CRATE_CAPACITY]
                        }
                        else if ( equali(szKey, "CRATE_REFILL") )
                        {
                            eCrate[CRATE_REFILL] = str_to_float(szValue)
                            if ( eCrate[CRATE_REFILL] < 0.0 && eCrate[CRATE_REFILL] != -1.0 ) eCrate[CRATE_REFILL] = -1.0
                        }
                        else if ( equali(szKey, "CRATE_DELAY") )
                        {
                            eCrate[CRATE_DELAY] = str_to_float(szValue)
                            if ( eCrate[CRATE_DELAY] < 0.0 ) eCrate[CRATE_DELAY] = 0.0
                        }
                        else if ( equali(szKey, "CRATE_HEALTH") )
                        {
                            eCrate[CRATE_HEALTH] = str_to_float(szValue)
                            if ( eCrate[CRATE_HEALTH] < 0.0 ) eCrate[CRATE_HEALTH] = 250.0
                        }
                        else if ( equali(szKey, "CRATE_ARMOR") )
                        {
                            eCrate[CRATE_ARMOR] = str_to_num(szValue)
                            if ( eCrate[CRATE_ARMOR] < 0 ) eCrate[CRATE_ARMOR] = 100
                        }
                        else if ( equali(szKey, "CRATE_FACTOR") )
                        {
                            eCrate[CRATE_FACTOR] = str_to_float(szValue)
                            if ( eCrate[CRATE_FACTOR] < 0.0 ) eCrate[CRATE_FACTOR] = 0.0
                        }
                        else if ( equali(szKey, "CRATE_FACTOR_MAX") )
                        {
                            eCrate[CRATE_FACTOR_MAX] = str_to_float(szValue)
                            if ( eCrate[CRATE_FACTOR_MAX] < eCrate[CRATE_FACTOR] ) eCrate[CRATE_FACTOR_MAX] = eCrate[CRATE_FACTOR]
                        }
                        else if ( equali(szKey, "CRATE_SPAWN_CHANCE") )
                        {
                            eCrate[CRATE_SPAWN_CHANCE] = str_to_float(szValue)
                            eCrate[CRATE_SPAWN_CHANCE] = floatclamp(eCrate[CRATE_SPAWN_CHANCE], 0.0, 1.0)
                        }
                        else if ( equali(szKey, "CRATE_EXPLODE_DAMAGE") )
                        {
                            eCrate[CRATE_EXPLODE_DAMAGE] = str_to_float(szValue)
                            if ( eCrate[CRATE_EXPLODE_DAMAGE] < 0.0 ) eCrate[CRATE_EXPLODE_DAMAGE] = 100.0
                        }
                        else if ( equali(szKey, "CRATE_EXPLODE_RADIUS") )
                        {
                            eCrate[CRATE_EXPLODE_RADIUS] = str_to_float(szValue)
                            if ( eCrate[CRATE_EXPLODE_RADIUS] < 0.0 ) eCrate[CRATE_EXPLODE_RADIUS] = 150.0
                        }
                        else if ( equali(szKey, "CRATE_WEAPON_MODE") )
                        {
                            eCrate[CRATE_WEAPON_MODE] = str_to_num(szValue)
                            eCrate[CRATE_WEAPON_MODE] = clamp(eCrate[CRATE_WEAPON_MODE], WEAPON_ALL, WEAPON_EXCEPT)
                        }
                        else if ( equali(szKey, "CRATE_WEAPON_LIST") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ',')
                            trim(szKey)
                            trim(szValue)

                            while( szKey[0] )
                            {
                                iWeapon = str_to_num(szKey)

                                if ( iWeapon >= 1
                                && iWeapon <= 30 )
                                    eCrate[CRATE_WEAPON_LIST][iWeapon] = true

                                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ',')
                                trim(szKey)
                            }
                        }
                    }
                }
            }
        }
    }

    if ( g_iCrateConfig )
        ArrayPushArray(g_aCrateConfig, eCrate)
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
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
}

public crateInit()
{
    if ( g_eSettings[SETTING_CRATE_LOAD] )
        loadData()
}

public crateMenu(id, iType)
{
    new szTitle[64],
        iMenu

    formatex(szTitle, charsmax(szTitle), "%L", id, "CRATE_MENU_TITLE")
    iMenu = menu_create(szTitle, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   { menuRoot(id, iMenu); }
        case MENU_CREATE: { menuCreate(iMenu);      format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CRATE_ROOT_CREATE"); }
        case MENU_TOGGLE: { menuToggle(id, iMenu);  format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CRATE_ROOT_TOGGLE"); }
        case MENU_REMOVE: { menuRemove(id, iMenu);  format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CRATE_ROOT_REMOVE"); }
        case MENU_ROTATE: { menuRotate(id, iMenu);  format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CRATE_ROOT_ROTATE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CRATE_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szTitle)
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

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_TOGGLE")
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

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iCrate >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_LIMIT", MAX_ENT)
            }
            else
            {
                crateSound(id, SOUND_MENU_NAV)
                crateMenu(id, MENU_CREATE)
            }
        }
        case ROOT_TOGGLE:
        {
            if ( !g_iCrate )
            {
                client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_NO_CRATE")
            }
            else
            {
                crateSound(id, SOUND_MENU_NAV)
                crateMenu(id, MENU_TOGGLE)
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
                crateSound(id, SOUND_MENU_REMOVE)
                crateMenu(id, MENU_REMOVE)
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

    crateCreate(id, item)
    crateSound(id, SOUND_MENU_NAV)
    crateMenu(id, MENU_ROTATE)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuToggle(id, iMenu)
{
    new szItem[64],
        eCrate[CRATE]

    ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_NAV_BACK")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_TOGGLE_CURRENT",
    eCrate[CRATE_STATE] == STATE_ACTIVE ? "\y" : "\r", eCrate[CRATE_NAME], id,
    eCrate[CRATE_STATE] == STATE_ACTIVE ? "CRATE_ON" : "CRATE_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_TOGGLE_ALL_ON")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_TOGGLE_ALL_OFF")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CRATE_ACTION] = true
    eCrate[CRATE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
}

public menuHandlerToggle(id, menu, item)
{
    new eCrate[CRATE]

    ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
    eCrate[CRATE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

    switch( item )
    {
        case TOGGLE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] >= g_iCrate - 1 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CRATE_MENU] ++

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_TOGGLE)
        }
        case TOGGLE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = g_iCrate - 1
            else
                g_ePlayerData[id][PDATA_CRATE_MENU] --

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_TOGGLE)
        }
        case TOGGLE_CURRENT:
        {
            eCrate[CRATE_STATE] = eCrate[CRATE_STATE] == STATE_ACTIVE ? STATE_INACTIVE : STATE_ACTIVE

            client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_TOGGLE_CURRENT",
            eCrate[CRATE_NAME], id, eCrate[CRATE_STATE] == STATE_ACTIVE ? "CRATE_CHAT_ACTIVATED" : "CRATE_CHAT_DEACTIVATED")
            ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_TOGGLE)
        }
        case TOGGLE_ALL_ON:
        {
            for ( new i = 0; i < g_iCrate; i ++ )
            {
                ArrayGetArray(g_aCrate, i, eCrate)
                eCrate[CRATE_STATE] = STATE_ACTIVE

                ArraySetArray(g_aCrate, i, eCrate)
            }

            client_print_color(0, 0, "%L %L", 0, "CRATE_CHAT_TAG", 0, "CRATE_CHAT_TOGGLE_ALL_ON")

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_TOGGLE)
        }
        case TOGGLE_ALL_OFF:
        {
            for ( new i = 0; i < g_iCrate; i ++ )
            {
                ArrayGetArray(g_aCrate, i, eCrate)
                eCrate[CRATE_STATE] = STATE_INACTIVE

                ArraySetArray(g_aCrate, i, eCrate)
            }

            client_print_color(0, 0, "%L %L", 0, "CRATE_CHAT_TAG", 0, "CRATE_CHAT_TOGGLE_ALL_OFF")

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_TOGGLE)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            g_ePlayerData[id][PDATA_CRATE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64],
        eCrate[CRATE]

    ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_NAV_BACK")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_REMOVE_CURRENT", eCrate[CRATE_NAME])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CRATE_ACTION] = true
    eCrate[CRATE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
}

public menuHandlerRemove(id, menu, item)
{
    new eCrate[CRATE]

    ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
    eCrate[CRATE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] >= g_iCrate - 1 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CRATE_MENU] ++

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_REMOVE)
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = g_iCrate - 1
            else
                g_ePlayerData[id][PDATA_CRATE_MENU] --

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_REMOVE)
        }
        case REMOVE_CURRENT:
        {
            crateKill(eCrate[CRATE_ID])
            crateRemove(g_ePlayerData[id][PDATA_CRATE_MENU])

            client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_REMOVE_CURRENT",
            eCrate[CRATE_NAME])
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0

            crateSound(id, g_iCrate > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            crateMenu(id, g_iCrate > 0 ? MENU_REMOVE : MENU_ROOT)
        }
        case REMOVE_ALL:
        {
            while( g_iCrate )
            {
                ArrayGetArray(g_aCrate, 0, eCrate)

                crateKill(eCrate[CRATE_ID])
                crateRemove(0)
            }

            client_print_color(0, 0, "%L %L", 0, "CRATE_CHAT_TAG", 0, "CRATE_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_ROOT)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            g_ePlayerData[id][PDATA_CRATE_ACTION] = false
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
    new eCrate[CRATE],
        iItem

    iItem = crateFind(g_ePlayerData[id][PDATA_CRATE_GHOST], eCrate)

    switch( item )
    {
        case ROTATE_RIGHT:
        {
            pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            eCrate[CRATE_ANGLES][1] -= 22.5
            if ( eCrate[CRATE_ANGLES][1] < -180.0 ) eCrate[CRATE_ANGLES][1] += 360.0

            set_pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            ArraySetArray(g_aCrate, iItem, eCrate)

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_ROTATE)
        }
        case ROTATE_LEFT:
        {
            pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            eCrate[CRATE_ANGLES][1] += 22.5
            if ( eCrate[CRATE_ANGLES][1] > 180.0 ) eCrate[CRATE_ANGLES][1] -= 360.0

            set_pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            ArraySetArray(g_aCrate, iItem, eCrate)

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_ROTATE)
        }
        case ROTATE_PLACE:
        {
            if ( crateTrace(eCrate, id) && iItem != -1 )
            {
                g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
                g_ePlayerData[id][PDATA_CRATE_ACTION] = false

                pev(eCrate[CRATE_ID], pev_origin, eCrate[CRATE_ORIGIN])
                pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
                eCrate[CRATE_NEXT_USE] = get_gametime() + 0.25
                eCrate[CRATE_STATE] = STATE_ACTIVE

                crateSetAnim(eCrate)
                crateSetActive(eCrate)
                ArraySetArray(g_aCrate, iItem, eCrate)

                client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_CREATE_NEW", eCrate[CRATE_NAME])
                crateSound(id, SOUND_MENU_NAV)
                crateMenu(id, MENU_ROOT)
            }
            else
            {
                crateSound(id, SOUND_MENU_NAV)
                crateMenu(id, MENU_ROTATE)
            }
        }
        default:
        {
            crateKill(eCrate[CRATE_ID])
            crateRemove(iItem)
            g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
            g_ePlayerData[id][PDATA_CRATE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public crateTask()
{
    new iPlayers[MAX_PLAYERS], iNum, id,
        eCrate[CRATE], iItem, iEnt

    get_players(iPlayers, iNum, "ach")
    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]
        iEnt = g_ePlayerData[id][PDATA_CRATE_GHOST]
        if ( !iEnt || (iItem = crateFind(iEnt, eCrate)) == -1 )
            continue

        if ( crateTrace(eCrate, id) ) eCrate[CRATE_STATE] = STATE_VALID
        else                          eCrate[CRATE_STATE] = STATE_INVALID

        ArraySetArray(g_aCrate, iItem, eCrate)
    }

    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        if ( eCrate[CRATE_STATE] != STATE_ACTIVE && eCrate[CRATE_STATE] != STATE_INACTIVE )
            continue

        if ( eCrate[CRATE_NEXT_REFILL]
        && get_gametime() >= eCrate[CRATE_NEXT_REFILL] )
        {
            eCrate[CRATE_CAPACITY] = eCrate[CRATE_CAPACITY_MAX]
            eCrate[CRATE_NEXT_REFILL] = 0.0
            eCrate[CRATE_NEXT_USE] = get_gametime() + 0.1

            if ( eCrate[CRATE_FLAGS] & FLAG_SOUND )
                crateSound(eCrate[CRATE_ID], SOUND_REFILL, false)
        }
        else if ( eCrate[CRATE_OCCUPIED]
        && get_gametime() >= eCrate[CRATE_NEXT_USE] )
        {
            eCrate[CRATE_OCCUPIED] = 0
            eCrate[CRATE_NEXT_USE] = 0.0
            crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)
        }

        ArraySetArray(g_aCrate, i, eCrate)
    }
}

stock crateDummy(eCrate[CRATE], iItem)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

    if ( !pev_valid(iEnt) )
        return

    set_pev(iEnt, pev_classname, g_szCN[eCrate[CRATE_CLASS]])
    set_pev(iEnt, pev_origin, eCrate[CRATE_ORIGIN])
    set_pev(iEnt, pev_angles, eCrate[CRATE_ANGLES])

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_NONE)
    set_pev(iEnt, pev_takedamage, DAMAGE_NO)
    engfunc(EngFunc_SetModel, iEnt, eCrate[CRATE_MODEL])

    eCrate[CRATE_ID] = iEnt
    ArraySetArray(g_aCrate, iItem, eCrate)

    dllfunc(DLLFunc_Spawn, iEnt)
}

stock crateCreate(id, iItem)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

    if ( !pev_valid(iEnt) )
        return

    new eCrate[CRATE]
    ArrayGetArray(g_aCrateConfig, iItem, eCrate)

    DispatchKeyValue(iEnt, "material", MATERIAL_METAL)
    eCrate[CRATE_ID] = iEnt
    eCrate[CRATE_ITEM] = iItem
    if ( id )
    {
        g_ePlayerData[id][PDATA_CRATE_GHOST] = eCrate[CRATE_ID]
        g_ePlayerData[id][PDATA_CRATE_ACTION] = true
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
    }

    set_pev(iEnt, pev_classname, g_szCN[eCrate[CRATE_CLASS]])
    engfunc(EngFunc_SetModel, iEnt, eCrate[CRATE_MODEL])

    ArrayPushArray(g_aCrate, eCrate)
    g_iCrate ++

    dllfunc(DLLFunc_Spawn, iEnt)
}

stock crateRemove(iItem)
{
    ArrayDeleteItem(g_aCrate, iItem)
    g_iCrate --
}

stock saveData(id)
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

        formatex(szData, charsmax(szData), "decal = %.2f %.2f %.2f^n^n",
        eCrate[CRATE_DECAL][0], eCrate[CRATE_DECAL][1], eCrate[CRATE_DECAL][2])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_SAVE", szFile)
    fclose(iFile)

    return PLUGIN_HANDLED
}

stock loadData()
{
    new szFile[64], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], Float:fDecal[3], iItem,
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
                crateCreate(0, iItem)
                ArrayGetArray(g_aCrate, iCount, eCrate)

                xs_vec_copy(fOrigin, eCrate[CRATE_ORIGIN])
                xs_vec_copy(fAngles, eCrate[CRATE_ANGLES])
                xs_vec_copy(fDecal, eCrate[CRATE_DECAL])
                set_pev(eCrate[CRATE_ID], pev_origin, fOrigin)
                set_pev(eCrate[CRATE_ID], pev_angles, fAngles)
                eCrate[CRATE_STATE] = STATE_ACTIVE
                eCrate[CRATE_FRAMERATE] = (2.0 + (eCrate[CRATE_COOLDOWN] - 0.5) / (40.0 - 0.5) * (3.2 - 2.0)) / eCrate[CRATE_COOLDOWN]

                crateSetBox(eCrate)
                crateSetAnim(eCrate, false)
                crateSetActive(eCrate)
                ArraySetArray(g_aCrate, iCount, eCrate)
            }

            iCount ++
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
                case 'd':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fDecal[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fDecal[1] = str_to_float(szKey)
                    fDecal[2] = str_to_float(szValue)
                }
            }
        }
    }

    if ( iCount != -1 )
    {
        crateCreate(0, iItem)
        ArrayGetArray(g_aCrate, iCount, eCrate)

        xs_vec_copy(fOrigin, eCrate[CRATE_ORIGIN])
        xs_vec_copy(fAngles, eCrate[CRATE_ANGLES])
        xs_vec_copy(fDecal, eCrate[CRATE_DECAL])
        set_pev(eCrate[CRATE_ID], pev_origin, fOrigin)
        set_pev(eCrate[CRATE_ID], pev_angles, fAngles)
        eCrate[CRATE_STATE] = STATE_ACTIVE
        eCrate[CRATE_FRAMERATE] = (2.0 + (eCrate[CRATE_COOLDOWN] - 0.5) / (40.0 - 0.5) * (3.2 - 2.0)) / eCrate[CRATE_COOLDOWN]

        crateSetBox(eCrate)
        crateSetAnim(eCrate, false)
        crateSetActive(eCrate)
        ArraySetArray(g_aCrate, iCount, eCrate)
    }

    fclose(iFile)
    return PLUGIN_HANDLED
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

public fwdAddToFullPack(es, e, iEnt, iHost, iHostFlags, iPlayer, pSet)
{
    if ( !pev_valid(iEnt)
    || !isCrate(iEnt)
    || !get_orig_retval() )
        return FMRES_IGNORED

    new eCrate[CRATE]
    crateFind(iEnt, eCrate)

    if ( !g_ePlayerData[iHost][PDATA_CRATE_ACTION] )
    {
        if ( eCrate[CRATE_FLAGS] & FLAG_DUMMY
        || (eCrate[CRATE_STATE] != STATE_ACTIVE && eCrate[CRATE_STATE] != STATE_INACTIVE) )
            set_es(es, ES_Effects, EF_NODRAW)
    }
    else if ( eCrate[CRATE_FLAGS] & FLAG_SELECT )
    {
        set_es(es, ES_RenderMode, kRenderTransAlpha)
        set_es(es, ES_RenderAmt, 32)

        switch( eCrate[CRATE_STATE] )
        {
            case STATE_ACTIVE:   set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_ACTIVE])
            case STATE_INACTIVE: set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_INACTIVE])
        }

        set_es(es, ES_RenderFx, kRenderFxGlowShell)
    }
    else if ( eCrate[CRATE_STATE] == STATE_INVALID
    || eCrate[CRATE_FLAGS] & FLAG_DUMMY )
    {
        set_es(es, ES_RenderMode, kRenderTransAlpha)
        set_es(es, ES_RenderAmt, g_eSettings[SETTING_GHOST_ALPHA])
    }

    return FMRES_IGNORED
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

public fwdTakeDamage(iEnt, iInflictor, iAttacker, Float:fDamage, iDamageBits)
{
    if ( !isCrate(iEnt) )
        return HAM_IGNORED

    new eCrate[CRATE], iItem,
        Float:fHealth

    iItem = crateFind(iEnt, eCrate)
    pev(iEnt, pev_health, fHealth)

    if ( !(eCrate[CRATE_FLAGS] & FLAG_BREAK) )
    {
        SetHamParamFloat(4, 0.0)
    }
    else if ( fDamage >= fHealth
    && iItem != -1
    && !(eCrate[CRATE_FLAGS] & FLAG_DUMMY) )
    {
        eCrate[CRATE_FLAGS] |= FLAG_DUMMY
        crateKill(eCrate[CRATE_ID])
        crateDummy(eCrate, iItem)

        if ( eCrate[CRATE_FLAGS] & FLAG_EXPLODE )
            crateExplode(eCrate)
    }

    return HAM_IGNORED
}

public fwdTraceAttack(iEnt, iAttacker, Float:fDamage, Float:fDirection[3], iTr, iDamageBits)
{
    if ( !isCrate(iEnt) )
        return HAM_IGNORED

    new Float:fEnd[3]
    get_tr2(iTr, TR_vecEndPos, fEnd)

    crateEmitParticles(fEnd)
    crateEmitSparks(fEnd)

    return HAM_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    static eCrate[CRATE], iItem,
    iEnt, iButton

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
        if ( (iEnt = crateUse(id))
        && (iItem = crateFind(iEnt, eCrate)) != -1
        && (eCrate[CRATE_STATE] == STATE_ACTIVE || eCrate[CRATE_STATE] == STATE_INACTIVE) )
        {
            if ( get_gametime() >= eCrate[CRATE_NEXT_USE]
            && (!eCrate[CRATE_OCCUPIED] || eCrate[CRATE_OCCUPIED] == id) )
                crateSupply(id, eCrate, iItem)

            iButton &= ~IN_USE
            set_pev(id, pev_button, iButton)
        }
    }

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    if ( g_ePlayerData[id][PDATA_CRATE_GHOST] )
    {
        new eCrate[CRATE], iItem

        if ( (iItem = crateFind(g_ePlayerData[id][PDATA_CRATE_GHOST], eCrate)) != -1 )
        {
            crateKill(g_ePlayerData[id][PDATA_CRATE_GHOST])
            crateRemove(iItem)
            g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
        }
    }

    return HAM_IGNORED
}

stock bool:crateTrace(eCrate[CRATE], id)
{
    new Float:fVec1[3]

    pev(id, pev_origin, eCrate[CRATE_ORIGIN])
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(eCrate[CRATE_ORIGIN], fVec1, eCrate[CRATE_ORIGIN])

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec1)
    xs_vec_add(fVec1, eCrate[CRATE_ORIGIN], fVec1)

    engfunc(EngFunc_TraceLine, eCrate[CRATE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, eCrate[CRATE_ORIGIN])

    crateSetBox(eCrate)
    crateSetOffset(eCrate)
    set_pev(eCrate[CRATE_ID], pev_origin, eCrate[CRATE_ORIGIN])

    return crateRadius(eCrate)
}

stock crateUse(id)
{
    if ( !(pev(id, pev_button) & IN_USE) )
        return 0

    new Float:fOrigin[3], Float:fVec1[3],
        iEnt = -1

    pev(id, pev_origin, fOrigin)
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(fOrigin, fVec1, fOrigin)

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_eSettings[SETTING_CRATE_RANGE], fVec1)
    xs_vec_add(fVec1, fOrigin, fVec1)

    engfunc(EngFunc_TraceLine, fOrigin, fVec1, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, fOrigin)

    while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, 5.0)) )
    {
        if ( !pev_valid(iEnt)
        || !isCrate(iEnt) )
            continue

        return iEnt
    }

    return 0
}

stock bool:crateAllow(id, eCrate[CRATE])
{
    new iWeaponID
    iWeaponID = cs_get_user_weapon(id)

    if ( iWeaponID == CSW_KNIFE || iWeaponID == CSW_C4 )    return false
    else if ( eCrate[CRATE_WEAPON_MODE] == WEAPON_ONLY )    return eCrate[CRATE_WEAPON_LIST][iWeaponID]
    else if ( eCrate[CRATE_WEAPON_MODE] == WEAPON_EXCEPT )  return !eCrate[CRATE_WEAPON_LIST][iWeaponID]

    return true
}

stock crateSupply(id, eCrate[CRATE], iItem)
{
    if ( eCrate[CRATE_CAPACITY] > 0
    && eCrate[CRATE_STATE] == STATE_ACTIVE
    && (CsTeams:eCrate[CRATE_TEAM] & cs_get_user_team(id))
    && crateAllow(id, eCrate) )
    {
        switch( eCrate[CRATE_CLASS] )
        {
            case CLASS_AMMO:     supplyAmmo(id, eCrate)
            case CLASS_GRENADES: supplyGrenades(id, eCrate)
            case CLASS_MARKET:   supplyMarket(id, eCrate)
        }

        if ( !eCrate[CRATE_CAPACITY] )
        {
            eCrate[CRATE_NEXT_EMPTY] = get_gametime() + 1.0

            if ( eCrate[CRATE_REFILL] != -1 )
                eCrate[CRATE_NEXT_REFILL] = get_gametime() + eCrate[CRATE_REFILL]
        }
    }
    else if ( get_gametime() >= eCrate[CRATE_NEXT_EMPTY]
    && eCrate[CRATE_FLAGS] & FLAG_SOUND )
    {
        eCrate[CRATE_NEXT_EMPTY] = get_gametime() + 1.0
        crateSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
    }

    ArraySetArray(g_aCrate, iItem, eCrate)
}

supplyAmmo(id, eCrate[CRATE])
{
    new iWeapon, iClip, iAmmo, iBoost
    iWeapon = cs_get_user_weapon(id, iClip, iAmmo)

    if ( (1 << iWeapon) & CSW_ALL_GUNS
    && iAmmo < floatround(eCrate[CRATE_FACTOR_MAX] * g_iWeaponMaxBP[iWeapon]) )
    {
        if ( eCrate[CRATE_MODE] & CRATE_FLAG_AMMO )
        {
            iBoost = floatround(g_iWeaponMaxBP[iWeapon] * eCrate[CRATE_FACTOR])
            iBoost = min(iBoost, floatround(eCrate[CRATE_FACTOR_MAX] * g_iWeaponMaxBP[iWeapon]) - iAmmo)

            cs_set_user_bpammo(id, iWeapon, iAmmo + iBoost)
            ammoPickup(id, iBoost)
        }

        if ( eCrate[CRATE_MODE] & CRATE_FLAG_VEST )     cs_set_user_armor(id, eCrate[CRATE_ARMOR], CS_ARMOR_KEVLAR)
        if ( eCrate[CRATE_MODE] & CRATE_FLAG_VESTHELM ) cs_set_user_armor(id, eCrate[CRATE_ARMOR], CS_ARMOR_VESTHELM)

        eCrate[CRATE_CAPACITY] -= 1.0
        eCrate[CRATE_OCCUPIED] = id
        eCrate[CRATE_NEXT_USE] = get_gametime() + eCrate[CRATE_COOLDOWN]
        crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])

        if ( !iClip )
            client_cmd(id, "+attack; wait; -attack;")

        if ( eCrate[CRATE_FLAGS] & FLAG_SOUND )
            crateSound(id, SOUND_SUPPLY)
    }
    else if ( get_gametime() >= eCrate[CRATE_NEXT_EMPTY]
    && eCrate[CRATE_FLAGS] & FLAG_SOUND )
    {
        eCrate[CRATE_NEXT_EMPTY] = get_gametime() + 1.0
        crateSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
    }
}

supplyGrenades(id, eCrate[CRATE])
{
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_HE )       grenadeAdd(id, CSW_HEGRENADE, "weapon_hegrenade", eCrate[CRATE_FACTOR])
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_FB1 )      grenadeAdd(id, CSW_FLASHBANG, "weapon_flashbang", eCrate[CRATE_FACTOR])
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_FB2 )      grenadeAdd(id, CSW_FLASHBANG, "weapon_flashbang", eCrate[CRATE_FACTOR])
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_SMOKE )    grenadeAdd(id, CSW_SMOKEGRENADE, "weapon_smokegrenade", eCrate[CRATE_FACTOR])
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_VEST )     cs_set_user_armor(id, eCrate[CRATE_ARMOR], CS_ARMOR_KEVLAR)
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_VESTHELM ) cs_set_user_armor(id, eCrate[CRATE_ARMOR], CS_ARMOR_VESTHELM)

    eCrate[CRATE_CAPACITY] -= 1.0
    eCrate[CRATE_OCCUPIED] = id
    eCrate[CRATE_NEXT_USE] = get_gametime() + eCrate[CRATE_COOLDOWN]
    crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])

    if ( eCrate[CRATE_FLAGS] & FLAG_SOUND )
        crateSound(id, SOUND_SUPPLY)
}

supplyMarket(id, eCrate[CRATE])
{
    new iWeapon
    iWeapon = cs_get_user_weapon(id)

    if ( iWeapon != CSW_KNIFE && iWeapon != CSW_C4 )
    {
        marketSell(id, iWeapon, eCrate)

        eCrate[CRATE_CAPACITY] -= 1.0
        eCrate[CRATE_OCCUPIED] = id
        eCrate[CRATE_NEXT_USE] = get_gametime() + eCrate[CRATE_COOLDOWN]
        crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])

        if ( eCrate[CRATE_FLAGS] & FLAG_SOUND )
            crateSound(id, SOUND_SELL)
    }
    else if ( get_gametime() >= eCrate[CRATE_NEXT_EMPTY]
    && eCrate[CRATE_FLAGS] & FLAG_SOUND )
    {
        eCrate[CRATE_NEXT_EMPTY] = get_gametime() + 1.0
        crateSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
    }
}

stock crateSetBox(eCrate[CRATE])
{
    new Float:fMins[3], Float:fMaxs[3],
        Float:fForward[3], Float:fRight[3], Float:fUp[3],
        Float:fCorners[8][3]

    engfunc(EngFunc_AngleVectors, eCrate[CRATE_ANGLES], fForward, fRight, fUp)
    xs_vec_copy(g_eSettings[SETTING_MINS], fMins)
    xs_vec_copy(g_eSettings[SETTING_MAXS], fMaxs)

    for ( new i = 0; i < 8; i ++ )
    {
        fCorners[i][0] = (i & 1) ? fMaxs[0] : fMins[0]
        fCorners[i][1] = (i & 2) ? fMaxs[1] : fMins[1]
        fCorners[i][2] = (i & 4) ? fMaxs[2] : fMins[2]

        boxRotate(fCorners[i], fForward, fRight, fUp)
    }

    xs_vec_copy(fCorners[0], fMins)
    xs_vec_copy(fCorners[0], fMaxs)
    for ( new i = 1; i < 8; i ++ )
    {
        fMins[0] = floatmin(fMins[0], fCorners[i][0])
        fMins[1] = floatmin(fMins[1], fCorners[i][1])
        fMins[2] = floatmin(fMins[2], fCorners[i][2])

        fMaxs[0] = floatmax(fMaxs[0], fCorners[i][0])
        fMaxs[1] = floatmax(fMaxs[1], fCorners[i][1])
        fMaxs[2] = floatmax(fMaxs[2], fCorners[i][2])
    }

    xs_vec_copy(fMins, eCrate[CRATE_MINS])
    xs_vec_copy(fMaxs, eCrate[CRATE_MAXS])
}

stock boxRotate(Float:fLocal[3], Float:fForward[3], Float:fRight[3], Float:fUp[3])
{
    new Float:fOut[3]
    fOut[0] = fLocal[0] * fForward[0] + fLocal[1] * fRight[0] + fLocal[2] * fUp[0]
    fOut[1] = fLocal[0] * fForward[1] + fLocal[1] * fRight[1] + fLocal[2] * fUp[1]
    fOut[2] = fLocal[0] * fForward[2] + fLocal[1] * fRight[2] + fLocal[2] * fUp[2]

    xs_vec_copy(fOut, fLocal)
}

stock crateSetOffset(eCrate[CRATE])
{
    new Float:fGaps[6], Float:fVec1[3],
        Float:fCurrentGap

    fGaps[0] = -eCrate[CRATE_MINS][0]
    fGaps[1] = eCrate[CRATE_MAXS][0]
    fGaps[2] = -eCrate[CRATE_MINS][1]
    fGaps[3] = eCrate[CRATE_MAXS][1]
    fGaps[4] = -eCrate[CRATE_MINS][2]
    fGaps[5] = eCrate[CRATE_MAXS][2]

    xs_vec_sub(eCrate[CRATE_ORIGIN], Float:{0.0, 0.0, 9999.9}, fVec1)
    engfunc(EngFunc_TraceLine, eCrate[CRATE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eCrate[CRATE_ID], 0)
    get_tr2(0, TR_vecEndPos, eCrate[CRATE_ORIGIN])
    xs_vec_copy(eCrate[CRATE_ORIGIN], eCrate[CRATE_DECAL])

    for ( new i = 0; i < 6; i ++ )
    {
        xs_vec_mul_scalar(g_fDirections[i], 9999.9, fVec1)
        xs_vec_add(fVec1, eCrate[CRATE_ORIGIN], fVec1)
        engfunc(EngFunc_TraceLine, eCrate[CRATE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eCrate[CRATE_ID], 0)
        get_tr2(0, TR_vecEndPos, fVec1)
        fCurrentGap = xs_vec_distance(eCrate[CRATE_ORIGIN], fVec1)

        if ( fCurrentGap < fGaps[i] )
        {
            get_tr2(0, TR_vecPlaneNormal, fVec1)
            xs_vec_mul_scalar(fVec1, fGaps[i] - fCurrentGap, fVec1)
            xs_vec_add(eCrate[CRATE_ORIGIN], fVec1, eCrate[CRATE_ORIGIN])
        }
    }
}

stock crateSetAnim(eCrate[CRATE], bool:bPlaySound = true)
{
    if ( eCrate[CRATE_CAPACITY] > 0.0 )
    {
        if ( eCrate[CRATE_DELAY] > 0.0 )
        {
            eCrate[CRATE_CAPACITY] = 0.0
            eCrate[CRATE_NEXT_REFILL] = get_gametime() + eCrate[CRATE_DELAY]

            if ( bPlaySound && (eCrate[CRATE_FLAGS] & FLAG_SOUND) )
                crateSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
        }
        else
        {
            if ( bPlaySound && (eCrate[CRATE_FLAGS] & FLAG_SOUND) )
                crateSound(eCrate[CRATE_ID], SOUND_PLACE, false)
        }
    }
    else
    {
        if ( bPlaySound && (eCrate[CRATE_FLAGS] & FLAG_SOUND) )
            crateSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
    }
}

stock crateSetActive(eCrate[CRATE])
{
    new Float:fMins[3],
        Float:fMaxs[3]

    set_pev(eCrate[CRATE_ID], pev_solid, SOLID_BBOX)
    set_pev(eCrate[CRATE_ID], pev_movetype, MOVETYPE_NONE)
    set_pev(eCrate[CRATE_ID], pev_takedamage, DAMAGE_AIM)
    set_pev(eCrate[CRATE_ID], pev_health, eCrate[CRATE_HEALTH])

    xs_vec_copy(eCrate[CRATE_MINS], fMins)
    xs_vec_copy(eCrate[CRATE_MAXS], fMaxs)
    engfunc(EngFunc_SetSize, eCrate[CRATE_ID], fMins, fMaxs)
    set_rendering(eCrate[CRATE_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

stock crateSetSeq(iEnt, iSequence, Float:fFrameRate)
{
    set_pev(iEnt, pev_sequence, iSequence)
    set_pev(iEnt, pev_frame, 0.0)
    set_pev(iEnt, pev_framerate, fFrameRate)
    set_pev(iEnt, pev_animtime, get_gametime())
}

stock crateSound(iEnt, iSound, iChan = CHAN_ITEM, bool:bPlayer = true, iFlags = 0)
{
    new szSample[64]

    switch( iSound )
    {
        case SOUND_MENU_NAV:        copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_NAV])
        case SOUND_MENU_REMOVE:     copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_REMOVE])
        case SOUND_MENU_ALERT:      copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_ALERT])
        case SOUND_PLACE:           copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_PLACE])
        case SOUND_EMPTY:           copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_EMPTY])
        case SOUND_REMOVE:          copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_REMOVE])
        case SOUND_SUPPLY:          copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_SUPPLY])
        case SOUND_SELL:            copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_SELL])
        case SOUND_REFILL:          copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_REFILL])
        case SOUND_METAL:           ArrayGetString(g_eSettings[SETTING_SOUND_METAL],    random(ArraySize(g_eSettings[SETTING_SOUND_METAL])),    szSample, charsmax(szSample))
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, iChan, szSample, VOL_NORM, ATTN_NORM, iFlags, PITCH_NORM)
}

stock bool:crateRadius(eCrate[CRATE])
{
    new iEnt = -1

    while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, eCrate[CRATE_ORIGIN], 15.0)) )
    {
        if ( pev_valid(iEnt)
        && iEnt != eCrate[CRATE_ID]
        && (isCrate(iEnt) || pev(iEnt, pev_solid) >= SOLID_BBOX) )
            return false
    }

    return true
}

stock crateEmitParticles(Float:fOrigin[3])
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fOrigin)
    write_byte(TE_GUNSHOTDECAL)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    write_short(0)
    write_byte(random_num(41, 45))
    message_end()
}

stock crateEmitSparks(Float:fOrigin[3])
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fOrigin)
    write_byte(TE_SPARKS)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    message_end()
}

stock crateExplode(eCrate[CRATE])
{
    new Float:fOrigin[3]
    xs_vec_copy(eCrate[CRATE_ORIGIN], fOrigin)

    explodeFireBall(eCrate, fOrigin)
    explodeDamage(eCrate, fOrigin)
}

stock explodeFireBall(eCrate[CRATE], Float:fOrigin[3])
{
    new iExplosion
    iExplosion = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_explosion"))

    if ( !pev_valid(iExplosion) )
        return;

    new iSpawnFlags,
        szRadius[16], Float:fRadius

    iSpawnFlags = SF_ENVEXPLOSION_NODAMAGE | SF_ENVEXPLOSION_NODECAL
    fRadius = eCrate[CRATE_EXPLODE_RADIUS] / 2.5
    fRadius = floatclamp(fRadius, 10.0, 150.0)
    formatex(szRadius, charsmax(szRadius), "%.2f", fRadius)
    DispatchKeyValue(iExplosion, "iMagnitude", szRadius)

    set_pev(iExplosion, pev_origin, fOrigin)
    set_pev(iExplosion, pev_spawnflags, iSpawnFlags)
    xs_vec_copy(eCrate[CRATE_DECAL], fOrigin)

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_WORLDDECAL)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    write_byte(random_num(46, 48))
    message_end()

    dllfunc(DLLFunc_Spawn, iExplosion)
    dllfunc(DLLFunc_Use, iExplosion, iExplosion)
}

stock explodeDamage(eCrate[CRATE], Float:fOrigin[3])
{
    new Float:fDistance, Float:fRatio, Float:fDamage,
        Float:fVec1[3], Float:fVec2[3], iEnt = -1

    while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, eCrate[CRATE_EXPLODE_RADIUS])) )
    {
        if ( !pev_valid(iEnt)
        || pev(iEnt, pev_takedamage) == DAMAGE_NO
        || iEnt == eCrate[CRATE_ID] )
            continue

        pev(iEnt, pev_absmin, fVec1)
        pev(iEnt, pev_absmax, fVec2)
        xs_vec_add(fVec1, fVec2, fVec1)
        xs_vec_mul_scalar(fVec1, 0.5, fVec1)

        fDistance = xs_vec_distance(fOrigin, fVec1)
        if ( fDistance > eCrate[CRATE_EXPLODE_RADIUS] )
            continue

        fRatio = 1.0 - fDistance / eCrate[CRATE_EXPLODE_RADIUS]
        fDamage = eCrate[CRATE_EXPLODE_DAMAGE] * fRatio

        ExecuteHam(Ham_TakeDamage, iEnt, eCrate[CRATE_ID], eCrate[CRATE_ID], fDamage, DMG_GRENADE)
    }
}

stock ammoPickup(id, iAmount)
{
    new iActiveWeapon,
        iAmmoType

    iActiveWeapon = cs_get_user_weapon_entity(id)
    iAmmoType = get_pdata_int(iActiveWeapon, MEMBER_AMMO_TYPE)

    message_begin(MSG_ONE_UNRELIABLE, g_iAmmoPickup, .player = id)
    write_byte(iAmmoType)
    write_byte(iAmount)
    message_end()
}

stock bool:hasGrenades(id)
{
    return (cs_get_user_bpammo(id, CSW_HEGRENADE) > 0
    || cs_get_user_bpammo(id, CSW_FLASHBANG) > 0
    || cs_get_user_bpammo(id, CSW_SMOKEGRENADE) > 0)
}

stock marketSell(id, iWeapon, eCrate[CRATE])
{
    new iMoney,
        iActiveWeapon,
        iBpAmmo,
        bool:bShouldKill = true

    iMoney = cs_get_user_money(id)
    iMoney += floatround(g_iWeaponMarket[iWeapon] * eCrate[CRATE_FACTOR])
    iActiveWeapon = cs_get_user_weapon_entity(id)

    switch( isGrenade(iActiveWeapon) )
    {
        case CSW_HEGRENADE:
        {
            iBpAmmo = cs_get_user_bpammo(id, CSW_HEGRENADE)
            cs_set_user_bpammo(id, CSW_HEGRENADE, iBpAmmo - 1)

            if ( iBpAmmo > 1 )
                bShouldKill = false
        }
        case CSW_FLASHBANG:
        {
            iBpAmmo = cs_get_user_bpammo(id, CSW_FLASHBANG)
            cs_set_user_bpammo(id, CSW_FLASHBANG, iBpAmmo - 1)

            if ( iBpAmmo > 1 )
                bShouldKill = false
        }
        case CSW_SMOKEGRENADE:
        {
            iBpAmmo = cs_get_user_bpammo(id, CSW_SMOKEGRENADE)
            cs_set_user_bpammo(id, CSW_SMOKEGRENADE, iBpAmmo - 1)

            if ( iBpAmmo > 1 )
                bShouldKill = false
        }
    }

    if ( bShouldKill )
    {
        ExecuteHam(Ham_Weapon_RetireWeapon, iActiveWeapon)
        ExecuteHam(Ham_RemovePlayerItem, id, iActiveWeapon)
        user_has_weapon(id, iWeapon, 0)
        ExecuteHam(Ham_Item_Kill, iActiveWeapon)
    }

    cs_set_user_money(id, iMoney, 1)
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

stock isGrenade(iEnt)
{
    new szEnt[32]
    pev(iEnt, pev_classname, szEnt, charsmax(szEnt))

    if ( equal(szEnt[7], "hegrenade") )          return CSW_HEGRENADE
    else if ( equal(szEnt[7], "flashbang") )     return CSW_FLASHBANG
    else if ( equal(szEnt[7], "smokegrenade") )  return CSW_SMOKEGRENADE

    return 0
}

stock grenadeAdd(id, iGrenade, szGrenade[], Float:fFactor)
{
    new iAmmo
    iAmmo = cs_get_user_bpammo(id, iGrenade)

    if ( !iAmmo )
    {
        give_item(id, szGrenade)
        cs_set_user_bpammo(id, iGrenade, floatround(fFactor * 1.0))
    }
    else
    {
        cs_set_user_bpammo(id, iGrenade, iAmmo + floatround(fFactor * 1.0))
    }
}

stock crateKill(iEnt)
{
    if ( pev_valid(iEnt) )
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

stock crateFind(iEnt, eCrate[CRATE])
{
    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        if ( eCrate[CRATE_ID] == iEnt )
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



