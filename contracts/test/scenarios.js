const { expect } = require("chai");
const {isBigNumber} = require("hardhat/common");
const {uniq, shuffle} = require("lodash");
const { ethers, upgrades } = require('hardhat');
const { getImplementationAddress } = require('@openzeppelin/upgrades-core');
const axios = require("axios");
const { default: BigNumber } = require("bignumber.js");
const {
    setupSigners, getAdmin, deployWasm, WASM, createTokenFactoryTokenAndMint, deployErc20PointerForCw20, queryWasm, createSeiOnlyAccount, executeWasm
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

describe("CW20 Token No Pointer Scenarios", function () {
    let accounts;
    let admin;
    let cw20Token;
    let bankContract;

    before(async function () {
        accounts = await setupSigners(await hre.ethers.getSigners());
        admin = await getAdmin();

        // Deploy base CW20 token for testing
        cw20Token = await deployWasm(WASM.CW20, admin.seiAddress, "cw20-base", {
            name: "Test Token",
            symbol: "TEST",
            decimals: 6,
            initial_balances: [
                { address: admin.seiAddress, amount: "1000000" }
            ],
            mint: {
                minter: admin.seiAddress,
                cap: "99900000000"
            }
        });
        
        // Deploy bank contract for type 4 testing
        bankContract = await deployWasm(WASM.CW20_BANK, admin.seiAddress, "bank-contract", {
            cw20_token_address: cw20Token
        });
    });

    describe("Owner Types", function() {
        it("type 1: should handle Sei address with association", async function() {
            const assocToken = await deployWasm(WASM.CW20, accounts[1].seiAddress, "cw20-assoc", {
                name: "Associated Token",
                symbol: "ASSOC",
                decimals: 6,
                initial_balances: [
                    { address: accounts[1].seiAddress, amount: "1000000" }
                ]
            });
            
            const balance = await queryWasm(assocToken, "balance", {
                address: accounts[1].seiAddress
            });
            expect(balance.data.balance).to.equal("1000000");
        });

        it("type 2: should handle Sei address without association", async function() {
            const {keyName, seiAddress} = await createSeiOnlyAccount();          
            
            const nonAssocToken = await deployWasm(WASM.CW20, seiAddress, "cw20-non-assoc", {
                name: "Non-Associated Token",
                symbol: "NAT",
                decimals: 6,
                initial_balances: [
                    { address: seiAddress, amount: "1000000" }
                ]
            }, keyName);
            
            const balance = await queryWasm(nonAssocToken, "balance", {
                address: seiAddress
            });
            expect(balance.data.balance).to.equal("1000000");
        });

        it("type 3: should handle CW20 token as owner", async function() {
            const ownerToken = await deployWasm(WASM.CW20, admin.seiAddress, "owner-token", {
                name: "Owner Token",
                symbol: "OWNER",
                decimals: 6,
                initial_balances: [
                    { address: admin.seiAddress, amount: "1000000" }
                ]
            });

            const ownedToken = await deployWasm(WASM.CW20, admin.seiAddress, "owned-token", {
                name: "Owned Token",
                symbol: "OWNED",
                decimals: 6,
                initial_balances: [
                    { address: admin.seiAddress, amount: "1000000" }
                ],
                mint: {
                    minter: ownerToken,
                    cap: "99900000000"
                }
            });

            const minterInfo = await queryWasm(ownedToken, "minter", {});
            expect(minterInfo.data.minter).to.equal(ownerToken);
        });

        it("type 4: should handle non-CW20 contract as owner", async function() {
            const bankOwnedToken = await deployWasm(WASM.CW20, admin.seiAddress, "bank-owned-token", {
                name: "Bank Owned Token",
                symbol: "BANK",
                decimals: 6,
                initial_balances: [
                    { address: admin.seiAddress, amount: "1000000" }
                ]
            });

            await executeWasm(bankOwnedToken, {
                transfer: {
                    recipient: bankContract,
                    amount: "1000000"
                }
            });

            const balance = await queryWasm(bankOwnedToken, "balance", {
                address: bankContract
            });
            expect(balance.data.balance).to.equal("1000000");
        });
    });
});
