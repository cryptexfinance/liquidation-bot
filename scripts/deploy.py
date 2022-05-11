from brownie import accounts
from brownie.project import get_loaded_projects

from bot.conf import settings


def main():
    project = get_loaded_projects()[0]
    acct = accounts.add(settings.DEPLOYER_PRIVATE_KEY)
    project.LiquidateVault.deploy(
        settings.WETH_ADDRESS,
        settings.TCAP_ADDRESS,
        settings.SOLO_MARGIN_ADDRESS,
        settings.SUSHISWAP_ROUTER_ADDRESS,
        {"from": acct}
    )
