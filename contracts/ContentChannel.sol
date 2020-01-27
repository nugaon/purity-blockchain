pragma solidity >=0.4.25 <0.6.0;

import { Subscriptions } from "./Subscriptions.sol";
import { FileUploads } from "./FileUploads.sol";
import { PurityNet } from "./PurityNet.sol";

contract ContentChannel {

    Subscriptions public subscriptionHandler;
    FileUploads public fileUploadHandler;
    address public contentCreator;
    PurityNet private purityNet;
    bytes32 public channelName;
    string public description;
    uint public channelId;

    event RevealContentForUser(address indexed user, uint requiredContentIndex);

    constructor(bytes32 _channelName, uint _subPrice, uint _subTime, bool _permitExternalSubs, string memory _description, address _owner, uint _channelId) public {
        channelName = _channelName;
        contentCreator = _owner;
        purityNet = PurityNet(msg.sender);
        subscriptionHandler = new Subscriptions(_subPrice, _subTime, _owner, _channelId, _permitExternalSubs, purityNet);
        fileUploadHandler = new FileUploads(_owner, _channelId, purityNet);
        description = _description;
        channelId = _channelId;
    }

    function setDescription(string calldata _description) external returns (bool) {
        description = _description;
        return true;
    }

    function getSubscriptionCount() external view returns (uint length) {
        return subscriptionHandler.getSubscriptionCount();
    }

    function getContentData()
        external
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
