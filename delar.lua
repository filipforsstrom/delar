-- delar
-- v1.0.1 @ljudvagg
-- llllllll.co/t/delar/63767
--
-- always looping
-- sample player
--
-- load a sample in params menu
-- 
-- encoders:
-- E1: select page
-- E2: rotate slices
-- E3: select slice
-- K1+E3: change pattern
--
-- keys:
-- K2: play/stop
-- K1+K2: auto rotate
-- K3(slice page): toggle slice
-- K3(other pages): default values
engine.name = 'DelarSequencer'
tabutil = require "tabutil"
ui = require "ui"
local pages
g = grid.connect()
leds = {}
keys_counter = {}
alt_key = false

sample_path = paths.home .. "/dust/audio/"
is_playing = false
playing_slice = 0
playing_slice_led_brightness = 15
playing_slice_screen_brightness = 15
sequence = {}
sequence_position = 1
slices = {}
max_num_patterns = 8
max_num_slices = 128
num_synth_params = 12
selected_screen_param = 1
num_screen_params = 11
rotations = {}
duration = 0
patterns = {}

p_filter = {
    cutoff = {name = "filter_cutoff", default = 20000},
    resonance = {name = "filter_resonance", default = 1},
    lfo_speed = {name = "filter_lfo_speed", default = 1.0},
    attack = {name = "filter_attack", default = 0.01},
    release = {name = "filter_release", default = 0.01},
    mod_env = {name = "filter_mod_env", default = 0},
    mod_lfo = {name = "filter_mod_lfo", default = 0},
    level = {name = "filter_level", default = 1.0}
}

p_sampler = {
    attack = {name = "attack", default = 0.01},
    length = {name = "length", default = 0},
    level = {name = "level", default = 0.5},
    loop = {name = "loop", default = 0},
    playback_rate = {name = "playback_rate", default = 0},
    rand_freq = {name = "rand_freq", default = 1},
    rand_start_amount = {name = "rand_start_amount", default = 0},
    rand_end_probability = {name = "rand_end_probability", default = 0},
    rand_pan_amount = {name = "rand_pan_amount", default = 0},
    release = {name = "release", default = 0.01}
}

function init()
    -- Init UI
    pages = ui.Pages.new(1, 3)
    -- pages:set_index_delta(1)

    for p = 1, max_num_patterns do
        patterns[p] = {}
        patterns[p].slices = {} -- initialize the slices field
        for s = 1, max_num_slices do
            patterns[p].slices[s] = {enabled = false, altered = false}
            for _, param in pairs(p_sampler) do
                patterns[p].slices[s][param.name] = param.default
            end
        end
    end

    for i = 1, max_num_slices do
        slices[i] = {enabled = false, altered = false}
    end

    for i = 1, 8 do for j = 1, 16 do table.insert(leds, {x = j, y = i}) end end

    for x = 1, 16 do -- for each x-column (16 on a 128-sized grid)...
        keys_counter[x] = {} -- create a x state counter.
    end

    init_filter_params()
    init_params()

    params:bang()
    params:set("p1s1enabled", 1)
    params:set("p2s1enabled", 1)
    params:set("p3s1enabled", 1)
    params:set("p4s1enabled", 1)
    params:set("p5s1enabled", 1)
    params:set("p6s1enabled", 1)
    params:set("p7s1enabled", 1)
    params:set("p8s1enabled", 1)
    -- engine.setSample(sample_path .. "delar/piano1.wav")
    -- is_playing = true
    -- engine.set_num_slices(max_num_slices)

    screen_dirty = true
    grid_dirty = true

    -- clocks
    screen_clock = clock.run(screen_redraw_clock)
    grid_clock = clock.run(grid_redraw_clock)
    playing_slice_led_clock = clock.run(playing_slice_led_clock)
    playing_slice_screen_clock = clock.run(playing_slice_screen_clock)
    rotation_clock = clock.run(rotation_clock)

    -- timers
    rotation_timer = metro.init(check_rotations, 0.04, -1)
    rotation_timer:start()
end

