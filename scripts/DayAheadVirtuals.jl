## Day-Ahead Virtual Awards 

using ErcotMagic 

# Function For DA Virtuals 
function DAVirtuals(; kwargs...)
    addparams = get(kwargs, :addparams, Dict())
    endpoint = get(kwargs, :endpoint, ErcotMagic.sixty_dam_awards)
    params = Dict("size" => "1000000"
    ) 
    merge!(params, addparams)
    dat = get_ercot_data(params, endpoint)
    ErcotMagic.normalize_columnnames!(dat)
end

"""
## Gets Telemetered Net Output and Virtuals for both Noble Solar Assets 
oppmin = opp[1:300, :]
plot(oppmin.DATETIME, [oppmin.MeterMWhs, oppmin.EnergyOnlyOfferAwardinMW], label=["Metered" "Virtual"], xlabel="Date", ylabel="Net Output", title="Noble Solar Net Output", legend=:topleft)
"""
function output_and_awards()
    # Actual Realized SCED Net output + ancillary awards
    sol1 = ErcotMagic.SCED_gen_data(addparams=Dict("resourceName" => "NOBLESLR_SOLAR1"))
    ErcotMagic.normalize_columnnames!(sol1)
    sol1 = sced_to_hourly(sol1)
    sol2 = ErcotMagic.SCED_gen_data(addparams=Dict("resourceName" => "NOBLESLR_SOLAR2"))
    ErcotMagic.normalize_columnnames!(sol2)
    sol2 = sced_to_hourly(sol2)
    solall = select(sol1, [:DATETIME, :TelemeteredNetOutput]) |> 
            (data -> leftjoin(data, select(sol2, [:DATETIME, :TelemeteredNetOutput]), on=:DATETIME, makeunique=true)) 
    solall.MeterMWhs .= solall.TelemeteredNetOutput .+ solall.TelemeteredNetOutput_1
    solall = select(solall, [:DATETIME, :MeterMWhs])
    ## Get all existing virtuals for a specific node 
    sgas = DAVirtuals(addparams=Dict("settlementPointName" => "NOBLESLR_ALL")) 
    sgas.DATETIME = DateTime.(sgas.DeliveryDate) .+ Hour.(sgas.HourEnding) .- Hour(1)

    # Dataset containing virtuals and metered output
    opp = leftjoin(sgas, solall, on=:DATETIME)
end

