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
  function _owns(address _claimant, uint256 _tokenId) external view returns (bool) {
    return sneakerIndexToOwner[_tokenId] == _claimant;
  }
}
