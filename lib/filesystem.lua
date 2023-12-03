filesystem = {}

function filesystem:set_sample(sample)
    engine.setSample(sample)
    is_playing = true
end

return filesystem
