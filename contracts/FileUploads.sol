pragma solidity >=0.4.25 <0.6.0;

contract FileUploads {

    struct encryptedContent {
        uint8 protocol; // 0: ipfs
        uint8 contentType; // for the client how to process the information; 0: undefined, 1: dns
        string fileAddress;
    }

    mapping(address => encryptedContent[]) private userRequiredContents; //specific encrypted content ID
    encryptedContent[] public subscriberContents; // linked to batched encrypted content IDs
    address public contentCreator;

    event NewContentUploaded(uint subscriberContentIndex, string comment);
    event RevealContentForUser(address user, uint requiredContentIndex);

    constructor(address owner) public {
        contentCreator = owner;
    }

    modifier onlyContentCreator() {
        require(
            contentCreator == msg.sender,
            "Only the content creator can call this function"
        );
        _;
    }

    function getRequiredContentsLength() public view returns(uint) {
        return userRequiredContents[msg.sender].length;
    }

    /// The batchedLinks is a pointer to a p2p storage address where the subscribers specific encrypted content ids have
    function uploadSubscriberContent(string memory batchedLinks, uint8 protocol, uint8 contentcontentType, string memory contentSummary) public onlyContentCreator {
        subscriberContents.push(encryptedContent({
            protocol: protocol,
            fileAddress: batchedLinks,
            contentType: contentcontentType
        }));

        emit NewContentUploaded(subscriberContents.length - 1, contentSummary);
    }

    function getSubscriberContentsLength() public view returns (uint) {
        return subscriberContents.length;
    }

    function revealContentForUser(address user, string memory encryptedContentAddress, uint8 protocolId, uint8 contentcontentType) public {
        userRequiredContents[msg.sender].push(encryptedContent({
            fileAddress: encryptedContentAddress,
            contentType: contentcontentType,
            protocol: protocolId
        }));

        emit RevealContentForUser(user, userRequiredContents[msg.sender].length - 1);
    }
}
