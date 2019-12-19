const Subscriptions = artifacts.require("Subscriptions");
const FileUploads = artifacts.require("FileUploads");
const ContentChannel = artifacts.require("ContentChannel");
const PurityNet = artifacts.require("PurityNet");

module.exports = function(deployer, network, accounts) {
    deployer.deploy(Subscriptions, web3.utils.toWei("1"), accounts[0]);
    deployer.deploy(FileUploads, accounts[0]);
    deployer.deploy(ContentChannel, web3.utils.fromAscii('channel1'), web3.utils.toWei("1"), "description", accounts[0]);
    deployer.deploy(PurityNet);
};
