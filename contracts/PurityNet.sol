pragma solidity >=0.4.25 <0.6.0;

import { ContentChannel } from "./ContentChannel.sol";
import "./LinkedListLib.sol";

contract PurityNet {

    using LinkedListLib for LinkedListLib.LinkedList;

    struct Category {
        bytes32 name;
        uint256 channelCreationCount;
    }

    struct ContentChannelData {
        uint[] categoryIds;
        ContentChannel contentChannel;
    }

    address private admin;
    uint256 constant NULL = 0;
    uint256 constant HEAD = 0;
    bool constant PREV = false;
    bool constant NEXT = true;
    uint public categoryCount; //how many categories exist -> current + 1 will be the next inserted item
    uint public channelCount; //how many channels exist -> current + 1 will be the next inserted item
    mapping(uint => Category) public categoryIdToStruct;
    mapping(bytes32 => uint) public categoryNameToId;
    mapping(uint => ContentChannelData) public contentChannels; // ID -> ContentChannel Contract
    mapping(bytes32 => uint) public channelNameToId;
    mapping(uint => LinkedListLib.LinkedList) private categoryChannelsList; //category id to channel id list
    LinkedListLib.LinkedList private orderedCategoryList; // all category names in an ordered array -> first is the most used

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
            address(contentChannels[channelNameToId[channelName]].contentChannel) == address(0),
            "Channel haSubscription happened for 'SubscriptionHappened' event at Contract ${channel.channelName}s benn already registered"
        );
        _;
    }

    // External functions

    /// @dev get paginated Category tuples with bytes32 categoryNames, uint256 channel count in category, uint256 category IDs
    /// @param _fromNodeId if 0 starts from the head. That is not counted in the result Array
    /// @param _size maximum how many result can be in the array.
    function getCategories(uint _fromNodeId, uint _size)
        external
        view
        returns (
            bytes32[] memory categoryNames_,
            uint256[] memory categoryChannelCounts_,
            uint256[] memory categoryIds_
        )
    {
        // init response variables
        categoryNames_ = new bytes32[](_size);
        categoryChannelCounts_ = new uint256[](_size);
        categoryIds_ = new uint256[](_size);

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
    }

    /// @dev return the addresses of the content Channels in a particular Category
    /// @param _fromContentChannelId if 0 starts from the head. That is not counted in the result Array
    /// @param _size maximum how many result can be in the array.
    function getChannelsFromCategories(bytes32 _categoryName, uint256 _fromContentChannelId, uint256 _size)
        external
        view
        returns (address[] memory contentChannelAddresses_)
    {
        contentChannelAddresses_ = new address[](_size);

        LinkedListLib.LinkedList storage categoryChannels = categoryChannelsList[categoryNameToId[_categoryName]];
        uint256 loopId = _fromContentChannelId;
        bool exists;
        uint256 adj;
        for (uint i = 0; i < _size; i++) {
            (exists,adj) = categoryChannels.getAdjacent(loopId, NEXT);
            if (!exists) {
                break;
            }
            contentChannelAddresses_[i] = (address(contentChannels[adj].contentChannel));
            loopId = adj;
        }
    }

    // Channel functions

    function createContentChannel(bytes32 channelName, bytes32 category, uint subPrice, string memory description)
        public
        uniqueChannel(channelName)
        returns (ContentChannel contentChannel)
    {
        //category ordering handling
        uint256 categoryId = categoryNameToId[category];
        uint256 channelCreationCount; // for channel id.
        // if the category not existed before, we create it.
        if (categoryId == 0) {
            categoryId = ++categoryCount;
            categoryNameToId[category] = categoryId;
            channelCreationCount = 1;
            categoryIdToStruct[categoryId] = Category({
                name: category,
                channelCreationCount: channelCreationCount
            });
            orderedCategoryList.push(categoryId, PREV);
        } else { // if it existed, reorder by channel creation countchannelName
            Category storage categoryData = categoryIdToStruct[categoryId];
            channelCreationCount = ++categoryData.channelCreationCount;
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

        contentChannel = new ContentChannel(channelName, subPrice, description, msg.sender, ++channelCount);

        //category items handling
        channelNameToId[channelName] = channelCount;
        contentChannels[channelCount].contentChannel = contentChannel;
        contentChannels[channelCount].categoryIds.push(categoryId);
        categoryChannelsList[categoryId].push(channelCount, PREV); //last item in the list | only one category at creation

        emit NewChannelCreated(channelName, category);
    }

    function getChannelDataFromId(uint _id) public view returns (uint[] memory, address) {
        return (contentChannels[_id].categoryIds, address(contentChannels[_id].contentChannel));
    }

    function getChannelAddressFromId(uint _id) public view returns (address) {
        return address(contentChannels[_id].contentChannel);
    }

    function getChannelAddressFromName(bytes32 _channelName) public view returns (address) {
        return getChannelAddressFromId(channelNameToId[_channelName]);
    }

    function getChannelCategoryIdsFromId(uint _channelId) public view returns (uint[] memory categoryIds_) {
        ContentChannelData storage contentChannelData = contentChannels[_channelId];
        categoryIds_ = contentChannelData.categoryIds;
    }

    // Category functions

    function reorderCategoryChannelPosition(uint256 _channelId) public returns (bool) {
		//order handling in categoryChannels
        uint[] memory categoryIds = getChannelCategoryIdsFromId(_channelId);

        for(uint i = 0; i < categoryIds.length; i++) {
            reorderInCategoryChannel(categoryIds[i], _channelId);
		}

        return true;
    }

    function reorderInCategoryChannel(uint _categoryId, uint256 _channelId) internal returns (bool) {
        ContentChannelData storage contentChannelData = contentChannels[_channelId];
        uint ownSubscriptionCount = contentChannelData.contentChannel.getSubscriptionCount();
        uint256 loopId = _channelId;
        LinkedListLib.LinkedList storage categoryChannels = categoryChannelsList[_categoryId];

        bool exists;
        uint256 adj;
        while(loopId != HEAD) {
            (exists,adj) = categoryChannels.getAdjacent(loopId, PREV);
            if (adj == HEAD) {
                break;
            }
            ContentChannelData storage loopChannelData = contentChannels[adj];
            if (loopChannelData.contentChannel.getSubscriptionCount() > ownSubscriptionCount) {
                break;
            }
            loopId = adj;
        }
        if(loopId != _channelId) {
            categoryChannels.remove(_channelId);
            categoryChannels.insert(loopId, _channelId, PREV);
        }
    }

    function removeFromCategory(bytes32 _categoryName, bytes32 _channelName) public onlyAdmin() {
        uint256 categoryId = categoryNameToId[_categoryName];
        uint256 channelId = channelNameToId[_channelName];
        categoryChannelsList[categoryId].remove(channelId);
        --categoryIdToStruct[categoryId].channelCreationCount;
        // order doesn't matter
        ContentChannelData storage channelData = contentChannels[channelId];
        uint256 removeCategoryIndex;
        uint256 categoriesLength;
        for (uint256 i = 0; i < categoriesLength; i++) {
            if(channelData.categoryIds[i] == categoryId) {
                removeCategoryIndex = i;
                break;
            }
        }
        if (categoriesLength > 1 && removeCategoryIndex != categoriesLength - 1) {
            channelData.categoryIds[removeCategoryIndex] = categoriesLength - 1;
        } else {
            channelData.categoryIds[removeCategoryIndex] = 0;
        }
        channelData.categoryIds.length--;
    }

    function addChannelToCategory(bytes32 _categoryName, bytes32 _channelName) public onlyAdmin() {
        uint256 categoryId = categoryNameToId[_categoryName];
        uint256 channelId = channelNameToId[_channelName];
        categoryChannelsList[categoryId].push(channelId, PREV);
        ++categoryIdToStruct[categoryId].channelCreationCount;
        ContentChannelData storage channelData = contentChannels[channelId];
        channelData.categoryIds.push(categoryId);
    }

    function getCategoryLength(bytes32 _categoryName) public view returns (uint) {
        return categoryIdToStruct[categoryNameToId[_categoryName]].channelCreationCount;
    }
}
