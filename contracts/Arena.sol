// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "./structs/SettleType.sol";
import "./structs/PeroidType.sol";
import "./interfaces/IArena.sol";
import "./interfaces/IOracle.sol";
import "./lib/SafeDecimalMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/ICreater.sol";
import "./interfaces/IBattle.sol";

pragma solidity ^0.8.0;

contract Arena is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeDecimalMath for uint256;

    EnumerableSetUpgradeable.AddressSet private battleSet;

    IOracle public oracle;
    ICreater public creater;

    mapping(address => bool) public isExist;

    function initialize() public initializer {
        __Ownable_init_unchained();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function setCreater(address _creater) public onlyOwner {
        creater = ICreater(_creater);
    }

    function setOracle(address _oracle) public onlyOwner {
        oracle = IOracle(_oracle);
    }

    function battleLength() public view returns (uint256 len) {
        len = battleSet.length();
    }

    function addBattle(address _battle) public {
        battleSet.add(_battle);
    }

    function getBattle(uint256 index) public view returns (address _battle) {
        _battle = battleSet.at(index);
    }

    function removeBattle(address _battle) public {
        battleSet.remove(_battle);
    }

    function containBattle(address _battle) public view returns (bool) {
        return battleSet.contains(_battle);
    }

    // /**
    //  * @param _collateral collateral token address, eg. DAI
    //  * @param _oracle oracle contract address
    //  * @param _trackName battle's track name, eg. WBTC-DAI
    //  * @param _priceName eg. BTC
    //  * @param amount collateral's amount
    //  * @param _spearPrice init price of spear, eg. 0.5*10**18
    //  * @param _shieldPrice init price of shield, eg. 0.5*10**18
    //  */
    function createBattle(
        address _collateral,
        string memory _trackName,
        string memory _priceName,
        uint256 _cAmount,
        uint256 _spearPrice,
        uint256 _shieldPrice,
        PeroidType _peroidType,
        SettleType _settleType,
        uint256 _settleValue
    ) public {
        // require(_peroidType == 0 || _peroidType == 1 || _peroidType == 2, "Not support battle duration");
        if (_settleType == SettleType.Positive) {
            require(_spearPrice < 5e17, "Arena::spear < 0.5");
        } else if (_settleType == SettleType.Negative) {
            require(_spearPrice > 5e17, "Arena::spear > 0.5");
        } else if (_settleType == SettleType.Specific) {
            (uint256 startPrice, uint256 strikePrice, , ) =
                oracle.getStrikePrice(
                    _priceName,
                    uint256(_peroidType),
                    uint256(_settleType),
                    _settleValue
                );
            if (strikePrice >= startPrice) {
                require(_spearPrice < 5e17, "Arena::spear < 0.5");
            } else {
                require(_spearPrice > 5e17, "Arena::spear > 0.5");
            }
        }
        if (_settleType != SettleType.Specific) {
            require(_settleValue % 1e16 == 0, "Arena::min 1%");
        }
        require(_spearPrice + _shieldPrice == 1e18, "should 1");

        (address battleAddr, bytes32 salt) =
            creater.getBattleAddress(
                _collateral,
                _trackName,
                uint256(_peroidType),
                uint256(_settleType),
                _settleValue
            );
        require(battleSet.contains(battleAddr) == false, "existed");
        creater.createBattle(salt);
        IERC20Upgradeable(_collateral).safeTransferFrom(
            msg.sender,
            address(this),
            _cAmount
        );
        IERC20Upgradeable(_collateral).safeTransfer(battleAddr, _cAmount);
        IBattle battle = IBattle(battleAddr);
        battle.init0(
            _collateral,
            address(this),
            _trackName,
            _priceName,
            _peroidType,
            _settleType,
            _settleValue
        );
        battle.init(
            msg.sender,
            _cAmount,
            _spearPrice,
            _shieldPrice,
            address(oracle)
        );
        battleSet.add(address(battle));
    }

    function isBattleExist(
        address _collateral,
        string memory _trackName,
        uint256 _peroidType,
        uint256 _settleType,
        uint256 _settleValue
    ) public view returns (bool, address) {
        
    }
}
