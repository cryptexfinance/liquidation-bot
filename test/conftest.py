import json
import re
from pathlib import Path

import pytest
from brownie import Contract, project

TEST_BUILD_DIR = Path("test/build")


@pytest.fixture()
def deployer_address(accounts):
    for account in accounts[2:]:
        balance = account.balance()
        account.transfer(accounts[0], balance, gas_price=0)
    return accounts[0]


def deploy(
        web3,
        contract_name,
        contructor_args,
        _deployer_address,
        build_path,
        libraries=None
) -> Contract:
    with open(build_path) as f:
        build = json.loads(f.read())
    abi = build["abi"]
    bytecode = build["bytecode"]
    if libraries:
        for marker in re.findall("_{1,}[^_]*_{1,}", bytecode):
            library = marker.strip("_")
            address = libraries[library].address[-40:]
            bytecode = bytecode.replace(marker, address)
    tx_hash = web3.eth.contract(
        abi=abi, bytecode=bytecode
    ).constructor(*contructor_args).transact(
        {"from": _deployer_address.address}
    )
    receipt = web3.eth.get_transaction_receipt(tx_hash)
    return Contract.from_abi(
        name=contract_name,
        address=receipt.contractAddress,
        abi=abi
    )


@pytest.fixture()
def WETH(web3, deployer_address):
    return deploy(
        web3,
        "WETH",
        (),
        deployer_address,
        TEST_BUILD_DIR / "WETH.json",
    )


@pytest.fixture()
def orchestrator(web3, deployer_address):
    return deploy(
        web3,
        "Orchestrator",
        (deployer_address.address,),
        deployer_address,
        TEST_BUILD_DIR / "Orchestrator.json"
    )


@pytest.fixture()
def TCAP(web3, deployer_address, orchestrator):
    return deploy(
        web3,
        "TCAP",
        ("TCAP", "TCAP", 0, orchestrator.address),
        deployer_address,
        TEST_BUILD_DIR / "TCAP.json"
    )


@pytest.fixture()
def weth_aggregator(web3, deployer_address):
    return deploy(
        web3,
        "WETHInterface",
        (),
        deployer_address,
        TEST_BUILD_DIR / "AggreagtorInterface.json"
    )


@pytest.fixture()
def tcap_aggregator(web3, deployer_address):
    return deploy(
        web3,
        "TCAPInterface",
        (),
        deployer_address,
        TEST_BUILD_DIR / "AggreagtorInterface.json"
    )


@pytest.fixture()
def weth_oracle(web3, deployer_address, weth_aggregator, orchestrator):
    return deploy(
        web3,
        "WETHOracle",
        (weth_aggregator.address, orchestrator.address),
        deployer_address,
        TEST_BUILD_DIR / "Oracle.json"
    )


@pytest.fixture()
def tcap_oracle(web3, deployer_address, tcap_aggregator, orchestrator):
    return deploy(
        web3,
        "TCAPOracle",
        (tcap_aggregator.address, orchestrator.address),
        deployer_address,
        TEST_BUILD_DIR / "Oracle.json"
    )


@pytest.fixture()
def weth_vault_handler(
        web3,
        deployer_address,
        weth_oracle,
        tcap_oracle,
        orchestrator,
        WETH,
        TCAP
):
    weth_vault = deploy(
        web3,
        "WETHVaultHandler",
        (
            orchestrator.address,
            10000000000,
            150,
            0,
            10,
            tcap_oracle.address,
            TCAP.address,
            WETH.address,
            weth_oracle.address,
            weth_oracle.address,
            deployer_address.address,
            20000000000000000000
        ),
        deployer_address,
        TEST_BUILD_DIR / "VaultHandler.json"
    )
    orchestrator.addTCAPVault(
        TCAP.address, weth_vault.address, {"from": deployer_address.address}
    )
    return weth_vault


@pytest.fixture()
def solo_margin(web3, deployer_address, WETH):
    _project = project.get_loaded_projects()[0]
    return _project.MockSoloMargin.deploy(
        WETH.address,
        {"from": deployer_address}
    )


@pytest.fixture()
def sushi_swap_factory(web3, deployer_address):
    return deploy(
        web3,
        "SushiSwapFactory",
        (deployer_address.address, ),
        deployer_address,
        TEST_BUILD_DIR / "SushiSwapFactory.json"
    )


@pytest.fixture()
def sushi_swap_router(web3, deployer_address, sushi_swap_factory, WETH):
    return deploy(
        web3,
        "SushiSwapRouter",
        (sushi_swap_factory.address, WETH.address),
        deployer_address,
        TEST_BUILD_DIR / "SushiSwapRouter02.json"
    )


@pytest.fixture()
def liquidate_vault(
        deployer_address, WETH, TCAP, solo_margin, sushi_swap_router
):
    _project = project.get_loaded_projects()[0]
    return _project.LiquidateVault.deploy(
        WETH.address,
        TCAP.address,
        solo_margin.address,
        sushi_swap_router.address,
        {"from": deployer_address.address}
    )


@pytest.fixture(autouse=True)
def override_settings(WETH, TCAP, weth_vault_handler, liquidate_vault):
    from bot.conf import os
    os.environ["WETH_ADDRESS"] = WETH.address
    os.environ["TCAP_ADDRESS"] = TCAP.address
    os.environ["WETH_VAULT_TCAP_ADDRESS"] = weth_vault_handler.address
    os.environ["WBTC_VAULT_TCAP_ADDRESS"] = weth_vault_handler.address
    os.environ["DAI_VAULT_TCAP_ADDRESS"] = weth_vault_handler.address
    os.environ["USDC_VAULT_TCAP_ADDRESS"] = weth_vault_handler.address
    os.environ["LIQUIDATE_VAULT_ADDRESS"] = liquidate_vault.address


@pytest.fixture(autouse=True)
def celery_eager_mode(override_settings):
    from bot.celery import app
    app.conf.task_always_eager = True
