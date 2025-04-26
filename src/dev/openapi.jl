using JSON





mutable struct Url
    url::String
end

mutable struct Path
    path::String
    method::String
    spec::Spec
end

mutable struct Spec
    summary::String
    parameters::String
    responses::String
    operationId::String
    operationId::Vector{String}
    description::String
end
