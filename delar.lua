engine.name = 'DelarSequencer'
tabutil = require "tabutil"
ui = require "ui"
local pages
g = grid.connect()
leds = {}
keys_counter = {}

sample_path = paths.home .. "/dust/audio/delar/"
is_playing = false
playing_step = 0
playing_step_led_brightness = 15
sequence = {}
sequence_position = 1
steps = {}
max_num_steps = 256
num_synth_params = 12
selected_screen_param = 1
num_screen_params = 12

p = {
    attack = {
        name = "attack",
        default = 0.01
    },
    cutoff = {
        name = "cutoff",
        default = 20000
    },
    length = {
        name = "length",
        default = 0
    },
    level = {
        name = "level",
        default = 0.5
    },
    playback_rate = {
        name = "playback_rate",
        default = 1.0
    },
    rand_freq = {
        name = "rand_freq",
        default = 1
    },
    rand_length_amount = {
        name = "rand_length_amount",
        default = 0
    },
    rand_length_unquantized = {
        name = "rand_length_unquantized",
        default = 0
    },
    rand_pan_amount = {
        name = "rand_pan_amount",
        default = 0
    },
    release = {
        name = "release",
        default = 0.01
    }
}

function init()
    -- Init UI
    pages = ui.Pages.new(1, 3)

    for i = 1, max_num_steps do
        steps[i] = {
            enabled = false,
            altered = false
        }
    end

    for i = 1, 8 do
        for j = 1, 16 do
            table.insert(leds, {
                x = j,
                y = i
            })
        end
    end

    for x = 1, 16 do -- for each x-column (16 on a 128-sized grid)...
        keys_counter[x] = {} -- create a x state counter.
    end

    init_params()

    params:bang()
    params:set("enabled32", 1)
    engine.setSample(sample_path .. "piano1.wav")
    is_playing = true
    -- engine.set_num_slices(max_num_steps)

    screen_dirty = true
    screen_clock = clock.run(screen_redraw_clock)

    grid_dirty = true
    grid_clock = clock.run(grid_redraw_clock)

    playing_step_led_clock = clock.run(playing_step_led_clock)
end

