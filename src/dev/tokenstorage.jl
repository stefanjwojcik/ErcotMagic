## Logic for dealing with token expiration and fetching a new token if necessary
## Idea is to reduce overhead by not fetching a new token every time

# Global variable to store token and its timestamp
@kwdef mutable struct TokenStorage
    refresh_token::String
    id_token::String
    access_token::String
    token_type::String
    acquired_at::DateTime
end

# Function to fetch new token (replace with your existing code)
function fetch_new_token()
    token = get_auth_token()
    token["acquired_at"] = Dates.now()
    return TokenStorage(token...)
end

# Function to check token validity and get a valid token
function get_valid_token!(token_storage::Ref{TokenStorage})
    # Token is valid for 1 hour
    token_lifetime = Dates.Hour(1)

    # If no token has been stored yet or the token has expired, fetch a new one
    if token_storage[] === nothing || (Dates.now() - token_storage[].acquired_at) > token_lifetime
        println("Token expired or not found, fetching a new one.")
        new_token = fetch_new_token()
        token_storage[] = TokenStorage(new_token, Dates.now())
    else
        println("Token is still valid.")
    end

    # Return the valid token
    return token_storage[].token
end

# Usage

# Initially, the token storage is empty (use `nothing`)
token_storage = Ref{TokenStorage}(nothing)

# Call the function to get a valid token, which will fetch a new one if necessary
token = get_valid_token!(token_storage)
println("Token: ", token)

# Simulate waiting for 30 minutes and checking again
println("Simulating 30 minutes later...")
Dates.now() += Dates.Minute(30)
token = get_valid_token!(token_storage)
println("Token: ", token)

# Simulate waiting for 1.5 hours and checking again
println("Simulating 1.5 hours later...")
Dates.now() += Dates.Hour(1) + Dates.Minute(30)
token = get_valid_token!(token_storage)
println("Token: ", token)
