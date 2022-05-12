from pathlib import Path

from brownie.project import load, get_loaded_projects
from brownie.network import connect, is_connected
from sqlalchemy.orm import Session
from sqlalchemy import and_

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
    
    def __init__(self, vault, vault_type, _network, minimum_ratio=150):
        if not is_connected():
            connect(_network)
        interface = project.interface
        self.vault = vault
        self.tcap_vault = interface.ITCAPVault(vault)
        self.vault_type = vault_type
        self.minimum_ratio = minimum_ratio

        self.liquidation_swap_path = {
            VaultTypes.WETH: [],
            VaultTypes.WBTC: [settings.WBTC_ADDRESS, settings.WETH_ADDRESS],
            VaultTypes.DAI: [settings.DAI_ADDRESS, settings.WETH_ADDRESS],
            VaultTypes.USDC: [settings.USDC_ADDRESS, settings.WETH_ADDRESS],
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
        from .tasks import check_and_liquidate_eth_vault
        liquidation_fn_by_vault_type = {
            VaultTypes.WETH: check_and_liquidate_eth_vault,
        }
        with Session(engine) as session:
            query = session.query(TCAPVaults).filter(
                TCAPVaults.vault_type == self.vault_type,
                and_(
                    TCAPVaults.vault_ratio > 0,
                    TCAPVaults.vault_ratio < self.minimum_ratio
                )
            ).order_by("vault_ratio")
            for vault in query:
                liquidation_fn_by_vault_type[self.vault_type].apply_async(
                    kwargs={"vault_id": vault.id}
                )

    def check_and_liquidate_vault(self, vault_id):
        liquidation_contract = project.LiquidateVault.at(
            settings.LIQUIDATE_VAULT_ADDRESS
        )
        path = [settings.WETH_ADDRESS, settings.TCAP_ADDRESS]
        swap_path = self.liquidation_swap_path[self.vault_type]
        is_profitable = liquidation_contract.isLiquidationProfitable(
            self.vault, vault_id, path, swap_path
        )
        if is_profitable:
            liquidation_contract.initiateFlashLoan(
                self.vault, vault_id, swap_path,
            )