function init_params()
    params:add_number("num_steps", "num steps", 1, max_num_steps, 127)
    params:set_action("num_steps", function(x)
        engine.set_num_slices(x)
    end)
    params:add_number("selected_step", "step", 1, max_num_steps, 1)
    params:set_action("selected_step", function(x)
        if x > params:get("num_steps") then
            params:set("selected_step", params:get("num_steps"))
        end
    end)
    params:add_file("sample", "sample", sample_path)
    params:set_action("sample", function(x)
        engine.setSample(x)
    end)

    attack = controlspec.def {
        min = 0.01, -- the minimum value
        max = 1.0, -- the maximum value
        warp = 'lin', -- a shaping option for the raw value
        step = 0.01, -- output value quantization
        default = p.attack.default, -- default value
        quantum = 0.002, -- each delta will change raw value by this much
        wrap = false -- wrap around on overflow (true) or clamp (false)
    }
    cutoff = controlspec.def {
        min = 30,
        max = 20000,
        warp = 'lin',
        step = 0.01,
        default = p.cutoff.default,
        quantum = 0.002,
        wrap = false
    }
    length = controlspec.def {
        min = -100.0,
        max = 100.0,
        warp = 'lin',
        step = 0.01,
        default = p.length.default,
        quantum = 0.002,
        wrap = false
    }
    level = controlspec.def {
        min = 0.0,
        max = 1.0,
        warp = 'lin',
        step = 0.01,
        default = p.level.default,
        quantum = 0.002,
        wrap = false
    }
    playbackRate = controlspec.def {
        min = 0.25,
        max = 32.0,
        warp = 'lin',
        step = 0.0001,
        default = p.playback_rate.default,
        quantum = 0.0001,
        wrap = false
    }
    rand_freq = controlspec.def {
        min = 0.1,
        max = 2.0,
        warp = 'lin',
        step = 0.01,
        default = p.rand_freq.default,
        quantum = 0.002,
        wrap = false
    }
    rand_length_amount = controlspec.def {
        min = 0.0,
        max = 100.0,
        warp = 'lin',
        step = 0.01,
        default = p.rand_length_amount.default,
        quantum = 0.002,
        wrap = false
    }
    rand_pan_amount = controlspec.def {
        min = 0.0,
        max = 100.0,
        warp = 'lin',
        step = 0.01,
        default = p.rand_pan_amount.default,
        quantum = 0.002,
        wrap = false
    }
    release = controlspec.def {
        min = 0.01,
        max = 1.0,
        warp = 'lin',
        step = 0.01,
        default = p.release.default,
        quantum = 0.002,
        wrap = false
    }
    params:add_number("rotation", "rotation", -1, 1, 0)
    params:set_action("rotation", function(x)
        if x > 0 or x < 0 then
            rotate(x)
        end
        params:set("rotation", 0)
    end)

    params:add_control(p.attack.name, "attack", attack)
    params:add_control(p.cutoff.name, "cutoff", cutoff)
    params:add_control(p.length.name, "length", length)
    params:add_control(p.level.name, "level", level)
    params:add_control(p.rand_freq.name, "rand freq", rand_freq)
    params:add_control(p.rand_length_amount.name, "rand length", rand_length_amount)
    params:add_number(p.rand_length_unquantized.name, "unquantize rand length", 0, 1, p.rand_length_unquantized.default)
    params:add_control(p.rand_pan_amount.name, "rand pan", rand_pan_amount)
    params:add_control(p.playback_rate.name, "rate", playbackRate)
    params:add_control(p.release.name, "release", release)

    for i = 1, max_num_steps do
        params:add_group("step " .. i, num_synth_params)
        -- params:hide("step " .. i)
        params:add_number("enabled" .. i, "enabled", 0, 1, 0)
        params:set_action("enabled" .. i, function(x)
            steps[i].enabled = (x == 1)
        end)
        params:add_number("altered" .. i, "altered", 0, 1, 0)
        params:set_action("altered" .. i, function(x)
            -- print("altered" .. i .. " changed to " .. x)
            if params_not_default(i) then
                steps[i].altered = true
            else
                params:set("altered" .. i, 0)
                steps[i].altered = false
            end
        end)
        params:add_control(p.attack.name .. i, "attack", attack)
        params:set_action(p.attack.name .. i, function(x)
            -- print("attack" .. i .. " changed to " .. x)
            params:set("altered" .. i, params:get("altered" .. i) ~ 1)
        end)
        params:add_control(p.cutoff.name .. i, "cutoff", cutoff)
        params:set_action(p.cutoff.name .. i, function(x)
            params:set("altered" .. i, params:get("altered" .. i) ~ 1)
        end)
        params:add_control(p.length.name .. i, "length", length)
        params:set_action(p.length.name .. i, function(x)
            params:set("altered" .. i, params:get("altered" .. i) ~ 1)
        end)
        params:add_control(p.level.name .. i, "level", level)
        params:set_action(p.level.name .. i, function(x)
            params:set("altered" .. i, params:get("altered" .. i) ~ 1)
        end)
        params:add_control(p.rand_freq.name .. i, "rand freq", rand_freq)
        params:set_action(p.rand_freq.name .. i, function(x)
            params:set("altered" .. i, params:get("altered" .. i) ~ 1)
        end)
        params:add_control(p.rand_length_amount.name .. i, "rand length", rand_length_amount)
        params:set_action(p.rand_length_amount.name .. i, function(x)
            params:set("altered" .. i, params:get("altered" .. i) ~ 1)
        end)
        params:add_number(p.rand_length_unquantized.name .. i, "unquantize rand length", 0, 1,
            p.rand_length_unquantized.default)
        params:set_action(p.rand_length_amount.name .. i, function(x)
            params:set("altered" .. i, params:get("altered" .. i) ~ 1)
        end)
        params:add_control(p.rand_pan_amount.name .. i, "rand pan", rand_pan_amount)
        params:set_action(p.rand_pan_amount.name .. i, function(x)
            params:set("altered" .. i, params:get("altered" .. i) ~ 1)
        end)
        params:add_control(p.playback_rate.name .. i, "rate", playbackRate)
        params:set_action(p.playback_rate.name .. i, function(x)
            params:set("altered" .. i, params:get("altered" .. i) ~ 1)
        end)
        params:add_control(p.release.name .. i, "release", release)
        params:set_action(p.release.name .. i, function(x)
            params:set("altered" .. i, params:get("altered" .. i) ~ 1)
        end)
    end
end

function rotate(x)
    local params_to_rotate = {"enabled", "altered", p.attack.name, p.cutoff.name, p.length.name, p.level.name,
                              p.playback_rate.name, p.rand_freq.name, p.rand_length_amount.name,
                              p.rand_length_unquantized.name, p.rand_pan_amount.name, p.release.name}
    local num_steps = params:get("num_steps")

    -- store all params in a table
    local all_params = {}
    for i = 1, num_steps do
        all_params[i] = {}
        for _, param in ipairs(params_to_rotate) do
            all_params[i][param] = params:get(param .. i)
        end
    end

    -- rotate the table
    local rotate_steps = x % num_steps -- calculate the number of steps to rotate
    if rotate_steps ~= 0 then -- only rotate if there are steps to rotate
        if rotate_steps < 0 then -- rotate left
            rotate_steps = rotate_steps + num_steps
        end
        for i = 1, rotate_steps do
            table.insert(all_params, 1, table.remove(all_params, num_steps))
        end
    end

    -- set all params to the new values
    for i = 1, num_steps do
        for _, param in ipairs(params_to_rotate) do
            params:set(param .. i, all_params[i][param])
        end
    end
