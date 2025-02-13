
### Bulk downloading pure Generation Resource SCED  data 
function SCED_data(; kwargs...)
    from = get(kwargs, :from, DateTime(today()) - Dates.Day(89) + Dates.Hour(7))
    to = get(kwargs, :to, from + Dates.Day(30))
    params = Dict("SCEDTimestampFrom" => string(from), 
                "SCEDTimestampTo" => string(to), 
                "size" => "1000000", 
                #"resourceType" => "PVGR", 
                "submittedTPOPrice1From" => "-40", # wind comes at -40
                "submittedTPOPrice1To" => "4000", 
                "submittedTPOMW1From" => "2", #minimum volumetric bid 
                "submittedTPOMW1To" => "10000") #  
    get_ercot_data(params, ErcotMagic.sced_data)
end

"""
# Bulk downloads SCED data (it's only available after 60 days, and 30 days are posted at a time)
## Focuses on on-peak offers (he 7-22)
"""
function update_sced_data()
    ## starting Date(today()) - Dates.Day(89)
    startdate = Date(today()) - Dates.Day(89)
    enddate = Date(today()) - Dates.Day(60)
    @showprogress for offerday in startdate:enddate
        try
            ## does this data exist? if so skip
            isfile("data/SCED_data_"*string(offerday)*".csv") && continue
            dat = SCED_data(from=DateTime(offerday) + Dates.Hour(7), 
                            to=DateTime(offerday)+Dates.Hour(22))
            dat = ErcotMagic.nothing_to_missing.(dat)
            CSV.write("data/SCED_data_"*string(offerday)*".csv", dat)
        catch e
            println("Error on date: ", i)
            println(e)
        end
    end
end

"""
# Function takes in on-peak SCED data, obtains the average price for the first segment by resource 
"""
function average_sced_prices(dat)
    ## Remove spaces from the column names
    dat = rename(dat, replace.(names(dat), " " => "_"))
    ## Remove dashes from the column names
    dat = rename(dat, replace.(names(dat), "-" => "_"))
    ## group by Resource_Name, Resource_Type,  
    dat = combine(groupby(dat, [:Resource_Name, :Resource_Type, :HSL]), :Submitted_TPO_Price1 => mean)
    return dat
end

"""
# Function takes in on-peak SCED data, obtains the average MW's across all TPO segments
"""
function average_sced_mws(dat)
    # lambda function to deal with nothing values 
    ## Remove spaces from the column names
    dat = rename(dat, replace.(names(dat), " " => "_"))
    ## Remove dashes from the column names
    dat = rename(dat, replace.(names(dat), "-" => "_"))
    # Add all TPO MW's together
    datmw = select(dat, r"Submitted_TPO_MW")
    datmw = nothing_to_zero.(datmw)
    # get rowwise max of tpo cols 
    dat.total_TPO_MW = maximum.(eachrow(datmw))
    ## group by Resource_Name, Resource_Type,  
    dat = combine(groupby(dat, [:Resource_Name, :Resource_Type, :HSL]), :total_TPO_MW => mean)
    return dat
end

function DA_energy_offers(; kwargs...)
    # From/To Dates are individual days
    from = get(kwargs, :from, Date(today()) - Dates.Day(89) )
    to = get(kwargs, :to, from + Dates.Day(1))
    onpeak = get(kwargs, :onpeak, true)
    if onpeak
        hefrom = 7
        heto = 22
    else
        hefrom = 0
        heto = 24
    end
    params = Dict("deliveryDateFrom" => string(from), 
                "deliveryDateTo" => string(to), 
                "hourEndingFrom" => string(hefrom),
                "hourEndingTo" => string(heto),
                "size" => "1000000", 
                "energyOnlyOfferMW1From" => "5", 
                "energyOnlyOfferMW1To" => "10000",
                "energyOnlyOfferPrice1From" => "-40",
                "energyOnlyOfferPrice1To" => "4000")
    get_ercot_data(params, ErcotMagic.sixty_dam_energy_only_offers)
end

"""
# Function to update the DA offer data
## Focuses on on-peak offers (he 7-22)
"""
function update_da_offer_data()
    ## starting Date(today()) - Dates.Day(89)
    startdate = Date(today()) - Dates.Day(89)
    enddate = Date(today()) - Dates.Day(60)
    @showprogress for offerday in startdate:enddate
        try
            # check if already exists 
            isfile("data/DA_energy_offers_"*string(offerday)*".csv") && continue
            dat = DA_energy_offers(from=offerday, to=offerday+Dates.Day(1), onpeak=true)
            #transform nothing to missing 
            dat = ErcotMagic.nothing_to_missing.(dat)
            CSV.write("data/DA_energy_offers_"*string(offerday)*".csv", dat)
        catch e
            println("Error on date: ", offerday)
            println(e)
        end
    end
end

function average_da_mws(dat)
    dat = rename(dat, replace.(names(dat), " " => "_"))
    ## Remove dashes from the column names
    dat = rename(dat, replace.(names(dat), "-" => "_"))
    # Add all TPO MW's together
    datmw = select(dat, r"Energy_Only_Offer_MW")
    datmw = coalesce.(datmw, 0.0)
    # get rowwise max of tpo cols 
    dat.avg_max_DA_mw_offer = maximum.(eachrow(datmw))
    ## group by Resource_Name, Resource_Type,  
    dat = combine(groupby(dat, [:Settlement_Point, :QSE]), :avg_max_DA_mw_offer => mean)
end
