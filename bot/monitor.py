from pathlib import Path

from brownie.project import load, get_loaded_projects
from brownie.network import connect, is_connected
from sqlalchemy.orm import Session

from bot.gas import GasNowStrategy
from bot.model import TCAPVaults, VaultTypes, insert_or_update_vaults, engine
from bot.conf import settings

projects = get_loaded_projects()

if not projects:
    project = load(Path(__file__).parent.parent)
    project.load_config()
else:
    project = projects[0]
    assert project._name == "LiquidationBotProject", "incorrect project loaded"


class Monitor:
    
    def __init__(self, vault, vault_type, _network):
        from .tasks import check_and_liquidate_eth_vault
        if not is_connected():
            connect(_network)
        interface = project.interface
        self.vault = vault
        self.tcap_vault = interface.ITCAPVault(vault)
        self.vault_type = vault_type
        self.liquidation_fn_by_vault_type = {
            VaultTypes.WETH: check_and_liquidate_eth_vault,
        }

        self.liquidation_swap_path = {
            VaultTypes.WETH: [],
            VaultTypes.WBTC: [settings.WBTCADDRESS, settings.WETHADDRESS],
            VaultTypes.DAI: [settings.DAIADDRESS, settings.WETHADDRESS],
            VaultTypes.USDC: [settings.USDCADDRESS, settings.WETHADDRESS],
        }

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
                self.liquidation_fn_by_vault_type[self.vault_type].apply_async(
                    kwargs={"vault_id": vault.vault_id}
                )

    def check_and_liquidate_vault(self, vault_id):
        liquidation_contract = project.LiquidateVault.at(
            settings.LIQUIDATEVAULTADDRESS
        )
        gas_strategy = GasNowStrategy()
        path = [settings.WETHADDRESS, settings.TCAPADDRESS]
        swap_path = self.liquidation_swap_path[self.vault_type]
        is_profitable = liquidation_contract.isLiquidationProfitable(
            self.vault, vault_id, path, swap_path
        )
        if is_profitable:
            liquidation_contract.initiateFlashLoan(
                self.vault, vault_id, swap_path,
            )
