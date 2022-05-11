from celery import Celery

from .conf import settings

app = Celery('liquidation_bot')
app.conf.broker_url = settings.REDIS_URL

app.autodiscover_tasks([
    'bot.tasks'
])


app.conf.beat_schedule = {
    'bot.tasks.discover_eth_vaults': {
        'task': 'bot.tasks.discover_eth_vaults',
        'schedule': 60 * 60,  # 60 minutes
    },
    'bot.tasks.check_eth_vaults_for_liquidation': {
        'task': 'bot.tasks.check_eth_vaults_for_liquidation',
        'schedule': 15 * 60,
    },
    'bot.tasks.check_wbtc_vaults_for_liquidation': {
        'task': 'bot.tasks.check_wbtc_vaults_for_liquidation',
        'schedule': 15 * 60,
    },
    'bot.tasks.check_dai_vaults_for_liquidation': {
        'task': 'bot.tasks.check_dai_vaults_for_liquidation',
        'schedule': 15 * 60,
    },
    'bot.tasks.check_usdc_vaults_for_liquidation': {
        'task': 'bot.tasks.check_usdc_vaults_for_liquidation',
        'schedule': 15 * 60,
    },
}
