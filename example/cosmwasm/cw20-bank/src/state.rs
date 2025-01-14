use cosmwasm_schema::cw_serde;
use cosmwasm_std::Addr;
use cw_storage_plus::{Item, Map};
use cosmwasm_std::Uint128;

#[cw_serde]
pub struct Config {
    pub owner: Addr,
    pub cw20_token_address: Addr,
}

pub const CONFIG: Item<Config> = Item::new("config");
pub const BALANCES: Map<&Addr, Uint128> = Map::new("balances");