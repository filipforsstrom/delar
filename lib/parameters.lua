parameters = {}

p_filter = {
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

    parameters:init_filter_params()
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