function init_filter_params()
    cutoff = controlspec.def {
        min = 30,
        max = 20000,
        warp = 'exp',
        step = 0.1,
        default = p_filter.cutoff.default,
        quantum = 0.001
    }
    resonance = controlspec.def {
        min = 0,
        max = 1,
        step = 0.01,
        default = p_filter.resonance.default,
        quantum = 0.001
    }
    lfo_speed = controlspec.def {
        min = 0.1,
        max = 20,
        step = 0.01,
        default = p_filter.lfo_speed.default,
        quantum = 0.001
    }
    attack = controlspec.def {
        min = 0.01,
        max = 1.0,
        step = 0.01,
        default = p_filter.attack.default,
        quantum = 0.001
    }
    release = controlspec.def {
        min = 0.01,
        max = 1.0,
        step = 0.01,
        default = p_filter.release.default,
        quantum = 0.001
    }
    mod_env = controlspec.def {
        min = -1.0,
        max = 1.0,
        step = 0.01,
        default = p_filter.mod_env.default,
        quantum = 0.001
    }
    mod_lfo = controlspec.def {
        min = -1.0,
        max = 1.0,
        step = 0.01,
        default = p_filter.mod_lfo.default,
        quantum = 0.001
    }
    level = controlspec.def {
        min = 0.0,
        max = 1.0,
        step = 0.01,
        default = p_filter.level.default,
        quantum = 0.001
    }

    local length = 0
    for _, _ in pairs(p_filter) do length = length + 1 end

    params:add_group("filter", length)
    params:add_control(p_filter.cutoff.name, "cutoff", cutoff)
    params:set_action(p_filter.cutoff.name,
                      function(x) engine.set_filter("cutoff", x) end)
    params:add_control(p_filter.resonance.name, "resonance", resonance)
    params:set_action(p_filter.resonance.name,
                      function(x) engine.set_filter("resonance", x) end)
    params:add_control(p_filter.lfo_speed.name, "lfo speed", lfo_speed)
    params:set_action(p_filter.lfo_speed.name,
                      function(x) engine.set_filter("lfoSpeed", x) end)
    params:add_control(p_filter.attack.name, "attack", attack)
    params:set_action(p_filter.attack.name,
                      function(x) engine.set_filter("attack", x) end)
    params:add_control(p_filter.release.name, "release", release)
    params:set_action(p_filter.release.name,
                      function(x) engine.set_filter("release", x) end)
    params:add_control(p_filter.mod_env.name, "mod env", mod_env)
    params:set_action(p_filter.mod_env.name,
                      function(x) engine.set_filter("modEnv", x) end)
    params:add_control(p_filter.mod_lfo.name, "mod lfo", mod_lfo)
    params:set_action(p_filter.mod_lfo.name,
                      function(x) engine.set_filter("modLfo", x) end)
    params:add_control(p_filter.level.name, "level", level)
    params:set_action(p_filter.level.name,
                      function(x) engine.set_filter("level", x) end)
end

