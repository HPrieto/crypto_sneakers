pragma solidity >=0.4.22 <0.9.0;

import "./AccessControl.sol";

/// @title Base contract for CryptoSneakers. Holds all common structs, events and base variables.
/// @author Heriberto Prieto
/// @dev See the SneakerCore contract documentation to understand how the various contract facets are arranged.
contract SneakerBase is AccessControl {
  /*** EVENTS ***/

  /// @dev Transfer event as defined in current draft of ERC721. Emitted every time a kitten
  ///  ownership is assigned, including births.
  event Transfer(address from, address to, uint256 tokenId);

  /*** DATA TYPES ***/

  // All the brands supported by CyptoSneakers.
  enum Brand {
    Adidas,
    AirJordan,
    AlexanderMcQueen,
    ASICS,
    Balenciaga,
    Burberry,
    Chanel,
    CommonProjects,
    Converse,
    Crocs,
    Diadora,
    Dior,
    Gucci,
    LiNing,
    LouisVuitton,
    NewBalance,
    Nike,
    OffWhite,
    Prada,
    Puma,
    Reebok,
    SaintLaurent,
    Saucony,
    UnderArmor,
    Vans,
    Versace
  }

  /// @dev The main Sneaker struct. Every Sneaker in CryptoSneakers is represented by a copy
  ///  of this structure, so great care was taken to ensure that it fits neatly into
  ///  exactly two 256-bit words. Note that the order of the members in this structure
  ///  is important because of the byte-packing rules used by Ethereum.
  /// @note Example sneaker can be found in: https://stockx.com/air-jordan-1-retro-high-patina
  struct Sneaker {
    // Brand of the sneaker.
    // Example: Nike
    Brand brand;

    // Name of the sneaker.
    // Example: 'Jordan 1 Retro High Patina'
    string name;

    // Size of specific sneaker.
    // Example: 10.5
    uint64 size;

    // Plant where sneaker was manufactured.
    // Example: XC
    // string plant;

    // Style code assigned by manufacturer;
    // Example: 555088-033
    string style;

    // Colorway of the sneaker.
    // Example: BLACK/GREY-RUST
    string colorWay;

    // Price of sneaker set by manufacturer on release.
    // Example: 170
    uint32 retailPrice;

    // Date when sneaker was manufactured.
    // Example: 01/05/2020 converted to timestamp.
    uint64 manufactureTime;

    // The date when sneaker was release on retail.
    // Example: 03/25/2021 converted to timestamp.
    uint64 releaseTime;

    // Unique code assigned to each sneaker by StockX.
    // Example: JB-JO1RHRSBG
    string stockXTicker;
  }

  /// @dev A lookup table indicating the cooldown duration after any successful
  ///  action requiring cooldown.
  uint32[14] public cooldowns = [
    uint32(1 minutes),
    uint32(2 minutes),
    uint32(5 minutes),
    uint32(10 minutes),
    uint32(30 minutes),
    uint32(1 hours),
    uint32(2 hours),
    uint32(4 hours),
    uint32(8 hours),
    uint32(16 hours),
    uint32(1 days),
    uint32(2 days),
    uint32(4 days),
    uint32(7 days)
  ];

  // An approximation of currently how many seconds are in between blocks.
  uint256 public secondsPerBlock = 15;

  /*** STORAGE ***/

  /// @dev An array containing the Sneaker struct for all Sneakers in existence. The ID
  ///  of each sneaker is actually an index into this array.
  Sneaker[] sneakers;

  /// @dev A mapping from sneaker IDs to the address that owns them. All sneakers have
  ///  some valid owner address.
  mapping (uint256 => address) public sneakerIndexToOwner;

  /// @dev A mapping from owner address to count of tokens that address owns.
  ///  Used internally inside balanceOf() to resolve ownership count.
  mapping (address => uint256) ownershipTokenCount;

  /// @dev A mapping from SneakerIDs to an address that has been approved to call
  ///  transferFrom(). Each Sneaker can only have one approved address for transfer
  ///  at any time. A zero value means no approval is outstanding.
  mapping (uint256 => address) public sneakerIndexToApproved;

  /// @dev A mapping from Sneaker StockX ticker to SneakerID. Each StockX ticker can only
  ///  be assigned to a specific sneaker.
  mapping (string => uint256) public stockXTickerToSneaker;

  /// @dev The address of the ClockAuction contract that handles sales of Sneakers. This
  ///  same contract handles both peer-to-peer sales.
  // SaleClockAuction public saleAuction;
  // TODO: Create SaleClockAuction contract.

  /// @dev Assigns ownership of a specific Sneaker to an address.
  function _transfer(address _from, address _to, uint256 _tokenId) internal {
    // Since the number of sneakers is capped to 2^32 we can't overflow this
    ownershipTokenCount[_to]++;
    // transfer ownership.
    sneakerIndexToOwner[_tokenId] = _to;
    // When creating new sneakers _from is 0x0, but we can't account that address.
    if (_from != address(0)) {
      ownershipTokenCount[_from]--;
      // clear any previously approved ownership exchange.
      delete sneakerIndexToApproved[_tokenId];
    }
    // Emit the transfer event.
    emit Transfer(_from, _to, _tokenId);
  }

  /// @dev An internal method that creates a new sneaker and stores it. This
  ///  method doesn't do any checking and should only be called when the
  ///  input data is known to be valid. Will generate a Transfer event.
  /// @param _brand The brand name of the sneaker.
  /// @param _name The name of the sneaker assigned by the brand.
  /// @param _size The size of the sneaker.
  /// @param _style The style number of the sneaker.
  /// @param _colorWay The colorway of the sneaker
  /// @param _retailPrice The price of the sneaker when released for retail purchasing.
  /// @param _manufactureTime The time when the shoe was manufactured.
  /// @param _releaseTime The date when the sneaker was first released for retail.
  /// @param _stockXTicker The unique identifier assigned to the sneaker by StockX.
  /// @param _owner The owner of the newly created sneaker.
  function _createSneaker(
    Brand _brand,
    string memory _name,
    uint32 _size,
    string memory _style,
    string memory _colorWay,
    uint32 _retailPrice,
    uint64 _manufactureTime,
    uint64 _releaseTime,
    string memory _stockXTicker,
    address _owner
  )
    internal
    returns (uint)
  {
    // These requires are not strictly necessary, our calling code should make
    // sure that these conditions are never broken. However! _createSneaker() is already
    // an expensive call (for storage), and it doesn't hurt to be especially careful
    // to ensure our data structures are always valid.
    require(_size == uint256(uint32(_size)));
    require(_retailPrice == uint256(uint64(_retailPrice)));

    Sneaker memory _sneaker = Sneaker({
      brand: _brand,
      name: _name,
      size: _size,
      style: _style,
      colorWay: _colorWay,
      retailPrice: _retailPrice,
      manufactureTime: _manufactureTime,
      releaseTime: _releaseTime,
      stockXTicker: _stockXTicker
    });

    uint256 newSneakerId = sneakers.push(_sneaker) - 1;

    // It's probably never going to happen, 4 billion sneakers is A LOT, but
    // let's just be 100% sure we never let this happen.
    require(newSneakerId == uint256(uint32(newSneakerId)));

    // Emit Transfer Event
    _transfer(address(0), _owner, newSneakerId);

    return newSneakerId;
  }
}
