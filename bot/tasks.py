import os

from .celery import app
from .monitor import Monitor
from .model import VaultTypes


weth_vault_monitor = Monitor(
    os.environ["WETH_VAULT_TCAP_ADDRESS"],
    VaultTypes.WETH,
    os.environ["NETWORK"]
)

wbtc_vault_monitor = Monitor(
    os.environ["WBTC_VAULT_TCAP_ADDRESS"],
    VaultTypes.WBTC,
    os.environ["NETWORK"]
)

dai_vault_monitor = Monitor(
    os.environ["DAI_VAULT_TCAP_ADDRESS"],
    VaultTypes.DAI,
    os.environ["NETWORK"]
)


usdc_vault_monitor = Monitor(
    os.environ["USDC_VAULT_TCAP_ADDRESS"],
    VaultTypes.USDC,
    os.environ["NETWORK"]
)


@app.task()
def discover_eth_vaults():
    weth_vault_monitor.crawl()


@app.task()
def check_eth_vaults_for_liquidation():
    weth_vault_monitor.check_vaults_for_liquidation()


@app.task()
def check_and_liquidate_eth_vault(vault_id):
    weth_vault_monitor.check_and_liquidate_vault(vault_id)


@app.task()
def check_wbtc_vaults_for_liquidation():
    wbtc_vault_monitor.check_vaults_for_liquidation()


@app.task()
def check_and_liquidate_wbtc_vault(vault_id):
    wbtc_vault_monitor.check_and_liquidate_vault(vault_id)


@app.task()
def check_dai_vaults_for_liquidation():
    dai_vault_monitor.check_vaults_for_liquidation()


@app.task()
def check_and_liquidate_dai_vault(vault_id):
    dai_vault_monitor.check_and_liquidate_vault(vault_id)


@app.task()
def check_usdc_vaults_for_liquidation():
    usdc_vault_monitor.check_vaults_for_liquidation()


@app.task()
def check_and_liquidate_usdc_vault(vault_id):
    usdc_vault_monitor.check_and_liquidate_vault(vault_id)