function init_params()
    params:add_number("rotation", "rotation", -1, 1, 0)
    params:set_action("rotation", function(x)
        if x > 0 or x < 0 then
            if #rotations < 1 then table.insert(rotations, x) end
        end
        params:set("rotation", 0)
    end)
    params:hide("rotation")
    params:add_number("rotate", "rotate", 0, 1, 0)
    params:hide("rotate")

    params:add_file("sample", "sample", sample_path)
    params:set_action("sample", function(x)
        engine.setSample(x)
        is_playing = true
    end)
    params:add_number("num_slices", "num slices", 1, max_num_slices, 128)
    params:set_action("num_slices", function(x) engine.set_num_slices(x) end)
    params:hide("num_slices")
    params:add_number("selected_pattern", "pattern", 1, max_num_patterns, 1)
    params:set_action("selected_pattern", function(x)
        sequence = get_active_slices(patterns[x].slices)
    end)
    params:hide("selected_pattern")
    params:add_number("selected_slice", "slice", 1, params:get("num_slices"), 1,
                      nil, true)
    -- params:set_action("selected_slice", function(x)
    --     if x > params:get("num_slices") then
    --         params:set("selected_slice", params:get("num_slices"))
    --     end
    --     grid_dirty = true
    --     screen_dirty = true
    -- end)
    params:hide("selected_slice")

    attack = controlspec.def {
        min = 0.01, -- the minimum value
        max = 1.0, -- the maximum value
        step = 0.01, -- output value quantization
        default = p_sampler.attack.default, -- default value
        quantum = 0.002 -- each delta will change raw value by this much
    }
    length = controlspec.def {
        min = -1.0,
        max = 1.0,
        step = 0.01,
        default = p_sampler.length.default,
        quantum = 0.002
    }
    level = controlspec.def {
        min = 0.0,
        max = 1.0,
        step = 0.01,
        default = p_sampler.level.default,
        quantum = 0.002
    }
    loop = controlspec.def {
        min = 0.0,
        max = 1.0,
        step = 0.01,
        default = p_sampler.loop.default,
        quantum = 0.002
    }
    -- playbackRate = controlspec.def {
    --     min = 0.25,
    --     max = 32.0,
    --     step = 0.0001,
    --     default = p.playback_rate.default,
    --     quantum = 0.0001,
    -- }
    rand_freq = controlspec.def {
        min = 0.1,
        max = 2.0,
        step = 0.01,
        default = p_sampler.rand_freq.default,
        quantum = 0.002
    }
    rand_length_amount = controlspec.def {
        min = 0.0,
        max = 1.0,
        step = 0.001,
        default = p_sampler.rand_start_amount.default,
        quantum = 0.002
    }
    rand_length_unquantized = controlspec.def {
        min = 0.0,
        max = 1.0,
        step = 0.01,
        default = p_sampler.rand_end_probability.default,
        quantum = 0.002
    }
    rand_pan_amount = controlspec.def {
        min = 0.0,
        max = 1.0,
        step = 0.01,
        default = p_sampler.rand_pan_amount.default,
        quantum = 0.002
    }
    release = controlspec.def {
        min = 0.01,
        max = 1.0,
        step = 0.01,
        default = p_sampler.release.default,
        quantum = 0.002
    }
    percentage = controlspec.def {
        min = -100,
        max = 100,
        step = 0.1,
        default = 0,
        quantum = 0.0005
    }

    -- offsets
    -- params:add_group("offsets", num_synth_params)
    params:add_control(p_sampler.attack.name, "attack", percentage)
    params:add_control(p_sampler.length.name, "length", percentage)
    params:add_control(p_sampler.level.name, "level", percentage)
    params:add_control(p_sampler.loop.name, "loop", percentage)
    params:add_control(p_sampler.rand_freq.name, "rand freq", percentage)
    params:add_control(p_sampler.rand_start_amount.name, "rand length",
                       percentage)
    params:add_control(p_sampler.rand_end_probability.name,
                       "unquantize rand length", percentage)
    params:add_control(p_sampler.rand_pan_amount.name, "rand pan", percentage)
    params:add_control(p_sampler.playback_rate.name, "playback rate", percentage)
    params:add_control(p_sampler.release.name, "release", percentage)
    -- params:hide(p_sampler.attack.name)
    -- params:hide(p_sampler.length.name)
    -- params:hide(p_sampler.level.name)
    -- params:hide(p_sampler.loop.name)
    -- params:hide(p_sampler.rand_freq.name)
    -- params:hide(p_sampler.rand_start_amount.name)
    -- params:hide(p_sampler.rand_end_probability.name)
    -- params:hide(p_sampler.rand_pan_amount.name)
    -- params:hide(p_sampler.playback_rate.name)
    -- params:hide(p_sampler.release.name)

    for i = 1, max_num_patterns do
        for j = 1, max_num_slices do
            params:add_group("pattern " .. i .. " slice " .. j, num_synth_params)
            params:hide("pattern " .. i .. " slice " .. j)
            params:add_number("p" .. i .. "s" .. j .. "enabled", "enabled", 0,
                              1, 0)
            params:set_action("p" .. i .. "s" .. j .. "enabled", function(x)
                slices[j].enabled = (x == 1)
                patterns[i].slices[j].enabled = (x == 1)
                sequence = get_active_slices(
                               patterns[params:get("selected_pattern")].slices)
            end)
            params:add_number("p" .. i .. "s" .. j .. "altered", "altered", 0,
                              1, 0)
            params:set_action("p" .. i .. "s" .. j .. "altered", function(x)
                -- print("altered" .. i .. " changed to " .. x)
                if params_not_default(j) then
                    slices[j].altered = true
                    patterns[i].slices[j].altered = true
                else
                    params:set("p" .. i .. "s" .. j .. "altered", 0)
                    slices[j].altered = false
                    patterns[i].slices[j].altered = false
                end
            end)
            params:add_control("p" .. i .. "s" .. j .. p_sampler.attack.name,
                               "attack", attack)
            params:set_action("p" .. i .. "s" .. j .. p_sampler.attack.name,
                              function(x)
                patterns[i].slices[j].attack = x
                params:set("p" .. i .. "s" .. j .. "altered",
                           params:get("p" .. i .. "s" .. j .. "altered") ~ 1)
            end)
            params:add_control("p" .. i .. "s" .. j .. p_sampler.length.name,
                               "length", length)
            params:set_action("p" .. i .. "s" .. j .. p_sampler.length.name,
                              function(x)
                patterns[i].slices[j].length = x
                params:set("p" .. i .. "s" .. j .. "altered",
                           params:get("p" .. i .. "s" .. j .. "altered") ~ 1)
            end)
            params:add_control("p" .. i .. "s" .. j .. p_sampler.level.name,
                               "level", level)
            params:set_action("p" .. i .. "s" .. j .. p_sampler.level.name,
                              function(x)
                patterns[i].slices[j].level = x
                params:set("p" .. i .. "s" .. j .. "altered",
                           params:get("p" .. i .. "s" .. j .. "altered") ~ 1)
            end)
            params:add_control("p" .. i .. "s" .. j .. p_sampler.loop.name,
                               "loop", loop)
            params:set_action("p" .. i .. "s" .. j .. p_sampler.loop.name,
                              function(x)
                patterns[i].slices[j].loop = x
                params:set("p" .. i .. "s" .. j .. "altered",
                           params:get("p" .. i .. "s" .. j .. "altered") ~ 1)
            end)
            params:add_control("p" .. i .. "s" .. j .. p_sampler.rand_freq.name,
                               "rand freq", rand_freq)
            params:set_action("p" .. i .. "s" .. j .. p_sampler.rand_freq.name,
                              function(x)
                patterns[i].slices[j].rand_freq = x
                params:set("p" .. i .. "s" .. j .. "altered",
                           params:get("p" .. i .. "s" .. j .. "altered") ~ 1)
            end)
            params:add_control("p" .. i .. "s" .. j ..
                                   p_sampler.rand_start_amount.name,
                               "rand length", rand_length_amount)
            params:set_action("p" .. i .. "s" .. j ..
                                  p_sampler.rand_start_amount.name, function(x)
                patterns[i].slices[j].rand_length_amount = x
                params:set("p" .. i .. "s" .. j .. "altered",
                           params:get("p" .. i .. "s" .. j .. "altered") ~ 1)
            end)
            params:add_control("p" .. i .. "s" .. j ..
                                   p_sampler.rand_end_probability.name,
                               "unquantize rand length", rand_length_unquantized)
            params:set_action("p" .. i .. "s" .. j ..
                                  p_sampler.rand_end_probability.name,
                              function(x)
                patterns[i].slices[j].rand_length_unquantized = x
                params:set("p" .. i .. "s" .. j .. "altered",
                           params:get("p" .. i .. "s" .. j .. "altered") ~ 1)
            end)
            params:add_control("p" .. i .. "s" .. j ..
                                   p_sampler.rand_pan_amount.name, "rand pan",
                               rand_pan_amount)
            params:set_action("p" .. i .. "s" .. j ..
                                  p_sampler.rand_pan_amount.name, function(x)
                patterns[i].slices[j].rand_pan_amount = x
                params:set("p" .. i .. "s" .. j .. "altered",
                           params:get("p" .. i .. "s" .. j .. "altered") ~ 1)
            end)
            params:add_number("p" .. i .. "s" .. j ..
                                  p_sampler.playback_rate.name, "playback rate",
                              -3, 4, 0)
            params:set_action("p" .. i .. "s" .. j ..
                                  p_sampler.playback_rate.name, function(x)
                patterns[i].slices[j].playback_rate = x
                params:set("p" .. i .. "s" .. j .. "altered",
                           params:get("p" .. i .. "s" .. j .. "altered") ~ 1)
            end)
            params:add_control("p" .. i .. "s" .. j .. p_sampler.release.name,
                               "release", release)
            params:set_action("p" .. i .. "s" .. j .. p_sampler.release.name,
                              function(x)
                patterns[i].slices[j].release = x
                params:set("p" .. i .. "s" .. j .. "altered",
                           params:get("p" .. i .. "s" .. j .. "altered") ~ 1)
            end)
        end
    end
