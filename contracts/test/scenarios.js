
const { expect } = require("chai");
const {isBigNumber} = require("hardhat/common");
const {uniq, shuffle} = require("lodash");
const { ethers, upgrades } = require('hardhat');
const { getImplementationAddress } = require('@openzeppelin/upgrades-core');
const axios = require("axios");
const { default: BigNumber } = require("bignumber.js");
const {
    setupSigners, getAdmin, deployWasm, WASM, createTokenFactoryTokenAndMint, deployErc20PointerForCw20
} = require("./lib");

describe("Scenarios", function () {
    let accounts;
    let admin;
    let cw20Address;
    let pointerAddr;
    let cw20Bank;
    before(async function () {
        accounts = await setupSigners(await hre.ethers.getSigners());
        admin = await getAdmin();

        // cw20
        cw20Address = await deployWasm(WASM.CW20, accounts[0].seiAddress, "cw20", {
            name: "Test",
            symbol: "TEST",
            decimals: 6,
            initial_balances: [
                { address: admin.seiAddress, amount: "1000000" },
                { address: accounts[0].seiAddress, amount: "2000000" },
                { address: accounts[1].seiAddress, amount: "3000000" }
            ],
            mint: {
                "minter": admin.seiAddress, "cap": "99900000000"
            }
        });

        // make pointer for cw20
        pointerAddr = await deployErc20PointerForCw20(hre.ethers.provider, cw20Address)

        // native token
        const random_num = Math.floor(Math.random() * 10000)
        denom = await createTokenFactoryTokenAndMint(`native-pointer-test-${random_num}`, 1000, accounts[0].seiAddress)

        // CW contract that owns the CW20 token
        cw20Bank = await deployWasm(WASM.CW20_BANK, accounts[0].seiAddress, "cw20-bank", {
            cw20_token_address: cw20Address
        });
    });

    it("placeholder", async function () {   
        console.log("cw20 address", cw20Address);
        console.log("native token address", denom);
        console.log("cw20 bank address", cw20Bank);
        console.log("cw20 pointer address", pointerAddr);
    });
});
