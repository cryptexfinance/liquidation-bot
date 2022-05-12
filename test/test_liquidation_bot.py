import pytest
from web3 import Web3

from brownie.project import get_loaded_projects

to_wei = Web3.toWei


@pytest.fixture()
def project():
    _pr = get_loaded_projects()[0]
    _pr.load_config()
    return _pr


@pytest.fixture()
def user(accounts):
    return accounts[1]


def setup_initial_prices(
        weth_aggregator,
        tcap_aggregator,
        tcap_price,
        eth_price,
        tcap_divisor,
        deployer_address
):
    weth_aggregator.setLatestAnswer(
        eth_price * 10 ** 8, {"from": deployer_address.address}
    )
    tcap_aggregator.setLatestAnswer(
        tcap_price * tcap_divisor * 10 ** 8, {"from": deployer_address.address}
    )


def setup_eth_vault_for_liquidation(weth_vault_handler, user):
    #  vault to liquidate
    weth_vault_handler.createVault({"from": user.address})
    tcap_to_mint = to_wei(30, "ether")
    weth_vault_handler.addCollateralETH(
        {
            "value": weth_vault_handler.requiredCollateral(tcap_to_mint) + 1,
            "from": user.address
        }
    )
    weth_vault_handler.mint(tcap_to_mint, {"from": user.address})


def setup_eth_tcap_exchange(
        weth_vault_handler,
        deployer_address,
        tcap_price,
        eth_price,
        tcap_divisor,
        tcap_aggregator,
        sushi_swap_factory,
        TCAP,
        WETH,
        project,
        sushi_swap_router
):
    # Exchange setup
    tcap_to_mint = to_wei(2000, "ether")
    weth_vault_handler.createVault({"from": deployer_address.address})
    required_collateral = weth_vault_handler.requiredCollateral(tcap_to_mint)
    weth_vault_handler.addCollateralETH(
        {"value": required_collateral + 1, "from": deployer_address.address}
    )
    weth_vault_handler.mint(tcap_to_mint, {"from": deployer_address.address})
    new_tcap_price = int(1.5 * tcap_price)
    tcap_aggregator.setLatestAnswer(
        new_tcap_price * tcap_divisor * 10 ** 8,
        {"from": deployer_address.address}
    )
    tx = sushi_swap_factory.createPair(
        TCAP.address, WETH.address,
        {"from": deployer_address.address}
    )
    pair = tx.events['PairCreated']['pair']
    sushi_swap_pair = project.interface.ISushiSwapPair(pair)
    eth_amount = (tcap_to_mint * new_tcap_price) / eth_price
    TCAP.approve(pair, 2 ** 256 - 1, {"from": deployer_address.address})
    TCAP.transfer(pair, tcap_to_mint, {"from": deployer_address.address})
    WETH.deposit(
        {"value": to_wei(1000, "ether"), "from": deployer_address.address}
    )
    WETH.approve(
        pair, 2 ** 256 - 1, {"from": deployer_address.address}
    )
    WETH.approve(
        sushi_swap_router.address, 2 ** 256 - 1,
        {"from": deployer_address.address}
    )
    WETH.transfer(
        pair, eth_amount, {"from": deployer_address.address}
    )
    sushi_swap_pair.mint(
        deployer_address.address,
        {"from": deployer_address.address}
    )


def test_liquidation_bot(
    weth_vault_handler,
    solo_margin,
    sushi_swap_router,
    sushi_swap_factory,
    tcap_aggregator,
    weth_aggregator,
    TCAP,
    WETH,
    liquidate_vault,
    deployer_address,
    user,
    project,
):
    eth_price = 1888
    tcap_price = 123
    tcap_divisor = 10000000000

    setup_initial_prices(
        weth_aggregator,
        tcap_aggregator,
        tcap_price,
        eth_price,
        tcap_divisor,
        deployer_address
    )

    setup_eth_vault_for_liquidation(weth_vault_handler, user)

    setup_eth_tcap_exchange(
        weth_vault_handler,
        deployer_address,
        tcap_price,
        eth_price,
        tcap_divisor,
        tcap_aggregator,
        sushi_swap_factory,
        TCAP,
        WETH,
        project,
        sushi_swap_router
    )

