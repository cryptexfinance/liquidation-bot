from celery import Celery

from .conf import settings

app = Celery('liquidation_bot')
app.conf.broker_url = settings.REDIS_URL

app.autodiscover_tasks([
    'bot.tasks'
])


app.conf.beat_schedule = {
    'bot.tasks.monitor_eth_vault': {
        'task': 'bot.tasks.monitor_eth_vault',
        'schedule': 15.0,
    },
}
