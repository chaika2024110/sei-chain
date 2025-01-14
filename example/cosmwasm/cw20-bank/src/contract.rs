#[cfg(not(feature = "library"))]
use cosmwasm_std::entry_point;
use cosmwasm_std::{
    to_json_binary, Binary, Deps, DepsMut, Env, MessageInfo, Response, StdResult, Uint128,
    WasmMsg, CosmosMsg,
};
use cw2::set_contract_version;
use cw20::{Cw20ExecuteMsg, Cw20ReceiveMsg};

use crate::error::ContractError;
use crate::msg::{ExecuteMsg, InstantiateMsg, QueryMsg, BalanceResponse};
use crate::state::{BALANCES, Config, CONFIG};

// Version info for migration
const CONTRACT_NAME: &str = "crates.io:cw20-bank";
const CONTRACT_VERSION: &str = env!("CARGO_PKG_VERSION");

#[cfg_attr(not(feature = "library"), entry_point)]
pub fn instantiate(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
    msg: InstantiateMsg,
) -> Result<Response, ContractError> {
    set_contract_version(deps.storage, CONTRACT_NAME, CONTRACT_VERSION)?;

    let config = Config {
        owner: info.sender.clone(),
        cw20_token_address: deps.api.addr_validate(&msg.cw20_token_address)?,
    };
    CONFIG.save(deps.storage, &config)?;

    Ok(Response::new()
        .add_attribute("method", "instantiate")
        .add_attribute("owner", info.sender)
        .add_attribute("cw20_token_address", msg.cw20_token_address))
}

#[cfg_attr(not(feature = "library"), entry_point)]
pub fn execute(
    deps: DepsMut,
    env: Env,
    info: MessageInfo,
    msg: ExecuteMsg,
) -> Result<Response, ContractError> {
    match msg {
        ExecuteMsg::Receive(msg) => execute_receive(deps, env, info, msg),
        ExecuteMsg::Withdraw { amount } => execute_withdraw(deps, env, info, amount),
    }
}

pub fn execute_receive(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
    wrapped: Cw20ReceiveMsg,
) -> Result<Response, ContractError> {
    let config = CONFIG.load(deps.storage)?;
    if info.sender != config.cw20_token_address {
        return Err(ContractError::Unauthorized {});
    }

    let sender = deps.api.addr_validate(&wrapped.sender)?;
    BALANCES.update(
        deps.storage,
        &sender,
        |balance: Option<Uint128>| -> StdResult<_> {
            Ok(balance.unwrap_or_default() + wrapped.amount)
        },
    )?;

    Ok(Response::new()
        .add_attribute("method", "receive")
        .add_attribute("sender", wrapped.sender)
        .add_attribute("amount", wrapped.amount))
}

pub fn execute_withdraw(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
    amount: Uint128,
) -> Result<Response, ContractError> {
    let balance = BALANCES
        .load(deps.storage, &info.sender)
        .unwrap_or_default();
    if balance < amount {
        return Err(ContractError::InsufficientFunds {});
    }

    BALANCES.save(
        deps.storage,
        &info.sender,
        &(balance - amount),
    )?;

    let config = CONFIG.load(deps.storage)?;
    let transfer_msg = Cw20ExecuteMsg::Transfer {
        recipient: info.sender.to_string(),
        amount,
    };
    let msg = CosmosMsg::Wasm(WasmMsg::Execute {
        contract_addr: config.cw20_token_address.to_string(),
        msg: to_json_binary(&transfer_msg)?,
        funds: vec![],
    });

    Ok(Response::new()
        .add_message(msg)
        .add_attribute("method", "withdraw")
        .add_attribute("recipient", info.sender)
        .add_attribute("amount", amount))
}

#[cfg_attr(not(feature = "library"), entry_point)]
pub fn query(deps: Deps, _env: Env, msg: QueryMsg) -> StdResult<Binary> {
    match msg {
        QueryMsg::Balance { address } => {
            let address = deps.api.addr_validate(&address)?;
            let balance = BALANCES.load(deps.storage, &address).unwrap_or_default();
            to_json_binary(&BalanceResponse { balance })
        }
    }
}