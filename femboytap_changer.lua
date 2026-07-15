local ffi  = ffi
local band, rshift, bxor, lshift = bit.band, bit.rshift, bit.bxor, bit.lshift
local floor = math.floor

local off = {}

local DUMPER = "https://raw.githubusercontent.com/a2x/cs2-dumper/main/output/"

local FIELDS = {
    m_pWeaponServices      = "m_pWeaponServices",
    m_hMyWeapons           = "m_hMyWeapons",
    m_hActiveWeapon        = "m_hActiveWeapon",
    m_AttributeManager     = { "m_AttributeManager", "C_EconEntity" },
    m_Item                 = "m_Item",
    m_pGameSceneNode       = "m_pGameSceneNode",
    m_modelState           = { "m_modelState", "CSkeletonInstance" },
    m_hModel               = { "m_hModel", "CModelState" },
    m_nSubclassID          = "m_nSubclassID",
    m_iTeamNum             = "m_iTeamNum",
    m_iHealth              = "m_iHealth",
    m_lifeState            = "m_lifeState",
    m_hOwnerEntity         = "m_hOwnerEntity",
    m_hPlayerPawn          = "m_hPlayerPawn",
    m_steamID              = "m_steamID",
    m_iItemDefinitionIndex = "m_iItemDefinitionIndex",
    m_bRestoreCustomMat    = "m_bRestoreCustomMaterialAfterPrecache",
    m_iEntityQuality       = "m_iEntityQuality",
    m_iItemIDLow           = "m_iItemIDLow",
    m_iItemIDHigh          = "m_iItemIDHigh",
    m_iAccountID           = "m_iAccountID",
    m_OriginalOwnerXuidLow = { "m_OriginalOwnerXuidLow", "C_EconEntity" },
    m_bInitialized         = "m_bInitialized",
    m_bDisallowSOC         = "m_bDisallowSOC",
    m_AttributeList        = "m_AttributeList",
    m_Attributes           = "m_Attributes",
    m_nFallbackPaintKit    = { "m_nFallbackPaintKit", "C_EconEntity" },
    m_nFallbackSeed        = { "m_nFallbackSeed", "C_EconEntity" },
    m_flFallbackWear       = { "m_flFallbackWear", "C_EconEntity" },
    m_nFallbackStatTrak    = { "m_nFallbackStatTrak", "C_EconEntity" },
    m_EconGloves           = { "m_EconGloves", "C_CSPlayerPawn" },
    m_bNeedToReApplyGloves = { "m_bNeedToReApplyGloves", "C_CSPlayerPawn" },

}
local function pull_offset(j, name, after)
    local init = 1

    if after then local p = j:find('"' .. after .. '"%s*:%s*{'); if p then init = p end end
    local v = j:match('"' .. name .. '"%s*:%s*(%d+)', init)
    return v and tonumber(v) or nil
end
pcall(function()
    local j = http.Get(DUMPER .. "client_dll.json")
    if type(j) ~= "string" then return end
    for key, spec in pairs(FIELDS) do
        local name, after = spec, nil
        if type(spec) == "table" then name, after = spec[1], spec[2] end
        local v = pull_offset(j, name, after)
        if v then off[key] = v end
    end
end)
off.m_szWorldModel = 48
off.m_modelState = off.m_modelState or 336
off.m_hModel     = off.m_hModel     or 160

