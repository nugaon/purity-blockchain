const Subscriptions = artifacts.require("Subscriptions");
const FileUploads = artifacts.require("FileUploads");
const ContentChannel = artifacts.require("ContentChannel");
const PurityNet = artifacts.require("PurityNet");

module.exports = function(deployer, network, accounts) {
    deployer.deploy(PurityNet, 5, web3.utils.toWei("0.001")).then(() => {
      // deployer.deploy(Subscriptions,
      //   web3.utils.toWei("1"), //sub fee
      //   accounts[0] //owner
      // );
      // deployer.deploy(FileUploads,
      //   accounts[0], //owner
      //   0, //channelId
      //   PurityNet.address
      // );
      // deployer.deploy(ContentChannel,
      //   web3.utils.fromAscii('channel1'), //channel name
      //   web3.utils.toWei("1"), //sub fee
      //   "description",
      //   accounts[0]
      // );
    });
};
