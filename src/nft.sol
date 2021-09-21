pragma solidity ^0.8.4;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ReceiverWeight} from "../lib/radicle-streaming/src/Pool.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Counters.sol";

import {FundingPool} from "./pool.sol";

contract FundingNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _totalTokens;

    FundingPool public pool;
    IERC20 public dai;

    // minimum streaming amount per second to mint an NFT
    uint128 minAmtPerSec;

    struct NFTType {
        uint128 limit;
        uint128 minted;
    }

    mapping (uint => NFTType) public nftTypes;
    mapping (uint => uint128) public tokenType;

    uint128 public constant UNLIMITED = type(uint128).max;
    uint128 public constant DEFAULT_TYPE = 0;

    constructor(FundingPool pool_, string memory name_, string memory symbol_, address owner_,
        uint128 minAmtPerSec_, uint128 defaultTypeLimit) ERC721(name_, symbol_) {
        pool = FundingPool(pool_);
        dai = pool.erc20();
        transferOwnership(owner_);
        minAmtPerSec = minAmtPerSec_;

        nftTypes[DEFAULT_TYPE].limit = defaultTypeLimit;
    }

    function addType(uint newTypeId, uint128 limit) external onlyOwner {
        require(nftTypes[newTypeId].limit == 0, "nft-type-already-exists");
        require(limit > 0, "limit-not-greater-than-zero");

        nftTypes[newTypeId].limit = limit;
    }

    function mint(address nftReceiver, uint128 typeId, uint128 topUp, uint128 amtPerSec) external returns (uint256) {
        require(amtPerSec >= minAmtPerSec, "amt-per-sec-too-low");
        uint128 cycleSecs = uint128(pool.cycleSecs());
        // todo currLeftSecs*amtPerSec should be immediately transferred to receiver instead of streaming
        require(topUp >= amtPerSec * cycleSecs, "toUp-too-low");


        require(nftTypes[typeId].minted++ < nftTypes[typeId].limit, "nft-type-reached-limit");

        //  mint token
        _totalTokens.increment();
        uint256 newTokenId = _totalTokens.current();
        _mint(address(this), newTokenId);

        if (typeId != DEFAULT_TYPE) {
            tokenType[newTokenId] = typeId;
        }

        // transfer currency to NFT registry
        dai.transferFrom(nftReceiver, address(this), topUp);
        dai.approve(address(pool), topUp);

        // start streaming
        ReceiverWeight[] memory receivers = new ReceiverWeight[](1);
        receivers[0] = ReceiverWeight({receiver: owner(), weight:1});
        pool.updateSender(address(this), uint128(newTokenId), topUp, 0, amtPerSec, receivers);

        // transfer nft from contract to receiver
        _transfer(address(this), nftReceiver, newTokenId);

        return newTokenId;
    }

    // todo needs to be implemented
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)  {
        // test metadata json
        return "QmaoWScnNv3PvguuK8mr7HnPaHoAD2vhBLrwiPuqH3Y9zm";
    }

    // todo needs to be implemented
    function contractURI() public view returns (string memory) {
        // test project data json
        return "QmdFspZJyihiG4jESmXC72VfkqKKHCnNSZhPsamyWujXxt";
    }
}