end

function params_not_default(step)
    local params_to_check = {p.attack, p.cutoff, p.length, p.level, p.rand_freq, p.rand_length_amount,
                             p.rand_length_unquantized, p.rand_pan_amount, p.playback_rate, p.release}
    for _, param in ipairs(params_to_check) do
        if params:get(param.name .. step) ~= param.default then
            return true
        end
    end
    return false
end

function key(n, z)
    if n == 2 and z == 1 then
        if is_playing then
            stop()
        else
            play()
        end
    end

    if n == 3 and z == 1 then
        -- toggle step enabled/disabled
        local selected_step = params:get("selected_step")
        if params:get("enabled" .. selected_step) == 1 then
            params:set("enabled" .. selected_step, 0)
        else
            params:set("enabled" .. selected_step, 1)
        end
    end
end

function osc_in(path, args, from)
    if path == "/step" then
        playing_step = args[1] + 1 -- lua is 1-indexed
        -- print("playing step: " .. playing_step)
        tick()
    elseif path == "/x" then
        -- step = args[1]
    else
        print(path)
        tab.print(args)
    end
    -- print("osc from " .. from[1] .. " port " .. from[2])
end

osc.event = osc_in

function tick()
    sequence = get_active_steps(steps)
    -- playing_step = sequence_position

    sequence_position = (sequence_position + 1)
    if sequence_position > #sequence then
        sequence_position = 1
    end

    if #sequence > 0 then
        send_next_step(sequence[sequence_position])
    else
        stop()
    end
    playing_step_led_brightness = 15
    screen_dirty = true
    grid_dirty = true
end

function play()
    sequence = get_active_steps(steps)
    sequence_position = 1
    send_next_step(sequence[sequence_position])
    engine.play()
    is_playing = true
end

function stop()
    engine.stop()
    is_playing = false
    playing_step = 0
end

function get_active_steps(steps)
    local active_steps = {}
    for i = 1, #steps do
        if steps[i].enabled then
            table.insert(active_steps, i)
        end
    end
    return active_steps
end

function send_next_step(step)
    local params_to_check = {p.attack.name, p.cutoff.name, p.length.name, p.level.name, p.playback_rate.name,
                             p.rand_freq.name, p.rand_length_amount.name, p.rand_length_unquantized.name,
                             p.rand_pan_amount.name, p.release.name}
    local engine_params = {}
    for i, param in ipairs(params_to_check) do
        local value = params:get(param .. step)
        if value == p[param].default then
            value = params:get(param)
        end
        engine_params[i] = value
    end
    engine.set_all(step, table.unpack(engine_params))
end

function enc(n, d)
    local selected_step = params:get("selected_step")
    if n == 1 then
        -- Page scroll
        pages:set_index_delta(util.clamp(d, -1, 1), false)
    end

    if n == 2 then
        selected_screen_param = util.clamp(selected_screen_param + d, 1, num_screen_params)
    end

    if pages.index == 1 then
        if n == 3 then
            params:set("selected_step", util.clamp(selected_step + d, 1, params:get("num_steps")))
        end
    end

    if n == 3 then
        if selected_screen_param == 1 then
            selected_step = util.clamp(selected_step + d, 1, params:get("num_steps"))
        elseif selected_screen_param == 2 then
            params:set(p.attack.name .. selected_step,
                util.clamp(params:get(p.attack.name .. selected_step) + d / 100, 0.01, 1))
        elseif selected_screen_param == 3 then
            params:set(p.length.name .. selected_step,
                util.clamp(params:get(p.length.name .. selected_step) + d / 10, -100, 100))
        elseif selected_screen_param == 4 then
            params:set(p.level.name .. selected_step,
                util.clamp(params:get(p.level.name .. selected_step) + d / 10, 0, 1))
        elseif selected_screen_param == 5 then
            params:set(p.playback_rate.name .. selected_step,
                util.clamp(params:get(p.playback_rate.name .. selected_step) + d / 100, 0.25, 32))
        elseif selected_screen_param == 6 then
            params:set(p.rand_freq.name .. selected_step,
                util.clamp(params:get(p.rand_freq.name .. selected_step) + d / 10, 0, 100))
        elseif selected_screen_param == 7 then
            params:set(p.rand_length_amount.name .. selected_step,
                util.clamp(params:get(p.rand_length_amount.name .. selected_step) + d / 10, 0, 100))
        elseif selected_screen_param == 8 then
            params:set(p.rand_length_unquantized.name .. selected_step,
                util.clamp(params:get(p.rand_length_unquantized.name .. selected_step) + d / 1, 0, 1))
        elseif selected_screen_param == 9 then
            params:set(p.rand_pan_amount.name .. selected_step,
                util.clamp(params:get(p.rand_pan_amount.name .. selected_step) + d / 10, 0, 1))
        elseif selected_screen_param == 10 then
            params:set(p.release.name .. selected_step,
                util.clamp(params:get(p.release.name .. selected_step) + d / 100, 0.01, 1))
        elseif selected_screen_param == 11 then
            params:set("rotation", util.clamp(params:get("rotation") + d / 100, -1, 1))
        elseif selected_screen_param == 12 then
            params:set(p.cutoff.name .. selected_step,
                util.clamp(params:get(p.cutoff.name .. selected_step) + d / 100, 30, 20000))
        end
    end
    screen_dirty = true
