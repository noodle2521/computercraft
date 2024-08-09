local speaker = peripheral.find("speaker")
if (not speaker) then error("error: speaker not found") end

local success, httpPlayer = pcall(require, "httpPlayer")
if (not success) then
    shell.run("wget https://github.com/noodle2521/computercraft/raw/main/httpPlayer.lua httpPlayer.lua")
    httpPlayer = require("httpPlayer")
end


local songListPath = "caches/song_list.txt"
local playlistsPath = "caches/playlists.txt"


-- cache tables
local songList = {}
local playlists = {}

local sortedPlaylists = {}

-- constants
local bytesPerSecond = 6000 -- 48kHz cc: tweaked speakers, dfpwm has 1 bit samples

--- ui variables
local uiLayer = 1
local pageOffset = 0
--songs list
local maxSongPage = 0
--current playlist
local currentPlaylist = {}


local function updateCache(cacheTable, path)
	local cacheFile = fs.open(path, "w")

    for _, line in ipairs(cacheTable) do
        cacheFile.writeLine(table.concat(line, "|"))
    end

	cacheFile.close()
end

local function readCache(cacheTable, path)
    if (fs.exists(path)) then
        local file = fs.open(path, "r")
        local line = file.readLine()
        local i = 1
        while (line) do
            local entry = {}
            for str in string.gmatch(line, "[^%|]+") do
                table.insert(entry, str)
            end
            cacheTable[i] = entry
            
            line = file.readLine()
            i = i + 1
        end
    end
end

local function updatePlaylists(removedIndex)
    for i, line in ipairs(playlists) do
        local songInPlaylist = false

        -- binary search sorted playlist
        local sorted = sortedPlaylists[i]
        local k , j = 1, #sorted
        while (j > k) do
            if (sorted[k] == removedIndex or sorted[j] == removedIndex) then
                songInPlaylist = true
                break
            end

            local mid = math.floor(k + (j/2))
            if (removedIndex < mid) then
                j = mid - 1
            elseif (removedIndex > mid) then
                k = mid + 1
            else
                songInPlaylist = true
                break
            end
        end

        if (songInPlaylist) then
            local songs = { table.unpack(line, 2) }
            for i, song in ipairs(songs) do
                local id = tonumber(song)
                if (id > removedIndex) then
                    line[i] = id - 1;
                end
            end
        end
    end
end

-- *** INCONSISTENT DEPENDING ON VERSION OF CC: TWEAKED
local function keyToDigit(key)
    if (key < keys.zero or key > keys.nine) then
        --error("key is not a digit")
        return -1
    end

    return key - keys.one + 1
end


--- ui functions
local function playSongWithUI(url, prevName, nextName)
    local allowSeek, audioByteLength = httpPlayer.pollUrl(url)
    if (allowSeek == nil) then
        return
    end

    local exit = false
    local playbackOffset = 0

    local function playSong()
        httpPlayer.playFromUrl(url, "song_interrupt", "chunk_queued", playbackOffset, allowSeek, audioByteLength)
    end

    local function seek(newOffset)
        os.queueEvent("song_interrupt")
        local clampedOffset = math.max(0, math.min(newOffset, audioByteLength - 1))
        playbackOffset = clampedOffset
        return
    end

    local function songUI()
        local paused = false
        local lastChunkByteOffset = 0
        local lastChunkTime = os.clock()
        while true do
            term.clear()
            print("\n\nspace: pause, 0-9: seek, A,D: back/forward 5s, J,K: last/next song, X: exit")


            local event, val1, val2 = os.pullEvent()
            if (event == "chunk_queued") then
                lastChunkByteOffset = val1
                lastChunkTime = val2
            elseif (event == "key_up") then
                local key = val1

                local digit = keyToDigit(key)
                if (digit >= 0) then
                    local newOffset = math.floor((digit / 10) * audioByteLength)
                    seek(newOffset)
                    return
                end
                if (key == keys.x) then
                    os.queueEvent("song_interrupt")
                    exit = true
                    return
                end
            end
        end
    end


    repeat
        parallel.waitForAll(playSong, songUI)
    until exit
    os.sleep(0.5)
end

