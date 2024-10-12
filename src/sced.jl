
### Bulk downloading SCED data 
function SCED_data(; kwargs...)
    from = get(kwargs, :from, DateTime(today()) - Dates.Day(89) + Dates.Hour(7))
    to = get(kwargs, :to, from + Dates.Hour(22))
    params = Dict("SCEDTimestampFrom" => string(from), 
                "SCEDTimestampTo" => string(to), 
                "size" => "1000000", 
                #"resourceType" => "SCGT90", 
                "submittedTPOPrice1From" => "-40", # wind comes at -40
                "submittedTPOPrice1To" => "4000", 
                "submittedTPOMW1From" => "5", #minimum volumetric bid 
                "submittedTPOMW1To" => "10000", 
                "telemeteredResourceStatus" => "ON") #  
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
