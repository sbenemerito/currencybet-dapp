var Currency = artifacts.require("./Currency.sol");

module.exports = (deployer) => {
  deployer.deploy(Currency);
};
