pragma solidity >=0.4.25 <0.6.0;

import { PurityNet } from "./PurityNet.sol";

contract ContentChannel {

    address public contentCreator;
    PurityNet private purityNet;
    bytes32 public channelName;
    string public description;
    uint public channelId;

    constructor(bytes32 _channelName, uint _subPrice, uint _subTime, bool _permitExternalSubs, string memory _description, address _owner, uint _channelId) public {
        channelName = _channelName;
        contentCreator = _owner;
        purityNet = PurityNet(msg.sender);
        description = _description;
        channelId = _channelId;

        // Subscriptions
        price = _subPrice;
        period = _subTime; // 2592000 -> 30 days
        permitExternalSubs = _permitExternalSubs;
    }

    modifier onlyContentCreator() {
        require(
            contentCreator == tx.origin || contentCreator == msg.sender,
            "Only the content creator can call this function"
        );
        _;
    }

    function setDescription(string calldata _description) external returns (bool) {
        description = _description;
        return true;
    }

    function getChannelData()
        external
        view
        returns(
            address contentCreator_,
            bytes32 channelName_,
            string memory description_,
            uint channelId_,
            uint balance_,
            uint price_,
            uint subscriptionCount_,
            uint userSubTime_
        )
    {
        contentCreator_ = contentCreator;
        channelName_ = channelName;
        description_ = description;
        channelId_ = channelId;
        balance_ = address(this).balance;
        price_ = price;
        subscriptionCount_ = subscribers.length;
        userSubTime_ = premiumDeadlines[msg.sender];
    }

    // FileUploads

    struct Content {
        uint8 protocol; // 0: dns, 1: ipfs
        uint8 contentType; // for the client how to process the information; 0: undefined, 1: image, 2: video, etc.
        string fileAddress;
        string summary;
        uint uploadTime; //timestamp
    }
    //mapping(address => Content[]) private userRequiredContents; //specific encrypted content ID
    Content[] public subscriberContents; // linked to batched encrypted content IDs
    bytes32[] public contentLabels;
    mapping(bytes32 => uint[]) private labelledContentIndexes;

    event NewContentUploaded(bytes32 indexed contentLabel, uint subscriberContentIndex, string comment);

    /* function getRequiredContentsLength() public view returns(uint) {
        return userRequiredContents[msg.sender].length;
    } */

    /// The batchedLinks is a pointer to a p2p storage address where the subscribers specific encrypted content ids have
    function uploadSubscriberContent(
        uint8 _protocol,
        string calldata _fileAddress,
        uint8 _contentType,
        string calldata _contentSummary,
        bytes32 _contentLabel
    )   external
        onlyContentCreator
    {
        subscriberContents.push(Content({
            protocol: _protocol,
            fileAddress: _fileAddress,
            contentType: _contentType,
            summary: _contentSummary,
            uploadTime: now
        }));

        if(_contentLabel != "") {
            uint[] storage contentIndexes = labelledContentIndexes[_contentLabel];
            if(contentIndexes.length == 0) {
              contentLabels.push(_contentLabel);
            }
            contentIndexes.push(subscriberContents.length - 1);
        }

        emit NewContentUploaded(_contentLabel, subscriberContents.length - 1, _contentSummary);
    }

    function getLabelledContentIndexes(bytes32 label) external view returns (uint[] memory) {
        return labelledContentIndexes[label];
    }

    function getSubscriberContentsLength() external view returns (uint) {
        return subscriberContents.length;
    }

    function getContentLabels() external view returns (bytes32[] memory) {
        return contentLabels;
    }

    // Subscriptions

    /// Get the sender's subscribers that could be already invalid too.
    /// To check how many subscribers invalid call getRemovableSubscibers()
    address[] public subscribers;
    uint public price;
    uint public period; // how many seconds the subscriber's subscription lives
    bool public permitExternalSubs; //if false, only the owner can invite Subscribers
    mapping(address => uint) public premiumDeadlines; //subscriber -> SubscriberDetails

    event SubscriptionHappened(address _subscriber);

    modifier payedEnough() {
        require(
            price <= msg.value,
            "The sended coin not enough for subscribe to the content creator."
        );
        _;
    }

    modifier greaterThanMinSubFee() {
        require(
            purityNet.minSubscriptionFee() <= msg.value,
            "You did not send enough coin to perform the action"
        );
        _;
    }

    modifier checkUserRegistered(address _user) {
        (,bytes32 userKey) = purityNet.userKeys(_user);
        require(
            userKey != bytes32(0),
            "User has not been registered on the PurityNet yet."
        );
        _;
    }

    modifier subscriptionEnabled() {
        require(
            permitExternalSubs,
            "Subscription is not enabled"
        );
        _;
    }

    /// @dev Call this function if user hasn't been subscribed on PurityNet ever before.
    function subscribe(bool _pubKeyPrefix, bytes32 _pubKey)
        public
        payedEnough
        greaterThanMinSubFee
        subscriptionEnabled
        payable
        returns (bool)
    {
        bool registration = purityNet.register(_pubKeyPrefix, _pubKey);
        if(registration) {
            return addToPremium(tx.origin);
        }
        return false;
    }

    function subscribe()
        public
        payedEnough
        greaterThanMinSubFee
        checkUserRegistered(tx.origin)
        subscriptionEnabled
        payable
        returns (bool)
    {
        return addToPremium(tx.origin);
    }

    /// @dev Can be called by only Content Creator.
    function invite(address _user)
        public
        greaterThanMinSubFee
        onlyContentCreator
        checkUserRegistered(_user)
        payable
        returns(bool)
    {
        return addToPremium(_user);
    }

    function addToPremium(address _user) private returns(bool){
        uint userSubTime = premiumDeadlines[_user];
        if (userSubTime == 0) {
            userSubTime = now + period;

            // also have to add to the content creator subscriptions array
            subscribers.push(_user);
        } else { // he already subscribed to this address
            if (userSubTime >= now) {
                userSubTime += period;
            } else {
                userSubTime = now + period;
            }
        }

        premiumDeadlines[_user] = userSubTime;

        // PurityNet actions
        bool successful = purityNet.reorderCategoryChannelPosition(channelId);

        emit SubscriptionHappened(_user);

        return successful;
    }

    function setSubscriptionPrice(uint value) public onlyContentCreator {
        price = value;
    }

    function setPermitExternalSubs(bool _permitExternalSubs) public onlyContentCreator {
        permitExternalSubs = _permitExternalSubs;
    }

    function withdrawBalance() public onlyContentCreator() {
        uint256 balance = address(this).balance;
        uint256 fee = ( balance / 100 ) * purityNet.withdrawFeePercent();
        uint256 userGet = balance - fee;
        msg.sender.transfer(userGet);
        address(purityNet).transfer(fee);
    }

    function checkSubInvalid(address subscriberAddress) public view returns (bool) {
        if (premiumDeadlines[subscriberAddress] > now) {
            return false;
        }
        return true;
    }

    /// Get back invalid subscriber indexes of the caller by presents boolean in its index
    /// it is useful to make parameter for removeSubscribers(uint[]) function.
    function getRemovableSubscribers() external view returns (bool[] memory){
        bool[] memory removableSubscribers = new bool[](subscribers.length);

        for (uint i = 0; i < subscribers.length; i++) {
            if (checkSubInvalid(subscribers[i])) {
                removableSubscribers[i] = true;
            }
        }

        return removableSubscribers;
    }

    /// Get the content creator's subscription count
    function getSubscriptionCount() external view returns (uint length) {
        return subscribers.length;
    }

    function getSubscribersWithKeys() external view returns(address[] memory subscribers_, bool[] memory pubKeyPrefixes_, bytes32[] memory pubKeys_) {
        subscribers_ = subscribers;
        (pubKeyPrefixes_, pubKeys_) = purityNet.getUsersKeys(subscribers_);
    }

    /// Remove subscribers from the 'subscribers' array at the given indexes
    /// The function handles the mixed order in the passed array.
    function removeSubscribers(uint[] memory subscriberIndexes) public onlyContentCreator {
        for (uint i = 0; i < subscriberIndexes.length; i++) {
            delete subscribers[subscriberIndexes[i]];
        }

        uint lastIndex = getLastSubscriberIndex();
        subscribers.length = lastIndex + 1;

        for (uint i = 0; i < subscriberIndexes.length; i++) {
            if (subscriberIndexes[i] < lastIndex) {
                subscribers[subscriberIndexes[i]] = subscribers[lastIndex];
                subscribers.length = lastIndex; //trim the last element of the array
                lastIndex = getLastSubscriberIndex();
            }
        }
    }

    /// Get back the last valid address index from the 'subscribers' array
    function getLastSubscriberIndex() private view returns (uint) {
        uint i = subscribers.length - 1;
        while (i > 0) {
            if (subscribers[i] != address(0)) {
                return i;
            }
            i--;
        }
        return i;
    }
}
