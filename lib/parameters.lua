parameters = {}

function parameters.init()
    params:add_file("sample", "sample", sample_path)
    params:set_action("sample", function(x)
        filesystem:set_sample(x)
    end)
end

return parameters
