const PurityNet = artifacts.require("PurityNet");
const Subscriptions = artifacts.require("Subscriptions");

contract('PurityNet', (accounts) => {

    it('Creates a channel', async() => {
        const instance = await PurityNet.deployed();
        const topic = web3.utils.fromAscii('topic1');
        const channel = web3.utils.fromAscii('contentChannel1');

        await instance.createContentChannel(channel, topic);
        const topicsLength = await instance.getTopicsLength(topic);
        const channel2 = await instance.getTopicItem(topic, topicsLength - 1);

        assert.equal(channel, channel2.substring(0, 32), "The channel creation wasn't successful");
    })

    it('Subscribe to the channel', async() => {
        const instance = await PurityNet.deployed();
        const channel = web3.utils.fromAscii('contentChannel1');
        const channelEntity = await instance.contentChannels(channel);
        const subscriptionHandler = new web3.eth.Contract(Subscriptions.abi, channelEntity.subscriptionHandler);

        await subscriptionHandler.methods.subscribe().send({from: accounts[2]});

        const subscriptionHappened = await subscriptionHandler.methods.getSubscriptionCount().call({from: accounts[2]});

        assert.equal(subscriptionHappened, 1, "The subscription wasn't successful");
    })
})
