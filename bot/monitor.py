from pathlib import Path

from brownie.project import load
from brownie.network import connect, is_connected

from bot.model import insert_or_update_vaults

project = load(Path(__file__).parent.parent)
project.load_config()


class Monitor:
    
    def __init__(self, vault, vault_type, _network):
        if not is_connected():
            connect(_network)
        interface = project.interface
        self.tcap_vault = interface.ITCAPVault(vault)
        self.vault_type = vault_type

    def crawl(self):
        no_vaults = self.tcap_vault.counter()[0]
        for vault_id in range(1, no_vaults):
            vault_ratio = self.tcap_vault.getVaultRatio(vault_id)
            print(
                vault_id,
                self.vault_type,
                vault_ratio
            )
            insert_or_update_vaults(
                vault_id,
                self.vault_type,
                vault_ratio
            )
