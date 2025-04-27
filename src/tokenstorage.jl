## Logic for dealing with token expiration and fetching a new token if necessary

# Global variable to store token and its timestamp
@kwdef mutable struct ErcotToken
    expires_in::String=""
    token_type::String=""
    refresh_token::String=""
    id_token::String=""
    access_token::String=""
    acquired_at::DateTime=Dates.now()
end

# Function to fetch new token (replace with your existing code)
function fetch_new_token()
    token = get_auth_token()
    token["acquired_at"] = Dates.now()
    token = Dict(Symbol(key) => value for (key, value) in token)
    return ErcotToken(; token...)
end

# Function to check token validity and get a valid token
function get_valid_token!()
    # Token is valid for 1 hour
    token_lifetime = Dates.Hour(1).value*60*60*1000

    # If no token has been stored yet or the token has expired, fetch a new one
    if ErcotMagic.ercot_token.id_token == "" || (Dates.now() - ErcotMagic.ercot_token.acquired_at).value > token_lifetime
        @info "Token expired or not found, fetching a new one."
        ErcotMagic.ercot_token = fetch_new_token()
    else
        #@info "Token is still valid."
    end

    # Return the valid token
    return ErcotMagic.ercot_token.id_token
end

# Usage

"""
# Call the function to get a valid token, which will fetch a new one if necessary
token = get_valid_token!()
println("Token: ", token)

# Simulate waiting for 30 minutes and checking again
println("Simulating 30 minutes later...")
Dates.now() += Dates.Minute(30)
token = get_valid_token!()
println("Token: ", token)

# Simulate waiting for 1.5 hours and checking again
println("Simulating 1.5 hours later...")
Dates.now() += Dates.Hour(1) + Dates.Minute(30)
token = get_valid_token!()
println("Token: ", token)
"""

global ercot_token = ErcotToken()