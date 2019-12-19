pragma solidity >=0.4.25 <0.6.0;

contract Subscriptions {

	struct SubscriberDetails {
		bool pubKeyPrefix; // User's can upload their public encryption keys, which will be used to get their subscribed premium content. this is the first part of the key
		bytes32 pubKey; // this is the second (last) part of the public key of the user
		uint userSubTimes; // timestamp
	}
	/// Get the sender's subscribers that could be already invalid too.
	/// To check how many subscribers invalid call getRemovableSubscibers()
	address[] public subscribers;
	address public contentCreator;
	uint public price;
	uint public period; // how many seconds the subscriber's subscription lives
	mapping(address => SubscriberDetails) public subscriberDetails; //subscriber -> SubscriberDetails

	event SubscriptionHappened(address _subscriber);

	constructor(uint _price, address _owner) public {
		period = 2592000; // 30 days
		contentCreator = _owner;
		price = _price;
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

	function subscribe(bool pubKeyPrefix, bytes32 pubKey)
		public
		payedEnough
		payable
		returns (bool)
	{
		SubscriberDetails storage subscriber = subscriberDetails[tx.origin];
		if (subscriber.userSubTimes == 0) {
			subscriber.userSubTimes = now + period;

			// also have to add to the content creator subscriptions array
			subscribers.push(tx.origin);
		} else { // he already subscribed to this address
			if (subscriber.userSubTimes >= now) {
				subscriber.userSubTimes += period;
			} else {
				subscriber.userSubTimes = now + period;
			}
		}
		subscriber.pubKeyPrefix = pubKeyPrefix;
		subscriber.pubKey = pubKey;

		emit SubscriptionHappened(tx.origin);

		return true;
	}

	function getSubscribers() public view returns(address[] memory) {
		return subscribers;
	}

	/// Only experimental yet.
	/* function getSubscribersDetails(address[] memory subscriberAddresses) public view returns(SubscriberDetails[] memory) {
		SubscriberDetails[] memory subscriberDetails_ = new SubscriberDetails[](subscriberAddresses.length);
		for (uint i = 0; i < subscriberAddresses.length; i++) {
			subscriberDetails_[i] = subscriberDetails[subscriberAddresses[i]];
		}
		return subscriberDetails_;
	} */

	function setSubscriptionPrice(uint value) public onlyContentCreator {
		price = value;
	}

	function checkSubInvalid(address subscriberAddress) public view returns (bool) {
		SubscriberDetails storage subscriber = subscriberDetails[subscriberAddress];
		if (subscriber.userSubTimes > now) {
			return false;
		}
		return true;
	}

	/// Get back invalid subscriber indexes of the caller by presents boolean in its index
	/// it is useful to make parameter for removeSubscribers(uint[]) function.
	function getRemovableSubscribers() public view returns (bool[] memory){
		bool[] memory removableSubscribers = new bool[](subscribers.length);

		for (uint i = 0; i < subscribers.length; i++) {
			if (checkSubInvalid(subscribers[i])) {
				removableSubscribers[i] = true;
			}
		}

		return removableSubscribers;
	}

	/// Get the content creator's subscription count
	function getSubscriptionCount() public view returns (uint length) {
		return subscribers.length;
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
	function getLastSubscriberIndex() public view returns (uint) {
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
