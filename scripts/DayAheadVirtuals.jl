## Day-Ahead Virtual Awards 

using ErcotMagic 

function DAVirtuals(; kwargs...)
    from = get(kwargs, :from, Date(today()) - Dates.Day(90) )
    to = get(kwargs, :to, Date(today()) - Dates.Day(60))
    addparams = get(kwargs, :addparams, Dict())
    endpoint = get(kwargs, :endpoint, ErcotMagic.sixty_dam_awards)
    params = Dict("size" => "1000000", 
                #"resourceType" => "PVGR", 
                #"submittedTPOPrice1From" => "-40", # wind comes at -40
                #"submittedTPOPrice1To" => "4000", 
                #"submittedTPOMW1From" => "2", #minimum volumetric bid 
                #"submittedTPOMW1To" => "10000"
    ) 
    merge!(params, addparams)
    dat = get_ercot_data(params, endpoint)
    ErcotMagic.normalize_columnnames!(dat)
end

## Get all existing virtuals for a specific node 
sgas = DAVirtuals(endpoint=ErcotMagic.sixty_dam_awards, addparams=Dict("settlementPointName" => "NOBLESLR_ALL"))

sgas = DAVirtuals(addparams=Dict("settlementPointName" => "NOBLESLR_ALL"))
