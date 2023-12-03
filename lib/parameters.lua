parameters = {}

parameters.p_sampler = {
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
    loop = {
        name = "loop",
        default = 0
    },
    playback_rate = {
        name = "playback_rate",
        default = 0
    },
    rand_freq = {
        name = "rand_freq",
        default = 1
    },
    rand_start_amount = {
        name = "rand_start_amount",
        default = 0
    },
    rand_end_probability = {
        name = "rand_end_probability",
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

local p_filter = {
    cutoff = {
        name = "filter_cutoff",
        default = 20000
    },
    resonance = {
        name = "filter_resonance",
        default = 1
    },
    lfo_speed = {
        name = "filter_lfo_speed",
        default = 1.0
    },
    attack = {
        name = "filter_attack",
        default = 0.01
    },
    release = {
        name = "filter_release",
        default = 0.01
    },
    mod_env = {
        name = "filter_mod_env",
        default = 0
    },
    mod_lfo = {
        name = "filter_mod_lfo",
        default = 0
    },
    level = {
        name = "filter_level",
        default = 1.0
    }
}

function parameters.init()
    params:add_file("sample", "sample", sample_path)
    params:set_action("sample", function(x)
        filesystem:set_sample(x)
    end)

    params:add_number("rotation", "rotation", -1, 1, 0)
    params:set_action("rotation", function(x)
        if x > 0 or x < 0 then
            if #rotations < 1 then
                table.insert(rotations, x)
            end
        end
        params:set("rotation", 0)
    end)
    params:hide("rotation")
    params:add_number("rotate", "rotate", 0, 1, 0)
    params:hide("rotate")

    params:add_number("num_slices", "num slices", 1, max_num_slices, 128)
    params:set_action("num_slices", function(x)
        engine.set_num_slices(x)
    end)
    params:hide("num_slices")
    params:add_number("selected_pattern", "pattern", 1, max_num_patterns, 1)
    params:set_action("selected_pattern", function(x)
        sequence = get_active_slices(patterns[x].slices)
    end)
    params:hide("selected_pattern")
    params:add_number("selected_slice", "slice", 1, params:get("num_slices"), 1, nil, true)
    -- params:set_action("selected_slice", function(x)
    --     if x > params:get("num_slices") then
    --         params:set("selected_slice", params:get("num_slices"))
    --     end
    --     grid_dirty = true
    --     screen_dirty = true
    -- end)
    params:hide("selected_slice")

    parameters:init_filter_params()
    parameters:init_sampler_params()

    params:bang()
    for p = 1, max_num_patterns do
        params:set("p" .. p .. "s1enabled", 1)
    end
end

function parameters:init_sampler_params()
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
    params:add_control(p_sampler.attack.name, "attack", percentage)
    params:add_control(p_sampler.length.name, "length", percentage)
    params:add_control(p_sampler.level.name, "level", percentage)
    params:add_control(p_sampler.loop.name, "loop", percentage)
    params:add_control(p_sampler.rand_freq.name, "rand freq", percentage)
    params:add_control(p_sampler.rand_start_amount.name, "rand length", percentage)
    params:add_control(p_sampler.rand_end_probability.name, "unquantize rand length", percentage)
    params:add_control(p_sampler.rand_pan_amount.name, "rand pan", percentage)
    params:add_control(p_sampler.playback_rate.name, "playback rate", percentage)
    params:add_control(p_sampler.release.name, "release", percentage)

    for p_num = 1, max_num_patterns do
        for s_num = 1, max_num_slices do
            params:add_group("pattern " .. p_num .. " slice " .. s_num, num_synth_params)
            params:hide("pattern " .. p_num .. " slice " .. s_num)
            params:add_number("p" .. p_num .. "s" .. s_num .. "enabled", "enabled", 0, 1, 0)
            params:set_action("p" .. p_num .. "s" .. s_num .. "enabled", function(x)
                slices[s_num].enabled = (x == 1)
                patterns[p_num].slices[s_num].enabled = (x == 1)
                sequence = get_active_slices(patterns[params:get("selected_pattern")].slices)
            end)
            params:add_number("p" .. p_num .. "s" .. s_num .. "altered", "altered", 0, 1, 0)
            params:set_action("p" .. p_num .. "s" .. s_num .. "altered", function(x)
                -- print("altered" .. i .. " changed to " .. x)
                if params_not_default(s_num) then
                    slices[s_num].altered = true
                    patterns[p_num].slices[s_num].altered = true
                else
                    params:set("p" .. p_num .. "s" .. s_num .. "altered", 0)
                    slices[s_num].altered = false
                    patterns[p_num].slices[s_num].altered = false
                end
            end)
            params:add_control("p" .. p_num .. "s" .. s_num .. p_sampler.attack.name, "attack", attack)
            params:set_action("p" .. p_num .. "s" .. s_num .. p_sampler.attack.name, function(x)
                patterns[p_num].slices[s_num].attack = x
                params:set("p" .. p_num .. "s" .. s_num .. "altered", params:get("p" .. p_num .. "s" .. s_num .. "altered") ~ 1)
            end)
            params:add_control("p" .. p_num .. "s" .. s_num .. p_sampler.length.name, "length", length)
            params:set_action("p" .. p_num .. "s" .. s_num .. p_sampler.length.name, function(x)
                patterns[p_num].slices[s_num].length = x
                params:set("p" .. p_num .. "s" .. s_num .. "altered", params:get("p" .. p_num .. "s" .. s_num .. "altered") ~ 1)
            end)
            params:add_control("p" .. p_num .. "s" .. s_num .. p_sampler.level.name, "level", level)
            params:set_action("p" .. p_num .. "s" .. s_num .. p_sampler.level.name, function(x)
                patterns[p_num].slices[s_num].level = x
                params:set("p" .. p_num .. "s" .. s_num .. "altered", params:get("p" .. p_num .. "s" .. s_num .. "altered") ~ 1)
            end)
            params:add_control("p" .. p_num .. "s" .. s_num .. p_sampler.loop.name, "loop", loop)
            params:set_action("p" .. p_num .. "s" .. s_num .. p_sampler.loop.name, function(x)
                patterns[p_num].slices[s_num].loop = x
                params:set("p" .. p_num .. "s" .. s_num .. "altered", params:get("p" .. p_num .. "s" .. s_num .. "altered") ~ 1)
            end)
            params:add_control("p" .. p_num .. "s" .. s_num .. p_sampler.rand_freq.name, "rand freq", rand_freq)
            params:set_action("p" .. p_num .. "s" .. s_num .. p_sampler.rand_freq.name, function(x)
                patterns[p_num].slices[s_num].rand_freq = x
                params:set("p" .. p_num .. "s" .. s_num .. "altered", params:get("p" .. p_num .. "s" .. s_num .. "altered") ~ 1)
            end)
            params:add_control("p" .. p_num .. "s" .. s_num .. p_sampler.rand_start_amount.name, "rand length",
                rand_length_amount)
            params:set_action("p" .. p_num .. "s" .. s_num .. p_sampler.rand_start_amount.name, function(x)
                patterns[p_num].slices[s_num].rand_length_amount = x
                params:set("p" .. p_num .. "s" .. s_num .. "altered", params:get("p" .. p_num .. "s" .. s_num .. "altered") ~ 1)
            end)
            params:add_control("p" .. p_num .. "s" .. s_num .. p_sampler.rand_end_probability.name, "unquantize rand length",
                rand_length_unquantized)
            params:set_action("p" .. p_num .. "s" .. s_num .. p_sampler.rand_end_probability.name, function(x)
                patterns[p_num].slices[s_num].rand_length_unquantized = x
                params:set("p" .. p_num .. "s" .. s_num .. "altered", params:get("p" .. p_num .. "s" .. s_num .. "altered") ~ 1)
            end)
            params:add_control("p" .. p_num .. "s" .. s_num .. p_sampler.rand_pan_amount.name, "rand pan", rand_pan_amount)
            params:set_action("p" .. p_num .. "s" .. s_num .. p_sampler.rand_pan_amount.name, function(x)
                patterns[p_num].slices[s_num].rand_pan_amount = x
                params:set("p" .. p_num .. "s" .. s_num .. "altered", params:get("p" .. p_num .. "s" .. s_num .. "altered") ~ 1)
            end)
            params:add_number("p" .. p_num .. "s" .. s_num .. p_sampler.playback_rate.name, "playback rate", -3, 4, 0)
            params:set_action("p" .. p_num .. "s" .. s_num .. p_sampler.playback_rate.name, function(x)
                patterns[p_num].slices[s_num].playback_rate = x
                params:set("p" .. p_num .. "s" .. s_num .. "altered", params:get("p" .. p_num .. "s" .. s_num .. "altered") ~ 1)
            end)
            params:add_control("p" .. p_num .. "s" .. s_num .. p_sampler.release.name, "release", release)
            params:set_action("p" .. p_num .. "s" .. s_num .. p_sampler.release.name, function(x)
                patterns[p_num].slices[s_num].release = x
                params:set("p" .. p_num .. "s" .. s_num .. "altered", params:get("p" .. p_num .. "s" .. s_num .. "altered") ~ 1)
            end)
        end
    end
end

function parameters:init_filter_params()
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
    for _, _ in pairs(p_filter) do
        length = length + 1
    end

    params:add_group("filter", length)
    params:add_control(p_filter.cutoff.name, "cutoff", cutoff)
    params:set_action(p_filter.cutoff.name, function(x)
        engine.set_filter("cutoff", x)
    end)
    params:add_control(p_filter.resonance.name, "resonance", resonance)
    params:set_action(p_filter.resonance.name, function(x)
        engine.set_filter("resonance", x)
    end)
    params:add_control(p_filter.lfo_speed.name, "lfo speed", lfo_speed)
    params:set_action(p_filter.lfo_speed.name, function(x)
        engine.set_filter("lfoSpeed", x)
    end)
    params:add_control(p_filter.attack.name, "attack", attack)
    params:set_action(p_filter.attack.name, function(x)
        engine.set_filter("attack", x)
    end)
    params:add_control(p_filter.release.name, "release", release)
    params:set_action(p_filter.release.name, function(x)
        engine.set_filter("release", x)
    end)
    params:add_control(p_filter.mod_env.name, "mod env", mod_env)
    params:set_action(p_filter.mod_env.name, function(x)
        engine.set_filter("modEnv", x)
    end)
    params:add_control(p_filter.mod_lfo.name, "mod lfo", mod_lfo)
    params:set_action(p_filter.mod_lfo.name, function(x)
        engine.set_filter("modLfo", x)
    end)
    params:add_control(p_filter.level.name, "level", level)
    params:set_action(p_filter.level.name, function(x)
        engine.set_filter("level", x)
    end)
end

return parameters
