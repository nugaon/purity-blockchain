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

    struct UserKey {
        bool pubKeyPrefix; // User's can upload their public encryption keys, which will be used to get their subscribed premium content. this is the first part of the key
        bytes32 pubKey; // this is the second (last) part of the public key of the user
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
    mapping(uint => ContentChannelData) private contentChannels; // ID -> ContentChannel Contract
    mapping(bytes32 => uint) public channelNameToId;
    uint8 public withdrawFeePercent; //at subcontracts balance withdraws this contract gets the withdraw fee.
    uint public minSubscriptionFee; //how many Wei should be paid minimum with a Subscription
    mapping(uint => LinkedListLib.LinkedList) private categoryChannelsList; //category id to channel id list
    LinkedListLib.LinkedList private orderedCategoryList; // all category names in an ordered array -> first is the most used
    mapping(address => UserKey) public userKeys; //subscriber -> Subscriber Public Key

    event NewChannelCreated(bytes32 channelName, bytes32 indexed category);
    event NewPremiumUser(address user);

    constructor(uint8 _withdrawFeePercent, uint _minSubscriptionFee) public {
        admin = msg.sender;
        categoryCount = 0;
        withdrawFeePercent = _withdrawFeePercent;
        minSubscriptionFee = _minSubscriptionFee;
    }

    modifier onlyAdmin() {
        require(
            admin == msg.sender,
            "Only the admin can call this function"
        );
        _;
    }

    /* modifier uniqueChannel(bytes32 channelName) {
        require(
            address(contentChannels[channelNameToId[channelName]].contentChannel) == address(0),
            "Channel has been already registered"
        );
        _;
    } */

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

    // Coin functions

    function () external payable {}

    function setWithdrawFeePercent(uint8 _withdrawFeePercent) public onlyAdmin() {
        withdrawFeePercent = _withdrawFeePercent;
    }

    function setSubscriptionFee(uint8 _minSubscriptionFee) public onlyAdmin() {
        minSubscriptionFee = _minSubscriptionFee;
    }

    function withdrawBalance() public onlyAdmin() {
        msg.sender.transfer(address(this).balance);
    }

    // Channel functions

    function createContentChannel(bytes32 _channelName, bytes32 _category, uint _subPrice, uint _subTime, bool _permitExternalSubs, string calldata _description)
        external
        //uniqueChannel(_channelName)
        returns (ContentChannel contentChannel)
    {
        require(
            address(contentChannels[channelNameToId[_channelName]].contentChannel) == address(0),
            "Channel has been already registered"
        );
        //category ordering handling
        uint256 categoryId = categoryNameToId[_category];
        uint256 channelCreationCount; // for channel id.
        // if the category not existed before, we create it.
        if (categoryId == 0) {
            categoryId = ++categoryCount;
            categoryNameToId[_category] = categoryId;
            channelCreationCount = 1;
            categoryIdToStruct[categoryId] = Category({
                name: _category,
                channelCreationCount: channelCreationCount
            });
            orderedCategoryList.push(categoryId, PREV);
        } else { // if it existed, reorder by channel creation count_channelName
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

        contentChannel = new ContentChannel(_channelName, _subPrice, _subTime, _permitExternalSubs, _description, msg.sender, ++channelCount);

        //category items handling
        channelNameToId[_channelName] = channelCount;
        contentChannels[channelCount].contentChannel = contentChannel;
        contentChannels[channelCount].categoryIds.push(categoryId);
        categoryChannelsList[categoryId].push(channelCount, PREV); //last item in the list | only one category at creation

        emit NewChannelCreated(_channelName, _category);
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

    // Subscriber functions

    function getUsersKeys(address[] calldata _users) external view returns (bool[] memory pubKeyPrefixes_, bytes32[] memory pubKeys_) {
        pubKeyPrefixes_ = new bool[](_users.length);
        pubKeys_ = new bytes32[](_users.length);

        for (uint256 i = 0; i < _users.length; i++) {
            UserKey storage userKey = userKeys[_users[i]];
            pubKeyPrefixes_[i] = userKey.pubKeyPrefix;
            pubKeys_[i] = userKey.pubKey;
        }
    }

    /// @dev First time when a user subscribe to a Channel this method called.
    function register(bool _pubKeyPrefix, bytes32 _pubKey) public returns(bool) {
        UserKey storage userKey = userKeys[tx.origin];
        if(userKey.pubKey != bytes32(0)) {
            userKey.pubKey = _pubKey;
            userKey.pubKeyPrefix = _pubKeyPrefix;
        } else {
            userKey.pubKey = _pubKey;
            userKey.pubKeyPrefix = _pubKeyPrefix;

            emit NewPremiumUser(tx.origin);
        }

        return true;
    }
}
