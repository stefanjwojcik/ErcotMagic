# Install the required package
#using Pkg
#Pkg.add("AWSS3")

# Import the package
using AWSS3

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