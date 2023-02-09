// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

contract TestConstants {
    uint256 public constant WAD = 1e18;

    bytes6 public constant CHI = 0x434849000000;
    bytes6 public constant RATE = 0x524154450000;

    string public constant SERIES_ID = "SERIES_ID";
    string public constant ILK_ID = "ILK_ID";

    string public constant CI = "CI";
    string public constant RPC = "RPC";
    string public constant LOCALHOST = "LOCALHOST";
    string public constant MAINNET = "MAINNET";
    string public constant ARBITRUM = "ARBITRUM";
    string public constant HARNESS = "HARNESS";
    string public constant UNIT_TESTS = "UNIT_TESTS";
    string public constant MOCK = "MOCK";
    string public constant NETWORK = "NETWORK";

    string public constant TIMELOCK = "TIMELOCK";
    string public constant CAULDRON = "CAULDRON";
    string public constant LADLE = "LADLE";
    string public constant REPAYFROMLADLEMODULE = "REPAYFROMLADLEMODULE";
    string public constant WRAPETHERMODULE = "WRAPETHERMODULE";
    string public constant STRATEGY = "STRATEGY";

    mapping(string => mapping(string => address)) public addresses;

    constructor() {
        addresses[MAINNET][TIMELOCK] = 0x3b870db67a45611CF4723d44487EAF398fAc51E3;
        addresses[MAINNET][CAULDRON] = 0xc88191F8cb8e6D4a668B047c1C8503432c3Ca867;
        addresses[MAINNET][LADLE] = 0x6cB18fF2A33e981D1e38A663Ca056c0a5265066A;
        addresses[MAINNET][REPAYFROMLADLEMODULE] = 0xd47a7473C83a1cC145407e82Def5Ae15F8b338c2;
        addresses[MAINNET][WRAPETHERMODULE] = 0x22768FCaFe7BB9F03e31cb49823d1Ece30C0b8eA;
        addresses[ARBITRUM][TIMELOCK] = 0xd0a22827Aed2eF5198EbEc0093EA33A4CD641b6c;
        addresses[ARBITRUM][CAULDRON] = 0x23cc87FBEBDD67ccE167Fa9Ec6Ad3b7fE3892E30;
        addresses[ARBITRUM][LADLE] = 0x16E25cf364CeCC305590128335B8f327975d0560;
        addresses[ARBITRUM][REPAYFROMLADLEMODULE] = 0xB8B238bBa16a3f773fb7fE61213bb94371fc6b01;
        addresses[ARBITRUM][WRAPETHERMODULE] = 0x4cD01eD221d6d198e2656c16c32803BF78134568;
    }
}