end

function check_rotations()
    if #rotations > 0 then
        rotate(rotations[1])
        table.remove(rotations, 1)
    end
end

function rotate(x)
    local pattern = params:get("selected_pattern")
    local params_to_rotate = {
        "enabled", "altered", p_sampler.attack.name, p_sampler.length.name,
        p_sampler.level.name, p_sampler.loop.name, p_sampler.playback_rate.name,
        p_sampler.rand_freq.name, p_sampler.rand_start_amount.name,
        p_sampler.rand_end_probability.name, p_sampler.rand_pan_amount.name,
        p_sampler.release.name
    }
    local num_slices = params:get("num_slices")

    -- store all params in a table
    local all_params = {}
    for i = 1, num_slices do
        all_params[i] = {}
        for _, param in ipairs(params_to_rotate) do
            all_params[i][param] = params:get(
                                       "p" .. pattern .. "s" .. i .. param)
        end
    end

    -- rotate the table
    local rotate_slices = x % num_slices -- calculate the number of slices to rotate
    if rotate_slices ~= 0 then -- only rotate if there are slices to rotate
        if rotate_slices < 0 then -- rotate left
            rotate_slices = rotate_slices + num_slices
        end
        for i = 1, rotate_slices do
            table.insert(all_params, 1, table.remove(all_params, num_slices))
        end
    end

    -- set all params to the new values
    for i = 1, num_slices do
        for _, param in ipairs(params_to_rotate) do
            params:set("p" .. pattern .. "s" .. i .. param, all_params[i][param])
        end
    end

    -- move selected slice in the direction of the rotation
    params:set("selected_slice", params:get("selected_slice") + x)

end

function params_not_default(slice)
    local pattern = params:get("selected_pattern")
    local pattern_slice = "p" .. pattern .. "s" .. slice
    local params_to_check = {
        p_sampler.attack, p_sampler.length, p_sampler.level, p_sampler.loop,
        p_sampler.rand_freq, p_sampler.rand_start_amount,
        p_sampler.rand_end_probability, p_sampler.rand_pan_amount,
        p_sampler.playback_rate, p_sampler.release
    }
    for _, param in ipairs(params_to_check) do
        if params:get(pattern_slice .. param.name) ~= param.default then
            return true
        end
    end
    return false
end

function key(n, z)
    if n == 1 then alt_key = z == 1 end

    if n == 2 and z == 1 and alt_key then
        params:set("rotate", params:get("rotate") == 0 and 1 or 0)
    end

    if n == 2 and z == 1 and not alt_key then
        if is_playing then
            stop_engine()
        else
            play_engine()
        end
    end

    if pages.index == 1 then
        if n == 3 and z == 1 then -- toggle slice enabled/disabled
            local selected_slice = params:get("selected_slice")
            local pattern = params:get("selected_pattern")
            local pattern_slice = "p" .. pattern .. "s" .. selected_slice
            if params:get(pattern_slice .. "enabled") == 1 then
                params:set(pattern_slice .. "enabled", 0)
            else
                params:set(pattern_slice .. "enabled", 1)
            end
        end
    end

    if pages.index == 2 then
        if n == 3 and z == 1 then
            set_all_params_default(params:get("selected_slice"))
        end
    else
        if pages.index == 3 then
            if n == 3 and z == 1 then set_all_offset_default() end
        end
    end
end

function set_all_params_default(slice)
    local pattern_slice = "p" .. params:get("selected_pattern") .. "s" .. slice
    local params_to_set = {
        p_sampler.attack, p_sampler.length, p_sampler.level, p_sampler.loop,
        p_sampler.rand_freq, p_sampler.rand_start_amount,
        p_sampler.rand_end_probability, p_sampler.rand_pan_amount,
        p_sampler.playback_rate, p_sampler.release
    }
    for _, param in ipairs(params_to_set) do
        params:set(pattern_slice .. param.name, param.default)
    end
end

function set_all_offset_default()
    local params_to_set = {
        p_sampler.attack, p_sampler.length, p_sampler.level, p_sampler.loop,
        p_sampler.rand_freq, p_sampler.rand_start_amount,
        p_sampler.rand_end_probability, p_sampler.rand_pan_amount,
        p_sampler.playback_rate, p_sampler.release
    }
    for _, param in ipairs(params_to_set) do params:set(param.name, 0) end
end

