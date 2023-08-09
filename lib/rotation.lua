local Rotation = {}

local clock = require 'core/clock'
-- local params = require 'core/paramset'
local params
local rotations = {1, 1, 1}

function Rotation:init(main_params)
    self.params = main_params
    rotation_clock = clock.run(self.clock)
end

function Rotation:insert(direction)
    table.insert(rotations, direction)
end

function Rotation:clock()
    while true do
        clock.sync(1 / 10)
        if #rotations > 0 then
            Rotation.rotate(rotations[1])
            table.remove(rotations, 1)
        end
        -- print("clock")
    end
end

function Rotation:rotate(x)
    local params_to_rotate = {"enabled", "altered", p_sampler.attack.name, p_sampler.length.name, p_sampler.level.name,
                              p_sampler.loop.name, p_sampler.playback_rate.name, p_sampler.rand_freq.name,
                              p_sampler.rand_start_amount.name, p_sampler.rand_end_probability.name,
                              p_sampler.rand_pan_amount.name, p_sampler.release.name}
    local num_steps = params:get("num_steps")
    print(num_steps)

    -- -- store all params in a table
    -- local all_params = {}
    -- for i = 1, num_steps do
    --     all_params[i] = {}
    --     for _, param in ipairs(params_to_rotate) do
    --         all_params[i][param] = params:get(param .. i)
    --     end
    -- end

    -- -- rotate the table
    -- local rotate_steps = x % num_steps -- calculate the number of steps to rotate
    -- if rotate_steps ~= 0 then -- only rotate if there are steps to rotate
    --     if rotate_steps < 0 then -- rotate left
    --         rotate_steps = rotate_steps + num_steps
    --     end
    --     for i = 1, rotate_steps do
    --         table.insert(all_params, 1, table.remove(all_params, num_steps))
    --     end
    -- end

    -- -- set all params to the new values
    -- for i = 1, num_steps do
    --     for _, param in ipairs(params_to_rotate) do
    --         params:set(param .. i, all_params[i][param])
    --     end
    -- end
end

return Rotation
