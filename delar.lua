engine.name = 'DelarSequencer'
tabutil = require "tabutil"
g = grid.connect()
leds = {}
keys_counter = {}

is_playing = false
playing_step = 0
playing_step_led_brightness = 15
sequence = {}
sequence_position = 1
steps = {}
num_steps = 128
num_synth_params = 8
selected_step = 1
selected_screen_param = 1
num_screen_params = 9

function init()
    engine.setSample("/home/we/dust/audio/piano1.wav")
    is_playing = true
    engine.set_num_slices(num_steps)

    -- for i = 1, 128 do
    --     steps[i] = false
    -- end

    for i = 1, num_steps do
        steps[i] = {
            enabled = false,
            altered = false
        }
    end

    -- steps[1].enabled = true
    -- steps[10].enabled = true

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

    params:bang() -- will make all steps altered!
    -- for i = 1, #steps do
    --     steps[i].altered = false
    -- end

    screen_dirty = true
    screen_clock = clock.run(screen_redraw_clock)

    grid_dirty = true
    grid_clock = clock.run(grid_redraw_clock)

    playing_step_led_clock = clock.run(playing_step_led_clock)
end

function init_params()
    attack = controlspec.def {
        min = 0.01, -- the minimum value
        max = 1.0, -- the maximum value
        warp = 'lin', -- a shaping option for the raw value
        step = 0.01, -- output value quantization
        default = 0.01, -- default value
        quantum = 0.002, -- each delta will change raw value by this much
        wrap = false -- wrap around on overflow (true) or clamp (false)
    }
    length = controlspec.def {
        min = -100.0,
        max = 100.0,
        warp = 'lin',
        step = 0.01,
        default = 0.0,
        quantum = 0.002,
        wrap = false
    }
    level = controlspec.def {
        min = 0.0,
        max = 1.0,
        warp = 'lin',
        step = 0.01,
        default = 0.5,
        quantum = 0.002,
        wrap = false
    }
    playbackRate = controlspec.def {
        min = 0.25,
        max = 32.0,
        warp = 'lin',
        step = 0.01,
        default = 1.0,
        quantum = 0.002,
        wrap = false
    }
    randFreq = controlspec.def {
        min = 0.1,
        max = 2.0,
        warp = 'lin',
        step = 0.01,
        default = 1.0,
        quantum = 0.002,
        wrap = false
    }
    randLengthAmount = controlspec.def {
        min = 0.0,
        max = 100.0,
        warp = 'lin',
        step = 0.01,
        default = 0.0,
        quantum = 0.002,
        wrap = false
    }
    randPanAmount = controlspec.def {
        min = 0.0,
        max = 100.0,
        warp = 'lin',
        step = 0.01,
        default = 0.0,
        quantum = 0.002,
        wrap = false
    }
    release = controlspec.def {
        min = 0.01,
        max = 1.0,
        warp = 'lin',
        step = 0.01,
        default = 0.01,
        quantum = 0.002,
        wrap = false
    }

    for i = 1, num_steps do
        params:add_group("step " .. i, num_synth_params)
        params:hide("step " .. i)
        params:add_number("enabled" .. i, "enabled", 0, 1, 0)
        params:set_action("enabled" .. i, function(x)
            steps[i].enabled = (x == 1)
        end)
        params:add_number("altered" .. i, "altered", 0, 1, 0)
        params:set_action("altered" .. i, function(x)
            -- steps[i].altered = (x == 1)
        end)
        params:add_control("attack" .. i, "attack", attack)
        params:set_action("attack" .. i, function(x)
            params:set("altered" .. i, 1)
        end)
        params:add_control("length" .. i, "length", length)
        params:set_action("length" .. i, function(x)
            params:set("altered" .. i, 1)
        end)
        params:add_control("level" .. i, "level", level)
        params:set_action("level" .. i, function(x)
            params:set("altered" .. i, 1)
        end)
        params:add_control("randFreq" .. i, "rand freq", randFreq)
        params:set_action("randFreq" .. i, function(x)
            params:set("altered" .. i, 1)
        end)
        params:add_control("randLengthAmount" .. i, "rand length", randLengthAmount)
        params:set_action("randLengthAmount" .. i, function(x)
            params:set("altered" .. i, 1)
        end)
        params:add_control("randPanAmount" .. i, "rand pan", randPanAmount)
        params:set_action("randPanAmount" .. i, function(x)
            params:set("altered" .. i, 1)
        end)
        params:add_control("rate" .. i, "rate", playbackRate)
        params:set_action("rate" .. i, function(x)
            params:set("altered" .. i, 1)
        end)
        params:add_control("release" .. i, "release", release)
        params:set_action("release" .. i, function(x)
            params:set("altered" .. i, 1)
        end)
    end
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
    -- print(step)
    local attack = params:get("attack" .. step)
    local length = params:get("length" .. step)
    local level = params:get("level" .. step)
    local rate = params:get("rate" .. step)
    local randFreq = params:get("randFreq" .. step)
    local randLengthAmount = params:get("randLengthAmount" .. step)
    local randLengthUnquantized = false;
    local randPanAmount = params:get("randPanAmount" .. step)
    local release = params:get("release" .. step)
    engine.set_all(step, attack, length, level, rate, randFreq, randLengthAmount, randLengthUnquantized, randPanAmount,
        release)
