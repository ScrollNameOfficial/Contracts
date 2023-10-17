// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ScrollName is ERC721Enumerable,Ownable {
    string uri;

    struct Domain {
        string name;
        uint256 expirationTime;
    }

    mapping(uint256 => Domain) private ensRegistry;
    mapping(string => uint256) private nameToTokenId;
    mapping(address => uint256) private addressToTokenId;
    mapping(address => uint256) private pointsBalance;

    uint256 private registrationFee = 13740910 wei;

    event DomainRegistered(uint256 indexed tokenId, string name, address indexed owner);

    modifier ensureNotExpired(uint256 tokenId) {
        require(!isExpired(tokenId), "Domain is expired");
        _;
    }

    constructor() ERC721("ScrollName", "SN") {
        uri = "https://app.scrollname.com/metadata/";
    }

    function getPointsBalance(address addr) external view returns (uint256) {
        return pointsBalance[addr];
    }

    function register(uint256 tokenId, string memory name, uint256 duration ,address inviter) external payable {

        uint256 expirationTime = block.timestamp + duration;

        require(ensRegistry[tokenId].expirationTime == 0, "Token already registered");
        require(nameToTokenId[name] == 0, "Name already registered");

        uint256 price = getPrice(duration);

        require(msg.value >= price, "Insufficient registration fee");

        if (nameToTokenId[name] != 0) {
            uint256 previousTokenId = nameToTokenId[name];
            require(isExpired(previousTokenId), "Name already registered");
            _burn(previousTokenId);
        }

        _mint(msg.sender, tokenId);
        ensRegistry[tokenId] = Domain(name, expirationTime);
        nameToTokenId[name] = tokenId;
        addressToTokenId[msg.sender] = tokenId;

        emit DomainRegistered(tokenId, name, msg.sender);

        if (msg.value > price) {
            uint256 refundAmount = msg.value - price;
            //payable(msg.sender).transfer(refundAmount);
            (bool success,)= payable(msg.sender).call{value: refundAmount}("");
            require(success,"refund fail");
        }
        //payable(owner()).transfer(price);
        (bool success_price,)= payable(owner()).call{value: price}("");
        require(success_price,"trans price fail");

        pointsBalance[msg.sender] += 100;

        if (inviter != address(0)) {
            // Add points to the inviter's balance
            pointsBalance[inviter] += 20;
        }

    }

    function isExpired(uint256 tokenId) public view returns (bool) {
        return block.timestamp > ensRegistry[tokenId].expirationTime;
    }

    function getAddressByName(string memory name) external view returns (address) {
        require(nameToTokenId[name] != 0, "Name not registered");
        return ownerOf(nameToTokenId[name]);
    }

    function getNameByAddress(address addr) external view returns (string memory) {
        require(addressToTokenId[addr] != 0, "Address not registered");
        return ensRegistry[addressToTokenId[addr]].name;
    }

    function getNameByTokenId(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return ensRegistry[tokenId].name;
    }

    function withdrawFunds() onlyOwner external {
        require(address(this).balance > 0, "No funds to withdraw");
        //payable(msg.sender).transfer(address(this).balance);
        (bool success,)= payable(msg.sender).call{value: address(this).balance}("");
        require(success,"trans eth fail");
    }

    function setUri(string memory i) onlyOwner public  {
        uri = i;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(uri, Strings.toString(tokenId)));
    }

    function getPrice(uint256 duration) public view returns (uint256){
        return duration * registrationFee;
    }

    function setRegistrationFee(uint256 fee) external onlyOwner {
        registrationFee = fee;
    }

    function getExpirationTimeFromName(string memory name) external view returns (uint256) {
        require(nameToTokenId[name] != 0, "Name not registered");
        return ensRegistry[nameToTokenId[name]].expirationTime;
    }
}