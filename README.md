# Ercot Magic

A Julia package for accessing Ercot Data from their official API. See the docs [here](docspage.com).

Make sure all Ercot User and Password are stored in the environment variables `ERCOT_USER` and `ERCOT_PASSWORD` respectively. You will also need `ERCOT_KEY` which is the API key. You can get an API key by signing up [here](https://developer.ercot.com/applications/pubapi/user-guide/registration-and-authentication/).

## TODO 
- [X] Add API Key to the environment variables
- [X] Generate constants as URLS for the API
- [X] Data Loading Functions
    - [X] Actual Load
    - [X] Actual Generation
    - [X] Forecast Load
    - [X] Forecast Generation
    - [X] Wind Generation
    - [X] Solar Generation
    - [X] Total Generation
    - [X] Be able to fill in long stretches of time with batched calls to the API
- [X] SCED Data Loading Functions
    - [X] Update long-term data 
    - [X] Get minimum volumetric energy offer price
    - [ ] Parse Energy Only offers
    - [ ] Parse Ancillary Service offers
- [ ] Add tests
- [ ] Add Docker Support
- [ ] Launch Daily Data Update Image
- [ ] Add Documentation
- [ ] Add examples