end

function screen_redraw_clock()
    while true do
        clock.sleep(1 / 15)
        if screen_dirty then
            redraw()
        end
    end
end

function redraw()
    screen.clear()

    pages:redraw()

    -- for m = 1, 5 do
    --     for n = 1, 5 do
    --         screen.rect(0.5 + m * 9, 0.5 + n * 9, 6, 6) -- (x,y,width,height)
    --         l = 2
    --         screen.level(l)
    --         screen.stroke()
    --     end
    -- end

    if pages.index == 1 then

        local selected_step = params:get("selected_step")
        local playing_step = playing_step

        -- Limit the number of squares to a minimum of 1 and a maximum of 256
        local num_steps = params:get("num_steps")

        -- Get the total width and height of the screen (you can adjust these values)
        local screenWidth = 128 -- Example: Change this to your actual screen width
        local screenHeight = 64 -- Example: Change this to your actual screen height

        -- Determine the size of each square on the x-axis
        local stepSizeX = 6
        local stepSizeY = 6

        -- Calculate the number of rows and columns to form the grid
        local numColumns = 16
        local numRows = 8

        -- Full grid
        for row = 1, numRows do
            for col = 1, numColumns do
                local stepX = col * stepSizeX
                local stepY = row * stepSizeY

                screen.rect(stepX, stepY, stepSizeX, stepSizeY)
                screen.level(1)
                screen.stroke()
            end
        end

        -- -- Active steps
        -- for row = 1, numRows do
        --     for col = 1, numColumns do
        --         local stepX = col * stepSizeX
        --         local stepY = row * stepSizeY

        --         if (row - 1) * numColumns + col <= num_steps then
        --             screen.rect(stepX, stepY, stepSizeX, stepSizeY)
        --             screen.level(5)
        --             screen.stroke()
        --         end
        --     end
        -- end

        -- Enabled steps
        for row = 1, numRows do
            for col = 1, numColumns do
                local stepX = col * stepSizeX
                local stepY = row * stepSizeY

                if steps[(row - 1) * numColumns + col].enabled then
                    screen.rect(stepX, stepY, stepSizeX, stepSizeY)
                    screen.level(5)
                    screen.stroke()
                end
            end
        end

        -- Playing step
        for row = 1, numRows do
            for col = 1, numColumns do
                local stepX = col * stepSizeX
                local stepY = row * stepSizeY

                if (row - 1) * numColumns + col == playing_step then
                    screen.rect(stepX + 2, stepY + 2, 2, 2)
                    screen.level(15)
                    screen.stroke()
                end
            end
        end

        -- Selected steps
        for row = 1, numRows do
            for col = 1, numColumns do
                local stepX = col * stepSizeX
                local stepY = row * stepSizeY

                if (row - 1) * numColumns + col == selected_step then
                    screen.rect(stepX, stepY, stepSizeX, stepSizeY)
                    screen.level(15)
                    screen.stroke()
                end
            end
        end

    elseif pages.index == 2 then
        -- step
        screen.font_size(8)
        screen.level(15)
        screen.move(5, 5)

        if playing_step > 0 then
            screen.text("step: " .. playing_step)
        else
            screen.text("step: -")
        end

        -- params
        screen.font_size(8)
        local selected_step = params:get("selected_step")

        screen.level(selected_screen_param == 1 and 15 or 2)
        screen.move(80, 5)
        screen.text_right("step:")
        screen.move(85, 5)
        screen.text(selected_step)

        screen.level(selected_screen_param == 2 and 15 or 2)
        screen.move(55, 15)
        screen.text_right("atk:")
        screen.move(60, 15)
        screen.text(params:get(p.attack.name .. selected_step))

        screen.level(selected_screen_param == 3 and 15 or 2)
        screen.move(55, 25)
        screen.text_right("len:")
        screen.move(60, 25)
        screen.text(params:get(p.length.name .. selected_step))

        screen.level(selected_screen_param == 4 and 15 or 2)
        screen.move(55, 35)
        screen.text_right("lvl:")
        screen.move(60, 35)
        screen.text(params:get(p.level.name .. selected_step))

        screen.level(selected_screen_param == 5 and 15 or 2)
        screen.move(55, 45)
        screen.text_right("rate:")
        screen.move(60, 45)
        screen.text(params:get(p.playback_rate.name .. selected_step))

        screen.level(selected_screen_param == 6 and 15 or 2)
        screen.move(55, 55)
        screen.text_right("rFreq:")
        screen.move(60, 55)
        screen.text(params:get(p.rand_freq.name .. selected_step))

        screen.level(selected_screen_param == 7 and 15 or 2)
        screen.move(105, 15)
        screen.text_right("rLen:")
        screen.move(110, 15)
        screen.text(params:get(p.rand_length_amount.name .. selected_step))

        screen.level(selected_screen_param == 8 and 15 or 2)
        screen.move(105, 25)
        screen.text_right("rLenQ:")
        screen.move(110, 25)
        screen.text(params:get(p.rand_length_unquantized.name .. selected_step))

        screen.level(selected_screen_param == 9 and 15 or 2)
        screen.move(105, 35)
        screen.text_right("rPan:")
        screen.move(110, 35)
        screen.text(params:get(p.rand_pan_amount.name .. selected_step))

        screen.level(selected_screen_param == 10 and 15 or 2)
        screen.move(105, 45)
        screen.text_right("rel:")
        screen.move(110, 45)
        screen.text(params:get(p.release.name .. selected_step))

        screen.level(selected_screen_param == 11 and 15 or 2)
        screen.move(105, 55)
        screen.text_right("rot:")
        screen.move(110, 55)
        screen.text(params:get("rotation"))

        screen.level(selected_screen_param == 12 and 15 or 2)
        screen.move(105, 65)
        screen.text_right("cutoff:")
        screen.move(110, 65)
        screen.text(params:get(p.cutoff.name .. selected_step))

    elseif pages.index == 3 then

    end

    screen_dirty = false
    screen.update()
