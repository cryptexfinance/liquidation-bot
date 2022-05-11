# TCAP Liquidation Bot

## Instructions for setting up.
The project used python >= 3.8

In a virtual env install the project requirements
```bash
$ pip install -e .
```

Create a `.env` file using  `.env.sample` and fill up the lsi of environment variables.
The project uses postgres and redis. The env vars for these can be found in the `.env.sample` file. 

To compile the contracts run:
```bash
$ brownie compile
```

The project uses celery to run tasks asynchronously and celery-beat for scheduling tasks.

To run the celery worker:
```bash
$ celery -A bot beat -l info
```

To deploy the liquidation contract:
```bash
brownie run deploy.py --network mainnet
```

To run the celery scheduler
``` bash
$ celery -A bot beat -l info
```

## Instructions for testing

The project has been built using foundry.
To install foundry:
```bash
$ curl -L https://foundry.paradigm.xyz | bash
$ foundryup
```
Install forge std library
```bash
$ forge install foundry-rs/forge-std
```

Install openzeppelin
```bash
$ forge install openzeppelin/openzeppelin-contracts
```
## Run tests
Tests use forge
```bash
$ forge test --fork-url YOUR_Kovan_RPC_URL
```
