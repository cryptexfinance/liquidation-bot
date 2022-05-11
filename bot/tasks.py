import os

from bot.celery import app

from .monitor import Monitor

weth_vault_monitor = Monitor(
    os.environ["WETHVAULTTCAPADDRESS"],
    os.environ["NETWORK"]
)


@app.task()
def discover_eth_vaults():
    weth_vault_monitor.crawl()

@app.task()
def check_vaults_for_liquidation():
    weth_vault_monitor.check_vaults_for_liquidation()


@app.task()
def check_and_liquidate_eth_vault(vault_id):
    weth_vault_monitor.check_and_liquidate_vault(vault_id)
