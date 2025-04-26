using JSON


function get_date_key(paramsvec::Vector{String})
    possible_date_keys = ["DeliveryDate", 
                         "deliveryDate",
                         "DeliveryHour", 
                         "deliveryHour",
                         "DeliveryInterval", 
                         "IntervalEnding", 
                         "intervalTime",
                         "OperatingDay", 
                         "operatingDay",
                         "OperatingDate", 
                         "SCEDTimestamp", 
                         "SCEDTimeStamp", 
                         "RTDTimestamp", 
                         "LDFDate"]
    # Remove "To" and "From" Get first matching date key from params 
    found_params = String[]
    for param in replace.(paramsvec, "To" => "", "From" => "")
        # Check if the parameter is in the list of possible date keys
        if param in possible_date_keys
            push!(found_params, param)
        end
    end
    return found_params
end



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