function osc_in(path, args, from)
    if path == "/step" then
        playing_slice = args[1] + 1 -- lua is 1-indexed
        -- print("playing slice: " .. playing_slice)
        tick()
    elseif path == "/duration" then
        -- print("received duration: " .. args[1])
        duration = args[1]
    elseif path == "/x" then
        -- slice = args[1]
    else
        print(path)
        tab.print(args)
    end
    -- print("osc from " .. from[1] .. " port " .. from[2])
end

osc.event = osc_in

function tick()
    sequence_position = (sequence_position + 1)
    if sequence_position > #sequence then sequence_position = 1 end

    if #sequence > 0 then
        send_next_slice(sequence[sequence_position])
    else
        stop_engine()
    end
    screen_dirty = true
    grid_dirty = true
end

function play_engine()
    sequence_position = 1
    send_next_slice(sequence[sequence_position])
    engine.play()
    is_playing = true
end

function stop_engine()
    engine.stop()
    params:set("rotate", 0)
    is_playing = false
    playing_slice = 0
end

function get_active_slices(slices)
    local active_slices = {}
    for i = 1, #slices do
        if slices[i].enabled then table.insert(active_slices, i) end
    end
    return active_slices
end

function send_next_slice(slice)
    local pattern = params:get("selected_pattern")
    local pattern_slice = "p" .. pattern .. "s" .. slice
    local params_to_check = {
        p_sampler.attack.name, p_sampler.loop.name, p_sampler.length.name,
        p_sampler.level.name, p_sampler.playback_rate.name,
        p_sampler.rand_freq.name, p_sampler.rand_start_amount.name,
        p_sampler.rand_end_probability.name, p_sampler.rand_pan_amount.name,
        p_sampler.release.name
    }
    local engine_params = {}
    for i, param in ipairs(params_to_check) do
        local slice_value = params:get(pattern_slice .. param)
        local range = params:get_range(pattern_slice .. param)
        local offset = params:get(param)
        local offset_slice_value = slice_value + (offset / 100) *
                                       (range[2] - range[1])

        if param == p_sampler.rand_end_probability.name or param ==
            p_sampler.loop.name then
            -- If the parameter is rand_length_unquantized or loop,
            -- randomly set the offset_slice_value to either 0 or 1
            -- unless it's already 0 or 1
            offset_slice_value =
                (offset_slice_value == 0 or offset_slice_value == 1) and
                    offset_slice_value or
                    (math.random() < offset_slice_value and 1 or 0)
        end

        local clamped_slice_value = util.clamp(offset_slice_value, range[1],
                                               range[2])

        -- print(param .. " slice: " .. slice_value)
        -- print(param .. " range: " .. range[1] .. " - " .. range[2])
        -- print(param .. " offset: " .. offset)
        -- print(param .. " offset slice: " .. offset_slice_value)
        -- print(param .. " clamped slice: " .. clamped_slice_value)

        engine_params[i] = clamped_slice_value
    end
    -- tab.print(engine_params)
    engine.set_all(slice, table.unpack(engine_params))
end