end

function g.key(x, y, z)
    local selected_step = params:get("selected_step")

    if z == 1 then -- if a grid key is pressed...
        selected_step = (y - 1) * 16 + x

        keys_counter[x][y] = clock.run(long_press, x, y) -- start the long press counter for that coordinate!
    elseif z == 0 then -- otherwise, if a grid key is released...
        if keys_counter[x][y] then -- and the long press is still waiting...
            clock.cancel(keys_counter[x][y]) -- then cancel the long press clock,
            short_press(x, y) -- and execute a short press instead.
        end
    end
    screen_dirty = true
end

function long_press(x, y) -- define a long press
    clock.sleep(0.5) -- a long press waits for a half-second...
    -- print("long press")
    keys_counter[x][y] = nil -- clear the counter
end

function short_press(x, y) -- define a short press
    local index = (y - 1) * 16 + x -- calculate the index in steps based on the x and y coordinates
    params:set("enabled" .. index, params:get("enabled" .. index) ~ 1)
    grid_dirty = true
end

function grid_redraw_clock()
    while true do
        clock.sleep(1 / 30)
        if grid_dirty then
            grid_redraw()
            grid_dirty = false
        end
    end
end

function grid_redraw()
    g:all(0)

    for i = 1, #steps do
        if steps[i].altered then
            g:led(leds[i].x, leds[i].y, 8)
        end

        if steps[i].enabled then
            g:led(leds[i].x, leds[i].y, 15)
        end
    end

    if playing_step > 0 then
        g:led(leds[playing_step].x, leds[playing_step].y, playing_step_led_brightness)
    end

    g:refresh()
end

function playing_step_led_clock()
    local direction = 1 -- 1 for increasing, -1 for decreasing
    while true do
        clock.sleep(1 / 15)
        playing_step_led_brightness = playing_step_led_brightness + direction
        if playing_step_led_brightness == 15 then
            direction = -1
        elseif playing_step_led_brightness == 0 then
            direction = 1
        end
        grid_dirty = true
    end
end