local function songListUI()
    print("songs:\n")
    if (#songList == 0) then
        print("none")
    else
        local start = (pageOffset) * 10 + 1
        for i = start, start + 9 do
            if (not songList[i]) then
                break
            end

            print(i .. ". " .. songList[i][1])
        end
    end

    print("\n\n1-0: play song, J,K: page down/up, A: add song, E: edit song, D: delete song, P: add to playlist, tab: playlists menu, X: exit")

    local event, key = os.pullEvent("key_up")
    local digit = keyToDigit(key)
    if (digit == 0) then
        digit = 10
    end
    if (digit >= 0 and #songList ~= 0) then
        local num = digit + (pageOffset * 10)

        if (songList[num]) then
            playSongWithUI(songList[num][2])
        end
    end
    -- jrop and klimb :relieved:
    if (key == keys.j) then
        pageOffset = math.min(pageOffset + 1, maxSongPage)
    end
    if (key == keys.k) then
        pageOffset = math.max(pageOffset - 1, 0)
    end
    if (key == keys.a) then
        --[[if (#songList > 9) then
            print("no there's too many already")
        else]]
        term.clear()

        print("new song title (spaces fine, pls no | thats my string separator):")
        local input1 = read()
        if (input1 == "") then
            goto continue
        end
        while (string.find(input1, "%|")) do
            print(">:(")
            input1 = read()
        end
        --songList[#songList+1][1] = input

        print("new song url (pls no | here either):")
        local input2 = read()
        if (input2 == "") then
            goto continue
        end
        while (string.find(input2, "%|")) do
            print(">:(")
            input2 = read()
        end
        --songList[#songList+1][2] = input

        table.insert(songList, {input1, input2})

        updateCache(songList, songListPath)
        maxSongPage = math.ceil(#songList / 10) - 1
    end
    if (key == keys.e) then
        print("which one? (1-0)")
        local event, key = os.pullEvent("key_up")
        local _digit = keyToDigit(key)
        if (_digit == 0) then
            _digit = 10
        end
        if (_digit >= 0 and #songList ~= 0) then
            local num = _digit + (pageOffset * 10)

            if (songList[num]) then
                term.clear()

                print("new song title (spaces fine, pls no | thats my string separator):")
                local input1 = read()
                if (input1 == "") then input1 = songList[num][1] end
                while (string.find(input1, "%|")) do
                    print(">:(")
                    input1 = read()
                end

                print("new song url (pls no | here either):")
                local input2 = read()
                if (input2 == "") then input2 = songList[num][2] end
                while (string.find(input2, "%|")) do
                    print(">:(")
                    input2 = read()
                end
                
                songList[num] = {input1, input2}

                updateCache(songList, songListPath)
            end
        end
    end
    if (key == keys.d) then
        print("which one? (1-0)")
        local event, key = os.pullEvent("key_up")
        local _digit = keyToDigit(key)
        if (_digit == 0) then
            _digit = 10
        end
        if (_digit >= 0 and #songList ~= 0) then
            local num = _digit + (pageOffset * 10)

            if (songList[num]) then
                print("removing " .. songList[num][1])
                table.remove(songList, num)
                updateCache(songList, songListPath)
                updatePlaylists(num)
                maxSongPage = math.ceil(#songList / 10) - 1
                os.sleep(1)
            end
        end
    end
    if (key == keys.p) then
        print("which one? (1-0)")
        local event, key = os.pullEvent("key_up")
        local _digit = keyToDigit(key)
        if (_digit == 0) then
            _digit = 10
        end
        if (_digit >= 0 and #songList ~= 0) then
            local num = _digit + (pageOffset * 10)
        end
    end
    if (key == keys.tab) then
        uiLayer = 2
    end
    if (key == keys.x) then
        uiLayer = 0
    end

    ::continue::
end

local function playlistsUI()
    --
end

local function currentPlaylistUI()
    --
end


---- main
-- read from song_list.txt if exists
readCache(songList, songListPath)
maxSongPage = math.ceil(#songList / 10) - 1

-- read from playlists.txt if exists
readCache(playlists, playlistsPath)
-- generate sortedPlaylists for faster contains check
for i, line in ipairs(playlists) do
    local sorted = { table.unpack(line, 2) }
    table.sort(sorted)
    sortedPlaylists[i] = sorted
end

--[[if (#songList > 10) then
    error("music list too long! ik its a skill issue but i dont wanna implement multi page ui-")
end]]


-- ui loop
while true do
    term.clear()

    if (uiLayer == 1) then
        songListUI()
    elseif (uiLayer == 2) then
        playlistsUI()
    elseif (uiLayer == 3) then
        currentPlaylistUI()
    else
        break
    end
end