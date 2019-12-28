pragma solidity >=0.4.25 <0.6.0;

import { Subscriptions } from "./Subscriptions.sol";
import { FileUploads } from "./FileUploads.sol";
import { PurityNet } from "./PurityNet.sol";

contract ContentChannel {

    Subscriptions subscriptionHandler;
    FileUploads fileUploadHandler;
    address contentCreator;
    PurityNet private purityNet;
    bytes32 public channelName;
    string public description;
    uint public channelId;

    event RevealContentForUser(address indexed user, uint requiredContentIndex);

    constructor(bytes32 _channelName, uint _subPrice, string memory _description, address _owner, uint _channelId) public {
        channelName = _channelName;
        contentCreator = _owner;
        purityNet = PurityNet(msg.sender);
        subscriptionHandler = new Subscriptions(_subPrice, _owner, _channelId, purityNet);
        fileUploadHandler = new FileUploads(_owner, _channelId, purityNet);
        description = _description;
        channelId = _channelId;
    }

    function setDescription(string memory _description) public returns (bool) {
        description = _description;
        return true;
    }

    function getSubscriptionCount() public view returns (uint length) {
        return subscriptionHandler.getSubscriptionCount();
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
