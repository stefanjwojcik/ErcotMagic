## Utility Functions 
## Note: edit ~/.bigqueryrc to set global settings for bq command line tool

using CSV, DataFrames, JSON3

function read_json(file_path::String)
    json_data = JSON3.read(open(file_path, "r"))
    return json_data
end

"""
## ostreacultura_bq_auth()
- If you are switching projects, you need to run gcloud config set project nanocentury to set the project.
- Activate the service account using the credentials file
"""
function bq_auth()
    auth_path =joinpath(homedir(),".ercotmagic/nanocentury-credentials.json")
    if isfile(auth_path)
        run(`gcloud auth activate-service-account --key-file=$auth_path`)
    else
        println("Credentials file not found")
    end
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

# Example usage
df = DataFrame(text = ["Alice", "Bob"], embed = [rand(3), rand(3)])
send_to_bq_table(df, "ercot", "embtest")

# Upload a DataFrame
using CSV, DataFrames
import OstreaCultura as OC
tdat = CSV.read("data/climate_test.csv", DataFrame)
emb = OC.multi_embeddings(tdat)


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
function bq(query::String)
    tname = tempname()
    run(pipeline(`bq query --use_legacy_sql=false --format=csv $query`, tname))
    return CSV.read(tname, DataFrame)
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

