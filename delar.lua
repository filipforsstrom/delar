engine.name = 'DelarSequencer'
tabutil = require "tabutil"
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
num_steps = 128
num_synth_params = 11
selected_step = 1
selected_screen_param = 1
num_screen_params = 10

p_names = {
    attack = "attack",
    length = "length",
    level = "level",
    playback_rate = "playback_rate",
    rand_freq = "rand_freq",
    rand_length_amount = "rand_length_amount",
    rand_length_unquantized = "rand_length_unquantized",
    rand_pan_amount = "rand_pan_amount",
    release = "release"
}

p = {
    attack = {
        name = "attack",
        default = 0.01
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

defaults = {
    attack = 0.01,
    length = 0,
    level = 0.5,
    playback_rate = 1.0,
    rand_freq = 1,
    rand_length_amount = 0,
    rand_length_unquantized = 0,
    rand_pan_amount = 0,
    release = 0.01
}

function init()
    for i = 1, num_steps do
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
    params:set("enabled89", 1)
    engine.setSample(sample_path .. "piano1.wav")
    is_playing = true
    engine.set_num_slices(num_steps)

    screen_dirty = true
    screen_clock = clock.run(screen_redraw_clock)

    grid_dirty = true
    grid_clock = clock.run(grid_redraw_clock)

    playing_step_led_clock = clock.run(playing_step_led_clock)
end

function init_params()
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

    params:add_control(p.attack.name, "attack", attack)
    params:add_control(p.length.name, "length", length)
    params:add_control(p.level.name, "level", level)
    params:add_control(p.rand_freq.name, "rand freq", rand_freq)
    params:add_control(p.rand_length_amount.name, "rand length", rand_length_amount)
    params:add_number(p.rand_length_unquantized.name, "unquantize rand length", 0, 1, p.rand_length_unquantized.default)
    params:add_control(p.rand_pan_amount.name, "rand pan", rand_pan_amount)
    params:add_control(p.playback_rate.name, "rate", playbackRate)
    params:add_control(p.release.name, "release", release)

    for i = 1, num_steps do
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

function params_not_default(step)
    local params_to_check = {p.attack, p.length, p.level, p.rand_freq, p.rand_length_amount, p.rand_length_unquantized,
                             p.rand_pan_amount, p.playback_rate, p.release}
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
    local params_to_check = {p.attack.name, p.length.name, p.level.name, p.playback_rate.name, p.rand_freq.name,
                             p.rand_length_amount.name, p.rand_length_unquantized.name, p.rand_pan_amount.name,
                             p.release.name}
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
    if n == 2 then
        selected_screen_param = util.clamp(selected_screen_param + d, 1, num_screen_params)
    end
    if n == 3 then
        if selected_screen_param == 1 then
            selected_step = util.clamp(selected_step + d, 1, num_steps)
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
    screen.font_face(1)
    screen.clear()

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

    screen_dirty = false
    screen.update()
end

function g.key(x, y, z)
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
