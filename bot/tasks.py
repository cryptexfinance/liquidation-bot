from .celery import app
from .monitor import Monitor
from .model import VaultTypes
from .conf import settings

weth_vault_monitor = Monitor(
    settings.WETH_VAULT_TCAP_ADDRESS,
    VaultTypes.WETH,
    settings.NETWORK
)

wbtc_vault_monitor = Monitor(
    settings.WBTC_VAULT_TCAP_ADDRESS,
    VaultTypes.WBTC,
    settings.NETWORK
)

dai_vault_monitor = Monitor(
    settings.DAI_VAULT_TCAP_ADDRESS,
    VaultTypes.DAI,
    settings.NETWORK
)


usdc_vault_monitor = Monitor(
    settings.USDC_VAULT_TCAP_ADDRESS,
    VaultTypes.USDC,
    settings.NETWORK
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
