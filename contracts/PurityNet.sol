pragma solidity >=0.4.25 <0.6.0;

import { ContentChannel } from "./ContentChannel.sol";
import "./LinkedListLib.sol";

contract PurityNet {

    using LinkedListLib for LinkedListLib.LinkedList;

    struct Category {
        bytes32 name;
        uint256 channelCreationCount;
    }

    address private admin;
    uint256 constant NULL = 0;
    uint256 constant HEAD = 0;
    bool constant PREV = false;
    bool constant NEXT = true;
    mapping(bytes32 => ContentChannel) public contentChannels; // ID -> ContentChannel Contract
    mapping(bytes32 => bytes32[]) public categoryChannels; //points to channelnames TODO List
    LinkedListLib.LinkedList private orderedCategoryList; // all category names in an ordered array -> first is the most used
    uint public categoryCount; //how many categories exist -> current + 1 will be the next inserted item
    mapping(uint => Category) public categoryIdToStruct;
    mapping(bytes32 => uint) public categoryNameToId;

    event NewChannelCreated(bytes32 channelName, bytes32 indexed category);

    constructor() public {
        admin = msg.sender;
        categoryCount = 0;
    }

    modifier onlyAdmin() {
        require(
            admin == msg.sender,
            "Only the admin can call this function"
        );
        _;
    }

    modifier uniqueChannel(bytes32 channelName) {
        require(
            address(contentChannels[channelName]) == address(0),
            "Channel haSubscription happened for 'SubscriptionHappened' event at Contract ${channel.channelName}s benn already registered"
        );
        _;
    }

    // Channel functions

    function createContentChannel(bytes32 channelName, bytes32 category, uint subPrice, string memory description)
        public
        uniqueChannel(channelName)
        returns (ContentChannel contentChannel)
    {
        contentChannel = new ContentChannel(channelName, subPrice, description, msg.sender);
        contentChannels[channelName] = contentChannel;

        //category ordering handling
        uint256 categoryId = categoryNameToId[category];
        // if the category not existed before, we create it.
        if (categoryId == 0) {
            categoryId = ++categoryCount;
            categoryNameToId[category] = categoryId;
            categoryIdToStruct[categoryId] = Category({
                name: category,
                channelCreationCount: 1
            });
            orderedCategoryList.push(categoryId, PREV);
        } else { // if it existed, reorder by channel creation count
            Category storage categoryData = categoryIdToStruct[categoryId];
            categoryData.channelCreationCount++;
            uint256 loopId = categoryId;
            Category memory adjCategoryData;
            bool exists;
            uint256 adj;
            while(loopId != HEAD) {
                (exists,adj) = orderedCategoryList.getAdjacent(loopId, PREV);
                adjCategoryData = categoryIdToStruct[adj];
                loopId = adj;
                if (adjCategoryData.channelCreationCount > categoryData.channelCreationCount) {
                    break;
                }
            }
            if (loopId != categoryId) {
                orderedCategoryList.remove(categoryId);
                orderedCategoryList.insert(loopId, categoryId, NEXT);
            }
        }

        //category items handling
        categoryChannels[category].push(channelName);

        emit NewChannelCreated(channelName, category);
    }

    function subscribeToChannel(bytes32 channelName, bool pubKeyPrefix, bytes32 pubKey)
        public
        payable
        returns(bool)
    {
        return contentChannels[channelName].subscribeToChannel(pubKeyPrefix, pubKey);
    }

    //category functions

    function removeFromCategory(bytes32 category, uint index) public onlyAdmin() {
        bytes32[] storage selectedcategoryChannels = categoryChannels[category];

        for (uint i = index; i < selectedcategoryChannels.length - 1; i++) {
            selectedcategoryChannels[i] = selectedcategoryChannels[i++];
        }

        selectedcategoryChannels.length = selectedcategoryChannels.length - 1;
    }

    function addChannelTocategory(bytes32 category, bytes32 channelName) public onlyAdmin() {
        categoryChannels[category].push(channelName);
    }

    function getCategoryLength(bytes32 category) public view returns (uint) {
        return categoryIdToStruct[categoryNameToId[category]].channelCreationCount;
    }

    /// @dev get paginated Category tuples with bytes32 categoryNames, uint256 channel count in category, uint256 category IDs
    /// @param _fromNodeId if 0 starts from the head. That is not counted in the result Array
    /// @param _size maximum how many result can be in the array.
    function getCategories(uint _fromNodeId, uint _size)
        external
        view
        returns (
            bytes32[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        // init response variables
        bytes32[] memory categoryNames_ = new bytes32[](_size);
        uint256[] memory categoryChannelCounts_ = new uint256[](_size);
        uint256[] memory categoryIds_ = new uint256[](_size);

        uint256 loopId = _fromNodeId;
        bool exists;
        uint256 adj;
        for (uint i = 0; i < _size; i++) {
            (exists,adj) = orderedCategoryList.getAdjacent(loopId, NEXT);
            if (!exists) {
                break;
            }
            Category storage categoryData = categoryIdToStruct[adj];
            categoryNames_[i] = categoryData.name;
            categoryChannelCounts_[i] = categoryData.channelCreationCount;
            categoryIds_[i] = adj;
            loopId = adj;
        }
        return (
            categoryNames_,
            categoryChannelCounts_,
            categoryIds_
        );
    }

    function getCategoryChannel(bytes32 category, uint index) public view returns (bytes32) {
        return categoryChannels[category][index];
    }
}
