
const { IdenityService } = require("purity-identity");
const PurityNet = artifacts.require("PurityNet");
const ContentChannel = artifacts.require("ContentChannel");

contract("PurityNet", (accounts) => {
    let instance;
    let channel1Address;
    let channel1Instance;
    let account1Identity
    let account2Identity
    let account3Identity

    before(async function() {
        instance = await PurityNet.deployed();
    });

    it("Create channel", async() => {
        const channelName = "contentChannel1";
        const categoryName = "category1";

        const category = web3.utils.fromAscii(categoryName);
        const channel = web3.utils.fromAscii(channelName);
        const subPrice = web3.utils.toWei("0.1");
        const subTime = 2592000; //in seconds
        const permitExternalSubs = true;
        const description = "basic description";

        await instance.createContentChannel(channel, category, subPrice, subTime, permitExternalSubs, description);
        const categoryChannelsLength = await instance.getCategoryLength(category);
        const categoryChannels = await instance.getChannelsFromCategories(category, 0, categoryChannelsLength);
        channel1Address = categoryChannels[categoryChannelsLength - 1];
        const channel2Instance = new ContentChannel(channel1Address);
        const channel2Name = await channel2Instance.channelName();

        assert.equal(channel, channel2Name.substring(0, 32), "The channel has not inserted into the category");
    })

    it("Set min. subscription fee for All Content Channels", async() => {
        const subscriptionFee = web3.utils.toWei("0.01");

        instance.setSubscriptionFee(subscriptionFee);
        assert.equal(await instance.minSubscriptionFee(), subscriptionFee, "The admin couldn't set the subscription Fee");
    });

    it("Subscribe to the channel", async() => {
        const channel = new ContentChannel(channel1Address);

        account1Identity = new IdenityService()
        const serializedPubKey1 = account1Identity.getSerializedPublicKey()
        const subscribeSuccess1 = await channel.subscribe(
          serializedPubKey1.pubKeyPrefix,
          serializedPubKey1.pubKey,
          {from: accounts[1], value: web3.utils.toWei("0.1")}
        );
        assert.equal(subscribeSuccess1.receipt.status, true, "The subscription didn't perform.");

        account2Identity = new IdenityService()
        account3Identity = new IdenityService()
        const serializedPubKey2 = account1Identity.getSerializedPublicKey()
        const subscribeSuccess2 = await channel.subscribe(
          serializedPubKey2.pubKeyPrefix,
          serializedPubKey2.pubKey,
          {from: accounts[2], value: web3.utils.toWei("0.1")}
        );
        const serializedPubKey3 = account1Identity.getSerializedPublicKey()
        const subscribeSuccess3 = await channel.subscribe(
          serializedPubKey3.pubKeyPrefix,
          serializedPubKey3.pubKey,
          {from: accounts[3], value: web3.utils.toWei("0.1")}
        );
        assert.equal(await channel.getSubscriptionCount(), 3, 'There are not 3 subscribers');
    });

    it('Remove the first 2 from the 3 subsribers', async() => {
        const channel = new ContentChannel(channel1Address);

        await channel.removeSubscribers([2, 0]);
        const subscribersCount = await channel.getSubscriptionCount();
        assert.equal(subscribersCount, 1, 'accounts[2] is not the only one subscriber in the subscribers array');
        const onlySubscriber = await channel.subscribers(0);
        assert.equal(onlySubscriber, accounts[2], "The only subscriber is not the accounts[2]");
    })

})
