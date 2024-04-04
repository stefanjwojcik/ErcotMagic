## Data artifacts 

using Tar, Inflate, SHA, ErcotMagic, JLD

## This is based on: https://pkgdocs.julialang.org/v1/artifacts/
alldata = get_data()
@save "training.jld" alldata
# compress using the command line 
# tar -czvf training.tar.gz training.jld
filename = "training.tar.gz"
# Copy these to Artifacts.toml
println("sha256: ", bytes2hex(open(sha256, filename)))
println("git-tree-sha1: ", Tar.tree_hash(IOBuffer(inflate_gzip(filename))))
# upload to git and provide 


# alldata = get_data()
function get_data()
    ##### TRAINING DATA 
    ## Get the data from ERCOT API and train the forecaster
    params = Dict("RTDTimestampFrom" => "2024-02-01T00:00:00", 
                    "RTDTimestampTo" => "2024-02-02T01:00:00",
                    "settlementPoint" => "HB_NORTH")
    rt_dat = get_ercot_data(params, ErcotMagic.rt_prices)
    ## Convert to Float32
    dat_train = Float32.(rt_dat.LMP)

    ###### VALIDATION DATA ######
    ## Download the next day's data for validation 
    params = Dict("RTDTimestampFrom" => "2024-02-02T00:00:00", 
                    "RTDTimestampTo" => "2024-02-03T01:00:00",
                    "settlementPoint" => "HB_NORTH")
    rt_datval = get_ercot_data(params, ErcotMagic.rt_prices)
    dat_valid = Float32.(rt_datval.LMP)

    #### ALL DATA ####
    alldata = dat_train, dat_valid
    return alldata
end