function enc(n, d)
    local selected_slice = params:get("selected_slice")
    local pattern = params:get("selected_pattern")
    local pattern_slice = "p" .. pattern .. "s" .. selected_slice

    if n == 1 then -- Page scroll
        pages:set_index_delta(util.clamp(d, -1, 1), false)
    end

    if pages.index == 1 then
        if n == 2 then
            params:set("rotation", util.clamp(params:get("rotation") + d, -1, 1))
        end
        if n == 3 then
            if alt_key then
                params:set("selected_pattern", util.clamp(
                               params:get("selected_pattern") + d, 1,
                               max_num_patterns))
            else
                params:set("selected_slice", selected_slice + d)
            end
        end
    end

    if pages.index == 2 then
        if n == 2 then
            selected_screen_param = util.clamp(selected_screen_param + d, 1,
                                               num_screen_params)
        end

        if n == 3 then
            if selected_screen_param == 1 then
                params:set("selected_slice", selected_slice + d)
            elseif selected_screen_param == 2 then
                params:set(pattern_slice .. p_sampler.attack.name,
                           util.clamp(
                               params:get(pattern_slice .. p_sampler.attack.name) +
                                   d / 100, 0.01, 1))
            elseif selected_screen_param == 3 then
                params:set(pattern_slice .. p_sampler.length.name, util.clamp(
                               params:get(pattern_slice .. p_sampler.length.name) +
                                   d / 100, -1, 1))
            elseif selected_screen_param == 4 then
                params:set(pattern_slice .. p_sampler.level.name, util.clamp(
                               params:get(pattern_slice .. p_sampler.level.name) +
                                   d / 100, 0, 1))
            elseif selected_screen_param == 5 then
                params:set(pattern_slice .. p_sampler.playback_rate.name,
                           util.clamp(
                               params:get(
                                   pattern_slice .. p_sampler.playback_rate.name) +
                                   d, -2, 3))
            elseif selected_screen_param == 6 then
                params:set(pattern_slice .. p_sampler.rand_freq.name,
                           util.clamp(
                               params:get(
                                   pattern_slice .. p_sampler.rand_freq.name) +
                                   d / 10, 0, 100))
            elseif selected_screen_param == 7 then
                params:set(pattern_slice .. p_sampler.rand_start_amount.name,
                           util.clamp(
                               params:get(
                                   pattern_slice ..
                                       p_sampler.rand_start_amount.name) + d /
                                   1000, 0, 1))
            elseif selected_screen_param == 8 then
                params:set(pattern_slice .. p_sampler.rand_end_probability.name,
                           util.clamp(
                               params:get(
                                   pattern_slice ..
                                       p_sampler.rand_end_probability.name) + d /
                                   100, 0, 1))
            elseif selected_screen_param == 9 then
                params:set(pattern_slice .. p_sampler.rand_pan_amount.name,
                           util.clamp(
                               params:get(
                                   pattern_slice ..
                                       p_sampler.rand_pan_amount.name) + d / 100,
                               0, 1))
            elseif selected_screen_param == 10 then
                params:set(pattern_slice .. p_sampler.release.name,
                           util.clamp(
                               params:get(
                                   pattern_slice .. p_sampler.release.name) + d /
                                   100, 0.01, 1))
            elseif selected_screen_param == 11 then
                params:set(pattern_slice .. p_sampler.loop.name, util.clamp(
                               params:get(pattern_slice .. p_sampler.loop.name) +
                                   d / 100, 0, 1))
            end
        end
    end

    if pages.index == 3 then
        if n == 2 then
            selected_screen_param = util.clamp(selected_screen_param + d, 1,
                                               num_screen_params)
        end

        if n == 3 then
            if selected_screen_param == 2 then
                params:set(p_sampler.attack.name, util.clamp(
                               params:get(p_sampler.attack.name) + d / 10, -100,
                               100))
            elseif selected_screen_param == 3 then
                params:set(p_sampler.length.name, util.clamp(
                               params:get(p_sampler.length.name) + d / 10, -100,
                               100))
            elseif selected_screen_param == 4 then
                params:set(p_sampler.level.name, util.clamp(
                               params:get(p_sampler.level.name) + d / 10, -100,
                               100))
            elseif selected_screen_param == 5 then
                params:set(p_sampler.playback_rate.name, util.clamp(
                               params:get(p_sampler.playback_rate.name) + d / 10,
                               -100, 100))
            elseif selected_screen_param == 6 then
                params:set(p_sampler.rand_freq.name, util.clamp(
                               params:get(p_sampler.rand_freq.name) + d / 10,
                               -100, 100))
            elseif selected_screen_param == 7 then
                params:set(p_sampler.rand_start_amount.name, util.clamp(
                               params:get(p_sampler.rand_start_amount.name) + d /
                                   10, -100, 100))
            elseif selected_screen_param == 8 then
                params:set(p_sampler.rand_end_probability.name, util.clamp(
                               params:get(p_sampler.rand_end_probability.name) +
                                   d / 10, -100, 100))
            elseif selected_screen_param == 9 then
                params:set(p_sampler.rand_pan_amount.name, util.clamp(
                               params:get(p_sampler.rand_pan_amount.name) + d /
                                   10, -100, 100))
            elseif selected_screen_param == 10 then
                params:set(p_sampler.release.name, util.clamp(
                               params:get(p_sampler.release.name) + d / 10,
                               -100, 100))
            elseif selected_screen_param == 11 then
                params:set(p_sampler.loop.name, util.clamp(
                               params:get(p_sampler.loop.name) + d / 10, -100,
                               100))
            end
        end
    end

    screen_dirty = true
end

function screen_redraw_clock()
    while true do
        clock.sleep(1 / 15)
        if screen_dirty then redraw() end
    end
end

