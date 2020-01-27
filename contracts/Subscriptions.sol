pragma solidity >=0.4.25 <0.6.0;

import { PurityNet } from "./PurityNet.sol";
import { ContentChannel } from "./ContentChannel.sol";

contract Subscriptions {

	/// Get the sender's subscribers that could be already invalid too.
	/// To check how many subscribers invalid call getRemovableSubscibers()
	address[] public subscribers;
	address public contentCreator;
	uint public price;
	uint public period; // how many seconds the subscriber's subscription lives
	bool public permitExternalSubs; //if false, only the owner can invite Subscribers
	mapping(address => uint) public premiumDeadlines; //subscriber -> SubscriberDetails
	uint public channelId;
	PurityNet private purityNet;

	event SubscriptionHappened(address _subscriber);

	constructor(uint _price, uint _period, address _owner, uint _channelId, bool _permitExternalSubs, PurityNet _purityNet) public {
		price = _price;
		period = _period; // 2592000 -> 30 days
		contentCreator = _owner;
		channelId = _channelId;
		permitExternalSubs = _permitExternalSubs;
		purityNet = _purityNet;
	}

	modifier payedEnough() {
		require(
			price <= msg.value,
			"The sended coin not enough for subscribe to the content creator."
		);
		_;
	}

	modifier onlyContentCreator() {
		require(
			contentCreator == tx.origin || contentCreator == msg.sender,
			"Only the content creator can call this function"
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

	/* function getSubscribers() external view returns(address[] memory) {
		return subscribers;
	} */

	/// Only experimental yet.
	/* function getSubscribersDetails(address[] memory subscriberAddresses) public view returns(SubscriberDetails[] memory) {
		SubscriberDetails[] memory premiumDeadlines_ = new SubscriberDetails[](subscriberAddresses.length);
		for (uint i = 0; i < subscriberAddresses.length; i++) {
			premiumDeadlines_[i] = premiumDeadlines[subscriberAddresses[i]];
		}
		return premiumDeadlines_;
	} */

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
