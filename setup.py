#!/usr/bin/env python
from setuptools import (
    find_packages,
    setup,
)

extras_require = {
    'linter': [
        "flake8==3.8.3",
        "isort>=4.2.15,<4.3.5",
        "mypy==0.910",
    ],
    'dev': [
        "pytest>=6.2.5,<7",
    ]
}

extras_require['dev'] = (
    + extras_require['linter']
    + extras_require['dev']
)


setup(
    name='liquidation-bot',
    version='0.0.1',
    description="""Liquidation bot for $TCAP""",
    long_description_content_type='text/markdown',
    long_description="""
        $TCAP Liquidation Bot by Cryptex.Finance
    """,
    author='Cryptex.Finance',
    author_email='voith@cryptex.finance',
    url='https://github.com/cryptexfinance/liquidation-bot',
    include_package_data=True,
    install_requires=[
        "alembic",
        "eth-brownie>=1.18.1,<2.0",
        "celery>=5.2.6,<6.0.0",
        "celery-redbeat>=2.0.0,<3.0.0",
        "psycopg2",
        "python-dotenv>=0.16.0,<1.0.0",
        "redis>=4.3.1,<5.0.0",
        "SQLAlchemy>=1.4.36,<2.0.0",
    ],
    python_requires='>=3.8,<3.11',
    extras_require=extras_require,
    py_modules=['liquidation_bot'],
    license="MIT",
    zip_safe=False,
    keywords='ethereum',
    packages=find_packages(exclude=["tests", "tests.*"]),
    package_data={"web3": ["py.typed"]},
    classifiers=[
        'Natural Language :: English',
        'Programming Language :: Python :: 3.8',
    ],
)
