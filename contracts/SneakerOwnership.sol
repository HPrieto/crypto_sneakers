pragma solidity >=0.4.22 <0.9.0;

import "./SneakerBase.sol";
import "./ERC721.sol";
import "./ERC721Metadata.sol";

/// @title The fact of CryptoSneakers core contract that manages ownership, ERC-721 (draft compliant).
/// @author Heriberto Prieto
contract SneakerOwnership is SneakerBase, ERC721 {

  /// @notice Name and symbol of the non fungible token, as defined in ERC721.
  string public constant name = "CryptoSneakers";
  string public constant symbol = "CS";

  // The contract that will return Sneaker metadata;
  ERC721Metadata public erc721Metadata;

  bytes4 constant InterfaceSignature_ERC165 =
    bytes4(keccak256('supportsInterface(bytes4)'));

  bytes4 constant InterfaceSignature_ERC721 =
    bytes4(keccak256('name()')) ^
    bytes4(keccak256('symbol()')) ^
    bytes4(keccak256('totalSupply()')) ^
    bytes4(keccak256('balanceOf(address)')) ^
    bytes4(keccak256('ownerOf(uint256)')) ^
    bytes4(keccak256('approve(address,uint256)')) ^
    bytes4(keccak256('transfer(address,uint256)')) ^
    bytes4(keccak256('transferFrom(address,address,uint256)')) ^
    bytes4(keccak256('tokensOfOwner(address)')) ^
    bytes4(keccak256('tokenMetadata(uint256,string)'));

  /// @notice Introspection interface as per ERC-165
  ///  Returns true for any standardized interfaces implemented by this contract. We implement
  ///  ERC0165 (obviously!) and ERC-721;
  function supportsInterface(bytes4 _interfaceID) external view returns (bool) {
    // DEBUG ONLY
    //require((InterfaceSignature_ERC165 == 0x01ffc9a7) && (InterfaceSignature_ERC721 == 0x9a20483d));
    return ((_interfaceID == InterfaceSignature_ERC165) || (_interfaceID == InterfaceSignature_ERC721));
  }

  /// @dev Set the address of the sibling contract that tracks metadata.
  ///  CEO only.
  function setMetadataAddress(address _contractAddress) public onlyCEO {
    erc721Metadata = ERC721Metadata(_contractAddress);
  }

  // Internal utility functions: These functions all assume that their input arguments
  // are valid. We leave it to public methods to sanitize their inputs and follow
  // the required logic.

  /// @dev Checks if a given address is the current owner of a particular Sneaker.
  /// @param _claimant The address we are validating against.
  /// @param _tokenId sneaker id, only valid when > 0
  function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
    return sneakerIndexToOwner[_tokenId] == _claimant;
  }

  /// @dev Checks if a given address currently has transferApproval for a particular Sneaker.
  /// @param _claimant The address we are validating against.
  /// @param _tokenId Sneaker id, only valid when > 0.
  function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
    return sneakerIndexToApproved[_tokenId] == _claimant;
  }

  /// @dev Marks an address as being approved for transferFrom(), overwriting any previous
  ///  approval. Settings _approved to address(0) clears all transfer approval.
  ///  NOTE: _approve() does NOT send the Approval event. This is intentional because
  ///  _approve() and transferFrom() are used together for putting Sneakers on auction, and
  ///  there is no value in spamming the log with Approval events in that case.
  function _approve(uint256 _tokenId, address _approved) internal {
    sneakerIndexToApproved[_tokenId] = _approved;
  }

  /// @notice Returns the number of Sneakers owned by a specific address.
  /// @param _owner The owner address to check.
  /// @dev Required for ERC-721 compliance.
  function balanceOf(address _owner) public view returns (uint256 count) {
    return ownershipTokenCount[_owner];
  }

  /// @notice Transfers a Sneaker to another address. If transferring to a smart
  ///  contract be VERY CAREFUL to ensure that it is aware of ERC-721 (or
  ///  CryptoSneakers specifically) or your Sneaker may be lost forever. Seriously.
  /// @param _to The address of the recipient, can be a user or contract.
  /// @param _tokenId The ID of the Sneaker to transfer.
  /// @dev Required for ERC-721 compliance.
  function transfer(address _to, uint256 _tokenId) external whenNotPaused {
    // Safety check to prevent against an unexpected 0x0 default.
    require(_to != address(0));
    // Disallow transfers to this contract to prevent accidental misuse.
    // The contract should never own any sneakers (except very briefly
    // after creation and before it goes on auction).
    require(_to != address(this));
    // Disallow transfers to the auction contracts to prevent accidental
    // misuse. Auction contracts should only take ownership of Sneakers
    // through the allow + transferFrom flow.
    // require(_to != address(saleAuction));
    // TODO: complete saleAuction

    // You can only send your own sneaker.
    require(_owns(msg.sender, _tokenId));

    // Reassign ownership, clear pending approvals, emit Transfer event.
    _transfer(msg.sender, _to, _tokenId);
  }

  /// @notice Grant another address the right to transfer a specific Sneaker via
  ///  transferFrom(). This is preferred flow for transfering NFTs to contacts.
  /// @param _to The address to be granted transfer approval. Pass address(0) to
  ///  clear all approvals.
  /// @param _tokenId The ID of the Sneaker that can be transferred if this call succeeds.
  /// @dev Required for ERC-721 compliance.
  function approve(address _to, uint256 _tokenId) external whenNotPaused {
    // Only an owner can grant transfer approval.
    require(_owns(msg.sender, _tokenId));

    // Register the approval (replacing any previous approval).
    _approve(_tokenId, _to);

    // Emit approval event.
    emit Approval(msg.sender, _to, _tokenId);
  }

  /// @notice Transfer a Sneaker owned by another address, for which the calling address
  ///  has previously been granted transfer approval by the owner.
  /// @param _from The address that owns the Sneaker to be transferred.
  /// @param _to The address that should take ownership of the Sneaker. Can be any address,
  ///  including the caller.
  /// @param _tokenId The ID of the Sneaker to be transferred.
  /// @dev Required for ERC-721 compiance.
  function transferFrom(address _from, address _to, uint256 _tokenId) external whenNotPaused {
    // Safety check to prevent against an unexpected 0x0 default.
    require(_to != address(0));
    // Disallow transfers to this contract to prevent accidental misuse.
    // The contract should never own any Sneakers (except very briefly
    // after creation and before it goes on auction).
    require(_to != address(this));
    // check for approval and valid ownership
    require(_approvedFor(msg.sender, _tokenId));
    require(_owns(_from, _tokenId));

    // Reassign ownership (also clears pending approvals and emits Transfer event).
    _transfer(_from, _to, _tokenId);
  }

  // @notice Returns the total number of Sneakers currently in existence.
  // @dev Required for ERC-721 compliance.
  function totalSupply() public view returns (uint) {
    return sneakers.length - 1;
  }

  /// @notice Returns the total number of Sneakers currently in existence.
  /// @dev Required for ERC-721 compliance.
  function ownerOf(uint256 _tokenId) external view returns (address owner) {
    owner = sneakerIndexToOwner[_tokenId];
    require(owner != address(0));
  }

  /// @notice Returns a list of all Sneaker IDs assigned to an address.
  /// @param _owner The owner whose Sneakers we are interested in.
  /// @dev This method MUST NEVER be called by smart contract code. First, it's faily
  ///  expensive (it walks the sntire Sneaker array looking for sneakers belonging to the owner.,
  ///  but it also returns a dynamic array, which is only supported for web3 calls, and
  ///  not contract-to-contract calls.
  function tokensOfOwner(address _owner) external view returns(uint256[] memory ownerTokens) {
    uint256 tokenCount = balanceOf(_owner);

    if (tokenCount == 0) {
      // Return an empty array.
      return new uint256[](0);
    } else {
      uint256[] memory result = new uint256[](tokenCount);
      uint256 totalSneakers = totalSupply();
      uint256 resultIndex = 0;

      // We count on the fact that all cats have IDs starting at 1 and increasing
      // sequentially up to the totalSneaker count.
      uint256 sneakerId;

      for (sneakerId = 1; sneakerId <= totalSneakers; sneakerId++) {
        if (sneakerIndexToOwner[sneakerId] == _owner) {
          result[resultIndex] = sneakerId;
          resultIndex++;
        }
      }

      return result;
    }
  }

  /// @dev Adapted from memcpy() by @hprieto
  function _memcpy(uint _dest, uint _src, uint _len) private view {
    // Copy word-length chucks while possible.
    for(; _len >= 32; _len -= 32) {
      assembly {
        mstore(_dest, mload(_src))
      }
      _dest += 32;
      _src += 32;
    }

    // Copy remaining bytes
    uint256 mask = 256 ** (32 - _len) - 1;
    assembly {
      let srcpart := and(mload(_src), not(mask))
      let destpart := and(mload(_dest), mask)
      mstore(_dest, or(destpart, srcpart))
    }
  }

  /// @dev Adapted from toString(slice) by @hprieto
  function _toString(bytes32[4] memory _rawBytes, uint256 _stringLength) private view returns (string memory) {
    string memory outputString = new string(_stringLength);
    uint256 outputPtr;
    uint256 bytesPtr;

    assembly {
      outputPtr := add(outputString, 32)
      bytesPtr := _rawBytes
    }

    _memcpy(outputPtr, bytesPtr, _stringLength);

    return outputString;
  }

  /// @notice Returns a URI pointing to a metadata package for this token conforming to
  ///  ERC-721 (https://github.com/ethereum/EIPs/issues/721)
  /// @param _tokenId The ID number of the Sneaker whose metadata should be returned.
  function tokenMetadata(uint256 _tokenId, string calldata _preferredTransport) external view returns (string memory infoUrl) {
    require(address(erc721Metadata) != address(0));
    bytes32[4] memory buffer;
    uint256 count;
    (buffer, count) = erc721Metadata.getMetadata(_tokenId, _preferredTransport);

    return _toString(buffer, count);
  }
}
