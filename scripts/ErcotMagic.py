
import requests, json, os, sys
from dotenv import load_dotenv
### Get Token Id 
# POST request to this endpoint: https://ercotb2c.b2clogin.com/ercotb2c.onmicrosoft.com/B2C_1_PUBAPI-ROPC-FLOW/oauth2/v2.0/token
# with the following parameters:
##Key 	Value 	Description
#grant_type 	password 	
#username 		The username of the account registered in the API Explorer
#password 		The password of the account registered in the API Explorer
#response_type 	id_token 	
#scope 	openid+fec253ea-0d06-4272-a5e6-b478baeecd70+offline_access 	
#client_id 	fec253ea-0d06-4272-a5e6-b478baeecd70 	
"""
load_dotenv()
ercotpass = os.getenv("ERCOTPASS")
ercotuser = os.getenv("ERCOTUSER")
token = get_token_id(ercotuser, ercotpass)

should look like: https://ercotb2c.b2clogin.com/ercotb2c.onmicrosoft.com/B2C_1_PUBAPI-ROPC-FLOW/oauth2/v2.0/token?grant_type=password&username=stefan.j.wojcik@gmail.com&password=JUJ5qhx_hfq3rcf8rba&response_type=id_token&scope=openid+fec253ea-0d06-4272-a5e6-b478baeecd70+offline_access&client_id=fec253ea-0d06-4272-a5e6-b478baeecd70
"""
#returns an error that the scope parameter must include 'openid' when requesting a token
def get_token_id(username, password):
    url = "https://ercotb2c.b2clogin.com/ercotb2c.onmicrosoft.com/B2C_1_PUBAPI-ROPC-FLOW/oauth2/v2.0/token"
    payload = {
        "grant_type": "password",
        "username": username,
        "password": password,
        "response_type": "id_token",
        "scope": "openid+fec253ea-0d06-4272-a5e6-b478baeecd70+offline_access",
        "client_id": "fec253ea-0d06-4272-a5e6-b478baeecd70"
    }
    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    response = requests.request("POST", url, headers=headers, data=payload)
    return response.text