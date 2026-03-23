---@diagnostic disable: undefined-global
local utils = require("mp.utils")

-- ════════════════════════════════════════════════════════════════════
-- FICHIERS DE SAUVEGARDE
-- ════════════════════════════════════════════════════════════════════
local history_file = utils.join_path(mp.command_native({"expand-path", "~~/"}), "last_played.txt")
local prefs_file   = utils.join_path(mp.command_native({"expand-path", "~~/"}), "folder_prefs.json")

local VALID_EXTENSIONS = {
    mkv=true, mp4=true, avi=true, m4v=true, webm=true,
    mp3=true, flac=true, wav=true, ogg=true
}

-- ════════════════════════════════════════════════════════════════════
-- GESTION DES PRÉFÉRENCES DE DOSSIER (Audio & Sous-titres)
-- ════════════════════════════════════════════════════════════════════
local loading_prefs = false

local function load_prefs()
    local f = io.open(prefs_file, "r")
    if not f then return {} end
    local content = f:read("*all")
    f:close()
    if content == "" then return {} end
    return utils.parse_json(content) or {}
end

local function save_prefs(prefs)
    local f = io.open(prefs_file, "w")
    if f then
        f:write(utils.format_json(prefs))
        f:close()
    end
end

local function on_track_change(name, value)
    if loading_prefs or not value then return end
    local path = mp.get_property("path")
    if not path then return end
    local dir, _ = utils.split_path(path)
    local prefs = load_prefs()
    if not prefs[dir] then prefs[dir] = {} end
    if prefs[dir][name] ~= value then
        prefs[dir][name] = value
        save_prefs(prefs)
    end
end

mp.observe_property("aid", "string", on_track_change)
mp.observe_property("sid", "string", on_track_change)

-- ════════════════════════════════════════════════════════════════════
-- UTILITAIRE : tri naturel
-- ════════════════════════════════════════════════════════════════════
local function padnum(d) return ("%03d%s"):format(#d, d) end
local function natural_less(a, b)
    return tostring(a):lower():gsub("%d+", padnum) < tostring(b):lower():gsub("%d+", padnum)
end

-- ════════════════════════════════════════════════════════════════════
-- GESTION DE LA LECTURE EN COURS (Autoresume & Autoload)
-- ════════════════════════════════════════════════════════════════════
mp.register_event("file-loaded", function()
    local path = mp.get_property("path")
    if not path then return end

    local dir, current_filename = utils.split_path(path)

    -- 1. SAUVEGARDE L'HISTORIQUE GLOBAL
    local f = io.open(history_file, "w")
    if f then f:write(path) f:close() end

    -- 2. APPLIQUE LES PRÉFÉRENCES DU DOSSIER
    local prefs = load_prefs()
    if prefs[dir] then
        loading_prefs = true
        if prefs[dir].aid then mp.set_property("aid", prefs[dir].aid) end
        if prefs[dir].sid then mp.set_property("sid", prefs[dir].sid) end
        mp.add_timeout(0.5, function() loading_prefs = false end)
    end

    -- 3. AUTOLOAD : charge TOUT le dossier dans la playlist
    if mp.get_property_number("playlist-count") == 1 then
        local files = utils.readdir(dir, "files")
        if not files then return end

        local media_files = {}
        for _, file in ipairs(files) do
            local ext = file:match("%.([^%.]+)$")
            if ext and VALID_EXTENSIONS[ext:lower()] then
                table.insert(media_files, file)
            end
        end

        table.sort(media_files, natural_less)

        -- Trouve l'index du fichier courant
        local current_index = nil
        for i, file in ipairs(media_files) do
            if file == current_filename then
                current_index = i
                break
            end
        end
        if not current_index then return end

        -- Ajoute tous les autres fichiers du dossier à la suite
        -- puis repositionne sur le fichier courant
        for i, file in ipairs(media_files) do
            if i ~= current_index then
                mp.commandv("loadfile", utils.join_path(dir, file), "append")
            end
        end

        -- Déplace le fichier courant à sa bonne position dans la playlist
        -- Il est actuellement à l'index 0, il doit aller à current_index-1
        if current_index > 1 then
            mp.commandv("playlist-move", 0, current_index)
        end
    end
end)

-- ════════════════════════════════════════════════════════════════════
-- REPRISE AU DÉMARRAGE À VIDE
-- ════════════════════════════════════════════════════════════════════
mp.add_timeout(0.1, function()
    if mp.get_property_number("playlist-count", 0) == 0 then
        local f = io.open(history_file, "r")
        if f then
            local last_file = f:read("*all")
            f:close()
            if last_file and last_file ~= "" then
                mp.commandv("loadfile", last_file)
            end
        end
    end
end)