// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ReceiverWeight} from "../lib/radicle-streaming/src/Pool.sol";
import "openzeppelin-contracts/access/Ownable.sol";

import {FundingPool} from "./pool.sol";

struct InputNFTType {
    uint128 nftTypeId;
    uint128 limit;
}

contract FundingNFT is ERC721, Ownable {
    FundingPool public pool;
    IERC20 public dai;

    // minimum streaming amount per second to mint an NFT
    uint128 minAmtPerSec;

    struct NFTType {
        uint128 limit;
        uint128 minted;
    }

    mapping (uint128 => NFTType) public nftTypes;

    // events
    event NewNFTType(uint128 indexed nftType, uint128 limit);

    constructor(FundingPool pool_, string memory name_, string memory symbol_, address owner_,
        uint128 minAmtPerSec_, InputNFTType[] memory inputNFTTypes) ERC721(name_, symbol_) {
        pool = FundingPool(pool_);
        dai = pool.erc20();
        minAmtPerSec = minAmtPerSec_;
        addTypes(inputNFTTypes);
        transferOwnership(owner_);
    }

    function addTypes(InputNFTType[] memory inputNFTTypes) public onlyOwner {
        for(uint i = 0; i < inputNFTTypes.length; i++) {
            uint128 limit = inputNFTTypes[i].limit;
            uint128 nftTypeId = inputNFTTypes[i].nftTypeId;
            // nftType already exists or limit is not > 0
            require(nftTypes[nftTypeId].limit == 0, "nftTypeId-already-in-usage");
            require(limit > 0, "zero-limit-not-allowed");

            nftTypes[nftTypeId].limit = limit;
            emit NewNFTType(nftTypeId, limit);
        }
    }

    function createTokenId(uint128 id, uint128 nftType) public pure returns(uint tokenId) {
        return uint((uint(nftType) << 128)) | id;
    }

    function tokenType(uint tokenId) public pure returns(uint128 nftType) {
        return uint128(tokenId >> 128);
    }

    function mint(address nftReceiver, uint128 typeId, uint128 topUp, uint128 amtPerSec) external returns (uint256) {
        require(amtPerSec >= minAmtPerSec, "amt-per-sec-too-low");
        uint128 cycleSecs = uint128(pool.cycleSecs());
        require(topUp >= amtPerSec * cycleSecs, "toUp-too-low");
        require(nftTypes[typeId].minted++ < nftTypes[typeId].limit, "nft-type-reached-limit");

        uint256 newTokenId = createTokenId(nftTypes[typeId].minted, typeId);

        _mint(address(this), newTokenId);

        // transfer currency to NFT registry
        dai.transferFrom(nftReceiver, address(this), topUp);
        dai.approve(address(pool), topUp);

        // start streaming
        ReceiverWeight[] memory receivers = new ReceiverWeight[](1);
        receivers[0] = ReceiverWeight({receiver: owner(), weight:1});
        pool.updateSender(address(this), newTokenId, topUp, 0, amtPerSec, receivers);

        // transfer nft from contract to receiver
        _transfer(address(this), nftReceiver, newTokenId);

        return newTokenId;
    }

    // todo needs to be implemented
    function tokenURI(uint256) public view virtual override returns (string memory)  {
        // test metadata json
        return "QmaoWScnNv3PvguuK8mr7HnPaHoAD2vhBLrwiPuqH3Y9zm";
    }

    // todo needs to be implemented
    function contractURI() public view returns (string memory) {
        // test project data json
        return "QmdFspZJyihiG4jESmXC72VfkqKKHCnNSZhPsamyWujXxt";
    }
}
