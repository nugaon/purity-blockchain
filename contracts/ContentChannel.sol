pragma solidity >=0.4.25 <0.6.0;

import { Subscriptions } from "./Subscriptions.sol";
import { FileUploads } from "./FileUploads.sol";

contract ContentChannel {

    Subscriptions subscriptionHandler;
    FileUploads fileUploadHandler;
    address contentCreator;
    address private admin;
    bytes32 public channelName;
    string public description;

    event RevealContentForUser(address indexed user, uint requiredContentIndex);

    constructor(bytes32 _channelName, address _owner) public {
        channelName = _channelName;
        contentCreator = _owner;
        admin = msg.sender;
        subscriptionHandler = new Subscriptions(_owner);
        fileUploadHandler = new FileUploads(_owner);
    }

    function subscribeToChannel() public payable returns(bool) {
        return subscriptionHandler.subscribe();
    }

    function setDescription(string memory _description) public returns (bool) {
        description = _description;
        return true;
    }

    function getContentData()
        public
        view
        returns(
            address subscriptionHandler_,
            address fileUploadHandler_,
            address contentCreator_,
            bytes32 channelName_
        )
    {
        subscriptionHandler_ = address(subscriptionHandler);
        fileUploadHandler_ = address(fileUploadHandler);
        contentCreator_ = contentCreator;
        channelName_ = channelName;
    }
}
