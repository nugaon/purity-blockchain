pragma solidity >=0.4.25 <0.6.0;

contract FileUploads {

    struct Content {
        uint8 protocol; // 0: ipfs
        uint8 contentType; // for the client how to process the information; 0: undefined, 1: dns
        string fileAddress;
        string password; //password for the encrypted content after reveal.
    }

    mapping(address => Content[]) private userRequiredContents; //specific encrypted content ID
    Content[] public subscriberContents; // linked to batched encrypted content IDs
    address public contentCreator;

    event NewContentUploaded(uint subscriberContentIndex, string comment);
    event RevealContentForUser(address indexed user, uint requiredContentIndex);

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
    function uploadSubscriberContent(string memory batchedLinks, uint8 protocol, uint8 contentcontentType, string memory contentSummary, string memory password) public onlyContentCreator {
        subscriberContents.push(Content({
            protocol: protocol,
            fileAddress: batchedLinks,
            contentType: contentcontentType,
            password: password
        }));

        emit NewContentUploaded(subscriberContents.length - 1, contentSummary);
    }

    function getSubscriberContentsLength() public view returns (uint) {
        return subscriberContents.length;
    }

    function revealContentForUser(address user, string memory encryptedContentAddress, uint8 protocolId, uint8 contentcontentType, string memory password) public {
        userRequiredContents[msg.sender].push(Content({
            fileAddress: encryptedContentAddress,
            contentType: contentcontentType,
            protocol: protocolId,
            password: password
        }));

        emit RevealContentForUser(user, userRequiredContents[msg.sender].length - 1);
    }
}
