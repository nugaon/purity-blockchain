pragma solidity >=0.4.25 <0.6.0;

import { PurityNet } from "./PurityNet.sol";

contract FileUploads {

    struct Content {
        uint8 protocol; // 0: dns, 1: ipfs
        uint8 contentType; // for the client how to process the information; 0: undefined, 1: image, 2: video, etc.
        string fileAddress;
        string summary;
        uint uploadTime; //timestamp
    }
    //mapping(address => Content[]) private userRequiredContents; //specific encrypted content ID
    Content[] public subscriberContents; // linked to batched encrypted content IDs
    Content public debutContent;
    address public contentCreator;
    uint public channelId;
    PurityNet private purityNet;
    bytes32[] public contentLabels;
    mapping(bytes32 => uint[]) private labelledContentIndexes;

    event NewContentUploaded(bytes32 indexed contentLabel, uint subscriberContentIndex, string comment);
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
            contentLabels.push(_contentLabel);
            labelledContentIndexes[_contentLabel].push(subscriberContents.length - 1);
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
