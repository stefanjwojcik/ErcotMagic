## Generation 

"""
"solar_system_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-737-cd/spp_hrly_avrg_actl_fcast?")
"wind_system_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-732-cd/wpp_hrly_avrg_actl_fcast?")
"wind_prod_5min" => ("intervalEnding", "https://api.ercot.com/api/public-reports/np4-733-cd/wpp_actual_5min_avg_values?")
"solar_prod_5min" => ("intervalEnding", "https://api.ercot.com/api/public-reports/np4-738-cd/spp_actual_5min_avg_values?")
"""
function get_generation(location, dates; kwargs...)
    type = get(kwargs, :type, "solar_system_forecast")
    # get the data for the location
    dat = ErcotMagic.get_data("solar_prod_5min", dates; kwargs...)
    # filter by location
    dat = filter(x -> x.location == location, dat)
    # remove location column
    select!(dat, Not(:location))
    # rename columns
    rename!(dat, :datetime => :time)
    return dat
end