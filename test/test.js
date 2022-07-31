const { expect } = require("chai");
const { assert } = require("hardhat");

const {BN, constants, expectEvent, expectRevert} = require('@openzeppelin/test-helpers');
const { soliditySha3 } = require("web3-utils");

const Example = artifacts.require("Example");

let accounts;
let exampleOne;
let owner;

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("Example Contract", function () {

	before(async function() {
		accounts = await web3.eth.getAccounts();
		owner = accounts[0];
		exampleOne = await Example.new("ExampleOne", "EX1", 137);
	});
	
	it("Should return the right name and symbol of the token once ExampleOne is deployed", async function() {
		assert.equal(await exampleOne.name(), "ExampleOne");
		assert.equal(await exampleOne.symbol(), "Ex1");
	});
  
});