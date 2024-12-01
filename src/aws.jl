## AWS S3 Functions

"""
## Function to get the files in the "ercotmagic" bucket
"""
function awsfiles(bucket::String="ercotmagic")
    path = S3Path("s3://$bucket")
    return readdir(path)
end

"""
## Function to parse datetimes, if any, in the filename

parse_date_from_filename("data_2024-02-01.csv")

parse_date_from_filename("data_2024-02-01T20:37:12.csv")
"""
function parse_date_from_filename(filename::String)
    date_regex = r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})"
    dmatch = match(date_regex, filename)
    if !isnothing(dmatch)
        return DateTime(dmatch.match)
    else
        return nothing
    end
end

"""
# Function to upload a CSV file to an S3 bucket
 # example dataframe 
using CSV
using DataFrames
df = DataFrame(A = 1:4, B = ["M", "F", "F", "M"])
CSV.write("data.csv", df) 
upload_csv_to_s3("ercotmagic", "data.csv", "data.csv")

"""
function upload_csv_to_s3(bucket::String, file_path::String, s3_key::String)
    # Read the CSV file
    file = open(file_path, "r")
    content = read(file, String)
    close(file)
    
    # Upload the file to S3
    AWSS3.s3_put(bucket, s3_key, content)
    println("File uploaded successfully to $bucket/$s3_key")
end

"""
# Function to download a CSV file from an S3 bucket
download_csv_from_s3("ercotmagic", "data.csv", "data.csv")
"""
function download_csv_from_s3(bucket::String, s3_key::String, download_path::String)
    # Download the file from S3
    try
        content = AWSS3.s3_get(bucket, s3_key)
    catch e
        return DataFrame()
    end
    
    # Save the file locally
    file = open(download_path, "w")
    write(file, content)
    close(file)
    println("File downloaded successfully to $download_path")
    return CSV.read(download_path, DataFrame)
end

# Example usage
# upload_csv_to_s3("my-bucket", "path/to/local/file.csv", "s3-key.csv")
# download_csv_from_s3("my-bucket", "s3-key.csv", "path/to/download/file.csv")