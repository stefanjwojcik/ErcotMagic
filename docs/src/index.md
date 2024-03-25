# Ercot Magic Documentation

## Installation

To install the package, use the following code:

```julia
using Pkg
Pkg.add("ErcotMagic")
```

## Overview

This is the documentation for the Ercot Magic package. The Ercot API is a great tool for accessing data on the Texas electricity market. This package provides a simple interface for accessing data from the Ercot API. The package is designed to be easy to use and flexible, allowing you to access a wide range of data from the Ercot API.

## Setup

You will need to obtain a token from the Ercot API to collect data. Go to the [Ercot API](https://data.ercot.com/) and create a user name and password. Once you do that, you can use the `get_auth_token` function to obtain a token in the form required for pulling in data. This token will be used to authenticate your requests to the Ercot API. The token is valid for 60 minutes, so you will need to obtain a new token regularly, but this is handled automatically by the package.

To obtain a token, use the following code:

```julia
using ErcotMagic
token = get_auth_token()
```

## Accessing Data

The [API](https://data.ercot.com/) provides a number of endpoints that you can access. I have create a some endpoints as constants within this package for ease of operation, but you can use which ones matter for you. 

**The ERCOT API does not provide access to all public data as of 03/23/2024**. You can access key data like DA LMP, RT LMP, and load/gen forecasts, but the 60 day report data is not available.

Without further ado, let's get some data. It's very simple to access the data, but you will need to know a bit about the parameters required for each query.

### Getting Day-Ahead LMP Data
```julia
using ErcotMagic
da_prices = "https://api.ercot.com/api/public-reports/np4-190-cd/dam_stlmnt_pnt_prices?"
params = Dict("deliveryDateFrom" => "2024-02-01", "deliveryDateTo" => "2024-02-25")
da_dat = get_ercot_data(params, da_prices)
```

### Endpoint URLS

You can also use a set of constants that are predefined for a few interesting endpoints. These are defined in the code, but here are a few examples:

**Day Ahead Prices**
```julia
da_prices = "https://api.ercot.com/api/public-reports/np4-190-cd/dam_stlmnt_pnt_prices?"
```

**Real Time Prices**
```julia
rt_prices = "https://api.ercot.com/api/public-reports/np6-970-cd/rtd_lmp_node_zone_hub?"
```

Hourly system-wide Mid-Term Load Forecasts (MTLFs) for all forecast models with an indicator for which forecast was in use by ERCOT at the time of publication for current day plus the next 7.

**Ercot Load Forecast Endpoint**
```julia
ercot_load_forecast = "https://api.ercot.com/api/public-reports/np3-566-cd/lf_by_model_study_area?"
```

**Ercot Zone Load Forecast Endpoint**
```julia
ercot_zone_load_forecast = "https://api.ercot.com/api/public-reports/np3-565-cd/lf_by_model_weather_zone?"
```

**Solar System Forecast**

```julia
solar_system_forecast = "https://api.ercot.com/api/public-reports/np4-737-cd/spp_hrly_avrg_actl_fcast?"
```

**Wind System Forecast**
```julia
wind_system_forecast = "https://api.ercot.com/api/public-reports/np4-732-cd/wpp_hrly_avrg_actl_fcast?"
```

### Getting Real-Time LMP Data
```julia
rt_prices = "https://api.ercot.com/api/public-reports/np6-970-cd/rtd_lmp_node_zone_hub?"
params = Dict("RTDTimestampFrom" => "2024-02-01T00:00:00", 
                "RTDTimestampTo" => "2024-02-01T01:00:00",
                "settlementPoint" => "HB_NORTH")
rt_dat = get_ercot_data(params, rt_prices)
```

### Getting Load Forecast Data
```julia
ercot_load_forecast = "https://api.ercot.com/api/public-reports/np3-566-cd/lf_by_model_study_area?"
params = Dict("deliveryDateFrom" => "2024-02-21", "deliveryDateTo" => "2024-02-25")
lf_dat = get_ercot_data(params, ercot_load_forecast)
```


## Documentation of Functions

```@autodocs
Modules = [ErcotMagic]
```
