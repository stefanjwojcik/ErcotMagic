## Functions to parse 60 day energy offer data! 

## Generator data - contains awarded amounts, curves, and resource type
params = Dict("deliveryDateFrom" => "2024-02-02", 
                "deliveryDateTo" => "2024-02-03", 
                "size" => "100")
gen_dat = get_ercot_data(params, gen_data)
## Remove spaces from the column names
gen_dat = rename(gen_dat, replace.(names(gen_dat), " " => "_"))
## Tabulate 

# - need to get a dense enough sample of data from each plant to get an average sense of their curve
# - how many segments does each plant typically offer? 
# - what is the median $/mwh segment price value per plant? 
# - what is the distribution of the median segment price? by fuel type?