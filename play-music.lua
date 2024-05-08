local dfpwm = require("cc.audio.dfpwm")

local speaker = peripheral.find("speaker")
if (not speaker) then error("error: speaker not found") end

local decoder = dfpwm.make_decoder()
local listpath = "caches/music_list.txt"
local music_list = {""}


local function updateCache()
	local cacheFile = fs.open(listpath, "w")

    for _, line in ipairs(music_list) do
        cacheFile.writeLine(line[1] .. "|" .. line[2])
    end

	cacheFile.close()
end

local function play(path)
    for chunk in io.lines(path, 16 * 1024) do
        local buf = decoder(chunk)
        while not speaker.playAudio(buf) do
            local event, data = os.pullEvent()

            if (event == "key_up" and data == keys.enter) then
                return
            end
        end
    end
end

local function wget_play(url, filename)
    shell.run("wget " .. url .. "'" .. filename .. "'")
    if (fs.exists(filename)) then
        play(filename)
        fs.delete(filename)
    else
        print("wget failed :(")
    end
end


---- main
-- read from music_list if exists
if (fs.exists(listpath)) then
    local file = fs.open(listpath, "r")
    local line = file.readLine()
    local i = 1
    while (line) do
        if (music_list == {""}) then music_list = {} end
        music_list[i][1] = string.gmatch(line, "[^%|]+")
        music_list[i][2] = string.gmatch(line, "[^%|]+")
        
        line = file.readLine()
        i = i + 1
    end
end

if (#music_list > 10) then
    error("music list too long! ik its a skill issue but i dont wanna implement multi page ui-")
end


-- ui loop
while true do
    term.clear()

    print("songs:\n")
    if (music_list == {""}) then
        print("none")
    else
        for i, line in ipairs(music_list) do
            print(i .. ". " .. line[1])
        end
    end

    print("1-0: play song, W: add song, E: edit song, D: delete song")

    local event, key = os.pullEvent("key_up")
    if (key >= keys.one and key <= keys.zero and music_list ~= {""}) then
        local num = key - keys.one - 1

        if (music_list[num]) then
            wget_play(music_list[num][2], music_list[num][1])
        end
    elseif (key == keys.w) then
        if (#music_list > 9) then
            print("no there's too many already")
        else
            term.clear()

            print("new song title (spaces fine, pls no | thats my string separator):")
            local input1 = read()
            while (string.find(input1, "%|")) do
                print(">:(")
                input1 = read()
            end
            --music_list[#music_list+1][1] = input

            print("new song url (pls no | here either):")
            local input2 = read()
            while (string.find(input2, "%|")) do
                print(">:(")
                input2 = read()
            end
            --music_list[#music_list+1][2] = input

            table.insert(music_list, {input1, input2})

            updateCache()
        end
    elseif (key == keys.e) then
        print("which one? (1-0)")
        local event, key = os.pullEvent("key_up")
        if (key >= keys.one and key <= keys.zero and music_list ~= {""}) then
            local num = key - keys.one - 1

            if (music_list[num]) then
                term.clear()

                print("new song title (spaces fine, pls no | thats my string separator):")
                local input = read()
                while (string.find(input, "%|")) do
                    print(">:(")
                    input = read()
                end
                music_list[num][1] = input

                print("new song url (pls no | here either):")
                local input = read()
                while (string.find(input, "%|")) do
                    print(">:(")
                    input = read()
                end
                music_list[num][2] = input

                updateCache()
            end
        end
    elseif (key == keys.d) then
        print("which one? (1-0)")
        local event, key = os.pullEvent("key_up")
        if (key >= keys.one and key <= keys.zero and music_list ~= {""}) then
            local num = key - keys.one - 1

            if (music_list[num]) then
                print("removing " .. music_list[num][1])
                table.remove(music_list, num)
                updateCache()
                os.sleep(1)
            end
        end
    end
end