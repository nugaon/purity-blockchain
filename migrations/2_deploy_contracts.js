const Subscriptions = artifacts.require("Subscriptions");
const FileUploads = artifacts.require("FileUploads");
const PurityNet = artifacts.require("PurityNet");

module.exports = function(deployer, network, accounts) {
    deployer.deploy(Subscriptions, accounts[0]);
    deployer.deploy(FileUploads, accounts[0]);
    deployer.deploy(PurityNet);
};
