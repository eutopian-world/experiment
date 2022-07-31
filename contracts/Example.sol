// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// Polygon (Matic) Mumbai Testnet Deployment
contract Example is ERC721, ERC721Enumerable, VRFConsumerBaseV2 {

    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;
    
    VRFCoordinatorV2Interface COORDINATOR;
    
    // Your subscription ID.
    uint64 s_subscriptionId;

    // Mumbai coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 s_keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 40,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 40000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 1 random value in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 1;

    struct Experience {
        string name;
        string description;
        string image;
        string creator;
        string category;
        string accessLink;
        uint256 uniqueVal;
    }

    mapping(uint256 => address) private buyer;
    mapping(address => uint256) private holder;
    mapping(uint256 => Experience) private requests;
    mapping(uint256 => Experience) private experiences;
    mapping(uint256 => uint256) private uniqueReq;
    uint256 private constant REQUEST_IN_PROGRESS = 99999;

    string private md0 = 'data:application/json;base64,';
    string private md_start = '{"';
    string private md1 = 'name": "';
    string private md2 = '", "description": "';
    string private md3 = '", "animation_url": "';
    string private md_end='"}';
    
    string private attr1='", "attributes": [{"trait_type": "Creator","value": "';
    string private attr2='"},{"trait_type": "Category","value": "';
    string private attr3='"},{"trait_type": "License","value": "';
    string private attr4='"}],"image": "';

    string private license = "MIT License";

    event ExperienceRequested(uint256 indexed requestId, address indexed user);
    event ExperienceFulfilled(uint256 indexed requestId, uint256 indexed uniqueParam);
    event ExperienceRegistered(uint256 indexed tokenId, uint256 indexed uniqueParam);

    /**
     * Constructor 
     *
     */
    constructor(string memory name, string memory symbol, uint64 subscriptionId)
        VRFConsumerBaseV2(vrfCoordinator)
        ERC721(name, symbol)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
    }

    /**
     * Register Augmented Interactive Experience
     */
    function registerExperience(string memory _name, string memory _description, string memory _image, string memory _creator, string memory _category, string memory _accessLink) public returns (uint256 requestId) {
        require(holder[_msgSender()] == 0, "AIE: Already requested registration");
        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        buyer[requestId] = _msgSender();
        holder[_msgSender()] = REQUEST_IN_PROGRESS;
        requests[requestId] = Experience(_name, _description, _image, _creator, _category, _accessLink, 0);
        emit ExperienceRequested(requestId, _msgSender());
        return requestId;
    }

    /**
     * Reveals the weapon metadata by minting the NFT
     */
    function revealExperience() public {
        require(holder[_msgSender()] != 0, "AIE: Experience not requested");
        require(holder[_msgSender()] != REQUEST_IN_PROGRESS, "AIE: Request under processing");
        uint256 uniqueParam = holder[_msgSender()];
        _tokenIdTracker.increment();
        uint256 currentTokenId = _tokenIdTracker.current();
        _safeMint(_msgSender(), currentTokenId);
        // TODO: Set Experience for the tokenId - need requestId 
        experiences[currentTokenId] = requests[uniqueReq[uniqueParam]];
        experiences[currentTokenId].uniqueVal = uniqueParam;
        holder[_msgSender()] = 0;
        emit ExperienceRegistered(currentTokenId, uniqueParam);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "AIE: Non-Existent Token");

        string memory params = string(abi.encodePacked("?uniqueParam=", uint256(experiences[tokenId].uniqueVal).toString(),"?tokenId=", uint256(tokenId).toString()));

        // Generate token's metadataURI in json
        string memory _tokenURI = string(abi.encodePacked(md0, Base64.encode(bytes(string(abi.encodePacked(md_start, md1, experiences[tokenId].name, md2, experiences[tokenId].description, getTraits(experiences[tokenId]), experiences[tokenId].image, md3, experiences[tokenId].accessLink, params, md_end))))));
        return _tokenURI;
    }

    // get string attributes of properties, used in tokenURI call
    function getTraits(Experience memory experience) internal view returns (string memory) {
        string memory attr = string(abi.encodePacked(attr1, experience.creator, attr2, experience.category, attr3, license));
        return string(abi.encodePacked(attr, attr4));
    }

    /**
     * Callback function used by VRF Coordinator to return the random number
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 uniqueParam = randomWords[0];
        holder[buyer[requestId]] = uniqueParam;
        uniqueReq[uniqueParam] = requestId;
        emit ExperienceFulfilled(requestId, uniqueParam);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}