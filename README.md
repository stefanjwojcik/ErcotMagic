# Ercot Magic

A Julia package for accessing Ercot Data from their official API. See the docs [here](https://developer.ercot.com/applications/pubapi/user-guide/openapi-documentation/).

Make sure all Ercot User and Password are stored in the environment variables `ERCOT_USER` and `ERCOT_PASSWORD` respectively. You will also need `ERCOT_KEY` which is the API key. You can get an API key by signing up [here](https://developer.ercot.com/applications/pubapi/user-guide/registration-and-authentication/).

OpenAPI spec is located here: "https://raw.githubusercontent.com/ercot/api-specs/refs/heads/main/pubapi/pubapi-apim-api.json"

## Notes on the API and Data
According to the forums, pricing data for current products is only available starting from mid December 2023. It is challenging to retrieve data any earlier than that. 

Mapping from units to node points is provided here: https://www.ercot.com/mp/data-products/data-product-details?id=NP4-160-SG

## Main Development Items  
- [X] Add API Key to the environment variables
- [X] Parse Open API Spec and extract parameters, summaries
- [X] Generate annotations of URLs for easier access
- [X] Generate EndPoint constants within the package containing (endpoint, summary, parameters, datekey)
- [X] Integrate EndPoint constants into get_ercot_data logic
- [X] Merge changes to token-saving into main branch 

### Loading Data
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


- [ ] API Features 
    - [ ] Get the latest data available for a given date
    - [ ] Sceddy - A tool to determine the optimal energy offer price for a given day
    - [ ] Stack - Generates an expected price curve for a given day based on historical data and net load for the coming day 
    - [ ] Proxy - Generates spreads of DART for a given day based on historical proxy data (net load, generation, outages, etc)
    - [ ] Replay - Training data for a BESS RL model (for renewable-tied resources, includes solar output)
    - [ ] Congest - Generates congestion prices for a given forward day based on historical data


## Other Things to do
- [ ] Add tests
- [ ] Add Docker Support
- [ ] Launch Daily Data Update Image
- [ ] Add Documentation
- [ ] Add examples

### Backlog/Not Important
- [X] BigQuery Dynamic Loading (bq.jl)
    - [ ] Generate tables containing constituent data  (e.g. wind, solar, etc) 
    - [ ] Generate tables for each API endpoint 
    - [ ] Determine the latest date available (if any)
    - [ ] Load Data with a specific date range
    - [ ] Set up Cron Job to update data daily
