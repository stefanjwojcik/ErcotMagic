# Ercot Magic

A Julia package for accessing Ercot Data from their official API. See the docs [here](docspage.com).

Make sure all Ercot User and Password are stored in the environment variables `ERCOT_USER` and `ERCOT_PASSWORD` respectively. You will also need `ERCOT_KEY` which is the API key. You can get an API key by signing up [here](https://developer.ercot.com/applications/pubapi/user-guide/registration-and-authentication/).

## Notes on the API and Data
According to the forums, pricing data for current products is only available starting from mid December 2023. It is challenging to retrieve data any earlier than that. 

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
- [X] BigQuery Dynamic Loading 
    - [] Generate tables for each endpoint 
    - [] Determine the latest date available (if any)
    - [] Load Data with a specific date range
    - [] Set up Cron Job to update data daily

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