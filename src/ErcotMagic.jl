module ErcotMagic

using HTTP
using JSON

mutable struct ErcotAPICall
    base_url::String
    params::Dict{String, String}
end


function ErcotAPICall(;base_url=nothing, params=nothing)
    if base_url === nothing
        error("base_url is required")
    end
    if params === nothing
        params = Dict{String, String}()
    end
    new(base_url, params)
end

function 

"""
# Example:
data = fetch_ercot_dalmp_data(delivery_date_from="2024-01-01", delivery_date_to="2024-01-31")

"""
function fetch_ercot_dalmp_data(;dst_flag=nothing, delivery_date_from=nothing, 
                           delivery_date_to=nothing, hour_ending=nothing,
                           bus_name=nothing, lmp_from=nothing, lmp_to=nothing,
                           page=nothing, size=nothing, sort=nothing, dir=nothing)
    
    base_url = "https://api.ercot.com/api/public-reports/np4-183-cd/dam_hourly_lmp"
    params = []
    
    if dst_flag !== nothing
        push!(params, "DSTFlag=$dst_flag")
    end
    if delivery_date_from !== nothing
        push!(params, "deliveryDateFrom=$delivery_date_from")
    end
    if delivery_date_to !== nothing
        push!(params, "deliveryDateTo=$delivery_date_to")
    end
    if hour_ending !== nothing
        push!(params, "hourEnding=$hour_ending")
    end
    if bus_name !== nothing
        push!(params, "busName=$bus_name")
    end
    if lmp_from !== nothing
        push!(params, "LMPFrom=$lmp_from")
    end
    if lmp_to !== nothing
        push!(params, "LMPTo=$lmp_to")
    end
    if page !== nothing
        push!(params, "page=$page")
    end
    if size !== nothing
        push!(params, "size=$size")
    end
    if sort !== nothing
        push!(params, "sort=$sort")
    end
    if dir !== nothing
        push!(params, "dir=$dir")
    end
    
    query_string = join(params, "&")
    full_url = string(base_url, query_string |> isempty ? "" : "?", query_string)
    
    response = HTTP.get(full_url)
    
    if response.status == 200
        return JSON.parse(String(response.body))
    else
        error("Request failed with status code: ", response.status)
    end
end


"""
# 60 Day DAM Energy Bid Awards
# NP3-966-ER
# Request for 60 day DAM Energy Bid Awards
https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_bid_awards[?deliveryDateFrom][&deliveryDateTo][&hourEndingFrom][&hourEndingTo][&settlementPointName][&qseName][&energyOnlyBidAwardInMWFrom][&energyOnlyBidAwardInMWTo][&settlementPointPriceFrom][&settlementPointPriceTo][&bidId][&page][&size][&sort][&dir]
"""
function fetch_ercot_60_day_dam_energy_bid_awards()
end



end # module ErcotMagic
