## Utility Functions 
## Note: edit ~/.bigqueryrc to set global settings for bq command line tool

using CSV, DataFrames, JSON3

function read_json(file_path::String)
    json_data = JSON3.read(open(file_path, "r"))
    return json_data
end

"""
## bq_auth()
- If you are switching projects, you need to run gcloud config set project nanocentury to set the project.
- Activate the service account using the credentials file
"""
function bq_auth(keyname::String="nanocentury-credentials.json")
    auth_path =joinpath(homedir(),".ercotmagic", keyname)
    if isfile(auth_path)
        run(`gcloud auth activate-service-account --key-file=$auth_path`)
    else
        println("Credentials file not found")
    end
end

function bq_set_project(project::String)
    run(`gcloud config set project $project`)
end

"""
## julia_to_bq_type(julia_type::DataType)
- Map Julia types to BigQuery types

Arguments:
  - julia_type: The Julia data type to map

Returns:
  - The corresponding BigQuery type as a string
"""
function julia_to_bq_type(julia_type::DataType)
    if julia_type == String
        return "STRING"
    elseif julia_type == Int64
        return "INTEGER"
    elseif julia_type == Float64
        return "FLOAT"
    elseif julia_type <: AbstractArray{Float64}
        return "FLOAT64"
    elseif julia_type <: AbstractArray{Int64}
        return "INTEGER"
    else
        return "STRING"
    end
end

"""
## create_bq_schema(df::DataFrame)
- Create a BigQuery schema from a DataFrame

Arguments:
  - df: The DataFrame to create the schema from

Returns:
  - The schema as a string in BigQuery format

Example:
df = DataFrame(text = ["Alice", "Bob"], embed = [rand(3), rand(3)])
create_bq_schema(df)
"""
function create_bq_schema(df::DataFrame)
    schema = []
    for col in names(df)
        if eltype(df[!, col]) <: AbstractArray
            push!(schema, Dict("name" => col, "type" => "FLOAT64", "mode" => "REPEATED"))
        else
            push!(schema, Dict("name" => col, "type" => julia_to_bq_type(eltype(df[!, col])), "mode" => "NULLABLE"))
        end
    end
    return JSON3.write(schema)
end

"""
## dataframe_to_json(df::DataFrame, file_path::String)
- Convert a DataFrame to JSON format and save to a file

Arguments:
  - df: The DataFrame to convert
  - file_path: The path where the JSON file should be saved
"""
function dataframe_to_json(df::DataFrame, file_path::String)
    open(file_path, "w") do io
        for row in eachrow(df)
            JSON.print(io, Dict(col => row[col] for col in names(df)))
            write(io, "\n")
        end
    end
end

"""
# Function to send a DataFrame to a BigQuery table
## send_to_bq_table(df::DataFrame, dataset_name::String, table_name::String)
- Send a DataFrame to a BigQuery table, which will append if the table already exists

Arguments:
  - df: The DataFrame to upload
  - dataset_name: The BigQuery dataset name
  - table_name: The BigQuery table name

# Example usage to send a DataFrame to a BigQuery table
da = ErcotMagic.batch_retrieve_data(Date(2023, 12, 13), Date(2023, 12, 13), "da_prices")
ErcotMagic.send_to_bq_table(da[1:2,:], "ercot", "da_prices")

# Load in the mapped data 
dat = CSV.read("data/Resource_Node_to_Unit_latest.csv", DataFrame)
# convert all columns to string 
for col in names(dat)
    dat[!, Symbol(col)] = string.(dat[!, Symbol(col)])
end
ErcotMagic.send_to_bq_table(dat, "ercot", "nodetounit")

"""
function send_to_bq_table(df::DataFrame, dataset_name::String, table_name::String)
    # Temporary JSON file
    json_file_path = tempname() * ".json"
    schema = create_bq_schema(df)
    ## Save schema to a file
    schema_file_path = tempname() * ".json"
    open(schema_file_path, "w") do io
        write(io, schema)
    end
    
    # Save DataFrame to JSON
    dataframe_to_json(df, json_file_path)

    # Use bq command-line tool to load JSON to BigQuery table with specified schema
    run(`bq load --source_format=NEWLINE_DELIMITED_JSON $dataset_name.$table_name $json_file_path $schema_file_path`)
    
    # Clean up and remove the temporary JSON file after upload
    rm(json_file_path)
    rm(schema_file_path)
    return nothing 
end

"""
## bq(query::String)
- Run a BigQuery query and return the result as a DataFrame

Example: bq("SELECT * FROM ostreacultura.climate_truth.training LIMIT 10")
"""
function bq(query::String, querylimit = "1000000000000")
    tname = tempname()
    #err_file = tempname()
    try
        run(pipeline(`bq query --maximum_bytes_billed=$querylimit --use_legacy_sql=false --format=csv $query`, tname, tname))
    catch e
        println("Error running query: $query")
        println(read(tname, String))
        return nothing
    end
    return CSV.read(tname, DataFrame)
end

"""
## Partition table by date
"""
function partition_table(table::String)
    query = """
    CREATE OR REPLACE TABLE $table
    PARTITION BY DATE(CAST(DATETIME AS DATETIME))
    AS
    SELECT *
    FROM $table
    """
    return query
end

"""
## Function to average embeddings over some group 
example: 
avg_embeddings("ostreacultura.climate_truth.embtest", "text", "embed")
"""
function avg_embeddings(table::String, group::String, embedname::String)
    query = """
    SELECT
        $group,
        ARRAY(
            SELECT AVG(value)
            FROM UNNEST($embedname) AS value WITH OFFSET pos
            GROUP BY pos
            ORDER BY pos
        ) AS averaged_array
    FROM (
        SELECT $group, ARRAY_CONCAT_AGG($embedname) AS $embedname
        FROM $table
        GROUP BY $group
    )
    """
    return query
end

"""
## SAVE results of query to a CSV file

Example: 
bq_csv("SELECT * FROM ostreacultura.climate_truth.training LIMIT 10", "data/test.csv")
"""
function bq_csv(query::String, path::String)
    run(pipeline(`bq query --use_legacy_sql=false --format=csv $query`, path))
end

# Idea is to dynamically update the Bigquery Data 
function get_start_date(endpoint::String)
    bq_start_date = ErcotMagic.bq("SELECT MAX(DATETIME(DATETIME)) FROM ercot." * endpoint)
    bq_start_date = isnothing(bq_start_date) ? Date(2023, 12, 13) : Date(bq_start_date[1, 1])
    return bq_start_date + Day(1)
end
