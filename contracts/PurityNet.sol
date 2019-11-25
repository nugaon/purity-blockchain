pragma solidity >=0.4.25 <0.6.0;

import { ContentChannel } from "./ContentChannel.sol";

contract PurityNet {

    address private admin;
    mapping(bytes32 => ContentChannel) public contentChannels; // ID -> ContentChannel Contract
    mapping(bytes32 => bytes32[]) public topics; //points to channelnames TODO List
    bytes32[] public topicHistory; // all topic names in this array -> TODO list

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

    modifier uniqueChannel(bytes32 channelName) {
        require(
            address(contentChannels[channelName]) == address(0),
            "Channel has benn already registered"
        );
        _;
    }

    // Channel functions

    function createContentChannel(bytes32 channelName, bytes32 topic)
        public
        uniqueChannel(channelName)
        returns (ContentChannel contentChannel)
    {
        contentChannel = new ContentChannel(channelName, msg.sender);
        contentChannels[channelName] = contentChannel;

        //topic handling
        if (topics[topic].length == 0) {
            topicHistory.push(topic);
        }

        topics[topic].push(channelName);

        emit NewChannelCreated(channelName, topic);
    }

    function subscribeToChannel(bytes32 channelName)
        public
        payable
        returns(bool)
    {
        return contentChannels[channelName].subscribeToChannel();
    }

    //Topic functions

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

    function getTopicsHistoryLength() public view returns (uint) {
        return topicHistory.length;
    }

    function getTopicItem(bytes32 topic, uint index) public view returns (bytes32) {
        return topics[topic][index];
    }
}
