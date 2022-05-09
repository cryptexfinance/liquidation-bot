import os

from bot.celery import app

from .monitor import Monitor


@app.task()
def monitor_eth_vault():
    Monitor(
        os.environ["WETHVAULTTCAPADDRESS"],
        os.environ["NETWORK"]
    ).monitor()

