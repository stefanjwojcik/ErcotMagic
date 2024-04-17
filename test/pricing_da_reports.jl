## Functions to parse 60 day energy offer data! 

## Generator data - contains awarded amounts, curves, and resource type
allfiles = readdir(joinpath("data"))
# Filter to those with DA_energy in name 
da_energy_files = filter(x -> occursin("DA_energy", x), allfiles)

# - need to get a dense enough sample of data from each plant to get an average sense of their curve
# - how many segments does each plant typically offer? 
# - what is the median $/mwh segment price value per plant? 
# - what is the distribution of the median segment price? by fuel type?

### Function to open a single .jld file and parse 
function parse_da_energy_file(file)
    data = @load joinpath("data", file)
    return data
end
