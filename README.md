# Ercot Magic

A Julia package for accessing Ercot Data from their official API. See the docs [here](docspage.com).

Make sure all Ercot User and Password are stored in the environment variables `ERCOT_USER` and `ERCOT_PASSWORD` respectively. You will also need `ERCOT_KEY` which is the API key.

## TODO 
- [ ] Data Loading Functions should include actual and predicted load/gen across solar, wind, and total 
- [ ] Prediction Frame function: 
    - [ ] Generates a complete training frame for the model
     should take in a date and return the prediction frame for that date
- [ ] Add tests