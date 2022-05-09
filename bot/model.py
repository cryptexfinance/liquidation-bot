import enum

from sqlalchemy import MetaData, Column, PrimaryKeyConstraint, create_engine
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session
from sqlalchemy.types import Integer, Enum
from sqlalchemy.ext.declarative import declarative_base

from .conf import settings

metadata = MetaData()
Base = declarative_base(metadata=metadata)
engine = create_engine(settings.DB_URL)


class VaultTypes(enum.Enum):
    WETH = 1
    WBTC = 2
    DAI = 3
    USDC = 4


class TCAPVaults(Base):
    __tablename__ = 'TcapVaults'

    id = Column(Integer, nullable=False)
    vault_type = Column(Enum(VaultTypes), nullable=False)
    vault_ratio = Column(Integer, nullable=False)

    __table_args__ = (
        PrimaryKeyConstraint(id, vault_type),
        {},
    )


def insert_or_update_vaults(id, vault_type, vault_ratio):
    insert_stmt = insert(TCAPVaults).values(
        id=id,
        vault_type=vault_type,
        vault_ratio=vault_ratio,
    ).on_conflict_do_update(
        index_elements=["id", "vault_type"],
        set_=dict(vault_ratio=vault_ratio)
    )
    with Session(engine) as session:
        session.execute(insert_stmt)
        session.commit()
