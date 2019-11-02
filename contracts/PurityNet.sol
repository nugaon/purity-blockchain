pragma solidity >=0.4.25 <0.6.0;

import { Subscriptions } from "./Subscriptions.sol";
import { FileUploads } from "./FileUploads.sol";

contract PurityNet {

    struct ContentChannel {
        Subscriptions subscriptionHandler;
        FileUploads fileUploadHandler;
        address creator;
    }

    address private admin;

    mapping(bytes32 => ContentChannel) public contentChannels;
    mapping(bytes32 => bytes32[]) public topics; //points to channelnames

    event NewChannelCreated(bytes32 channelName, bytes32 indexed topic);

    constructor() public {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(
            admin == msg.sender,
            "Only the admin can call this function"
        );
        _;
    }

    function createContentChannel(bytes32 contentId, bytes32 topic) public returns (Subscriptions subscriptionHandler, FileUploads fileUploadHandler){
        subscriptionHandler = new Subscriptions(msg.sender);
        fileUploadHandler = new FileUploads(msg.sender);
        //TODO if not null
        contentChannels[contentId] = ContentChannel({
            creator: msg.sender,
            subscriptionHandler: subscriptionHandler,
            fileUploadHandler: fileUploadHandler
        });

        topics[topic].push(contentId);

        emit NewChannelCreated(contentId, topic);
    }

    function removeFromTopic(bytes32 topic, uint index) public onlyAdmin() {
        bytes32[] storage selectedTopics = topics[topic];

        for (uint i = index; i < selectedTopics.length - 1; i++) {
            selectedTopics[i] = selectedTopics[i++];
        }

        selectedTopics.length = selectedTopics.length - 1;
    }

    function addToTopic(bytes32 topic, bytes32 channelName) public onlyAdmin() {
        topics[topic].push(channelName);
    }

    function getTopicLength(bytes32 topic) public view returns (uint) {
        return topics[topic].length;
    }

    function getTopicItem(bytes32 topic, uint index) public view returns (bytes32) {
        return topics[topic][index];
    }
}
