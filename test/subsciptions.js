const Subscriptions = artifacts.require("Subscriptions");

contract('Subscriptions', (accounts) => {

    it('Set 3 gwei the value of the subscription and subscribe with accounts[1]', async() => {
        const instance = await Subscriptions.deployed();

        const value = "3000000000";
        await instance.setSubscriptionPrice(value);
        const subPrice = await instance.price();
        assert.equal(value, subPrice, "Value of the subscription hasn't set.");

        try {
            const subscribeFail = await instance.subscribe({ from: accounts[1], value: "2000000000" });
        } catch(e) {
            const reason = 'The sended coin not enough for subscribe to the content creator.';
            assert.equal(e.reason, reason, "The subscription was successful with lesser than the subscription value");
        }

        const subscribeSuccess = await instance.subscribe({ from: accounts[1], value: "3000000000" });
        assert.equal(subscribeSuccess.receipt.status, true, "The subscription was not successful with the correct subscription value");
    });

    it('Should be subscribed the first 3 accounts (after the coinbase account)', async() => {
        const instance = await Subscriptions.deployed();

        const subscribeSuccess1 = await instance.subscribe({ from: accounts[2], value: "3000000000" });
        const subscribeSuccess2 = await instance.subscribe({ from: accounts[3], value: "3000000000" });
        const subCount = (await instance.getSubscriptionCount()).toNumber();
        assert.equal(subCount, 3, 'There are not 3 subscribers');
    })

    it('Delete 2 accounts and only the accounts[2] remains', async() => {
        const instance = await Subscriptions.deployed();

        const deleteAccounts = await instance.removeSubscribers([2, 0]);
        const subscribersCount = await instance.getSubscriptionCount();
        assert.equal(subscribersCount, 1, 'not only accounts[2] is in the subscribers array');
        const onlySubscriber = await instance.subscribers(0);
        assert.equal(onlySubscriber, accounts[2], "not accounts[2] is the only subscriber");
    })
});