end

function enc(n, d)
    if n == 2 then
        selected_screen_param = util.clamp(selected_screen_param + d, 1, num_screen_params)
    end
    if n == 3 then
        if selected_screen_param == 1 then
            selected_step = util.clamp(selected_step + d, 1, num_steps)
        elseif selected_screen_param == 2 then
            params:set("attack" .. selected_step, util.clamp(params:get("attack" .. selected_step) + d / 100, 0.01, 1))
        elseif selected_screen_param == 3 then
            params:set("length" .. selected_step, util.clamp(params:get("length" .. selected_step) + d / 10, -100, 100))
        elseif selected_screen_param == 4 then
            params:set("level" .. selected_step, util.clamp(params:get("level" .. selected_step) + d / 10, 0, 1))
        elseif selected_screen_param == 5 then
            params:set("rate" .. selected_step, util.clamp(params:get("rate" .. selected_step) + d / 100, 0.25, 32))
        elseif selected_screen_param == 6 then
            params:set("randFreq" .. selected_step, util.clamp(params:get("randFreq" .. selected_step) + d / 10, 0, 100))
        elseif selected_screen_param == 7 then
            params:set("randLengthAmount" .. selected_step,
                util.clamp(params:get("randLengthAmount" .. selected_step) + d / 10, 0, 100))
        elseif selected_screen_param == 8 then
            params:set("randPanAmount" .. selected_step,
                util.clamp(params:get("randPanAmount" .. selected_step) + d / 10, 0, 1))
        elseif selected_screen_param == 9 then
            params:set("release" .. selected_step, util.clamp(params:get("release" .. selected_step) + d / 100, 0.01, 1))

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
    screen.text(params:get("attack" .. selected_step))

    screen.level(selected_screen_param == 3 and 15 or 2)
    screen.move(55, 25)
    screen.text_right("len:")
    screen.move(60, 25)
    screen.text(params:get("length" .. selected_step))

    screen.level(selected_screen_param == 4 and 15 or 2)
    screen.move(55, 35)
    screen.text_right("lvl:")
    screen.move(60, 35)
    screen.text(params:get("level" .. selected_step))

    screen.level(selected_screen_param == 5 and 15 or 2)
    screen.move(55, 45)
    screen.text_right("rate:")
    screen.move(60, 45)
    screen.text(params:get("rate" .. selected_step))

    screen.level(selected_screen_param == 6 and 15 or 2)
    screen.move(55, 55)
    screen.text_right("rFreq:")
    screen.move(60, 55)
    screen.text(params:get("randFreq" .. selected_step))

    screen.level(selected_screen_param == 7 and 15 or 2)
    screen.move(105, 15)
    screen.text_right("rLen:")
    screen.move(110, 15)
    screen.text(params:get("randLengthAmount" .. selected_step))

    screen.level(selected_screen_param == 8 and 15 or 2)
    screen.move(105, 25)
    screen.text_right("rPan:")
    screen.move(110, 25)
    screen.text(params:get("randPanAmount" .. selected_step))

    screen.level(selected_screen_param == 9 and 15 or 2)
    screen.move(105, 35)
    screen.text_right("rel:")
    screen.move(110, 35)
    screen.text(params:get("release" .. selected_step))

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
    print("long press")
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
            g:led(leds[i].x, leds[i].y, 5)
        end

        if steps[i].enabled then
            g:led(leds[i].x, leds[i].y, 15)
        end
    end

    if playing_step > 0 then
        g:led(leds[playing_step].x, leds[playing_step].y, playing_step_led_brightness)
    end

    -- g:led(keys[3].x, keys[3].y, 15)
    -- g:led(16, 1, 15)

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