function redraw()
    screen.clear()
    screen.font_face(1)
    screen.font_size(8)

    local screenWidth = 128
    local screenHeight = 64
    local pattern = params:get("selected_pattern")
    local selected_slice = params:get("selected_slice")

    pages:redraw()

    if pages.index == 1 then

        local playing_slice = playing_slice

        -- pattern
        screen.level(2)
        screen.move(screenWidth / 2, 5)
        screen.text_center("pattern " .. pattern)

        -- Determine the size of each square on the x-axis
        local sliceSizeX = 6
        local sliceSizeY = 6

        -- Calculate the number of rows and columns to form the grid
        local numColumns = 16
        local numRows = 8

        -- Calculate the starting position of the grid to center it on the screen
        local startX = (screenWidth - (numColumns * sliceSizeX)) / 2 -
                           sliceSizeX
        local startY = (screenHeight - (numRows * sliceSizeY)) / 2 - sliceSizeY

        -- Full grid
        for row = 1, numRows do
            for col = 1, numColumns do
                local sliceX = startX + col * sliceSizeX
                local sliceY = startY + row * sliceSizeY

                screen.rect(sliceX, sliceY, sliceSizeX, sliceSizeY)
                screen.level(1)
                screen.stroke()
            end
        end

        -- Enabled slices
        for row = 1, numRows do
            for col = 1, numColumns do
                local sliceX = startX + col * sliceSizeX
                local sliceY = startY + row * sliceSizeY

                if patterns[pattern].slices[(row - 1) * numColumns + col]
                    .enabled then
                    screen.rect(sliceX, sliceY, sliceSizeX, sliceSizeY)
                    screen.level(5)
                    screen.stroke()
                end
            end
        end

        -- Altered slices
        for row = 1, numRows do
            for col = 1, numColumns do
                local sliceX = startX + col * sliceSizeX
                local sliceY = startY + row * sliceSizeY

                if patterns[pattern].slices[(row - 1) * numColumns + col]
                    .altered then
                    screen.rect(sliceX + 1, sliceY + 1, sliceSizeX - 2,
                                sliceSizeY - 2)
                    screen.level(15)
                    screen.stroke()
                end
            end
        end

        -- Playing slice
        for row = 1, numRows do
            for col = 1, numColumns do
                local sliceX = startX + col * sliceSizeX
                local sliceY = startY + row * sliceSizeY

                if (row - 1) * numColumns + col == playing_slice then
                    screen.rect(sliceX + 2, sliceY + 2, 2, 2)
                    screen.level(playing_slice_screen_brightness)
                    screen.stroke()
                end
            end
        end

        -- Selected slices
        for row = 1, numRows do
            for col = 1, numColumns do
                local sliceX = startX + col * sliceSizeX
                local sliceY = startY + row * sliceSizeY

                if (row - 1) * numColumns + col == selected_slice then
                    screen.rect(sliceX, sliceY, sliceSizeX, sliceSizeY)
                    screen.level(15)
                    screen.stroke()
                end
            end
        end

    elseif pages.index == 2 then
        -- position
        screen.level(2)
        screen.move(90, 5)
        screen.text_right("pos ")
        screen.move(95, 5)
        if playing_slice > 0 then
            screen.text(playing_slice)
        else
            screen.text("-")
        end

        -- params
        local pattern_slice = "p" .. pattern .. "s" .. selected_slice

        screen.level(selected_screen_param == 1 and 15 or 2)
        screen.move(40, 5)
        screen.text_right("slice:")
        screen.move(45, 5)
        screen.text(selected_slice)

        screen.level(selected_screen_param == 2 and 15 or 2)
        screen.move(40, 15)
        screen.text_right("atk:")
        screen.move(45, 15)
        screen.text(params:get(pattern_slice .. p_sampler.attack.name))

        screen.level(selected_screen_param == 3 and 15 or 2)
        screen.move(40, 25)
        screen.text_right("len:")
        screen.move(45, 25)
        screen.text(params:get(pattern_slice .. p_sampler.length.name))

        screen.level(selected_screen_param == 4 and 15 or 2)
        screen.move(40, 35)
        screen.text_right("lvl:")
        screen.move(45, 35)
        screen.text(params:get(pattern_slice .. p_sampler.level.name))

        screen.level(selected_screen_param == 5 and 15 or 2)
        screen.move(40, 45)
        screen.text_right("rate:")
        screen.move(45, 45)
        screen.text(params:get(pattern_slice .. p_sampler.playback_rate.name))

        screen.level(selected_screen_param == 6 and 15 or 2)
        screen.move(40, 55)
        screen.text_right("rFreq:")
        screen.move(45, 55)
        screen.text(params:get(pattern_slice .. p_sampler.rand_freq.name))

        screen.level(selected_screen_param == 7 and 15 or 2)
        screen.move(90, 15)
        screen.text_right("rStart:")
        screen.move(95, 15)
        screen.text(
            params:get(pattern_slice .. p_sampler.rand_start_amount.name))

        screen.level(selected_screen_param == 8 and 15 or 2)
        screen.move(90, 25)
        screen.text_right("rEnd:")
        screen.move(95, 25)
        local rand_length_unquantized = params:get(pattern_slice ..
                                                       p_sampler.rand_end_probability
                                                           .name)
        if rand_length_unquantized <= 0 then
            screen.text("f")
        elseif rand_length_unquantized >= 1 then
            screen.text("t")
        else
            screen.text(rand_length_unquantized)
        end

        screen.level(selected_screen_param == 9 and 15 or 2)
        screen.move(90, 35)
        screen.text_right("rPan:")
        screen.move(95, 35)
        screen.text(params:get(pattern_slice .. p_sampler.rand_pan_amount.name))

        screen.level(selected_screen_param == 10 and 15 or 2)
        screen.move(90, 45)
        screen.text_right("rel:")
        screen.move(95, 45)
        screen.text(params:get(pattern_slice .. p_sampler.release.name))

        screen.level(selected_screen_param == 11 and 15 or 2)
        screen.move(90, 55)
        screen.text_right("loop:")
        screen.move(95, 55)
        local loop = params:get(pattern_slice .. p_sampler.loop.name)
        if loop <= 0 then
            screen.text("f")
        elseif loop >= 1 then
            screen.text("t")
        else
            screen.text(loop)
        end

    elseif pages.index == 3 then
        -- position
        screen.level(2)
        screen.move(90, 5)
        screen.text_right("pos ")
        screen.move(95, 5)
        if playing_slice > 0 then
            screen.text(playing_slice)
        else
            screen.text("-")
        end

        screen.level(2)
        screen.move(40, 5)
        screen.text_right("offset")

        -- offset params
        screen.level(selected_screen_param == 2 and 15 or 2)
        screen.move(40, 15)
        screen.text_right("atk:")
        screen.move(45, 15)
        local attack = params:get(p_sampler.attack.name)
        if attack <= -100 or attack >= 100 then
            screen.text(math.floor(attack))
        else
            screen.text(attack)
        end

        screen.level(selected_screen_param == 3 and 15 or 2)
        screen.move(40, 25)
        screen.text_right("len:")
        screen.move(45, 25)
        local length = params:get(p_sampler.length.name)
        if length <= -100 or length >= 100 then
            screen.text(math.floor(length))
        else
            screen.text(length)
        end

        screen.level(selected_screen_param == 4 and 15 or 2)
        screen.move(40, 35)
        screen.text_right("lvl:")
        screen.move(45, 35)
        local level = params:get(p_sampler.level.name)
        if level <= -100 or level >= 100 then
            screen.text(math.floor(level))
        else
            screen.text(level)
        end

        screen.level(selected_screen_param == 5 and 15 or 2)
        screen.move(40, 45)
        screen.text_right("rate:")
        screen.move(45, 45)
        local playback_rate = params:get(p_sampler.playback_rate.name)
        if playback_rate <= -100 or playback_rate >= 100 then
            screen.text(math.floor(playback_rate))
        else
            screen.text(playback_rate)
        end

        screen.level(selected_screen_param == 6 and 15 or 2)
        screen.move(40, 55)
        screen.text_right("rFreq:")
        screen.move(45, 55)
        local rand_freq = params:get(p_sampler.rand_freq.name)
        if rand_freq <= -100 or rand_freq >= 100 then
            screen.text(math.floor(rand_freq))
        else
            screen.text(rand_freq)
        end

        screen.level(selected_screen_param == 7 and 15 or 2)
        screen.move(90, 15)
        screen.text_right("rStart:")
        screen.move(95, 15)
        local rand_length_amount = params:get(p_sampler.rand_start_amount.name)
        if rand_length_amount <= -100 or rand_length_amount >= 100 then
            screen.text(math.floor(rand_length_amount))
        else
            screen.text(rand_length_amount)
        end

        screen.level(selected_screen_param == 8 and 15 or 2)
        screen.move(90, 25)
        screen.text_right("rEnd:")
        screen.move(95, 25)
        local rand_length_unquantized = params:get(
                                            p_sampler.rand_end_probability.name)
        if rand_length_unquantized <= -100 or rand_length_unquantized >= 100 then
            screen.text(math.floor(rand_length_unquantized))
        else
            screen.text(rand_length_unquantized)
        end

        screen.level(selected_screen_param == 9 and 15 or 2)
        screen.move(90, 35)
        screen.text_right("rPan:")
        screen.move(95, 35)
        local rand_pan_amount = params:get(p_sampler.rand_pan_amount.name)
        if rand_pan_amount <= -100 or rand_pan_amount >= 100 then
            screen.text(math.floor(rand_pan_amount))
        else
            screen.text(rand_pan_amount)
        end

        screen.level(selected_screen_param == 10 and 15 or 2)
        screen.move(90, 45)
        screen.text_right("rel:")
        screen.move(95, 45)
        local release = params:get(p_sampler.release.name)
        if release <= -100 or release >= 100 then
            screen.text(math.floor(release))
        else
            screen.text(release)
        end

        screen.level(selected_screen_param == 11 and 15 or 2)
        screen.move(90, 55)
        screen.text_right("loop:")
        screen.move(95, 55)
        local loop = params:get(p_sampler.loop.name)
        if loop <= -100 or loop >= 100 then
            screen.text(math.floor(loop))
        else
            screen.text(loop)
        end
    end

    -- draw a crosshair in the center of the screen
    -- screen.level(15)
    -- screen.move(screenWidth / 2, 0)
    -- screen.line(screenWidth / 2, screenHeight)
    -- screen.move(0, screenHeight / 2)
    -- screen.line(screenWidth, screenHeight / 2)
    -- screen.stroke()

    screen_dirty = false
    screen.update()
