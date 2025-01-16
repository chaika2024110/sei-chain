const { expect } = require("chai");
const {
    setupSigners, getAdmin, deployWasm, WASM, deployErc20PointerForCw20, queryWasm, createSeiOnlyAccount, executeWasm, ABI
} = require("./lib");

describe("Scenarios", function () {
    let accounts;
    let admin;
    let cw20Token;
    let pointerAddr;
    let bankContractAddr;
    let pointer;
    let unassociatedEvmAddr = "0x8d6df9Bb1B36AB127B7f3C43E020224b2872aC76"

    before(async function () {
        accounts = await setupSigners(await hre.ethers.getSigners());
        admin = await getAdmin();

        // Deploy base CW20 token for testing
        cw20Token = await deployWasm(WASM.CW20, admin.seiAddress, "cw20-base", {
            name: "Test Token",
            symbol: "TEST",
            decimals: 6,
            initial_balances: [
                { address: admin.seiAddress, amount: "1000000" },
                { address: accounts[0].seiAddress, amount: "1000000" },
            ],
            mint: {
                minter: admin.seiAddress,
                cap: "99900000000"
            }
        });

        // Pointer for cw20 token
        pointerAddr = await deployErc20PointerForCw20(hre.ethers.provider, cw20Token);
        const contract = new hre.ethers.Contract(pointerAddr, ABI.ERC20, hre.ethers.provider);
        pointer = contract.connect(accounts[0].signer)
        
        // Deploy bank contract for type 4 testing
        bankContractAddr = await deployWasm(WASM.CW20_BANK, admin.seiAddress, "bank-contract", {
            cw20_token_address: cw20Token
        });
    });

    describe("CW20 Token No Pointer Scenarios", function() {
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
                    recipient: bankContractAddr,
                    amount: "1000000"
                }
            });

            const balance = await queryWasm(bankOwnedToken, "balance", {
                address: bankContractAddr
            });
            expect(balance.data.balance).to.equal("1000000");
        });
    });

    describe("CW20 Token Pointer Scenarios", function() {
        it("type 1: ERC20 Pointer->CW20: owner is a sei address with no association", async function() {
            const {_, seiAddress} = await createSeiOnlyAccount();
            await executeWasm(cw20Token, {
                transfer: {
                    recipient: seiAddress,
                    amount: "1"
                }
            });
            const balance = await queryWasm(cw20Token, "balance", {
                address: seiAddress
            });
            expect("1").to.equal(balance.data.balance);
        });

        it("type 2: ERC20 Pointer->CW20: owner is a sei address with association", async function() {
            const balanceSender = await pointer.balanceOf(accounts[0].evmAddress);
            const recipient = accounts[1].evmAddress;
            const tx = await pointer.transfer(recipient, 1);
            await tx.wait();
            const balance = await pointer.balanceOf(recipient);
            expect(balance).to.equal(1);
        });

        it("type 3: owner is bank contract", async function() {
            await executeWasm(cw20Token, {
                transfer: {
                    recipient: bankContractAddr,
                    amount: "1"
                }
            });
            const balance = await queryWasm(cw20Token, "balance", {
                address: bankContractAddr
            });
            expect("1").to.equal(balance.data.balance);
        });

        it("type 4: owner is unassociated evm address", async function() {
            // this is not supported
            // const tx = await pointer.transfer(unassociatedEvmAddr, 1);
            // await tx.wait();
            // const balance = await pointer.balanceOf(unassociatedEvmAddr);
            // expect(balance).to.equal(1);
        });
    });
});