local function r_u8 (a) return ffi.cast("uint8_t*",  a)[0] end
local function r_u16(a) return ffi.cast("uint16_t*", a)[0] end
local function r_i32(a) return ffi.cast("int32_t*",  a)[0] end
local function r_u32(a) return ffi.cast("uint32_t*", a)[0] end
local function r_u64(a) return ffi.cast("uint64_t*", a)[0] end
local function r_ptr(a) return tonumber(ffi.cast("uint64_t*", a)[0]) end
local function w_u8 (a,v) ffi.cast("uint8_t*",  a)[0]=v end
local function w_u16(a,v) ffi.cast("uint16_t*", a)[0]=v end
local function w_i32(a,v) ffi.cast("int32_t*",  a)[0]=v end
local function w_u32(a,v) ffi.cast("uint32_t*", a)[0]=v end
local function w_u64(a,v) ffi.cast("uint64_t*", a)[0]=v end
local function w_f32(a,v) ffi.cast("float*",    a)[0]=v end
local function valid(p) return p ~= nil and p > 0x10000 and p < 0x7FFFFFFFFFFF end
local function read_cstr(a, max)
    if not valid(a) then return "" end
    local t = {}
    for i = 0, (max or 160) - 1 do
        local c = r_u8(a + i); if c == 0 then break end
        t[#t+1] = string.char(c)
    end
    return table.concat(t)
end

local function sig_rva(modBase, mod, pattern, instrLen)
    if not modBase then return nil end
    local a = mem.FindPattern(mod, pattern); if not a or a == 0 then return nil end
    a = tonumber(a)
    return (a + instrLen + r_i32(a + 3)) - modBase
end
local function sig_disp(mod, pattern)
    local a = mem.FindPattern(mod, pattern); if not a or a == 0 then return nil end
    return r_i32(tonumber(a) + 3)
end
-- cs2-dumper 2026-07-10 fallbacks (updated after CS2 patch)
local FALLBACK_ENTITYLIST = 0x254EE60
local FALLBACK_LOCALCTRL  = 0x237EBA0

do
    local cb = mem.GetModuleBase("client.dll")
    local eb = mem.GetModuleBase("engine2.dll")

    local ENTLIST_PATS = {
        "48 8B 0D ?? ?? ?? ?? 48 89 7C 24 ?? 8B FA C1 EB",
        "48 89 0D ?? ?? ?? ?? E9 ?? ?? ?? ?? CC",
    }
    for _, pat in ipairs(ENTLIST_PATS) do
        off.dwEntityList = sig_rva(cb, "client.dll", pat, 7)
        if off.dwEntityList then break end
    end
    if not off.dwEntityList then
        off.dwEntityList = FALLBACK_ENTITYLIST
        print(string.format("[changer] entlist pattern miss, using fallback RVA 0x%X", FALLBACK_ENTITYLIST))
    end

    off.dwLocalPlayerController = sig_rva(cb, "client.dll", "48 8B 05 ?? ?? ?? ?? 41 89 BE", 7)
    if not off.dwLocalPlayerController then
        off.dwLocalPlayerController = FALLBACK_LOCALCTRL
        print(string.format("[changer] localctrl pattern miss, using fallback RVA 0x%X", FALLBACK_LOCALCTRL))
    end

    off.dwNetworkGameClient     = sig_rva(eb, "engine2.dll", "48 89 3D ?? ?? ?? ?? FF 87", 7)
    off.dwNetworkGameClient_signOnState = sig_disp("engine2.dll", "44 8B 81 ?? ?? ?? ?? 48 8D 0D")
    if not off.dwLocalPlayerController or not off.dwEntityList or not off.m_hMyWeapons then
        print("[changer] WARNING: signatures/netvars not resolved -- changer inactive")
    else
        print(string.format("[changer] sigs ok: entlist=%X ctrl=%X ngc=%s",
            off.dwEntityList, off.dwLocalPlayerController,
            off.dwNetworkGameClient and string.format("%X", off.dwNetworkGameClient) or "nil"))
    end
end

local function tou32(x) x = x % 0x100000000; if x < 0 then x = x + 0x100000000 end; return x end
local function mul32(a, b)
    a = a % 0x100000000; b = b % 0x100000000
    local ah, al = floor(a/0x10000), a%0x10000
    local bh = floor(b/0x10000)
    return (al*(b%0x10000) + ((al*bh + ah*(b%0x10000)) % 0x10000)*0x10000) % 0x100000000
end
local MM = 0x5bd1e995
local function murmur2(str, seed)
    local len = #str
    local h = tou32(bxor(seed, len))
    local i, rem = 1, len
    while rem >= 4 do
        local b0,b1,b2,b3 = str:byte(i, i+3)
        local k = b0 + b1*256 + b2*65536 + b3*16777216
        k = mul32(k, MM); k = tou32(bxor(k, rshift(k, 24))); k = mul32(k, MM)
        h = mul32(h, MM); h = tou32(bxor(h, k))
        i = i + 4; rem = rem - 4
    end
    if rem >= 3 then h = tou32(bxor(h, lshift(str:byte(i+2), 16))) end
    if rem >= 2 then h = tou32(bxor(h, lshift(str:byte(i+1), 8))) end
    if rem >= 1 then h = tou32(bxor(h, str:byte(i))); h = mul32(h, MM) end
    h = tou32(bxor(h, rshift(h, 13))); h = mul32(h, MM); h = tou32(bxor(h, rshift(h, 15)))
    return h
end
local function subclass_hash(def) return murmur2(tostring(def):lower(), 0x31415926) end

local DLL = "client.dll"
-- client.dll 
local sig = {
    set_model      = "40 53 48 83 EC ?? 48 8B D9 4C 8B C2 48 8B 0D ?? ?? ?? ?? 48 8D 54 24 40",  -- CBaseModelEntity::SetModel
    update_subclass= "4C 8B DC 53 48 81 EC ?? ?? ?? ?? 48 8B 41",                                 -- CEconItemView subclass refresh
    set_mesh_mask  = "48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC ?? 48 8D 99 ?? ?? ?? ?? 48 8B 71", -- CSkeletonInstance mesh mask
    regen_skins    = "48 83 EC ?? E8 ?? ?? ?? ?? 48 85 C0 0F 84 ?? ?? ?? ?? 48 8B 10",            -- regenerate custom skins
}
-- a + 5 + rel32 -> CBodyComponent::SetBodyGroup
local SBG_SIG = "E8 ?? ?? ?? ?? EB 0C 48 8B CF"
local fn, fnptr = {}, {}
local function resolve()
    for name, pattern in pairs(sig) do
        if not fn[name] then local a = mem.FindPattern(DLL, pattern); if a and a ~= 0 then fn[name] = a end end
    end
    if not fn.set_body_group then
        local a = mem.FindPattern(DLL, SBG_SIG)
        if a and a ~= 0 then fn.set_body_group = a + 5 + r_i32(a + 1) end
    end
    if fn.set_model       and not fnptr.set_model       then fnptr.set_model       = ffi.cast("void(*)(void*, const char*)", fn.set_model) end
    if fn.update_subclass and not fnptr.update_subclass then fnptr.update_subclass = ffi.cast("void(*)(void*)",              fn.update_subclass) end
    if fn.set_mesh_mask   and not fnptr.set_mesh_mask   then fnptr.set_mesh_mask   = ffi.cast("void(*)(void*, uint64_t)",    fn.set_mesh_mask) end
    if fn.regen_skins     and not fnptr.regen_skins     then fnptr.regen_skins     = ffi.cast("void(*)(void)",               fn.regen_skins) end
    if fn.set_body_group  and not fnptr.set_body_group  then fnptr.set_body_group  = ffi.cast("void(*)(void*, const char*, unsigned int)", fn.set_body_group) end
end
local function vfunc(this, index)
    if not valid(this) then return nil end
    local vt = r_ptr(this); if not valid(vt) then return nil end
    local f = r_ptr(vt + index*8); if not valid(f) then return nil end
    return f
end
local function vcall_void(this, index)
    local f = vfunc(this, index); if not f then return end
    ffi.cast("void(*)(void*)", f)(ffi.cast("void*", this))
end
local function vcall_void_bool(this, index, b)
    local f = vfunc(this, index); if not f then return end
    ffi.cast("void(*)(void*, int)", f)(ffi.cast("void*", this), b and 1 or 0)
end

local KNIVES = {
    { name = "Default (no swap)", def = nil },
    { name = "Bayonet",        def = 500 }, { name = "Classic Knife",  def = 503 },
    { name = "Flip Knife",     def = 505 }, { name = "Gut Knife",      def = 506 },
    { name = "Karambit",       def = 507 }, { name = "M9 Bayonet",     def = 508 },
    { name = "Huntsman",       def = 509 }, { name = "Falchion",       def = 512 },
    { name = "Bowie Knife",    def = 514 }, { name = "Butterfly",      def = 515 },
    { name = "Shadow Daggers", def = 516 }, { name = "Paracord Knife", def = 517 },
    { name = "Survival Knife", def = 518 }, { name = "Ursus Knife",    def = 519 },
    { name = "Navaja Knife",   def = 520 }, { name = "Nomad Knife",    def = 521 },
    { name = "Stiletto",       def = 522 }, { name = "Talon Knife",    def = 523 },
    { name = "Skeleton Knife", def = 525 }, { name = "Kukri Knife",    def = 526 },
}
local WEAPONS = {
    { name = "AK-47",        def = 7  }, { name = "M4A4",         def = 16 },
    { name = "M4A1-S",       def = 60 }, { name = "AWP",          def = 9  },
    { name = "SSG 08",       def = 40 }, { name = "SCAR-20",      def = 38 },
    { name = "G3SG1",        def = 11 }, { name = "SG 553",       def = 39 },
    { name = "AUG",          def = 8  }, { name = "FAMAS",        def = 10 },
    { name = "Galil AR",     def = 13 }, { name = "Desert Eagle", def = 1  },
    { name = "R8 Revolver",  def = 64 }, { name = "Dual Berettas",def = 2  },
    { name = "Five-SeveN",   def = 3  }, { name = "Glock-18",     def = 4  },
    { name = "Tec-9",        def = 30 }, { name = "P2000",        def = 32 },
    { name = "P250",         def = 36 }, { name = "USP-S",        def = 61 },
    { name = "CZ75-Auto",    def = 63 }, { name = "MAC-10",       def = 17 },
    { name = "P90",          def = 19 }, { name = "PP-Bizon",     def = 26 },
    { name = "MP5-SD",       def = 23 }, { name = "MP7",          def = 33 },
    { name = "MP9",          def = 34 }, { name = "UMP-45",       def = 24 },
    { name = "M249",         def = 14 }, { name = "Negev",        def = 28 },
    { name = "XM1014",       def = 25 }, { name = "MAG-7",        def = 27 },
    { name = "Nova",         def = 35 }, { name = "Sawed-Off",    def = 29 },
}
local GLOVES = {
    { name = "Default (off)",      def = 0    },
    { name = "Bloodhound Gloves",  def = 5027 }, { name = "Sport Gloves",      def = 5030 },
    { name = "Driver Gloves",      def = 5031 }, { name = "Hand Wraps",        def = 5032 },
    { name = "Moto Gloves",        def = 5033 }, { name = "Specialist Gloves", def = 5034 },
    { name = "Hydra Gloves",       def = 5035 }, { name = "Broken Fang Gloves",def = 4725 },
}
local function is_knife(def) return def == 42 or def == 59 or (def >= 500 and def <= 526) end

local SKINS = {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47.png",
        "paint_name": "AK-47  | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1207",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1207.png",
        "paint_name": "AK-47 | Kanlı Spor",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1352",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1352.png",
        "paint_name": "AK-47 | Oligark",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "113",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-113.png",
        "paint_name": "AK-47 | Dışlanmış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1171",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1171.png",
        "paint_name": "AK-47 | Miras",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "456",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-456.png",
        "paint_name": "AK-47 | Hidroponik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "394",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-394.png",
        "paint_name": "AK-47 | Kartel",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-44.png",
        "paint_name": "AK-47 | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "941",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-941.png",
        "paint_name": "AK-47 | Hayalet Bozan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "600",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-600.png",
        "paint_name": "AK-47 | Neon Devrim",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "959",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-959.png",
        "paint_name": "AK-47 | Anubis Lejyonu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "801",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-801.png",
        "paint_name": "AK-47 | Asiimov",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "836",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-836.png",
        "paint_name": "AK-47 | Kayıp Tapınak",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "282",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-282.png",
        "paint_name": "AK-47 | Kırmızı Çizgi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1143.png",
        "paint_name": "AK-47 | Buzlu Kömür",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "474",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-474.png",
        "paint_name": "AK-47 | Aquamarine İntikamı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "422",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-422.png",
        "paint_name": "AK-47 | Seçkin Yapım",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1141",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1141.png",
        "paint_name": "AK-47 | Gece Dileği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "506",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-506.png",
        "paint_name": "AK-47 | Kaotik Matris",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "302",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-302.png",
        "paint_name": "AK-47 | Vulcan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "490",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-490.png",
        "paint_name": "AK-47 | Cephe Arkası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1221",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1221.png",
        "paint_name": "AK-47 | Tek Atış",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "724",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-724.png",
        "paint_name": "AK-47 | Yabani Lotus",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1018",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1018.png",
        "paint_name": "AK-47 | Jaguar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "707",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-707.png",
        "paint_name": "AK-47 | Neon Savaşçı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1004",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1004.png",
        "paint_name": "AK-47 | X-Ray",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "180",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-180.png",
        "paint_name": "AK-47 | Ateş Yılanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "912",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-912.png",
        "paint_name": "AK-47 | Geçişli Renk",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "341",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-341.png",
        "paint_name": "AK-47 | Birinci Sınıf Deri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "142",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-142.png",
        "paint_name": "AK-47 | B'deki Canavar",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "316",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-316.png",
        "paint_name": "AK-47 | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "300",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-300.png",
        "paint_name": "AK-47 | Zümrüt Çizgili",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "380",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-380.png",
        "paint_name": "AK-47 | Çöl İsyancısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "340",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-340.png",
        "paint_name": "AK-47 | Havalı Grafiti Deri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1087",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1087.png",
        "paint_name": "AK-47 | Soyut 1337",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "639",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-639.png",
        "paint_name": "AK-47 | Kanlı Spor",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "675",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-675.png",
        "paint_name": "AK-47 | İmparatoriçe",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "921",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-921.png",
        "paint_name": "AK-47 | Altın Sarmaşık",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "885",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-885.png",
        "paint_name": "AK-47 | Retro Dalga",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1035",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1035.png",
        "paint_name": "AK-47 | Gece Kaplanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1238",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1238.png",
        "paint_name": "AK-47 | Çelik Delta",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "524",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-524.png",
        "paint_name": "AK-47 | Yakıt Enjektörü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "656",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-656.png",
        "paint_name": "AK-47 | Yörünge Mk01",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1179",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1179.png",
        "paint_name": "AK-47 | Zeytin Yeşili Kamuflaj",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "226",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-226.png",
        "paint_name": "AK-47 | Mavi Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "172",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-172.png",
        "paint_name": "AK-47 | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1070",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1070.png",
        "paint_name": "AK-47 | Yeşil Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "14",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-14.png",
        "paint_name": "AK-47 | Kırmızı Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "795",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-795.png",
        "paint_name": "AK-47 | Güvenlik Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "745",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-745.png",
        "paint_name": "AK-47 | Barok Mor",
        "legacy_model": true
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1309",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1309.png",
        "paint_name": "AK-47 | Yeni Kızıl Dalga",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1218",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1218.png",
        "paint_name": "AK-47 | Gece Yarısı Laminatı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1283",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1283.png",
        "paint_name": "AK-47 | Soğuk Zümrüt",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "1288",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-1288.png",
        "paint_name": "AK-47 | Gri Kamuflaj",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-72.png",
        "paint_name": "AK-47 | Av Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "122",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-122.png",
        "paint_name": "AK-47 | Orman Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 7,
        "weapon_name": "weapon_ak47",
        "paint": "170",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ak47-170.png",
        "paint_name": "AK-47 | Yırtıcı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug.png",
        "paint_name": "AUG  | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "246",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-246.png",
        "paint_name": "AUG | Geçişli Kehribar",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "913",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-913.png",
        "paint_name": "AUG | Sevimli Köpekçikler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "507",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-507.png",
        "paint_name": "AUG | Kıvrımlı Çizgiler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "727",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-727.png",
        "paint_name": "AUG | Gece Yarısı Zambağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "779",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-779.png",
        "paint_name": "AUG | Rastgele Erişim",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "995",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-995.png",
        "paint_name": "AUG | Araştırma",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "1033",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-1033.png",
        "paint_name": "AUG | Yeşim Taşı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "758",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-758.png",
        "paint_name": "AUG | Alevli Piton",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "197",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-197.png",
        "paint_name": "AUG | Koyu Mavi Eloksallı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "33",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-33.png",
        "paint_name": "AUG | Kızıl Yeni",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "1198",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-1198.png",
        "paint_name": "AUG | Demir Gözcü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "121",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-121.png",
        "paint_name": "AUG | Şık Dekor",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "1339",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-1339.png",
        "paint_name": "AUG | Karşı Saldırı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "455",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-455.png",
        "paint_name": "AUG | Akihabara Kabulü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "280",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-280.png",
        "paint_name": "AUG | Bukalemun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "845",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-845.png",
        "paint_name": "AUG | Momentum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "674",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-674.png",
        "paint_name": "AUG | Üçgen Taktik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "305",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-305.png",
        "paint_name": "AUG | Tork",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "541",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-541.png",
        "paint_name": "AUG | Kırlangıç Sürüsü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "886",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-886.png",
        "paint_name": "AUG | Kutup Kurdu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "134",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-134.png",
        "paint_name": "AUG | Zapems'in Gözü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "583",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-583.png",
        "paint_name": "AUG | Soylu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "1088",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-1088.png",
        "paint_name": "AUG | Veba",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "823",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-823.png",
        "paint_name": "AUG | Gece Kum Fırtınası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "690",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-690.png",
        "paint_name": "AUG | Göl Kuşu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "601",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-601.png",
        "paint_name": "AUG | Syd Mead",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "942",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-942.png",
        "paint_name": "AUG | Tom Cat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "173",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-173.png",
        "paint_name": "AUG | Pembe Domuzcuk",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "708",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-708.png",
        "paint_name": "AUG | Kehribar Akıntısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "10",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-10.png",
        "paint_name": "AUG | Bakır Kafalı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "927",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-927.png",
        "paint_name": "AUG | Çürük Odun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "1249",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-1249.png",
        "paint_name": "AUG | Yılan Yuvası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "73",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-73.png",
        "paint_name": "AUG | Kartal Kanatları",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "1308",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-1308.png",
        "paint_name": "AUG | Komando Birliği",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "740",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-740.png",
        "paint_name": "AUG | Murano Mavisi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "9",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-9.png",
        "paint_name": "AUG | Bengal Kaplanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "46",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-46.png",
        "paint_name": "AUG | Paralı Asker",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "47",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-47.png",
        "paint_name": "AUG | Sömürgeci",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "100",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-100.png",
        "paint_name": "AUG | Fırtına Uğultusu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "444",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-444.png",
        "paint_name": "AUG | Daedalus'un Düşüşü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "110",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-110.png",
        "paint_name": "AUG | Hedef Tahtası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "794",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-794.png",
        "paint_name": "AUG | Tarayıcı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 8,
        "weapon_name": "weapon_aug",
        "paint": "375",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_aug-375.png",
        "paint_name": "AUG | Radyasyon Tehlikesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp.png",
        "paint_name": "AWP  | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1026",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1026.png",
        "paint_name": "AWP | Geçişli Renk",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "395",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-395.png",
        "paint_name": "AWP | Savaş Tanrısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "718",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-718.png",
        "paint_name": "AWP | Pati",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "212",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-212.png",
        "paint_name": "AWP | Grafit",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "51",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-51.png",
        "paint_name": "AWP | Yıldırım Çarpması",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1029",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1029.png",
        "paint_name": "AWP | İpek Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "424",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-424.png",
        "paint_name": "AWP | Solucan Tanrısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1346",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1346.png",
        "paint_name": "AWP | Buzlu Kömür",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1213",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1213.png",
        "paint_name": "AWP | Tazı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1206",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1206.png",
        "paint_name": "AWP | Alacalı Printstream",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1170",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1170.png",
        "paint_name": "AWP | Krom Top",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "279",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-279.png",
        "paint_name": "AWP | Asiimov",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1144",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1144.png",
        "paint_name": "AWP | Göz Alıcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "259",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-259.png",
        "paint_name": "AWP | Kırmızı Çizgi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "662",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-662.png",
        "paint_name": "AWP | Oni Taiji",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "475",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-475.png",
        "paint_name": "AWP | Hiper Canavar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "525",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-525.png",
        "paint_name": "AWP | Seçkin Yapım",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "803",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-803.png",
        "paint_name": "AWP | Neo-Noir",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "640",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-640.png",
        "paint_name": "AWP | Sanrı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "943",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-943.png",
        "paint_name": "AWP | Kılcal Damar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "838",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-838.png",
        "paint_name": "AWP | Engerek",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "887",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-887.png",
        "paint_name": "AWP | Dışlanmış",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "917",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-917.png",
        "paint_name": "AWP | Vahşi Ateş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "181",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-181.png",
        "paint_name": "AWP | Corticera",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "344",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-344.png",
        "paint_name": "AWP | Ejderha Destanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "446",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-446.png",
        "paint_name": "AWP | Medusa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "137",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-137.png",
        "paint_name": "AWP | Krako",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1280",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1280.png",
        "paint_name": "AWP | Tek Atışta Ölüm",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "691",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-691.png",
        "paint_name": "AWP | Azrail",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "736",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-736.png",
        "paint_name": "AWP | Prens",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "975",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-975.png",
        "paint_name": "AWP | Canların Başı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "756",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-756.png",
        "paint_name": "AWP | Gungnir",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "819",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-819.png",
        "paint_name": "AWP | Çöl Pulları",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1222",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1222.png",
        "paint_name": "AWP | Altın Yılan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "584",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-584.png",
        "paint_name": "AWP | Phobos",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1239",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1239.png",
        "paint_name": "AWP | Nil Toprağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "163",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-163.png",
        "paint_name": "AWP | CMYK",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "174",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-174.png",
        "paint_name": "AWP | *BOOM*",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "84",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-84.png",
        "paint_name": "AWP | Pembe DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "227",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-227.png",
        "paint_name": "AWP | Elektrikli Kovan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "788",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-788.png",
        "paint_name": "AWP | Acheron",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "251",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-251.png",
        "paint_name": "AWP | Çukur Engereği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1058",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1058.png",
        "paint_name": "AWP | Pop Art",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "1324",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-1324.png",
        "paint_name": "AWP | Arsenik Kirliliği",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "451",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-451.png",
        "paint_name": "AWP | Güneş Aslanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-72.png",
        "paint_name": "AWP | Av Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 9,
        "weapon_name": "weapon_awp",
        "paint": "30",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_awp-30.png",
        "paint_name": "AWP | Engerek Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet.png",
        "paint_name": "Süngü（★）  | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-38.png",
        "paint_name": "Süngü（★） | Geçişli Renk",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-417.png",
        "paint_name": "Süngü（★） | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-418.png",
        "paint_name": "Süngü（★） | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-419.png",
        "paint_name": "Süngü（★） | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-420.png",
        "paint_name": "Süngü（★） | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-421.png",
        "paint_name": "Süngü（★） | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-568.png",
        "paint_name": "Süngü（★） | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-569.png",
        "paint_name": "Süngü（★） | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-570.png",
        "paint_name": "Süngü（★） | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-571.png",
        "paint_name": "Süngü（★） | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-572.png",
        "paint_name": "Süngü（★） | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-413.png",
        "paint_name": "Süngü（★） | Mermer Solma",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "580",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-580.png",
        "paint_name": "Süngü（★） | Serbest Stil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-415.png",
        "paint_name": "Süngü（★） | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-416.png",
        "paint_name": "Süngü（★） | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-59.png",
        "paint_name": "Süngü（★） | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-409.png",
        "paint_name": "Süngü（★） | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-42.png",
        "paint_name": "Süngü（★） | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "410",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-410.png",
        "paint_name": "Süngü（★） | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-43.png",
        "paint_name": "Süngü（★） | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-44.png",
        "paint_name": "Süngü（★） | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-414.png",
        "paint_name": "Süngü（★） | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "558",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-558.png",
        "paint_name": "Süngü（★） | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "563",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-563.png",
        "paint_name": "Süngü（★） | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "573",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-573.png",
        "paint_name": "Süngü（★） | Ototronik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-5.png",
        "paint_name": "Süngü（★） | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-77.png",
        "paint_name": "Süngü（★） | Boreal Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "578",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-578.png",
        "paint_name": "Süngü（★） | Berrak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-12.png",
        "paint_name": "Süngü（★） | Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-40.png",
        "paint_name": "Süngü（★） | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-98.png",
        "paint_name": "Süngü（★） | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-175.png",
        "paint_name": "Süngü（★） | Alacalı Pas",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-72.png",
        "paint_name": "Süngü（★） | Av Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 500,
        "weapon_name": "weapon_bayonet",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bayonet-143.png",
        "paint_name": "Süngü（★） | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon.png",
        "paint_name": "PP-Bizon  | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "1083",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-1083.png",
        "paint_name": "PP-Bizon | Bağlantı Kutusu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "70",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-70.png",
        "paint_name": "PP-Bizon | Karbon Fiber",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "267",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-267.png",
        "paint_name": "PP-Bizon | Kobalt Yarı Ton",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "159",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-159.png",
        "paint_name": "PP-Bizon | Pirinç",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "203",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-203.png",
        "paint_name": "PP-Bizon | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "349",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-349.png",
        "paint_name": "PP-Bizon | Ölüm Girdabı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "676",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-676.png",
        "paint_name": "PP-Bizon | Kumarbaz",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "306",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-306.png",
        "paint_name": "PP-Bizon | Antika",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "526",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-526.png",
        "paint_name": "PP-Bizon | Foton Bölgesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "542",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-542.png",
        "paint_name": "PP-Bizon | Anubis Yargısı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "508",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-508.png",
        "paint_name": "PP-Bizon | Yakıt Çubuğu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "692",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-692.png",
        "paint_name": "PP-Bizon | Gece İsyanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "884",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-884.png",
        "paint_name": "PP-Bizon | Yol Canavarı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "1125",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-1125.png",
        "paint_name": "PP-Bizon | Uzay Kedisi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "1099",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-1099.png",
        "paint_name": "PP-Bizon | Taktik Fener",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "973",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-973.png",
        "paint_name": "PP-Bizon | Gizemli Yazıt",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "594",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-594.png",
        "paint_name": "PP-Bizon | Biçerdöver",
        "legacy_model": true
    },
{
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "457",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-457.png",
        "paint_name": "PP-Bizon | Bambu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "641",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-641.png",
        "paint_name": "PP-Bizon | Hararetli Akış",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "775",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-775.png",
        "paint_name": "PP-Bizon | Tesis Kroki",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "164",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-164.png",
        "paint_name": "PP-Bizon | Modern Avcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "829",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-829.png",
        "paint_name": "PP-Bizon | Bukalemun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "293",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-293.png",
        "paint_name": "PP-Bizon | Ölümcül Isırık",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "13",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-13.png",
        "paint_name": "PP-Bizon | Su Çizgili",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "236",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-236.png",
        "paint_name": "PP-Bizon | Gece Harekatı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "224",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-224.png",
        "paint_name": "PP-Bizon | Su İzi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "1325",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-1325.png",
        "paint_name": "PP-Bizon | Ahşap Kamuflaj",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "873",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-873.png",
        "paint_name": "PP-Bizon | Deniz Kuşu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "376",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-376.png",
        "paint_name": "PP-Bizon | Kimyasal Yeşil",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "3",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-3.png",
        "paint_name": "PP-Bizon | Kırmızı Elma",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "25",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-25.png",
        "paint_name": "PP-Bizon | Orman Yaprakları",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "171",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-171.png",
        "paint_name": "PP-Bizon | Radyasyon Uyarısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "148",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-148.png",
        "paint_name": "PP-Bizon | Çöl Çizgili",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "149",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-149.png",
        "paint_name": "PP-Bizon | Kent Çizgili",
        "legacy_model": false
    },
    {
        "weapon_defindex": 26,
        "weapon_name": "weapon_bizon",
        "paint": "770",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_bizon-770.png",
        "paint_name": "PP-Bizon | Soğuk Oda",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a.png",
        "paint_name": "CZ75-Otomatik | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "298",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-298.png",
        "paint_name": "CZ75-Otomatik | Ordu Parlaklığı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "1195",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-1195.png",
        "paint_name": "CZ75-Otomatik | Bakır Çekirdek",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "859",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-859.png",
        "paint_name": "CZ75-Otomatik | Zümrüt Kuvars",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "622",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-622.png",
        "paint_name": "CZ75-Otomatik | Polimer",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "268",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-268.png",
        "paint_name": "CZ75-Otomatik | Çizgili Plaka",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "269",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-269.png",
        "paint_name": "CZ75-Otomatik | Fuşya Zamanı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "334",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-334.png",
        "paint_name": "CZ75-Otomatik | Sarmal",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "315",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-315.png",
        "paint_name": "CZ75-Otomatik | Zehirli Dart",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "325",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-325.png",
        "paint_name": "CZ75-Otomatik | Kadeh",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "453",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-453.png",
        "paint_name": "CZ75-Otomatik | Zümrüt",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "32",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-32.png",
        "paint_name": "CZ75-Otomatik | Gümüş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "270",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-270.png",
        "paint_name": "CZ75-Otomatik | Victoria",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "937",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-937.png",
        "paint_name": "CZ75-Otomatik | Girdap",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "350",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-350.png",
        "paint_name": "CZ75-Otomatik | Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "944",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-944.png",
        "paint_name": "CZ75-Otomatik | Eskitilmiş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "709",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-709.png",
        "paint_name": "CZ75-Otomatik | Bütçe",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "435",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-435.png",
        "paint_name": "CZ75-Otomatik | Öncü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "1036",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-1036.png",
        "paint_name": "CZ75-Otomatik | Yılan Kartalı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "476",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-476.png",
        "paint_name": "CZ75-Otomatik | Sarı Ceket",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "687",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-687.png",
        "paint_name": "CZ75-Otomatik | Taktik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "602",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-602.png",
        "paint_name": "CZ75-Otomatik | Baskı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "976",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-976.png",
        "paint_name": "CZ75-Otomatik | İntikam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "543",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-543.png",
        "paint_name": "CZ75-Otomatik | Kızıl Şahin",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "643",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-643.png",
        "paint_name": "CZ75-Otomatik | Xiangliu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "1064",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-1064.png",
        "paint_name": "CZ75-Otomatik | Sendika",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "218",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-218.png",
        "paint_name": "CZ75-Otomatik | Mavi Altıgen",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "366",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-366.png",
        "paint_name": "CZ75-Otomatik | Yeşil Kareli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "1076",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-1076.png",
        "paint_name": "CZ75-Otomatik | Matris Kadro",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-12.png",
        "paint_name": "CZ75-Otomatik | Kızıl Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "333",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-333.png",
        "paint_name": "CZ75-Otomatik | Mor Plaka",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "322",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-322.png",
        "paint_name": "CZ75-Otomatik | Siyah Nitrit",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "297",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-297.png",
        "paint_name": "CZ75-Otomatik | Smokin",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "1329",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-1329.png",
        "paint_name": "CZ75-Otomatik | Pembe Gökyüzü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "933",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-933.png",
        "paint_name": "CZ75-Otomatik | Gece Yarısı Avcı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 63,
        "weapon_name": "weapon_cz75a",
        "paint": "147",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_cz75a-147.png",
        "paint_name": "CZ75-Otomatik | Orman Çizgili",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle.png",
        "paint_name": "Desert Eagle | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "37",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-37.png",
        "paint_name": "Desert Eagle | Alev",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "61",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-61.png",
        "paint_name": "Desert Eagle | Hipnotik",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "425",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-425.png",
        "paint_name": "Desert Eagle | Bronz Dekor",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "296",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-296.png",
        "paint_name": "Desert Eagle | Gök Taşı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "231",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-231.png",
        "paint_name": "Desert Eagle | Kobalt Dağılımı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "1006",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-1006.png",
        "paint_name": "Desert Eagle | Gece Soyguncusu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "757",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-757.png",
        "paint_name": "Desert Eagle | Zümrüt Ejderha",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "992",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-992.png",
        "paint_name": "Desert Eagle | Bronz Plaka",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "185",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-185.png",
        "paint_name": "Desert Eagle | Altın Koi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "469",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-469.png",
        "paint_name": "Desert Eagle | Günbatımı Fırtınası (İçi)",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "468",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-468.png",
        "paint_name": "Desert Eagle | Gece Yarısı Fırtınası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "470",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-470.png",
        "paint_name": "Desert Eagle | Günbatımı Fırtınası (Nii)",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "1054",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-1054.png",
        "paint_name": "Desert Eagle | Eloksal Solmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "509",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-509.png",
        "paint_name": "Desert Eagle | Korint",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "397",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-397.png",
        "paint_name": "Desert Eagle | Naga",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "603",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-603.png",
        "paint_name": "Desert Eagle | Direktör",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "527",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-527.png",
        "paint_name": "Desert Eagle | Kumandan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "273",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-273.png",
        "paint_name": "Desert Eagle | Miras",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "328",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-328.png",
        "paint_name": "Desert Eagle | El Topu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "347",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-347.png",
        "paint_name": "Desert Eagle | Pilot",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "962",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-962.png",
        "paint_name": "Desert Eagle | Baskı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "1050",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-1050.png",
        "paint_name": "Desert Eagle | Karşı Saldırı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "351",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-351.png",
        "paint_name": "Desert Eagle | Komplo",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "1090",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-1090.png",
        "paint_name": "Desert Eagle | Okyanus Sürüşü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "945",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-945.png",
        "paint_name": "Desert Eagle | Mavi Katmanlı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "645",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-645.png",
        "paint_name": "Desert Eagle | Oksit Alevi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "938",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-938.png",
        "paint_name": "Desert Eagle | Işık Atar",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "138",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-138.png",
        "paint_name": "Desert Eagle | Tahterevalli",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "114",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-114.png",
        "paint_name": "Desert Eagle | Kaligrafi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "1189",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-1189.png",
        "paint_name": "Desert Eagle | Bronz Saldırı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "711",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-711.png",
        "paint_name": "Desert Eagle | Kod Adı Kırmızı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "841",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-841.png",
        "paint_name": "Desert Eagle | Hafif Ray",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "764",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-764.png",
        "paint_name": "Desert Eagle | Çöl Fırtınası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "805",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-805.png",
        "paint_name": "Desert Eagle | Mekanik Endüstri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "1257",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-1257.png",
        "paint_name": "Desert Eagle | Nane Yelpazesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "17",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-17.png",
        "paint_name": "Desert Eagle | Kent DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "90",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-90.png",
        "paint_name": "Desert Eagle | Çamur Kaplı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "237",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-237.png",
        "paint_name": "Desert Eagle | Moloz",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "232",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-232.png",
        "paint_name": "Desert Eagle | Kızıl Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-40.png",
        "paint_name": "Desert Eagle | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "1318",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-1318.png",
        "paint_name": "Desert Eagle | Marangoz",
        "legacy_model": false
    },
    {
        "weapon_defindex": 1,
        "weapon_name": "weapon_deagle",
        "paint": "1056",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_deagle-1056.png",
        "paint_name": "Desert Eagle | Sputnik",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite.png",
        "paint_name": "Çift Beretta | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "249",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-249.png",
        "paint_name": "Çift Beretta | Kobalt Kuvars",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "1005",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-1005.png",
        "paint_name": "Çift Beretta | Sokak Soyguncusu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "220",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-220.png",
        "paint_name": "Çift Beretta | Hemoglobin",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "453",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-453.png",
        "paint_name": "Çift Beretta | Zümrüt",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "28",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-28.png",
        "paint_name": "Çift Beretta | Gece Mavisi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "528",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-528.png",
        "paint_name": "Çift Beretta | Kartel",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-43.png",
        "paint_name": "Çift Beretta | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "1156",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-1156.png",
        "paint_name": "Çift Beretta | Ölümcül Çiçek",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "747",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-747.png",
        "paint_name": "Çift Beretta | İkiz Turbo",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "491",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-491.png",
        "paint_name": "Çift Beretta | Ejderha Gözü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "1126",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-1126.png",
        "paint_name": "Çift Beretta | Kavun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "396",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-396.png",
        "paint_name": "Çift Beretta | Kent Şoku",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "139",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-139.png",
        "paint_name": "Çift Beretta | Melek",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "307",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-307.png",
        "paint_name": "Çift Beretta | İntikam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "190",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-190.png",
        "paint_name": "Çift Beretta | Ahşap",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "1169",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-1169.png",
        "paint_name": "Çift Beretta | Sığınak",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "1347",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-1347.png",
        "paint_name": "Çift Beretta | Melek Gözleri",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "112",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-112.png",
        "paint_name": "Çift Beretta | Su Şoku",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "625",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-625.png",
        "paint_name": "Çift Beretta | Kraliyet Muhafızları",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "1091",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-1091.png",
        "paint_name": "Çift Beretta | Sırt deseni",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "903",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-903.png",
        "paint_name": "Çift Beretta | Seçkin 1.6",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "978",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-978.png",
        "paint_name": "Çift Beretta | Felaket",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "895",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-895.png",
        "paint_name": "Çift Beretta | İki Taraf",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "658",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-658.png",
        "paint_name": "Çift Beretta | Cobra",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "544",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-544.png",
        "paint_name": "Çift Beretta | Ventilatör",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "447",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-447.png",
        "paint_name": "Çift Beretta | Düellocu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "860",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-860.png",
        "paint_name": "Çift Beretta | Alevli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "261",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-261.png",
        "paint_name": "Çift Beretta | Deniz Muhafızı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "998",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-998.png",
        "paint_name": "Çift Beretta | Karanlık Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "330",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-330.png",
        "paint_name": "Çift Beretta | Gül",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "450",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-450.png",
        "paint_name": "Çift Beretta | Terazi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "276",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-276.png",
        "paint_name": "Çift Beretta | Siyah Panter",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "46",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-46.png",
        "paint_name": "Çift Beretta | Paralı Asker",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "47",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-47.png",
        "paint_name": "Çift Beretta | Kolonyal",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "153",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-153.png",
        "paint_name": "Çift Beretta | Yıkım",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "1335",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-1335.png",
        "paint_name": "Çift Beretta | İkinci Sınır",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "1290",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-1290.png",
        "paint_name": "Çift Beretta | Malakit",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "1263",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-1263.png",
        "paint_name": "Çift Beretta | Sedef Gül",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "824",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-824.png",
        "paint_name": "Çift Beretta | Odun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "710",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-710.png",
        "paint_name": "Çift Beretta | Parçalanmış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 2,
        "weapon_name": "weapon_elite",
        "paint": "1086",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_elite-1086.png",
        "paint_name": "Çift Beretta | Yağ Değişimi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas.png",
        "paint_name": "FAMAS | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1066",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1066.png",
        "paint_name": "FAMAS | Hat Hatası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "477",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-477.png",
        "paint_name": "FAMAS | Sinir Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1053",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1053.png",
        "paint_name": "FAMAS | Erimiş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "371",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-371.png",
        "paint_name": "FAMAS | Yeraltı Dünyası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "999",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-999.png",
        "paint_name": "FAMAS | Gizli Plan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "60",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-60.png",
        "paint_name": "FAMAS | Kara Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "288",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-288.png",
        "paint_name": "FAMAS | Çavuş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "529",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-529.png",
        "paint_name": "FAMAS | Değer Değişimi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "429",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-429.png",
        "paint_name": "FAMAS | Cin",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "154",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-154.png",
        "paint_name": "FAMAS | Artık Görüntü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1241",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1241.png",
        "paint_name": "FAMAS | Nephthys Nehri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "492",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-492.png",
        "paint_name": "FAMAS | Hayatta Kalan Z",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "904",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-904.png",
        "paint_name": "FAMAS | Emekli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "723",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-723.png",
        "paint_name": "FAMAS | Athena Gözü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "260",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-260.png",
        "paint_name": "FAMAS | Atım",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1092",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1092.png",
        "paint_name": "FAMAS | ZX81 Renkli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1184",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1184.png",
        "paint_name": "FAMAS | Hayal Kırıklığı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1146",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1146.png",
        "paint_name": "FAMAS | Miyav 36",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "919",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-919.png",
        "paint_name": "FAMAS | Anıt",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "626",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-626.png",
        "paint_name": "FAMAS | Mekanik Endüstri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "604",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-604.png",
        "paint_name": "FAMAS | Roll Cage",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1127",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1127.png",
        "paint_name": "FAMAS | Göz Hapsi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "461",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-461.png",
        "paint_name": "FAMAS | Kısa Kollu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1202",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1202.png",
        "paint_name": "FAMAS | 2A2F",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "882",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-882.png",
        "paint_name": "FAMAS | Kısmi Yıkama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "218",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-218.png",
        "paint_name": "FAMAS | Mavi Altıgen",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "178",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-178.png",
        "paint_name": "FAMAS | Uğursuz Kedi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "92",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-92.png",
        "paint_name": "FAMAS | Göl Mavisi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "240",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-240.png",
        "paint_name": "FAMAS | Kaliforniya Kamuflajı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "47",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-47.png",
        "paint_name": "FAMAS | Kolonyal",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1219",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1219.png",
        "paint_name": "FAMAS | Yeti Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1321",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1321.png",
        "paint_name": "FAMAS | Gri Hayalet",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "835",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-835.png",
        "paint_name": "FAMAS | Koruyucu Renk",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "659",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-659.png",
        "paint_name": "FAMAS | Ölüm Dansı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "863",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-863.png",
        "paint_name": "FAMAS | Gece Bağları",
        "legacy_model": true
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "244",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-244.png",
        "paint_name": "FAMAS | Çöküş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "869",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-869.png",
        "paint_name": "FAMAS | Gün Batımı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "194",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-194.png",
        "paint_name": "FAMAS | Ateş Püskürten",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "22",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-22.png",
        "paint_name": "FAMAS | Kontrast",
        "legacy_model": false
    },
    {
        "weapon_defindex": 10,
        "weapon_name": "weapon_famas",
        "paint": "1302",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_famas-1302.png",
        "paint_name": "FAMAS | Palmiye",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven.png",
        "paint_name": "Five-SeveN | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "1002",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-1002.png",
        "paint_name": "Five-SeveN | Yaban Mersini Vişne",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "274",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-274.png",
        "paint_name": "Five-SeveN | Bakır Galaksi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "252",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-252.png",
        "paint_name": "Five-SeveN | Gümüş Kuvars",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "210",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-210.png",
        "paint_name": "Five-SeveN | Eloksal Bronz",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "352",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-352.png",
        "paint_name": "Five-SeveN | Av Şoku",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "831",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-831.png",
        "paint_name": "Five-SeveN | Eloksal Solmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "605",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-605.png",
        "paint_name": "Five-SeveN | Scoria",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-44.png",
        "paint_name": "Five-SeveN | Yüzey Sertleştirme",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "837",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-837.png",
        "paint_name": "Five-SeveN | Öfkeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "585",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-585.png",
        "paint_name": "Five-SeveN | Daimyo",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "979",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-979.png",
        "paint_name": "Five-SeveN | Masal Şatosu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "1128",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-1128.png",
        "paint_name": "Five-SeveN | Karalama",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "530",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-530.png",
        "paint_name": "Five-SeveN | Üçlü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "427",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-427.png",
        "paint_name": "Five-SeveN | Maymun İşi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "906",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-906.png",
        "paint_name": "Five-SeveN | Dost",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "660",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-660.png",
        "paint_name": "Five-SeveN | Canavar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "510",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-510.png",
        "paint_name": "Five-SeveN | Geçmişe Dönüş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "387",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-387.png",
        "paint_name": "Five-SeveN | Kent Tehlikesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "646",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-646.png",
        "paint_name": "Five-SeveN | Kılcal Damar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "1082",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-1082.png",
        "paint_name": "Five-SeveN | Düşme Tehlikesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "1168",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-1168.png",
        "paint_name": "Five-SeveN | Karışım",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "1093",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-1093.png",
        "paint_name": "Five-SeveN | Senkronizasyon",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "693",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-693.png",
        "paint_name": "Five-SeveN | Kızıl Tepkime",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "729",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-729.png",
        "paint_name": "Five-SeveN | Pembe Çiçek",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "784",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-784.png",
        "paint_name": "Five-SeveN | Soğutucu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "223",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-223.png",
        "paint_name": "Five-SeveN | Gece Gölgesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "78",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-78.png",
        "paint_name": "Five-SeveN | Gece Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "265",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-265.png",
        "paint_name": "Five-SeveN | Kami",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "464",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-464.png",
        "paint_name": "Five-SeveN | Neon Turuncu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "1062",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-1062.png",
        "paint_name": "Five-SeveN | Gece Yarısı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "377",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-377.png",
        "paint_name": "Five-SeveN | Sıcaklık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "151",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-151.png",
        "paint_name": "Five-SeveN | Orman",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "254",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-254.png",
        "paint_name": "Five-SeveN | Siyah Nitrit",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "46",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-46.png",
        "paint_name": "Five-SeveN | Paralı Asker",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "3",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-3.png",
        "paint_name": "Five-SeveN | Kırmızı Elma",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "1262",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-1262.png",
        "paint_name": "Five-SeveN | Mavi Gökyüzü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "1336",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-1336.png",
        "paint_name": "Five-SeveN | Sonbahar",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "932",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-932.png",
        "paint_name": "Five-SeveN | Mor Salkım",
        "legacy_model": false
    },
    {
        "weapon_defindex": 3,
        "weapon_name": "weapon_fiveseven",
        "paint": "141",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_fiveseven-141.png",
        "paint_name": "Five-SeveN | Turuncu Kabuk",
        "legacy_model": false
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1.png",
        "paint_name": "G3SG1 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "1034",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-1034.png",
        "paint_name": "G3SG1 | Antik Ritüel",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "382",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-382.png",
        "paint_name": "G3SG1 | Kara Leopar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "739",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-739.png",
        "paint_name": "G3SG1 | Menekşe Murano",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "438",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-438.png",
        "paint_name": "G3SG1 | Chronos",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "891",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-891.png",
        "paint_name": "G3SG1 | Siyah Kum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "511",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-511.png",
        "paint_name": "G3SG1 | İnfazcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "1129",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-1129.png",
        "paint_name": "G3SG1 | Rüya Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "1095",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-1095.png",
        "paint_name": "G3SG1 | Antrenman Haritası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "712",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-712.png",
        "paint_name": "G3SG1 | Açık Deniz",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "677",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-677.png",
        "paint_name": "G3SG1 | Avcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "980",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-980.png",
        "paint_name": "G3SG1 | Kan Revan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "493",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-493.png",
        "paint_name": "G3SG1 | Akı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "806",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-806.png",
        "paint_name": "G3SG1 | Arındırıcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "606",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-606.png",
        "paint_name": "G3SG1 | Ventilatör",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "628",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-628.png",
        "paint_name": "G3SG1 | İğne",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "74",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-74.png",
        "paint_name": "G3SG1 | Kutup Kamuflajı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "6",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-6.png",
        "paint_name": "G3SG1 | Kutup Esintisi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "195",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-195.png",
        "paint_name": "G3SG1 | Bereket",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "8",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-8.png",
        "paint_name": "G3SG1 | Çöl Fırtınası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "465",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-465.png",
        "paint_name": "G3SG1 | Neon Turuncu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "235",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-235.png",
        "paint_name": "G3SG1 | Hibrit Kamuflaj",
        "legacy_model": true
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "294",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-294.png",
        "paint_name": "G3SG1 | Yeşil Elma",
        "legacy_model": false
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "46",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-46.png",
        "paint_name": "G3SG1 | Paralı Asker",
        "legacy_model": false
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "1328",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-1328.png",
        "paint_name": "G3SG1 | Kırmızı Yeşim",
        "legacy_model": false
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "545",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-545.png",
        "paint_name": "G3SG1 | Turuncu Sızma",
        "legacy_model": false
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "1305",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-1305.png",
        "paint_name": "G3SG1 | Yeşil Hücre",
        "legacy_model": false
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-72.png",
        "paint_name": "G3SG1 | Av Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "930",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-930.png",
        "paint_name": "G3SG1 | Deniz Sarmaşığı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "147",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-147.png",
        "paint_name": "G3SG1 | Orman Çizgili",
        "legacy_model": false
    },
    {
        "weapon_defindex": 11,
        "weapon_name": "weapon_g3sg1",
        "paint": "229",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_g3sg1-229.png",
        "paint_name": "G3SG1 | Mavi Çizgili",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar.png",
        "paint_name": "Galil AR | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "246",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-246.png",
        "paint_name": "Galil AR | Kehribar Solmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "460",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-460.png",
        "paint_name": "Galil AR | Su Terası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "216",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-216.png",
        "paint_name": "Galil AR | Mavi Titanyum",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1178",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1178.png",
        "paint_name": "Galil AR | Gökkuşağı Kaşık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "379",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-379.png",
        "paint_name": "Galil AR | Cehennem Bekçisi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "398",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-398.png",
        "paint_name": "Galil AR | Gevezelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "629",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-629.png",
        "paint_name": "Galil AR | Siyah Kum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "661",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-661.png",
        "paint_name": "Galil AR | Şeker",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1038",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1038.png",
        "paint_name": "Galil AR | Vandal",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1147",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1147.png",
        "paint_name": "Galil AR | Yok Edici",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "428",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-428.png",
        "paint_name": "Galil AR | Bütçe",
        "legacy_model": true
    },
{
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "478",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-478.png",
        "paint_name": "Galil AR | Roket Dondurma",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "939",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-939.png",
        "paint_name": "Galil AR | NV",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "264",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-264.png",
        "paint_name": "Galil AR | Kum Fırtınası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1185",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1185.png",
        "paint_name": "Galil AR | Kontrol",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "494",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-494.png",
        "paint_name": "Galil AR | Soğuk Taş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "972",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-972.png",
        "paint_name": "Galil AR | Anka Şirketi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "981",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-981.png",
        "paint_name": "Galil AR | Vandal",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "546",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-546.png",
        "paint_name": "Galil AR | Ateş Hattı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "192",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-192.png",
        "paint_name": "Galil AR | Parçalanmış",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "83",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-83.png",
        "paint_name": "Galil AR | Turuncu DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "76",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-76.png",
        "paint_name": "Galil AR | Kış Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "308",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-308.png",
        "paint_name": "Galil AR | Kami",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "807",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-807.png",
        "paint_name": "Galil AR | Sinyal",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "790",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-790.png",
        "paint_name": "Galil AR | Soğuk Füzyon",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1032",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1032.png",
        "paint_name": "Galil AR | Alacakaranlık Kalıntıları",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "235",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-235.png",
        "paint_name": "Galil AR | Varyant Kamuflaj",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "237",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-237.png",
        "paint_name": "Galil AR | Kentsel Enkaz",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1296",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1296.png",
        "paint_name": "Galil AR | Asit Dağlama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "294",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-294.png",
        "paint_name": "Galil AR | Yeşil Elma",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "297",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-297.png",
        "paint_name": "Galil AR | Kırlangıç Kuyruğu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "101",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-101.png",
        "paint_name": "Galil AR | Kum Fırtınası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1275",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1275.png",
        "paint_name": "Galil AR | Gri Pus",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1314",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1314.png",
        "paint_name": "Galil AR | Kan Portakalı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1264",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1264.png",
        "paint_name": "Galil AR | Nar Bülbülü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "842",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-842.png",
        "paint_name": "Galil AR | Çizgili",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1071",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1071.png",
        "paint_name": "Galil AR | Dikkat!",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "647",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-647.png",
        "paint_name": "Galil AR | Kızıl Tsunami",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "241",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-241.png",
        "paint_name": "Galil AR | Avcı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "239",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-239.png",
        "paint_name": "Galil AR | Aşındırıcı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "1013",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-1013.png",
        "paint_name": "Galil AR | Anka Siyahı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 13,
        "weapon_name": "weapon_galilar",
        "paint": "119",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_galilar-119.png",
        "paint_name": "Galil AR | Adaçayı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock.png",
        "paint_name": "Glock-18 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-38.png",
        "paint_name": "Glock-18 | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "694",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-694.png",
        "paint_name": "Glock-18 | Şehir Işıkları",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "799",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-799.png",
        "paint_name": "Glock-18 | Uzun Farlar",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "437",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-437.png",
        "paint_name": "Glock-18 | Alacakaranlık Galaksisi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "230",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-230.png",
        "paint_name": "Glock-18 | Demir Kafes",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "48",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-48.png",
        "paint_name": "Glock-18 | Ejderha Dövmesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1119",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1119.png",
        "paint_name": "Glock-18 | Gama Doppler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1120",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1120.png",
        "paint_name": "Glock-18 | Gama Doppler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1121",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1121.png",
        "paint_name": "Glock-18 | Gama Doppler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1122",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1122.png",
        "paint_name": "Glock-18 | Gama Doppler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1123",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1123.png",
        "paint_name": "Glock-18 | Gama Doppler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "367",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-367.png",
        "paint_name": "Glock-18 | Reaksiyon",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "789",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-789.png",
        "paint_name": "Glock-18 | Nükleer Bahçe",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "159",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-159.png",
        "paint_name": "Glock-18 | Pirinç",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "479",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-479.png",
        "paint_name": "Glock-18 | Bunsen Beki",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "381",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-381.png",
        "paint_name": "Glock-18 | Öğütücü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "623",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-623.png",
        "paint_name": "Glock-18 | Demir İşleme",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "353",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-353.png",
        "paint_name": "Glock-18 | Su Elementi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "808",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-808.png",
        "paint_name": "Glock-18 | Oksit Alevi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "957",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-957.png",
        "paint_name": "Glock-18 | Mermi Kraliçesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "607",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-607.png",
        "paint_name": "Glock-18 | Gelincik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "399",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-399.png",
        "paint_name": "Glock-18 | Ölünün Mezarı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "963",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-963.png",
        "paint_name": "Glock-18 | Moda",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "918",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-918.png",
        "paint_name": "Glock-18 | Nükleer Karışım",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "680",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-680.png",
        "paint_name": "Glock-18 | Dışı Seni Yakar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1227",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1227.png",
        "paint_name": "Glock-18 | Yeşim Tavşan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "988",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-988.png",
        "paint_name": "Glock-18 | Karanlık El",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1240",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1240.png",
        "paint_name": "Glock-18 | Ramses'in Dokunuşu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1100",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1100.png",
        "paint_name": "Glock-18 | Atıştırmalık Zamanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "586",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-586.png",
        "paint_name": "Glock-18 | Çöl İsyancısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1016",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1016.png",
        "paint_name": "Glock-18 | Franklin",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1167",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1167.png",
        "paint_name": "Glock-18 | Blok-18",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "129",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-129.png",
        "paint_name": "Glock-18 | Altın Diş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1348",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1348.png",
        "paint_name": "Glock-18 | Aynalı Mozaik",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1208",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1208.png",
        "paint_name": "Glock-18 | Umbral Tavşan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1200",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1200.png",
        "paint_name": "Glock-18 | Yeşil Çizgi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "532",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-532.png",
        "paint_name": "Glock-18 | Kraliyet Alayı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "495",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-495.png",
        "paint_name": "Glock-18 | Hayalet",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1158",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1158.png",
        "paint_name": "Glock-18 | Kış Saldırısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1039",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1039.png",
        "paint_name": "Glock-18 | Netlik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "713",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-713.png",
        "paint_name": "Glock-18 | Savaş Şahini",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "832",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-832.png",
        "paint_name": "Glock-18 | Kurban",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "278",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-278.png",
        "paint_name": "Glock-18 | Mavi Çatlak",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "84",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-84.png",
        "paint_name": "Glock-18 | Pembe DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "732",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-732.png",
        "paint_name": "Glock-18 | Sentetik Yaprak",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "293",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-293.png",
        "paint_name": "Glock-18 | Ölüm Saçan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "152",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-152.png",
        "paint_name": "Glock-18 | Çamurcun Girdap",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1265",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1265.png",
        "paint_name": "Glock-18 | Derin Deniz",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-40.png",
        "paint_name": "Glock-18 | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "2",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-2.png",
        "paint_name": "Glock-18 | Yer Altı Suyu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "3",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-3.png",
        "paint_name": "Glock-18 | Elma Şekeri",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "208",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-208.png",
        "paint_name": "Glock-18 | Kum Rengi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1312",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1312.png",
        "paint_name": "Glock-18 | Mercan Tokası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1079",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1079.png",
        "paint_name": "Glock-18 | Kırmızı Lastik",
        "legacy_model": false
    },
    {
        "weapon_defindex": 4,
        "weapon_name": "weapon_glock",
        "paint": "1282",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_glock-1282.png",
        "paint_name": "Glock-18 | Nar Bülbülü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000.png",
        "paint_name": "P2000 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "246",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-246.png",
        "paint_name": "P2000 | Amber Fades",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "1055",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-1055.png",
        "paint_name": "P2000 | Uzay Yarışı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "1019",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-1019.png",
        "paint_name": "P2000 | Panter",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "327",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-327.png",
        "paint_name": "P2000 | Örme Zırh",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "997",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-997.png",
        "paint_name": "P2000 | Sevk",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "211",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-211.png",
        "paint_name": "P2000 | Okyanus Köpüğü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "515",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-515.png",
        "paint_name": "P2000 | İmparatorluk",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "71",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-71.png",
        "paint_name": "P2000 | Akrep",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "32",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-32.png",
        "paint_name": "P2000 | Gümüş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "951",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-951.png",
        "paint_name": "P2000 | Dağlama",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "485",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-485.png",
        "paint_name": "P2000 | El Topu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "960",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-960.png",
        "paint_name": "P2000 | Sarmaşık",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "184",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-184.png",
        "paint_name": "P2000 | Mercan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "346",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-346.png",
        "paint_name": "P2000 | Ucuz Deri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "1224",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-1224.png",
        "paint_name": "P2000 | Saplantı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "389",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-389.png",
        "paint_name": "P2000 | Ateş Elementi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "667",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-667.png",
        "paint_name": "P2000 | Orman Çatışması",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "357",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-357.png",
        "paint_name": "P2000 | Fildişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "894",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-894.png",
        "paint_name": "P2000 | Obsidyen",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "338",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-338.png",
        "paint_name": "P2000 | Nabız",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "700",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-700.png",
        "paint_name": "P2000 | Şehir Tehlikesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "1138",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-1138.png",
        "paint_name": "P2000 | Göğe Yükseliş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "635",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-635.png",
        "paint_name": "P2000 | Çim",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "591",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-591.png",
        "paint_name": "P2000 | Ejderha",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "878",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-878.png",
        "paint_name": "P2000 | Mercan Grisi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "21",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-21.png",
        "paint_name": "P2000 | Granit",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "550",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-550.png",
        "paint_name": "P2000 | Okyanus",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "275",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-275.png",
        "paint_name": "P2000 | Kızıl Parçacık",
        "legacy_model": true
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "1342",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-1342.png",
        "paint_name": "P2000 | Red Wing",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "1181",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-1181.png",
        "paint_name": "P2000 | Kaymaz Kabza",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "95",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-95.png",
        "paint_name": "P2000 | Çayır",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "1292",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-1292.png",
        "paint_name": "P2000 | Sulak Alan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "443",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-443.png",
        "paint_name": "P2000 | Yol Bulucu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "104",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-104.png",
        "paint_name": "P2000 | Çayır Yaprakları",
        "legacy_model": false
    },
    {
        "weapon_defindex": 32,
        "weapon_name": "weapon_hkp2000",
        "paint": "1259",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_hkp2000-1259.png",
        "paint_name": "P2000 | İmparatorluk Baroku",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly.png",
        "paint_name": "Kelebek Bıçak (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-38.png",
        "paint_name": "Kelebek Bıçak (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "617",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-617.png",
        "paint_name": "Kelebek Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-418.png",
        "paint_name": "Kelebek Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "618",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-618.png",
        "paint_name": "Kelebek Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-420.png",
        "paint_name": "Kelebek Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-421.png",
        "paint_name": "Kelebek Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-568.png",
        "paint_name": "Kelebek Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-569.png",
        "paint_name": "Kelebek Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-570.png",
        "paint_name": "Kelebek Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-571.png",
        "paint_name": "Kelebek Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-572.png",
        "paint_name": "Kelebek Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-413.png",
        "paint_name": "Kelebek Bıçak (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "581",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-581.png",
        "paint_name": "Kelebek Bıçak (★) | Özgür Ruh",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-415.png",
        "paint_name": "Kelebek Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "619",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-619.png",
        "paint_name": "Kelebek Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-59.png",
        "paint_name": "Kelebek Bıçak (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-409.png",
        "paint_name": "Kelebek Bıçak (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-42.png",
        "paint_name": "Kelebek Bıçak (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "411",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-411.png",
        "paint_name": "Kelebek Bıçak (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-43.png",
        "paint_name": "Kelebek Bıçak (★) | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-44.png",
        "paint_name": "Kelebek Bıçak (★) | Alacalı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-414.png",
        "paint_name": "Kelebek Bıçak (★) | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "1105",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-1105.png",
        "paint_name": "Kelebek Bıçak (★) | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "1115",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-1115.png",
        "paint_name": "Kelebek Bıçak (★) | Otokrom",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "1110",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-1110.png",
        "paint_name": "Kelebek Bıçak (★) | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-5.png",
        "paint_name": "Kelebek Bıçak (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-77.png",
        "paint_name": "Kelebek Bıçak (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "579",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-579.png",
        "paint_name": "Kelebek Bıçak (★) | Berrak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-12.png",
        "paint_name": "Kelebek Bıçak (★) | Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-40.png",
        "paint_name": "Kelebek Bıçak (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-98.png",
        "paint_name": "Kelebek Bıçak (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-175.png",
        "paint_name": "Kelebek Bıçak (★) | Yanık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-72.png",
        "paint_name": "Kelebek Bıçak (★) | Ağ Camgöbeği",
        "legacy_model": false
    },
    {
        "weapon_defindex": 515,
        "weapon_name": "weapon_knife_butterfly",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_butterfly-143.png",
        "paint_name": "Kelebek Bıçak (★) | Şehir Kamoflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-38.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-417.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-418.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-419.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-420.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-421.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-413.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-415.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-416.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-59.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-409.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-42.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "410",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-410.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-43.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-44.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Alacalı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-414.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-5.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-77.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-12.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-98.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-175.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Yanık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-72.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Ağ Camgöbeği",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "735",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-735.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 518,
        "weapon_name": "weapon_knife_canis",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_canis-143.png",
        "paint_name": "Hayatta Kalma Bıçağı (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord.png",
        "paint_name": "Paracord Bıçak (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-38.png",
        "paint_name": "Paracord Bıçak (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-417.png",
        "paint_name": "Paracord Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-418.png",
        "paint_name": "Paracord Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-419.png",
        "paint_name": "Paracord Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-420.png",
        "paint_name": "Paracord Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-421.png",
        "paint_name": "Paracord Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-413.png",
        "paint_name": "Paracord Bıçak (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-415.png",
        "paint_name": "Paracord Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-416.png",
        "paint_name": "Paracord Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-59.png",
        "paint_name": "Paracord Bıçak (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-409.png",
        "paint_name": "Paracord Bıçak (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-42.png",
        "paint_name": "Paracord Bıçak (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "410",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-410.png",
        "paint_name": "Paracord Bıçak (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-43.png",
        "paint_name": "Paracord Bıçak (★) | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-44.png",
        "paint_name": "Paracord Bıçak (★) | Alacalı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-414.png",
        "paint_name": "Paracord Bıçak (★) | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-5.png",
        "paint_name": "Paracord Bıçak (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-77.png",
        "paint_name": "Paracord Bıçak (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-12.png",
        "paint_name": "Paracord Bıçak (★) | Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "621",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-621.png",
        "paint_name": "Paracord Bıçak (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-175.png",
        "paint_name": "Paracord Bıçak (★) | Yanık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-72.png",
        "paint_name": "Paracord Bıçak (★) | Ağ Camgöbeği",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "735",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-735.png",
        "paint_name": "Paracord Bıçak (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 517,
        "weapon_name": "weapon_knife_cord",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_cord-143.png",
        "paint_name": "Paracord Bıçak (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css.png",
        "paint_name": "Klasik Bıçak (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-38.png",
        "paint_name": "Klasik Bıçak (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-59.png",
        "paint_name": "Klasik Bıçak (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-42.png",
        "paint_name": "Klasik Bıçak (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-43.png",
        "paint_name": "Klasik Bıçak (★) | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-44.png",
        "paint_name": "Klasik Bıçak (★) | Alacalı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-5.png",
        "paint_name": "Klasik Bıçak (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-77.png",
        "paint_name": "Klasik Bıçak (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-12.png",
        "paint_name": "Klasik Bıçak (★) | Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-175.png",
        "paint_name": "Klasik Bıçak (★) | Yanık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-72.png",
        "paint_name": "Klasik Bıçak (★) | Ağ Camgöbeği",
        "legacy_model": false
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "735",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-735.png",
        "paint_name": "Klasik Bıçak (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 503,
        "weapon_name": "weapon_knife_css",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_css-143.png",
        "paint_name": "Klasik Bıçak (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion.png",
        "paint_name": "Pala (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-38.png",
        "paint_name": "Pala (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-417.png",
        "paint_name": "Pala (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-418.png",
        "paint_name": "Pala (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-419.png",
        "paint_name": "Pala (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-420.png",
        "paint_name": "Pala (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-421.png",
        "paint_name": "Pala (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-568.png",
        "paint_name": "Pala (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-569.png",
        "paint_name": "Pala (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-570.png",
        "paint_name": "Pala (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-571.png",
        "paint_name": "Pala (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-572.png",
        "paint_name": "Pala (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-413.png",
        "paint_name": "Pala (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "581",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-581.png",
        "paint_name": "Pala (★) | Özgür Ruh",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-415.png",
        "paint_name": "Pala (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-416.png",
        "paint_name": "Pala (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-59.png",
        "paint_name": "Pala (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-409.png",
        "paint_name": "Pala (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-42.png",
        "paint_name": "Pala (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "411",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-411.png",
        "paint_name": "Pala (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-43.png",
        "paint_name": "Pala (★) | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-44.png",
        "paint_name": "Pala (★) | Alacalı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-414.png",
        "paint_name": "Pala (★) | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "1106",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-1106.png",
        "paint_name": "Pala (★) | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "1116",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-1116.png",
        "paint_name": "Pala (★) | Otokrom",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "1111",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-1111.png",
        "paint_name": "Pala (★) | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-5.png",
        "paint_name": "Pala (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-77.png",
        "paint_name": "Pala (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "579",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-579.png",
        "paint_name": "Pala (★) | Berrak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-12.png",
        "paint_name": "Pala (★) | Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-40.png",
        "paint_name": "Pala (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "621",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-621.png",
        "paint_name": "Pala (★) | Ultraviyole",
        "legacy_model": false
    },
{
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-175.png",
        "paint_name": "Pala (★) | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-72.png",
        "paint_name": "Pala (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 512,
        "weapon_name": "weapon_knife_falchion",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_falchion-143.png",
        "paint_name": "Pala (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip.png",
        "paint_name": "Sustalı Bıçak (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-38.png",
        "paint_name": "Sustalı Bıçak (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-417.png",
        "paint_name": "Sustalı Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-418.png",
        "paint_name": "Sustalı Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-419.png",
        "paint_name": "Sustalı Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-420.png",
        "paint_name": "Sustalı Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-421.png",
        "paint_name": "Sustalı Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-568.png",
        "paint_name": "Sustalı Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-569.png",
        "paint_name": "Sustalı Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-570.png",
        "paint_name": "Sustalı Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-571.png",
        "paint_name": "Sustalı Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-572.png",
        "paint_name": "Sustalı Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-413.png",
        "paint_name": "Sustalı Bıçak (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "580",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-580.png",
        "paint_name": "Sustalı Bıçak (★) | Serbest Stil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-415.png",
        "paint_name": "Sustalı Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-416.png",
        "paint_name": "Sustalı Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-59.png",
        "paint_name": "Sustalı Bıçak (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-409.png",
        "paint_name": "Sustalı Bıçak (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-42.png",
        "paint_name": "Sustalı Bıçak (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "410",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-410.png",
        "paint_name": "Sustalı Bıçak (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-43.png",
        "paint_name": "Sustalı Bıçak (★) | Ultraviyole",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-44.png",
        "paint_name": "Sustalı Bıçak (★) | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-414.png",
        "paint_name": "Sustalı Bıçak (★) | Paslı Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "559",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-559.png",
        "paint_name": "Sustalı Bıçak (★) | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "564",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-564.png",
        "paint_name": "Sustalı Bıçak (★) | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "574",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-574.png",
        "paint_name": "Sustalı Bıçak (★) | Otokratik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-5.png",
        "paint_name": "Sustalı Bıçak (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-77.png",
        "paint_name": "Sustalı Bıçak (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "578",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-578.png",
        "paint_name": "Sustalı Bıçak (★) | Berrak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-12.png",
        "paint_name": "Sustalı Bıçak (★) | Katliam Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-40.png",
        "paint_name": "Sustalı Bıçak (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-98.png",
        "paint_name": "Sustalı Bıçak (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-175.png",
        "paint_name": "Sustalı Bıçak (★) | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-72.png",
        "paint_name": "Sustalı Bıçak (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 505,
        "weapon_name": "weapon_knife_flip",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_flip-143.png",
        "paint_name": "Sustalı Bıçak (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut.png",
        "paint_name": "Pala Bıçak (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-38.png",
        "paint_name": "Pala Bıçak (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-417.png",
        "paint_name": "Pala Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-418.png",
        "paint_name": "Pala Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-419.png",
        "paint_name": "Pala Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-420.png",
        "paint_name": "Pala Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-421.png",
        "paint_name": "Pala Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-568.png",
        "paint_name": "Pala Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-569.png",
        "paint_name": "Pala Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-570.png",
        "paint_name": "Pala Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-571.png",
        "paint_name": "Pala Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-572.png",
        "paint_name": "Pala Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-413.png",
        "paint_name": "Pala Bıçak (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "580",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-580.png",
        "paint_name": "Pala Bıçak (★) | Serbest Stil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-415.png",
        "paint_name": "Pala Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-416.png",
        "paint_name": "Pala Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-59.png",
        "paint_name": "Pala Bıçak (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-409.png",
        "paint_name": "Pala Bıçak (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-42.png",
        "paint_name": "Pala Bıçak (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "410",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-410.png",
        "paint_name": "Pala Bıçak (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-43.png",
        "paint_name": "Pala Bıçak (★) | Ultraviyole",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-44.png",
        "paint_name": "Pala Bıçak (★) | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-414.png",
        "paint_name": "Pala Bıçak (★) | Paslı Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "560",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-560.png",
        "paint_name": "Pala Bıçak (★) | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "565",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-565.png",
        "paint_name": "Pala Bıçak (★) | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "575",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-575.png",
        "paint_name": "Pala Bıçak (★) | Otokratik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-5.png",
        "paint_name": "Pala Bıçak (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-77.png",
        "paint_name": "Pala Bıçak (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "578",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-578.png",
        "paint_name": "Pala Bıçak (★) | Berrak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-12.png",
        "paint_name": "Pala Bıçak (★) | Katliam Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-40.png",
        "paint_name": "Pala Bıçak (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-98.png",
        "paint_name": "Pala Bıçak (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-175.png",
        "paint_name": "Pala Bıçak (★) | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-72.png",
        "paint_name": "Pala Bıçak (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 506,
        "weapon_name": "weapon_knife_gut",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gut-143.png",
        "paint_name": "Pala Bıçak (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife.png",
        "paint_name": "Navaja (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-38.png",
        "paint_name": "Navaja (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-417.png",
        "paint_name": "Navaja (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-418.png",
        "paint_name": "Navaja (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-419.png",
        "paint_name": "Navaja (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-420.png",
        "paint_name": "Navaja (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-421.png",
        "paint_name": "Navaja (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-413.png",
        "paint_name": "Navaja (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-415.png",
        "paint_name": "Navaja (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-416.png",
        "paint_name": "Navaja (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-59.png",
        "paint_name": "Navaja (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-409.png",
        "paint_name": "Navaja (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-42.png",
        "paint_name": "Navaja (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "857",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-857.png",
        "paint_name": "Navaja (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-43.png",
        "paint_name": "Navaja (★) | Ultraviyole",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-44.png",
        "paint_name": "Navaja (★) | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-414.png",
        "paint_name": "Navaja (★) | Paslı Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-5.png",
        "paint_name": "Navaja (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-77.png",
        "paint_name": "Navaja (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-12.png",
        "paint_name": "Navaja (★) | Katliam Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-98.png",
        "paint_name": "Navaja (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-175.png",
        "paint_name": "Navaja (★) | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-72.png",
        "paint_name": "Navaja (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "735",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-735.png",
        "paint_name": "Navaja (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 520,
        "weapon_name": "weapon_knife_gypsy_jackknife",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_gypsy_jackknife-143.png",
        "paint_name": "Navaja (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit.png",
        "paint_name": "Karambit (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-38.png",
        "paint_name": "Karambit (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-417.png",
        "paint_name": "Karambit (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-418.png",
        "paint_name": "Karambit (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-419.png",
        "paint_name": "Karambit (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-420.png",
        "paint_name": "Karambit (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-421.png",
        "paint_name": "Karambit (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-568.png",
        "paint_name": "Karambit (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-569.png",
        "paint_name": "Karambit (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-570.png",
        "paint_name": "Karambit (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-571.png",
        "paint_name": "Karambit (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-572.png",
        "paint_name": "Karambit (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-413.png",
        "paint_name": "Karambit (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "582",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-582.png",
        "paint_name": "Karambit (★) | Serbest Stil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-415.png",
        "paint_name": "Karambit (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-416.png",
        "paint_name": "Karambit (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-59.png",
        "paint_name": "Karambit (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-409.png",
        "paint_name": "Karambit (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-42.png",
        "paint_name": "Karambit (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "410",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-410.png",
        "paint_name": "Karambit (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-43.png",
        "paint_name": "Karambit (★) | Ultraviyole",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-44.png",
        "paint_name": "Karambit (★) | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-414.png",
        "paint_name": "Karambit (★) | Paslı Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "561",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-561.png",
        "paint_name": "Karambit (★) | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "566",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-566.png",
        "paint_name": "Karambit (★) | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "576",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-576.png",
        "paint_name": "Karambit (★) | Otokratik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-5.png",
        "paint_name": "Karambit (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-77.png",
        "paint_name": "Karambit (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "578",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-578.png",
        "paint_name": "Karambit (★) | Berrak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-12.png",
        "paint_name": "Karambit (★) | Katliam Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-40.png",
        "paint_name": "Karambit (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-98.png",
        "paint_name": "Karambit (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-175.png",
        "paint_name": "Karambit (★) | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-72.png",
        "paint_name": "Karambit (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 507,
        "weapon_name": "weapon_knife_karambit",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_karambit-143.png",
        "paint_name": "Karambit (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri.png",
        "paint_name": "Kukri (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-38.png",
        "paint_name": "Kukri (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-59.png",
        "paint_name": "Kukri (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-42.png",
        "paint_name": "Kukri (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-43.png",
        "paint_name": "Kukri (★) | Ultraviyole",
        "legacy_model": true
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-44.png",
        "paint_name": "Kukri (★) | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-5.png",
        "paint_name": "Kukri (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-77.png",
        "paint_name": "Kukri (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-12.png",
        "paint_name": "Kukri (★) | Katliam Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-175.png",
        "paint_name": "Kukri (★) | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-72.png",
        "paint_name": "Kukri (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "735",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-735.png",
        "paint_name": "Kukri (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 526,
        "weapon_name": "weapon_knife_kukri",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_kukri-143.png",
        "paint_name": "Kukri (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet.png",
        "paint_name": "M9 Süngü (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-38.png",
        "paint_name": "M9 Süngü (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-417.png",
        "paint_name": "M9 Süngü (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-418.png",
        "paint_name": "M9 Süngü (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-419.png",
        "paint_name": "M9 Süngü (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-420.png",
        "paint_name": "M9 Süngü (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-421.png",
        "paint_name": "M9 Süngü (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-568.png",
        "paint_name": "M9 Süngü (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-569.png",
        "paint_name": "M9 Süngü (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-570.png",
        "paint_name": "M9 Süngü (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-571.png",
        "paint_name": "M9 Süngü (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-572.png",
        "paint_name": "M9 Süngü (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-413.png",
        "paint_name": "M9 Süngü (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "581",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-581.png",
        "paint_name": "M9 Süngü (★) | Serbest Stil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-415.png",
        "paint_name": "M9 Süngü (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-416.png",
        "paint_name": "M9 Süngü (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-59.png",
        "paint_name": "M9 Süngü (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-409.png",
        "paint_name": "M9 Süngü (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-42.png",
        "paint_name": "M9 Süngü (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "411",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-411.png",
        "paint_name": "M9 Süngü (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-43.png",
        "paint_name": "M9 Süngü (★) | Ultraviyole",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-44.png",
        "paint_name": "M9 Süngü (★) | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-414.png",
        "paint_name": "M9 Süngü (★) | Paslı Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "562",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-562.png",
        "paint_name": "M9 Süngü (★) | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "567",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-567.png",
        "paint_name": "M9 Süngü (★) | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "577",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-577.png",
        "paint_name": "M9 Süngü (★) | Otokratik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-5.png",
        "paint_name": "M9 Süngü (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-77.png",
        "paint_name": "M9 Süngü (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "579",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-579.png",
        "paint_name": "M9 Süngü (★) | Berrak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-12.png",
        "paint_name": "M9 Süngü (★) | Katliam Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-40.png",
        "paint_name": "M9 Süngü (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-98.png",
        "paint_name": "M9 Süngü (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-175.png",
        "paint_name": "M9 Süngü (★) | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-72.png",
        "paint_name": "M9 Süngü (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 508,
        "weapon_name": "weapon_knife_m9_bayonet",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_m9_bayonet-143.png",
        "paint_name": "M9 Süngü (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor.png",
        "paint_name": "Göçebe Bıçağı (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-38.png",
        "paint_name": "Göçebe Bıçağı (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-417.png",
        "paint_name": "Göçebe Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-418.png",
        "paint_name": "Göçebe Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-419.png",
        "paint_name": "Göçebe Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-420.png",
        "paint_name": "Göçebe Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-421.png",
        "paint_name": "Göçebe Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-413.png",
        "paint_name": "Göçebe Bıçağı (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-415.png",
        "paint_name": "Göçebe Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-416.png",
        "paint_name": "Göçebe Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-59.png",
        "paint_name": "Göçebe Bıçağı (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-409.png",
        "paint_name": "Göçebe Bıçağı (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-42.png",
        "paint_name": "Göçebe Bıçağı (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "410",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-410.png",
        "paint_name": "Göçebe Bıçağı (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-43.png",
        "paint_name": "Göçebe Bıçağı (★) | Ultraviyole",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-44.png",
        "paint_name": "Göçebe Bıçağı (★) | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-414.png",
        "paint_name": "Göçebe Bıçağı (★) | Paslı Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-5.png",
        "paint_name": "Göçebe Bıçağı (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-77.png",
        "paint_name": "Göçebe Bıçağı (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-12.png",
        "paint_name": "Göçebe Bıçağı (★) | Katliam Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-98.png",
        "paint_name": "Göçebe Bıçağı (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-175.png",
        "paint_name": "Göçebe Bıçağı (★) | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-72.png",
        "paint_name": "Göçebe Bıçağı (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "735",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-735.png",
        "paint_name": "Göçebe Bıçağı (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 521,
        "weapon_name": "weapon_knife_outdoor",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_outdoor-143.png",
        "paint_name": "Göçebe Bıçağı (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push.png",
        "paint_name": "Gölge Hançerler (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-38.png",
        "paint_name": "Gölge Hançerler (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "617",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-617.png",
        "paint_name": "Gölge Hançerler (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-418.png",
        "paint_name": "Gölge Hançerler (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "618",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-618.png",
        "paint_name": "Gölge Hançerler (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-420.png",
        "paint_name": "Gölge Hançerler (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-421.png",
        "paint_name": "Gölge Hançerler (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-568.png",
        "paint_name": "Gölge Hançerler (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-569.png",
        "paint_name": "Gölge Hançerler (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-570.png",
        "paint_name": "Gölge Hançerler (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-571.png",
        "paint_name": "Gölge Hançerler (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-572.png",
        "paint_name": "Gölge Hançerler (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-413.png",
        "paint_name": "Gölge Hançerler (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "581",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-581.png",
        "paint_name": "Gölge Hançerler (★) | Serbest Stil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-415.png",
        "paint_name": "Gölge Hançerler (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "619",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-619.png",
        "paint_name": "Gölge Hançerler (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-59.png",
        "paint_name": "Gölge Hançerler (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-409.png",
        "paint_name": "Gölge Hançerler (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-42.png",
        "paint_name": "Gölge Hançerler (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "411",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-411.png",
        "paint_name": "Gölge Hançerler (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-43.png",
        "paint_name": "Gölge Hançerler (★) | Ultraviyole",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-44.png",
        "paint_name": "Gölge Hançerler (★) | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-414.png",
        "paint_name": "Gölge Hançerler (★) | Paslı Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "1108",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-1108.png",
        "paint_name": "Gölge Hançerler (★) | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "1118",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-1118.png",
        "paint_name": "Gölge Hançerler (★) | Otokratik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "1113",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-1113.png",
        "paint_name": "Gölge Hançerler (★) | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-5.png",
        "paint_name": "Gölge Hançerler (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-77.png",
        "paint_name": "Gölge Hançerler (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "579",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-579.png",
        "paint_name": "Gölge Hançerler (★) | Berrak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-12.png",
        "paint_name": "Gölge Hançerler (★) | Katliam Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-40.png",
        "paint_name": "Gölge Hançerler (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-98.png",
        "paint_name": "Gölge Hançerler (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-175.png",
        "paint_name": "Gölge Hançerler (★) | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-72.png",
        "paint_name": "Gölge Hançerler (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 516,
        "weapon_name": "weapon_knife_push",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_push-143.png",
        "paint_name": "Gölge Hançerler (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton.png",
        "paint_name": "İskelet Bıçak (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-38.png",
        "paint_name": "İskelet Bıçak (★) | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-417.png",
        "paint_name": "İskelet Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-418.png",
        "paint_name": "İskelet Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-419.png",
        "paint_name": "İskelet Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-420.png",
        "paint_name": "İskelet Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-421.png",
        "paint_name": "İskelet Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-568.png",
        "paint_name": "İskelet Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-569.png",
        "paint_name": "İskelet Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-570.png",
        "paint_name": "İskelet Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-571.png",
        "paint_name": "İskelet Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-572.png",
        "paint_name": "İskelet Bıçak (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-413.png",
        "paint_name": "İskelet Bıçak (★) | Mermer Solgun",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "581",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-581.png",
        "paint_name": "İskelet Bıçak (★) | Serbest Stil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-415.png",
        "paint_name": "İskelet Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-416.png",
        "paint_name": "İskelet Bıçak (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-59.png",
        "paint_name": "İskelet Bıçak (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-409.png",
        "paint_name": "İskelet Bıçak (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-42.png",
        "paint_name": "İskelet Bıçak (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "411",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-411.png",
        "paint_name": "İskelet Bıçak (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-43.png",
        "paint_name": "İskelet Bıçak (★) | Ultraviyole",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-44.png",
        "paint_name": "İskelet Bıçak (★) | Sertleştirilmiş Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-414.png",
        "paint_name": "İskelet Bıçak (★) | Paslı Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "562",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-562.png",
        "paint_name": "İskelet Bıçak (★) | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "567",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-567.png",
        "paint_name": "İskelet Bıçak (★) | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "577",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-577.png",
        "paint_name": "İskelet Bıçak (★) | Otokratik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-5.png",
        "paint_name": "İskelet Bıçak (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-77.png",
        "paint_name": "İskelet Bıçak (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "579",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-579.png",
        "paint_name": "İskelet Bıçak (★) | Berrak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-12.png",
        "paint_name": "İskelet Bıçak (★) | Katliam Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-40.png",
        "paint_name": "İskelet Bıçak (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-98.png",
        "paint_name": "İskelet Bıçak (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-175.png",
        "paint_name": "İskelet Bıçak (★) | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-72.png",
        "paint_name": "İskelet Bıçak (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 525,
        "weapon_name": "weapon_knife_skeleton",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_skeleton-143.png",
        "paint_name": "İskelet Bıçak (★) | Şehir Kamuflajı",
        "legacy_model": false
    },
{
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto.png",
        "paint_name": "Stiletto Bıçağı (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-38.png",
        "paint_name": "Stiletto Bıçağı (★) | Solmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-417.png",
        "paint_name": "Stiletto Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-418.png",
        "paint_name": "Stiletto Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-419.png",
        "paint_name": "Stiletto Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-420.png",
        "paint_name": "Stiletto Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-421.png",
        "paint_name": "Stiletto Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-413.png",
        "paint_name": "Stiletto Bıçağı (★) | Mermer Solması",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-415.png",
        "paint_name": "Stiletto Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-416.png",
        "paint_name": "Stiletto Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-59.png",
        "paint_name": "Stiletto Bıçağı (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-409.png",
        "paint_name": "Stiletto Bıçağı (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-42.png",
        "paint_name": "Stiletto Bıçağı (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "857",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-857.png",
        "paint_name": "Stiletto Bıçağı (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-43.png",
        "paint_name": "Stiletto Bıçağı (★) | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-44.png",
        "paint_name": "Stiletto Bıçağı (★) | Isıl İşlem",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-414.png",
        "paint_name": "Stiletto Bıçağı (★) | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-5.png",
        "paint_name": "Stiletto Bıçağı (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-77.png",
        "paint_name": "Stiletto Bıçağı (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-12.png",
        "paint_name": "Stiletto Bıçağı (★) | Kızıl Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-98.png",
        "paint_name": "Stiletto Bıçağı (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-175.png",
        "paint_name": "Stiletto Bıçağı (★) | Alazlanmış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-72.png",
        "paint_name": "Stiletto Bıçağı (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "735",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-735.png",
        "paint_name": "Stiletto Bıçağı (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 522,
        "weapon_name": "weapon_knife_stiletto",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_stiletto-143.png",
        "paint_name": "Stiletto Bıçağı (★) | Kentsel Maske",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie.png",
        "paint_name": "Bowie Bıçağı (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-38.png",
        "paint_name": "Bowie Bıçağı (★) | Solmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-417.png",
        "paint_name": "Bowie Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-418.png",
        "paint_name": "Bowie Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-419.png",
        "paint_name": "Bowie Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-420.png",
        "paint_name": "Bowie Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-421.png",
        "paint_name": "Bowie Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-568.png",
        "paint_name": "Bowie Bıçağı (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-569.png",
        "paint_name": "Bowie Bıçağı (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-570.png",
        "paint_name": "Bowie Bıçağı (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-571.png",
        "paint_name": "Bowie Bıçağı (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-572.png",
        "paint_name": "Bowie Bıçağı (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-413.png",
        "paint_name": "Bowie Bıçağı (★) | Mermer Solması",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "581",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-581.png",
        "paint_name": "Bowie Bıçağı (★) | Serbest Stil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-415.png",
        "paint_name": "Bowie Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-416.png",
        "paint_name": "Bowie Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-59.png",
        "paint_name": "Bowie Bıçağı (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-409.png",
        "paint_name": "Bowie Bıçağı (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-42.png",
        "paint_name": "Bowie Bıçağı (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "411",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-411.png",
        "paint_name": "Bowie Bıçağı (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-43.png",
        "paint_name": "Bowie Bıçağı (★) | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-44.png",
        "paint_name": "Bowie Bıçağı (★) | Isıl İşlem",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-414.png",
        "paint_name": "Bowie Bıçağı (★) | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "1104",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-1104.png",
        "paint_name": "Bowie Bıçağı (★) | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "1114",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-1114.png",
        "paint_name": "Bowie Bıçağı (★) | Ototronik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "1109",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-1109.png",
        "paint_name": "Bowie Bıçağı (★) | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-5.png",
        "paint_name": "Bowie Bıçağı (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-77.png",
        "paint_name": "Bowie Bıçağı (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "579",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-579.png",
        "paint_name": "Bowie Bıçağı (★) | Parlak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-12.png",
        "paint_name": "Bowie Bıçağı (★) | Kızıl Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-40.png",
        "paint_name": "Bowie Bıçağı (★) | Gece Şeridi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-98.png",
        "paint_name": "Bowie Bıçağı (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-175.png",
        "paint_name": "Bowie Bıçağı (★) | Alazlanmış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-72.png",
        "paint_name": "Bowie Bıçağı (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 514,
        "weapon_name": "weapon_knife_survival_bowie",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_survival_bowie-143.png",
        "paint_name": "Bowie Bıçağı (★) | Kentsel Maske",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical.png",
        "paint_name": "Huntsman Bıçağı (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-38.png",
        "paint_name": "Huntsman Bıçağı (★) | Solmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-417.png",
        "paint_name": "Huntsman Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-418.png",
        "paint_name": "Huntsman Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-419.png",
        "paint_name": "Huntsman Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-420.png",
        "paint_name": "Huntsman Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-421.png",
        "paint_name": "Huntsman Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "568",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-568.png",
        "paint_name": "Huntsman Bıçağı (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "569",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-569.png",
        "paint_name": "Huntsman Bıçağı (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "570",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-570.png",
        "paint_name": "Huntsman Bıçağı (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "571",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-571.png",
        "paint_name": "Huntsman Bıçağı (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "572",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-572.png",
        "paint_name": "Huntsman Bıçağı (★) | Gama Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-413.png",
        "paint_name": "Huntsman Bıçağı (★) | Mermer Solması",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "581",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-581.png",
        "paint_name": "Huntsman Bıçağı (★) | Serbest Stil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-415.png",
        "paint_name": "Huntsman Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-416.png",
        "paint_name": "Huntsman Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-59.png",
        "paint_name": "Huntsman Bıçağı (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-409.png",
        "paint_name": "Huntsman Bıçağı (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-42.png",
        "paint_name": "Huntsman Bıçağı (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "411",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-411.png",
        "paint_name": "Huntsman Bıçağı (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-43.png",
        "paint_name": "Huntsman Bıçağı (★) | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-44.png",
        "paint_name": "Huntsman Bıçağı (★) | Isıl İşlem",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-414.png",
        "paint_name": "Huntsman Bıçağı (★) | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "1107",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-1107.png",
        "paint_name": "Huntsman Bıçağı (★) | Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "620",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-620.png",
        "paint_name": "Huntsman Bıçağı (★) | Ultraviyole",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "1117",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-1117.png",
        "paint_name": "Huntsman Bıçağı (★) | Ototronik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "1112",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-1112.png",
        "paint_name": "Huntsman Bıçağı (★) | Siyah Laminat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-5.png",
        "paint_name": "Huntsman Bıçağı (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-77.png",
        "paint_name": "Huntsman Bıçağı (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "579",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-579.png",
        "paint_name": "Huntsman Bıçağı (★) | Parlak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-12.png",
        "paint_name": "Huntsman Bıçağı (★) | Kızıl Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-40.png",
        "paint_name": "Huntsman Bıçağı (★) | Gece Şeridi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-175.png",
        "paint_name": "Huntsman Bıçağı (★) | Alazlanmış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-72.png",
        "paint_name": "Huntsman Bıçağı (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 509,
        "weapon_name": "weapon_knife_tactical",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_tactical-143.png",
        "paint_name": "Huntsman Bıçağı (★) | Kentsel Maske",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus.png",
        "paint_name": "Ursus Bıçağı (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-38.png",
        "paint_name": "Ursus Bıçağı (★) | Solmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-417.png",
        "paint_name": "Ursus Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "418",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-418.png",
        "paint_name": "Ursus Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "419",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-419.png",
        "paint_name": "Ursus Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "420",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-420.png",
        "paint_name": "Ursus Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "421",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-421.png",
        "paint_name": "Ursus Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "413",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-413.png",
        "paint_name": "Ursus Bıçağı (★) | Mermer Solması",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-415.png",
        "paint_name": "Ursus Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-416.png",
        "paint_name": "Ursus Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-59.png",
        "paint_name": "Ursus Bıçağı (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-409.png",
        "paint_name": "Ursus Bıçağı (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-42.png",
        "paint_name": "Ursus Bıçağı (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "857",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-857.png",
        "paint_name": "Ursus Bıçağı (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-43.png",
        "paint_name": "Ursus Bıçağı (★) | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-44.png",
        "paint_name": "Ursus Bıçağı (★) | Isıl İşlem",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-414.png",
        "paint_name": "Ursus Bıçağı (★) | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-5.png",
        "paint_name": "Ursus Bıçağı (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-77.png",
        "paint_name": "Ursus Bıçağı (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-12.png",
        "paint_name": "Ursus Bıçağı (★) | Kızıl Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-98.png",
        "paint_name": "Ursus Bıçağı (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-175.png",
        "paint_name": "Ursus Bıçağı (★) | Alazlanmış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-72.png",
        "paint_name": "Ursus Bıçağı (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "735",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-735.png",
        "paint_name": "Ursus Bıçağı (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 519,
        "weapon_name": "weapon_knife_ursus",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_ursus-143.png",
        "paint_name": "Ursus Bıçağı (★) | Kentsel Maske",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker.png",
        "paint_name": "Talon Bıçağı (★) | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-38.png",
        "paint_name": "Talon Bıçağı (★) | Solmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "417",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-417.png",
        "paint_name": "Talon Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "852",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-852.png",
        "paint_name": "Talon Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "853",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-853.png",
        "paint_name": "Talon Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "854",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-854.png",
        "paint_name": "Talon Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "855",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-855.png",
        "paint_name": "Talon Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "856",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-856.png",
        "paint_name": "Talon Bıçağı (★) | Mermer Solması",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "415",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-415.png",
        "paint_name": "Talon Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "416",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-416.png",
        "paint_name": "Talon Bıçağı (★) | Doppler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "59",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-59.png",
        "paint_name": "Talon Bıçağı (★) | Katliam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "409",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-409.png",
        "paint_name": "Talon Bıçağı (★) | Kaplan Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-42.png",
        "paint_name": "Talon Bıçağı (★) | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "858",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-858.png",
        "paint_name": "Talon Bıçağı (★) | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "43",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-43.png",
        "paint_name": "Talon Bıçağı (★) | Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-44.png",
        "paint_name": "Talon Bıçağı (★) | Isıl İşlem",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "414",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-414.png",
        "paint_name": "Talon Bıçağı (★) | Paslı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-5.png",
        "paint_name": "Talon Bıçağı (★) | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-77.png",
        "paint_name": "Talon Bıçağı (★) | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-12.png",
        "paint_name": "Talon Bıçağı (★) | Kızıl Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-98.png",
        "paint_name": "Talon Bıçağı (★) | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-175.png",
        "paint_name": "Talon Bıçağı (★) | Alazlanmış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "72",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-72.png",
        "paint_name": "Talon Bıçağı (★) | Safari Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "735",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-735.png",
        "paint_name": "Talon Bıçağı (★) | Gece",
        "legacy_model": false
    },
    {
        "weapon_defindex": 523,
        "weapon_name": "weapon_knife_widowmaker",
        "paint": "143",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_knife_widowmaker-143.png",
        "paint_name": "Talon Bıçağı (★) | Kentsel Maske",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249.png",
        "paint_name": "M249 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "902",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-902.png",
        "paint_name": "M249 | Aztek",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "266",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-266.png",
        "paint_name": "M249 | Magma",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "983",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-983.png",
        "paint_name": "M249 | Kontur",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "1148",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-1148.png",
        "paint_name": "M249 | Downtown",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "1242",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-1242.png",
        "paint_name": "M249 | Batık",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "401",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-401.png",
        "paint_name": "M249 | Sistem Kilidi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "547",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-547.png",
        "paint_name": "M249 | Hayalet",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "1042",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-1042.png",
        "paint_name": "M249 | O.S.I.P.R.",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "496",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-496.png",
        "paint_name": "M249 | Nebula Savaşçısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "900",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-900.png",
        "paint_name": "M249 | Savaş Kuşu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "875",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-875.png",
        "paint_name": "M249 | Spektral Sapma",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "75",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-75.png",
        "paint_name": "M249 | Tipi Mermer",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "202",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-202.png",
        "paint_name": "M249 | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "452",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-452.png",
        "paint_name": "M249 | Deniz Raporu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "1298",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-1298.png",
        "paint_name": "M249 | Adaçayı Spreyi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "120",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-120.png",
        "paint_name": "M249 | Hipnoz",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "151",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-151.png",
        "paint_name": "M249 | Yabani Orman",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "472",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-472.png",
        "paint_name": "M249 | Darbeli Matkap",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "648",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-648.png",
        "paint_name": "M249 | Zümrüt Zehirli Ok Kurbağası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "243",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-243.png",
        "paint_name": "M249 | Timsah Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "827",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-827.png",
        "paint_name": "M249 | Puro Kutusu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "933",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-933.png",
        "paint_name": "M249 | Gece Yarısı Palmiyesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "22",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-22.png",
        "paint_name": "M249 | Kontrast Sprey",
        "legacy_model": false
    },
    {
        "weapon_defindex": 14,
        "weapon_name": "weapon_m249",
        "paint": "170",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m249-170.png",
        "paint_name": "M249 | Yırtıcı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1.png",
        "paint_name": "M4A4 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "780",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-780.png",
        "paint_name": "M4A4 | Anakart",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "471",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-471.png",
        "paint_name": "M4A4 | Gün Doğumu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "155",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-155.png",
        "paint_name": "M4A4 | Mermi Yağmuru",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "993",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-993.png",
        "paint_name": "M4A4 | Global Offensive",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "255",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-255.png",
        "paint_name": "M4A4 | Asiimov",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "309",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-309.png",
        "paint_name": "M4A4 | Kükreyiş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "400",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-400.png",
        "paint_name": "M4A4 | Ejderha Kralı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "985",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-985.png",
        "paint_name": "M4A4 | Siber",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "588",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-588.png",
        "paint_name": "M4A4 | Issız Uzay",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1149",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1149.png",
        "paint_name": "M4A4 | Çoklu Şarjör",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "480",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-480.png",
        "paint_name": "M4A4 | Şeytani Daimyo",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "384",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-384.png",
        "paint_name": "M4A4 | Griffin",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "664",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-664.png",
        "paint_name": "M4A4 | Cehennem Ateşi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1041",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1041.png",
        "paint_name": "M4A4 | Canlı Renkler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "695",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-695.png",
        "paint_name": "M4A4 | Neo-Noir",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "971",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-971.png",
        "paint_name": "M4A4 | Diş Perisi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1228",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1228.png",
        "paint_name": "M4A4 | Geri Tepme Seçkinleri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1209",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1209.png",
        "paint_name": "M4A4 | Temukau",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "449",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-449.png",
        "paint_name": "M4A4 | Poseidon",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "336",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-336.png",
        "paint_name": "M4A4 | Çöl Seçkinleri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "215",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-215.png",
        "paint_name": "M4A4 | X-Ray",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1097",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1097.png",
        "paint_name": "M4A4 | Örümcek Zambağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "811",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-811.png",
        "paint_name": "M4A4 | Magnezyum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1063",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1063.png",
        "paint_name": "M4A4 | Koalisyon",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "844",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-844.png",
        "paint_name": "M4A4 | İmparator",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "533",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-533.png",
        "paint_name": "M4A4 | Savaş Yıldızı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1255",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1255.png",
        "paint_name": "M4A4 | Horus'un Gözü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "512",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-512.png",
        "paint_name": "M4A4 | Kraliyet Şövalyesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "632",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-632.png",
        "paint_name": "M4A4 | Keyif Kaçıran",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1313",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1313.png",
        "paint_name": "M4A4 | Demir Kaplama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "17",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-17.png",
        "paint_name": "M4A4 | Kentsel DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "926",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-926.png",
        "paint_name": "M4A4 | Kırmızı DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "8",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-8.png",
        "paint_name": "M4A4 | Çöl Fırtınası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "164",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-164.png",
        "paint_name": "M4A4 | Modern Avcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "793",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-793.png",
        "paint_name": "M4A4 | Dönüştürücü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "16",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-16.png",
        "paint_name": "M4A4 | Orman Kaplanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1266",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1266.png",
        "paint_name": "M4A4 | Deniz Kaplanı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "118",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-118.png",
        "paint_name": "M4A4 | Türbin",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1210",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1210.png",
        "paint_name": "M4A4 | Savoir Faire",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1353",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1353.png",
        "paint_name": "M4A4 | Tam Gaz",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1165",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1165.png",
        "paint_name": "M4A4 | Gravür Lordu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer.png",
        "paint_name": "M4A1-S | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1177",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1177.png",
        "paint_name": "M4A1-S | Solmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "862",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-862.png",
        "paint_name": "M4A1-S | Yosunlu Kuvars",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "301",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-301.png",
        "paint_name": "M4A1-S | Atomik Alaşım",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1017",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1017.png",
        "paint_name": "M4A1-S | Mavi Fosfor",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "326",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-326.png",
        "paint_name": "M4A1-S | Şövalye",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "60",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-60.png",
        "paint_name": "M4A1-S | Kara Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "445",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-445.png",
        "paint_name": "M4A1-S | Hot Rod",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "383",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-383.png",
        "paint_name": "M4A1-S | Basilisk",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "257",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-257.png",
        "paint_name": "M4A1-S | Muhafız",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "321",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-321.png",
        "paint_name": "M4A1-S | Chantico'nun Ateşi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "631",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-631.png",
        "paint_name": "M4A1-S | Flashback",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "430",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-430.png",
        "paint_name": "M4A1-S | Hiper Canavar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1001",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1001.png",
        "paint_name": "M4A1-S | Ormana Hoş Geldiniz",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "946",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-946.png",
        "paint_name": "M4A1-S | İkinci Oyuncu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "360",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-360.png",
        "paint_name": "M4A1-S | Yok Edici",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1223",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1223.png",
        "paint_name": "M4A1-S | Emphyteusis",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "663",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-663.png",
        "paint_name": "M4A1-S | Brifing",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "714",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-714.png",
        "paint_name": "M4A1-S | Kabus",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "984",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-984.png",
        "paint_name": "M4A1-S | Printstream",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "548",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-548.png",
        "paint_name": "M4A1-S | Ateş Tanrısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1216",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1216.png",
        "paint_name": "M4A1-S | Stratosfer Seferi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "644",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-644.png",
        "paint_name": "M4A1-S | Muhrip 2000",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "587",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-587.png",
        "paint_name": "M4A1-S | Mekanize Endüstri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "681",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-681.png",
        "paint_name": "M4A1-S | Kurşunlu Cam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1073",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1073.png",
        "paint_name": "M4A1-S | Yakın Tehlike",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1130",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1130.png",
        "paint_name": "M4A1-S | Gece Terörü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1243",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1243.png",
        "paint_name": "M4A1-S | Çamur Deseni",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "792",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-792.png",
        "paint_name": "M4A1-S | Kontrol Paneli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "497",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-497.png",
        "paint_name": "M4A1-S | Altın Bobin",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1311",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1311.png",
        "paint_name": "M4A1-S | Glitch Art",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-77.png",
        "paint_name": "M4A1-S | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1319",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1319.png",
        "paint_name": "M4A1-S | Gül Peteği",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "440",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-440.png",
        "paint_name": "M4A1-S | İkarus'un Düşüşü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "189",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-189.png",
        "paint_name": "M4A1-S | Parlak Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "160",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-160.png",
        "paint_name": "M4A1-S | Karalama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "217",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-217.png",
        "paint_name": "M4A1-S | Kan Kaplanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "235",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-235.png",
        "paint_name": "M4A1-S | VariCamo",
        "legacy_model": true
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1166",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1166.png",
        "paint_name": "M4A1-S | Siyah Lotus",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1340",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1340.png",
        "paint_name": "M4A1-S | Sıvılaşmış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "106",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-106.png",
        "paint_name": "M4A1-S | Vaporwave",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "254",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-254.png",
        "paint_name": "M4A1-S | Nitro",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1338",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1338.png",
        "paint_name": "M4A1-S | Yalnızlık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 60,
        "weapon_name": "weapon_m4a1_silencer",
        "paint": "1059",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1_silencer-1059.png",
        "paint_name": "M4A1-S | Gazoz Pop",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "101",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-101.png",
        "paint_name": "M4A4 | Hortum",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "874",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-874.png",
        "paint_name": "M4A4 | Poli Patina",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "730",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-730.png",
        "paint_name": "M4A4 | Karanlık Çiçek",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "167",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-167.png",
        "paint_name": "M4A4 | Radyasyon Tehlikesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "187",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-187.png",
        "paint_name": "M4A4 | Yıldız",
        "legacy_model": true
    },
{
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "176",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-176.png",
        "paint_name": "M4A4 | Anakart",
        "legacy_model": false
    },
    {
        "weapon_defindex": 16,
        "weapon_name": "weapon_m4a1",
        "paint": "1281",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_m4a1-1281.png",
        "paint_name": "M4A4 | Flaş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10.png",
        "paint_name": "MAC-10 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "38",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-38.png",
        "paint_name": "MAC-10 | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "246",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-246.png",
        "paint_name": "MAC-10 | Kehribar Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "651",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-651.png",
        "paint_name": "MAC-10 | Son Dalış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1025",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1025.png",
        "paint_name": "MAC-10 | Altın Külçesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "761",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-761.png",
        "paint_name": "MAC-10 | Boru Hattı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "665",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-665.png",
        "paint_name": "MAC-10 | Aloha",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "534",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-534.png",
        "paint_name": "MAC-10 | Lapis Timsahı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "402",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-402.png",
        "paint_name": "MAC-10 | Malakit",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "682",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-682.png",
        "paint_name": "MAC-10 | Okyanus",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "372",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-372.png",
        "paint_name": "MAC-10 | Nükleer Bahçe",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "742",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-742.png",
        "paint_name": "MAC-10 | Kırmızı Telkari",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "32",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-32.png",
        "paint_name": "MAC-10 | Gümüş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "188",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-188.png",
        "paint_name": "MAC-10 | Oymalı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "589",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-589.png",
        "paint_name": "MAC-10 | Etçil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "44",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-44.png",
        "paint_name": "MAC-10 | Menevişli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "337",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-337.png",
        "paint_name": "MAC-10 | Sıcaklık",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "343",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-343.png",
        "paint_name": "MAC-10 | Yolcu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "498",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-498.png",
        "paint_name": "MAC-10 | Rengarenk",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "310",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-310.png",
        "paint_name": "MAC-10 | Lanet",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "965",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-965.png",
        "paint_name": "MAC-10 | Cazibe",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1150",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1150.png",
        "paint_name": "MAC-10 | Maymun Kamuflajı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "947",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-947.png",
        "paint_name": "MAC-10 | Diskotek",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "433",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-433.png",
        "paint_name": "MAC-10 | Neon Sürücü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1131",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1131.png",
        "paint_name": "MAC-10 | Kapana Kısılmış",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1045",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1045.png",
        "paint_name": "MAC-10 | Atari Meraklısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1067",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1067.png",
        "paint_name": "MAC-10 | Propaganda",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "284",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-284.png",
        "paint_name": "MAC-10 | Paçavra",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1229",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1229.png",
        "paint_name": "MAC-10 | İllüzyon",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1244",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1244.png",
        "paint_name": "MAC-10 | Şaka",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1098",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1098.png",
        "paint_name": "MAC-10 | Oyuncak Kutusu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "140",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-140.png",
        "paint_name": "MAC-10 | Ahbap",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "748",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-748.png",
        "paint_name": "MAC-10 | Dana Derisi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "908",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-908.png",
        "paint_name": "MAC-10 | Klasik Kasa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "812",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-812.png",
        "paint_name": "MAC-10 | Kepenk",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "840",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-840.png",
        "paint_name": "MAC-10 | Beyaz Balık",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1009",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1009.png",
        "paint_name": "MAC-10 | Anakonda",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "898",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-898.png",
        "paint_name": "MAC-10 | Takipçi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "17",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-17.png",
        "paint_name": "MAC-10 | Kentsel DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1075",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1075.png",
        "paint_name": "MAC-10 | Katman",
        "legacy_model": true
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1295",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1295.png",
        "paint_name": "MAC-10 | Asit Yıkama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1285",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1285.png",
        "paint_name": "MAC-10 | Bakır Borre",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1164",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1164.png",
        "paint_name": "MAC-10 | Işık Kutusu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1349",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1349.png",
        "paint_name": "MAC-10 | Kedi Kavgası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "126",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-126.png",
        "paint_name": "MAC-10 | Siber Taarruz",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1204",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1204.png",
        "paint_name": "MAC-10 | Raydan Çıkmış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1334",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1334.png",
        "paint_name": "MAC-10 | Bronz Tuzak",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "333",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-333.png",
        "paint_name": "MAC-10 | Çivit Mavisi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-98.png",
        "paint_name": "MAC-10 | Ultraviyole",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "3",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-3.png",
        "paint_name": "MAC-10 | Şeker Elması",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "101",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-101.png",
        "paint_name": "MAC-10 | Kasırga",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "1269",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-1269.png",
        "paint_name": "MAC-10 | Fırtına",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "826",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-826.png",
        "paint_name": "MAC-10 | Çöpçü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "157",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-157.png",
        "paint_name": "MAC-10 | Palmiye",
        "legacy_model": false
    },
    {
        "weapon_defindex": 17,
        "weapon_name": "weapon_mac10",
        "paint": "871",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mac10-871.png",
        "paint_name": "MAC-10 | Sörf Tahtası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7.png",
        "paint_name": "MAG-7 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "70",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-70.png",
        "paint_name": "MAG-7 | Karbon Fiber",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "327",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-327.png",
        "paint_name": "MAG-7 | Örme Zırh",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "666",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-666.png",
        "paint_name": "MAG-7 | Sert Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "633",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-633.png",
        "paint_name": "MAG-7 | Sonar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "822",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-822.png",
        "paint_name": "MAG-7 | Lacivert Parıltı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "34",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-34.png",
        "paint_name": "MAG-7 | Metalik DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "32",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-32.png",
        "paint_name": "MAG-7 | Gümüş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "703",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-703.png",
        "paint_name": "MAG-7 | SWAG-7",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "754",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-754.png",
        "paint_name": "MAG-7 | Paslı Kaplama",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "291",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-291.png",
        "paint_name": "MAG-7 | Gök Muhafızı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "1220",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-1220.png",
        "paint_name": "MAG-7 | Uykusuzluk",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "961",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-961.png",
        "paint_name": "MAG-7 | Canavar Çağrısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "499",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-499.png",
        "paint_name": "MAG-7 | Kobalt Çekirdeği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "1132",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-1132.png",
        "paint_name": "MAG-7 | Öngörü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "431",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-431.png",
        "paint_name": "MAG-7 | Isı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "608",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-608.png",
        "paint_name": "MAG-7 | Kaya Resmi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "1089",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-1089.png",
        "paint_name": "MAG-7 | Bizmut",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "737",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-737.png",
        "paint_name": "MAG-7 | Cinquedea",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "1245",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-1245.png",
        "paint_name": "MAG-7 | Bakır Kaplama",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "948",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-948.png",
        "paint_name": "MAG-7 | Adalet",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "909",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-909.png",
        "paint_name": "MAG-7 | Popdog",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "535",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-535.png",
        "paint_name": "MAG-7 | Muhafız",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "462",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-462.png",
        "paint_name": "MAG-7 | Karşı Teras",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "1072",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-1072.png",
        "paint_name": "MAG-7 | Prizmatik Teras",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "177",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-177.png",
        "paint_name": "MAG-7 | Hatıra",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "787",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-787.png",
        "paint_name": "MAG-7 | Çekirdek Sızıntısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "1188",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-1188.png",
        "paint_name": "MAG-7 | İkmal",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "1355",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-1355.png",
        "paint_name": "MAG-7 | Büyüklük",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "473",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-473.png",
        "paint_name": "MAG-7 | Deniz Kuşu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "1306",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-1306.png",
        "paint_name": "MAG-7 | Bakır Oksit",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "99",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-99.png",
        "paint_name": "MAG-7 | Kum Tepesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "100",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-100.png",
        "paint_name": "MAG-7 | Fırtına",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "39",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-39.png",
        "paint_name": "MAG-7 | Dozer",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "773",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-773.png",
        "paint_name": "MAG-7 | Yabani Orman",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "198",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-198.png",
        "paint_name": "MAG-7 | Tehlike",
        "legacy_model": false
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "385",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-385.png",
        "paint_name": "MAG-7 | Kavrulmuş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 27,
        "weapon_name": "weapon_mag7",
        "paint": "171",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mag7-171.png",
        "paint_name": "MAG-7 | Radyasyon Uyarısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd.png",
        "paint_name": "MP5-SD | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "781",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-781.png",
        "paint_name": "MP5-SD | Yardımcı İşlemci",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "949",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-949.png",
        "paint_name": "MP5-SD | Çöl Saldırısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "1231",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-1231.png",
        "paint_name": "MP5-SD | Tasfiye",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "986",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-986.png",
        "paint_name": "MP5-SD | Condition Zero",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "888",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-888.png",
        "paint_name": "MP5-SD | Hurda",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "915",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-915.png",
        "paint_name": "MP5-SD | Ajan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "810",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-810.png",
        "paint_name": "MP5-SD | Fosfor",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "1137",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-1137.png",
        "paint_name": "MP5-SD | Çocukluk Kabusu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "923",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-923.png",
        "paint_name": "MP5-SD | Çöl Vahası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "846",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-846.png",
        "paint_name": "MP5-SD | Gauss",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "974",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-974.png",
        "paint_name": "MP5-SD | İtici",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "768",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-768.png",
        "paint_name": "MP5-SD | Savan Yarım Tonu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "872",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-872.png",
        "paint_name": "MP5-SD | Bambu Bahçesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "800",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-800.png",
        "paint_name": "MP5-SD | Deney Fareleri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "1061",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-1061.png",
        "paint_name": "MP5-SD | Sonbahar Twilly",
        "legacy_model": true
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "1294",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-1294.png",
        "paint_name": "MP5-SD | Altın Yaprak",
        "legacy_model": false
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "1180",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-1180.png",
        "paint_name": "MP5-SD | Statik",
        "legacy_model": false
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "1344",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-1344.png",
        "paint_name": "MP5-SD | Odak",
        "legacy_model": false
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "798",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-798.png",
        "paint_name": "MP5-SD | Nitro",
        "legacy_model": false
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "1274",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-1274.png",
        "paint_name": "MP5-SD | Asit Yıkama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "161",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-161.png",
        "paint_name": "MP5-SD | Neon Sıkma",
        "legacy_model": false
    },
    {
        "weapon_defindex": 23,
        "weapon_name": "weapon_mp5sd",
        "paint": "753",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp5sd-753.png",
        "paint_name": "MP5-SD | Çamur Banyosu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7.png",
        "paint_name": "MP7 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "752",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-752.png",
        "paint_name": "MP7 | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "782",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-782.png",
        "paint_name": "MP7 | Anakart",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "1007",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-1007.png",
        "paint_name": "MP7 | Kasa Soygunu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "213",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-213.png",
        "paint_name": "MP7 | Okyanus Köpüğü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "28",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-28.png",
        "paint_name": "MP7 | Eloksallı Lacivert",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "423",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-423.png",
        "paint_name": "MP7 | Zırh Çekirdeği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "354",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-354.png",
        "paint_name": "MP7 | Kentsel Tehlike",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "500",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-500.png",
        "paint_name": "MP7 | Özel Teslimat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "1133",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-1133.png",
        "paint_name": "MP7 | Dipsiz Hayalet",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "1096",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-1096.png",
        "paint_name": "MP7 | Gerilla",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "481",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-481.png",
        "paint_name": "MP7 | İntikamcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "847",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-847.png",
        "paint_name": "MP7 | Yaramazlık",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "893",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-893.png",
        "paint_name": "MP7 | Neon Katman",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "940",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-940.png",
        "paint_name": "MP7 | Usturlap",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "627",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-627.png",
        "paint_name": "MP7 | Sirüs",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "696",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-696.png",
        "paint_name": "MP7 | Kanlı Spor",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "1246",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-1246.png",
        "paint_name": "MP7 | Güneşte Pişmiş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "719",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-719.png",
        "paint_name": "MP7 | Güç Çekirdeği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-5.png",
        "paint_name": "MP7 | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "1023",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-1023.png",
        "paint_name": "MP7 | Camgöbeği Çiçek",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "15",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-15.png",
        "paint_name": "MP7 | Barut Dumanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "365",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-365.png",
        "paint_name": "MP7 | Zeytin Yeşili Ekose",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "11",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-11.png",
        "paint_name": "MP7 | Kafatasları",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "250",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-250.png",
        "paint_name": "MP7 | İmparatorluk",
        "legacy_model": true
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "1163",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-1163.png",
        "paint_name": "MP7 | Gülümse",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "1354",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-1354.png",
        "paint_name": "MP7 | Sigara Öldürür",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "1326",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-1326.png",
        "paint_name": "MP7 | Kırmızı Toprak Yarım Tonu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "209",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-209.png",
        "paint_name": "MP7 | Yer Altı Suyu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "102",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-102.png",
        "paint_name": "MP7 | Kar Fırtınası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "728",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-728.png",
        "paint_name": "MP7 | Camgöbeği Çiçek",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-175.png",
        "paint_name": "MP7 | Kavrulmuş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "442",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-442.png",
        "paint_name": "MP7 | Asterion",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "536",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-536.png",
        "paint_name": "MP7 | İmparatorluk",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "649",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-649.png",
        "paint_name": "MP7 | Akoben",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "245",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-245.png",
        "paint_name": "MP7 | Ordu Keşif",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "141",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-141.png",
        "paint_name": "MP7 | Portakal Kabuğu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 33,
        "weapon_name": "weapon_mp7",
        "paint": "935",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp7-935.png",
        "paint_name": "MP7 | Yırtıcı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9.png",
        "paint_name": "MP9 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "630",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-630.png",
        "paint_name": "MP9 | Kum Pulları",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1094",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1094.png",
        "paint_name": "MP9 | Fuji Dağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "448",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-448.png",
        "paint_name": "MP9 | Pandora'nın Kutusu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "61",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-61.png",
        "paint_name": "MP9 | Hipnoz",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "298",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-298.png",
        "paint_name": "MP9 | Ordu Parıltısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "329",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-329.png",
        "paint_name": "MP9 | Karanlık Çağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "820",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-820.png",
        "paint_name": "MP9 | Müzik Kutusu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "549",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-549.png",
        "paint_name": "MP9 | Biyo-sızıntı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "482",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-482.png",
        "paint_name": "MP9 | Yakut Zehirli Ok",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "867",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-867.png",
        "paint_name": "MP9 | Vitray",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "262",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-262.png",
        "paint_name": "MP9 | Gül Demiri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "33",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-33.png",
        "paint_name": "MP9 | Hot Rod",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "697",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-697.png",
        "paint_name": "MP9 | Siyah Kum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "386",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-386.png",
        "paint_name": "MP9 | Dart",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "403",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-403.png",
        "paint_name": "MP9 | Ölümcül Zehir",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1037",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1037.png",
        "paint_name": "MP9 | Besin Zinciri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "679",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-679.png",
        "paint_name": "MP9 | Yapışkan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "910",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-910.png",
        "paint_name": "MP9 | Hydra",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "734",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-734.png",
        "paint_name": "MP9 | Yabani Zambak",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1211",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1211.png",
        "paint_name": "MP9 | Hafif Tehdit",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "609",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-609.png",
        "paint_name": "MP9 | Hava Kilidi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1225",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1225.png",
        "paint_name": "MP9 | Tüy Siklet",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "715",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-715.png",
        "paint_name": "MP9 | Kılcal Damar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "331",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-331.png",
        "paint_name": "MP9 | Fırtına",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "804",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-804.png",
        "paint_name": "MP9 | Orta Dereceli Tehdit",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1134",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1134.png",
        "paint_name": "MP9 | Yıldız Işığı Muhafızı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1278",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1278.png",
        "paint_name": "MP9 | Taslak",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1330",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1330.png",
        "paint_name": "MP9 | Çoklu Arazi Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "368",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-368.png",
        "paint_name": "MP9 | Gün Batımı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "366",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-366.png",
        "paint_name": "MP9 | Yeşil Ekose",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "755",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-755.png",
        "paint_name": "MP9 | Sürgü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1258",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1258.png",
        "paint_name": "MP9 | Kobalt Yarım Tonu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1310",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1310.png",
        "paint_name": "MP9 | Yırtık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1193",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1193.png",
        "paint_name": "MP9 | Merkez",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1341",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1341.png",
        "paint_name": "MP9 | Bozuk Plak",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "100",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-100.png",
        "paint_name": "MP9 | Fırtına",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "39",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-39.png",
        "paint_name": "MP9 | Dozer",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "1301",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-1301.png",
        "paint_name": "MP9 | Çam",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "931",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-931.png",
        "paint_name": "MP9 | Yabani Orman",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "199",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-199.png",
        "paint_name": "MP9 | Kurak Mevsim",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "141",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-141.png",
        "paint_name": "MP9 | Portakal Kabuğu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 34,
        "weapon_name": "weapon_mp9",
        "paint": "148",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_mp9-148.png",
        "paint_name": "MP9 | Kum Çizgili",
        "legacy_model": false
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev.png",
        "paint_name": "Negev | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "298",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-298.png",
        "paint_name": "Negev | Ordu Parıltısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "432",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-432.png",
        "paint_name": "Negev | Savaş Gemisi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "28",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-28.png",
        "paint_name": "Negev | Eloksallı Lacivert",
        "legacy_model": false
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "317",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-317.png",
        "paint_name": "Negev | Bratatat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "483",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-483.png",
        "paint_name": "Negev | Geveze",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "1152",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-1152.png",
        "paint_name": "Negev | At Bana",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "1043",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-1043.png",
        "paint_name": "Negev | Yutucu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "514",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-514.png",
        "paint_name": "Negev | Güç Yükleyici",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "950",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-950.png",
        "paint_name": "Negev | Prototip",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "355",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-355.png",
        "paint_name": "Negev | Çöl Saldırısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "958",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-958.png",
        "paint_name": "Negev | Ultra Hafif",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "144",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-144.png",
        "paint_name": "Negev | Nükleer Atık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "763",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-763.png",
        "paint_name": "Negev | Mjölnir",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "783",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-783.png",
        "paint_name": "Negev | Bölme",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "610",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-610.png",
        "paint_name": "Negev | Göz Alıcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "1012",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-1012.png",
        "paint_name": "Negev | Anka Şablonu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "240",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-240.png",
        "paint_name": "Negev | California Kamuflajı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "920",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-920.png",
        "paint_name": "Negev | Barok Kum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "1080",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-1080.png",
        "paint_name": "Negev | Altyapı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "1300",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-1300.png",
        "paint_name": "Negev | Ham Porselen",
        "legacy_model": false
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "1260",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-1260.png",
        "paint_name": "Negev | Ekşi Üzümler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "698",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-698.png",
        "paint_name": "Negev | Aslan Balığı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "285",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-285.png",
        "paint_name": "Negev | Arazi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "369",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-369.png",
        "paint_name": "Negev | Nükleer Atık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 28,
        "weapon_name": "weapon_negev",
        "paint": "201",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_negev-201.png",
        "paint_name": "Negev | Palmiye",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova.png",
        "paint_name": "Nova | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "298",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-298.png",
        "paint_name": "Nova | Ordu Parıltısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "214",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-214.png",
        "paint_name": "Nova | Grafit",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "248",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-248.png",
        "paint_name": "Nova | Kırmızı Kuvars",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "634",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-634.png",
        "paint_name": "Nova | Gila",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "299",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-299.png",
        "paint_name": "Nova | Kafesli Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "746",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-746.png",
        "paint_name": "Nova | Barok Turuncu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "590",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-590.png",
        "paint_name": "Nova | Exo",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "323",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-323.png",
        "paint_name": "Nova | Paslı Kaplama",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "286",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-286.png",
        "paint_name": "Nova | Antika",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "890",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-890.png",
        "paint_name": "Nova | Rüzgarda Savrulan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "537",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-537.png",
        "paint_name": "Nova | Hiper Canavar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "356",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-356.png",
        "paint_name": "Nova | Koi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "987",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-987.png",
        "paint_name": "Nova | Berrak Polimer",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "484",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-484.png",
        "paint_name": "Nova | Korucu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "716",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-716.png",
        "paint_name": "Nova | Oyuncak Asker",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "145",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-145.png",
        "paint_name": "Nova | Kenetli",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "263",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-263.png",
        "paint_name": "Nova | Yükselen Kafatası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "62",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-62.png",
        "paint_name": "Nova | Çiçek Açma",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "158",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-158.png",
        "paint_name": "Nova | Ceviz",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "699",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-699.png",
        "paint_name": "Nova | Çılgın Altılı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "809",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-809.png",
        "paint_name": "Nova | Odun Ateşi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "1247",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-1247.png",
        "paint_name": "Nova | Sobek'in Isırığı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "324",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-324.png",
        "paint_name": "Nova | Yorkshire",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "785",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-785.png",
        "paint_name": "Nova | Mandren",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "166",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-166.png",
        "paint_name": "Nova | Alevli Turuncu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "164",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-164.png",
        "paint_name": "Nova | Modern Avcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "191",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-191.png",
        "paint_name": "Nova | Fırtına",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "929",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-929.png",
        "paint_name": "Nova | İnce Kum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "1077",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-1077.png",
        "paint_name": "Nova | Yıldızlararası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "450",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-450.png",
        "paint_name": "Nova | Terazi Burcundaki Ay",
        "legacy_model": true
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "1162",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-1162.png",
        "paint_name": "Nova | Karanlık Mühür",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "1350",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-1350.png",
        "paint_name": "Nova | Oküler",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "1192",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-1192.png",
        "paint_name": "Nova | Kiraz Çiçeği",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "294",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-294.png",
        "paint_name": "Nova | Yeşil Elma",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "3",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-3.png",
        "paint_name": "Nova | Şeker Elması",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "99",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-99.png",
        "paint_name": "Nova | Kum Tepesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "1261",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-1261.png",
        "paint_name": "Nova | Turkuaz Ekose",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "1331",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-1331.png",
        "paint_name": "Nova | Bataklık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "225",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-225.png",
        "paint_name": "Nova | Hayalet Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "25",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-25.png",
        "paint_name": "Nova | Orman Yaprakları",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "107",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-107.png",
        "paint_name": "Nova | Kutup Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "1051",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-1051.png",
        "paint_name": "Nova | Rüzgarda Savrulan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "170",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-170.png",
        "paint_name": "Nova | Yırtıcı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 35,
        "weapon_name": "weapon_nova",
        "paint": "1337",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_nova-1337.png",
        "paint_name": "Nova | İstasyon",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250.png",
        "paint_name": "P250 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "813",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-813.png",
        "paint_name": "P250 | Bir Daha Asla",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1081",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1081.png",
        "paint_name": "P250 | Siber Kabuk",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "230",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-230.png",
        "paint_name": "P250 | Çelik Karışıklık",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "271",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-271.png",
        "paint_name": "P250 | Girdap",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "650",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-650.png",
        "paint_name": "P250 | Dalgalanma",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "741",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-741.png",
        "paint_name": "P250 | Siyah Telkari",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "34",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-34.png",
        "paint_name": "P250 | Metalik DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "388",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-388.png",
        "paint_name": "P250 | Kartel",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "426",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-426.png",
        "paint_name": "P250 | Valans",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "848",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-848.png",
        "paint_name": "P250 | Bakır Pası",
        "legacy_model": true
    },
{
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1212",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1212.png",
        "paint_name": "P250 | Konstrüktivist",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "358",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-358.png",
        "paint_name": "P250 | Süpernova",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "295",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-295.png",
        "paint_name": "P250 | Franklin",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "551",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-551.png",
        "paint_name": "P250 | Asiimov",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "668",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-668.png",
        "paint_name": "P250 | Kırmızı Kaya",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "968",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-968.png",
        "paint_name": "P250 | Kaset",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "678",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-678.png",
        "paint_name": "P250 | Biyogaz",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "982",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-982.png",
        "paint_name": "P250 | Kirletici",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "404",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-404.png",
        "paint_name": "P250 | Ölüm Döngüsü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1230",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1230.png",
        "paint_name": "P250 | Yeniden Yapılandırma",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "258",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-258.png",
        "paint_name": "P250 | Mehndi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "125",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-125.png",
        "paint_name": "P250 | X-Işını",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1248",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1248.png",
        "paint_name": "P250 | Apep'in Laneti",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "749",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-749.png",
        "paint_name": "P250 | Şarap",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1044",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1044.png",
        "paint_name": "P250 | Siber Öncü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "907",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-907.png",
        "paint_name": "P250 | Inferno",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "592",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-592.png",
        "paint_name": "P250 | Zırh",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1153",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1153.png",
        "paint_name": "P250 | Büyüleyici İlüzyon",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "777",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-777.png",
        "paint_name": "P250 | Tesis Serisi - Taslak",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "207",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-207.png",
        "paint_name": "P250 | Poligon",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "928",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-928.png",
        "paint_name": "P250 | Gizlenen",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "786",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-786.png",
        "paint_name": "P250 | Anahtar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "77",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-77.png",
        "paint_name": "P250 | Kuzey Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "78",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-78.png",
        "paint_name": "P250 | Alacakaranlık Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "15",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-15.png",
        "paint_name": "P250 | Barut",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "164",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-164.png",
        "paint_name": "P250 | Modern Avcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "466",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-466.png",
        "paint_name": "P250 | Japon Kırmızısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "373",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-373.png",
        "paint_name": "P250 | Nükleer Kirlilik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "501",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-501.png",
        "paint_name": "P250 | Kanat Vuruşu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1030",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1030.png",
        "paint_name": "P250 | Bengal Kaplanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "219",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-219.png",
        "paint_name": "P250 | Kırmızı Yuva",
        "legacy_model": true
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1315",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1315.png",
        "paint_name": "P250 | Kızıl Gelgit",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1345",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1345.png",
        "paint_name": "P250 | Bullfrog",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "130",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-130.png",
        "paint_name": "P250 | Merkez",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1307",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1307.png",
        "paint_name": "P250 | Bakır Oksit",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "99",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-99.png",
        "paint_name": "P250 | Kum Tepesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "102",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-102.png",
        "paint_name": "P250 | Gümüş Kaplama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "774",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-774.png",
        "paint_name": "P250 | Eğlencesine",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1317",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1317.png",
        "paint_name": "P250 | Çökelti",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "825",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-825.png",
        "paint_name": "P250 | Kuraklık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "467",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-467.png",
        "paint_name": "P250 | Japon Naneli",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "1273",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-1273.png",
        "paint_name": "P250 | Kırmızı Çizgili",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "168",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-168.png",
        "paint_name": "P250 | Nükleer Caydırıcı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "162",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-162.png",
        "paint_name": "P250 | Vahşi Sıçrama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 36,
        "weapon_name": "weapon_p250",
        "paint": "27",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p250-27.png",
        "paint_name": "P250 | Kemik Örtüsü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90.png",
        "paint_name": "P90 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1020",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1020.png",
        "paint_name": "P90 | Kadim Gezegen",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "759",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-759.png",
        "paint_name": "P90 | Yıldız Pitonu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "67",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-67.png",
        "paint_name": "P90 | Soğukkanlı Katil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1015",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1015.png",
        "paint_name": "P90 | Kapana Kısılmış",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "744",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-744.png",
        "paint_name": "P90 | Barok Kırmızısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "335",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-335.png",
        "paint_name": "P90 | Derin Mavi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "342",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-342.png",
        "paint_name": "P90 | Kahverengi Deri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "156",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-156.png",
        "paint_name": "P90 | Kedi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "182",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-182.png",
        "paint_name": "P90 | Zümrüt Ejderha",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1000",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1000.png",
        "paint_name": "P90 | Leopar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "359",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-359.png",
        "paint_name": "P90 | Asiimov",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "611",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-611.png",
        "paint_name": "P90 | Acımasız",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "486",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-486.png",
        "paint_name": "P90 | Elite Yapım",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "911",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-911.png",
        "paint_name": "P90 | Eski Günler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "849",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-849.png",
        "paint_name": "P90 | Uzaylı Dünyası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1250",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1250.png",
        "paint_name": "P90 | Skarab",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "311",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-311.png",
        "paint_name": "P90 | Çöl Savaşı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "516",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-516.png",
        "paint_name": "P90 | Oymalı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "283",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-283.png",
        "paint_name": "P90 | Üçgen",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "936",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-936.png",
        "paint_name": "P90 | Saldırı Vektörü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "969",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-969.png",
        "paint_name": "P90 | Konteyner",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "593",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-593.png",
        "paint_name": "P90 | Ölüm Makinesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1233",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1233.png",
        "paint_name": "P90 | Kraliçe",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "636",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-636.png",
        "paint_name": "P90 | Sığ Mezar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1154",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1154.png",
        "paint_name": "P90 | Rush",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "717",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-717.png",
        "paint_name": "P90 | Çekiş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1332",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1332.png",
        "paint_name": "P90 | Çöl Yarım Tonu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "776",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-776.png",
        "paint_name": "P90 | Tesis Serisi - Negatif",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "925",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-925.png",
        "paint_name": "P90 | Çöl DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "228",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-228.png",
        "paint_name": "P90 | Kör Nokta",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "669",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-669.png",
        "paint_name": "P90 | Ölümcül Kavrayış",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "977",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-977.png",
        "paint_name": "P90 | Canavar Rush",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1277",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1277.png",
        "paint_name": "P90 | Mavi Taktik",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1074",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1074.png",
        "paint_name": "P90 | Kesit",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "20",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-20.png",
        "paint_name": "P90 | Virüs Krizi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1256",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1256.png",
        "paint_name": "P90 | Mercan Ağıtı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1291",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1291.png",
        "paint_name": "P90 | Hardal Gazı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1190",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1190.png",
        "paint_name": "P90 | Dalga Kıran",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "127",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-127.png",
        "paint_name": "P90 | Randy Rush",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "1199",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-1199.png",
        "paint_name": "P90 | Tam Puan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "100",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-100.png",
        "paint_name": "P90 | Fırtına",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "726",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-726.png",
        "paint_name": "P90 | Gün Batımı Zambakları",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-175.png",
        "paint_name": "P90 | Kavruk",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "111",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-111.png",
        "paint_name": "P90 | Buz Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "244",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-244.png",
        "paint_name": "P90 | Yıkım",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "828",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-828.png",
        "paint_name": "P90 | Yeşil Sarmaşık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "169",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-169.png",
        "paint_name": "P90 | Radyasyon Uyarısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "133",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-133.png",
        "paint_name": "P90 | Silinmiş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "124",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-124.png",
        "paint_name": "P90 | Çöl",
        "legacy_model": false
    },
    {
        "weapon_defindex": 19,
        "weapon_name": "weapon_p90",
        "paint": "234",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_p90-234.png",
        "paint_name": "P90 | Beyaz Ahşap",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver.png",
        "paint_name": "R8 Revolver | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "523",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-523.png",
        "paint_name": "R8 Revolver | Kehribar Solması",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "522",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-522.png",
        "paint_name": "R8 Revolver | Solma",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "37",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-37.png",
        "paint_name": "R8 Revolver | Kızgın Ateş",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "1011",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-1011.png",
        "paint_name": "R8 Revolver | Anka",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "1293",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-1293.png",
        "paint_name": "R8 Revolver | Yaprak",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "595",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-595.png",
        "paint_name": "R8 Revolver | Yeniden Başlat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "721",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-721.png",
        "paint_name": "R8 Revolver | Hayatta Kalan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "843",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-843.png",
        "paint_name": "R8 Revolver | Kafa Ezici",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "1232",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-1232.png",
        "paint_name": "R8 Revolver | Muz Tabancası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "952",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-952.png",
        "paint_name": "R8 Revolver | Kemik Dövme",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "683",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-683.png",
        "paint_name": "R8 Revolver | Alpaka",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "892",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-892.png",
        "paint_name": "R8 Revolver | Hafıza Parçaları",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "1047",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-1047.png",
        "paint_name": "R8 Revolver | Atık Kralı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "1237",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-1237.png",
        "paint_name": "R8 Revolver | Kakma",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "1145",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-1145.png",
        "paint_name": "R8 Revolver | Çılgın Sekizli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "701",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-701.png",
        "paint_name": "R8 Revolver | Sabit",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "924",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-924.png",
        "paint_name": "R8 Revolver | Çöl Kamuflajı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "12",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-12.png",
        "paint_name": "R8 Revolver | Kızıl Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "123",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-123.png",
        "paint_name": "R8 Revolver | Tango",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "40",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-40.png",
        "paint_name": "R8 Revolver | Kâbus Gecesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "798",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-798.png",
        "paint_name": "R8 Revolver | Nitrasyon",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "1276",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-1276.png",
        "paint_name": "R8 Revolver | Kobalt Kabzalı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "866",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-866.png",
        "paint_name": "R8 Revolver | Aqua",
        "legacy_model": false
    },
    {
        "weapon_defindex": 64,
        "weapon_name": "weapon_revolver",
        "paint": "27",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_revolver-27.png",
        "paint_name": "R8 Revolver | Kemik Örtüsü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff.png",
        "paint_name": "Sawed-Off | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "246",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-246.png",
        "paint_name": "Sawed-Off | Kehribar Solması",
        "legacy_model": false
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "797",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-797.png",
        "paint_name": "Sawed-Off | Fren Işığı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "41",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-41.png",
        "paint_name": "Sawed-Off | Bakır Kaplama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "673",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-673.png",
        "paint_name": "Sawed-Off | Gece Zambakları",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "390",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-390.png",
        "paint_name": "Sawed-Off | Yol Canavarı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "655",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-655.png",
        "paint_name": "Sawed-Off | Sudak",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "323",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-323.png",
        "paint_name": "Sawed-Off | Paslanmış",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "345",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-345.png",
        "paint_name": "Sawed-Off | Üstün Deri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "596",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-596.png",
        "paint_name": "Sawed-Off | Spot Işığı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "953",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-953.png",
        "paint_name": "Sawed-Off | Kıyamet",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "814",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-814.png",
        "paint_name": "Sawed-Off | Kara Kum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "405",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-405.png",
        "paint_name": "Sawed-Off | Huzur Kanatları",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "720",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-720.png",
        "paint_name": "Sawed-Off | Yutulan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "1155",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-1155.png",
        "paint_name": "Sawed-Off | Mumu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "256",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-256.png",
        "paint_name": "Sawed-Off | Kraken",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "434",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-434.png",
        "paint_name": "Sawed-Off | Origami",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "1140",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-1140.png",
        "paint_name": "Sawed-Off | Ruh Çağıran",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "638",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-638.png",
        "paint_name": "Sawed-Off | Vahşi Prenses",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "552",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-552.png",
        "paint_name": "Sawed-Off | Hurda",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "517",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-517.png",
        "paint_name": "Sawed-Off | Palyaço Kafası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "1272",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-1272.png",
        "paint_name": "Sawed-Off | Akış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "204",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-204.png",
        "paint_name": "Sawed-Off | Mozaik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "458",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-458.png",
        "paint_name": "Sawed-Off | Bambu Gölgeleri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "5",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-5.png",
        "paint_name": "Sawed-Off | Orman DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "83",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-83.png",
        "paint_name": "Sawed-Off | Turuncu DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "880",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-880.png",
        "paint_name": "Sawed-Off | Çöl Çiçeği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "1014",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-1014.png",
        "paint_name": "Sawed-Off | Pusu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "250",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-250.png",
        "paint_name": "Sawed-Off | Tutuklayıcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "1160",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-1160.png",
        "paint_name": "Sawed-Off | Analog Girdi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "171",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-171.png",
        "paint_name": "Sawed-Off | Radyasyon Uyarısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "870",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-870.png",
        "paint_name": "Sawed-Off | Çalılık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "30",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-30.png",
        "paint_name": "Sawed-Off | Yılan Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 29,
        "weapon_name": "weapon_sawedoff",
        "paint": "119",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sawedoff-119.png",
        "paint_name": "Sawed-Off | Bilge",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20.png",
        "paint_name": "SCAR-20 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "298",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-298.png",
        "paint_name": "SCAR-20 | Ordu İhtişamı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "70",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-70.png",
        "paint_name": "SCAR-20 | Karbon Fiber",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "196",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-196.png",
        "paint_name": "SCAR-20 | Zümrüt",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "159",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-159.png",
        "paint_name": "SCAR-20 | Pirinç",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "406",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-406.png",
        "paint_name": "SCAR-20 | Mavi Delik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "642",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-642.png",
        "paint_name": "SCAR-20 | Plan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "883",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-883.png",
        "paint_name": "SCAR-20 | Yaban Mersini",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "391",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-391.png",
        "paint_name": "SCAR-20 | Kalp Atışı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "914",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-914.png",
        "paint_name": "SCAR-20 | Depo Baskını",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "312",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-312.png",
        "paint_name": "SCAR-20 | Gelecek Nesil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "597",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-597.png",
        "paint_name": "SCAR-20 | Kanlı Spor",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "954",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-954.png",
        "paint_name": "SCAR-20 | Uygulayıcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "502",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-502.png",
        "paint_name": "SCAR-20 | Yeşil Denizci",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "612",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-612.png",
        "paint_name": "SCAR-20 | Güç Merkezi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "1226",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-1226.png",
        "paint_name": "SCAR-20 | Parçalar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "1028",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-1028.png",
        "paint_name": "SCAR-20 | Magna Carta",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "865",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-865.png",
        "paint_name": "SCAR-20 | Taş Örgü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "165",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-165.png",
        "paint_name": "SCAR-20 | Sıçrama Reçeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "685",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-685.png",
        "paint_name": "SCAR-20 | Orman Akıntısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "518",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-518.png",
        "paint_name": "SCAR-20 | Orman Patlaması",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "232",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-232.png",
        "paint_name": "SCAR-20 | Kızıl Ağ",
        "legacy_model": true
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "117",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-117.png",
        "paint_name": "SCAR-20 | Öncü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "1343",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-1343.png",
        "paint_name": "SCAR-20 | Kafesli",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "1327",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-1327.png",
        "paint_name": "SCAR-20 | Okra",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "46",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-46.png",
        "paint_name": "SCAR-20 | Kiralık Asker",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "100",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-100.png",
        "paint_name": "SCAR-20 | Fırtına",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "116",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-116.png",
        "paint_name": "SCAR-20 | Çöl Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "157",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-157.png",
        "paint_name": "SCAR-20 | Palmiye",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "896",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-896.png",
        "paint_name": "SCAR-20 | Söküp At",
        "legacy_model": false
    },
    {
        "weapon_defindex": 38,
        "weapon_name": "weapon_scar20",
        "paint": "1139",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_scar20-1139.png",
        "paint_name": "SCAR-20 | Gece Tavuğu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556.png",
        "paint_name": "SG 553 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "765",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-765.png",
        "paint_name": "SG 553 | Çöl Çiçeği",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "1022",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-1022.png",
        "paint_name": "SG 553 | Yıkıntı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "61",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-61.png",
        "paint_name": "SG 553 | Büyüleyici",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "298",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-298.png",
        "paint_name": "SG 553 | Ordu İhtişamı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "28",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-28.png",
        "paint_name": "SG 553 | Mavi Kaplama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "247",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-247.png",
        "paint_name": "SG 553 | Şam Çeliği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "363",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-363.png",
        "paint_name": "SG 553 | Gezgin Derisi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "598",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-598.png",
        "paint_name": "SG 553 | Hafif Gökyüzü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "553",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-553.png",
        "paint_name": "SG 553 | Atlas",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "1084",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-1084.png",
        "paint_name": "SG 553 | İş Hayatı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "1151",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-1151.png",
        "paint_name": "SG 553 | Yeşil Ejderha",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "1234",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-1234.png",
        "paint_name": "SG 553 | Siber Güç",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "487",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-487.png",
        "paint_name": "SG 553 | Gelecek Nesil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "955",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-955.png",
        "paint_name": "SG 553 | Karanlık Kanat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "287",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-287.png",
        "paint_name": "SG 553 | Elektronik Darbe",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "750",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-750.png",
        "paint_name": "SG 553 | Ralli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "897",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-897.png",
        "paint_name": "SG 553 | Bölge 4",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "613",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-613.png",
        "paint_name": "SG 553 | Üç Büyük",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "901",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-901.png",
        "paint_name": "SG 553 | Meyveli",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "1048",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-1048.png",
        "paint_name": "SG 553 | Ağır Metal",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "815",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-815.png",
        "paint_name": "SG 553 | Tehlikeli Mesafe",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "686",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-686.png",
        "paint_name": "SG 553 | Hayalet",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "966",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-966.png",
        "paint_name": "SG 553 | Paslı Bıçak",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "519",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-519.png",
        "paint_name": "SG 553 | Leopar Güvesi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "1320",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-1320.png",
        "paint_name": "SG 553 | Mavi Yarım Ton",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "98",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-98.png",
        "paint_name": "SG 553 | Ölümcül Menekşe",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "864",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-864.png",
        "paint_name": "SG 553 | Kırmızı Elma",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "101",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-101.png",
        "paint_name": "SG 553 | Kasırga",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "39",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-39.png",
        "paint_name": "SG 553 | Gözdağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "1270",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-1270.png",
        "paint_name": "SG 553 | Gece Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "861",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-861.png",
        "paint_name": "SG 553 | Yol Barikatı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "934",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-934.png",
        "paint_name": "SG 553 | Beyaz Kemik",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "243",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-243.png",
        "paint_name": "SG 553 | Timsah Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "378",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-378.png",
        "paint_name": "SG 553 | Radyasyon Uyarısı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "702",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-702.png",
        "paint_name": "SG 553 | Aloha",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "186",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-186.png",
        "paint_name": "SG 553 | Dalga Boyası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 39,
        "weapon_name": "weapon_sg556",
        "paint": "136",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_sg556-136.png",
        "paint_name": "SG 553 | Delikli Dalga",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08.png",
        "paint_name": "SSG 08 | Varsayılan",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "253",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-253.png",
        "paint_name": "SSG 08 | Asit Solması",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "70",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-70.png",
        "paint_name": "SSG 08 | Karbon Fiber",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "996",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-996.png",
        "paint_name": "SSG 08 | Tespit",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "60",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-60.png",
        "paint_name": "SSG 08 | Kara Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "361",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-361.png",
        "paint_name": "SSG 08 | Derinlik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "222",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-222.png",
        "paint_name": "SSG 08 | Kanlı Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "989",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-989.png",
        "paint_name": "SSG 08 | Sallantı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "670",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-670.png",
        "paint_name": "SSG 08 | Güve",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "624",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-624.png",
        "paint_name": "SSG 08 | Ejder Ateşi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "956",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-956.png",
        "paint_name": "SSG 08 | Rüya Gezgini",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "304",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-304.png",
        "paint_name": "SSG 08 | Çatlak",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "967",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-967.png",
        "paint_name": "SSG 08 | Sunucu 001",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "538",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-538.png",
        "paint_name": "SSG 08 | Medyum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "1052",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-1052.png",
        "paint_name": "SSG 08 | Ölümcül Vuruş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "503",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-503.png",
        "paint_name": "SSG 08 | Demir",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "899",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-899.png",
        "paint_name": "SSG 08 | Kanlı Savaşçı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "1101",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-1101.png",
        "paint_name": "SSG 08 | Hız ve Tutku",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "1251",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-1251.png",
        "paint_name": "SSG 08 | Mavi Gravür",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "554",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-554.png",
        "paint_name": "SSG 08 | Hayalet Savaşçı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "751",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-751.png",
        "paint_name": "SSG 08 | El Freni",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "513",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-513.png",
        "paint_name": "SSG 08 | Paradoks",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "877",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-877.png",
        "paint_name": "SSG 08 | Yarım Ton",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "868",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-868.png",
        "paint_name": "SSG 08 | Sahil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "200",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-200.png",
        "paint_name": "SSG 08 | Maya Düşü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "743",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-743.png",
        "paint_name": "SSG 08 | Turuncu İnce İş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "319",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-319.png",
        "paint_name": "SSG 08 | Dolaylı Yol",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "1060",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-1060.png",
        "paint_name": "SSG 08 | Bahar Eşarbı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "1289",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-1289.png",
        "paint_name": "SSG 08 | Kaplan",
        "legacy_model": false
    },
{
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "1304",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-1304.png",
        "paint_name": "SSG 08 | Yeşil Seramik",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "96",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-96.png",
        "paint_name": "SSG 08 | Mavi Ladin",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "762",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-762.png",
        "paint_name": "SSG 08 | Kana Bulanmış",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "99",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-99.png",
        "paint_name": "SSG 08 | Kum Tanesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "1271",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-1271.png",
        "paint_name": "SSG 08 | Gri Sis",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "1316",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-1316.png",
        "paint_name": "SSG 08 | Günbatımı Düşüşü",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "233",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-233.png",
        "paint_name": "SSG 08 | Tropikal Fırtına",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "26",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-26.png",
        "paint_name": "SSG 08 | Yosunlu Çizgi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "147",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-147.png",
        "paint_name": "SSG 08 | Orman Çizgisi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "935",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-935.png",
        "paint_name": "SSG 08 | Yağmacı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "1187",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-1187.png",
        "paint_name": "SSG 08 | Anıt",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "1161",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-1161.png",
        "paint_name": "SSG 08 | Felaket",
        "legacy_model": false
    },
    {
        "weapon_defindex": 40,
        "weapon_name": "weapon_ssg08",
        "paint": "128",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ssg08-128.png",
        "paint_name": "SSG 08 | Ölümcül Bölge",
        "legacy_model": false
    },
    {
        "weapon_defindex": 31,
        "weapon_name": "weapon_taser",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_taser.png",
        "paint_name": "Zeus X27 Şok Cihazı  | Default",
        "legacy_model": false
    },
    {
        "weapon_defindex": 31,
        "weapon_name": "weapon_taser",
        "paint": "292",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_taser-292.png",
        "paint_name": "Zeus X27 Şok Cihazı | Ejderha Efsanesi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 31,
        "weapon_name": "weapon_taser",
        "paint": "1297",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_taser-1297.png",
        "paint_name": "Zeus X27 Şok Cihazı | Bataklık DDPAT",
        "legacy_model": false
    },
    {
        "weapon_defindex": 31,
        "weapon_name": "weapon_taser",
        "paint": "1268",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_taser-1268.png",
        "paint_name": "Zeus X27 Şok Cihazı | Elektrik Mavisi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 31,
        "weapon_name": "weapon_taser",
        "paint": "1205",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_taser-1205.png",
        "paint_name": "Zeus X27 Şok Cihazı | Taşınabilir Şarj",
        "legacy_model": false
    },
    {
        "weapon_defindex": 31,
        "weapon_name": "weapon_taser",
        "paint": "1172",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_taser-1172.png",
        "paint_name": "Zeus X27 Şok Cihazı | Olimpos",
        "legacy_model": false
    },
    {
        "weapon_defindex": 31,
        "weapon_name": "weapon_taser",
        "paint": "1183",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_taser-1183.png",
        "paint_name": "Zeus X27 Şok Cihazı | Yıllık Balık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9.png",
        "paint_name": "Tec-9  | Default",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "248",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-248.png",
        "paint_name": "Tec-9 | Kızıl Kuvars",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "272",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-272.png",
        "paint_name": "Tec-9 | Titanyum Levha",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "36",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-36.png",
        "paint_name": "Tec-9 | Kemik Rengi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "555",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-555.png",
        "paint_name": "Tec-9 | Yeniden Alevlenen Savaş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "599",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-599.png",
        "paint_name": "Tec-9 | Buz Taç",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "216",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-216.png",
        "paint_name": "Tec-9 | Mavi Titanyum",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "159",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-159.png",
        "paint_name": "Tec-9 | Pirinç",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "671",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-671.png",
        "paint_name": "Tec-9 | Kağıt Kesme",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "303",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-303.png",
        "paint_name": "Tec-9 | Isaac",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "520",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-520.png",
        "paint_name": "Tec-9 | Kar Kürkü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "839",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-839.png",
        "paint_name": "Tec-9 | Bambu Kamuflaj",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "684",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-684.png",
        "paint_name": "Tec-9 | Kırık Opal",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "905",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-905.png",
        "paint_name": "Tec-9 | Işıltılı Adımlar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "1235",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-1235.png",
        "paint_name": "Tec-9 | İsyankar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "1252",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-1252.png",
        "paint_name": "Tec-9 | Çürümüş Mumya",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "289",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-289.png",
        "paint_name": "Tec-9 | Kum Fırtınası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "722",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-722.png",
        "paint_name": "Tec-9 | Yılan-9",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "889",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-889.png",
        "paint_name": "Tec-9 | Katliamcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "791",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-791.png",
        "paint_name": "Tec-9 | Uzaktan Kumanda",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "816",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-816.png",
        "paint_name": "Tec-9 | Hurda",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "964",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-964.png",
        "paint_name": "Tec-9 | Kardeşler Takımı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "539",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-539.png",
        "paint_name": "Tec-9 | Jambiya",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "614",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-614.png",
        "paint_name": "Tec-9 | Yakıt Enjektörü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "1024",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-1024.png",
        "paint_name": "Tec-9 | Kadim Totem",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "459",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-459.png",
        "paint_name": "Tec-9 | Bambu Ormanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "17",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-17.png",
        "paint_name": "Tec-9 | Şehir DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "463",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-463.png",
        "paint_name": "Tec-9 | Terörist",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "439",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-439.png",
        "paint_name": "Tec-9 | Hades",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "795",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-795.png",
        "paint_name": "Tec-9 | Güvenlik Ağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "738",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-738.png",
        "paint_name": "Tec-9 | Murano Turuncusu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "374",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-374.png",
        "paint_name": "Tec-9 | Nükleer Zehir",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "1010",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-1010.png",
        "paint_name": "Tec-9 | Phoenix Grafiti",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "235",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-235.png",
        "paint_name": "Tec-9 | Değişken Kamuflaj",
        "legacy_model": true
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "1299",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-1299.png",
        "paint_name": "Tec-9 | Ham Porselen",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "2",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-2.png",
        "paint_name": "Tec-9 | Yeraltı Suyu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "1279",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-1279.png",
        "paint_name": "Tec-9 | Mavi Patlama",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "206",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-206.png",
        "paint_name": "Tec-9 | Kükreyen Kasırga",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "1214",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-1214.png",
        "paint_name": "Tec-9 | Gümüş Kaplı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "766",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-766.png",
        "paint_name": "Tec-9 | Kaplan Deseni Şablonu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "1286",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-1286.png",
        "paint_name": "Tec-9 | Kayış-9",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "1322",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-1322.png",
        "paint_name": "Tec-9 | Sitrik Asit",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "733",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-733.png",
        "paint_name": "Tec-9 | Paslı Yaprak",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "242",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-242.png",
        "paint_name": "Tec-9 | Ordu Ağı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "179",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-179.png",
        "paint_name": "Tec-9 | Nükleer Caydırıcılık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 30,
        "weapon_name": "weapon_tec9",
        "paint": "1159",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_tec9-1159.png",
        "paint_name": "Tec-9 | Cüruf",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45.png",
        "paint_name": "UMP-45  | Default",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1085",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1085.png",
        "paint_name": "UMP-45 | Mekanik Düzenek",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "879",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-879.png",
        "paint_name": "UMP-45 | Solgun",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "37",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-37.png",
        "paint_name": "UMP-45 | Alevler İçinde",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "851",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-851.png",
        "paint_name": "UMP-45 | Şehirdeki Ay Işığı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "70",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-70.png",
        "paint_name": "UMP-45 | Karbon Fiber",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1049",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1049.png",
        "paint_name": "UMP-45 | Sarsıntı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "436",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-436.png",
        "paint_name": "UMP-45 | Yarış Kralı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "672",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-672.png",
        "paint_name": "UMP-45 | Alaşım Çiçeği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "441",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-441.png",
        "paint_name": "UMP-45 | Minotor'un Labirenti",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "615",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-615.png",
        "paint_name": "UMP-45 | Brifing",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "556",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-556.png",
        "paint_name": "UMP-45 | Vahşi Kılıç Diş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "488",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-488.png",
        "paint_name": "UMP-45 | İsyan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "704",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-704.png",
        "paint_name": "UMP-45 | Beyaz Kurt",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "688",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-688.png",
        "paint_name": "UMP-45 | İfşa",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "802",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-802.png",
        "paint_name": "UMP-45 | Momentum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "916",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-916.png",
        "paint_name": "UMP-45 | Plastik Patlayıcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1236",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1236.png",
        "paint_name": "UMP-45 | Vahşi Çocuk",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "281",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-281.png",
        "paint_name": "UMP-45 | Onbaşı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1003",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1003.png",
        "paint_name": "UMP-45 | Suç Mahalli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "652",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-652.png",
        "paint_name": "UMP-45 | İskele",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "990",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-990.png",
        "paint_name": "UMP-45 | Altın Bizmut",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1157",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1157.png",
        "paint_name": "UMP-45 | Barikat",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "412",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-412.png",
        "paint_name": "UMP-45 | Kızıl Ağ",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "725",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-725.png",
        "paint_name": "UMP-45 | Unutma Beni Çiçeği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "778",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-778.png",
        "paint_name": "UMP-45 | Tesis Serisi·Koyu Çizim",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "17",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-17.png",
        "paint_name": "UMP-45 | Şehir DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "15",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-15.png",
        "paint_name": "UMP-45 | Barut Dumanı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1008",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1008.png",
        "paint_name": "UMP-45 | Köpek Dişi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "362",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-362.png",
        "paint_name": "UMP-45 | Gizemli Saray",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "90",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-90.png",
        "paint_name": "UMP-45 | Çamur Katili",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "250",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-250.png",
        "paint_name": "UMP-45 | Tutuklayıcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "93",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-93.png",
        "paint_name": "UMP-45 | Karamel Rengi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "333",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-333.png",
        "paint_name": "UMP-45 | Mor ve Mavi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1303",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1303.png",
        "paint_name": "UMP-45 | Zümrüt Girdabı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-175.png",
        "paint_name": "UMP-45 | Yanık Rengi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "169",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-169.png",
        "paint_name": "UMP-45 | Radyasyon Uyarısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "193",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-193.png",
        "paint_name": "UMP-45 | Kemik Yığını",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "392",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-392.png",
        "paint_name": "UMP-45 | Halüsinasyon",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1175",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1175.png",
        "paint_name": "UMP-45 | Motorize",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1351",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1351.png",
        "paint_name": "UMP-45 | Continuum",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "131",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-131.png",
        "paint_name": "UMP-45 | Siyah Hayalet",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1194",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1194.png",
        "paint_name": "UMP-45 | K.O. Fabrikası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 24,
        "weapon_name": "weapon_ump45",
        "paint": "1203",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_ump45-1203.png",
        "paint_name": "UMP-45 | Gece Yarısı Yolculuğu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer.png",
        "paint_name": "USP Susturuculu  | Default",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "818",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-818.png",
        "paint_name": "USP Susturuculu | Mor DDPAT",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "221",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-221.png",
        "paint_name": "USP Susturuculu | Serum",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1027",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1027.png",
        "paint_name": "USP Susturuculu | Kilitli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "922",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-922.png",
        "paint_name": "USP Susturuculu | Turuncu Anol",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "60",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-60.png",
        "paint_name": "USP Susturuculu | Kara Su",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "277",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-277.png",
        "paint_name": "USP Susturuculu | Paslanmaz Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "339",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-339.png",
        "paint_name": "USP Susturuculu | Kayman",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "364",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-364.png",
        "paint_name": "USP Susturuculu | Ticari Deri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1102",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1102.png",
        "paint_name": "USP Susturuculu | Siyah Nilüfer",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "705",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-705.png",
        "paint_name": "USP Susturuculu | Beyin Fırtınası",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "637",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-637.png",
        "paint_name": "USP Susturuculu | Yeni Nesil",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "290",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-290.png",
        "paint_name": "USP Susturuculu | Muhafız",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "817",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-817.png",
        "paint_name": "USP Susturuculu | Geri Dönüş",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "504",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-504.png",
        "paint_name": "USP Susturuculu | Ateş Et ve Öldür",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "991",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-991.png",
        "paint_name": "USP Susturuculu | Küçük Yeşil Canavar",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1142",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1142.png",
        "paint_name": "USP Susturuculu | Çıkartma Koleksiyonu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "489",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-489.png",
        "paint_name": "USP Susturuculu | Tork",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "318",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-318.png",
        "paint_name": "USP Susturuculu | Otoban Katili",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "313",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-313.png",
        "paint_name": "USP Susturuculu | Avcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1136",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1136.png",
        "paint_name": "USP Susturuculu | Cehennem Bileti",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "657",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-657.png",
        "paint_name": "USP Susturuculu | Mavi Kopya",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "653",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-653.png",
        "paint_name": "USP Susturuculu | Siyah Hayalet",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "540",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-540.png",
        "paint_name": "USP Susturuculu | Kurşun Boru",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1040",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1040.png",
        "paint_name": "USP Susturuculu | Asılan Adam",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1253",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1253.png",
        "paint_name": "USP Susturuculu | Çöl Taktiği",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "830",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-830.png",
        "paint_name": "USP Susturuculu | Alp Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1323",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1323.png",
        "paint_name": "USP Susturuculu | Kanlı Bıçak",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "332",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-332.png",
        "paint_name": "USP Susturuculu | Safir Mavisi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "217",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-217.png",
        "paint_name": "USP Susturuculu | Kanlı Kaplan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "183",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-183.png",
        "paint_name": "USP Susturuculu | Çılgın Yayılma",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "236",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-236.png",
        "paint_name": "USP Susturuculu | Gece Yarısı Operasyonu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "454",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-454.png",
        "paint_name": "USP Susturuculu | Yeşil Paraşütçü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1065",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1065.png",
        "paint_name": "USP Susturuculu | Gümüş Kaplı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1217",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1217.png",
        "paint_name": "USP Susturuculu | Kraliyet Muhafızı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1284",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1284.png",
        "paint_name": "USP Susturuculu | Hindistan Cevizi Çiçeği",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1031",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1031.png",
        "paint_name": "USP Susturuculu | Kadim Fantezi",
        "legacy_model": true
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "443",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-443.png",
        "paint_name": "USP Susturuculu | Yol Bulucu",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "25",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-25.png",
        "paint_name": "USP Susturuculu | Orman Yaprakları",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "796",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-796.png",
        "paint_name": "USP Susturuculu | Motor Arıza Lambası",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "115",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-115.png",
        "paint_name": "USP Susturuculu | 27",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1186",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1186.png",
        "paint_name": "USP Susturuculu | PC-GRN",
        "legacy_model": false
    },
    {
        "weapon_defindex": 61,
        "weapon_name": "weapon_usp_silencer",
        "paint": "1173",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_usp_silencer-1173.png",
        "paint_name": "USP Susturuculu | Çene Kırıcı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": 0,
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014.png",
        "paint_name": "XM1014  | Default",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1021",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1021.png",
        "paint_name": "XM1014 | Kadim Efsane",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "994",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-994.png",
        "paint_name": "XM1014 | Eski Şart",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "760",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-760.png",
        "paint_name": "XM1014 | Buzdan Zincirler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "821",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-821.png",
        "paint_name": "XM1014 | Zarif Sarmaşık",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "370",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-370.png",
        "paint_name": "XM1014 | Kemik Kırıcı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1135",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1135.png",
        "paint_name": "XM1014 | Zombi Saldırısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "42",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-42.png",
        "paint_name": "XM1014 | Mavi Çelik",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "521",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-521.png",
        "paint_name": "XM1014 | Teclu Brülörü",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1046",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1046.png",
        "paint_name": "XM1014 | Sarıl Bana",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "505",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-505.png",
        "paint_name": "XM1014 | Scumbria",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "407",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-407.png",
        "paint_name": "XM1014 | Zehirli Cıva",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "689",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-689.png",
        "paint_name": "XM1014 | Çok Renkli Lekeli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "654",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-654.png",
        "paint_name": "XM1014 | Dört Mevsim",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "348",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-348.png",
        "paint_name": "XM1014 | Kırmızı Deri",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "146",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-146.png",
        "paint_name": "XM1014 | Canavar Karışımı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "970",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-970.png",
        "paint_name": "XM1014 | Gömülü Gölgeler",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "393",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-393.png",
        "paint_name": "XM1014 | Huzur",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "314",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-314.png",
        "paint_name": "XM1014 | Gökyüzü Muhafızı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "850",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-850.png",
        "paint_name": "XM1014 | Yanan Timsah",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "706",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-706.png",
        "paint_name": "XM1014 | Paslı Alev",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1254",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1254.png",
        "paint_name": "XM1014 | Hiyeroglif",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "557",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-557.png",
        "paint_name": "XM1014 | Takım Elbiseli",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1103",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1103.png",
        "paint_name": "XM1014 | Aslan",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1287",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1287.png",
        "paint_name": "XM1014 | Bakır Lekeli Kamuflaj",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "834",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-834.png",
        "paint_name": "XM1014 | Yarı Ton Geçişi",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1333",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1333.png",
        "paint_name": "XM1014 | Tuval Bulutları",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "166",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-166.png",
        "paint_name": "XM1014 | Alev Turuncusu",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "731",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-731.png",
        "paint_name": "XM1014 | Muz Yaprağı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "320",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-320.png",
        "paint_name": "XM1014 | Kanlı Kırmızı Piton",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "238",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-238.png",
        "paint_name": "XM1014 | Gök Mavisi Değişken Kamuflaj",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "240",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-240.png",
        "paint_name": "XM1014 | Kaliforniya Kamuflajı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "616",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-616.png",
        "paint_name": "XM1014 | Rüzgar Akımı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1267",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1267.png",
        "paint_name": "XM1014 | Sakız Kamuflajı",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "95",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-95.png",
        "paint_name": "XM1014 | Endüstriyel Ot",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "205",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-205.png",
        "paint_name": "XM1014 | Vahşi Orman",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "96",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-96.png",
        "paint_name": "XM1014 | Mavi Ladin",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1215",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1215.png",
        "paint_name": "XM1014 | Yalnızlık",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "169",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-169.png",
        "paint_name": "XM1014 | Radyasyon Uyarısı",
        "legacy_model": true
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "135",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-135.png",
        "paint_name": "XM1014 | Şehir Delikli",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1078",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1078.png",
        "paint_name": "XM1014 | Mavi Lastik",
        "legacy_model": false
    },
    {
        "weapon_defindex": 25,
        "weapon_name": "weapon_xm1014",
        "paint": "1201",
        "image": "https://raw.githubusercontent.com/Nereziel/cs2-WeaponPaints/main/website/img/skins/weapon_xm1014-1201.png",
        "paint_name": "XM1014 | Koş Koş Koş",
        "legacy_model": false
    }

local function skin_list_for(def)
    local names  = { "[ None ]" }
    local paints = { 0 }
    local src = def and SKINS[def]
    if src then
        for i = 1, #src do
            names[i+1]  = src[i][1]
            paints[i+1] = src[i][2]
        end
    end
    return names, paints
end

local ITEMS = {}
local function add_item(name, def, kind) ITEMS[#ITEMS+1] = { name = name, def = def, kind = kind } end

for i = 1, #KNIVES do
    local k = KNIVES[i]
    if k.def then add_item("[Knife] " .. k.name, k.def, "knife") end
end
for i = 1, #WEAPONS do
    add_item(WEAPONS[i].name, WEAPONS[i].def, "weapon")
end
for i = 1, #GLOVES do
    local g = GLOVES[i]
    add_item(g.def == 0 and "[Glove] Default (off)" or "[Glove] " .. g.name, g.def, "glove")
end

local itemNames = {}; for i = 1, #ITEMS do itemNames[i] = ITEMS[i].name end

local DEF_TO_ITEM = {}
for i = 1, #ITEMS do
    if ITEMS[i].kind ~= "glove" then DEF_TO_ITEM[ITEMS[i].def] = i end
end

local state = {
    cfg          = {},
    opts         = {},
    knifeDef     = nil,
    gloveDef     = nil,
    applied      = {},
    pendingReset = {},
    resetKnife   = false,
    resetGlove   = false,
    localModel       = nil,
    appliedLocalModel= nil,
    -- multiplayer model changer
    modelAssignments = {}, -- key -> path
    modelApplied     = {}, -- key -> last path we set
    modelPersist     = true,
    modelTargetMode  = 1,  -- 1 self, 2 teammates, 3 enemies, 4 selected
}

local Config = {}

local g_activeDef = nil

local function item_ptr(wpn) return wpn + off.m_AttributeManager + off.m_Item end

local function safe_wear(wear)
    if not wear or wear <= 0 then return 0.0001 end
    return wear
end

local function write_fallback(wpn, paint, wear, seed, stat, statval)
    w_i32(wpn + off.m_nFallbackPaintKit, paint)
    w_f32(wpn + off.m_flFallbackWear, safe_wear(wear))
    w_i32(wpn + off.m_nFallbackSeed, seed)
    w_i32(wpn + off.m_nFallbackStatTrak, stat and (statval or 0) or -1)
end

local function mark_item_custom(item)
    w_u32(item + off.m_iItemIDHigh, 0xFFFFFFFF)
    w_u8 (item + off.m_bInitialized, 1)
    w_u8 (item + off.m_bDisallowSOC, 0)
    w_u8 (item + off.m_bRestoreCustomMat, 1)
end

local function refresh_econ(wpn)
    vcall_void_bool(wpn, 10, true)
    vcall_void_bool(wpn, 110, true)
end

local function apply_knife_model(wpn)
    if fnptr.set_model then
        local vdata = r_ptr(wpn + off.m_nSubclassID + 8)
        if valid(vdata) then
            local s = read_cstr(vdata + off.m_szWorldModel, 160)
            if s:find("models/") and s:find("%.vmdl") then fnptr.set_model(ffi.cast("void*", wpn), s) end
        end
    end
    if fnptr.set_mesh_mask then
        local node = r_ptr(wpn + off.m_pGameSceneNode)
        if valid(node) then fnptr.set_mesh_mask(ffi.cast("void*", node), 2) end
    end
end

local function set_knife_subclass(wpn, def_target, quality)
    local item = item_ptr(wpn)
    w_u16(item + off.m_iItemDefinitionIndex, def_target)
    w_i32(item + off.m_iEntityQuality, quality)
    w_u32(wpn + off.m_nSubclassID, subclass_hash(def_target))
    if fnptr.update_subclass then fnptr.update_subclass(ffi.cast("void*", wpn)) end
    apply_knife_model(wpn)
    return item
end

local function process_knife(wpn, def_target, paint, wear, seed, stat, statval)
    local item = set_knife_subclass(wpn, def_target, 3)
    mark_item_custom(item)
    write_fallback(wpn, paint, wear, seed, stat, statval)
    refresh_econ(wpn)
    vcall_void(wpn, 195)
end

local function process_weapon(wpn, paint, wear, seed, stat, statval)
    mark_item_custom(item_ptr(wpn))
    write_fallback(wpn, paint, wear, seed, stat, statval)
    refresh_econ(wpn)
end

local function restore_weapon(wpn)
    write_fallback(wpn, 0, 0.0001, 0, false)
    refresh_econ(wpn)
end

local function restore_knife(wpn, pawn)
    local def_target = (r_u8(pawn + off.m_iTeamNum) == 2) and 59 or 42
    set_knife_subclass(wpn, def_target, 0)
    write_fallback(wpn, 0, 0.0001, 0, false)
    refresh_econ(wpn)
    vcall_void(wpn, 195)
end

local ATTR_STRUCT = 72

local game_alloc, game_free
local function resolve_mem()
    if game_alloc then return true end
    pcall(function() ffi.cdef[[ void* GetModuleHandleA(const char*); ]] end)
    pcall(function() ffi.cdef[[ void* GetProcAddress(void*, const char*); ]] end)
    local tier0
    pcall(function() tier0 = ffi.C.GetModuleHandleA("tier0.dll") end)
    if not tier0 then return false end
    local pa, pf
    pcall(function() pa = ffi.C.GetProcAddress(tier0, "MemAlloc_AllocFunc") end)
    pcall(function() pf = ffi.C.GetProcAddress(tier0, "MemAlloc_FreeFunc") end)
    if not pa or not pf then return false end
    pcall(function()
        game_alloc = ffi.cast("void*(*)(size_t)", pa)
        game_free  = ffi.cast("void(*)(void*)", pf)
    end)
    return game_alloc ~= nil and game_free ~= nil
end

local function glove_attr_remove(item)
    local addr = item + off.m_AttributeList + off.m_Attributes
    local size = r_ptr(addr)
    local ptr  = r_ptr(addr + 8)
    w_u64(addr, 0); w_u64(addr + 8, 0)
    if game_free and size ~= 0 and valid(ptr) then
        pcall(function() game_free(ffi.cast("void*", ptr)) end)
    end
end

local function glove_attr_set(item, paint, seed, wear)
    glove_attr_remove(item)
    if paint <= 0 then return end
    if not resolve_mem() then return end
    wear = safe_wear(wear)
    local raw  = game_alloc(ATTR_STRUCT * 3)
    local bptr = tonumber(ffi.cast("uintptr_t", raw))
    if not bptr or bptr == 0 then return end
    for i = 0, (ATTR_STRUCT * 3) / 8 - 1 do w_u64(bptr + i * 8, 0) end
    local function mk(i, def, val)
        local b = bptr + i * ATTR_STRUCT
        w_u16(b + 0x30, def); w_f32(b + 0x34, val); w_f32(b + 0x38, val)
    end
    mk(0, 6, paint)
    mk(1, 7, seed)
    mk(2, 8, wear)
    local addr = item + off.m_AttributeList + off.m_Attributes
    w_u64(addr, 3)
    w_u64(addr + 8, bptr)
end

local function local_account_id(base)
    local ctrl = r_ptr(base + off.dwLocalPlayerController)
    if not valid(ctrl) then return 0 end
    local sid = r_u64(ctrl + off.m_steamID)
    return tonumber(sid % 0x100000000)
end

local glove_key, glove_apply = nil, 0
local function apply_gloves(base, pawn, gdef, paint, wear, seed)
    local g    = pawn + off.m_EconGloves
    local cur  = r_u16(g + off.m_iItemDefinitionIndex)
    local init = r_u8 (g + off.m_bInitialized)
    local key  = gdef.."|"..paint.."|"..floor(wear*100000).."|"..seed

    if key ~= glove_key then glove_key = key; glove_apply = 6 end
    local engine_reset = (cur ~= gdef) or (init == 0)
    if engine_reset and glove_apply <= 0 then glove_apply = 2 end

    if glove_apply > 0 then
        local acc = local_account_id(base)
        w_u8 (g + off.m_bInitialized, 0)
        w_u16(g + off.m_iItemDefinitionIndex, gdef)
        w_i32(g + off.m_iEntityQuality, 3)
        w_u32(g + off.m_iItemIDHigh, 0xFFFFFFFF)
        w_u32(g + off.m_iItemIDLow,  0xFFFFFFFF)
        w_u32(g + off.m_iAccountID, acc)
        w_u32(g + off.m_OriginalOwnerXuidLow, acc)
        glove_attr_set(g, paint, seed, wear)
        w_u8 (g + off.m_bDisallowSOC, 0)
        w_u8 (g + off.m_bRestoreCustomMat, 1)
        w_u8 (g + off.m_bInitialized, 1)
        w_u8 (pawn + off.m_bNeedToReApplyGloves, 1)
        if fnptr.set_body_group then
            pcall(function() fnptr.set_body_group(ffi.cast("void*", pawn), "first_or_third_person", 1) end)
        end
        glove_apply = glove_apply - 1
    end
end

local function reset_gloves(pawn)
    local g = pawn + off.m_EconGloves
    w_u8 (g + off.m_bInitialized, 0)
    w_u16(g + off.m_iItemDefinitionIndex, 0)
    glove_attr_remove(g)
    w_u8 (pawn + off.m_bNeedToReApplyGloves, 1)
    glove_key, glove_apply = nil, 0
    if fnptr.set_body_group then
        pcall(function() fnptr.set_body_group(ffi.cast("void*", pawn), "first_or_third_person", 1) end)
    end
end

local function handle_to_entity(elist, hnd)
    if not valid(elist) or hnd == 0 or hnd == 0xFFFFFFFF then return nil end
    local idx   = band(hnd, 0x7FFF)
    local chunk = r_ptr(elist + 8 * rshift(idx, 9) + 16); if not valid(chunk) then return nil end
    local e     = r_ptr(chunk + 112 * band(idx, 0x1FF))
    if valid(e) and valid(r_ptr(e)) then return e end
    return nil
end

local function pawn_alive(pawn)

    local ls = r_u8 (pawn + off.m_lifeState)
    local hp = r_i32(pawn + off.m_iHealth)
    return ls == 0 and hp > 0 and hp < 100000
end

local function in_game()
    local cl, so = off.dwNetworkGameClient, off.dwNetworkGameClient_signOnState
    -- missing offsets: do NOT assume in-game (avoids SetModel on bad ptrs in menu)
    if not cl or not so then return false end
    local eng = mem.GetModuleBase("engine2.dll"); if not eng then return false end
    local client = r_ptr(eng + cl); if not valid(client) then return false end
    return r_i32(client + so) == 6
end

local function get_live_local()
    local ok, lp = pcall(entities.GetLocalPlayer)
    if not ok or not lp then return nil end
    local alive = false
    pcall(function() alive = lp:IsAlive() end)
    return alive and lp or nil
end

local model_ffi_done = false
local function model_ffi()
    if model_ffi_done then return end
    model_ffi_done = true
    pcall(function() ffi.cdef[[
        typedef struct {
            uint32_t dwFileAttributes;
            uint32_t ftCreationLo, ftCreationHi;
            uint32_t ftAccessLo,   ftAccessHi;
            uint32_t ftWriteLo,    ftWriteHi;
            uint32_t nFileSizeHigh, nFileSizeLow;
            uint32_t dwReserved0,  dwReserved1;
            char     cFileName[260];
            char     cAlternateFileName[14];
        } AW_FIND_DATA;
        void*    FindFirstFileA(const char*, AW_FIND_DATA*);
        int      FindNextFileA(void*, AW_FIND_DATA*);
        int      FindClose(void*);
        uint32_t GetCurrentDirectoryA(uint32_t, char*);
        typedef struct {
            int32_t  m_nLength;
            uint32_t m_nAllocatedSize;
            union { char* p; char s[8]; } u;
        } AW_CBufStr;
    ]] end)
    pcall(function() ffi.cdef[[ void* GetModuleHandleA(const char*); ]] end)
    pcall(function() ffi.cdef[[ void* GetProcAddress(void*, const char*); ]] end)
end

local function find_invalid() return ffi.cast("void*", ffi.cast("intptr_t", -1)) end

local function models_root()
    model_ffi()
    local buf = ffi.new("char[?]", 1024)
    local n = ffi.C.GetCurrentDirectoryA(1024, buf)
    local cwd = ffi.string(buf, n)

    local root, count = cwd:gsub("[\\/]bin[\\/]win64.*$", "\\csgo")
    if count == 0 then return nil end
    return root
end

local SCAN_DIRS = { "characters", "agents", "models" }
local SKIP_DIRS_ALT = { exg = true, materials = true }

local g_modelScanAlt = false
local g_modelFilter  = ""

local function scan_into(dir, names, paths, opts)
    opts = opts or {}
    local fd = ffi.new("AW_FIND_DATA")
    local h = ffi.C.FindFirstFileA(dir .. "\\*", fd)
    if h == find_invalid() then return end
    repeat
        local nm = ffi.string(fd.cFileName)
        if nm ~= "." and nm ~= ".." then
            local full = dir .. "\\" .. nm
            if band(fd.dwFileAttributes, 0x10) ~= 0 then
                local low = nm:lower()
                if not (opts.skip_exg_mat and SKIP_DIRS_ALT[low]) then
                    scan_into(full, names, paths, opts)
                end
            elseif nm:sub(-7) == ".vmdl_c" then
                local stem = nm:sub(1, #nm - 7)
                if not stem:lower():match("_arms?$") then
                    local p = full:lower():find("\\csgo\\", 1, true)
                    if p then
                        local rel = full:sub(p + 6):gsub("\\", "/")
                        rel = rel:sub(1, #rel - 2)
                        local filt = opts.filter
                        if filt and filt ~= "" then
                            local fl = filt:lower()
                            if not stem:lower():find(fl, 1, true) and not rel:lower():find(fl, 1, true) then
                                -- skip non-matching name
                            else
                                names[#names + 1] = stem
                                paths[#paths + 1] = rel
                            end
                        else
                            names[#names + 1] = stem
                            paths[#paths + 1] = rel
                        end
                    end
                end
            end
        end
    until ffi.C.FindNextFileA(h, fd) == 0
    ffi.C.FindClose(h)
end

local g_modelNames, g_modelPaths
local function scan_models()
    if g_modelNames then return g_modelNames, g_modelPaths end
    local names, paths = { "[ OFF ]" }, { "" }
    pcall(function()
        local root = models_root()
        if not root then return end
        local opts = {
            skip_exg_mat = g_modelScanAlt and true or false,
            filter = (g_modelFilter and g_modelFilter ~= "") and g_modelFilter or nil,
        }
        if g_modelScanAlt then
            scan_into(root .. "\\characters", names, paths, opts)
        else
            for _, sub in ipairs(SCAN_DIRS) do
                scan_into(root .. "\\" .. sub, names, paths, opts)
            end
        end
    end)
    g_modelNames, g_modelPaths = names, paths
    return names, paths
end
local function rescan_models()
    g_modelNames, g_modelPaths = nil, nil
    return scan_models()
end

local g_IRS = nil
local PRECACHE_SIG = "40 53 55 57 48 81 EC 80 00 00 00 48 8B 01 49 8B E8 48 8B FA"
local function resolve_model_fns()
    if fnptr.precache and g_IRS and fnptr.cbuf_insert then return true end
    model_ffi()
    if not fn.precache then
        local a = mem.FindPattern("resourcesystem.dll", PRECACHE_SIG)
        if a and a ~= 0 then fn.precache = a end
    end
    if fn.precache and not fnptr.precache then
        fnptr.precache = ffi.cast("void*(*)(void*, void*, const char*)", fn.precache)
    end
    if not g_IRS then
        pcall(function()
            local rs = ffi.C.GetModuleHandleA("resourcesystem.dll")
            local ci = rs and ffi.C.GetProcAddress(rs, "CreateInterface")
            if ci then
                local CI = ffi.cast("void*(*)(const char*, int*)", ci)
                local irs = CI("ResourceSystem013", nil)
                if irs ~= nil then g_IRS = irs end
            end
        end)
    end
    if not fnptr.cbuf_insert then
        pcall(function()
            local t0 = ffi.C.GetModuleHandleA("tier0.dll")
            local ins = t0 and ffi.C.GetProcAddress(t0, "?Insert@CBufferString@@QEAAPEBDHPEBDH_N@Z")
            if ins then fnptr.cbuf_insert = ffi.cast("const char*(*)(void*, int, const char*, int, int)", ins) end
        end)
    end
    return fnptr.precache ~= nil and g_IRS ~= nil and fnptr.cbuf_insert ~= nil
end

local function precache_model(path)
    if path == nil or path == "" then return end
    if not resolve_model_fns() then return end
    local cb = ffi.new("AW_CBufStr")
    cb.m_nLength = 0
    cb.m_nAllocatedSize = 0xC0000008
    cb.u.p = nil
    pcall(function() fnptr.cbuf_insert(cb, 0, path, -1, 0) end)
    pcall(function() fnptr.precache(g_IRS, cb, "") end)
end

local function safe_set_model(pawn, path)
    if not fnptr.set_model then return false end
    if not valid(pawn) then return false end
    if type(path) ~= "string" or path == "" or not path:find("%.vmdl") then return false end
    if (pawn % 8) ~= 0 then return false end
    if not valid(r_ptr(pawn)) then return false end
    precache_model(path)
    local ok = pcall(function() fnptr.set_model(ffi.cast("void*", pawn), path) end)
    return ok
end

local function entity_by_index(idx)
    if not idx or idx <= 0 or idx > 0x7fff then return nil end
    if not off.dwEntityList then return nil end
    if not in_game() then return nil end
    local ok, ent = pcall(function()
        local base = mem.GetModuleBase(DLL); if not base then return nil end
        local elist = r_ptr(base + off.dwEntityList); if not valid(elist) then return nil end
        local chunk = r_ptr(elist + 8 * rshift(idx, 9) + 16); if not valid(chunk) then return nil end
        local e = r_ptr(chunk + 112 * band(idx, 0x1FF))
        if valid(e) and valid(r_ptr(e)) then return e end
        return nil
    end)
    if ok and valid(ent) then return ent end
    return nil
end

local function player_display_name(pawn)
    local n
    pcall(function()
        local ctrl = pawn:GetPropEntity("m_hController")
        if ctrl then
            n = ctrl:GetName()
            if (not n or n == "") then n = ctrl:GetPropString("m_iszPlayerName") end
        end
        if (not n or n == "") then n = pawn:GetName() end
    end)
    if n and n ~= "" then return n end
    local idx = 0
    pcall(function() idx = pawn:GetIndex() end)
    return "#" .. tostring(idx)
end

local function player_key(pawn, is_local)
    if is_local then return "local" end
    local sid
    pcall(function()
        local ctrl = pawn:GetPropEntity("m_hController")
        if ctrl then
            sid = ctrl:GetProp("m_steamID")
            if not sid or sid == 0 then
                if ctrl.GetPropInt then sid = ctrl:GetPropInt("m_steamID") end
            end
        end
    end)
    if sid and tonumber(sid) and tonumber(sid) > 0 then return "s:" .. tostring(sid) end
    local idx = 0
    pcall(function() idx = pawn:GetIndex() end)
    return "i:" .. tostring(idx)
end

local function collect_alive_players()
    local out = {}
    local ok_f, pawns = pcall(entities.FindByClass, "C_CSPlayerPawn")
    if not ok_f or not pawns then return out end

    local ok_lp, lp = pcall(entities.GetLocalPlayer)
    if not ok_lp or not lp then
        ok_lp, lp = pcall(entities.GetLocalPawn)
    end
    local lp_idx = -1
    if ok_lp and lp then pcall(function() lp_idx = lp:GetIndex() end) end

    for _, pawn in pairs(pawns) do
        local alive, idx, team = false, 0, 0
        pcall(function() alive = pawn:IsAlive() end)
        if alive then
            pcall(function() idx = pawn:GetIndex() end)
            pcall(function() team = pawn:GetTeamNumber() end)
            if idx and idx > 0 then
                local is_local = (idx == lp_idx)
                out[#out + 1] = {
                    pawn = pawn,
                    raw = nil, -- resolve lazily only when applying in-game
                    idx = idx,
                    team = team or 0,
                    is_local = is_local,
                    name = player_display_name(pawn),
                    key = player_key(pawn, is_local),
                }
            end
        end
    end
    return out
end

local function model_needs_apply(info, path)
    if not path or path == "" then return false end
    if state.modelPersist then
        local cur
        pcall(function() cur = info.pawn:GetModelName() end)
        if type(cur) == "string" and cur == path then return false end
        return true
    end
    return state.modelApplied[info.key] ~= path
end

local function apply_path_to_player(info, path)
    if not info or not path or path == "" then return false end
    if not in_game() then return false end
    if not model_needs_apply(info, path) then return false end
    local raw = info.raw
    if not valid(raw) then
        raw = entity_by_index(info.idx)
        info.raw = raw
    end
    if not valid(raw) then return false end
    if safe_set_model(raw, path) then
        state.modelApplied[info.key] = path
        if info.is_local then
            state.appliedLocalModel = path
            state.overrideActive = true
        end
        return true
    end
    return false
end

local function apply_all_model_assignments()
    if not fnptr.set_model then return end
    if not in_game() then return end
    if not next(state.modelAssignments) and not (state.localModel and state.localModel ~= "") then
        return
    end
    local ok, players = pcall(collect_alive_players)
    if not ok or not players then return end
    for _, info in ipairs(players) do
        local path = state.modelAssignments[info.key]
        if (not path or path == "") and info.is_local then
            path = state.localModel
        end
        if path and path ~= "" then
            pcall(apply_path_to_player, info, path)
        end
    end
end

local function apply_local_model(pawn, lp)
    if not fnptr.set_model then return end
    if not valid(pawn) then return end
    if not in_game() then return end
    local path = state.modelAssignments["local"] or state.localModel
    if path and path ~= "" then
        if not lp then return end
        local info = { pawn = lp, raw = pawn, key = "local", is_local = true, idx = 0 }
        pcall(function() info.idx = lp:GetIndex() end)
        apply_path_to_player(info, path)
    else
        if state.appliedLocalModel == "OFF" then return end
        state.modelApplied["local"] = nil
        state.appliedLocalModel = "OFF"
    end
end

local function assign_models_to_target(mode, selected_key, path)
    if not in_game() then return 0 end
    local players = collect_alive_players()
    local lp_team = 0
    for _, info in ipairs(players) do
        if info.is_local then lp_team = info.team; break end
    end
    local count = 0
    for _, info in ipairs(players) do
        local match = false
        if mode == 1 then
            match = info.is_local
        elseif mode == 2 then
            match = (not info.is_local) and info.team == lp_team and lp_team > 1
        elseif mode == 3 then
            match = info.team ~= lp_team and info.team > 1
        elseif mode == 4 then
            match = selected_key and info.key == selected_key
        end
        if match then
            if path and path ~= "" then
                state.modelAssignments[info.key] = path
                if info.is_local then state.localModel = path end
                state.modelApplied[info.key] = nil
                pcall(apply_path_to_player, info, path)
            else
                state.modelAssignments[info.key] = nil
                state.modelApplied[info.key] = nil
                if info.is_local then
                    state.localModel = nil
                    state.appliedLocalModel = nil
                end
            end
            count = count + 1
        end
    end
    pcall(Config.save)
    return count
end

local function clear_model_assignments(mode, selected_key)
    return assign_models_to_target(mode, selected_key, nil)
end

local function clear_all_model_assignments()
    state.modelAssignments = {}
    state.modelApplied = {}
    state.localModel = nil
    state.appliedLocalModel = nil
    pcall(Config.save)
end

local function run()

    local lp = get_live_local()
    if not lp or not in_game() then
        if next(state.applied) then state.applied = {} end
        return
    end

    local base = mem.GetModuleBase(DLL); if not base then return end
    local ctrl = r_ptr(base + off.dwLocalPlayerController); if not valid(ctrl) then return end
    local myHandle = r_u32(ctrl + off.m_hPlayerPawn)
    if myHandle == 0 or myHandle == 0xFFFFFFFF then return end

    local elist = r_ptr(base + off.dwEntityList); if not valid(elist) then return end
    local pawn = handle_to_entity(elist, myHandle); if not valid(pawn) then return end
    if not valid(r_ptr(pawn + off.m_pGameSceneNode)) then return end

    if not pawn_alive(pawn) then
        if next(state.applied) then state.applied = {} end
        return
    end

    local applied = state.applied

    apply_all_model_assignments()
    apply_local_model(pawn, lp)

    if state.resetGlove then
        reset_gloves(pawn); state.resetGlove = false
    elseif state.gloveDef then
        local c = state.cfg[state.gloveDef]
        if c then apply_gloves(base, pawn, state.gloveDef, c.paint, c.wear, c.seed) end
    end

    local ws   = r_ptr(pawn + off.m_pWeaponServices); if not valid(ws) then return end
    local count= r_i32(ws + off.m_hMyWeapons)
    local arr  = r_ptr(ws + off.m_hMyWeapons + 8)
    if count<=0 or count>64 or not valid(arr) then return end

    local kdef = state.knifeDef
    local kc   = kdef and state.cfg[kdef]

    local did = false
    for i = 0, count - 1 do
        local wpn = handle_to_entity(elist, r_u32(arr + i*4))
        if wpn then

            if r_u32(wpn + off.m_hOwnerEntity) == myHandle then
                do
                    local def = r_u16(item_ptr(wpn) + off.m_iItemDefinitionIndex)
                    if is_knife(def) then
                        if state.resetKnife and not (kdef and kc) then
                            restore_knife(wpn, pawn); applied[wpn] = nil; state.resetKnife = false; did = true
                        elseif kdef and kc then
                            local s = "k|"..kdef.."|"..kc.paint.."|"..kc.wear.."|"..kc.seed.."|"..tostring(kc.stat).."|"..tostring(kc.statval or 0)
                            if applied[wpn] ~= s then
                                process_knife(wpn, kdef, kc.paint, kc.wear, kc.seed, kc.stat, kc.statval); applied[wpn]=s; did=true
                            end
                        end
                    else
                        if state.pendingReset[def] then
                            restore_weapon(wpn); applied[wpn] = nil; state.pendingReset[def] = nil; did = true
                        else
                            local c = state.cfg[def]
                            if c then
                                if c.paint > 0 then
                                    local s = "w|"..c.paint.."|"..c.wear.."|"..c.seed.."|"..tostring(c.stat).."|"..tostring(c.statval or 0)
                                    if applied[wpn] ~= s then
                                        process_weapon(wpn, c.paint, c.wear, c.seed, c.stat, c.statval); applied[wpn]=s; did=true
                                    end
                                else
                                    local s = "w|none"
                                    if applied[wpn] ~= s then
                                        restore_weapon(wpn); applied[wpn]=s; did=true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if did and fnptr.regen_skins then fnptr.regen_skins() end
end

local function active_weapon_def()
    if not get_live_local() then return nil end
    local base = mem.GetModuleBase(DLL); if not base then return nil end
    local ctrl = r_ptr(base + off.dwLocalPlayerController); if not valid(ctrl) then return nil end
    local elist = r_ptr(base + off.dwEntityList)
    local pawn = handle_to_entity(elist, r_u32(ctrl + off.m_hPlayerPawn)); if not valid(pawn) then return nil end
    local ws   = r_ptr(pawn + off.m_pWeaponServices); if not valid(ws) then return nil end
    local wpn  = handle_to_entity(elist, r_u32(ws + off.m_hActiveWeapon)); if not wpn then return nil end
    return r_u16(item_ptr(wpn) + off.m_iItemDefinitionIndex)
end

local CFG_FILE = "awchanger.txt"

local function file_write(path, data)
    local ok = false
    pcall(function()
        local f = file.Open(path, "w")
        if f then f:Write(data); f:Close(); ok = true end
    end)
    return ok
end

local function file_read(path)
    local data
    pcall(function()
        local f = file.Open(path, "r")
        if f then data = f:Read(); f:Close() end
    end)
    return data
end

function Config.serialize()
    local lines = { "AWCFG1",
                    "K " .. tostring(state.knifeDef or 0),
                    "G " .. tostring(state.gloveDef or 0) }
    for def, c in pairs(state.cfg) do
        lines[#lines + 1] = string.format("E %d %d %.6f %d %d %s %d",
            def, c.paint or 0, c.wear or 0.0001, c.seed or 0, c.stat and 1 or 0, c.kind or "weapon", c.statval or 0)
    end
    for k, v in pairs(state.opts) do
        local tv = type(v)
        local tag = (tv == "boolean") and "b" or (tv == "number") and "n" or "s"
        local sv  = (tv == "boolean") and (v and "1" or "0") or tostring(v)
        lines[#lines + 1] = string.format("O %s %s %s", k, tag, sv)
    end
    if state.localModel and state.localModel ~= "" then
        lines[#lines + 1] = "L " .. state.localModel
    end
    lines[#lines + 1] = "P " .. (state.modelPersist and "1" or "0")
    for key, path in pairs(state.modelAssignments) do
        if key ~= "local" and type(path) == "string" and path ~= "" then
            lines[#lines + 1] = "A " .. key .. " " .. path
        end
    end
    return table.concat(lines, "\n")
end

function Config.parse(str)
    if type(str) ~= "string" or not str:find("AWCFG1", 1, true) then return nil end
    local newCfg, kdef, gdef, opts, lmodel = {}, nil, nil, {}, nil
    local persist, assigns = true, {}
    for line in str:gmatch("[^\r\n]+") do
        local t = line:sub(1, 1)
        if t == "K" then
            local v = tonumber(line:match("^K%s+(%-?%d+)")); if v and v ~= 0 then kdef = v end
        elseif t == "G" then
            local v = tonumber(line:match("^G%s+(%-?%d+)")); if v and v ~= 0 then gdef = v end
        elseif t == "E" then
            local d, p, w, s, st, kind, sv =
                line:match("^E%s+(%-?%d+)%s+(%-?%d+)%s+([%d%.eE%+%-]+)%s+(%-?%d+)%s+(%d)%s+(%a+)%s*(%d*)")
            d, p, w, s = tonumber(d), tonumber(p), tonumber(w), tonumber(s)
            if d then
                newCfg[d] = { paint = p or 0, wear = w or 0.0001, seed = s or 0,
                              stat = (st == "1"), kind = kind or "weapon", statval = tonumber(sv) or 0 }
            end
        elseif t == "O" then
            local k, tag, v = line:match("^O%s+(%S+)%s+(%a)%s+(.*)$")
            if k then
                if     tag == "b" then opts[k] = (v == "1")
                elseif tag == "n" then opts[k] = tonumber(v) or 0
                else                   opts[k] = v end
            end
        elseif t == "L" then
            local v = line:match("^L%s+(.+)$")
            if v and v ~= "" then lmodel = v end
        elseif t == "P" then
            local v = line:match("^P%s+(%d)")
            persist = (v == "1")
        elseif t == "A" then
            local k, p = line:match("^A%s+(%S+)%s+(.+)$")
            if k and p and p ~= "" then assigns[k] = p end
        end
    end
    return newCfg, kdef, gdef, opts, lmodel, persist, assigns
end

function Config.applyTable(newCfg, kdef, gdef, opts, lmodel, persist, assigns)
    for def, c in pairs(state.cfg) do
        if c.kind == "weapon" and not newCfg[def] then state.pendingReset[def] = true end
    end
    if state.knifeDef and state.knifeDef ~= kdef then state.resetKnife = true end
    if state.gloveDef and state.gloveDef ~= gdef then state.resetGlove = true end
    state.cfg      = newCfg
    state.knifeDef = kdef
    state.gloveDef = gdef
    state.opts     = opts or {}
    state.localModel = lmodel
    state.appliedLocalModel = nil
    state.applied  = {}
    state.modelPersist = (persist ~= false)
    state.modelAssignments = assigns or {}
    if lmodel and lmodel ~= "" then state.modelAssignments["local"] = lmodel end
    state.modelApplied = {}
    g_modelScanAlt = not not state.opts.model_scan_alt
    g_modelFilter  = type(state.opts.model_filter) == "string" and state.opts.model_filter or ""
    g_modelNames, g_modelPaths = nil, nil
end

function Config.save() return file_write(CFG_FILE, Config.serialize()) end

function Config.load()
    local newCfg, kdef, gdef, opts, lmodel, persist, assigns = Config.parse(file_read(CFG_FILE))
    if not newCfg then return false end
    Config.applyTable(newCfg, kdef, gdef, opts, lmodel, persist, assigns)
    return true
end

local function commit()
    state.applied = {}
    Config.save()
end

local C = {}
C.items     = ITEMS
C.names     = itemNames
C.defToItem = DEF_TO_ITEM
C.offsets   = off

function C.skinList(def) return skin_list_for(def) end
function C.isKnife(def)  return is_knife(def) end
function C.activeDef()   return g_activeDef end
function C.knifeDef()    return state.knifeDef end
function C.getCfg(def)   return state.cfg[def] end

function C.apply(item, paint, wear, seed, stat, statval)
    if not item then return "nothing selected" end
    if item.kind == "glove" and item.def == 0 then
        state.cfg[0]     = nil
        state.gloveDef   = nil
        state.resetGlove = true
        commit()
        return "gloves: default"
    end
    state.cfg[item.def] = { paint = paint, wear = wear, seed = seed, stat = stat, statval = statval, kind = item.kind }
    if     item.kind == "knife" then state.knifeDef = item.def
    elseif item.kind == "glove" then state.gloveDef = item.def end
    commit()
    return string.format("applied: %s (paint %d)", item.name, paint)
end

function C.remove(item)
    if not item then return "nothing selected" end
    state.cfg[item.def] = nil
    if item.kind == "knife" then
        if state.knifeDef == item.def then state.knifeDef = nil end
        state.resetKnife = true
    elseif item.kind == "glove" then
        if state.gloveDef == item.def then state.gloveDef = nil end
        state.resetGlove = true
    else
        state.pendingReset[item.def] = true
    end
    commit()
    return "removed: " .. item.name
end

function C.resetAll()
    for def, c in pairs(state.cfg) do
        if c.kind == "weapon" then state.pendingReset[def] = true end
    end
    state.cfg        = {}
    state.knifeDef   = nil
    state.gloveDef   = nil
    state.resetKnife = true
    state.resetGlove = true
    commit()
    return "reset all"
end

function C.clearConfig()
    C.resetAll()
    pcall(function() file.Delete(CFG_FILE) end)
    return "config cleared"
end

function C.loadConfig() return Config.load() end
function C.getOpt(k)     return state.opts[k] end
function C.setOpt(k, v)  state.opts[k] = v; Config.save() end

function C.modelList()     return scan_models() end
function C.refreshModels() return rescan_models() end
function C.getModelScanAlt() return g_modelScanAlt end
function C.setModelScanAlt(on)
    g_modelScanAlt = not not on
    state.opts.model_scan_alt = g_modelScanAlt
    Config.save()
end
function C.getModelFilter() return g_modelFilter or "" end
function C.setModelFilter(q)
    g_modelFilter = tostring(q or "")
    state.opts.model_filter = g_modelFilter
    Config.save()
end
function C.getLocalModel() return state.localModel end
function C.setLocalModel(path)
    if path == nil or path == "" then
        state.localModel = nil
        state.modelAssignments["local"] = nil
    else
        state.localModel = path
        state.modelAssignments["local"] = path
    end
    state.appliedLocalModel = nil
    state.modelApplied["local"] = nil
    Config.save()
    return state.localModel
end

function C.getModelPersist() return state.modelPersist end
function C.setModelPersist(on)
    state.modelPersist = not not on
    state.opts.model_persist = state.modelPersist
    -- force re-check next tick
    state.modelApplied = {}
    state.appliedLocalModel = nil
    Config.save()
end

function C.listPlayers()
    return collect_alive_players()
end

function C.applyModelTarget(mode, selected_key, path)
    state.modelTargetMode = mode or 1
    return assign_models_to_target(mode or 1, selected_key, path)
end

function C.clearModelTarget(mode, selected_key)
    return clear_model_assignments(mode or 1, selected_key)
end

function C.clearAllModels()
    clear_all_model_assignments()
end

callbacks.Register("CreateMove", function()
    local okd, d = pcall(active_weapon_def); g_activeDef = okd and d or nil
    local ok, err = pcall(run)
    if not ok then print("[changer] error: " .. tostring(err)) end
end)

resolve()
pcall(resolve_model_fns)
local n = 0; for _ in pairs(SKINS) do n = n + 1 end
print(string.format("[changer] ready: %d weapons, set_model=%s", n, fn.set_model and "ok" or "NIL"))
local ok_root, root_str = pcall(models_root)
print(string.format("[changer] precache: fn=%s irs=%s cbuf=%s root=%s",
    fnptr.precache and "ok" or "NIL", g_IRS and "ok" or "NIL",
    fnptr.cbuf_insert and "ok" or "NIL", tostring(ok_root and root_str or "ERR")))

return C