end

function g.key(x, y, z)
    if z == 1 then -- if a grid key is pressed...
        local key = (y - 1) * 16 + x
        params:set("selected_slice", key)

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
    local selected_slice = (y - 1) * 16 + x -- calculate the index in slices based on the x and y coordinates
    local pattern = params:get("selected_pattern")
    local param = "p" .. pattern .. "s" .. selected_slice .. "enabled"
    params:set(param, params:get(param) ~ 1)
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
    local pattern = params:get("selected_pattern")
    g:all(0)

    for i = 1, #patterns[pattern].slices do
        if patterns[pattern].slices[i].altered then
            g:led(leds[i].x, leds[i].y, 8)
        end

        if patterns[pattern].slices[i].enabled then
            g:led(leds[i].x, leds[i].y, 15)
        end
    end

    if playing_slice > 0 then
        g:led(leds[playing_slice].x, leds[playing_slice].y,
              playing_slice_led_brightness)
    end

    g:refresh()
end

function playing_slice_led_clock()
    local direction = 1 -- 1 for increasing, -1 for decreasing
    while true do
        clock.sleep(1 / 15)
        playing_slice_led_brightness = playing_slice_led_brightness + direction
        if playing_slice_led_brightness >= 15 then
            direction = -1
        elseif playing_slice_led_brightness <= 0 then
            direction = 1
        end
        grid_dirty = true
    end
end

function playing_slice_screen_clock()
    local direction = 1 -- 1 for increasing, -1 for decreasing
    while true do
        clock.sleep(1 / 15)
        playing_slice_screen_brightness =
            playing_slice_screen_brightness + direction
        if playing_slice_screen_brightness >= 15 then
            direction = -1
        elseif playing_slice_screen_brightness <= 0 then
            direction = 1
        end
        screen_dirty = true
    end
end

function rotation_clock()
    while true do
        clock.sync(1 / 0.5)
        if params:get("rotate") == 1 then params:set("rotation", 1) end
    end
end

function duration_clock()
    clock.sleep(duration)
    print("waited duration: " .. duration)
end

function cleanup() engine.free() end
