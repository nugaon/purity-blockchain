pragma solidity >=0.4.25 <0.6.0;

contract Subscriptions {

	/// Get the sender's subscribers that could be already invalid too.
	/// To check how many subscribers invalid call getRemovableSubscibers()
	address[] public subscribers;
	address public contentCreator;
	uint public price;
	uint public period; // how many seconds the subscriber's subscription lives
	mapping(address => uint) public userSubTimes; //timestamp

	event SubscriptionHappened(address _subscriber);

	constructor(address owner) public {
		period = 2592000; // 30 days
		contentCreator = owner;
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

	function subscribe()
		public
		payedEnough
		payable
		returns (bool)
	{
		if (userSubTimes[tx.origin] == 0) {
			userSubTimes[tx.origin] = now + period;

			// also have to add to the content creator subscriptions array
			subscribers.push(tx.origin);
		} else { // he already subscribed to this address
			if (userSubTimes[tx.origin] >= now) {
				userSubTimes[tx.origin] += period;
			} else {
				userSubTimes[tx.origin] = now + period;
			}
		}

		emit SubscriptionHappened(tx.origin);

		return true;
	}

	function setSubscriptionPrice(uint value) public onlyContentCreator {
		price = value;
	}

	function checkSubInvalid(address subscriber) public view returns (bool) {
		if (userSubTimes[subscriber] > now) {
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
