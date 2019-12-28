pragma solidity >=0.4.25 <0.6.0;

import { PurityNet } from "./PurityNet.sol";

contract FileUploads {

    struct Content {
        uint8 protocol; // 0: dns, 1: ipfs
        uint8 contentType; // for the client how to process the information; 0: undefined, 1: image, 2: video, etc.
        string fileAddress;
        string summary;
        string password; //password for the encrypted content after reveal.
        uint uploadTime; //timestamp
    }
    mapping(address => Content[]) private userRequiredContents; //specific encrypted content ID
    Content[] public subscriberContents; // linked to batched encrypted content IDs
    Content public debutContent;
    address public contentCreator;
    uint public channelId;
    PurityNet private purityNet;

    event NewContentUploaded(uint subscriberContentIndex, string comment);
    event RevealContentForUser(address indexed user, uint requiredContentIndex);

    constructor(address _contentCreator, uint _channelId, PurityNet _purityNet) public {
        contentCreator = _contentCreator;
        channelId = _channelId;
        purityNet = _purityNet;
    }

    modifier onlyContentCreator() {
        require(
            contentCreator == tx.origin || contentCreator == msg.sender,
            "Only the content creator can call this function"
        );
        _;
    }

    function getRequiredContentsLength() public view returns(uint) {
        return userRequiredContents[msg.sender].length;
    }

    function setDebutContent(
        uint8 _protocol,
        string memory _fileAddress,
        uint8 _contentType
    )   public
        returns(bool)
    {
        debutContent = Content({
            protocol: _protocol,
            fileAddress: _fileAddress,
            contentType: _contentType,
            summary: "",
            password: "",
            uploadTime: now
        });
        return true;
    }

    /// The batchedLinks is a pointer to a p2p storage address where the subscribers specific encrypted content ids have
    function uploadSubscriberContent(
        uint8 _protocol,
        string memory _fileAddress,
        uint8 _contentType,
        string memory _password,
        string memory _contentSummary
    )   public
        onlyContentCreator
    {
        subscriberContents.push(Content({
            protocol: _protocol,
            fileAddress: _fileAddress,
            contentType: _contentType,
            password: _password,
            summary: _contentSummary,
            uploadTime: now
        }));

        emit NewContentUploaded(subscriberContents.length - 1, _contentSummary);
    }

    function getSubscriberContentsLength() public view returns (uint) {
        return subscriberContents.length;
    }

    /* function revealContentForUser(
        string memory _fileAddress,
        uint8 _contentType,
        uint8 _protocolId,
        string memory _password,
        address _user
    )
        public
    {
        //TODO
        //indexid

        emit RevealContentForUser(_user, userRequiredContents[msg.sender].length - 1);
    } */
}
