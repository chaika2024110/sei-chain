
const { expect } = require("chai");
const {isBigNumber} = require("hardhat/common");
const {uniq, shuffle} = require("lodash");
const { ethers, upgrades } = require('hardhat');
const { getImplementationAddress } = require('@openzeppelin/upgrades-core');
const axios = require("axios");
const { default: BigNumber } = require("bignumber.js");
const {
    setupSigners, getAdmin, deployWasm, WASM, createTokenFactoryTokenAndMint
} = require("./lib");

describe("Scenarios", function () {
    let accounts;
    let admin;
    let cw20Address;

    before(async function () {
        accounts = await setupSigners(await hre.ethers.getSigners());
        admin = await getAdmin();

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

        // native token
        const random_num = Math.floor(Math.random() * 10000)
        denom = await createTokenFactoryTokenAndMint(`native-pointer-test-${random_num}`, 1000, accounts[0].seiAddress)

        // CW contract that owns the CW20 token
    });

    it("placeholder", async function () {   
        console.log("cw20 address", cw20Address);
        console.log("native token address", denom);
    });
});
