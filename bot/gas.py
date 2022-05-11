# {"status":"1","message":"OK","result":{
# "LastBlock":"14755604","SafeGasPrice":"123","ProposeGasPrice":"124","FastGasPrice":"124","suggestBaseFee":"122.604327854","gasUsedRatio":"0.11443261011044,0.40412721051873,0.2763288,0.0706858333333333,0.175580466666667"}}
import math

import requests
from brownie.network.gas.strategies import GasNowStrategy as _GasNowStrategy

from bot.conf import settings

etherscan_url = f"https://api.etherscan.io/api?module=gastracker&action=gasoracle&apikey={settings.ETHERSCAN_API_KEY}"


class GasNowStrategy(_GasNowStrategy):

    def __init__(self, speed: str = "FastGasPrice"):
        if speed not in (
          "SafeGasPrice", "ProposeGasPrice", "FastGasPrice"
        ):
            raise ValueError(
                "`speed` must be one of: "
                "SafeGasPrice, ProposeGasPrice, FastGasPrice"
            )
        self.speed = speed

    def get_gas_price(self):
        response = requests.get(etherscan_url)
        response.raise_for_status()
        data = response.json()["result"]
        return math.ceil(data[self.speed])
