// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./BondingCurve.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./lib/SafeDecimalMath.sol";
import "./structs/RoundResult.sol";
// import "hardhat/console.sol";

contract BattleLP is BondingCurve, ERC20Upgradeable {

    using SafeDecimalMath for uint;

    mapping(uint=>uint) public startPrice;
    mapping(uint=>uint) public endPrice;

    mapping(uint=>uint) public startTS;
    mapping(uint=>uint) public endTS;

    mapping(uint=>uint) public strikePrice;
    mapping(uint=>uint) public strikePriceOver;
    mapping(uint=>uint) public strikePriceUnder;

    mapping(uint=>RoundResult) public roundResult;

    mapping(address=>uint) public lockTS;

    function _tryAddLiquidity(uint ri, uint cDeltaAmount) internal view returns(uint cDeltaSpear, uint cDeltaShield, uint deltaSpear, uint deltaShield, uint lpDelta) {
        uint cVirtual = cSpear[ri] + cShield[ri];
        cDeltaSpear = cSpear[ri].multiplyDecimal(cDeltaAmount).divideDecimal(cVirtual);
        cDeltaShield = cShield[ri].multiplyDecimal(cDeltaAmount).divideDecimal(cVirtual);
        deltaSpear = spearBalance[ri][address(this)].multiplyDecimal(cDeltaAmount).divideDecimal(cVirtual);
        deltaShield = shieldBalance[ri][address(this)].multiplyDecimal(cDeltaAmount).divideDecimal(cVirtual);
        if(totalSupply() == 0) {
            lpDelta = cDeltaAmount;
        } else {
            lpDelta = cDeltaAmount.multiplyDecimal(totalSupply()).divideDecimal(collateral[ri]);
        }
    }

    function _addLiquidity(uint ri, uint cDeltaAmount) internal returns (uint lpDelta) {
        (uint cDeltaSpear, uint cDeltaShield, uint deltaSpear, uint deltaShield, uint _lpDelta) = _tryAddLiquidity(ri, cDeltaAmount);
        addCSpear(ri, cDeltaSpear);
        addCShield(ri, cDeltaShield);
        mintSpear(ri, address(this), deltaSpear);
        mintShield(ri, address(this), deltaShield);
        // mint lp
        lpDelta = _lpDelta;
        _mint(msg.sender, lpDelta);
    }

    function _getCDelta(uint ri, uint lpDeltaAmount) internal view returns(uint cDelta) {
        uint spSold = spearSold(ri);
        uint shSold = shieldSold(ri);

        uint maxSold = spSold > shSold ? spSold:shSold;
        // console.log("collateral %s, maxSold %s", collateral[ri]/1e18, maxSold/1e18);
        cDelta = (collateral[ri] - maxSold).multiplyDecimal(lpDeltaAmount).divideDecimal(totalSupply());
    }

    function _tryRemoveLiquidity(uint ri, uint lpDeltaAmount) internal view returns(uint cDelta, uint deltaSpear, uint deltaShield, uint earlyWithdrawFee){
        uint cDelta0 = _getCDelta(ri, lpDeltaAmount);
        // console.log("tryRemoveLiquidity cDelta %s", cDelta0/1e18);

        cDelta = cDelta0.multiplyDecimal(1e18-pRatio(ri));
        // cDelta = cDelta0;
        earlyWithdrawFee = cDelta0 - cDelta;
        // console.log("tryRemoveLiquidity cDelta %s", cDelta);
        deltaSpear = spearBalance[ri][address(this)].multiplyDecimal(lpDeltaAmount).divideDecimal(totalSupply());
        deltaShield = shieldBalance[ri][address(this)].multiplyDecimal(lpDeltaAmount).divideDecimal(totalSupply());
    }

    function _removeLiquidity(uint ri, uint lpDeltaAmount) internal returns(uint, uint) {
        (uint cDelta, uint deltaSpear, uint deltaShield, ) = _tryRemoveLiquidity(ri, lpDeltaAmount);
        // console.log("%s", cDelta / 1e18);
        // console.log("%s", deltaSpear / 1e18);
        // console.log("%s", deltaShield / 1e18);
        uint cDeltaSpear = cSpear[ri].multiplyDecimal(lpDeltaAmount).divideDecimal(totalSupply());
        uint cDeltaShield = cShield[ri].multiplyDecimal(lpDeltaAmount).divideDecimal(totalSupply());
        // uint cDeltaSpear = cDelta.multiplyDecimal(cSpear[ri]).divideDecimal(collateral[ri]);
        // uint cDeltaShield = cDelta.multiplyDecimal(cShield[ri]).divideDecimal(collateral[ri]);
        // uint cDeltaSurplus = cDelta.multiplyDecimal(cSurplus(ri)).divideDecimal(collateral[ri]);
        // console.log("cDeltaSpear %s", cDeltaSpear/1e18);
        // console.log("cDeltaShield %s", cDeltaShield/1e18);
        // console.log("cDeltaSurplus %s", cDeltaSurplus/1e18);
        subCSpear(ri, cDeltaSpear);
        subCShield(ri, cDeltaShield);
        if (cDeltaSpear + cDeltaShield >= cDelta) {
            addCSurplus(ri, cDeltaSpear+cDeltaShield-cDelta);
        } else {
            subCSurplus(ri, cDelta - cDeltaSpear - cDeltaShield);
        }
        burnSpear(ri, address(this), deltaSpear);
        burnShield(ri, address(this), deltaShield);
        _burn(msg.sender, lpDeltaAmount);
        // console.log("%s", 8);
        return (cDelta, lpDeltaAmount);
    }

    // penalty ratio
    function pRatio(uint ri) public view returns (uint ratio){
        if (spearSold(ri) == 0 && shieldSold(ri) == 0) {
            return 0;
        }
        uint s = 1e18 - (endTS[ri]-block.timestamp).divideDecimal(endTS[ri]-startTS[ri]);
        // console.log("pRatio %s", s);
        ratio = (DMath.sqrt(s) * 1e9).multiplyDecimal(1e16);
        // console.log("pRatio ra   tio %s", ratio);
    }

    function _beforeTokenTransfer(address from, address to, uint amount) internal override {
        require(block.timestamp >= lockTS[from], "Locking");
        require(block.timestamp >= lockTS[to], "Locking");
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterAddLiquidity(uint ri, uint cDeltaAmount) internal virtual {}
    function _afterRemoveLiquidity(uint ri, uint lpDeltaAmount) internal virtual {}

}