from pathlib import Path

from brownie.project import load
from brownie.network import connect, is_connected
from sqlalchemy.orm import Session

from bot.gas import GasNowStrategy
from bot.model import TCAPVaults, VaultTypes, insert_or_update_vaults, engine
from bot.tasks import check_and_liquidate_eth_vault
from bot.conf import settings
project = load(Path(__file__).parent.parent)
project.load_config()

liquidation_fn_by_vault_type = {
    VaultTypes.WETH: check_and_liquidate_eth_vault,
}

liquidation_swap_path = {
    VaultTypes.WETH: [],
    VaultTypes.WBTC: [settings.WBTCADDRESS, settings.WETHADDRESS],
    VaultTypes.DAI: [settings.DAIADDRESS, settings.WETHADDRESS],
    VaultTypes.USDC: [settings.USDCADDRESS, settings.WETHADDRESS],
}


class Monitor:
    
    def __init__(self, vault, vault_type, _network):
        if not is_connected():
            connect(_network)
        interface = project.interface
        self.vault = vault
        self.tcap_vault = interface.ITCAPVault(vault)
        self.vault_type = vault_type

    def crawl(self):
        no_vaults = self.tcap_vault.counter()[0]
        for vault_id in range(1, no_vaults):
            vault_ratio = self.tcap_vault.getVaultRatio(vault_id)
            insert_or_update_vaults(
                vault_id,
                self.vault_type,
                vault_ratio
            )

    def check_vaults_for_liquidation(self):
        with Session(engine) as session:
            query = session(TCAPVaults).filter(
                TCAPVaults.vault_type == self.vault_type,
                TCAPVaults.vault_ratio != 0
            ).order_by("vault_ratio")
            for vault in query:
                liquidation_fn_by_vault_type[self.vault_type].apply_async(
                    kwargs={"vault_id": vault.vault_id}
                )

    def check_and_liquidate_vault(self, vault_id):
        liquidation_contract = project.LiquidateVault.at(
            settings.LIQUIDATEVAULTADDRESS
        )
        gas_strategy = GasNowStrategy()
        path = [settings.WETHADDRESS, settings.TCAPADDRESS]
        swap_path = liquidation_swap_path[self.vault_type]
        is_profitable = liquidation_contract.isLiquidationProfitable(
            self.vault, vault_id, path, swap_path
        )
        if is_profitable:
            liquidation_contract.initiateFlashLoan(
                self.vault, vault_id, swap_path,
            )
